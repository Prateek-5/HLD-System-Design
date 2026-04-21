# 🎯 02 · Rapid-Fire Self-Test (60 Questions)

> Cover the **answers column** with your hand. Read a question. Answer out loud. Uncover to check.
> Target: answer each in **under 10 seconds**. A full pass should take 10 minutes. If any category scores <70%, go back to the linked file.

---

## How to use

- **Round 1 (understanding)**: go one category at a time. Score yourself honestly.
- **Round 2 (speed)**: go end-to-end. Aim for <10s per question.
- **Round 3 (interview sim)**: answer in full sentences, out loud, as if explaining to an interviewer.

Scoring:
- ≥90% across all categories = interview-ready.
- 70–89% = solid; fix weak spots.
- <70% in a category = re-read that file before the interview.

---

## 🔷 1. Load Balancing (`load_balancing.md`)

| # | Question | Answer |
|---|---|---|
| 1 | L4 vs L7 — one-line difference? | L4 routes on IP+port; L7 routes on HTTP path/header/cookie. |
| 2 | One algorithm for a WebSocket service and why? | Least-connections — sessions are long-lived; round-robin goes lopsided. |
| 3 | How do you make the LB itself not a SPOF? | Active-passive with floating VIP (VRRP) or anycast. |
| 4 | What is "power of two choices"? | Pick 2 backends at random, send to the one with fewer connections. Near-least-conn at O(1) cost. |
| 5 | Why is a sticky session usually a smell? | It implies the app stores state in memory; prefer externalized session (Redis, JWT). |

---

## 🔷 2. Caching (`caching.md`)

| # | Question | Answer |
|---|---|---|
| 6 | Default cache pattern in production? | Cache-aside (app checks cache; on miss, reads source + populates). |
| 7 | Write-through vs write-back in one line each? | Write-through: write cache+DB together (consistent, slower). Write-back: write cache, async to DB (fast, durability risk). |
| 8 | Three fixes for cache stampede? | Request coalescing (singleflight), TTL jitter, stale-while-revalidate. |
| 9 | When should you NOT cache? | Low-repetition reads, data that changes constantly, cache as slow as source. |
| 10 | Why can a 99% hit rate still hurt the DB? | The 1% misses on hot keys can cluster; p99 latency + absolute miss rate matter more than average hit rate. |

---

## 🔷 3. Databases (`databases.md`, `nosql_internals.md`)

| # | Question | Answer |
|---|---|---|
| 11 | MVCC in one sentence? | Readers see an older row version while a writer creates a new one — no blocking. |
| 12 | Name 4 isolation levels, weakest to strongest? | Read Uncommitted < Read Committed < Repeatable Read < Serializable. |
| 13 | Why is LSM good for writes? | All writes are sequential appends to a commit log + memtable; no random disk I/O on the hot path. |
| 14 | What does a bloom filter do on an LSM read? | Probabilistic "is this key possibly in this SSTable?" — avoids pointless reads; zero false negatives. |
| 15 | When would you choose Cassandra over Postgres? | Write-heavy, horizontally-scaling workload with tunable consistency (e.g., time-series events). |
| 16 | With N=3, W=2, R=2 — is this strongly consistent? | Yes. W+R > N → reads always overlap with at least one writer. |

---

## 🔷 4. Database Replication (`database_replication.md`)

| # | Question | Answer |
|---|---|---|
| 17 | Sync vs async — one-line tradeoff? | Sync: no data loss, higher latency. Async: fast, risk of lost writes on primary crash. |
| 18 | What is replication lag and why does it matter? | Time between primary commit and replica catching up; causes read-after-write anomalies. |
| 19 | What does CDC actually do under the hood? | Tails the DB's WAL, emits structured change events to a stream (Kafka). |
| 20 | Outbox pattern solves what? | The dual-write race — writing to DB and Kafka atomically. Outbox row written in same tx, relayed later. |

---

## 🔷 5. Sharding & Consistent Hashing

