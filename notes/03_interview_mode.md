# 🔥 03 · Interview Mode — Rapid Q→A Revision Layer

> Every important question from every notes file, with answer location, 30-sec answer, key bullets, and decision framework where applicable.
>
> **How to use:** start from any question. If you can't answer in 30s, jump to 📍 Answer Location and re-read that section.
>
> **Classification legend:**
> 🎯 **Direct** — answer in one section of one file.
> 🧩 **Implicit** — requires combining multiple sections.
> 🔓 **Open-ended** — expects reasoning + tradeoff argumentation.

---

## 🔷 Load Balancing

### Q1. Difference between L4 and L7 load balancer? 🎯
- 📍 **Answer Location**: [`load_balancing.md`](load_balancing.md) § Core Concepts
- ⚡ **1-line**: L4 routes on IP+port (fast, protocol-agnostic); L7 routes on HTTP path/host/header (smart, parses HTTP).
- **Key bullets**:
  - L4: TCP/UDP splicing; can't see URL; no caching.
  - L7: parses HTTP → path routing, host-based multi-tenancy, cookie stickiness, TLS termination, caching, WAF.
  - L7 costs CPU for HTTP parsing; L4 is nearly line-rate.

### Q2. Why is an LB a SPOF and how do you fix it? 🎯
- 📍 [`load_balancing.md`](load_balancing.md) § Tradeoffs, SPOF section.
- ⚡ One LB dies → all traffic fails. Fix: active-passive with floating VIP (VRRP/keepalived), or active-active with DNS multi-A or anycast.
- **Key**: cloud-managed LBs (AWS ALB, GCP LB) abstract the HA; on-prem you own it.

### Q3. WebSocket backend — which LB algorithm? 🧩
- 📍 [`load_balancing.md`](load_balancing.md) § Algorithms + connections.
- ✅ **30-sec answer**: Least-connections. Sessions are long-lived; round-robin goes lopsided fast because new requests don't equal new work.
- 🔍 **Deep**: WS = persistent per-user connection. RR would send new WS attempts evenly but existing conns stay on their server, so some boxes have 10k conns while fresh ones have 100. Least-conn keeps load balanced across both old and new.
- 🎯 **Interviewer tests**: do you understand that "balanced requests" ≠ "balanced work" for long-lived protocols?

### Q4. Power of two choices — why does it work? 🔓
- ⚡ **30-sec**: Pick 2 backends at random, send to whichever has fewer connections. Theoretically exponentially better than pure random; almost matches least-connections at O(1) cost.
- 🧠 **Decision framework**: Random → cheap but uneven. Least-conn → best but needs global state. Power-of-two → middle ground, nearly as good as least-conn without the state overhead. Default in modern meshes.

### Q5. Subsetting — why does it matter at scale? 🔓
- ⚡ **30-sec**: With 10k backends and 1k LBs, each LB having a connection to every backend = 10M TCP connections. Subsetting gives each LB ~100 backends only → 100k connections. Saves RAM + CPU.
- 🎯 **Interviewer expects**: you know that fan-out isn't free; the connection matrix is the silent killer at scale.

---

## 🔷 Caching

### Q6. Default cache pattern — and when do you deviate? 🎯
- 📍 [`caching.md`](caching.md) § Core Concepts.
- ⚡ **Cache-aside** is default (app reads cache, on miss fetches + populates).
- **Deviate when**: you need freshness guarantees (write-through) or absolute write throughput (write-back with replication).

### Q7. Three fixes for cache stampede (thundering herd)? 🎯
- 📍 [`caching.md`](caching.md) § Cache stampede.
- ⚡ **Request coalescing** (singleflight); **TTL jitter**; **stale-while-revalidate**.
- 🎯 **Interviewer tests**: you don't just say "add a cache" — you acknowledge and mitigate cache-induced failure modes.

### Q8. When should you NOT cache? 🧩
- ⚡ **30-sec**:
  1. Low repetition (unique requests) → 0% hit rate.
  2. Data changes constantly → invalidation cost exceeds saved work.
  3. Source is already fast (memory-to-memory).
- 🎯 **Interviewer tests**: you don't treat caching as always-beneficial dogma.

