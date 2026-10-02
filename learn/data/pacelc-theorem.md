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
- Concrete latency numbers for sync-replication RTT costs.
- Spanner's TrueTime — how Google made strong consistency + low latency possible globally (via GPS + atomic clocks).
