# ⚡ 00 · Quick Revision — All of System Design in 2–3 Pages

> Read this in the last 30 min before an interview. Everything else is detail.

---

## The 4-step interview script

1. **Clarify** — core use cases, scale (DAU, QPS), consistency, latency budget. Write a one-line contract at the top.
2. **Estimate** — QPS, storage/day, storage/year, peak = 2–3× avg.
3. **High-level arch** — client → edge → LB → API/GW → services → cache → DB → async workers. Justify each box.
4. **Deep dive** — on the component the interviewer picks. Cover: data model, shard key, replication, index, cache, failure mode.

---

## Numbers to know cold

| Latency | Typical |
|---|---|
| RAM | 100 ns |
| SSD | 100 μs |
| HDD | 10 ms |
| Same-DC RTT | 0.5 ms |
| Cross-country RTT | 50 ms |
| Cross-ocean RTT | 200 ms |

| Capacity | Ballpark |
|---|---|
| Single DB node | 10k–50k QPS |
| Single Redis node | 100k+ QPS |
| 1 year | 31.5 M seconds |

---

## The "always pick this first" table

| Problem | Default first pick |
|---|---|
| Read >> write | Cache (Redis) in front |
| Write > single-node ceiling | Shard via consistent hashing |
| Global static content | CDN |
| Async coordination across services | Message queue / Kafka |
| Read-heavy complex query | Read replica + denormalized view |
| Bursty traffic | Queue + worker pool (backpressure) |
| Need strong consistency (money, auth) | SQL with ACID |
| Flexible schema, horizontal scale | NoSQL (Document/Wide-column) |
| Real-time bi-dir client | WebSocket (+ sticky routing) |
| Rate limiting | Token bucket in Redis |
| Cascading failure prevention | Circuit breaker + timeouts + retries with jitter |

---

## Consistency decision

- Money, inventory, auth → **strong (ACID / CP)**.
- Feed, counts, likes, recommendations → **eventual (BASE / AP)**.
- Ask per data type. Never one answer for the whole system.

---

## Sharding strategy

- **Hash** — even spread; use **consistent hashing** to avoid remap-everything on rebalance.
- **Range** — good for range queries; risk of hot shards (e.g., latest-timestamp).
- **List** — explicit (geography, tenant).
- **Lookup table** — max flexibility, central metadata.

Pick a shard key that matches the dominant query pattern + has high cardinality + low skew.

---

## Write/read patterns

**Fan-out on write (push)** — write to all followers' feeds on post. Read = 1 lookup. Good for normal users.
**Fan-out on read (pull)** — on feed load, query all followed users. Good for celebrities.
**Hybrid** — most systems (Twitter).

---

## Cache strategies

- **Cache-aside** (lazy) — app checks cache first; on miss, fetch + populate. Most common.
- **Write-through** — write to cache + DB simultaneously. Consistent but slower writes.
- **Write-back** — write to cache, async to DB. Fast but durability risk.
- **Write-around** — write skips cache, goes to DB. First read after write = miss.

**Stampede fixes**: request coalescing, TTL jitter, stale-while-revalidate.

---

## Common patterns (compressed)

- **Circuit breaker** — open on N failures, half-open probe, close on success.
- **Retry with exponential backoff + jitter** — never retry without jitter.
- **Idempotency key** on every mutating endpoint.
- **Saga** for multi-service transactions (compensations on failure).
- **Outbox pattern** — write event to same DB tx, ship via CDC.
- **Backpressure** — queue fills → reject new work, not drop existing.

---

## CAP / PACELC crib

- Partition happens → pick **C** (reject writes) or **A** (serve stale).
- No partition → pick **Latency** or **Consistency** (PACELC).
- Cassandra: PA/EL. MongoDB: PA/EC. HBase: PC/EC. Pick per workload.

---

## Failure mode cheat sheet

| Box dies | Mitigation |
|---|---|
| One service instance | LB health check evicts; autoscaler replaces |
| DB primary | Promote replica; write downtime brief |
| Cache | Stampede protection; fall back to DB gracefully |
| Region | Multi-region active-active + DNS failover |
| Message queue | Broker HA; DLQ for poison messages |

---

## What seniors say (phrases to land)

- "I picked X over Y because ___. Cost: ___."
- "My biggest failure mode is ___; I'd mitigate with ___."
- "For this data I need strong consistency; for this data eventual is OK because ___."
- "I'd instrument this with p50/p95/p99 + error rate + saturation, alert on burn rate."
- "If traffic 10×, the bottleneck becomes ___."

---

## Red flags to avoid

- ❌ Picking components before clarifying scale.
- ❌ "Just add a cache/queue" without numbers.
- ❌ Strong consistency everywhere.
- ❌ No mention of failure modes.
- ❌ No monitoring/observability.
- ❌ Microservices for a 3-person team.

---

## 30-second recap

System design = **clarify → estimate → build left-to-right (client → edge → service → data) → justify every box with failure story + tradeoff → wrap with SLO/observability/cost**.

Every component exists because without it, the system fails at some specific scale or condition. Be able to say what that is.
