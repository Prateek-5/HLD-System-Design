# ⚡ 04 · Confusion Resolver — Deep Conceptual Traps in `learn/`

> Companion to `notes/04_confusion_resolver.md`. This one is **deeper and more conceptual** — traps specific to the layered curriculum where depth of understanding matters more than one-liners.
>
> Use this **before an interview** to avoid misconceptions. Use **during study** whenever something feels subtly off.

---

## 🧭 Networking Foundations

### ❗ "An IP address identifies a device"
✅ **Clarification**: It identifies a **network interface**. A laptop with WiFi + Ethernet has two IPs. A server with 4 NICs has four. "Device" and "IP" are not 1:1.
- 📍 [`foundations/networking/ip.md`](foundations/networking/ip.md)

### ❗ "Routers maintain a table of every IP on the internet"
✅ **Clarification**: They hold **prefixes** (CIDR blocks), not individual IPs. Longest-prefix matching means a router storing ~900k prefixes can route packets to 4B+ individual addresses. This is literally how the internet scales.
- 📍 [`foundations/networking/ip.md`](foundations/networking/ip.md) § Longest-prefix matching

### ❗ "NAT just changes the source IP"
✅ **Clarification**: NAT changes **source IP AND source port** (officially "PAT" — Port Address Translation). The port rewrite is the trick that lets thousands of clients share one public IP without collision. Without port rewriting, the return traffic can't be disambiguated.
- 📍 [`foundations/networking/ip.md`](foundations/networking/ip.md) § NAT return-path

### ❗ "CIDR `/24` = 256 usable hosts"
✅ **Clarification**: `/24` = 256 addresses, but **254 usable**. The first (`.0`) is the network identifier; the last (`.255`) is broadcast. Off-by-two is a classic interview gotcha.

### ❗ "Ports are physical things"
✅ **Clarification**: Ports are **16-bit numbers** the OS uses to route packets to processes. Nothing physical about them. A single network card serves 65k+ ports.

### ❗ "HTTPS encrypts everything including the hostname"
✅ **Clarification**: TLS encrypts the HTTP payload and most headers. The **SNI** (Server Name Indication) — the hostname — is sent in the clear during handshake so the server knows which cert to present. ESNI/ECH is the emerging fix.

### ❗ "TCP guarantees delivery"
✅ **Clarification**: TCP guarantees **reliable, in-order delivery across an established connection**. If the connection breaks (other side crashes, network partitions unreachably), data after the break is lost — TCP cannot work miracles against network failures.

### ❗ "UDP is unreliable"
✅ **Clarification**: UDP provides **no reliability guarantees**. It's not "broken" — it's intentionally minimal. Applications add reliability on top when needed (QUIC, DTLS, RTP).

### ❗ "HTTP/2 is always faster than HTTP/1.1"
✅ **Clarification**: HTTP/2 multiplexes over one TCP connection, but a lost packet head-of-line-blocks all streams. On lossy mobile/wifi, HTTP/1.1 with 6 parallel connections can be *faster*. HTTP/3 (QUIC) properly fixes this.
- 📍 [`foundations/networking/tcp-udp.md`](foundations/networking/tcp-udp.md) § HOL blocking

### ❗ "DNS is a server"
✅ **Clarification**: DNS is a **distributed protocol** running on a hierarchy of servers (root → TLD → authoritative), plus the recursive resolvers that actually do the work for clients. "The DNS" is one of the largest distributed systems in existence.
- 📍 [`foundations/networking/dns.md`](foundations/networking/dns.md)

### ❗ "DNS failover is fast"
✅ **Clarification**: DNS failover takes **minutes** because of TTL caching at resolvers, OSes, and browsers. For fast failover (seconds), use **anycast** + BGP withdrawal or LB-level health checks, not DNS.

### ❗ "Forward proxy and reverse proxy do different things"
✅ **Clarification**: Both forward traffic between client and server. The difference is **which side is hidden**: forward proxy hides clients from servers; reverse proxy hides servers from clients. Same mechanism, opposite direction.
- 📍 [`foundations/networking/proxy.md`](foundations/networking/proxy.md)

### ❗ "OSI layers are rigid and strictly followed"
✅ **Clarification**: Modern protocols bend the model. TLS spans L5/L6. QUIC integrates L4 + encryption. HTTP/3 runs HTTP (L7) over QUIC (L4-ish) over UDP. OSI is a **vocabulary**, not a prescription.
- 📍 [`foundations/networking/osi.md`](foundations/networking/osi.md)

