# OLTP vs OLAP & Columnar Storage

> *"A database optimized for one row at a time and a database optimized for one column at a time look superficially the same — they're both 'databases.' Their internals are completely different. Trying to use one for the other is how teams discover that 'just put a bigger machine on it' doesn't work."*

---

## Topic Overview

Two fundamentally different workload shapes drive two fundamentally different database designs. **OLTP (Online Transactional Processing)** handles many small operations: insert this order, update that user's balance, fetch this row by ID. Latency-sensitive, write-heavy, strongly consistent. Postgres, MySQL, Oracle. **OLAP (Online Analytical Processing)** handles few large operations: sum these revenues across years, compute conversion rates by cohort, aggregate billions of rows. Throughput-sensitive, read-heavy, often eventually consistent. Snowflake, BigQuery, Redshift, ClickHouse, DuckDB.

The internal designs diverge dramatically. OLTP databases store rows together (row-oriented); OLAP stores columns together (columnar). OLTP optimizes for B-tree lookups; OLAP for sequential scans with aggressive vectorization. OLTP optimizes for write latency; OLAP for read throughput on aggregations.

This is the topic that explains why Postgres struggles when you ask it to scan a billion rows for analytics, and why ClickHouse is bad at "update this user's profile." The architectural choices made decades ago shaped two product categories. Understanding which fits which workload is one of the most important data-engineering decisions any team makes.

---

## Intuition Before Definitions

Imagine a library.

**OLTP library.** Books are arranged so that you can grab any specific book quickly. The catalog points to its exact location. You walk in, find your book, leave. The library is optimized for rapid retrieval of individual items. Most visits are brief.

**OLAP library.** Books are arranged so you can quickly count how many of *each genre* are present, total. The genres are color-coded; mystery books are in one wing, romance in another. To find a specific book by title? You'd scan a whole wing — slow. But "how many books were published in 1995?" is fast: walk down a single shelf.

Both are libraries. Both have books. But the *organization* is fundamentally different, optimized for different questions. Trying to find a specific book in the OLAP library is painful. Trying to count all 1995 books in the OLTP library is painful. Neither is "better." They're built for different jobs.

---

## Historical Evolution

**Era 1 — One database for everything.**
1980s-90s. Oracle, IBM DB2, Sybase. Used for both transactional and analytical workloads on the same instance. Performance was acceptable because data was small.

**Era 2 — The data warehouse.**
1990s. Inmon and Kimball formalize "data warehouse" as a separate analytical store. Periodic ETL from OLTP to warehouse. Teradata, Netezza emerged.

**Era 3 — Columnar storage research.**
1980s onward. C-Store (academic, 2005) demonstrates columnar advantages for analytics. Vertica commercialized it.

**Era 4 — Modern OLAP era.**
2010s. Redshift (2012), BigQuery (2010), Snowflake (2014). Cloud-native columnar warehouses. ClickHouse (2016) open-source. Massive analytics throughput at affordable cost.

**Era 5 — HTAP attempts.**
"Hybrid Transactional-Analytical Processing" — single systems claiming both workloads. TiDB, SingleStore, CockroachDB. Promising; mixed track record.

**Era 6 — Embedded OLAP.**
DuckDB (2019), Polars. Bring columnar analytics to single-node and embedded contexts. The "modern Excel replacement."

The pattern: workload shapes drove database specialization. Trying to merge them back has been a recurring goal but operationally hard.

---

## Core Mental Models

**1. Row-oriented = fast row access; columnar = fast column access.**
Storing all of a row's columns together (rows in a heap) makes "fetch this row by ID" cheap. Storing all values of a column together (columnar) makes "sum this column over a billion rows" cheap.

**2. OLTP = high-frequency small operations; OLAP = low-frequency large operations.**
OLTP: thousands of transactions per second, each touching a few rows. OLAP: hundreds of queries per hour, each touching millions or billions of rows.

**3. The disk pattern follows.**
OLTP uses random I/O (B-tree lookups); OLAP uses sequential I/O (full column scans). Hardware optimizations differ accordingly.

**4. Compression is a columnar superpower.**
Columns of similar values compress dramatically. A column of timestamps from one day fits in tiny space. Run-length encoding, dictionary encoding, bit packing — all natural at the column level.

**5. Vectorization beats row-at-a-time.**
Process 1024 values at once with SIMD; modern OLAP engines exploit this. Row-at-a-time engines pay per-row overhead; vectorized engines pay per-batch.

---

## Deep Technical Explanation

### Row-oriented storage (OLTP)

A row is stored together: all columns of one row in one block.

```
Row 1: [user_id=1, name="Alice", email="a@x.com", created_at=...]
Row 2: [user_id=2, name="Bob",   email="b@x.com", created_at=...]
Row 3: [user_id=3, name="Carol", email="c@x.com", created_at=...]
```

