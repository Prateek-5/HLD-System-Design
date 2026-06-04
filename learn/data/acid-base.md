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
- **Isolation-level anomalies** (dirty read, non-repeatable read, phantom read) — the specific bugs that appear when transactions overlap. Knowing them by name is how you justify a chosen isolation level in an interview.
- **Snapshot isolation vs serializable** — two strong isolation levels: snapshot gives each transaction a consistent point-in-time view (fast, but allows write-skew); serializable behaves as if transactions ran one at a time (safest, more costly). Postgres implements the latter as **SSI (Serializable Snapshot Isolation)**, which adds conflict detection on top of snapshots so no manual locking is needed (→ see Interview Lens).
- **Linearizability** — a *consistency model for distributed reads/writes* (every read sees the latest committed write, system-wide). It is a **separate axis from ACID**, not "a level above" it: ACID is about transaction guarantees on one database; linearizability is about ordering across replicas.

**🔧 How to close:** open two `psql` sessions against the same Postgres table, `BEGIN` both, and try to observe a dirty read / non-repeatable read under `READ COMMITTED` vs `REPEATABLE READ`. Watching one session *not* see the other's uncommitted change makes isolation levels concrete.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🐛 Gap 1 — Isolation-Level Anomalies (Dirty / Non-Repeatable / Phantom Reads)
- 🔹 **What it is**: The three named bugs that appear when two transactions overlap — reading uncommitted data (dirty read), getting two different answers to the same query (non-repeatable read), or having new rows appear mid-transaction (phantom read).
- 🔹 **Why it matters**: Each SQL isolation level is *defined* by which of these it prevents. Naming the anomaly is how you justify "I'd use REPEATABLE READ here" instead of hand-waving.
- 🔹 **Connection**: Section C said isolation is achieved via 2PL or MVCC and listed READ COMMITTED / REPEATABLE READ / SERIALIZABLE — these anomalies are exactly what those levels turn on and off.
- 🔹 **When needed**: 🟢 **Foundational** — any time you touch a relational DB; standard intermediate interview material.
- 🔹 **Intuition**: A whiteboard in a shared room. A dirty read is reading something a coworker scribbled but hasn't decided to keep. A non-repeatable read is glancing twice and the number changed underneath you. A phantom read is a whole new line item appearing between glances.
- 🔹 **If you go deeper**: Read the ANSI SQL-92 isolation definitions, then the critique "A Critique of ANSI SQL Isolation Levels" (Berenson, Bernstein et al., 1995) which shows the standard is ambiguous and introduces snapshot isolation.
- 🔹 **Interview hook**: *"What's the difference between a non-repeatable read and a phantom read?"* → Non-repeatable read = an *existing* row's value changed between two reads; phantom read = the *set* of rows matching a predicate changed (new/removed rows). REPEATABLE READ stops the former; only SERIALIZABLE (or range locks) stops the latter.

---

#### 📸 Gap 2 — Snapshot Isolation vs Serializable (and Write Skew)
- 🔹 **What it is**: Snapshot isolation gives every transaction a consistent point-in-time view of the DB; serializable guarantees the outcome is as if transactions ran one-at-a-time. Snapshot is faster but allows *write skew*, a bug serializable forbids.
- 🔹 **Why it matters**: Most databases' "REPEATABLE READ" is actually snapshot isolation, and write skew silently breaks invariants (two doctors both go off-call because each saw the other still on). Knowing this separates people who memorized level names from people who understand them.
- 🔹 **Connection**: Section C mentioned MVCC (versioning) — that *is* the snapshot mechanism. This gap explains what MVCC alone does *not* protect against.
- 🔹 **When needed**: 🟡 **Mid-level** — common once you design real transactional flows; frequent in DB-heavy interviews.
- 🔹 **Intuition**: Two roommates each check the fridge, both see no milk, both independently go buy milk. Each acted on a correct *snapshot*, but the combined result (two cartons) violates the "we only need one" rule. That gap-in-coordination is write skew.
- 🔹 **If you go deeper**: Study Postgres's SSI (Serializable Snapshot Isolation) and the paper "Serializable Isolation for Snapshot Databases" (Cahill, Röhm, Fekete, 2008), which adds cheap conflict detection on top of snapshots.
- 🔹 **Interview hook**: *"Snapshot isolation prevents dirty and non-repeatable reads — so why isn't it serializable?"* → Because of write skew: two transactions read overlapping data, write to disjoint rows, and each commit is individually valid but together they violate an invariant no serial order would allow.