---

## 🧭 Scaling & Availability

### ❗ "L4 vs L7 is a performance choice"
✅ **Clarification**: It's a **capability** choice first, performance second. L4 literally cannot see URL paths or HTTP headers — it's an architectural limit, not a tuning knob.
- 📍 [`foundations/scaling/load-balancing.md`](foundations/scaling/load-balancing.md) § L4 vs L7 table

### ❗ "Sticky sessions = good load balancing"
✅ **Clarification**: Sticky sessions **break horizontal scaling**. They imply state in memory on a specific backend. On failover, those users lose their session. The proper fix: externalize state to Redis / JWT / DB.

### ❗ "LB health check passing = backend healthy"
✅ **Clarification**: Only if the check is **deep enough**. A `/healthz` that returns 200 unconditionally doesn't exercise DB connections, cache, or dependencies. Shallow health checks mask real failures.

### ❗ "Caching is always a performance win"
✅ **Clarification**: Caching is wrong when (1) access has low repetition, (2) data changes fast, (3) cache access is as slow as source. Caching adds invalidation complexity — sometimes that outweighs the speed gain.
- 📍 [`foundations/scaling/caching.md`](foundations/scaling/caching.md) § When NOT to cache

### ❗ "Cache-aside = write-around"
✅ **Clarification**: Different axes. **Cache-aside** describes read path (app checks cache, on miss fetches source). **Write-around** describes write path (skip cache). You can combine: cache-aside reads + write-around writes is a common pair.

### ❗ "High cache hit rate is sufficient"
✅ **Clarification**: 99% hit rate can still kill the DB if the 1% miss path clusters on hot keys that expire together. Monitor **absolute miss QPS and p99 miss latency**, not just hit rate.

### ❗ "A cache miss just means reading from DB"
✅ **Clarification**: At scale, a cache miss on a hot key can trigger a **thundering herd** — 1000 concurrent requests all miss → 1000 concurrent DB queries. Request coalescing + TTL jitter are mandatory, not optional.
- 📍 [`foundations/scaling/caching.md`](foundations/scaling/caching.md) § Stampede

### ❗ "5 nines = always up"
✅ **Clarification**: 99.999% = ~5 min downtime/year. It's not "always up" — it's "barely any downtime". Each additional nine costs ~10× engineering investment (redundancy, automation, ops maturity).

### ❗ "Redundancy multiplies availability"
✅ **Clarification**: **Parallel redundancy** multiplies (good). **Series dependencies** degrade. A 99.9% service behind a 99.9% LB in series = 99.8% total. Every added series dependency drops your number.
- 📍 [`foundations/scaling/availability.md`](foundations/scaling/availability.md) § Series vs parallel

### ❗ "Horizontal scaling is always better than vertical"
✅ **Clarification**: Depends on state. Stateless tier → horizontal trivially. Stateful tier (SQL DB) → vertical first (simpler), then replicas, then shard (painful). Don't shard before you need to.

### ❗ "A cluster is a group of servers behind an LB"
✅ **Clarification**: That's a **load-balanced fleet**. A **cluster** has the nodes **coordinating with each other** — gossip, consensus, membership, replication. Cassandra ring = cluster. 10 Nginx boxes behind an LB = just a fleet.
- 📍 [`foundations/scaling/clustering.md`](foundations/scaling/clustering.md)

### ❗ "CDN handles dynamic content fine"
✅ **Clarification**: CDN shines on cacheable content keyed by URL. Per-user dynamic content needs **edge compute** (Cloudflare Workers, Lambda@Edge) to collapse origin round-trips. Personalized dashboards = not a CDN win out of the box.

---

## 🧭 Data Layer

### ❗ "NoSQL = no ACID"
✅ **Clarification**: Outdated. MongoDB 4.0+, DynamoDB, Cassandra (LWT), Spanner/CockroachDB all offer ACID with caveats. Treat ACID-ness as a per-operation capability, not a per-database label.

### ❗ "SQL scales badly"
✅ **Clarification**: SQL **vertical-scales superbly**. It just horizontal-scales with friction (shared-nothing SQL is hard). Single-node Postgres on modern hardware handles tens of thousands of QPS. Most orgs never need to shard.

### ❗ "MVCC means readers never block"
✅ **Clarification**: Correct for **readers vs writers**. But **writers vs writers** still conflict on the same row. MVCC eliminates reader-writer blocking only.
- 📍 [`data/sql-databases.md`](data/sql-databases.md) § MVCC

