# SQL Databases — The Relational Model

## A. Intuition First
SQL databases organize data as tables of rows and columns. Relationships are explicit (foreign keys). A query language (SQL) expresses *what* you want, the optimizer figures out *how*. ACID guarantees make them the default for anything "money-shaped" (transactions, inventory, reservations).

**Why they dominated**: Codd's 1970 relational model + Stonebraker's systems (Ingres → Postgres) made reasoning about data *declarative*, and ACID made it safe for business.

## B. Mental Model
- **Tables** (entities) with **rows** (records) and **columns** (typed attributes).
- **Primary key** uniquely identifies a row. **Foreign key** references another table.
- **Joins** combine tables at query time.
- **Schema-on-write**: you define types first, then insert.

## C. Internal Working
- **Storage**: row-oriented pages on disk (typically 8KB). B-tree indexes on primary and secondary keys.
- **Transactions**: ACID. Most modern systems use **MVCC** — each row has multiple versions; readers don't block writers.

> **❓ What does MVCC actually mean, and why do databases use it?**
>
> **The problem it solves:** under classical locking, when Alice is updating a row, any reader has to wait for her to commit. For a read-heavy website (99% reads, 1% writes), that's disastrous — reads pile up behind rare writes.
>
> **MVCC (Multi-Version Concurrency Control)** flips this: *instead of locking the row, keep the old version around while the new one is being written.*
>
> **Intuition — version history for every row:**
> - Alice begins a transaction and updates `account[42].balance = 500` (was 400).
> - The database doesn't overwrite. It creates a **new row version** tagged with Alice's transaction ID.
> - Meanwhile Bob starts a read transaction: "what's the balance of account 42?"
> - The database sees Bob's transaction ID is older than Alice's uncommitted change, so Bob **sees the old value (400)** — no waiting, no lock, no blocking.
> - Alice commits. Any transaction started *after* the commit sees 500.
>
> **Consequence:** readers never block writers; writers never block readers. Only writer-vs-writer on the same row needs coordination.
>
> **The cost:** old versions pile up; Postgres runs `VACUUM` to reclaim them, MySQL InnoDB uses an undo log. Misconfigured vacuuming → table bloat → slow reads.
>
> **Where it's used:** Postgres (default), MySQL InnoDB (default), Oracle, SQL Server (snapshot isolation mode), CockroachDB, YugabyteDB.
>
> **🔄 Micro reinforcement**:
> 1. *Recall*: in MVCC, does a reader ever wait for a writer? *(No, it sees an older version.)*
> 2. *Recall*: what's the operational downside if Postgres VACUUM falls behind? *(Bloat — disk usage balloons, reads slow as they scan dead versions.)*
> 3. *What if* two transactions both update the same row concurrently? *(The second one blocks on the first — MVCC doesn't eliminate writer conflicts, just reader-writer conflicts.)*
- **Query planning**: parser → optimizer (picks index use, join order) → executor.
- **Replication**: WAL shipping to replicas for read scaling / HA.

## D. Visual Representation
```
users                 orders
┌──────┬──────┐       ┌───────┬────────┬──────────┐
│ id   │ name │ ←─┐   │ id    │ user_id│ amount   │
└──────┴──────┘   └───┤       │  (FK)  │          │
                     └───────┴────────┴──────────┘
    JOIN users ON orders.user_id = users.id
```

## E. Tradeoffs
### Advantages
Schema enforcement, ACID, expressive SQL, decades of tooling, complex joins.

### Disadvantages
Hard to scale horizontally (shared-nothing SQL is painful). Schema changes can be slow on huge tables. Costly joins at scale.

### Materialized view
A pre-computed result stored like a table. Fast reads at the cost of staleness + storage. Refreshed on schedule or on write.

### N+1 query problem
ORM/GraphQL pitfall: you fetch N parent rows, then issue N child queries instead of one JOIN. Fix: **dataloader pattern** (batch), explicit joins, or `SELECT … IN (...)` batching.

## F. Interview Lens
- "When SQL, when NoSQL?" — see [SQL vs NoSQL](sql-vs-nosql.md).
- "What's N+1 and how do you fix it?"
- "What does ACID stand for and why does it matter?"
- "How does Postgres handle concurrent updates to the same row?" — MVCC + row-level locks.
- Pitfalls: using SQL for a truly schemaless workload; over-normalizing and then suffering join-heavy query plans.

## G. Real-World Mapping
Postgres, MySQL, Oracle, SQL Server, MariaDB, Amazon Aurora, Google Spanner (globally distributed SQL).

## H. Questions
**Beginner**: What's a primary key? A foreign key?
**Intermediate**:
1. What's a materialized view?
2. What is N+1 and how do you avoid it?
**Advanced**:
1. How does MVCC let readers not block writers?
2. What limits a single-node SQL DB's write QPS?

## I. Mini Design
"Ticket booking DB": accounts, events, seats, bookings. Enforce one-seat-one-booking with a unique constraint + transaction isolation level SERIALIZABLE for concurrent bookings.

## J. Cross-Topic Connections
- [NoSQL](nosql-databases.md), [ACID/BASE](acid-base.md), [Indexes](indexes.md), [Normalization](normalization-denormalization.md), [Replication](database-replication.md), [Sharding](sharding.md).

## K. Confidence Checklist
- [ ] Can write basic SQL including JOIN.
- [ ] Can explain ACID.
- [ ] Knows N+1 problem.
- [ ] Can explain MVCC.

### Red flags
- ❌ Blindly picking SQL for a high-volume event firehose.

## L. Potential Gaps & Improvements
- **Isolation levels (READ COMMITTED, REPEATABLE READ, SERIALIZABLE)** — rules for how much one transaction sees another's in-flight changes; picking the right one trades anomalies for speed and is core to concurrency questions.
- **MVCC (Multi-Version Concurrency Control)** — the database keeps multiple row versions so readers never block writers; understanding it explains why Postgres stays fast under contention (→ see Interview Lens).
- **SSI (Serializable Snapshot Isolation)** — Postgres's way of getting the safest SERIALIZABLE level without heavy locking; matters when you need correctness guarantees but still want throughput.
- **EXPLAIN ANALYZE (query plans)** — shows exactly how the engine will fetch your data (index scan vs full table scan); the first tool to reach for when a query is slow.
- **Connection pooling (PgBouncer, etc.)** — a proxy that reuses a small set of DB connections across many clients so the database isn't crushed by thousands of short-lived ones; essential at scale.

**🔧 How to close:** Start Postgres in Docker (`docker run --rm -e POSTGRES_PASSWORD=pw -p 5432:5432 postgres`), create a table with a few thousand rows, then run `EXPLAIN ANALYZE SELECT * FROM t WHERE col = 'x';` before and after `CREATE INDEX` to watch the plan flip from Seq Scan to Index Scan and the cost drop.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🪜 Gap 1 — Isolation Levels & the Anomalies They Prevent
- 🔹 **What it is**: The four SQL isolation levels (READ UNCOMMITTED, READ COMMITTED, REPEATABLE READ, SERIALIZABLE) are dials that control how much one in-flight transaction can see another's uncommitted or changing data.
- 🔹 **Why it matters**: Picking too loose a level lets bugs like dirty reads, non-repeatable reads, and phantom reads silently corrupt money-shaped data; too strict and you pay in throughput and deadlocks.
- 🔹 **Connection**: The Mini Design told you to use `SERIALIZABLE` for concurrent seat bookings — this gap explains *why* that level (and not READ COMMITTED, the Postgres default) is what actually prevents two people booking the same seat.
- 🔹 **When needed**: 🟢 **Foundational** — every backend dev hits this; the default level is rarely the right one for critical writes.
- 🔹 **Intuition**: Editing a shared Google Doc. READ COMMITTED = you only see others' changes once they save; REPEATABLE READ = the doc looks frozen for your whole session; SERIALIZABLE = the system pretends everyone edited one-at-a-time in a line.
- 🔹 **If you go deeper**: Read the Postgres "Transaction Isolation" docs and the classic *"A Critique of ANSI SQL Isolation Levels"* (Berenson et al., 1995) which shows the ANSI definitions are ambiguous. Then run two `psql` sessions and reproduce a non-repeatable read.
- 🔹 **Interview hook**: *"Two users try to book the last seat at the same time — how do you guarantee only one wins?"* → A `UNIQUE` constraint plus SERIALIZABLE (or `SELECT ... FOR UPDATE` row locking); the loser's transaction aborts or blocks rather than double-booking.

---

#### 🔁 Gap 2 — MVCC Internals: Versions, VACUUM, and Bloat
- 🔹 **What it is**: Multi-Version Concurrency Control keeps multiple physical versions of each row so readers see a consistent snapshot without locking writers; old versions must later be garbage-collected.
- 🔹 **Why it matters**: It's the reason Postgres stays fast under read-heavy contention — and the reason a misconfigured database can mysteriously bloat to 3x its size and slow down.
- 🔹 **Connection**: The Internal Working section introduced MVCC and mentioned `VACUUM`/undo logs. This gap turns that intuition into the operational knowledge interviewers probe: what dead tuples are and what happens when cleanup falls behind.
- 🔹 **When needed**: 🟡 **Mid-level** — useful once you understand transactions; essential for anyone operating a real Postgres/MySQL instance.
- 🔹 **Intuition**: A library that never throws out old editions of a book — every reader gets the edition that existed when they walked in. Great for readers, but eventually the shelves overflow and a janitor (VACUUM) must clear the obsolete copies.
- 🔹 **If you go deeper**: Read Postgres's `VACUUM`/autovacuum docs and compare with MySQL InnoDB's undo log + purge thread. Build it: insert and update a row 100k times, then run `SELECT n_dead_tup FROM pg_stat_user_tables;` to watch dead tuples accumulate before autovacuum reaps them.
- 🔹 **Interview hook**: *"Why does an UPDATE-heavy Postgres table get slow over time even though row count is flat?"* → Each UPDATE leaves a dead tuple; if autovacuum can't keep up, scans wade through dead versions and the table/index bloats.

---

#### 🛡️ Gap 3 — Serializable Snapshot Isolation (SSI)
- 🔹 **What it is**: Postgres's implementation of SERIALIZABLE that builds on MVCC snapshots and detects dangerous read-write dependency cycles at commit time, instead of taking heavy pessimistic locks up front.
- 🔹 **Why it matters**: It gives you the strongest correctness guarantee while keeping MVCC's "readers don't block writers" performance — but it can abort transactions with serialization-failure errors your app must retry.
- 🔹 **Connection**: Builds directly on the MVCC model from Internal Working and the isolation levels from Gap 1 — SSI is *how* Postgres delivers the SERIALIZABLE level the Mini Design relies on without falling back to full table locks.
- 🔹 **When needed**: 🔴 **Senior** — deep concurrency-control territory; signals you understand the cost model behind "just use SERIALIZABLE."
- 🔹 **Intuition**: An optimistic referee who lets every player move freely, then reviews the replay at the end — if two plays would only make sense in different timelines, one gets disallowed and replayed.
- 🔹 **If you go deeper**: Read Cahill, Röhm & Fekete's *"Serializable Isolation for Snapshot Databases"* (SIGMOD 2008) — the paper Postgres's SSI is based on. Then write app code that catches `serialization_failure` (SQLSTATE 40001) and retries the transaction.
- 🔹 **Interview hook**: *"How can you get true serializability without crippling concurrency with locks?"* → SSI: run on snapshots, track read-write dependencies, and abort only the rare transactions that form a dangerous cycle.

---

#### 🔎 Gap 4 — Reading Query Plans with EXPLAIN ANALYZE
- 🔹 **What it is**: A command that shows the optimizer's chosen execution plan plus *actual* timings and row counts when the query runs, exposing whether it used an index, a sequential scan, or an expensive join strategy.
- 🔹 **Why it matters**: It's the single most important debugging tool for slow queries — the difference between guessing and seeing exactly where time goes.
- 🔹 **Connection**: The Internal Working section described the parser → optimizer → executor pipeline; EXPLAIN ANALYZE is your window into the decisions that pipeline made, and the file's own "How to close" exercise has you watch a Seq Scan flip to an Index Scan.
- 🔹 **When needed**: 🟢 **Foundational** — anyone writing SQL professionally should be able to read a basic plan.
- 🔹 **Intuition**: A GPS trip breakdown after you arrive — not just the route it picked, but how long each leg actually took, so you can spot the one street that cost you twenty minutes.
- 🔹 **If you go deeper**: Learn to read nested-loop vs hash vs merge joins and the `Rows Removed by Filter` line; paste plans into a visualizer like explain.dalibo.com or PEV. Practice spotting when estimated rows wildly diverge from actual (a sign your statistics are stale — run `ANALYZE`).
- 🔹 **Interview hook**: *"A query that was fast yesterday is slow today — how do you diagnose it?"* → `EXPLAIN ANALYZE` it, look for an unexpected Seq Scan or a row-estimate that's off by orders of magnitude (stale stats / missing index).

---

#### 🚪 Gap 5 — Connection Pooling at Scale
- 🔹 **What it is**: A proxy (PgBouncer, the canonical example) that maintains a small reusable set of physical database connections and multiplexes thousands of client requests over them.
- 🔹 **Why it matters**: Each Postgres connection is a full OS process costing memory; a few thousand short-lived app connections (serverless, microservices) will exhaust the database before the CPU is even busy.
- 🔹 **Connection**: The Disadvantages section noted SQL is hard to scale horizontally — connection exhaustion is one of the first scaling walls you hit, well before sharding, and pooling is the cheap fix.
- 🔹 **When needed**: 🟡 **Mid-level** — comes up the moment an app has more than a handful of stateless instances or runs on serverless/Lambda.
- 🔹 **Intuition**: A restaurant with 20 tables but 500 walk-ins — a host (the pooler) seats people as tables free up instead of letting all 500 crowd in and grind service to a halt.
- 🔹 **If you go deeper**: Compare PgBouncer's session vs transaction vs statement pooling modes (transaction mode is the high-throughput default, but breaks session-level features like prepared statements and `SET`). Run PgBouncer in front of Postgres and load-test with and without it.
- 🔹 **Interview hook**: *"Your serverless functions are erroring with 'too many connections' under load — what's wrong and how do you fix it?"* → Each invocation opens its own connection; put a transaction-mode pooler (PgBouncer / RDS Proxy) between the functions and the database.

---

### 🏆 Start here if you have limited time
1. **Isolation levels (Gap 1)** — the highest-leverage concept; it underpins the file's own seat-booking design and shows up in nearly every transactions interview.
2. **EXPLAIN ANALYZE (Gap 4)** — immediately practical; you'll use it the next time any query is slow.

---

### 🧭 Suggested Deep Dive Order
1. **Isolation levels & anomalies** (~1h; foundational, directly extends ACID and the Mini Design).
2. **EXPLAIN ANALYZE / query plans** (~45 min; instant payoff for debugging real queries).
3. **MVCC internals & VACUUM** (~1h; explains the operational behavior behind the concurrency you just learned).
4. **Connection pooling** (~30 min; the first scaling wall, cheap to fix once understood).
5. **Serializable Snapshot Isolation** (~1.5h; senior-depth, ties isolation levels and MVCC together).
