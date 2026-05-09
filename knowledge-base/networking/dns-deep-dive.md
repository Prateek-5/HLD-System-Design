# DNS Deep Dive

> *"DNS is the name resolution system that makes the internet usable. It's also been the cause of more outages than any single piece of infrastructure: 'it's not DNS / there's no way it's DNS / it was DNS' is a meme because the experience is universal. Understanding DNS is understanding the layer everything depends on."*

---

## Topic Overview

DNS (Domain Name System) translates human-friendly names ("example.com") into machine-friendly IP addresses ("93.184.216.34"). It's a hierarchical, distributed, caching system designed in 1983 and still running. Every browser request, every API call, every email starts with a DNS lookup.

The design is elegant: a tree of authoritative servers; recursive resolvers that traverse the tree; caching at every layer; eventual consistency through TTLs. It scales to billions of requests per second globally with no central coordination.

The pathologies are also legendary: caches that don't expire when they should; resolvers that misbehave; outages that take hours to propagate; misconfigured records that cascade through every depending service. DNS outages are some of the worst because everything depends on DNS.

This is the topic where naming, distribution, and caching collide. DNS is so foundational that engineers rarely think about it — until something breaks. Understanding the system shapes architectural decisions: what TTLs to set, how to fail over, how to debug "the site is down for some users."

---

## Intuition Before Definitions

Imagine a global phone book where every entry has multiple copies, scattered around the world.

You want to call someone. You don't carry the entire phone book; you ask your local librarian. They might have it cached. If not, they ask a chain of more authoritative librarians until they find the answer. They tell you; they cache the answer for next time.

Each librarian's cache has a expiration time. After it expires, they re-query. If the answer changed, they get the new one — but only after the cache expires.

That's DNS. Your computer is the user; the local resolver is the librarian; the chain goes up to root servers and authoritative servers. TTLs determine how long answers are cached.

The brilliant part: this scales globally with no central authority. The problematic part: when you change a record, the change propagates only as fast as the longest TTL allows. "DNS propagation" is real; it's why DNS changes feel slow.

---

## Historical Evolution

**Era 1 — HOSTS.TXT.**
Early ARPANET: a single file `hosts.txt` listed all machines. Distributed manually. Worked for hundreds of hosts.

**Era 2 — DNS standardized.**
1983-1987. Paul Mockapetris designs DNS. RFCs 1034, 1035. Hierarchical, distributed.

**Era 3 — Recursive resolvers and caching.**
1990s. Most queries served from cache. Internet scales to millions of names.

**Era 4 — DNSSEC.**
~2005. DNS Security Extensions; cryptographic signatures. Slow adoption due to complexity.

**Era 5 — Encrypted DNS.**
~2018. DoH (DNS over HTTPS), DoT (DNS over TLS). Privacy and integrity concerns.

**Era 6 — Modern operational practice.**
Today. CDN-managed DNS (Route53, Cloudflare); GeoDNS; failover; integrated with traffic management.

The pattern: DNS's basic design is unchanged; modern usage layers operational sophistication on top.

---

## Core Mental Models

**1. DNS is a hierarchical tree.**
Root → TLD (`.com`) → second-level (`example.com`) → subdomains. Each level delegates to the next.

**2. Caching is everywhere.**
Browser, OS, recursive resolver, ISP. Every layer caches. TTLs control cache duration.

**3. Authority is delegated.**
Each domain has authoritative servers. They are the source of truth. Other servers cache from them.

**4. TTL trade-offs are operational.**
Long TTL: fewer queries; slow propagation of changes.
Short TTL: more queries; fast change propagation.

**5. Most DNS issues are caching issues.**
"Why isn't the change taking effect?" Almost always: somewhere in the cache hierarchy.

---

## Deep Technical Explanation

### The hierarchy

```
. (root)
├── com.
│   ├── google.com.
│   │   ├── www.google.com.
│   │   └── mail.google.com.
│   └── example.com.
├── org.
└── net.
```

