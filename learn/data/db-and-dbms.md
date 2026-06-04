# Databases and DBMS — What a Database Actually Is

> **Prereq**: [Storage](../foundations/scaling/storage.md)

## A. Intuition First
A database stores data for durable, queryable access. A DBMS (Database Management System) is the software layer that manages it — concurrency, integrity, indexes, transactions, backup. "The database" colloquially means both.

**Why it had to exist**: writing raw files to disk means you reimplement concurrency control, indexing, crash recovery, schema evolution, and query planning every time. A DBMS gives you all of that as a service.

## B. Mental Model
Four layers inside every DBMS:
1. **Query planner/optimizer** — turns SQL (or other queries) into an execution plan.
2. **Execution engine** — runs the plan: scans, joins, filters, aggregations.
3. **Storage engine** — pages, indexes (B-tree, LSM), buffer pool, WAL.
4. **Transaction manager** — concurrency control (MVCC or locking), durability (WAL + fsync).

## C. Internal Working
- **Schema** — defines shape (strict in SQL, optional in NoSQL).
- **Table / collection** — set of rows / documents.
- **Row / document** — one record.
- **Column / field** — typed attribute.
- **Index** — secondary lookup structure; pointer from key → row location.
- **WAL (Write-Ahead Log)** — every change written to log *before* data file, enabling crash recovery.
- **Buffer pool** — RAM cache of disk pages.

## D. Visual Representation
```
Query → Planner → Execution engine → Storage engine (buffer pool, disk)
                                              ↓
                                           WAL / redo log
```

## E. Tradeoffs
- Each DBMS makes choices: strict schema vs flexible, ACID vs BASE, row-oriented vs column-oriented.
- Generic databases are a compromise; specialized ones (time-series, graph, search) beat them at their niche.

## F. Interview Lens
- "Why do we use databases at all?" — see "why it had to exist".
- "What are the components of a DBMS?" — list the 4 layers above.
- "What's a WAL?" — durability + recovery.
- Pitfalls: not knowing indexes exist; not knowing transactions exist.

## G. Real-World Mapping
Postgres, MySQL, MongoDB, Cassandra, DynamoDB, Redis, BigTable, Snowflake — each optimizes for different workloads.

## H. Questions
**Beginner**: What's the difference between a database and a DBMS? What's a row vs a document?
**Intermediate**: What does a query planner do? What's a WAL?
**Advanced**: Trace a SELECT from SQL text to disk I/O.

## I. Mini Design
"Build a minimal DBMS": a key-value store with WAL + fsync + in-memory index. Explain how you'd add (a) crash recovery, (b) secondary indexes, (c) ACID transactions.

## J. Cross-Topic Connections
- [SQL databases](sql-databases.md), [NoSQL](nosql-databases.md), [ACID/BASE](acid-base.md), [Indexes](indexes.md), [Transactions](transactions.md).

## K. Confidence Checklist
- [ ] Can name DBMS components.
- [ ] Knows WAL, buffer pool, index.

### Red flags
- ❌ Treating DB as a black box.

## L. Potential Gaps & Improvements
- **Query optimizer internals** — the engine that decides *how* to run your SQL (which index, join order); knowing **cost-based** (estimates rows/IO from statistics) vs **rule-based** (fixed heuristics) explains why "the same query" can be fast or slow.
- **MVCC (Multi-Version Concurrency Control)** — keeps multiple row versions so readers never block writers and vice versa; matters because it's how Postgres/MySQL deliver high concurrency without locking everything.
- **2PL (Two-Phase Locking)** — the older concurrency scheme where transactions grab locks then release them all at the end; worth contrasting with MVCC to understand lock contention and deadlocks.
- **Slotted pages on disk** — the fixed-size block layout (e.g. Postgres 8 KB pages) where a header points to variable-length rows; understanding it demystifies storage bloat, `VACUUM`, and why updates can be costly.

**🔧 How to close:** Spin up Postgres in Docker (`docker run --rm -e POSTGRES_PASSWORD=pw -p 5432:5432 postgres`), create a table with a few thousand rows, then run `EXPLAIN (ANALYZE, BUFFERS) SELECT ...` with and without an index to watch the cost-based optimizer switch between a sequential scan and an index scan.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🧠 Gap 1 — Query Optimizer Internals (Cost-Based vs Rule-Based)
- 🔹 **What it is**: The planner stage that decides *how* to execute your SQL — which index to use, what join order, whether to scan or seek — by estimating the cost of each candidate plan from table statistics.
- 🔹 **Why it matters**: It explains the single most common real-world mystery: "the same query is fast on Monday and slow on Tuesday." Stale stats or a bad row estimate flips the plan.
- 🔹 **Connection**: This file lists the **query planner/optimizer** as layer 1 of the DBMS but treats it as a box. This opens the box.
- 🔹 **When needed**: 🟢 **Foundational** — every backend engineer hits a slow query; reading `EXPLAIN` is a near-universal skill.
- 🔹 **Intuition**: A GPS app comparing routes. It doesn't know live traffic perfectly — it *estimates* travel time per road (its "statistics") and picks the cheapest. Feed it stale traffic data and it routes you into a jam.
- 🔹 **If you go deeper**: Run `EXPLAIN ANALYZE` in Postgres and compare estimated vs actual rows; read the Postgres docs on the planner and `ANALYZE`/`pg_statistic`. The foundational paper is Selinger et al., "Access Path Selection in a Relational Database Management System" (System R, 1979).
- 🔹 **Interview hook**: *"Why might adding an index make a query slower?"* → The optimizer may already prefer a sequential scan for low-selectivity predicates; a new index also adds write/maintenance cost and can mislead the planner if stats are stale.