| # | Question | Answer |
|---|---|---|
| 21 | Why consistent hashing over `hash(key) % N`? | Adding/removing a node moves only ~1/N keys, not all of them. |
| 22 | Why virtual nodes? | Smooth load distribution; avoid one physical node owning a huge arc of the ring. |
| 23 | Best shard key criteria? | High cardinality, low skew, matches dominant query pattern. |
| 24 | Hot-key mitigation on a good shard? | Replicate the hot key across N shards; salt the key (`user:bieber:0..9`). |

---

## 🔷 6. Messaging (`message_queues_and_pubsub.md`)

| # | Question | Answer |
|---|---|---|
| 25 | Queue vs pub-sub one-liner? | Queue: 1 message → 1 consumer (work distribution). Pub-sub: 1 message → N subscribers (fan-out). |
| 26 | Default delivery guarantee and consequence? | At-least-once → consumers must be idempotent. |
| 27 | Where does Kafka preserve ordering? | Within a partition. Across partitions, no guarantee. |
| 28 | DLQ — purpose? | Poison-message isolation after N retries; alert on depth. |
| 29 | Kafka EOS requires what three parts? | Idempotent producer + transactional writes + consumer offsets committed in same tx. |

---

## 🔷 7. Distributed Transactions (`distributed_transactions.md`)

| # | Question | Answer |
|---|---|---|
| 30 | Why avoid 2PC across microservices? | Blocking on coordinator, SPOF, poor scale, distributed locks. |
| 31 | Saga — one sentence? | Sequence of local transactions with compensating actions on failure. |
| 32 | Choreography vs orchestration? | Choreography: services publish/subscribe to events; orchestration: central workflow engine drives steps. |
| 33 | Sagas lack what ACID property? | Isolation — other transactions may see intermediate states. |

---

## 🔷 8. Consensus (`distributed_consensus.md`)

| # | Question | Answer |
|---|---|---|
| 34 | Quorum formula? | ⌊N/2⌋ + 1 (strict majority). |
| 35 | 5 nodes tolerate how many failures? | 2. Quorum = 3. |
| 36 | Why randomized election timeout in Raft? | Prevents split votes by avoiding simultaneous elections. |
| 37 | Can Raft-backed systems be AP? | No. They refuse progress on the minority side during a partition → CP. |

---

## 🔷 9. Rate Limiting (`rate_limiting.md`)

| # | Question | Answer |
|---|---|---|
| 38 | Default algorithm? | Token bucket in Redis via atomic Lua script. |
| 39 | 429 response should include? | `Retry-After` header + structured error body. |
| 40 | What if the rate limiter itself is down? | Fail-open (allow traffic, alert) — failing closed takes down your whole platform. |
| 41 | Why is per-IP sometimes bad? | Shared NAT (office, mobile carriers) — many legitimate users look like one. |

---

## 🔷 10. Resilience (circuit breaker, retries)

| # | Question | Answer |
|---|---|---|
| 42 | Three circuit breaker states? | Closed (normal), Open (fail fast), Half-open (single probe to test recovery). |
| 43 | Retry pattern that avoids amplifying outages? | Exponential backoff + jitter + cap. |
| 44 | Why jitter specifically? | Randomizes retry times so 1000 clients don't synchronize into a thundering herd. |

---

## 🔷 11. Networking (`network_protocols.md`)

| # | Question | Answer |
|---|---|---|
| 45 | Why does HTTP/3 use UDP? | Avoids TCP's head-of-line blocking; each QUIC stream is independent. |
| 46 | What's an ephemeral port? | OS-picked short-lived source port on a client — unique per outgoing connection. |
| 47 | Why does TLS 1.3 matter for mobile users? | 1-RTT handshake (0-RTT with resumption) — saves 100 ms on every new connection. |
| 48 | HOL blocking in HTTP/2 — one sentence? | One lost TCP packet freezes all 10 multiplexed streams until retransmit. |