Each level has authoritative nameservers. Root servers know the TLDs; TLD servers know the registered domains; domain servers know the records within.

13 root servers (named A-M) — actually anycast clusters with hundreds of physical servers. Highly redundant.

### Record types

- **A**: IPv4 address.
- **AAAA**: IPv6 address.
- **CNAME**: alias to another name.
- **MX**: mail server.
- **TXT**: arbitrary text (SPF, DKIM, etc.).
- **NS**: nameservers for the zone.
- **SOA**: start of authority; metadata.
- **PTR**: reverse DNS.
- **SRV**: service location.

Each record has a TTL. Different record types may have different uses.

### Recursive resolution

When you query `www.example.com`:

1. **Browser cache**: hit? return.
2. **OS cache**: hit? return.
3. **Stub resolver** sends to recursive resolver (typically ISP or 1.1.1.1 / 8.8.8.8).
4. **Recursive resolver** checks cache; if miss:
   a. Asks root server: "who's authoritative for .com?"
   b. Asks .com server: "who's authoritative for example.com?"
   c. Asks example.com server: "what's www.example.com?"
   d. Returns answer.
5. Recursive caches; returns to client.
6. Client caches; uses.

In practice: most lookups hit cache somewhere; full recursive resolution is rare.

### TTL strategy

**Low TTL (60s, 300s):**
- Fast failover possible.
- More query load on authoritative servers.
- Used for dynamic IPs, load-balancer health.

**Medium TTL (1 hour):**
- Standard for most records.
- Balance of query load and flexibility.

**High TTL (1 day, 1 week):**
- Reduces query load.
- Slow to react to changes.
- Used for stable infrastructure.

**Failover strategy:**
- Keep TTLs low (60-300s) on records you might fail over.
- During steady state: more queries; acceptable.
- During failover: change propagates within TTL.

### CNAME and chains

CNAME: name aliases another name. Common pattern:

```
www.example.com  CNAME  d12345.cloudfront.net.
d12345.cloudfront.net.  A  198.51.100.1
```

Browser resolves www.example.com → CNAME → resolves cloudfront.net → A record → IP.

CNAME chains shouldn't be too long; some resolvers limit to 5 hops.

CNAME at apex (`example.com` directly) is forbidden by RFC; modern providers use ALIAS or ANAME records to simulate.

### Anycast DNS

Public DNS providers (1.1.1.1, 8.8.8.8) use anycast: same IP advertised from many locations; users automatically reach the closest.

Properties:
- **Low latency**: closest server.
- **Automatic failover**: routing handles failures.
- **DDoS resistance**: distribute attack across many points.

Cloudflare, Google, Quad9 all use anycast.

### GeoDNS / Latency-based routing

Authoritative servers can return different answers based on the requester:
- Geographic location.
- Network performance.
- Server health.

Used for CDNs, regional routing, multi-region deployments.

Trade-off: caching becomes complicated. The recursive resolver caches *its* answer; users behind that resolver get the same answer regardless of their actual location.

### Failover with DNS

Pattern: DNS health checks; if origin fails, change DNS to point to backup.

Properties:
- Slow: TTL + cache propagation. Users see failover after their cache expires.
- Imperfect: some clients ignore TTL.

Mitigation:
- Low TTL (60s).
- Anycast (alternative; instant failover at network layer).
- Application-level retry to backup.

### DNSSEC

Cryptographic signatures on DNS records:
- Signed by zone's private key.
- Verified by chain of trust up to root.
- Prevents DNS spoofing.

Adoption is incomplete. Many domains aren't signed. Validation is sometimes problematic. DNSSEC is half-deployed in 2024.

### DNS over HTTPS (DoH) / TLS (DoT)

Encrypts DNS queries:
- DoT: DNS over TLS, port 853.
- DoH: DNS over HTTPS, looks like normal HTTPS traffic.

Privacy benefits: ISPs can't see queries. Operational impact: harder to monitor, filter.