Reading row 2 by user_id: B-tree lookup; one disk read; you get all columns.

Aggregating average created_at across millions of rows: must read every row from disk, even though you only need one column. I/O wasted on unused columns.

This is why Postgres is fast for `SELECT * FROM users WHERE user_id = 42` and slow for `SELECT AVG(created_at) FROM users`.

### Columnar storage (OLAP)

A column is stored together: all values of one column in one block.

```
user_id:    [1, 2, 3, 4, 5, ...]
name:       ["Alice", "Bob", "Carol", "Dave", "Eve", ...]
email:      ["a@x.com", "b@x.com", ...]
created_at: [t1, t2, t3, ...]
```

Reading row 2 by user_id: must read from each column file at offset 2. Multiple I/O operations. Slow.

Aggregating AVG(created_at): read just the created_at column. Skip all other columns. I/O is exactly what's needed.

This is why ClickHouse is fast for `SELECT AVG(created_at) FROM users` and slow for `SELECT * FROM users WHERE user_id = 42`.

### Compression in columnar

A column has homogeneous data. This compresses extraordinarily well:

- **Dictionary encoding**: distinct values mapped to small IDs. A `country` column with 200 distinct values compresses 95%+.
- **Run-length encoding**: `[A, A, A, B, B, C, C, C, C]` → `[(A, 3), (B, 2), (C, 4)]`.
- **Bit packing**: small-integer columns (e.g., status flags) packed into bits.
- **Delta encoding**: `[100, 102, 105, 109]` → `[100, +2, +3, +4]`. Useful for sorted timestamp columns.
- **Generic compression**: LZ4, ZSTD, Snappy on top.

10× compression is typical; 100× is not unheard of for specific column types. Storage cost drops; I/O drops; queries get faster.

In row stores, compression is harder — different columns in a row have different patterns; compression is per-block, less effective.

### Vectorized execution

OLTP engines process row-at-a-time:
```c
for (each_row) {
    process(row);  // 100ns per row
}
```

OLAP engines process batch-at-a-time:
```c
for (each_batch_of_1024_rows) {
    process_vectorized(batch);  // 1ns per row, due to SIMD
}
```

The 100× speedup comes from:
- Better CPU cache behavior.
- SIMD instructions on AVX/NEON.
- Fewer function call overheads.
- Branch prediction working better.

ClickHouse, DuckDB, Snowflake all do this. Postgres recently added some vectorized operations; still mostly row-at-a-time.

### Indexing in OLAP

OLAP doesn't use B-trees the way OLTP does. Common patterns:

- **Partition pruning**: data partitioned by date or other dimension; query reads only relevant partitions.
- **Min/max statistics**: per-block min/max; queries can skip blocks where values can't match.
- **Bloom filters**: probabilistic membership; "this block doesn't contain value X" cheaply.
- **Sparse indexes**: index every Nth row, not every row. Reduce index size.
- **Materialized views**: pre-aggregated results for common queries.

The point: scan as little as possible; aggregate quickly when scanning.

### MPP (massively parallel processing)

OLAP at scale fans out across many nodes:

- Data partitioned across nodes.
- Each node scans its partition.
- Results aggregated.

A 10TB query that takes 1 hour on one node finishes in 6 minutes on 10 nodes. Embarrassingly parallel for many analytical workloads.

Modern systems (BigQuery, Snowflake, Spark) automate this. Hand-tuning of partition keys still matters for correctness and performance.

### HTAP — the holy grail

Hybrid Transactional-Analytical Processing aims to do both:

- Transactional writes (OLTP).
- Analytical queries (OLAP) on the same data, in real time.

Approaches:
- **Two storage formats internally**: row for writes, column for reads, replicated. TiDB/TiFlash, SingleStore.
- **Periodic conversion**: writes go to row; periodically converted to columnar. Latency between write and analytical visibility.
- **Single hybrid format**: hard to optimize for both; usually one wins.

HTAP works for some workloads. Pure-OLTP and pure-OLAP teams often still keep separate systems.

### ETL and ELT

The classic pattern:
- **ETL (Extract, Transform, Load)**: data extracted from OLTP, transformed, loaded into warehouse.
- **ELT (Extract, Load, Transform)**: extract and load raw; transform in the warehouse.

ETL was traditional (limited warehouse compute). ELT is modern (cheap warehouse compute; transformation in SQL is simpler).

CDC (Change Data Capture) enables near-real-time replication from OLTP to OLAP via WAL streaming.

### Common workload mismatches

**Running analytics on OLTP.** Engineer writes a complex aggregation against the production Postgres. Query takes 30 minutes; locks tables; degrades production. Fix: replicate to a warehouse; run analytics there.

