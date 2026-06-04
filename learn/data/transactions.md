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

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔁 Gap 1 — Retry-on-Serialization-Failure Pattern
- 🔹 **What it is**: An application-side loop that re-runs a whole transaction from `BEGIN` when the database aborts it with a serialization conflict error.
- 🔹 **Why it matters**: Serializable and SSI don't block conflicting writers — they let them run, then abort the loser at commit. If your code doesn't retry, those aborts surface as failed user requests.
- 🔹 **Connection**: The file's Mini Design and its "🔧 How to close" exercise both produce the `could not serialize access` error. This gap is *what you do* once you see it.
- 🔹 **When needed**: 🟢 **Foundational** — anyone who uses Serializable/SSI in production needs this; it's a small, learnable pattern.
- 🔹 **Intuition**: Two people grabbing the last item at a self-checkout. The system lets both scan, then one gets "item unavailable" and simply tries the next available one — they don't give up shopping.
- 🔹 **If you go deeper**: Read the Postgres docs on "Serializable Isolation Level" (the explicit "applications using this level must be prepared to retry transactions" note), and implement a capped exponential-backoff retry wrapper around your DB calls.
- 🔹 **Interview hook**: *"Why does Serializable isolation push work back onto the application?"* → Because conflict resolution is deferred to commit time as an abort, so the app must catch the serialization-failure error and replay the transaction.

---

#### 💀 Gap 2 — Deadlock Detection & Lock Ordering
- 🔹 **What it is**: The database mechanism that spots a cycle where each transaction holds a lock the other needs, then kills one (the "victim") so the rest can proceed.
- 🔹 **Why it matters**: Deadlocks explain seemingly-random `deadlock detected` aborts in production, and the fix (consistent lock ordering + retries) is a common interview probe.
- 🔹 **Connection**: Section C says 2PL "can deadlock → detect + abort one," and the Mini Design's two `UPDATE`s on different rows are exactly the shape that deadlocks when two transfers run in opposite order.
- 🔹 **When needed**: 🟡 **Mid-level** — relevant once you write multi-row transactions; common in backend interviews.
- 🔹 **Intuition**: Two people in a narrow hallway, each waiting for the other to step aside. Someone has to back up (the victim) or both wait forever.
- 🔹 **If you go deeper**: Read Postgres's deadlock detector (`deadlock_timeout`) and InnoDB's deadlock section in the MySQL manual; reproduce one by updating rows A→B in one session and B→A in another.
- 🔹 **Interview hook**: *"How do you avoid deadlocks in a bank-transfer transaction?"* → Always acquire row locks in a consistent order (e.g. lowest account id first) and add retry-on-deadlock.

---

#### 🔀 Gap 3 — Read-Write Skew & Why It Needs Serializable
- 🔹 **What it is**: An anomaly where two transactions each read an overlapping set of rows and write based on that now-stale view, leaving an invalid state even though neither overwrote the other's row.
- 🔹 **Why it matters**: It's the textbook reason Snapshot Isolation is *not* serializable, and the canonical justification for reaching for Serializable/SSI.
- 🔹 **Connection**: Section B lists the standard anomalies (dirty/non-repeatable/phantom); skew is the subtler one those isolation levels still allow but SSI (the file's "how does Postgres do serializable cheaply?" topic) catches.
- 🔹 **When needed**: 🟡 **Mid-level** — important once you understand isolation levels and need to justify Serializable.
- 🔹 **Intuition**: Two doctors each checking "is at least one other doctor on call?" — both see a colleague online, both go off-call, and now nobody covers the shift. Each decision was fine alone; together they break the invariant.
- 🔹 **If you go deeper**: Read the Cahill/Röhm/Fekete paper "Serializable Isolation for Snapshot Databases" (the basis of Postgres SSI), and Martin Kleppmann's *Designing Data-Intensive Applications* ch. 7 write-skew section.
- 🔹 **Interview hook**: *"Give an example Snapshot Isolation gets wrong."* → The on-call/booking write-skew case: both transactions read a constraint, both write, and the global invariant is violated.

---

#### 🧊 Gap 4 — Snapshot Isolation vs SSI Internals
- 🔹 **What it is**: Snapshot Isolation gives each transaction a consistent point-in-time read view; SSI adds runtime tracking of read/write dependencies (rw-antidependencies) to detect and abort the cycles that would break serializability.
- 🔹 **Why it matters**: It answers "how does Postgres offer Serializable without heavyweight locking?" — a strong senior-level signal about MVCC databases.
- 🔹 **Connection**: Section C explains MVCC and Section G notes Postgres has "Serializable Snapshot Isolation available." This gap opens up *how* SSI is built on the MVCC machinery the file already taught.
- 🔹 **When needed**: 🔴 **Senior** — genuinely deep DB-internals territory; senior or DB-focused interviews.
- 🔹 **Intuition**: A photo (snapshot) of the warehouse taken when you walked in — you shop against that frozen picture. SSI is a supervisor watching which photos overlapped and cancelling one checkout if two shoppers' decisions would contradict reality.
- 🔹 **If you go deeper**: Read the Postgres SSI implementation notes (`src/backend/storage/lmgr/predicate.c` README) and the original VLDB paper above; compare with how Oracle/MySQL stop at Snapshot Isolation.
- 🔹 **Interview hook**: *"How does Postgres make Serializable cheap?"* → It keeps MVCC snapshot reads but tracks rw-dependencies and aborts a transaction only when a dangerous cycle of antidependencies forms, avoiding broad read locks.

---

### 🏆 Start here if you have limited time
1. **Retry-on-serialization-failure** — smallest, most immediately useful pattern; you'll hit the error the moment you try Serializable.
2. **Deadlock detection & lock ordering** — directly applies to the bank-transfer design in this file and shows up in most backend interviews.

---

### 🧭 Suggested Deep Dive Order
1. **Retry-on-serialization-failure** (~30 min; turns the scary abort error into a one-line pattern).
2. **Deadlock detection & lock ordering** (~1h; reproduce a real deadlock, then fix it with consistent ordering).
3. **Read-write skew** (~1h; the conceptual "why Serializable exists" payoff).
4. **Snapshot Isolation vs SSI internals** (~2–3h; senior DB-internals depth, ties MVCC and serializability together).