---

#### 🔀 Gap 2 — MVCC (Multi-Version Concurrency Control)
- 🔹 **What it is**: A concurrency strategy where each write creates a *new version* of a row instead of overwriting it, so readers see a consistent snapshot without blocking writers (and vice versa).
- 🔹 **Why it matters**: It's how Postgres, MySQL/InnoDB, and Oracle deliver high read/write concurrency. It also explains table bloat, `VACUUM`, and "why my disk grew even though I only updated rows."
- 🔹 **Connection**: This file names the **transaction manager** and lists "MVCC or locking" as the concurrency choice. MVCC is the modern default worth understanding first.
- 🔹 **When needed**: 🟡 **Mid-level** — shows up the moment you discuss isolation levels, long-running transactions, or Postgres maintenance.
- 🔹 **Intuition**: A shared Google Doc with version history. While you read yesterday's snapshot, someone else edits a new version; nobody waits for a lock, and old versions linger until cleanup garbage-collects them.
- 🔹 **If you go deeper**: Read the Postgres docs on MVCC and `VACUUM`; inspect hidden `xmin`/`xmax` columns. Compare with InnoDB's undo logs. Background: Reed's 1978 thesis on multiversion concurrency.
- 🔹 **Interview hook**: *"How can a reader and a writer touch the same row at the same time without blocking?"* → MVCC: the writer creates a new version, the reader keeps reading the old visible version per its snapshot.

---

#### 🔒 Gap 3 — 2PL (Two-Phase Locking) and Deadlocks
- 🔹 **What it is**: The classic concurrency protocol where a transaction acquires locks in a "growing" phase and releases them only in a "shrinking" phase (typically all at commit), guaranteeing serializability.
- 🔹 **Why it matters**: Contrasting 2PL with MVCC is how you reason about lock contention, deadlocks, and why some workloads serialize under load. Many engines (e.g. SQL Server, MySQL for writes) still lean on locking.
- 🔹 **Connection**: It's the "or locking" half of the transaction-manager choice this file mentions. Knowing both halves lets you explain *why* an engine picked one.
- 🔹 **When needed**: 🟡 **Mid-level** — relevant for isolation-level and deadlock interview questions; 🔴 **Senior** if you go into strict 2PL vs serializable-snapshot internals.
- 🔹 **Intuition**: A library where you must check out *every* book you'll need before reading any, and return them all only when fully done. Two patrons each holding a book the other wants = deadlock.
- 🔹 **If you go deeper**: Read about strict 2PL, lock escalation, and deadlock detection (wait-for graphs). Compare with Postgres's Serializable Snapshot Isolation (SSI). Foundational: Eswaran et al., "The Notions of Consistency and Predicate Locks in a Database System" (1976).
- 🔹 **Interview hook**: *"How does a database detect a deadlock?"* → It builds a wait-for graph of transactions blocked on each other's locks; a cycle means deadlock, and the engine aborts a victim transaction.

---

#### 🧱 Gap 4 — On-Disk Page Layout (Slotted Pages, Bloat, VACUUM)
- 🔹 **What it is**: The fixed-size block format (e.g. Postgres's 8 KB pages) where a page header holds a slot array pointing to variable-length rows packed from the end of the page inward.
- 🔹 **Why it matters**: It demystifies storage bloat, why deletes/updates don't immediately free space, what `VACUUM` actually reclaims, and why an `UPDATE` can be as expensive as an `INSERT`.
- 🔹 **Connection**: The **storage engine** layer in this file mentions "pages" and the **buffer pool**. This is the concrete on-disk shape of a page.
- 🔹 **When needed**: 🔴 **Senior** — deep storage-internals territory; great signal but rarely a basic requirement.
- 🔹 **Intuition**: A parking lot with a numbered directory board at the entrance (the slot array) and cars parked from the back wall forward. When a car leaves, its directory slot is freed but the empty space isn't reclaimed until a sweeper (`VACUUM`) compacts the lot.
- 🔹 **If you go deeper**: Read the Postgres docs on "Database Page Layout" (`PageHeaderData`, `ItemId`), then use the `pageinspect` extension to dump a real page. Compare with LSM-tree storage (RocksDB/Cassandra) where pages are immutable and compaction replaces VACUUM.
- 🔹 **Interview hook**: *"Why does an UPDATE in Postgres write a whole new row version?"* → MVCC plus the slotted-page model: the old tuple stays until VACUUM, and the new version is written into free page space (or a new page), which is why update-heavy tables bloat.

---

### 🏆 Start here if you have limited time
1. **Query optimizer internals** — reading `EXPLAIN` pays off in nearly every backend job, today.
2. **MVCC** — unlocks isolation levels, the most common transaction-interview territory.

---

### 🧭 Suggested Deep Dive Order
1. **Query optimizer internals** (~1h; immediately practical — run `EXPLAIN ANALYZE` on your own queries).
2. **MVCC** (~1h; explains concurrency, isolation, and Postgres bloat).
3. **2PL & deadlocks** (~45 min; the contrasting concurrency model interviewers probe).
4. **On-disk page layout** (~1.5h; senior storage-internals depth, ties MVCC + VACUUM together).