**Using OLAP for transactions.** Engineer tries to "update this row" on Snowflake. Slow; expensive (per-query pricing); not designed for it. Fix: don't.

**The single-database utopia.** "We'll just use Postgres for everything." Works until it doesn't. Postgres can scale far for OLTP; analytics workloads have separate needs. The right answer is usually two systems.

### Choosing a system

| Workload | Pick |
|---|---|
| User-facing transactions | OLTP (Postgres, MySQL) |
| Real-time queries on small data | OLTP |
| Reports on millions of rows | OLAP (Snowflake, BigQuery, ClickHouse) |
| Embedded analytics in app | DuckDB, SQLite (analytical mode) |
| Data lake exploration | Spark, Presto, Trino |
| Real-time analytics | ClickHouse, Druid, Pinot |
| Time-series specifically | TimescaleDB, Influx, ClickHouse |

The honest answer for most teams: an OLTP database for the application, and an OLAP warehouse for analytics, with CDC or batch ETL between.

---

## Real Engineering Analogies

**The supermarket vs warehouse.**
A supermarket optimizes for individual transactions: small purchases, fast checkout, broad selection. A warehouse optimizes for bulk: pallets, forklifts, infrequent large transfers. The same goods, organized differently, for different transaction patterns.

**The library reading room vs the citation index.**
The reading room serves readers who want specific books quickly. The citation index serves researchers who want "all references to this topic." Both are about books; the operations differ; the organization differs.

---

## Production Engineering Perspective

What goes wrong:

- **The analytics-on-OLTP disaster.** Reporting query against production Postgres locks tables for 30 minutes. Customer-facing latency spikes. Mitigation: replica or warehouse.
- **The Snowflake bill shock.** Bad query patterns (full table scans on huge tables) drive bills 10× expected. Snowflake bills per-query compute; learning to write efficient analytical SQL is a skill.
- **The CDC replication lag.** Real-time analytics depends on CDC; CDC backs up 1 hour. Reports lag reality. Fix: monitor; scale CDC infrastructure.
- **The columnar update.** Engineer tries to UPDATE individual rows in ClickHouse. ClickHouse's columnar format makes this very inefficient (rewrite whole columns/blocks). Mitigation: don't update; insert new and use ReplacingMergeTree-like semantics.
- **The "we'll use HTAP" surprise.** Adopted single HTAP system. Discovered that for specific workloads, dedicated systems would have been faster and cheaper. Mitigation: assess workload requirements explicitly.

The senior data engineer's habits:
- **Separate OLTP and OLAP** by default.
- **CDC or scheduled ELT** to keep analytical replicas current.
- **Test analytical queries** at scale.
- **Cost-monitor** OLAP usage.
- **Choose columnar or row** based on workload.

---

## Failure Scenarios

**Scenario 1 — The locked production database.**
Marketing team runs a "quick" analytical query against production Postgres. Query holds locks for 20 minutes. All transactions queue. Site is effectively down. Recovery: kill the query; education; later: replica for analytics.

**Scenario 2 — The Snowflake bill.**
Team migrates analytics to Snowflake. Queries run; everyone happy. Month-end bill: 5× projected. Investigation: many queries scanning whole tables when they could partition-prune. Recovery: training; query review.

**Scenario 3 — The CDC failure.**
CDC pipeline from Postgres to ClickHouse silently fails. Real-time analytics dashboards show stale data. Discovery weeks later when business decisions reference outdated metrics. Lesson: monitor CDC lag.

**Scenario 4 — The HTAP regret.**
Team adopted SingleStore for "one system handles both." Two years later: OLTP performance is acceptable but not ideal; OLAP performance is acceptable but not ideal. Migration to dedicated systems. Lesson: assess specific requirements before HTAP commitment.

**Scenario 5 — The columnar UPDATE.**
Engineer tries to "fix" individual rows in ClickHouse via UPDATE. Query runs for hours rewriting blocks. Production table degraded. Recovery: model as inserts with versioning.

---

## Performance Perspective

- **OLTP**: thousands of small operations per second; sub-millisecond per op.
- **OLAP**: large queries; aggregations over GBs in seconds (with vectorization + parallel).
- **Compression**: 5-30× in columnar; less in row.
- **Vectorization**: 10-100× speedup on aggregations.
- **Disk I/O patterns**: random for OLTP, sequential for OLAP.

---

## Scaling Perspective

- **OLTP vertical**: scales to large machines; sharding for further scale.
- **OLAP horizontal**: MPP scales to many nodes natively.
- **OLTP geographic**: read replicas; multi-region challenging.
- **OLAP geographic**: multi-region warehouses; replication via ELT.
- **Cost**: OLAP often cheaper per byte stored but per-query expensive; OLTP opposite.

---

## Cross-Domain Connections

