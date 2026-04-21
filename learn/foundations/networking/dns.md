# DNS — The World's Largest Distributed Key-Value Store

> **Prereq**: [IP](ip.md), [TCP/UDP](tcp-udp.md)
> **What you will understand by the end**: what happens in the exact moment between typing `google.com` and the first packet leaving your laptop for Google's servers. And why DNS is, surprisingly, one of the most interesting distributed systems in existence.

---

## A. Intuition First

### The analogy
DNS is the phonebook of the internet. You know a human name (`google.com`), DNS tells you the phone number (`142.250.72.206`).

But it's not *one* phonebook. It's a globally-distributed, hierarchical, heavily-cached system where **nobody has the full list** and the list constantly changes.

### Why it *had* to exist

Early ARPANET had a single file, `HOSTS.TXT`, distributed from SRI every day or so. It mapped every hostname to an IP. This worked when the internet had 200 machines.

By 1983 this was already breaking. Paul Mockapetris proposed DNS as:
- **Distributed** — nobody owns the full list.
- **Hierarchical** — organized as a tree so authority can be delegated (`.com` admins don't need to know about `google.com`'s subdomains).
- **Cached** — because the same lookups happen billions of times a day.
- **Fault-tolerant** — multiple servers at every level.

DNS is arguably the most successful distributed system in history.

---

## B. Mental Model

### The hierarchy (read right-to-left)

Take `mail.google.com.`

- `.` (root) — the implied trailing dot; the root of the tree.
- `com` — top-level domain (TLD).
- `google` — second-level domain.
- `mail` — subdomain.

Each level delegates authority to the next. The root operators don't know what's in `.com`; they just know "ask the `.com` TLD servers". The `.com` servers don't know `mail.google.com`; they just know "ask Google's authoritative nameservers".

### The four kinds of DNS server

| Server | Role |
|---|---|
| **Recursive resolver** | The server your machine asks. It does all the legwork. Usually run by your ISP or `1.1.1.1` / `8.8.8.8`. |
| **Root nameserver** | 13 logical servers (hundreds of physical, via anycast). Know only "which TLD server owns this extension." |
| **TLD nameserver** | One set per TLD (`.com`, `.org`, `.uk`). Know which authoritative nameserver owns a given domain. |
| **Authoritative nameserver** | The actual source of truth for a domain. Returns the final answer (A/AAAA/CNAME/etc.). |

### Record types you must know

| Record | What it holds |
|---|---|
| **A** | Domain → IPv4 |
| **AAAA** | Domain → IPv6 |
| **CNAME** | Domain → another domain (alias). Triggers a second lookup. |
| **MX** | Mail server for this domain |
| **TXT** | Arbitrary text (used for SPF, DKIM, domain verification) |
| **NS** | Which nameserver is authoritative for this zone |
| **SOA** | Metadata about a zone (serial, TTLs) |
| **PTR** | IP → domain (reverse lookup) |
| **SRV** | Service discovery (hostname + port for a named service) |

---

## C. Internal Working — Step by Step

### Full lookup: `example.com` from a cold cache

```
Your Laptop → Recursive Resolver → Root → TLD → Authoritative → back
```

1. **Browser** needs IP for `example.com`. Asks the OS stub resolver.
2. **OS stub resolver** checks its cache. Miss. Sends UDP query to the configured recursive resolver (e.g., `1.1.1.1`, port 53).
3. **Recursive resolver** checks *its* cache. Miss. Begins the hunt:
4. → Sends query to a **root server** (it has the root server list baked in).
5. Root server replies: "I don't know `example.com`, but the `.com` TLD is at `a.gtld-servers.net` et al."
6. → Recursive resolver queries **TLD server** for `.com`.
7. TLD server replies: "`example.com` is authoritatively served by `ns1.example.com` at IP `X.X.X.X`."
8. → Recursive resolver queries the **authoritative server**.
9. Authoritative replies: "`example.com` A record = `93.184.216.34`, TTL=3600."
10. Recursive resolver **caches** the answer (for up to 3600 seconds) and returns it to your OS.
11. OS caches it too, returns to the browser.
12. Browser opens TCP to `93.184.216.34:443`.