Browser-level DoH (Firefox, Chrome) bypasses OS resolver. Enterprise concerns about visibility.

### Caching pathologies

**Cache poisoning.** Attacker injects malicious response into resolver's cache. Mitigated by source port randomization, DNSSEC.

**Stale entries.** Resolver returns expired entries due to bugs.

**Negative caching.** "This domain doesn't exist" cached. Sometimes too long.

**Inconsistent caches.** Different resolvers have different views; users behind different resolvers see different answers.

### Common operational issues

**The TTL miscalibration.** New service has TTL=86400 (1 day). Need to change IPs urgently. Wait a day for cache.

**The CNAME apex.** Customer sets CNAME on apex domain; some resolvers fail. Fix: use ALIAS / ANAME.

**The propagation panic.** Changed DNS; some users see old; others see new. Wait for TTL.

**The stale negative cache.** Domain didn't exist; now does; users still see "doesn't exist" until cache expires.

### Operational tools

- `dig` / `nslookup`: query specific records.
- `dig +trace`: full recursive trace.
- `dnsperf`: load testing.
- `cdnplanet`: see DNS from many locations.
- `MX Toolbox`, `DNSChecker`: web-based.

Production: monitoring DNS resolution from many points (synthetic monitoring); alerting on changes.

---

## Real Engineering Analogies

**The phone book hierarchy.**
National phone book → city phone books → individual entries. Each level points to the next. You don't carry the national book; you have a local one.

**The library inter-loan system.**
Local library doesn't have the book; asks regional library; regional asks national. The book travels; future requests cache. Each library has its own retention policy (TTL).

---

## Production Engineering Perspective

What goes wrong:

- **The DNS-induced outage.** Authoritative server fails; cached answers expire; users can't reach service. Recovery: bring authoritative back; or use longer TTLs going forward.
- **The cache propagation pain.** TTL is 24h; need to change IP; users on stale entries fail. Mitigation: lower TTLs ahead of changes.
- **The negative cache pollution.** Service deployed; some resolvers cached "doesn't exist" briefly; users see error for hours.
- **The DNSSEC validation failure.** Signed zone; validation breaks; resolvers can't validate; service unreachable. Recovery: fix DNSSEC or disable.
- **The CNAME chain explosion.** New service uses CDN that uses CDN; 7-hop CNAME chain. Some resolvers fail. Mitigation: shorter chains.
- **The internal DNS dependency.** Internal services use DNS; DNS server fails; everything fails. Mitigation: redundant DNS; local caching.

The senior engineer's habits:
- **Tune TTLs** based on change frequency.
- **Use anycast or low TTL** for failover.
- **Monitor DNS** from multiple geographies.
- **Avoid CNAME chains**.
- **Plan for DNS server failure** (redundancy).

---

## Failure Scenarios

**Scenario 1 — The TTL trap.**
TTL set to 86400s. IP change required. Users on cache for 24 hours. Recovery: educate; lower TTL for future.

**Scenario 2 — The DNS provider outage.**
Single DNS provider; outage; entire infrastructure unreachable. Recovery: multi-provider DNS; redundancy.

**Scenario 3 — The DNSSEC misstep.**
DNSSEC misconfigured; validation fails; some users (with strict validators) can't reach service. Mitigation: monitoring DNSSEC validity.

**Scenario 4 — The CNAME-at-apex.**
Customer wants `example.com` to point to CDN; tries CNAME; some resolvers fail (RFC violation). Use ALIAS record.

**Scenario 5 — The internal DNS cascade.**
Internal services use DNS for service discovery. DNS server fails. Services can't find each other. Cascading outage. Mitigation: client-side DNS caching; multiple DNS servers.

---

## Performance Perspective

- **Cache hit**: microseconds (in browser/OS).
- **Cache miss**: milliseconds (recursive lookup).
- **Cold lookup**: tens to hundreds of milliseconds (full recursive).
- **Anycast**: low (closest server).
- **DoH/DoT**: similar to plain DNS plus TLS overhead.

