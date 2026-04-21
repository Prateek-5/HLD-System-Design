# 🔥 03 · Interview Mode — Question-Navigable Layer (full curriculum)

> Complement to `notes/03_interview_mode.md`. This one uses the **full depth** of the `learn/` curriculum — richer answers, more tradeoff analysis, more case study depth.
>
> **How to use**: start from any question. If you can't answer in 30s out loud, follow 📍 Answer Location into the relevant layered file.
>
> **Classification legend**:
> 🎯 **Direct** — fully answered in one section of one file.
> 🧩 **Implicit** — requires combining 2+ files.
> 🔓 **Open-ended** — expects reasoning + defended tradeoffs.

---

## 🧭 Layer 1 — Foundations: Networking

### Q1. Walk me through what happens when I type `google.com` into a browser. 🔓
- 📍 [`frameworks/request-lifecycle.md`](frameworks/request-lifecycle.md) — the full walkthrough, stage by stage.
- ⚡ **30-sec**: URL parse → DNS resolve → TCP handshake → TLS handshake → CDN edge → LB → API gateway → app service → cache → DB → response back along the same path.
- 🎯 **Interviewer tests**: can you narrate 13 stages without skipping NAT, TLS, cache, LB? Senior signal.

### Q2. IPv4 vs IPv6 — real difference? 🎯
- 📍 [`foundations/networking/ip.md`](foundations/networking/ip.md) § Versions.
- ⚡ IPv4 = 32-bit (4.3 B addresses; ran out ~2011). IPv6 = 128-bit (effectively infinite) + restores end-to-end connectivity that NAT broke.

### Q3. What is CIDR and why does it exist? 🔓
- 📍 [`foundations/networking/ip.md`](foundations/networking/ip.md) § CIDR (enhanced with full why + worked example).
- ⚡ **30-sec**: Before CIDR (1993), classful addressing forced orgs to take 256 / 65k / 16M blocks; waste was enormous and routing tables were exploding toward router-memory collapse. CIDR lets you allocate any power-of-2 size and summarize many networks into one route via longest-prefix match.
- 🧠 **Decision framework (VPC sizing)**: VPC `/16` (65k), subnets `/20` per AZ (~4k each), further subnet `/24` per tier. Always leave headroom.

### Q4. Walk me through a DNS lookup. 🎯
- 📍 [`foundations/networking/dns.md`](foundations/networking/dns.md) § Full lookup.
- ⚡ OS stub resolver → recursive resolver (cache check) → root (returns TLD) → TLD (returns authoritative) → authoritative (returns A record). Most lookups hit cache at one of the 3 layers and skip later steps.

### Q5. Why does DNS use UDP? 🎯
- 📍 [`foundations/networking/dns.md`](foundations/networking/dns.md) § Tradeoffs.
- ⚡ Small payload, app-layer retries are cheap, TCP handshake would triple cost. Falls back to TCP when response > 512 bytes or for zone transfers.

### Q6. TCP 3-way handshake — what gets exchanged? 🎯
- 📍 [`foundations/networking/tcp-udp.md`](foundations/networking/tcp-udp.md) § TCP handshake.
- ⚡ Client SYN (seq=X) → Server SYN+ACK (seq=Y, ack=X+1) → Client ACK (ack=Y+1). Establishes bidirectional sequence numbers; costs 1 RTT before data.

### Q7. What is head-of-line blocking and how does HTTP/3 fix it? 🔓
- 📍 [`foundations/networking/tcp-udp.md`](foundations/networking/tcp-udp.md) § HOL, [`architecture/long-polling-websockets-sse.md`](architecture/long-polling-websockets-sse.md).
- ⚡ **30-sec**: TCP guarantees in-order delivery; one lost packet freezes all multiplexed streams in HTTP/2. HTTP/3 runs over UDP via QUIC; streams are independent so loss in stream A doesn't block stream B.
- 🎯 **Interviewer tests**: do you understand why modern protocols abandoned TCP for multiplexing?

### Q8. What's an ephemeral port? 🎯
- 📍 [`foundations/networking/tcp-udp.md`](foundations/networking/tcp-udp.md) § Ports (enhanced).
- ⚡ Short-lived source port the OS picks per outgoing connection so the 4-tuple (src IP, src port, dst IP, dst port) is unique. Linux default range 32768–60999. Exhaustion occurs around 28k concurrent conns to the same destination.