### ❗ "Index = faster everything"
✅ **Clarification**: Each index slows every write on its columns (must update index). 10 indexes = 10× write amplification. Indexes also consume RAM + disk. Over-indexing is a real anti-pattern.
- 📍 [`data/indexes.md`](data/indexes.md)

### ❗ "Composite index on `(a,b,c)` helps queries on `b`"
✅ **Clarification**: **No.** Left-most prefix rule: `(a,b,c)` helps queries filtering by `a`, `(a,b)`, or `(a,b,c)` only. A query with only `WHERE b=?` does NOT use this index.

### ❗ "Primary-replica async = safe because replicas catch up"
✅ **Clarification**: On primary crash, any ack'd writes not yet shipped to replicas are **lost**. Safety depends on the workload's tolerance: bank ledger ≠ Twitter feed.
- 📍 [`data/database-replication.md`](data/database-replication.md)

### ❗ "Replication lag is fine; replicas eventually catch up"
✅ **Clarification**: "Eventually" can mean seconds or *minutes* under load. During lag:
- Read-after-write anomalies (user doesn't see own post).
- Failover loses data (async).
- Analytics reports wrong numbers.

### ❗ "Sharding solves scaling"
✅ **Clarification**: Sharding adds an **ecosystem** of concerns: shard key design, query routing, cross-shard joins (hard), cross-shard tx (sagas), rebalancing, hot shards, per-shard backups. One decision doesn't solve scaling — it introduces many.
- 📍 [`data/sharding.md`](data/sharding.md)

### ❗ "Consistent hashing fixes hot keys"
✅ **Clarification**: It fixes **hot shards under node churn** (adds/removes only move 1/N keys). It does NOT fix **a single key with 100× the traffic of others** — that still lands on one shard. Separate mitigation: replicate hot keys, salt, two-tier cache.

### ❗ "ACID solves cross-service consistency"
✅ **Clarification**: ACID applies **within one DB**. It does not extend across services or DBs. For cross-service atomicity: sagas + compensations + idempotency.

### ❗ "CAP says pick 2 of 3"
✅ **Clarification**: P is mandatory (partitions will happen on any real network). During partition, pick **C** (reject) or **A** (serve stale). "CA" only makes sense on a single node.
- 📍 [`data/cap-theorem.md`](data/cap-theorem.md) § Concrete partition scenario

### ❗ "Eventual consistency = stale for N seconds then consistent"
✅ **Clarification**: "Eventually" has no upper bound. Under a persistent partition, replicas can diverge for hours. Real systems add SLAs on top ("99% of reads within 100ms of write") — that's a different guarantee.

### ❗ "Serializable = Linearizable"
✅ **Clarification**: **Linearizable** = operations look atomic w.r.t. a global clock. **Serializable** = transactions look as if run one-at-a-time. You can have one without the other. Both together = the strictest model, most expensive.

### ❗ "2PC works; people just misunderstand it"
✅ **Clarification**: 2PC is mathematically sound, but operationally **blocking on coordinator crash**. Participants sit in "prepared" state holding locks indefinitely. In microservices at scale, this is a ticking bomb.
- 📍 [`data/distributed-transactions.md`](data/distributed-transactions.md)

### ❗ "Sagas = 2PC without the coordinator"
✅ **Clarification**: Fundamentally different. Sagas have **no isolation** — other transactions see intermediate states. 2PC is atomic across the full transaction. Sagas trade isolation for liveness.

### ❗ "Compensation = rollback"
✅ **Clarification**: Rollback silently undoes. **Compensation is a new forward action** — you can't un-charge a card, you issue a refund. Model business semantics, not technical undo.

---

## 🧭 Architecture

### ❗ "Microservices = scales better"
✅ **Clarification**: Microservices scale **team velocity and fault domains**, not QPS per se. A well-tuned monolith on modern hardware handles massive load. Split when **team coordination** becomes the bottleneck.
- 📍 [`architecture/monolith-vs-microservices.md`](architecture/monolith-vs-microservices.md)

### ❗ "Microservices = small services"
✅ **Clarification**: It's about **independent deployability + team ownership**, not line count. A "microservice" with 100k LOC owned by one team is fine if it deploys independently.

### ❗ "Shared DB is OK between microservices"
✅ **Clarification**: Biggest anti-pattern. Tight schema coupling. Coordinated deploy required for schema changes. No independent evolution. **Each service owns its data.** Sync to analytics via CDC.

### ❗ "Distributed monolith = a nuanced microservice architecture"
✅ **Clarification**: No — it's an **anti-pattern**. Many services that deploy together, share DBs, or have synchronous call chains = worst of both worlds. You pay microservice complexity without getting microservice benefits.

### ❗ "Event-driven architecture = fire-and-forget"
✅ **Clarification**: EDA requires **schema discipline** (schema registry), **idempotent consumers**, **distributed tracing**, and often a workflow engine for long-lived flows. "Just publish events" without these = event chaos.
- 📍 [`architecture/event-driven-architecture.md`](architecture/event-driven-architecture.md)

### ❗ "Event sourcing is the future"
✅ **Clarification**: ES is right for domains where the **history of changes** is the valuable data (finance ledgers, audit-heavy regulated industries). For CRUD apps, it's over-engineering that adds schema-evolution pain.
- 📍 [`architecture/event-sourcing.md`](architecture/event-sourcing.md)

### ❗ "CQRS should be applied everywhere"
✅ **Clarification**: CQRS pays off when read and write patterns are wildly different and justify two schemas. For a simple CRUD app, one well-indexed table beats CQRS complexity.

### ❗ "API Gateway = load balancer"
✅ **Clarification**: Gateway = LB + **app-aware concerns** (auth, rate limit, routing, aggregation). LB = traffic distribution. They overlap but aren't identical. Most real architectures run both (LB before gateway).
- 📍 [`architecture/api-gateway.md`](architecture/api-gateway.md)

### ❗ "GraphQL is always better for mobile"
✅ **Clarification**: GraphQL saves round trips for heterogeneous mobile clients. Costs: harder caching at CDN (every query is unique), N+1 queries, harder rate limiting per endpoint, schema governance. Mobile with limited queries → REST may win.

### ❗ "WebSocket is the right choice for real-time"
✅ **Clarification**: Only if you need **bi-directional**. For server-push only (notifications, feed updates), **SSE** is simpler, auto-reconnects, HTTP-native, works through more proxies.
- 📍 [`architecture/long-polling-websockets-sse.md`](architecture/long-polling-websockets-sse.md)

---

## 🧭 Reliability & Security

### ❗ "Retry + timeout = resilient"
✅ **Clarification**: Naive retries **amplify outages**. You need timeout + exponential backoff + jitter + retry budget + circuit breaker + idempotency keys. Each is necessary; none is sufficient alone.
- 📍 [`reliability/circuit-breaker.md`](reliability/circuit-breaker.md) § Retry storm

### ❗ "Exponential backoff fixes retry storms"
✅ **Clarification**: Only **with jitter**. Without jitter, 1000 clients synchronize their retries at identical intervals → load oscillates between spiky and quiet → recovering service flaps. Jitter spreads retries in time.

### ❗ "Circuit breaker prevents all cascading failures"
✅ **Clarification**: It protects **you** from a sick downstream. It doesn't help if **you** are the slow one. For that you need load shedding, backpressure, and **bulkheads** (isolated thread pools per dependency).

### ❗ "Rate limit by IP is fair"
✅ **Clarification**: Shared NAT (offices, mobile carriers) makes thousands of users look like one. You punish legitimate users and miss distributed attackers. Default: **auth first, then limit per user**.

### ❗ "Service discovery via DNS is enough"
✅ **Clarification**: DNS-based service discovery has TTL-bound staleness (seconds). For fast membership changes (pod rolls in k8s), you need the k8s API or a sidecar with realtime updates.

### ❗ "99.999% availability is achievable with redundancy"
✅ **Clarification**: 5 nines needs redundancy + **automation + ops maturity + chaos testing + game days**. Without the latter, redundant systems just give you more things to break simultaneously.

### ❗ "SLA = SLO"
✅ **Clarification**: **SLO** is internal target (stricter). **SLA** is external contract with financial consequences. SLOs should have buffer so you don't owe refunds on every blip.
- 📍 [`reliability/sla-slo-sli.md`](reliability/sla-slo-sli.md)

### ❗ "Backups = recovery plan"
✅ **Clarification**: An **untested backup is not a backup**. Restore tested monthly or the backup is fiction. Same for DR: if you haven't done a game-day failover, your RTO is hope, not a number.

### ❗ "OAuth authenticates users"
✅ **Clarification**: OAuth is for **authorization** (delegated access). **OIDC** is the authentication layer on top of OAuth. "Sign in with Google" = OIDC, which uses OAuth internally.
- 📍 [`reliability/oauth-oidc.md`](reliability/oauth-oidc.md)

### ❗ "TLS is end-to-end in my system"
✅ **Clarification**: In most real deployments, TLS terminates at the LB/reverse proxy; backends speak plaintext HTTP inside a trusted network (or mTLS for zero-trust). True end-to-end needs TLS passthrough mode.

### ❗ "Containers are lightweight VMs"
✅ **Clarification**: Containers share the **host kernel**. A kernel exploit escapes the container boundary. For untrusted multi-tenant workloads: **microVMs** (Firecracker) or full VMs.

---

## 🧭 Case Study Specific

### ❗ "Twitter uses push fan-out for all users"
✅ **Clarification**: Only for normal users. For celebrities (>10k followers), pure push = melt the write pipeline. Twitter uses **hybrid**: push for normal, pull for celebs, merge at read time.
- 📍 [`interview-systems/twitter.md`](interview-systems/twitter.md)

### ❗ "Netflix = Cassandra for everything"
✅ **Clarification**: Netflix uses Cassandra heavily for event streams (viewing history), but **MySQL** for billing and transactional data. Polyglot persistence is the reality even at Netflix scale.

### ❗ "Uber dispatch just uses Redis GEO"
✅ **Clarification**: Uber built **H3 hex grid** specifically because rectangular geohash cells distort at different latitudes and create neighbor-query anomalies. Redis GEO works for small-scale systems; H3 is the production-grade answer.

### ❗ "WhatsApp sends messages via HTTP REST"
✅ **Clarification**: WhatsApp uses persistent **WebSockets** for real-time delivery, with sharded servers (consistent hashing by user_id) for connection routing and Cassandra for durable message storage. Short-lived HTTP would never handle the scale.

### ❗ "URL shortener is trivial"
✅ **Clarification**: At Bit.ly scale (billions of URLs, 100k redirect QPS), key generation (counter shards), caching hot URLs, analytics pipeline, abuse detection (phishing), and multi-region writes all need design. The problem is "trivial" only at hello-world scale.

---

## 🧭 Frameworks / Meta

### ❗ "Design interviews have a correct answer"
✅ **Clarification**: There's a **defensible** answer given stated requirements. The interview tests whether you can (1) clarify requirements, (2) pick a design, (3) **articulate the alternatives you rejected and why**. Naming tradeoffs ≫ picking optimally.

### ❗ "Just add a cache / queue / sharding"
✅ **Clarification**: Derive from **numbers**. "200k QPS → a single DB can't serve → cache absorbs 95%+ reads" beats a hand-wave. Back-of-envelope math is senior signal.

### ❗ "I'll use consensus for strong consistency"
✅ **Clarification**: Consensus (Raft/Paxos) gives agreement on the next log entry. It doesn't magically give you low-latency strong consistency across continents — you still pay RTT per commit. Spanner uses **TrueTime** (GPS + atomic clocks) to reduce this cost at infrastructure scale.

### ❗ "Strong consistency + low latency + high availability — let's have all three"
✅ **Clarification**: Impossible in a partitioned distributed system (CAP + PACELC). Pick **per data type**:
- Payments → strong + sacrifice latency/availability on partition.
- Feeds → eventual + low latency.
- Auth tokens → strong + cached aggressively.

Articulating this *per data type* is senior signal.

---

## 🧭 Using This File

### Before an interview
Read end-to-end. Each item is 30 seconds; whole file ~25 minutes. Catches the "parroted wisdom" you might say without meaning.

### During study
Whenever something feels subtly wrong, check here. If your intuition matches a ❗ item on this list, stop and re-read.

### Add your own
Any time an interviewer catches you in a misconception, add the ❗/✅ pair here. Your own list > a generic one.

### Companion files
- [`00_learning_path.md`](00_learning_path.md) — 7-layer curriculum.
- [`00_evaluation.md`](00_evaluation.md) — scorecard + gaps.
- [`03_interview_mode.md`](03_interview_mode.md) — Q→A navigable layer.
- [`99_interview_mastery.md`](99_interview_mastery.md) — night-before checklist.
- [`frameworks/thinking-framework.md`](frameworks/thinking-framework.md) — 4-stage script.
- [`frameworks/request-lifecycle.md`](frameworks/request-lifecycle.md) — cross-topic narrative.