### Q9. How do you make cache + DB stay consistent? 🔓
- 🧠 **Decision framework**:
  - Tolerate seconds of staleness → TTL + cache-aside (default).
  - Need immediate consistency → write-through (pay latency).
  - Need async + durable → write-back + replicated cache (risky on crash).
  - Need "event-driven" → CDC invalidates cache keys on DB writes.
- ⚡ **Key rule**: cache is *derived data*. It should tolerate the primary writing without its knowledge.

### Q10. Why is 99% hit rate still risky? 🔓
- ⚡ **30-sec**: The 1% miss path can cluster on hot keys that all expire together → DB gets a 1000× spike. Hit-rate is an average; p99 latency + absolute miss QPS matter more.

---

## 🔷 Databases & NoSQL

### Q11. SQL vs NoSQL — decision framework? 🔓
- 🧠 **Framework** (pick per workload, not per system):
  - Need strict schema + joins + ACID → **SQL**.
  - Need flexible schema + horizontal scale → **Document NoSQL** (Mongo).
  - Need write-heavy time-series at huge scale → **Wide-column** (Cassandra).
  - Need KV + TTL + simple → **Redis / DynamoDB**.
  - Need graph traversal → **Neo4j / Neptune**.
- ⚡ **30-sec**: real systems use multiple; polyglot persistence is normal.

### Q12. Why is MVCC useful? 🎯
- 📍 [`databases.md`](databases.md) § MVCC (added), [`learn/data/sql-databases.md`](../learn/data/sql-databases.md).
- ⚡ Readers don't block writers and vice versa — critical for read-heavy OLTP.
- **Key**: each row has versioned copies; readers see consistent snapshot. Cost: vacuum/bloat management.

### Q13. LSM vs B-tree — when each wins? 🔓
- 🧠 **Framework**:
  - Write-heavy workload → **LSM** (Cassandra, RocksDB). Writes are sequential appends.
  - Read-heavy point queries → **B-tree** (Postgres, MySQL InnoDB). Balanced tree with O(log n) lookups.
  - LSM pays with read amp (must check multiple SSTables) + compaction CPU.
  - B-tree pays with random writes + in-place updates.

### Q14. With N=3, W=2, R=2 — strongly consistent? 🎯
- ⚡ **Yes.** W + R = 4 > N = 3 → every read touches at least one replica that saw the latest write.
- **Corollary**: N=3, W=1, R=1 → 1+1=2 < 3 → stale reads possible.

