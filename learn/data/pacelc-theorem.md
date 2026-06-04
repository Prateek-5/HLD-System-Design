# PACELC Theorem — CAP's Honest Cousin

## A. Intuition First
CAP only talks about what happens during a **partition**. PACELC adds: *even when there's no partition (E = else), you still trade **Latency** vs **Consistency**.*

Real systems spend 99.99% of time in the "else" state. The latency-vs-consistency call is the one you make every day.

## B. Mental Model
If Partition → Availability vs Consistency (A/C).
Else → Latency vs Consistency (L/C).

Classification:
- **PA/EL** — Cassandra (AP under P, low-latency/eventually-consistent in normal ops).
- **PC/EC** — HBase, BigTable (consistency-first under all conditions).
- **PA/EC** — MongoDB's default (AP under partition, consistent in normal ops).
- **PC/EL** — rare.

## C. Internal Working
Why latency-vs-consistency tension exists in normal ops:
- Strong consistency requires coordination (quorum read/write, sync replication). Coordination = more RTTs = more latency.
- Eventual consistency lets you serve from the nearest replica without waiting.

## D. Visual Representation
```
Partition: C vs A
Else:      C vs L
         ───────────────
Cassandra: A | L        (speed over correctness)
HBase:     C | C        (correctness over speed)
MongoDB:   A | C        (up under partition, consistent in steady state)
```

## E. Tradeoffs
- PACELC forces you to be honest: you're trading off **all the time**, not only during rare partitions.
- Explicitly picking per-service is the mark of a senior designer.

## F. Interview Lens
- "What does PACELC say that CAP doesn't?" — latency/consistency in normal ops.
- "Classify DB X as PACELC." — good signal.
- "Design a system that's PC/EC for payments and PA/EL for browsing."

## G. Real-World Mapping
Same as CAP-mapping; PACELC just adds the second axis.

## H. Questions
**Beginner**: What does PACELC add to CAP?
**Intermediate**: Classify Cassandra and MongoDB.
**Advanced**: Design a global system with explicit PACELC choices per workload.

## I. Mini Design
Geo-distributed e-commerce:
- Payments service: PC/EC (Spanner or CockroachDB — sync replication, synchronous consistency).
- Product catalog reads: PA/EL (CDN + read replicas, accept minutes of staleness).

## J. Cross-Topic Connections
- [CAP](cap-theorem.md), [Replication](database-replication.md).

## K. Confidence Checklist
- [ ] Can classify a DB using PACELC.
- [ ] Knows latency vs consistency is a *constant* call, not only during partitions.

## L. Potential Gaps & Improvements
- **RTT (Round-Trip Time)** — the time a request takes to reach a peer and return; concrete sync-replication RTT numbers (e.g. ~1ms same-AZ vs ~70ms cross-region) make the "consistency costs latency" tradeoff tangible.
- **Sync vs async replication** — whether a write waits for replicas to acknowledge (sync = consistent but slow) or returns immediately (async = fast but stale); this is the exact knob PACELC's L-vs-C axis describes.
- **Spanner's TrueTime** — Google's clock API that bounds time uncertainty using GPS and atomic clocks, letting Spanner give strong consistency at low latency globally; the standout proof that PC/EC can be made fast.
- **Quorum (R + W > N)** — requiring a majority of replicas to agree on reads/writes so you never read stale data; tunable quorums let you slide along the latency-vs-consistency line per query (→ see Internal Working).

**🔧 How to close:** Spin up a 3-node CockroachDB cluster with `docker compose` (their official quickstart), then run `SET CLUSTER SETTING ...` and time the same `INSERT` with `EXPLAIN ANALYZE` — compare a local single-node write against a write that must reach a quorum across simulated regions to feel the RTT cost of strong consistency yourself.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### ⏱️ Gap 1 — RTT & Sync vs Async Replication (the L-vs-C knob)
- 🔹 **What it is**: RTT (Round-Trip Time) is how long a request takes to reach a replica and come back; **sync replication** waits for replicas to acknowledge a write (consistent but slow), while **async replication** returns immediately (fast but possibly stale).
- 🔹 **Why it matters**: This is the *physical* reason the latency-vs-consistency axis exists — coordination costs measurable milliseconds, and that cost is what PACELC's "E = else" branch is trading.
- 🔹 **Connection**: This file's Internal Working says "coordination = more RTTs = more latency." Sync vs async is literally the dial that sets where you land on that line.
- 🔹 **When needed**: 🟢 **Foundational** — every reader designing replication makes this call; it shows up in most mid-level interviews.
- 🔹 **Intuition**: Sending a group text and *waiting for everyone to read-receipt before you act* (sync) vs sending it and carrying on, trusting it'll arrive (async). A reply across town (~1ms) is instant; a reply overseas (~70ms) you feel.
- 🔹 **If you go deeper**: Read PostgreSQL's `synchronous_commit` levels (`on`, `remote_apply`, `off`) and try MySQL semi-sync replication — both let you dial the exact sync/async behavior PACELC describes.
- 🔹 **Interview hook**: *"Why does strong consistency cost latency in normal operation?"* → because a consistent write must block on at least one cross-node/cross-region RTT for acknowledgment before it returns.