**Most of the time, you skip steps 4–9** because some resolver in the chain has a cached answer. That's why DNS feels fast (typically <10 ms) even though the underlying protocol is recursive across continents.

> **🧠 What if DNS caching didn't exist?** Every single page load would trigger 4 round-trips across continents just to resolve the hostname. Google's 8.8.8.8 would collapse within minutes. **Caching is not an optimization — it's the protocol's survival condition.**

### Why caches make this scale
- A TTL of 3600 seconds means: one fetch per hour per resolver for that record.
- Millions of users behind the same ISP resolver → they all share one cache entry.
- This is why DNS infrastructure can serve **trillions of queries per day** with surprisingly modest hardware.

### The cache hierarchy you never think about
Your browser has a DNS cache. The OS has one. The resolver has one. Each might disagree on TTLs. A common debugging confusion: you updated a DNS record, but a stale cache somewhere is still serving the old IP. You run `dig @8.8.8.8 example.com` and it's fresh, but your browser still shows the old page.

### 🧱 What each DNS server *knows* and *doesn't know*

| Server | ✅ Knows | ❌ Does NOT know |
|---|---|---|
| Root | Which TLD server owns `.com`, `.org`, `.in`, etc. | Anything about `google.com` or `example.com` |
| TLD (`.com`) | Which authoritative NS owns `google.com` | The actual A record (IP) for `google.com` |
| Authoritative | A, AAAA, CNAME, MX for domains it owns | Anything about other domains |
| Recursive resolver | Cached answers + root hints | Any domain not yet cached — must recurse |

This separation is the entire reason DNS scales. If every root server had to know every domain's IP, root would collapse.

> **🔎 Quick Check** — In 10 seconds: when you `dig google.com`, which of these 4 servers does your laptop talk to first?
> **🎯 Recall** — You talk to the recursive resolver; it talks to root/TLD/authoritative on your behalf.

### What does `dig` actually send? (packet level)
```
$ dig +trace example.com A
```
- Sends a UDP query to port 53 on the resolver.
- Query payload: DNS header (ID, flags) + question section ("example.com, type A, class IN").
- Response: DNS header (same ID, response flag) + answer section with the A record(s) + authority + additional sections.
- UDP because the question + answer usually fits in a single 512-byte packet.
- **Falls back to TCP** if the response would exceed 512 bytes (large zone transfers, DNSSEC responses).

---

## D. Visual Representation

```
        ┌──────────────────────────────────────────────┐
        │           your browser                        │
        └──────────────┬───────────────────────────────┘
                       │ "need IP for example.com"
                       ▼
        ┌──────────────────────────────────────────────┐
        │   OS stub resolver (cache miss)               │
        └──────────────┬───────────────────────────────┘
                       │ UDP :53
                       ▼
        ┌──────────────────────────────────────────────┐
        │   Recursive Resolver (1.1.1.1)                │
        │   - cache miss → recurse                      │
        └─┬────────────┬──────────────┬────────────────┘
          │1           │2              │3
          ▼            ▼              ▼
      [Root ns]    [.com TLD ns]   [example.com  ]
      "ask .com"   "ask ns1.       "A 93.184.216.34"
                    example.com"    ← final answer
```

---

## E. Tradeoffs

### Why DNS uses UDP (mostly)
- Tiny payload (question + answer ~100 bytes). TCP's handshake would triple latency.
- DNS retries are cheap — the client just asks again.
- Consequence: DNS queries can be **spoofed**. You send a query to your resolver; an attacker on-path can race a forged response back. This is why **DNSSEC** and **DNS over HTTPS (DoH) / DNS over TLS (DoT)** exist.

### Caching wins but creates stale reads
- TTL is a tradeoff: long TTL = fast, low load, but slow to propagate changes (updating a DNS record can take hours in the worst case).
- Before an expected IP change (migration), you typically lower TTL to 60s for a day before the cutover.

### Single point of failure?
- No — the root and TLD servers are replicated massively via anycast. Cloudflare, Google, AWS all run highly-redundant recursive resolvers.
- But: your specific authoritative nameserver *is* a SPOF for your domain. If `ns1.example.com` dies, your domain becomes unreachable (caches expire, nobody can resolve). That's why you always set up multiple nameservers (Route 53 defaults to 4).

