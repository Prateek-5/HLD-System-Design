# ACID and BASE Consistency Models

## A. Intuition First
ACID = strict guarantees. BASE = looser, scale-friendly. They're opposite ends of a spectrum. Real systems pick per-data-type: ACID for money, BASE for activity feeds.

## B. Mental Model
### ACID
- **Atomic**: all-or-nothing.
- **Consistent**: invariants hold before & after (FK constraints, uniqueness).
- **Isolated**: concurrent tx's look serial.
- **Durable**: committed data survives crash.

### BASE
- **Basically Available**: the system keeps serving, possibly with stale data.
- **Soft state**: state may drift between replicas.
- **Eventual consistency**: given no new writes, replicas converge.

## C. Internal Working
### How ACID is achieved
- **Atomicity + Durability**: via WAL + fsync + rollback.
- **Isolation**: via 2PL (locks) or MVCC (versioning). Different **isolation levels** trade consistency for throughput (READ COMMITTED, REPEATABLE READ, SERIALIZABLE).
- **Consistency**: DB-level constraints enforced at commit.

### How BASE is achieved
- Async replication; conflict resolution after the fact.
- Quorum reads/writes tune staleness.
- Write optimistically; reconcile asynchronously.

## D. Visual Representation
```
ACID:  Write → all replicas sync → ack          (strong, slow)
BASE:  Write → primary ack → replicas async      (fast, may be stale)
```

## E. Tradeoffs
- ACID costs latency and limits horizontal scale.
- BASE costs developer cognitive load (handle stale reads, conflicts).
- Choose per data. Cart checkout = ACID. "Likes count" = BASE (eventual).

## F. Interview Lens
- "Explain ACID." — word-perfect is expected.
- "What's the difference between ACID and BASE?"
- "Why can't a banking system be eventual-consistent?" — if two ATMs withdraw at once from a stale balance, you get a negative account.
- Pitfalls: saying "NoSQL = BASE" — many NoSQL (DynamoDB, MongoDB recent versions) now support ACID transactions.

## G. Real-World Mapping
- Postgres, MySQL, Spanner, CockroachDB: ACID.
- Cassandra, DynamoDB (default), Riak: BASE-y; tunable.
- S3 used to be eventually consistent; now strongly consistent (2020).

## H. Questions
**Beginner**: What does ACID stand for?
**Intermediate**: Isolation levels?
**Advanced**:
1. Design a system where reads are BASE but specific flows (checkout) require ACID.
2. Explain serializable vs snapshot isolation.

## I. Mini Design
Shopping cart: each item add is idempotent → eventually consistent is OK. Checkout: transaction across cart + inventory + payment → ACID required.

## J. Cross-Topic Connections
- [SQL](sql-databases.md), [NoSQL](nosql-databases.md), [CAP](cap-theorem.md), [PACELC](pacelc-theorem.md), [Transactions](transactions.md).

## K. Confidence Checklist
- [ ] Can recite ACID + BASE.
- [ ] Knows different data types need different guarantees.
- [ ] Knows isolation levels exist.

### Red flags
- ❌ Believing ACID and BASE are a binary choice per-system.

## L. Potential Gaps & Improvements
- Isolation-level anomalies (dirty read, non-repeatable, phantom) deserve deep dive.
- Snapshot isolation vs serializable.
- Linearizability (another level above ACID) — missing.