---

#### 🌐 Gap 3 — Linearizability: A Separate Axis from ACID
- 🔹 **What it is**: A consistency model for distributed reads/writes where every read returns the most recent committed write, system-wide, as if there were a single copy of the data updated instantaneously.
- 🔹 **Why it matters**: Interviewers love conflating the "C" in ACID with the "C" in CAP. Linearizability is the real distributed-systems C, and it's orthogonal to transaction guarantees — confusing them is a classic senior red flag.
- 🔹 **Connection**: Section B's "Consistent" is about *invariants on one database*; Section D contrasted sync vs async replication. Linearizability is the formal name for the "all replicas synced before ack" strong end of that spectrum.
- 🔹 **When needed**: 🔴 **Senior** — distributed-systems and infra rounds; not needed for single-node CRUD work.
- 🔹 **Intuition**: A bank with many branches but one shared ledger updated the instant any teller writes — walk into any branch a microsecond later and you see the new balance. No branch ever shows a stale number.
- 🔹 **If you go deeper**: Read Herlihy & Wing's original "Linearizability" paper (1990), then Kleppmann's *Designing Data-Intensive Applications* ch. 9 for how it relates to consensus (Raft/Paxos) and the CAP theorem.
- 🔹 **Interview hook**: *"Is the 'C' in ACID the same as the 'C' in CAP?"* → No. ACID's C is application-defined invariants enforced by one DB; CAP's C is linearizability — a system-wide ordering guarantee across replicas. They're independent axes.

---

#### 🔁 Gap 4 — ACID Across Services: Sagas & Distributed Transactions
- 🔹 **What it is**: Patterns for getting ACID-like outcomes when a single logical operation spans multiple databases or services — two-phase commit (2PC) for tight coupling, or the Saga pattern (a chain of local transactions with compensating undo steps) for loose coupling.
- 🔹 **Why it matters**: The moment you split a monolith into services, the database transaction that guaranteed atomicity disappears. Sagas are the standard answer in microservices interviews for "how do you keep order + payment + inventory consistent?"
- 🔹 **Connection**: Section I's Mini Design needs a transaction across cart + inventory + payment. On one database that's a `BEGIN…COMMIT`; across three services it becomes a saga or 2PC — this gap is the bridge from the single-DB world this file teaches to the distributed one.
- 🔹 **When needed**: 🟡 **Mid-level** for microservices design; 🔴 **Senior** when you must reason about partial failure and idempotency.
- 🔹 **Intuition**: Booking a trip by phone — you reserve a flight, then a hotel, then a car. If the car falls through, you don't get a magic rollback; you call back to *cancel* the flight and hotel. Those cancel calls are the compensating transactions of a saga.
- 🔹 **If you go deeper**: Read Hector Garcia-Molina's original "Sagas" paper (1987), then study how Temporal or AWS Step Functions orchestrate saga workflows in production. Contrast with 2PC's blocking coordinator problem.
- 🔹 **Interview hook**: *"You can't run a SQL transaction across three microservices — so how do you keep checkout atomic?"* → Use a saga: each step is a local transaction, and every step has a compensating action; on failure you run compensations in reverse. You trade atomicity for eventual consistency plus idempotent, reversible steps.

---

### 🏆 Start here if you have limited time
1. **Isolation-level anomalies** — 🟢 foundational; "explain dirty vs phantom read" is asked constantly and unlocks every isolation-level discussion.
2. **Snapshot vs serializable (write skew)** — the depth that separates rote level-memorizers from people who actually understand isolation.

---

### 🧭 Suggested Deep Dive Order
1. **Isolation-level anomalies** (~45 min; reproduce each in two `psql` sessions — directly extends the How-to-close exercise).
2. **Snapshot isolation vs serializable** (~1h; understand MVCC and engineer a write-skew bug, then watch SERIALIZABLE reject it).
3. **Sagas & distributed transactions** (~1.5h; high payoff for any microservices interview).
4. **Linearizability** (~2h; senior-infra signaling, ties ACID into CAP and consensus).
