# ⚡ 04 · Confusion Resolver — Traps That Trip Up Most Engineers

> For each recurring misunderstanding: what people get wrong, and the one-sentence resolution.
> Use this file **before an interview** to avoid the traps; use **during study** whenever something feels subtly off.

---

## 🔷 Networking

### ❗ "L4 vs L7 is a performance thing"
✅ **Clarification**: It's a **visibility + capability** thing first, performance second. L4 *cannot* route on URL or host header — that's not a tuning knob, it's a hard architectural limit. Pick L7 if you need any of: path routing, cookie stickiness, TLS termination at edge, HTTP caching, WAF. Pick L4 only if you don't need those and want raw throughput.

### ❗ "TLS is end-to-end between my client and my backend"
✅ **Clarification**: In almost every real production setup, TLS terminates at the LB/reverse proxy. Backends speak plaintext HTTP inside the trusted network (or mTLS for zero-trust). "End-to-end TLS" requires backends running TLS themselves and the LB doing *passthrough* mode.

### ❗ "HTTP/2 is always faster than HTTP/1.1"
✅ **Clarification**: HTTP/2 multiplexes over one TCP, but one lost packet head-of-line-blocks **all** streams. On lossy networks (mobile, crowded WiFi), HTTP/1.1 with 6 parallel connections can be *faster*. HTTP/3 (QUIC) fixes this properly by running independent streams over UDP.

### ❗ "DNS is fast / DNS is slow"
✅ **Clarification**: DNS feels fast because **everyone has cached answers**. A cold lookup (no resolver cache anywhere) is 4 round trips across continents = 50–200 ms. TTLs are how you trade freshness for speed.

### ❗ "NAT changes the client's IP"
✅ **Clarification**: NAT changes both **source IP AND source port** (PAT — port address translation). The port rewrite is what lets many clients share one public IP without collision.

---

## 🔷 Caching

### ❗ "Cache-aside and write-through are opposites"
✅ **Clarification**: They address different axes. **Cache-aside** is about how *reads* populate the cache. **Write-through / around / back** are about how *writes* propagate. You can combine: most apps use cache-aside reads + explicit invalidate/update on writes.

### ❗ "Eventual consistency = slow"
✅ **Clarification**: Eventual consistency is usually *faster* (no cross-node coordination). The "eventual" is about correctness, not latency — there's a small window where different readers see different values. A strongly-consistent cache is typically *slower* per operation.

### ❗ "High cache hit rate means cache is healthy"
✅ **Clarification**: Hit rate is an *average*. The 1% misses can cluster on hot keys that all expire together → DB sees 1000× spike. Look at absolute miss QPS and p99 miss latency.

### ❗ "Redis is a cache"
✅ **Clarification**: Redis *can* be a cache but is much more — it's an in-memory data-structure server. Used as session store, rate limiter, leaderboard (sorted sets), geo index, pub-sub, job queue, lock store (with caveats), and yes, cache. Treating it as "just a cache" throws away 80% of its value.

---

## 🔷 Databases

### ❗ "NoSQL = no ACID"
✅ **Clarification**: Outdated. MongoDB (4.0+), DynamoDB (transactions API), Cassandra (lightweight transactions via Paxos), and Spanner/CockroachDB all offer ACID with caveats. Classification is per-operation now, not per-DB.

### ❗ "Sharding is how you make a SQL database horizontal"
✅ **Clarification**: Sharding spreads *data*. You also need to think about: routing queries to the right shard, cross-shard joins (usually avoid), cross-shard transactions (use sagas), rebalancing on node add/remove (consistent hashing), and shard-aware backups/restores. Sharding is an ecosystem, not a single decision.

### ❗ "Primary-replica async is safe because it's fast"
✅ **Clarification**: On primary crash, any writes that were acked but not yet shipped to replicas are **lost**. For a bank ledger, that's unacceptable. For a Twitter feed, it's fine. Know what your data can tolerate.

### ❗ "ACID solves all my concurrency problems"
✅ **Clarification**: ACID is **within one DB node (or cluster)**. It does not extend across services or DBs. For cross-service atomicity, you need sagas + compensations + idempotent consumers.

### ❗ "Index makes everything faster"
✅ **Clarification**: Index accelerates the *read* it matches and *slows every write* that touches it (must update the index too). A table with 10 indexes pays 10× write cost. Also: indexes consume RAM (buffer pool) and disk. Over-indexing is a real anti-pattern.

### ❗ "Left-most prefix is about physical ordering"
✅ **Clarification**: It's about what queries the index can *accelerate*. A composite index on `(a, b, c)` helps queries filtering by `a`, `(a,b)`, or `(a,b,c)`. It does NOT help queries filtering only by `b` or `c`.

---

## 🔷 Consistency Models

### ❗ "CAP says pick two"
✅ **Clarification**: P is mandatory (network partitions happen). The real choice is **C or A during a partition**. "CA" only makes sense for a single-node system.

