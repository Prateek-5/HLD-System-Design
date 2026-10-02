# Indexing & Storage Engines

> *"You cannot understand a query plan if you don't understand the shape of the data on disk. The plan is a strategy. The disk is the terrain."*

---

## Topic Overview

Every database is, at heart, two things stacked on top of each other: a *storage engine* that decides how bytes are laid out on disk and how to find them again, and a *query layer* that decides what to ask the storage engine for. Most performance conversations are about query layers. Most performance *problems* are about storage engines.

Indexes are how a storage engine answers the question "where is the data I want?" without reading every page. They are the difference between a 50ms point lookup and a 50-second sequential scan. They are also the reason your write throughput is half of what you expected — because every index is a parallel data structure that has to be maintained in lockstep with the table.

The two dominant storage engine families — **B+ tree based** (Postgres, InnoDB, SQL Server, Oracle) and **LSM tree based** (Cassandra, RocksDB, ScyllaDB, modern Mongo) — are not competing implementations of the same idea. They are *different bets about the future shape of your workload*. Understanding which bet they made, and why, is what separates engineers who tune databases from engineers who guess at parameters.

---

## Intuition Before Definitions

Imagine a phone book.

If you want to find "Smith, J." you don't read from "Aaron, A." onward — you flip to roughly the middle, see you're past S, flip back, narrow down. The phone book is sorted, and that single property turns linear search into something close to logarithmic. That's a B-tree, basically. Sorted data, navigable by halving.

Now imagine your phone book has 100 million entries and gets 10,000 new names per second. You can't keep re-sorting it on the fly. So you do something different: you keep the *main* phone book sorted, but new entries go into a small "pending" notebook. Every so often, you sit down and merge the pending notebook into the main book. While the pending notebook is small, lookups check both — fast. Over time you might end up with several pending notebooks of different sizes, periodically merged into bigger ones.

That's an LSM tree. Different bet: writes are cheap (just append), reads pay the cost of looking in multiple places.

That's the entire decision tree of modern storage engines, in one analogy:

> **B-tree: keep everything sorted, pay on every write. LSM: append cheaply, pay on every read (and on compaction).**

Indexes are sub-instances of the same idea. A secondary index is a smaller, separately-sorted phone book that maps "Last Name" → "row location," letting you jump into the main book without scanning it.

---

## Historical Evolution

**Era 1 — Heap files and sequential scans.**
Early databases stored rows in arrival order. Finding anything specific meant scanning. This was fine when datasets fit in core memory and "big" meant a megabyte.

**Era 2 — Hash indexes.**
Constant-time lookups, beautiful for equality. Useless for range queries. Doesn't survive memory pressure well — collision chains explode. Still alive in Postgres `hash` indexes and, more importantly, in in-memory caches like Redis.

**Era 3 — B-trees and B+ trees.**
Bayer & McCreight, 1970. Designed specifically for *block-oriented storage*: each node holds many keys, fanout is wide (hundreds per node), depth stays shallow (3–5 levels for billions of rows). The B+ tree refinement keeps all data in leaf pages, linked together for range scans. This single data structure is the workhorse of OLTP for fifty years and counting.

