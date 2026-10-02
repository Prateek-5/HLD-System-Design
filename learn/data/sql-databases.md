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
- Isolation levels (READ COMMITTED, REPEATABLE READ, SERIALIZABLE) — needs own section.
- Query plans: EXPLAIN ANALYZE.
- Connection pooling (pgbouncer etc.) at scale.
