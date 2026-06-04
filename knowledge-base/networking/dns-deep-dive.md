# DNS Deep Dive

> *"DNS is the name resolution system that makes the internet usable. It's also been the cause of more outages than any single piece of infrastructure: 'it's not DNS / there's no way it's DNS / it was DNS' is a meme because the experience is universal. Understanding DNS is understanding the layer everything depends on."*

---

## Topic Overview

DNS (Domain Name System) translates human-friendly names ("example.com") into machine-friendly IP addresses (e.g., "203.0.113.10"). It's a hierarchical, distributed, caching system designed in 1983 and still running. Every browser request, every API call, every email starts with a DNS lookup.

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

## Key Takeaways

- **DNS is a hierarchical, cached, eventually-consistent cache hierarchy.** Root → TLD → second-level → subdomains; each level delegates to the next. Caching happens at every layer (browser, OS, recursive resolver, ISP), and most lookups hit cache — full recursive resolution is rare.
- **Authoritative servers are the source of truth; everything else caches from them.** Recursive resolvers handle the bulk of queries.
- **TTLs control propagation speed — this is the central operational lever.** Long TTL = fewer queries but slow change propagation; short TTL = more queries but fast propagation. Most DNS issues ("why isn't my change taking effect?") are caching issues somewhere in the hierarchy. "DNS is slow to update" is a feature of caching, not a bug.
- **Tune TTLs deliberately by change frequency.** Lower TTLs (60–300s) ahead of planned changes or on records you might fail over; raise them on stable infrastructure to cut query load.
- **Anycast gives scale and resilience** (closest server, automatic network-layer failover, DDoS resistance) and is an alternative to low-TTL DNS failover, which is slow and imperfect because some clients ignore TTLs.
- **GeoDNS routes by location/health**, but caching complicates it: users behind the same resolver get the same answer regardless of their actual location.
- **CNAME chains can break** (resolvers often cap ~5 hops; deep CDN-on-CDN chains hit a 7-hop explosion that some resolvers reject), and **CNAME at the apex is forbidden by RFC** — use ALIAS/ANAME instead.
- **DNS lookups are TCP/UDP dependencies** that precede every connection, so DNS failures cascade through every layer above. Plan for DNS-server failure with redundancy, multiple providers, and client-side caching; a single internal DNS failure can cascade across service discovery.
- **DNSSEC** provides integrity via cryptographic signing but has adoption gaps and can itself cause outages when validation breaks. **DoH/DoT** add privacy (encrypting queries) at the cost of monitoring/filtering visibility.
- **Watch negative-cache pollution**: a freshly deployed service whose "doesn't exist" answer got cached can show errors to some users for hours.
- **Monitor DNS resolution from multiple geographies** (synthetic monitoring), since users behind different resolvers can see different answers.

## Interview angle

- **"How does DNS work?"** Hierarchical, recursive, cached.
- **"What's a TTL?"** Cache duration controlling propagation.
- **"What's anycast?"** Many locations sharing one IP; users reach the closest.
- **"How does DNS failover work?"** Health check + low TTL.
- **"What's DNSSEC?"** Cryptographic signing for integrity.
- **"DoH vs DoT?"** DNS over HTTPS vs DNS over TLS (port 853).
- **Common traps:** believing DNS is instant; not knowing TTL strategies.
