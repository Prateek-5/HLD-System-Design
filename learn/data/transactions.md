# Transactions — A Unit of Work

## A. Intuition First
A transaction groups multiple ops as one: either all succeed or none do. The DB takes care of the "or none" part.

## B. Mental Model
- **BEGIN** → work → **COMMIT** (persist) or **ROLLBACK** (undo).
- Governed by ACID.
- Concurrent transactions may interact; **isolation levels** define how much.

### States
Active → Partially committed → Committed → Terminated.
Or Active → Failed → Aborted → Terminated.

### Isolation levels (low → high)
- **Read Uncommitted**: sees other's uncommitted writes. Very bad.
- **Read Committed**: sees only committed writes. Postgres default.
- **Repeatable Read**: sees a stable snapshot for the tx. MySQL InnoDB default.
- **Serializable**: tx's look executed one-at-a-time. Slowest, safest.

Anomalies by level:
- Dirty read → blocked at Read Committed+.
- Non-repeatable read → blocked at Repeatable Read+.
- Phantom read → blocked at Serializable (and snapshot isolation in Postgres).

## C. Internal Working
### 2PL (Two-Phase Locking)
- Growing phase: acquire locks.
- Shrinking phase: release only after commit.
- Prevents anomalies; can deadlock → detect + abort one.

### MVCC (Postgres, MySQL InnoDB)
- Each write creates a new row version with a transaction ID.
- Readers see a consistent snapshot (don't block writers, nor vice versa).
- Vacuum / purge removes obsolete versions.

## D. Visual Representation
```
T1:   BEGIN ─ R(x) ─ W(x) ─ COMMIT
T2:   BEGIN ─ R(x) ─ W(x) ─ COMMIT
      (isolation level decides what T2 sees mid-T1)
```

## E. Tradeoffs
- Higher isolation → lower concurrency.
- Pick the lowest that's correct for the workload.

## F. Interview Lens
- "Describe isolation levels."
- "What's a phantom read?" — a tx re-runs a range query and sees new rows inserted by another committed tx.
- "Can MVCC deadlock?" — writers still can, on the same row.
- Pitfalls: using default isolation without checking.

## G. Real-World Mapping
- Postgres: MVCC, Read Committed default, Serializable Snapshot Isolation available.
- MySQL InnoDB: MVCC + next-key locks; Repeatable Read default.
- SQL Server: pessimistic locking + snapshot optional.

## H. Questions
**Beginner**: ACID meaning.
**Intermediate**:
1. Phantom read vs non-repeatable read.
2. MVCC vs locking.
**Advanced**:
1. Design a high-throughput transactional API with correctness for critical flows.
2. What happens at Serializable when two tx's conflict?

## I. Mini Design
Bank transfer tx:
```
BEGIN
UPDATE accounts SET balance = balance - 100 WHERE id = 1;
UPDATE accounts SET balance = balance + 100 WHERE id = 2;
COMMIT;
```
At Read Committed, you could lose to phantom. At Serializable, correct. Alternative: SELECT ... FOR UPDATE to lock explicitly.

## J. Cross-Topic Connections
- [ACID/BASE](acid-base.md), [Distributed Transactions](distributed-transactions.md), [Replication](database-replication.md).

## K. Confidence Checklist
- [ ] Can name 4 isolation levels + anomalies each blocks.
- [ ] Understands MVCC.

### Red flags
- ❌ "Just wrap it in a transaction" without isolation level awareness.

## L. Potential Gaps & Improvements
- **Snapshot Isolation vs SSI (Serializable Snapshot Isolation)** — Snapshot Isolation lets each transaction read a consistent point-in-time view; SSI (used by Postgres) adds conflict detection on top to give true serializability without heavy locking — know it to answer "how does Postgres do serializable cheaply?".
- **Deadlock detection** — the database's mechanism for spotting two transactions each holding a lock the other needs, then killing one so the system unblocks; learners care because it explains random "deadlock detected, transaction aborted" errors and why retry logic matters.
- **Read-write skew anomaly** — a subtle bug where two transactions each read overlapping data and write based on a now-stale view, leaving the database in an invalid state even though neither overwrote the other; it is the classic reason you need Serializable isolation (→ see Interview Lens).
- **Retry-on-serialization-failure pattern** — application-side loop that re-runs a transaction when the DB aborts it for a conflict; essential because Serializable/SSI isolation pushes conflict handling back onto your code.

**🔧 How to close:** Spin up Postgres in Docker (`docker run -e POSTGRES_PASSWORD=pw -p 5432:5432 postgres`), open two `psql` sessions, run `BEGIN ISOLATION LEVEL SERIALIZABLE;` in both, then have each read the same row and update a different one — commit both and watch one fail with `ERROR: could not serialize access due to read/write dependencies` to feel read-write skew and SSI firsthand.