- **Indexing**: OLTP relies on B-trees; OLAP uses sparse indexes, partitions, statistics. (See [indexing-and-storage-engines.md](./indexing-and-storage-engines.md).)
- **MVCC**: OLTP heavily uses; OLAP often uses simpler concurrency. (See [mvcc-and-isolation-levels.md](./mvcc-and-isolation-levels.md).)
- **Sharding**: both shard differently; OLTP by access key, OLAP by partition. (See [sharding-and-partitioning-strategies.md](../scalability/sharding-and-partitioning-strategies.md).)
- **CQRS**: maps neatly to OLTP-write + OLAP-read split. (See [cqrs-and-event-sourcing.md](../architecture-patterns/cqrs-and-event-sourcing.md).)
- **Replication**: CDC streams from OLTP to OLAP. (See [replication-strategies.md](./replication-strategies.md).)
- **Query optimization**: planner strategies differ per workload. (See [query-optimization-and-execution-plans.md](./query-optimization-and-execution-plans.md).)

The unifying observation: **workload shape drives database design. Mismatching workload to system is one of the most expensive engineering mistakes; matching them well is one of the highest-leverage decisions.**

---

## Real Production Scenarios

- **Snowflake's adoption**: countless case studies of teams moving analytics off OLTP.
- **ClickHouse at Cloudflare, Yandex, others**: real-time analytics at scale.
- **DuckDB's rise**: in-process columnar for embedded analytics. Many "ad-hoc reports" use cases.
- **Databricks' lakehouse vision**: unify warehouse and data lake; published architectures.
- **Discord's switch from MongoDB to Cassandra to ScyllaDB**: documented workload shape evolution.

---

## What Junior Engineers Usually Miss

- That **analytics on OLTP can lock production**.
- That **columnar = compressed + vectorized**, not just "stored differently."
- That **OLTP and OLAP are different products** for good reasons.
- That **HTAP is operationally complex**.
- That **OLAP UPDATEs are typically expensive**.
- That **Snowflake bills per-query compute**.
- That **CDC enables real-time-ish analytics**.
- That **partition pruning is critical** in OLAP.

---

## What Senior Engineers Instinctively Notice

- They **separate workloads** by default.
- They **use CDC** for real-time analytics.
- They **monitor query costs** in OLAP systems.
- They **partition correctly** in OLAP.
- They **avoid OLAP UPDATEs**.
- They **distinguish workload shape** before choosing a system.

---

## Interview Perspective

What gets tested:

1. **"OLTP vs OLAP?"** Tests fundamental literacy.
2. **"Why is columnar good for analytics?"** Sequential reads, compression, vectorization.
3. **"Why is row-oriented good for OLTP?"** Random row access; consistency; transactions.
4. **"What's vectorized execution?"** Batched processing; SIMD.
5. **"How would you design analytics for an OLTP system?"** Replicate to OLAP; CDC.
6. **"What's HTAP?"** Hybrid; trade-offs.
7. **"When to use DuckDB vs Snowflake?"** Embedded vs cloud; size; cost.

Common traps:
- Believing "more memory" fixes OLAP on OLTP.
- Treating columnar as simple "columns instead of rows."

---

## 20% Knowledge Giving 80% Understanding

1. **OLTP = row-oriented, small transactions; OLAP = columnar, big aggregations.**
2. **Compression** is a columnar superpower (5-30×).
3. **Vectorization** is a columnar speedup (10-100×).
4. **Partition pruning** is OLAP's first-line optimization.
5. **CDC bridges** OLTP to OLAP for real-time.
6. **OLAP UPDATEs are expensive**; design as appends.
7. **HTAP exists but is hard**; usually two systems.
8. **MPP scales OLAP** horizontally.
9. **Cost models differ**: OLTP per-instance; OLAP per-query.
10. **Match workload to system** carefully.

---

## Final Mental Model

> **OLTP and OLAP are not "two settings of the same database." They're different products optimized for different workloads. Columnar storage, vectorization, partitioning, compression — these are OLAP's tools. Row storage, B-trees, MVCC, fine-grained locking — these are OLTP's. Trying to make one do the other's job ends in pain. Picking the right tool for each workload, with CDC or ETL between them, is the reliable architecture.**

The senior data engineer evaluates a system's workload shape before choosing infrastructure. Aggregations over millions of rows? OLAP. Per-user transactions? OLTP. Both? Two systems with replication. The cost of running two systems is small relative to the cost of forcing one to do both jobs.

Modern teams often have: an OLTP database for the application, a CDC pipeline to a data lake or warehouse, and a query engine for analytics. The architecture matches the work. The teams that try to consolidate suffer; the teams that specialize ship.

That's OLTP vs OLAP. That's columnar storage. That's the most consequential architectural choice in data systems — and one that's still surprisingly often gotten wrong by teams that don't think about workload shape before reaching for tools.