---

#### 🗳️ Gap 2 — Tunable Quorums (R + W > N)
- 🔹 **What it is**: A rule where reads contact `R` replicas and writes contact `W` replicas out of `N` total; if `R + W > N` you're guaranteed to read at least one replica that has the latest write, so you never read stale data.
- 🔹 **Why it matters**: It turns the latency-vs-consistency tradeoff from a fixed product choice into a *per-query slider* — the most concrete way to "be honest about trading off all the time."
- 🔹 **Connection**: The Gaps bullet names this directly, and the body's PA/EL example (Cassandra) is exactly the system where you tune `R` and `W` per query to slide along PACELC's L/C axis.
- 🔹 **When needed**: 🟡 **Mid-level** — essential once you've used a tunable-consistency store like Cassandra or DynamoDB.
- 🔹 **Intuition**: A vote among 5 judges. Ask only 1 judge (fast, might catch a stale opinion) or insist a majority agree (slower, but you trust the verdict). `R + W > N` just means the "ask" and "tell" groups always overlap by at least one judge.
- 🔹 **If you go deeper**: Read the Amazon Dynamo paper (2007) on quorums and read-repair, then set `CONSISTENCY ONE` vs `QUORUM` in `cqlsh` against a multi-node Cassandra cluster and observe the latency and staleness difference.
- 🔹 **Interview hook**: *"How do you read strongly from an eventually-consistent store without going fully synchronous?"* → tune `R + W > N` so read and write quorums overlap.

---

#### 🛰️ Gap 3 — Spanner's TrueTime (making PC/EC fast)
- 🔹 **What it is**: A Google clock API backed by GPS receivers and atomic clocks that returns a *bounded interval* of the current time rather than a single timestamp, letting Spanner order transactions globally with externally-consistent guarantees.
- 🔹 **Why it matters**: It's the standout proof that the PC/EC corner doesn't *have* to be slow — TrueTime lets Spanner give strong consistency at global scale, breaking the usual "consistency = high latency" assumption.
- 🔹 **Connection**: The body classifies PC/EC (HBase, BigTable) as "correctness over speed" and your Mini Design picks Spanner for payments — TrueTime is *why* Spanner can be the PC/EC choice without crippling latency.
- 🔹 **When needed**: 🔴 **Senior** — deep distributed-systems infra; great signaling, rarely required day-to-day.
- 🔹 **Intuition**: Instead of each office clock claiming "it's exactly 3:00:00," every clock honestly says "it's somewhere between 3:00:00 and 3:00:07." If you simply wait out that 7ms uncertainty before committing, everyone agrees on ordering without phoning each other.
- 🔹 **If you go deeper**: Read the Spanner paper (Corbett et al., OSDI 2012), focusing on the "commit wait" and the `TT.now()` interval; compare with how CockroachDB approximates the same idea using HLCs (Hybrid Logical Clocks) without atomic clocks.
- 🔹 **Interview hook**: *"How can a globally-distributed database be both strongly consistent and low-latency?"* → bound clock uncertainty (TrueTime) and wait out the uncertainty window rather than coordinating on every read.

---

### 🏆 Start here if you have limited time
1. **RTT & Sync vs Async Replication** — it's the foundation that makes every other PACELC tradeoff click, and it's the most common interview question.
2. **Tunable Quorums (R + W > N)** — the concrete mechanism interviewers expect you to name when asked how to slide between consistency and latency.

---

### 🧭 Suggested Deep Dive Order
1. **RTT & Sync vs Async Replication** (~30 min; foundational — makes the L-vs-C axis physical).
2. **Tunable Quorums** (~1h; hands-on with Cassandra/Dynamo, widely applicable).
3. **Spanner's TrueTime** (~1.5h; senior-infra signaling — the proof PC/EC can be fast).
