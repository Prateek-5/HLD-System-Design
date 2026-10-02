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
- Query optimizer internals, cost-based vs rule-based.
- MVCC (multi-version concurrency control) vs 2PL.
- Page layout on disk (slotted pages in Postgres).