### ❗ "Eventual consistency means immediately consistent after X seconds"
✅ **Clarification**: It means *replicas will converge given no new writes*, but there's no upper bound. On a long partition, you could be divergent for hours. Most systems give you SLAs like "99% of reads see data within 100ms of write" — that's a different guarantee.

### ❗ "Linearizability = Serializability"
✅ **Clarification**: **Linearizability** = single-operation ordering as if there's a global clock. **Serializability** = transaction-level: concurrent transactions look as if run one-at-a-time. You can have serializable-but-not-linearizable (Postgres snapshot isolation) and linearizable-but-not-serializable. Both together = strictest guarantee, most expensive.

### ❗ "Strong consistency is always better"
✅ **Clarification**: Strong consistency pays in latency + availability under partition. For 80% of data (feeds, likes, views, recommendations), eventual is correct **and** cheaper. Designing everything strongly consistent is over-engineering.

---

## 🔷 Messaging

### ❗ "Exactly-once delivery is a thing"
✅ **Clarification**: At-least-once + idempotent consumers = *effectively once*. True exactly-once delivery in a distributed system is mathematically impossible without coordinated clocks + consensus. Kafka EOS is a specific pattern (idempotent producer + transactional writes + read-process-write tx) that approximates it *within Kafka*.

### ❗ "Kafka guarantees order"
✅ **Clarification**: Within a partition. Across partitions, no. To keep related events ordered, **key them the same** so they hash to the same partition.

### ❗ "A queue is just a list of messages"
✅ **Clarification**: A durable queue is a small distributed system: replication, visibility timeouts, ack/retry state, DLQ, cross-consumer coordination. That's why "just use Postgres as a queue" falls over at scale.

### ❗ "At-least-once means I'll get the message twice sometimes"
✅ **Clarification**: You'll *probably* get it once, but might get it 2 or 20 times on network turbulence. Design for idempotency, not "twice" specifically.

---

## 🔷 Distributed Transactions

### ❗ "2PC works fine, people just don't understand it"
✅ **Clarification**: 2PC's correctness is sound in theory. The operational problem is **blocking on coordinator crash**: participants sit in prepared state holding locks until manual recovery. In microservice systems with thousands of transactions/sec, this is a ticking timebomb.

### ❗ "Sagas are just 2PC without the coordinator"
✅ **Clarification**: Sagas have **no isolation**. Other transactions see intermediate states. In 2PC, the whole transaction is atomic and isolated. Sagas trade isolation for liveness — a very different correctness model.

### ❗ "Compensation = rollback"
✅ **Clarification**: Rollback undoes a change silently. **Compensation is a new forward action** — you can't un-send a payment, you issue a refund. Model the business semantics, not a technical undo.

---

## 🔷 Consensus

### ❗ "More nodes = better consensus"
✅ **Clarification**: More nodes = more message passing per decision. 3 or 5 is the sweet spot. 7 only when tolerating 3 simultaneous failures is worth the round-trip cost.

### ❗ "Raft is just Paxos with a simpler API"
✅ **Clarification**: Raft adds **strong leadership** (one leader at a time per term) and **log-oriented replication** (rather than value-oriented). These constraints are what make Raft understandable — but they also mean Raft has a single-leader throughput ceiling that multi-Paxos doesn't.

### ❗ "Consensus is always strongly consistent"
✅ **Clarification**: Consensus guarantees agreement on the next log entry, but reads from a follower can be stale. **Linearizable reads** require either going to the leader or using a "read index" protocol with lease/heartbeat checks.

---

## 🔷 Resilience

### ❗ "Retry + timeout = resilient"
✅ **Clarification**: Naive retries amplify outages (retry storm). You need:
1. Timeout per call.
2. **Exponential backoff + jitter**.
3. A **retry budget / cap**.
4. **Circuit breaker** to stop retrying a dead downstream.
5. **Idempotency keys** on mutating calls.

### ❗ "Circuit breaker prevents all cascading failures"
✅ **Clarification**: Circuit breaker protects **you** from a sick downstream. It doesn't help if **you** are the slow one — for that you need load shedding, backpressure, and bulkheads (resource isolation per dependency).

### ❗ "Backoff protects the downstream"
✅ **Clarification**: Only with **jitter**. Without jitter, 1000 clients retry at identical intervals → synchronized thundering herd. Jitter is the load-spreading mechanism; backoff alone just delays the stampede.

---

## 🔷 Observability

### ❗ "If I log everything, I'm observable"
✅ **Clarification**: Logs alone don't aggregate into "how healthy is my service?" You need metrics (aggregates), logs (details), and traces (end-to-end causality). Logs without trace IDs = useless during a cross-service incident.

### ❗ "Alert on CPU > 80%"
✅ **Clarification**: Alert on **symptoms users experience** (error rate, latency, SLO burn rate), not causes. A service at 95% CPU that's still within latency SLO doesn't need a page.

### ❗ "SLO = SLA"
✅ **Clarification**: **SLO** is internal target (what engineering commits to). **SLA** is external contract (what customers get a refund for). SLOs are usually **stricter** than SLAs — you want buffer before you owe money.