### Q9. Forward vs reverse proxy — which does Cloudflare run? 🎯
- 📍 [`foundations/networking/proxy.md`](foundations/networking/proxy.md).
- ⚡ Cloudflare = **reverse proxy** in front of your origin. Forward proxy sits in front of clients (corporate egress). Cloudflare hides your origin from the public internet.

### Q10. If `ping` works but `curl https://server` times out — which layer? 🔓
- 📍 [`foundations/networking/osi.md`](foundations/networking/osi.md) § "which layer is the problem".
- ⚡ Ping = L3 ICMP → L1/L2/L3 are fine. Problem is L4+ (TCP port blocked, TLS cert invalid, app not listening).

---

## 🧭 Layer 2 — Foundations: Scaling

### Q11. L4 vs L7 — what can L7 do that L4 can't? 🔓
- 📍 [`foundations/scaling/load-balancing.md`](foundations/scaling/load-balancing.md) § L4-vs-L7 capability table.
- ⚡ **30-sec**: L4 routes on IP+port only. L7 can route by path, host header, cookies; terminate TLS; cache; do WAF; compress; rewrite headers.
- 🧠 **Framework**: pick L7 if you need any of URL routing / cookie stickiness / TLS termination / caching / WAF. Pick L4 for raw throughput or non-HTTP protocols.

### Q12. WebSocket service — which LB algorithm? 🎯
- 📍 [`foundations/scaling/load-balancing.md`](foundations/scaling/load-balancing.md) § Algorithms.
- ⚡ Least-connections. Sessions are long-lived; round-robin goes lopsided fast.

### Q13. Three fixes for cache stampede? 🎯
- 📍 [`foundations/scaling/caching.md`](foundations/scaling/caching.md) § Cache stampede (enhanced).
- ⚡ Request coalescing (singleflight) + TTL jitter + stale-while-revalidate.

### Q14. Compare write-through / write-around / write-back. 🎯
- 📍 [`foundations/scaling/caching.md`](foundations/scaling/caching.md) § Write strategies.
- ⚡ **Write-through**: write cache+DB together → consistent, slower. **Write-around**: write skips cache → first read is miss. **Write-back**: write cache, async to DB → fast, durability risk.

### Q15. Your web app serves 10k QPS. Compute availability given LB (99.9%) + App (99.9%) + DB (99.9%) in series. 🔓
- 📍 [`foundations/scaling/availability.md`](foundations/scaling/availability.md) § Series vs parallel (enhanced with worked example).
- ⚡ **30-sec**: 0.999 × 0.999 × 0.999 = **99.7%**. You missed 3-nines by a full nine. Add redundant LB (1-(0.001)² = 99.9999%), 3 app instances parallel, primary+sync-replica DB → series of redundant components ≈ 99.99+%.
- 🎯 **Interviewer tests**: you can do series/parallel math on the fly.

### Q16. Cold cache after deploy — why dangerous? 🧩
- 📍 [`foundations/scaling/caching.md`](foundations/scaling/caching.md) § Cold-cache problem.
- ⚡ Every request is a miss → full load hits DB → DB overwhelms. Mitigations: warm cache before cutover, gradual traffic shift, or request coalescing so 1000 misses on the same key = 1 DB hit.

### Q17. Push vs pull CDN — when each? 🎯
- 📍 [`foundations/scaling/cdn.md`](foundations/scaling/cdn.md) § Types.
- ⚡ **Pull** = default; scales with traffic, simple. **Push** = for tight control (pre-positioning Netflix new releases). Most production = pull.

### Q18. Vertical vs horizontal scaling — where does each break? 🔓
- 📍 [`foundations/scaling/scalability.md`](foundations/scaling/scalability.md).
- ⚡ **Vertical** breaks at hardware ceiling + $ curve goes exponential + one box = SPOF. **Horizontal** breaks at the stateful tier (sharding pain, consistency pain, cross-shard transactions).

### Q19. Split brain — what and how to resolve? 🎯
- 📍 [`foundations/scaling/clustering.md`](foundations/scaling/clustering.md).
- ⚡ Network partition → both halves think they're leader → accept writes independently → divergent state. Fix: quorum (N/2+1) — only majority side makes decisions.