---

## Scaling Perspective

- **Authoritative server**: handle millions of queries/sec at the largest providers.
- **Recursive resolver**: similar at scale.
- **TTL strategy**: longer TTL = lower query load.
- **Anycast**: scales geographically.

---

## Cross-Domain Connections

- **Caching**: DNS is a cache hierarchy. (See [caching-hierarchy.md](../caching/caching-hierarchy.md).)
- **Load balancing**: DNS-based load balancing. (See [load-balancing-strategies.md](../scalability/load-balancing-strategies.md).)
- **Edge / CDN**: DNS routes to nearest edge. (See [edge-computing-and-cdns.md](../scalability/edge-computing-and-cdns.md).)
- **Failover / DR**: DNS failover patterns. (See [disaster-recovery-and-rto-rpo.md](../system-failures/disaster-recovery-and-rto-rpo.md).)
- **TCP**: DNS lookup precedes every TCP connection. (See [tcp-and-network-fundamentals.md](./tcp-and-network-fundamentals.md).)

The unifying observation: **DNS is the layer everything depends on; its failures cascade through all layers above. The protocols below (UDP, TCP for large responses) and the practices around it (TTL, failover) shape the operational reality of every service on the internet.**

---

## Real Production Scenarios

- **Dyn DNS attack (2016)**: massive DDoS against authoritative DNS provider; took down many sites including Twitter.
- **AWS Route 53**: hyperscale managed DNS.
- **Cloudflare 1.1.1.1**: public DNS resolver.
- **Facebook's BGP/DNS outage (2021)**: multi-hour outage caused partly by DNS unreachability.

---

## What Junior Engineers Usually Miss

- That **caching is everywhere**.
- That **TTL controls propagation speed**.
- That **CNAME chains** can break.
- That **CNAME at apex** is forbidden.
- That **DNS lookups are TCP/UDP** dependencies.
- That **DNSSEC** has adoption gaps.

---

## What Senior Engineers Instinctively Notice

- They **tune TTLs** based on use case.
- They **use multiple DNS providers** for redundancy.
- They **monitor DNS** from multiple points.
- They **lower TTLs ahead of changes**.
- They **avoid CNAME at apex**.
- They **plan for cache propagation**.

---

## Interview Perspective

What gets tested:

1. **"How does DNS work?"** Hierarchical, recursive, cached.
2. **"What's a TTL?"** Cache duration.
3. **"What's anycast?"** Multiple locations sharing IP.
4. **"How does DNS failover work?"** Health check + TTL.
5. **"What's DNSSEC?"** Cryptographic signing.
6. **"DoH vs DoT?"** HTTPS vs TLS for DNS.

Common traps:
- Believing DNS is instant.
- Not knowing about TTL strategies.

---

## 20% Knowledge Giving 80% Understanding

1. **DNS is a cache hierarchy.**
2. **TTLs control propagation**.
3. **Recursive resolvers handle most queries**.
4. **Authoritative servers are source of truth**.
5. **Anycast for scale and resilience**.
6. **GeoDNS for routing**.
7. **CNAME chains** can break.
8. **DNSSEC** for integrity.
9. **DoH/DoT** for privacy.
10. **DNS failures cascade** widely.

---

## Final Mental Model

> **DNS is the most foundational layer most engineers don't think about. It's also the layer that, when it fails, takes down everything. The system is hierarchical, cached, and eventually consistent — and managing those properties (TTLs, redundancy, failover) is core operational discipline.**

The senior engineer respects DNS. They tune TTLs deliberately. They use multiple providers. They monitor from many points. They plan for cache propagation. They know that "DNS is slow to update" is a feature, not a bug.

The teams that hit DNS-induced outages are the ones who didn't think about it. The teams that survived DNS issues with minimal customer impact are the ones who built resilience in. The protocol's age belies its complexity; the operational discipline is real.

That's DNS. That's name resolution at internet scale. That's the layer between a name and an IP — and the layer that touches every connection your services ever make.