### ❗ "I want 100% uptime"
✅ **Clarification**: 100% is impossible *and undesirable* — leaves zero error budget for risky changes (new features, migrations). Google SRE's error budget model uses the "allowed" downtime as a release-velocity lever.

---

## 🔷 Microservices & Containers

### ❗ "Microservices scale better than monoliths"
✅ **Clarification**: Microservices scale **teams and fault domains**, not necessarily throughput. A well-tuned monolith on modern hardware handles enormous QPS. Split when *team coordination* becomes the bottleneck, not "for scale".

### ❗ "Containers are lightweight VMs"
✅ **Clarification**: Containers share the host kernel — isolation is weaker (escape via kernel exploit is possible). For multi-tenant untrusted workloads, use microVMs (Firecracker) or full VMs.

### ❗ "Service mesh = API gateway"
✅ **Clarification**: Gateway sits at the **edge** (north-south, external traffic). Mesh sidecars handle **internal** (east-west, service-to-service). They solve overlapping concerns (auth, mTLS, routing) in different layers — most large orgs run both.

### ❗ "Shared DB between microservices is fine"
✅ **Clarification**: It's the single biggest anti-pattern in microservices. You get tight schema coupling, distributed-deploy coordination on schema changes, and no independent evolution. **Each service owns its data.** Sync to shared analytics via CDC.

---

## 🔷 Rate Limiting

### ❗ "Limit by IP — easy and fair"
✅ **Clarification**: Shared NAT (corporate offices, mobile carriers) makes thousands of real users look like one. You punish legitimate users and miss distributed attackers. **Auth first + limit per user** is the correct default.

### ❗ "Fail the request if the rate limiter is down"
✅ **Clarification**: **Fail-open** by default. Better to allow a brief excess than take the whole platform down over a Redis hiccup. Exception: security-sensitive endpoints (auth, payment).

### ❗ "Fixed window is simpler than sliding window"
✅ **Clarification**: Simpler, yes — but has a **2× burst at window boundary** (e.g., all of minute-1's budget used at 59s, then minute-2's used at 00s → 2× rate briefly). Sliding window counter is the default for this reason.

---

## 🔷 CDN / Caching (Layered)

### ❗ "CDN handles dynamic content fine"
✅ **Clarification**: CDN shines on static or URL-keyable content. Personalized dynamic content requires edge compute (Cloudflare Workers, Lambda@Edge) or origin round-trip. Don't promise CDN benefits for logged-in dashboards.

### ❗ "Purge the CDN when I update something"
✅ **Clarification**: CDN purges propagate *over seconds to minutes* globally. For user-visible instant updates, use **immutable URLs** (e.g., `file.v42.jpg`) + long TTL. Change the URL on update; old one eventually expires.

---

## 🔷 Real-time

### ❗ "WebSocket is always the right choice for real-time"
✅ **Clarification**: Only if you need **bi-directional**. For server-only push (notifications, ticker), **SSE** is simpler, auto-reconnects, works through proxies, and doesn't need upgrade dance. Use WS when the client also publishes.

### ❗ "Long-polling is primitive and should never be used"
✅ **Clarification**: It's a valid fallback on restrictive networks (corporate proxies that block WS). Still used as a fallback tier. Just not the default.

---

## 🔷 Design Tradeoffs (meta)

### ❗ "There's a right answer to this design question"
✅ **Clarification**: There's a *defensible* answer given a set of stated requirements. The interview is about whether you can **state the requirements, pick a design, and articulate the tradeoffs you rejected**. Naming alternatives + reasons ≫ picking correctly.

### ❗ "Adding X component will fix performance"
✅ **Clarification**: Derive X from numbers. "200k QPS means 1 DB node can't serve it, so we add a cache absorbing 95%+ reads" beats "let's add a cache" with no math. Numbers → architecture.

### ❗ "Strong consistency + low latency + high availability — we'll figure it out"
✅ **Clarification**: You can't have all three simultaneously in a distributed system under failures (CAP + PACELC). Pick per data type:
- Payments → strong + sacrifice latency/availability on partition.
- Feeds → eventual + low latency.
- Auth tokens → strong + cached aggressively.

Articulating this *per data type* is senior signal.

---

## 🧭 Using this file

1. **Before an interview**: read end-to-end. Each item is 30 seconds; whole file ~15 minutes.
2. **During design discussions**: if you feel yourself about to parrot a cached phrase ("just use a cache", "CAP says pick two"), stop — check here.
3. **Add your own**: every time an interviewer catches you in a misconception, add the pair here. Your own confusion resolver > a generic one.

### Companion files
- [`00_quick_revision.md`](00_quick_revision.md) — everything compressed.
- [`01_interview_patterns.md`](01_interview_patterns.md) — 10 patterns behind 80% of questions.
- [`02_quiz.md`](02_quiz.md) — 60-question timed test.
- [`03_interview_mode.md`](03_interview_mode.md) — Q→A with answer locations + decision frameworks.