### Q15. Pick a shard key for Twitter tweets. Defend. 🔓
- ⚡ **30-sec**: `hash(user_id)` so each user's tweets cluster on one shard → cheap feed generation and range scans. Accept that celebs become hot-key; mitigate by replicating their partition across N shards.
- 🎯 **Interviewer expects**:
  - You can name the query pattern (feed = user's recent tweets).
  - You acknowledge the skew (celebrities) and mitigate (replicate/salt).
  - You explicitly say why NOT `tweet_id` (would scatter user's tweets across all shards → feed read fans out).

---

## 🔷 Database Replication

### Q16. Sync vs async replication — tradeoff? 🎯
- ⚡ Sync: no data loss on primary crash, +RTT latency per write. Async: fast writes, lose recent acks on crash.
- 🧠 **Framework**:
  - Bank ledger → sync (at minimum semi-sync).
  - Social feed → async with sub-second lag is fine.
  - Critical multi-region → Raft/Paxos (consensus-based sync).

### Q17. Replication lag — cause + mitigation? 🧩
- 📍 [`database_replication.md`](database_replication.md) § Replication lag + CDC.
- ⚡ **Cause**: replica applies WAL async; busy replica falls behind; large transactions on primary block replay.
- **Mitigations**: bigger replicas, logical replication parallelism, route critical reads to primary, session consistency (stick user to one replica for their session).

### Q18. What does CDC actually do? 🎯
- 📍 [`database_replication.md`](database_replication.md) § CDC walkthrough (added).
- ⚡ Tails the DB's WAL, emits `{op, before, after}` events to a Kafka topic. Downstream systems derive state from events → no dual-writes, no race.

### Q19. Outbox pattern — why and how? 🔓
- ⚡ **30-sec**: Solves the "write to DB AND publish to Kafka" atomicity problem. Write event row to an `outbox` table *in the same local tx as the DB change*. A relay (or Debezium) ships outbox rows to Kafka. Either both commit or neither.
- 🎯 **Interviewer expects**: you acknowledge dual-write hazards and name the exactly-one pattern that fixes them cleanly.

---

## 🔷 Sharding & Consistent Hashing

### Q20. Why consistent hashing over `hash(key) % N`? 🎯
- ⚡ Adding/removing a node remaps only ~1/N keys with consistent hashing. With modulo, nearly all keys change shards.

### Q21. Why virtual nodes? 🎯
- 📍 [`learn/data/consistent-hashing.md`](../learn/data/consistent-hashing.md) (enhanced).
- ⚡ Smooths load distribution. Without them, 3 physical nodes placed randomly on the ring can own 50/10/40 splits.

### Q22. Hot key on a sharded system — mitigation? 🔓
- 🧠 **Framework** (in order of effort):
  1. **Replicate** the hot key to N shards; fan-out reads.
  2. **Salt** the key (`user:celeb:0..9`) for counters / aggregations.
  3. **Two-tier cache** — app-local for hottest keys.
  4. **Throttle** writes upstream.
- ⚡ **Key insight**: consistent hashing distributes hashes evenly, not *traffic*. Celebrities still concentrate on one shard.

---

## 🔷 Messaging (Queues & Pub-Sub)

### Q23. Queue vs pub-sub — one-line each? 🎯
- ⚡ Queue: 1 message → 1 consumer in the group (work distribution). Pub-sub: 1 message → all subscribers (fan-out).

### Q24. Default delivery guarantee and consequence? 🎯
- ⚡ **At-least-once** → retries on failure → consumers MUST be idempotent or dedup.

### Q25. Kafka ordering — what's guaranteed? 🎯
- ⚡ Within a partition only. Across partitions, no ordering. Key your messages (e.g., by `user_id`) to keep related events in order.

### Q26. Kafka Exactly-Once Semantics (EOS) — what are the 3 components? 🔓
- 📍 [`message_queues_and_pubsub.md`](message_queues_and_pubsub.md) § Kafka EOS (added).
- ⚡ **3 components**:
  1. **Idempotent producer** (PID + seq deduplication on retry).
  2. **Transactional producer** (multi-partition atomic commit).
  3. **Read-process-write tx** (offset committed in same tx as output writes).
- **Catch**: end-to-end exactly-once to a non-Kafka sink (DB, API) still needs an idempotent sink or outbox pattern.

### Q27. What's a DLQ and why do you need one? 🎯
- ⚡ Dead-letter queue. After N retries on a poison message, move it aside. Alert on depth; debug later. Without it, one bad message jams the consumer forever.

---

## 🔷 Distributed Transactions

### Q28. Why avoid 2PC in microservices? 🔓
- ⚡ **30-sec**: Blocking on coordinator crash leaves participants holding locks. Coordinator is a SPOF. Synchronous across services = brittle + slow.
- **Alternative**: sagas + compensating transactions.

### Q29. Saga — one-sentence explanation? 🎯
- ⚡ Sequence of local transactions; each step publishes an event to trigger the next; on failure, run compensations in reverse.

### Q30. Choreography vs orchestration? 🔓
- 🧠 **Framework**:
  - Simple linear flow → **choreography** (pub-sub events, no central brain).
  - Complex branches / visibility / long-running → **orchestration** (Temporal, Step Functions, Conductor).
- ⚡ Trade: choreography = decoupled but hard to debug; orchestration = visible + debuggable but central dependency.

### Q31. Sagas lack which ACID property? 🎯
- ⚡ **Isolation.** Intermediate states are visible to other transactions. Design UIs and downstream systems to tolerate "in-progress" states.

---

## 🔷 Consensus (Raft / Paxos)

### Q32. Quorum formula + how many nodes to tolerate f failures? 🎯
- ⚡ Quorum = ⌊N/2⌋ + 1. To tolerate **f** failures, need **2f+1** nodes.
- 3 nodes → tolerate 1. 5 → 2. 7 → 3.

### Q33. Why randomized election timeout in Raft? 🎯
- ⚡ Prevents simultaneous candidates → avoids split votes requiring new elections.

### Q34. Can Raft-backed systems be AP? 🔓
- ⚡ **No.** Minority side refuses progress during partition (CP). They pick consistency over availability by design.

### Q35. Why 3 or 5 nodes, not 4 or 6? 🎯
- ⚡ Even numbers give same fault tolerance as N-1 but cost more inter-node traffic. Odd is canonical.

---

## 🔷 Rate Limiting

### Q36. Default rate-limiter algorithm + storage? 🎯
- ⚡ **Token bucket** in **Redis**, via atomic **Lua script** for per-key atomicity.

### Q37. Fail-open vs fail-closed for the limiter? 🔓
- ⚡ **Fail-open**: if Redis dies, allow traffic and alert. Don't take down the entire platform over a rate-limiter outage.
- **Caveat**: for security-sensitive endpoints (auth), fail-closed on those only.

### Q38. Retry + rate limit — how do they cooperate? 🧩
- ⚡ Server returns `429 Retry-After: 30`. Client should **exponential backoff + jitter**, never raw retry. Idempotency key makes the retry safe to repeat.

---

## 🔷 Resilience (Circuit Breaker, Retries)

### Q39. Three circuit breaker states? 🎯
- ⚡ **Closed** (all good), **Open** (fail fast, skip the call), **Half-Open** (one probe to test recovery; success → closed, failure → open).

### Q40. Exponential backoff without jitter — what breaks? 🔓
- ⚡ **30-sec**: 1000 clients all retry at the exact same intervals (1s, 2s, 4s, 8s...). Load spikes perfectly synchronized → recovering downstream oscillates between alive/dead. Jitter randomizes retry times to desynchronize.

### Q41. When to use bulkheads? 🧩
- ⚡ When one downstream's misbehavior can exhaust threads/connections shared with unrelated downstream calls. Separate thread pools per downstream → one sick dependency can't starve all others.

---

## 🔷 Networking

### Q42. Why does HTTP/3 use UDP? 🔓
- ⚡ To escape TCP's **head-of-line blocking**: in HTTP/2, one lost TCP packet freezes all multiplexed streams. QUIC streams over UDP are independent.

### Q43. TLS 1.2 vs 1.3 handshake — how many RTTs? 🎯
- ⚡ 1.2 = 2 RTT (handshake + data). 1.3 = 1 RTT. 1.3 with resumption = 0 RTT.

### Q44. What's an ephemeral port? 🎯
- 📍 [`learn/foundations/networking/tcp-udp.md`](../learn/foundations/networking/tcp-udp.md) § Ephemeral ports.
- ⚡ Short-lived source port the OS picks per outgoing connection to uniquely identify the 4-tuple.

### Q45. CIDR `/24` — how many usable hosts? 🎯
- 📍 [`learn/foundations/networking/ip.md`](../learn/foundations/networking/ip.md) § CIDR.
- ⚡ 256 addresses minus 2 (network + broadcast) = **254** usable hosts.

---

## 🔷 CAP / Consistency

### Q46. Pick two — honest version? 🎯
- ⚡ P is mandatory (partitions happen). During partition, pick **C** (reject writes) or **A** (serve stale/divergent).

### Q47. Classify Cassandra + MongoDB in PACELC. 🎯
- ⚡ Cassandra = **PA/EL** (AP under partition, latency-first in normal ops). MongoDB default = **PA/EC** (AP under partition, consistent in normal ops).

### Q48. When is eventual consistency the wrong choice? 🔓
- ⚡ **30-sec**: Anywhere two truths = a bug. Money (balance), inventory (seats), authentication tokens, uniqueness constraints. Feeds, likes, comments, recommendations → eventual is fine.

---

## 🔷 Observability

### Q49. Three pillars of observability? 🎯
- ⚡ Metrics, logs, traces. Linked via correlation/trace IDs.

### Q50. RED method vs USE method? 🎯
- ⚡ **RED** (services): Rate, Errors, Duration. **USE** (resources): Utilization, Saturation, Errors.

### Q51. Burn rate 14.4× — what does it mean? 🔓
- 📍 [`observability_logging_alerts.md`](observability_logging_alerts.md) § Burn rate.
- ⚡ You're consuming 30-day error budget 14.4× faster than sustainable. At that rate, 2% of a month's budget burns in an hour → urgent page.

### Q52. Why is cardinality a problem in Prometheus? 🎯
- ⚡ Each unique tag combination = new time series = RAM. Tag like `request_id` with millions of values → memory explosion.

---

## 🔷 Real-time / Geo

### Q53. WebSocket vs SSE vs long polling for chat? 🔓
- 🧠 **Framework**:
  - Bi-directional + low-latency → **WebSocket**.
  - Server-push-only → **SSE** (simpler, auto-reconnect, HTTP-native).
  - Legacy fallback → **long polling**.
- ⚡ Chat = WebSocket.

### Q54. Why H3 over geohash? 🎯
- ⚡ Hex cells have uniform neighbor distances; geohash rectangles distort near poles and at cell edges.

### Q55. Design surge pricing — key mechanism? 🔓
- ⚡ Per-cell `supply/demand` ratio, recomputed every ~30s. Surge multiplier = function of ratio (clamped 1.0–3.5×). Hot-cell replication needed.

---

## 🔷 Containers / Microservices

### Q56. Namespaces vs cgroups? 🎯
- ⚡ **Namespaces** = what a process *sees* (isolated PID, network, mount). **cgroups** = what a process *can use* (CPU, RAM, I/O limits).

### Q57. Prerequisites before going microservices? 🔓
- ⚡ CI/CD per service, distributed tracing, centralized logging, service discovery, circuit breakers, on-call rotation. Without these, you get a **distributed monolith** — worst of both worlds.

### Q58. Firecracker — why interesting? 🎯
- ⚡ microVM — container-like density (~125 ms boot) with VM-like kernel isolation. Powers AWS Lambda.

---

## 🔷 System Design Case Questions

### Q59. Design Twitter feed — push vs pull? 🔓
- 🧠 **Framework**:
  - Normal users → **push** (fan-out on write to follower timelines).
  - Celebrities (>10k followers) → **pull** (too expensive to write to all followers).
  - Hybrid at read time = Twitter's actual approach.

### Q60. Design URL shortener — key generation? 🔓
- 🧠 **Framework**:
  - **Counter + base62** (simplest, sharded counter ranges).
  - **Random + DB unique** (collisions + retry).
  - **Hash of URL** (dedup but predictable).
- ⚡ Pick counter-based with pre-allocated ranges per app server; fast, collision-free.

---

## 🧠 Decision Frameworks (reusable)

### Framework A — "Do I need strong consistency?"
| Signal | Pick |
|---|---|
| Money, uniqueness, inventory | Strong (ACID / CP) |
| Social feed, counts, likes | Eventual (BASE / AP) |
| Authentication / authz | Strong |
| Search / recommendations | Eventual + refresh |

### Framework B — "Which storage?"
| Need | Pick |
|---|---|
| OLTP, relations, ACID | Postgres / MySQL |
| Flexible schema, horizontal | MongoDB / DynamoDB |
| Massive write, time-series | Cassandra |
| Sub-ms KV, sessions | Redis |
| Full-text search | Elasticsearch |
| Metrics | Prometheus / Influx |
| Blobs | S3 |

### Framework C — "What's my async transport?"
| Need | Pick |
|---|---|
| High throughput + replay | Kafka |
| Complex routing | RabbitMQ |
| Managed + AWS-native | SQS + SNS |
| Simple + in-process | Redis Streams |

### Framework D — "Fan-out pattern?"
| Writers : Readers | Pick |
|---|---|
| Many : One (work) | Queue |
| One : Many (broadcast) | Pub-sub |
| Many : Many (replay) | Kafka topic |

### Framework E — "Which consistency tool under partition?"
- Tolerate stale reads? → AP (Cassandra, DynamoDB).
- Tolerate write unavailability? → CP (MongoDB, HBase).
- Need linearizable? → Consensus (etcd, Spanner).

---

## 📊 How to use this file

1. **Before an interview**: skim all questions and try to answer in 30s. Anything you stumble on → jump to 📍 Answer Location.
2. **During study**: when reading a notes file, come here to check if you can answer its questions cold.
3. **Post-interview**: add any new question you were asked + your answer + a Decision Framework hook if relevant.

Pair this file with:
- [`02_quiz.md`](02_quiz.md) — timed rapid-fire test (60 short Qs).
- [`04_confusion_resolver.md`](04_confusion_resolver.md) — common misunderstandings.
- [`01_interview_patterns.md`](01_interview_patterns.md) — patterns behind 80% of questions.
- [`00_quick_revision.md`](00_quick_revision.md) — everything compressed to 2–3 pages.