### Q20. Block vs file vs object storage — pick for each case. 🧩
- 📍 [`foundations/scaling/storage.md`](foundations/scaling/storage.md).
- ⚡ **Block (EBS)**: DB files, OS disks, low latency. **File (EFS/NFS)**: shared POSIX mounts, legacy apps. **Object (S3)**: static assets, media, backups, CDN origin.

---

## 🧭 Layer 3 — Data

### Q21. SQL vs NoSQL decision — framework? 🔓
- 📍 [`data/sql-vs-nosql.md`](data/sql-vs-nosql.md), [`data/nosql-databases.md`](data/nosql-databases.md).
- 🧠 **Framework**:
  - Money/inventory/ACID → SQL.
  - Flexible schema, heavy scale → Document (Mongo).
  - Write-heavy time-series → Wide-column (Cassandra).
  - Sessions, caches, KV → Redis.
  - Graph traversal → Neo4j.
  - Real systems = polyglot persistence.

### Q22. MVCC — what and why? 🎯
- 📍 [`data/sql-databases.md`](data/sql-databases.md) § MVCC (enhanced).
- ⚡ Readers see an older row version while a writer creates a new one. Readers never block writers and vice versa. Cost: vacuum/bloat management.

### Q23. Walk through N=3, W=2, R=2 consistency math. 🎯
- 📍 [`data/nosql-databases.md`](data/nosql-databases.md), [`data/database-replication.md`](data/database-replication.md).
- ⚡ W+R > N → every read overlaps with a replica that saw the last write → strong consistency per-key. N=3, W=1, R=1 → 2<3 → may see stale reads.

### Q24. Primary crash with async replication — what can be lost? 🎯
- 📍 [`data/database-replication.md`](data/database-replication.md) § Replication lag + Read-after-write (enhanced).
- ⚡ Any writes acked by primary but not yet shipped to replicas. That's the data-loss window — seconds to tens of seconds typically.

### Q25. Read-after-write anomaly — cause and 3 fixes? 🎯
- 📍 [`data/database-replication.md`](data/database-replication.md) § Read-after-write flow (enhanced).
- ⚡ User posts, auto-refresh hits a lagged replica, user doesn't see their own post. Fixes: route user's reads to primary for N sec after their write; sticky session to one replica + wait for its lag; client-side merge with locally-known state.

### Q26. What does CDC actually do? 🎯
- 📍 [`notes/database_replication.md`](../notes/database_replication.md) § CDC walkthrough.
- ⚡ Tails the DB's WAL, emits structured `{op, before, after}` events to Kafka. Derives downstream state (search, cache, warehouse) without dual-writes.

### Q27. Explain LSM vs B-tree. 🔓
- 📍 [`data/nosql-databases.md`](data/nosql-databases.md) § Wide-column, [`notes/nosql_internals.md`](../notes/nosql_internals.md).
- ⚡ **B-tree**: balanced tree, in-place updates, great for point reads. **LSM**: append-only commit log + memtable → SSTables → background compaction. Great for writes, pays with read amp.
- 🧠 **Framework**: write-heavy → LSM. Read-heavy OLTP → B-tree.

### Q28. Isolation levels — anomalies each blocks? 🔓
- 📍 [`data/transactions.md`](data/transactions.md).
- ⚡ Read Uncommitted → dirty read possible. Read Committed → no dirty read; non-repeatable read still possible. Repeatable Read → no non-repeatable; phantom still possible. Serializable → no anomalies, highest cost.

### Q29. CAP theorem — walk through a concrete partition scenario. 🔓
- 📍 [`data/cap-theorem.md`](data/cap-theorem.md) § Concrete partition scenario (enhanced).
- ⚡ **30-sec**: Alice and Bob both withdraw from joint account during partition. **CP**: minority side rejects, no data corruption. **AP**: both accept → balance diverges → conflict on heal. Pick CP for money, AP for feeds.

### Q30. Classify Cassandra, MongoDB, HBase in PACELC. 🎯
- 📍 [`data/pacelc-theorem.md`](data/pacelc-theorem.md).
- ⚡ Cassandra = PA/EL (AP under partition, latency-first normally). MongoDB default = PA/EC. HBase = PC/EC (consistency first in all cases).