**Era 4 — Log-structured storage.**
Researchers in the 90s noticed that *random writes are catastrophically slow* on rotating disks compared to sequential writes. The idea: turn random updates into sequential appends, defer the sorting work until later. Log-structured filesystems came first; log-structured merge trees (O'Neil et al., 1996) brought the idea to indexes.

**Era 5 — LSM-tree dominance for write-heavy workloads.**
Bigtable, Cassandra, HBase, LevelDB, RocksDB. The rise of timeseries, IoT, social, and cloud-scale workloads — all heavily write-skewed — made LSM the natural fit. RocksDB became a building block for everything from CockroachDB to Kafka Streams to ML feature stores.

**Era 6 — Convergence and specialization.**
Modern systems blur the lines. SQL Server has columnstore indexes (column-oriented storage). Postgres has BRIN, GIN, GiST, SP-GiST for specialized cases. ClickHouse uses sparse indexes optimized for OLAP. Storage engines are no longer one-size-fits-all — they're a portfolio.

The pattern across eras: **the disk's physics shaped the data structures, and as the disk changed (HDD → SSD → NVMe → cloud block storage), the optimal data structures shifted.**

---

## Core Mental Models

**1. The storage engine answers two questions: where is row X, and what's near it?**
Indexes are the answer-keys. Different index types optimize for different question shapes.

**2. Every index is a tax on writes.**
Insert one row, update N indexes. This is not optional. The tax is paid in I/O, in CPU, in WAL volume, and in lock contention. The right number of indexes is the *minimum* set that makes your hot read paths fast — not "every column someone might filter on."

**3. Random vs sequential I/O is the hidden ruler.**
On HDDs, random I/O was 100× slower than sequential. On SSDs, the gap shrinks to ~10×. On NVMe, ~3×. But it never goes to zero, and the *write amplification* of random small writes still wears out flash. Storage engine design is downstream of this single ratio.

**4. Reads and writes are zero-sum at some layer.**
You can be fast at reads (B-tree) by paying on writes. You can be fast at writes (LSM) by paying on reads or compaction. You can be fast at both for *small* datasets by living in memory. There is no design that's free in all dimensions.

**5. The query plan is a treasure map; the storage layout is the terrain.**
A "good" plan on bad terrain is still slow. Indexes turn bad terrain into navigable roads — selectively, where it matters.

---

## Deep Technical Explanation

### B+ trees in detail

A B+ tree of order k:
- Internal nodes hold up to k keys and k+1 pointers.
- Leaf nodes hold the actual key-value pairs (or key-rowID pairs in secondary indexes), linked left-to-right.
- Height is log_k(N). For k ≈ 200 and N = 1 billion, height ≈ 4.

Critical implications:
- Point lookup: ~4 disk reads. With caching, often 1–2.
- Range scan: walk the leaf-level linked list, almost free per row after the first.
- Insert: descend, possibly split nodes upward. Splits are O(log N) amortized but can cause cascading writes.
- Delete: similar, with possible merges. Most engines defer merges (they don't actually shrink the tree) — leading to *tree bloat* over time.

**Page-level mechanics:**
- Each node is one disk page (typically 8KB or 16KB).
- Branching factor is determined by `page_size / (key_size + pointer_size)`.
- Wider keys = lower fanout = deeper tree = more I/O.
- This is why indexing a `varchar(255)` column is more expensive than indexing an `int`.

**Write path:**
1. Find the leaf.
2. WAL the change.
3. Modify the in-memory page.
4. Page is eventually flushed by the background writer.
5. Other indexes also updated, each with their own WAL entry.

The hidden cost isn't the B-tree itself — it's the *secondary indexes* attached to the same table.

### LSM trees in detail

Components:
- **Memtable**: in-memory sorted structure (often a skip list). All writes go here first.
- **WAL**: persistent log so the memtable is durable.
- **SSTables (Sorted String Tables)**: when memtable fills, flush to disk as an immutable sorted file.
- **Compaction**: background process that merges SSTables to reduce the number of files reads must check.

**Read path:**
1. Check memtable.
2. Check most recent SSTable.
3. Continue down levels until found or exhausted.
4. Bloom filters short-circuit "not in this SSTable" decisions.

**Write amplification:**
A value written once may be rewritten many times during compactions. Levels-style compaction (RocksDB default) has write amplification proportional to the number of levels (typically 10–30×). Tiered compaction trades this for *space* amplification. The compaction strategy is the single biggest tuning knob in an LSM system.

**Read amplification:**
Without bloom filters, every read might check every SSTable. With well-tuned bloom filters, reads hit ~1–2 SSTables on average. This is why Cassandra and RocksDB obsess about bloom filter false positive rates.

**Space amplification:**
Old versions of the same key linger across multiple SSTables until compaction reconciles them. Active datasets can be 1.5–3× their logical size on disk.

### Heap vs clustered

- **Heap-organized tables** (Postgres, Oracle by default): the table is a heap; the primary key index points *into* the heap. Secondary indexes also point at the heap. Updates can move the row, requiring index updates.
- **Clustered (index-organized) tables** (InnoDB primary, SQL Server): the table *is* a B+ tree on the primary key. Secondary indexes hold primary key values, not row pointers — so secondary index lookups become two lookups (the index, then the primary key tree).

This single architectural choice determines:
- Whether range scans on the PK are blazing fast (clustered) or just normal (heap).
- Whether secondary indexes are cheap to maintain (heap with TID pointers) or relatively expensive (clustered, two trees per lookup).
- Whether `UPDATE` of indexed columns causes cascading rewrites (yes, in different ways for both).

### Specialized indexes worth knowing

| Index type | Best for | Cost |
|---|---|---|
| Hash | Equality only, in-memory | No range, hash collisions |
| B-tree (B+) | General purpose, ranges | Updates expensive on hot rows |
| BRIN | Massive sequentially-correlated data | Useless for random data |
| GIN | Full-text, JSONB, arrays | Slow updates, large size |
| GiST | Geospatial, custom types | Complex tuning |
| Bitmap | Low-cardinality, OLAP | Bad under writes |
| Columnstore | Analytical aggregates | Bad for OLTP point lookups |

The right question is never "should I add an index?" — it's "which index *type* fits this query shape and update frequency?"

---

## Real Engineering Analogies

**The library card catalog.**
A B+ tree is a card catalog: cards alphabetized in drawers, drawers labeled with ranges, drawers grouped by floor. To find a book, you walk down the hierarchy. The cards (leaves) are linked alphabetically so you can browse "all books starting with 'P'." Adding a new book means inserting a card — possibly splitting a drawer if it overflows. Periodically, librarians rebalance the catalog.

**The mailroom analogy for LSM.**
Imagine a mailroom that receives 10,000 letters a day. Sorting each letter into the right pigeonhole on arrival is too slow. So instead, letters go into "today's bin" — unsorted, fast. At end of day, today's bin is sorted into a daily folder. Every week, daily folders merge into a weekly folder. Every month, weekly folders merge into a monthly archive. Looking up "where is John's letter from last Tuesday?" means checking today's bin, this week's daily folder, possibly last week's, etc. Slow but bounded. Every layer is sorted, just at a different timescale.

That mailroom is RocksDB.

---

## Production Engineering Perspective

Things that actually matter at 3am:

- **Index bloat.** A B-tree never shrinks naturally. Tables that churn (high update + delete) develop bloated indexes that no longer fit in cache. `pg_stat_user_indexes` and `pgstattuple` exist for a reason.
- **The covering index trick.** Adding extra columns to an index so the query can be answered from the index alone (`INCLUDE` in Postgres, "covering index" in SQL Server). Eliminates the heap fetch entirely. Massive win for hot read paths.
- **Index selectivity is everything.** An index on `gender` with two values is useless. An index on `email` with 50M unique values is golden. Cardinality matters more than column "importance."
- **Composite index column order.** `(a, b)` is not the same as `(b, a)`. The first column must appear in the WHERE clause for the index to be useful. Junior engineers index every permutation; seniors think about query patterns and index once.
- **Compaction storms in LSM systems.** A tier-2 → tier-3 compaction that touches 100GB can saturate disk I/O for 20 minutes. If you don't rate-limit it, your p99 latency goes through the roof during compaction.
- **Write stalls in RocksDB.** When the memtable fills faster than it can flush, writes block. When L0 has too many files, writes block. Cascading backpressure that looks like "the database froze."
- **Vacuum and B-tree interaction (Postgres).** Vacuum can reclaim space inside index pages but can't shrink the index. `REINDEX CONCURRENTLY` is the heavy artillery.

The senior engineer's habit: **periodically audit indexes**. `pg_stat_user_indexes` shows unused indexes (`idx_scan = 0`). Dropping them is one of the highest-leverage performance wins available — every index dropped accelerates every write to that table.

---

## Failure Scenarios

**Scenario 1 — The 100-index table.**
A reporting database accreted indexes over years. Every analyst added "just one more" for their dashboard. Now the table has 47 indexes. INSERTs take 800ms. Bulk loads time out. Migration to a slimmer index set takes a week of coordination because nobody knows which indexes are still used.

**Scenario 2 — The wrong storage engine for the workload.**
A timeseries application launched on Postgres for "transactional safety." Six months in, write throughput is the bottleneck — every metric write maintains 8 indexes. Migration to TimescaleDB (B-tree + chunking) or to an LSM-based system buys 5–10× write throughput, at the cost of operational learning curve.

**Scenario 3 — Compaction collapse.**
A Cassandra cluster operating fine for months suddenly sees write latency spikes. Investigation: leveled compaction can't keep up because data ingestion grew 3× without re-tuning. Pending compactions queue up, L0 fills, writes stall, replicas timeout, gossip drops nodes, cluster goes into split-brain.

**Scenario 4 — Index page split storms.**
A primary key is a UUIDv4 — random by design. Every insert lands in a different leaf page, causing splits across the entire tree. Sequential UUIDs (UUIDv7, ULIDs) would have inserted into the rightmost leaf and avoided 90% of the splits. Migration: hours of rebuilding indexes during a maintenance window.

**Scenario 5 — Bloom filter false positive cascade.**
An LSM cluster's bloom filters were sized for an older dataset. Data grew 10×. False positive rate climbed from 1% to 12%. Read amplification doubled. Hot key reads now check 5 SSTables instead of 1. Latency: 2ms → 18ms. Root cause is invisible without checking bloom filter metrics.

---

## Performance Perspective

- **Cache locality wins everything.** A 10GB index that fits in RAM is *thousands of times* faster than a 10GB index that doesn't. Whatever you do, fight for the working set to fit in cache.
- **Sequential vs random I/O still matters on SSDs.** Less than on HDDs, but enough that LSM's append-only writes still beat B-tree's random updates for write-heavy workloads.
- **CPU cache also matters.** Modern B-tree implementations care deeply about cache-line alignment, prefetching, and binary search vs linear search inside a node.
- **The buffer pool is your real database.** Disk is the cold storage. Tuning `shared_buffers` / `innodb_buffer_pool_size` / equivalent is more impactful than almost any other knob.

---

## Scaling Perspective

- **Vertical:** B-trees scale beautifully on a single machine into the multi-TB range as long as RAM keeps pace with the working set.
- **Horizontal reads:** straightforward via replication. Indexes are replicated alongside data.
- **Horizontal writes:** the hard problem. Sharded B-trees (Vitess, Citus) work but have cross-shard query pain. LSM-based distributed systems (Cassandra, ScyllaDB, RocksDB-backed CockroachDB) embrace partitioning at the storage layer.
- **The fundamental scaling question:** is your workload write-bound or read-bound? B-trees and LSMs are not interchangeable — picking wrong is a six-month rewrite.
- **Caching as scaling:** at large scale, the index hierarchy extends *outside* the database — Redis, Memcached, application caches. The principle is the same: closer to the CPU = faster, less consistent.

---

## Cross-Domain Connections

- **MVCC**: every index entry needs visibility info; bloated indexes from MVCC churn are the silent killer of B-tree performance. (See [mvcc-and-isolation-levels.md](mvcc-and-isolation-levels.md).)
- **Distributed systems:** consistent hashing in distributed caches and partitioning is, structurally, a hash index across machines. Range partitioning is a B-tree at the cluster level.
- **Filesystems:** ext4 uses B-trees for inodes. ZFS and Btrfs are copy-on-write trees. The same data structures recur at every layer of the stack.
- **JavaScript runtime:** V8's hidden classes (shape transitions) function similarly to indexes — they cache "where is the field with name X?" so property access doesn't have to scan. Same instinct, different domain.
- **Networking:** routing tables in routers are tries (radix trees), which are conceptually a B-tree variant optimized for prefix matching.
- **Operating systems:** page tables are tree structures with caching (TLBs) — exactly the same architecture as databases with buffer pools.

The unifying insight: **fast lookup over large data is always a tree, and fast updates over a tree are always a battle with random I/O.**

---

## Real Production Scenarios

- **Discord's switch from MongoDB to Cassandra (2017)**, and later to ScyllaDB. Driven entirely by storage engine fit: write-skewed workload, MMAP-based MongoDB hitting working-set limits, LSM-based Cassandra winning until coordinator overhead became the bottleneck.
- **GitHub's MySQL operations**: famous engineering posts on how they manage online schema migrations and index rebuilds at scale, with `gh-ost` orchestrating the InnoDB realities.
- **CockroachDB on RocksDB → Pebble**: rewrote the storage engine in Go to gain control over compaction behavior. The tuning of compaction is a first-class engineering concern, not a footnote.
- **Uber's migration from Postgres to MySQL (2016)** — controversial, but their stated reason was index maintenance overhead in Postgres' heap-organized tables under their workload.
- **Stripe's index audits**: documented practice of regularly hunting unused indexes and dropping them, treating index hygiene as a continuous activity.

---

## What Junior Engineers Usually Miss

- That **adding indexes makes writes slower**, full stop. Every index is a parallel structure to maintain.
- That **column order in composite indexes matters** and `(a, b)` ≠ `(b, a)`.
- That **a query using an index is not automatically fast** — index scans on a large match set can be slower than a sequential scan.
- That **`SELECT *` defeats covering index optimizations**.
- That **reindexing is sometimes the right answer** for performance regression in a long-running database.
- That **storage engine choice constrains what's achievable** — no amount of query tuning fixes a B-tree handling a write-skewed workload.

---

## What Senior Engineers Instinctively Notice

- They check the **explain plan** before tuning, not after.
- They ask "what does this table's working set look like in RAM?" before reaching for indexes.
- They recognize that **`UUID` primary keys cause B-tree page split storms** and reach for sortable alternatives.
- They **monitor unused indexes** and drop them as part of routine hygiene.
- They know which **bloom filter false positive rate** their LSM is configured for.
- They don't pick "Postgres vs MySQL vs Cassandra" by feature checklist — they pick by *workload shape*.
- They treat the **buffer pool hit rate** as a north-star metric.

---

## Interview Perspective

What interviewers are testing:

1. **Do you know why a B-tree is shaped like a B-tree?** Specifically, that fanout × depth = log scaling, and that fanout is dictated by page size. The candidate who says "log N" without saying "because page size limits fanout" is reciting, not reasoning.
2. **Can you explain LSM vs B-tree as a tradeoff?** Not "LSM is faster for writes" — *why* it's faster, what it costs in reads and space, and when each is the right call.
3. **Composite index column order question.** Almost guaranteed to come up. The candidate who knows `(status, created_at)` is great for "filter by status, sort by date" but not for "filter by date, sort by status" is showing real understanding.
4. **Covering indexes.** Bonus points for mentioning them unprompted on a hot read path question.
5. **Indexed UUID primary keys.** A trap question. The right answer involves random vs sequential UUIDs and B-tree page split behavior.
6. **The "should I add an index" reflex test.** The right answer is *"it depends on the read/write ratio, the cardinality, and what's already indexed."*

Common traps:
- Thinking more indexes = faster.
- Confusing clustered and non-clustered indexes.
- Missing the difference between LSM read amplification and write amplification.
- Forgetting that indexes need to fit (mostly) in RAM to actually help.

---

## Worked Example — Choosing Indexes for a Real Schema

A `tickets` table in a multi-tenant ticketing system. ~100M rows. Several common queries.

### The schema

```sql
CREATE TABLE tickets (
    id BIGSERIAL PRIMARY KEY,
    tenant_id BIGINT NOT NULL,
    assignee_id BIGINT,
    status TEXT NOT NULL,           -- 'open', 'pending', 'closed', etc.
    priority INTEGER NOT NULL,       -- 1-4
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    title TEXT NOT NULL,
    body TEXT,
    tags TEXT[]
);
```

### The queries

Top queries from `pg_stat_statements`:

```sql
-- Q1 (40% of reads): list tickets for a tenant
SELECT * FROM tickets
 WHERE tenant_id = ?
 ORDER BY created_at DESC
 LIMIT 50;

-- Q2 (25%): tickets assigned to a user
SELECT * FROM tickets
 WHERE tenant_id = ? AND assignee_id = ?
 ORDER BY priority DESC, created_at DESC;

-- Q3 (15%): open tickets for a tenant
SELECT * FROM tickets
 WHERE tenant_id = ? AND status = 'open'
 ORDER BY priority DESC;

-- Q4 (10%): full-text search on title
SELECT * FROM tickets
 WHERE tenant_id = ? AND title ILIKE '%database%';

-- Q5 (5%): tag search
SELECT * FROM tickets
 WHERE tenant_id = ? AND 'urgent' = ANY(tags);
```

### Naive index strategy (the wrong way)

```sql
-- One index per filter column
CREATE INDEX idx_tickets_tenant ON tickets (tenant_id);
CREATE INDEX idx_tickets_assignee ON tickets (assignee_id);
CREATE INDEX idx_tickets_status ON tickets (status);
CREATE INDEX idx_tickets_priority ON tickets (priority);
CREATE INDEX idx_tickets_created_at ON tickets (created_at);
```

Why this is bad:
- 5 indexes; every INSERT updates all 5.
- Most queries combine `tenant_id` with another filter; a single-column index on `tenant_id` is too unselective (all of one tenant's data).
- `status` has cardinality of ~5; index is barely useful.

### Better — composite indexes matched to queries

```sql
-- Q1: list by tenant, sorted by created_at
CREATE INDEX idx_tickets_tenant_created
    ON tickets (tenant_id, created_at DESC);
-- Postgres can use this to satisfy ORDER BY without a separate sort.

-- Q2: tickets by tenant + assignee, sorted by priority
CREATE INDEX idx_tickets_tenant_assignee_priority
    ON tickets (tenant_id, assignee_id, priority DESC, created_at DESC);

-- Q3: open tickets by tenant
CREATE INDEX idx_tickets_tenant_open
    ON tickets (tenant_id, priority DESC, created_at DESC)
    WHERE status = 'open';
-- Partial index: only includes open tickets. Smaller, faster.

-- Q4: full-text search
CREATE INDEX idx_tickets_title_fts
    ON tickets USING gin (to_tsvector('english', title));
-- GIN index for full-text search.

-- Q5: tag membership
CREATE INDEX idx_tickets_tags
    ON tickets USING gin (tags);
-- GIN index for array membership.
```

### Why composite > single-column

`(tenant_id, created_at DESC)` lets Postgres:
- Filter by tenant_id (B-tree navigation).
- Read in already-sorted order (no separate sort step).

A single-column `tenant_id` index would have to:
- Find rows by tenant.
- Sort them by created_at.
- LIMIT 50.

For 1M rows per tenant, that's a 1M-row sort on every query. Composite index turns it into reading the first 50 rows.

### Why `WHERE status = 'open'` is a partial index

`status = 'open'` matches ~5-10% of rows. A partial index only includes those rows. Smaller; less to scan; faster.

The same selectivity from a regular index would still scan all of the relevant tenant's rows.

### Index sizes

For the 100M-row table:

```
Heap (table itself):                     50 GB
idx_tickets_pkey (B-tree):               5 GB
idx_tickets_tenant_created (B-tree):     5 GB
idx_tickets_tenant_assignee_priority:    7 GB
idx_tickets_tenant_open (partial):       0.7 GB (only ~10% of rows)
idx_tickets_title_fts (GIN):             10 GB
idx_tickets_tags (GIN):                  3 GB
                                         ──────
Total indexes:                           30 GB
Storage overhead:                        60% of table
```

Acceptable. The naive-strategy 5-index version had similar index size but worse query performance.

### Verification with EXPLAIN

```sql
EXPLAIN ANALYZE
SELECT * FROM tickets
 WHERE tenant_id = 42 AND assignee_id = 1234
 ORDER BY priority DESC, created_at DESC LIMIT 50;

-- Plan:
-- Limit  (cost=0.56..200.34 rows=50 width=180)
--   ->  Index Scan using idx_tickets_tenant_assignee_priority on tickets
--         (cost=0.56..2003.45 rows=500 width=180)
--         Index Cond: ((tenant_id = 42) AND (assignee_id = 1234))
-- Planning Time: 0.234 ms
-- Execution Time: 1.823 ms
```

Reads 50 rows from the index, in order, no sort step. Fast.

### What to drop

After deploying the new indexes, audit unused ones:

```sql
SELECT indexrelname, idx_scan
  FROM pg_stat_user_indexes
 WHERE schemaname = 'public'
 ORDER BY idx_scan;
```

Indexes with `idx_scan = 0` after a week have no usage. Drop them. Each drop accelerates writes.

---

## Recent Production References (2023-2024)

- **Postgres 16's improvements to parallel index builds**: faster CREATE INDEX CONCURRENTLY.
- **MySQL 8's invisible indexes**: test index removal without dropping. Operational discipline tool.
- **Datadog's Postgres tuning posts**: documented index strategies at scale.
- **Stripe's database engineering**: ongoing public engineering on indexes for high-write OLTP.
- **CockroachDB's regional-by-row tables**: indexes co-located with data per region.
- **The "drop unused indexes" practice**: increasingly automated; many teams have lint rules.
- **TimescaleDB's hypertables**: indexes per partition; specialized for time-series.

---

## 20% Knowledge Giving 80% Understanding

1. **B-tree = sorted, random updates expensive. LSM = appended, sorted in background, reads check multiple files.**
2. **Every index taxes writes.** The right number is the minimum that makes hot reads fast.
3. **Cardinality and selectivity matter more than which column is "important."**
4. **Composite index `(a, b)` only helps when `a` is in the WHERE clause.**
5. **The buffer pool / page cache is your real database. Working set must fit.**
6. **Heap vs clustered tables changes the cost model of secondary indexes.**
7. **LSM trees are write-optimized; their pain shows up in compaction and read amplification.**
8. **Random PKs (UUIDv4) destroy B-tree insert performance. Use sortable IDs.**
9. **Drop unused indexes ruthlessly. They tax every write for no benefit.**
10. **The query plan is downstream of the storage layout. Look at terrain first.**

---

## Final Mental Model

> **An index is a deal: pay extra on writes, pay less on reads. The art of database engineering is making that deal *exactly* where it pays off, and nowhere else.**

The hardware shapes the data structure. The data structure shapes the query plan. The query plan shapes user-perceived performance. When something is slow, walk the chain — almost always, the answer is at the storage layer, not the SQL.

A senior engineer's instinct, tuning a database, isn't to add indexes. It's to look at the working set, the cache hit rate, the index list, the row width, and the access pattern — and to *subtract* whatever isn't earning its keep.

That's storage engineering. That's the disk you're standing on, every time you write a query.