### DNS failure modes
- Authoritative down → domain unreachable for new clients once caches expire.
- Resolver down → all your local clients lose internet until they switch resolver.
- Cache poisoning → attacker injects wrong answer; DNSSEC / DoT are the defenses.

---

## F. Interview Lens

### Classic DNS questions
- "What happens when you type `google.com` in the browser?" — the all-time classic. DNS is step 2 (after parsing URL).
- "Walk me through a DNS lookup in detail." — recite the 11-step flow above.
- "Why does DNS use UDP?" — see above.
- "What's the difference between recursive and iterative query?" — recursive: "give me the answer, even if you have to chase it". Iterative: "give me the best answer you have, and if it's a referral I'll do the next hop myself." Recursive resolvers accept recursive queries from clients and issue iterative queries upstream.
- "What's a CNAME, and what's the cost?" — alias; a CNAME lookup costs an extra round trip to resolve the aliased name. Avoid at the apex (there's a reason, called "CNAME at the apex" problem).

### DNS in system design
When designing any global system, DNS is your **first layer of routing and failover**:
- **DNS load balancing** — give different users different IPs (round-robin, weighted, geo-proximity).
- **GeoDNS** — resolve to the nearest PoP. Netflix, Google, Cloudflare all do this.
- **Failover** — health check backend; if it fails, swap the A record.

Catch: DNS failover is slow (minutes) because of TTL. For fast failover, use an anycast IP + BGP withdrawal, not DNS.

### Pitfalls
- Thinking DNS always uses UDP. It uses TCP for large responses and zone transfers.
- Confusing "DNS load balancing" with L4 / L7 load balancers. DNS LB is dumb — it doesn't know if a target is healthy in real time.
- Forgetting caching: all your DNS-level decisions propagate on TTL boundaries, not instantly.

### Depth by level
- **Junior**: knows DNS maps names to IPs; knows about A, CNAME.
- **Mid**: walks the recursion, knows record types, explains TTL.
- **Senior**: understands DNS as a distributed system; can design a geo-routing DNS system; knows the limits of DNS failover.

---

## G. Real-World Mapping

- **Route 53 (AWS)**, **Cloudflare DNS**, **Google Cloud DNS** — managed authoritative + recursive services.
- **Netflix / Amazon.com** use geo-DNS to route users to the nearest region.
- **Kubernetes `CoreDNS`** — internal DNS for service discovery inside a cluster. `my-service.default.svc.cluster.local` is resolved by CoreDNS to the service's ClusterIP.
- **CDN routing** — many CDNs use CNAME (`yourapp.com` → CNAME `d1234.cloudfront.net`) so the CDN's own DNS can do the fine-grained routing.

---

## H. Questions

### Beginner
1. Why do we need DNS? Why not just use IPs?
2. What's the difference between an A record and a CNAME?
3. What does TTL mean in DNS?

### Intermediate
1. Walk me through a DNS lookup step by step.
2. Why does DNS use UDP, and when does it switch to TCP?
3. What's the difference between a recursive and an iterative query?
4. If I update my A record, why do some users still hit the old server?
5. What happens if my authoritative nameserver dies?

### Advanced (interview)
1. Design a DNS-based global load balancer for a service with PoPs in 10 regions. How do you route users? How do you handle a regional outage?
2. Explain DNS cache poisoning and how DNSSEC prevents it.
3. Why can't you CNAME at the zone apex (e.g., `example.com` CNAMED to something)? What do cloud providers use instead?
4. At 1M QPS of DNS, where's the bottleneck in a naive recursive resolver? How would you scale it?
5. Compare DNS-based failover vs anycast-based failover. When would you choose each?

---

## I. Mini Design Problem — "Build a DNS resolver"

### Requirements
- Handle 100k queries/sec.
- Serve from cache when possible; recurse when needed.
- <10 ms p99 latency on cache hits.

### Sketched solution
1. **Frontend**: UDP listener on port 53, multi-threaded / async (Go, Rust, or a custom kernel-bypass stack like DPDK at the extreme).
2. **Cache**: in-memory LRU keyed by `(name, type)` → `(answer, TTL_expires_at)`. Use a concurrent hashmap with per-bucket locks.
3. **Cache miss path**: issue upstream query; use **query deduplication** — if 10k clients ask for `google.com` at once (cache cold), send *one* upstream query and fan out the single answer. This is called the "thundering herd" fix.
4. **Negative caching**: cache NXDOMAIN answers too, honoring TTL in the SOA record.
5. **Failover**: if authoritative is slow, have a list of backup roots; retry with exponential backoff.
6. **Observability**: metrics per zone, per record type, per cache hit/miss.

A real resolver (Unbound, Knot, Bind) looks exactly like this.

---

## J. Cross-Topic Connections
- **[IP](ip.md)** — DNS returns IPs.
- **[TCP/UDP](tcp-udp.md)** — DNS protocol choice.
- **[CDN](../scaling/cdn.md)** — CDNs use DNS (or anycast) to route to the nearest edge.
- **[Load Balancing](../scaling/load-balancing.md)** — DNS-level LB is one form.
- **[Service Discovery](../../reliability/service-discovery.md)** — DNS-based service discovery (Consul, k8s).
- **[Caching](../scaling/caching.md)** — DNS *is* a caching system.

---

## K. Confidence Checklist
- [ ] I can draw the 4-level DNS hierarchy (root / TLD / authoritative / resolver).
- [ ] I can walk through a lookup in detail with cache behavior.
- [ ] I know A vs AAAA vs CNAME vs MX vs TXT.
- [ ] I understand why DNS uses UDP and when it falls back to TCP.
- [ ] I can discuss TTL tradeoffs and DNS-based failover.

### Red flags
- ❌ Thinking DNS "is a server" rather than a protocol + distributed system.
- ❌ Can't explain why a recently-changed record still serves stale data.
- ❌ Confusing authoritative with recursive.

---

## L. Potential Gaps & Improvements
- **DNSSEC** mechanism (signed records, chain of trust) is skipped — it deserves its own section.
- **DoH / DoT** (DNS over HTTPS / TLS) — the privacy frontier, relevant for modern interviews.
- **Anycast DNS** — explained briefly in IP, deserves more here.
- No worked example with `dig +trace` output, which is a teaching goldmine.
- EDNS0 (extended DNS) and the 512-byte → 4096-byte jump — missing.

**How to close:** run `dig +trace google.com` and read every line. You'll see the actual recursion happen in real time.

---

### 🧭 Guided Deep-Learning Layer

#### 🔐 Gap 1 — DNSSEC
- 🔹 **What it is**: Cryptographic signatures on DNS records so resolvers can verify answers weren't tampered with in flight.
- 🔹 **Why it matters**: Without it, an on-path attacker can forge DNS replies (poisoning) → redirect users to malicious sites. Governments have done this.
- 🔹 **Connection**: The "attacker races a forged response" scenario mentioned in this file is exactly what DNSSEC prevents via chain-of-trust from the root.
- 🔹 **When needed**: 🟡 **Useful for mid-level security interviews**, 🔴 **Important for infra-security roles**.
- 🔹 **Intuition**: Like a tamper-evident seal on every DNS answer. The root publishes a signing key; each TLD's key is signed by root; each zone's key by its TLD. Any broken link = reject.
- 🔹 **If you go deeper**: Read the chain-of-trust (root → TLD → domain), the DS + DNSKEY records, why adoption has been slow (operational complexity + key rollover pain).
- 🔹 **Interview hook**: *"How do you prevent DNS spoofing?"* → DNSSEC for integrity + DoH/DoT for privacy.

---

#### 🕵️ Gap 2 — DoH / DoT (DNS over HTTPS / TLS)
- 🔹 **What it is**: DNS queries tunneled over TLS (DoT, port 853) or HTTPS (DoH, port 443) so ISPs and on-path observers can't see your lookups.
- 🔹 **Why it matters**: Modern browsers (Firefox, Chrome) default to DoH. This breaks ISP-level DNS-based content blocking and logging. Big privacy + geopolitics issue.
- 🔹 **Connection**: UDP-based DNS is observable on the wire. DoH/DoT hides the query content; only the resolver sees what you asked.
- 🔹 **When needed**: 🟡 **Useful for security/privacy interviews**, 🟢 curiosity otherwise.
- 🔹 **Intuition**: Traditional DNS = sending a postcard (anyone en route reads it). DoH = sending in a sealed envelope.
- 🔹 **If you go deeper**: Why DoH (port 443) is politically controversial — indistinguishable from normal HTTPS, can't be blocked without blocking all web traffic. Contrast with DoT (port 853, easier to block).
- 🔹 **Interview hook**: *"Why is DoH using port 443 rather than 853 like DoT?"* → Unblockable via firewall without collateral damage; political + privacy reasons.

---

#### 🌐 Gap 3 — Anycast DNS
- 🔹 **What it is**: Announcing the *same* DNS server IP from many geographic locations via BGP; packets route to the nearest.
- 🔹 **Why it matters**: It's how `8.8.8.8`, `1.1.1.1`, and the 13 DNS root servers serve billions of queries per day from hundreds of physical machines — all sharing one IP.
- 🔹 **Connection**: The "13 root servers, hundreds of physical machines" remark in this file works because of anycast.
- 🔹 **When needed**: 🔴 **Important for senior CDN / infra interviews**, 🟡 useful at mid-level.
- 🔹 **Intuition**: One phone number that rings in the nearest call center. Callers never notice; the center they reach depends on geography.
- 🔹 **If you go deeper**: Understand anycast is a routing property (via BGP), not a DNS property. Applies to any protocol — Cloudflare uses it for HTTP, DNS, and more.
- 🔹 **Interview hook**: *"How does `1.1.1.1` respond to queries from Tokyo within 10ms?"* → Anycast BGP announcement from a Tokyo PoP.

---

#### 🔬 Gap 4 — Worked `dig +trace` Example
- 🔹 **What it is**: Running `dig +trace example.com` shows the real recursion hop by hop — root → TLD → authoritative — with timing.
- 🔹 **Why it matters**: The abstract diagram in this file becomes concrete bytes. You can't un-see how DNS actually works.
- 🔹 **Connection**: Directly validates the 11-step flow described above.
- 🔹 **When needed**: 🟢 **Optional but high-value practice**. Do it once.
- 🔹 **Intuition**: It's the difference between reading about a recipe and watching it cooked on camera.
- 🔹 **If you go deeper**: Run it for a domain with a CNAME chain — you'll see the extra hop. Run for a CDN-hosted domain — you'll see the CDN's nameservers taking over.
- 🔹 **Interview hook**: Sets you up for *"walk me through a DNS lookup"* with lived experience, not memorization.

---

#### 📏 Gap 5 — EDNS0 and the 512 → 4096 Byte Jump
- 🔹 **What it is**: Original DNS limited UDP responses to 512 bytes. EDNS0 (extension) allows 4096 bytes. Beyond 4096 → falls back to TCP.
- 🔹 **Why it matters**: DNSSEC and large response sets (AAAA + many A records) exceed 512 bytes. Without EDNS0, everything falls to TCP → slow.
- 🔹 **Connection**: The "UDP unless response is large" note in this file depends on EDNS0. Without it, DNSSEC is impractical.
- 🔹 **When needed**: 🟢 **Mostly trivia**. Useful for understanding why DNSSEC adoption needed protocol changes.
- 🔹 **Intuition**: DNS had a tiny envelope size by default; EDNS0 is a standardized larger envelope, negotiated between client and server.
- 🔹 **If you go deeper**: Read the EDNS0 options field — it's also how DNS cookies (anti-spoofing) and client subnet (CDN geo-routing) are carried.
- 🔹 **Interview hook**: Rarely direct, but comes up if *"why did DNSSEC take so long to adopt?"* → partially because legacy middleboxes dropped EDNS0 responses.

---

### 🏆 Start here if you have limited time

1. **Anycast DNS** — lets you explain how big resolvers scale; senior interview gold.
2. **DNSSEC** — security angle, comes up on any role touching auth or public DNS.

Skip EDNS0 trivia, run `dig +trace` once as practice.

---

### 🧭 Suggested Deep Dive Order

1. **Run `dig +trace` live** (~10 min; immediate intuition boost).
2. **Anycast DNS** (~1h; senior interview payoff).
3. **DNSSEC** (~1–2h; security-critical).
4. **DoH / DoT** (~45 min; modern privacy landscape).
5. **EDNS0** (~30 min; trivia with occasional relevance).