### Q31. Why 2PC fails in microservices + what replaces it? 🔓
- 📍 [`data/distributed-transactions.md`](data/distributed-transactions.md).
- ⚡ **30-sec**: 2PC blocks on coordinator crash — participants hold locks indefinitely. Coordinator is SPOF. Replace with **sagas**: each step is a local transaction + compensation on failure. No distributed locks.
- 🎯 **Interviewer tests**: you know 2PC's operational failure mode and the modern alternative.

### Q32. Pick a shard key for Twitter tweets. Defend. 🔓
- 📍 [`data/sharding.md`](data/sharding.md) § Hot-key playbook (enhanced).
- ⚡ `hash(user_id)` — cheap feed scan per user. Celebrity skew → replicate hot partitions across N shards. NOT `tweet_id` (scatters user's tweets → feed fan-out read explodes).

### Q33. Why consistent hashing over modulo? 🎯
- 📍 [`data/consistent-hashing.md`](data/consistent-hashing.md) § Virtual nodes (enhanced).
- ⚡ Add/remove a node: modulo remaps ~all keys; CH moves only ~1/N. Virtual nodes smooth uneven ring distribution.

### Q34. DB federation vs sharding? 🎯
- 📍 [`data/database-federation.md`](data/database-federation.md).
- ⚡ **Federation** = by function (users DB, orders DB). **Sharding** = by row (users_1, users_2). Federation = natural for microservices; sharding = within one service's data.

### Q35. Indexes — when is adding one a net negative? 🔓
- 📍 [`data/indexes.md`](data/indexes.md).
- ⚡ Writes slow by ~1× per index (must update index too). If write QPS dominates read QPS for that column, the index hurts. Always profile with EXPLAIN first.

---

## 🧭 Layer 4 — Architecture

### Q36. Monolith vs microservices — when to split? 🔓
- 📍 [`architecture/monolith-vs-microservices.md`](architecture/monolith-vs-microservices.md) § Prerequisites (enhanced).
- 🧠 **Framework**: Split when team coordination becomes the bottleneck, not "for scale". First ensure: CI/CD per service, tracing, centralized logs, service discovery, circuit breakers, on-call rotation. Without those → distributed monolith = worst of both worlds.

### Q37. Queue vs pub-sub — choose for order events. 🎯
- 📍 [`architecture/message-queues.md`](architecture/message-queues.md), [`architecture/pub-sub.md`](architecture/pub-sub.md).
- ⚡ Pub-sub if multiple downstream services react (inventory, billing, shipping, analytics). Queue if only one worker pool processes.

### Q38. Event sourcing vs CRUD persistence? 🔓
- 📍 [`architecture/event-sourcing.md`](architecture/event-sourcing.md).
- ⚡ CRUD: store current state. ES: store the sequence of events; current state = fold over events. Gains: full audit, temporal queries, natural replay. Costs: complexity, schema evolution of events, snapshots for fast reads.

### Q39. CQRS — when does it pay off? 🔓
- 📍 [`architecture/cqrs.md`](architecture/cqrs.md).
- ⚡ When reads and writes have wildly different patterns. Write side normalized + transactional; read side denormalized + cached. Sync via events/CDC. Not worth it for a simple CRUD app.

### Q40. Choreography vs orchestration for a checkout saga? 🔓
- 📍 [`architecture/event-driven-architecture.md`](architecture/event-driven-architecture.md) § Worked example (enhanced).
- 🧠 **Framework**: Simple flow / 2–3 steps / each team owns a step → choreography. Complex branches / 5+ steps / compensations / visibility → orchestration (Temporal/Step Functions).

### Q41. REST vs GraphQL vs gRPC — pick per use case. 🔓
- 📍 [`architecture/rest-graphql-grpc.md`](architecture/rest-graphql-grpc.md).
- 🧠 **Framework**: Public API → REST (cacheable, familiar). Mobile/multi-client flexibility → GraphQL. Internal microservices → gRPC (binary, typed, HTTP/2).

### Q42. API gateway — what goes in vs what doesn't? 🔓
- 📍 [`architecture/api-gateway.md`](architecture/api-gateway.md) § god-gateway warning (enhanced).
- ⚡ **In**: auth (coarse), rate limit, routing, TLS termination, observability. **NOT in**: business logic, schema validation specific to services, domain rules. Avoid the "god gateway" that becomes a monolith itself.

### Q43. WebSocket vs SSE vs long-polling for chat? 🎯
- 📍 [`architecture/long-polling-websockets-sse.md`](architecture/long-polling-websockets-sse.md).
- ⚡ Chat = bi-directional → WebSocket. Server-push only (notifications) → SSE. Legacy fallback → long-poll.

### Q44. N-tier architecture — why separate tiers? 🎯
- 📍 [`architecture/n-tier-architecture.md`](architecture/n-tier-architecture.md).
- ⚡ Independent scaling, fault isolation, clear contract boundaries. Cost: network hops add latency; operational complexity.

---

## 🧭 Layer 5 — Reliability & Security

### Q45. Circuit breaker states + how to size thresholds? 🔓
- 📍 [`reliability/circuit-breaker.md`](reliability/circuit-breaker.md) § Retry storm (enhanced).
- ⚡ **Closed → Open → Half-Open → Closed**. Trigger on rolling-window failure rate (say >50%) + latency breach. Cool-down 30s. Half-open: send 1 probe; success → close, failure → reopen with doubled cooldown.

### Q46. Retry without jitter — what breaks? 🎯
- 📍 [`reliability/circuit-breaker.md`](reliability/circuit-breaker.md) § Retry storm (enhanced).
- ⚡ 1000 clients retry at identical intervals → synchronized thundering herd → oscillating outage. Jitter randomizes retry times.

### Q47. Token bucket in Redis — implementation? 🎯
- 📍 [`reliability/rate-limiting.md`](reliability/rate-limiting.md) § Idempotency flow (enhanced).
- ⚡ Per-key state `(tokens, last_refill)` updated in atomic Lua script: refill tokens based on elapsed time up to cap, consume 1 if available or reject.

### Q48. Idempotency key lifecycle? 🎯
- 📍 [`reliability/rate-limiting.md`](reliability/rate-limiting.md) § Idempotency flow (enhanced).
- ⚡ Client generates UUID; server stores it in Redis with `SETNX + TTL=24h`. First call runs op and stores response. Retry with same key → return cached response. Safe for retries.

### Q49. Service discovery — client-side vs server-side? 🎯
- 📍 [`reliability/service-discovery.md`](reliability/service-discovery.md).
- ⚡ Client-side: clients query registry and pick endpoint directly (less infra, but each language needs the integration). Server-side: clients hit a stable LB which does the discovery (simpler clients, LB becomes critical).

### Q50. RTO vs RPO — design DR tier? 🔓
- 📍 [`reliability/disaster-recovery.md`](reliability/disaster-recovery.md).
- 🧠 **Framework**:
  - Backup & restore: RTO hours / RPO hours (cheap).
  - Pilot light: RTO minutes / RPO seconds.
  - Warm standby: RTO minutes / RPO ~0.
  - Hot-hot multi-region: RTO seconds / RPO ~0 (expensive).

### Q51. SLA / SLO / SLI — differences? 🎯
- 📍 [`reliability/sla-slo-sli.md`](reliability/sla-slo-sli.md).
- ⚡ **SLI** = what you measure (latency, success rate). **SLO** = internal target (99.9% success). **SLA** = external contract (or refund). SLOs are stricter than SLAs to leave buffer.

### Q52. Error budget — what does it unlock? 🔓
- 📍 [`reliability/sla-slo-sli.md`](reliability/sla-slo-sli.md).
- ⚡ Budget = 1 − SLO (e.g., 0.1% = ~43 min/month). Unspent → ship faster, take risks, deploy Fridays. Spent → freeze risky changes, focus on reliability. Turns reliability into a quantified conversation.

### Q53. OAuth vs OIDC? 🎯
- 📍 [`reliability/oauth-oidc.md`](reliability/oauth-oidc.md).
- ⚡ OAuth = delegated **authorization** (tokens grant access). OIDC = authentication layer on top (identity tokens). "Sign in with Google" = OIDC, which uses OAuth underneath.

### Q54. TLS 1.3 handshake cost? 🎯
- 📍 [`reliability/ssl-tls-mtls.md`](reliability/ssl-tls-mtls.md).
- ⚡ 1 RTT handshake. With session resumption: 0 RTT. Down from TLS 1.2's 2 RTTs.

### Q55. mTLS vs TLS? 🎯
- 📍 [`reliability/ssl-tls-mtls.md`](reliability/ssl-tls-mtls.md).
- ⚡ TLS = server proves identity. mTLS = both client and server present certs. Used in zero-trust meshes; cert distribution is the ops cost.

### Q56. Containers vs microVMs (Firecracker)? 🎯
- 📍 [`reliability/vms-and-containers.md`](reliability/vms-and-containers.md).
- ⚡ Containers share host kernel → weak isolation, dense. microVMs have own kernel via KVM → VM-like isolation at container-like density (125ms cold start). Lambda runs on Firecracker.

### Q57. Geohash vs H3 vs S2? 🎯
- 📍 [`reliability/geohashing-quadtrees.md`](reliability/geohashing-quadtrees.md).
- ⚡ Geohash: rectangular, string prefix-indexed. H3 (Uber): hexagonal, uniform neighbor distances. S2 (Google): spherical Hilbert curve, most accurate, most complex.

---

## 🧭 Layer 6 — Interview Systems (Case Studies)

### Q58. Design URL shortener. 🔓
- 📍 [`interview-systems/url-shortener.md`](interview-systems/url-shortener.md).
- ⚡ **30-sec**: counter-based key gen (base62 encoded); Cassandra/DynamoDB for key→URL mapping; Redis cache for hot redirects; 302 redirect for analytics; Kafka → ClickHouse for click events.
- 🧠 **Framework**: 7-char base62 = 3.5T combinations. Read:write = 100:1 → cache-heavy. Sharded counters per app server to avoid contention.

### Q59. Design WhatsApp. 🔓
- 📍 [`interview-systems/whatsapp.md`](interview-systems/whatsapp.md).
- ⚡ **30-sec**: WebSocket per user, sharded chat servers (consistent hashing by user_id), Cassandra for messages (partition by user+time), Redis for presence, S3+CDN for media, Signal protocol E2E encryption. Offline → queue in Cassandra, flush on reconnect.
- 🎯 **Interviewer tests**: connection management, group-chat fan-out, presence with TTL.

### Q60. Design Twitter feed — push / pull / hybrid? 🔓
- 📍 [`interview-systems/twitter.md`](interview-systems/twitter.md) § Fan-out math (enhanced).
- ⚡ **Push** (fan-out on write) for normal users — cheap read, write to all followers. **Pull** (fan-out on read) for celebrities (>10k followers) — otherwise one Bieber tweet = 100M writes. **Hybrid** merges at read time. This is Twitter's actual design.

### Q61. Design Netflix — video delivery at scale? 🔓
- 📍 [`interview-systems/netflix.md`](interview-systems/netflix.md) § HLS manifest (enhanced).
- ⚡ Transcode into bitrate ladder → segment into 2–10s chunks → HLS/DASH manifest → object storage → Open Connect (Netflix's own CDN with appliances inside ISPs) → client adaptive bitrate.
- 🎯 **Interviewer tests**: Do you know shot-based encoding? Why own CDN? (Netflix is 15%+ of internet traffic.)

### Q62. Design Uber dispatch. 🔓
- 📍 [`interview-systems/uber.md`](interview-systems/uber.md) § Surge math (enhanced).
- ⚡ **30-sec**: Drivers publish GPS every 3-5s → Redis GEO / H3 hex cells. Rider request → compute rider cell → query current + 6 neighbor cells → filter + rank by ETA → offer to best driver → timeout → next. Surge = per-cell supply/demand ratio recomputed every 30s.

---

## 🧭 Frameworks

### Q63. Walk me through your approach to a design interview. 🔓
- 📍 [`frameworks/thinking-framework.md`](frameworks/thinking-framework.md).
- ⚡ 4-stage script: **Clarify** (requirements + scale + consistency) → **Estimate** (QPS + storage + bandwidth) → **High-level arch** (client → edge → service → data) → **Deep dive** (data model, shard key, replication, indexes, failure modes) → **Non-functional wrap** (SLO, monitoring, cost).

### Q64. Walk me through a request's lifecycle. 🔓
- 📍 [`frameworks/request-lifecycle.md`](frameworks/request-lifecycle.md).
- ⚡ 13 stages (see Q1). If you can narrate all 13 from cache-check in browser to Kafka analytics event, you've internalized the foundations.

---

## 🧠 Reusable Decision Frameworks

### Framework A — "Do I need strong consistency?"
| Signal | Pick |
|---|---|
| Money, uniqueness, inventory, auth tokens | **Strong** (ACID / CP) |
| Social feed, counts, likes, views | **Eventual** (BASE / AP) |
| Search / recommendations | **Eventual** + refresh |

### Framework B — "Which storage for this tier?"
| Need | Pick |
|---|---|
| OLTP, relations, ACID | Postgres / MySQL |
| Flexible schema, horizontal | MongoDB / DynamoDB |
| Massive write, time-series | Cassandra / ScyllaDB |
| Sub-ms KV, sessions | Redis |
| Full-text search | Elasticsearch |
| Time-series metrics | Prometheus / Influx |
| Blobs / media | S3 + CDN |

### Framework C — "What's my async transport?"
| Need | Pick |
|---|---|
| High throughput + replay + EOS | Kafka |
| Complex routing (topic, fanout, headers) | RabbitMQ |
| Fully managed, AWS-native | SQS + SNS |
| Lightweight, in-process | Redis Streams |

### Framework D — "Which fan-out pattern for this workload?"
| Writer : Reader | Pick |
|---|---|
| Many : One (work) | Queue |
| One : Many (broadcast) | Pub-sub |
| Many : Many (replay) | Kafka topic |

### Framework E — "Which consistency tool under partition?"
| Need | Pick |
|---|---|
| Tolerate stale reads | AP (Cassandra, DynamoDB) |
| Tolerate write unavailability | CP (MongoDB, HBase) |
| Linearizable multi-region | Consensus (etcd, Spanner, CockroachDB) |

### Framework F — "Which LB algorithm?"
| Workload | Algorithm |
|---|---|
| Homogeneous + short requests | Round-robin |
| Heterogeneous servers | Weighted RR |
| Long-lived connections (WS, DB) | Least-connections |
| Cache locality / session stickiness | Hash-based / sticky |
| Mixed, no state | Power of two choices |

### Framework G — "How do I scale X tier?"
| Tier | Horizontal strategy |
|---|---|
| Web / app (stateless) | Trivial — add instances behind LB |
| Read-heavy DB | Read replicas + cache-aside |
| Write-heavy DB | Shard by key with consistent hashing |
| Queue | More partitions + more consumers |
| Object storage | Already horizontal (S3) |

### Framework H — "Sync or async replication?"
| Data | Pick |
|---|---|
| Bank ledger, critical writes | Sync (at least semi-sync) |
| Feed, counters, likes | Async |
| Multi-region with low latency | Consensus (Raft/Paxos) |

### Framework I — "Push, pull, or hybrid fan-out?"
| Signal | Pick |
|---|---|
| Normal user follow counts | Push |
| Celebrity follower counts (>10k) | Pull |
| Mixed | Hybrid (Twitter approach) |

### Framework J — "Cache pattern?"
| Need | Pick |
|---|---|
| General-purpose | Cache-aside (default) |
| Transparent to app | Read-through |
| Immediate consistency | Write-through |
| Max write speed + tolerate loss | Write-back + replicated cache |
| Bursts of writes rarely read | Write-around |

---

## 📊 How to use this file

1. **First pass (study)**: read all questions out loud, try the 30-sec answer, check against file. Target: ≥80% on the first pass.
2. **Second pass (speed)**: timed — 30s per question. Anything slower → go back to 📍 location.
3. **Third pass (mock interview)**: answer in full sentences. Use Decision Frameworks for all tradeoff questions.

### Companion files
- [`00_learning_path.md`](00_learning_path.md) — 7-layer curriculum.
- [`00_evaluation.md`](00_evaluation.md) — scorecard + gaps.
- [`04_confusion_resolver.md`](04_confusion_resolver.md) — traps in `learn/` content.
- [`99_interview_mastery.md`](99_interview_mastery.md) — night-before checklist.
- [`frameworks/thinking-framework.md`](frameworks/thinking-framework.md) — 4-stage interview script.
- [`frameworks/request-lifecycle.md`](frameworks/request-lifecycle.md) — the single best cross-topic narrative.