---

## 🔷 12. CAP / Consistency

| # | Question | Answer |
|---|---|---|
| 49 | "Pick two" — honest version? | P is mandatory (partitions happen). During partition, pick C or A. |
| 50 | Cassandra classification in PACELC? | PA/EL — AP under partition, latency-first in normal ops. |
| 51 | When is eventual consistency the wrong choice? | Money, inventory, uniqueness, authentication. Anywhere two truths = a bug. |

---

## 🔷 13. Observability (`observability_logging_alerts.md`)

| # | Question | Answer |
|---|---|---|
| 52 | Three pillars? | Metrics, logs, traces. |
| 53 | RED method — what three signals? | Rate, Errors, Duration. |
| 54 | Burn rate alert — what does "14.4×" mean? | You're burning 30-day error budget 14.4× faster than sustainable → urgent page. |
| 55 | Why is high tag cardinality a killer for Prometheus? | Each unique label combination is a new time series → memory explodes. |

---

## 🔷 14. Real-time & Geo

| # | Question | Answer |
|---|---|---|
| 56 | Pick between WebSocket / SSE / long-polling for chat? | WebSocket (bidirectional, persistent). |
| 57 | What does H3 give over geohash? | Hexagonal cells (uniform neighbor distance); better for proximity queries. |
| 58 | How does surge pricing scale? | Compute per-cell supply/demand ratio in near-real-time; multiplier per cell. |

---

## 🔷 15. Containers / Microservices

| # | Question | Answer |
|---|---|---|
| 59 | Namespaces vs cgroups? | Namespaces isolate what a process sees (PID, net, mount). Cgroups cap what it can use (CPU, RAM, I/O). |
| 60 | Three prereqs before going microservices? | CI/CD per service, distributed tracing, on-call maturity. (Also: service discovery, feature flags, logging.) |

---

## 📊 Scoring & Next Steps

| Score band | Meaning |
|---|---|
| ≥54/60 (90%) | Interview-ready — rehearse the 5 hardest. |
| 42–53 (70–88%) | Solid. Re-read files for any 2+ wrong answers per category. |
| <42 | Block a weekend; re-read the 7-day plan in `index.md`. |

### Where each category maps

| Category | Revise this file |
|---|---|
| LB | [`load_balancing.md`](load_balancing.md) |
| Caching | [`caching.md`](caching.md) |
| DBs + NoSQL | [`databases.md`](databases.md), [`nosql_internals.md`](nosql_internals.md) |
| Replication | [`database_replication.md`](database_replication.md) |
| Sharding | [`databases.md`](databases.md) |
| Messaging | [`message_queues_and_pubsub.md`](message_queues_and_pubsub.md) |
| Dist Tx | [`distributed_transactions.md`](distributed_transactions.md) |
| Consensus | [`distributed_consensus.md`](distributed_consensus.md) |
| Rate Limit | [`rate_limiting.md`](rate_limiting.md) |
| Networking | [`network_protocols.md`](network_protocols.md) |
| CAP | [`databases.md`](databases.md), [`00_quick_revision.md`](00_quick_revision.md) |
| Observability | [`observability_logging_alerts.md`](observability_logging_alerts.md) |
| Real-time / Geo | [`location_based_services.md`](location_based_services.md) |
| Containers / µservices | [`containers_docker.md`](containers_docker.md), [`microservices.md`](microservices.md) |

---

## 🧠 5 Hardest Questions (most candidates miss)

1. **Q29** — Kafka EOS's three components (walkthrough in `message_queues_and_pubsub.md`).
2. **Q16** — W+R>N math for strong consistency.
3. **Q44** — *Why jitter specifically* (most remember backoff, forget jitter).
4. **Q54** — Burn rate math (many learn SLO, not the alert math).
5. **Q22** — Virtual nodes *solve what* (most know "consistent hashing" but can't explain uneven load).

Nail these 5 and you've passed the "does this person actually understand it?" bar.
