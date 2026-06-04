# Indexes — Faster Reads, at a Cost

## A. Intuition First
An index is a table-of-contents for your data. Without it, finding a row means scanning every row. With it, O(log n) lookups.

**Trade**: faster reads, slower writes (index must be maintained), more storage.

## B. Mental Model
An index is a **data structure over a column (or columns)** mapping value → row location.
- **B-tree**: ordered, supports range queries, most common.
- **Hash index**: O(1) equality lookup, no range queries.
- **LSM-tree**: merged sorted runs; write-optimized. Used by Cassandra, RocksDB.
- **Inverted index**: for full-text search. Used by Elasticsearch, Lucene.
- **Spatial index** (R-tree, geohash): geo queries.

## C. Internal Working
### B-tree lookup
- Balanced tree, each node holds K keys and K+1 pointers.
- Depth ~ log_K(N). For N=1B, K=200, depth ≈ 4.
- Every read: 4 disk I/Os (or cached pages).

### Write cost
Insert → walk tree → possibly split nodes → write new page. Plus every secondary index must be updated. A table with 10 indexes pays 10× write cost.

### Dense vs sparse
- **Dense**: one index entry per row. More memory, faster exact lookup.
- **Sparse**: one entry per page/block. Less memory, slower point lookup (scans within page). Common on primary-key-ordered data (MySQL InnoDB's "clustered index" is sparse at the page level).

### Composite index
Index on `(a, b, c)` speeds queries on `a`, `(a,b)`, `(a,b,c)`. Does NOT help on `b` or `c` alone (left-most prefix rule).

### Covering index
Index that contains all columns a query needs → query answered from index alone, no row fetch.

## D. Visual Representation
```
idx_email:
     ┌─'a@x.com'─┐  ┌─'m@x.com'─┐
     │           │  │           │
     ▼           ▼  ▼           ▼
   row-ptr     row-ptr         row-ptr
```

## E. Tradeoffs
- Every write hits every index.
- Indexes consume memory (buffer pool) and disk.
- Over-indexing → slow writes, DB can't fit indexes in RAM, thrash.
- Under-indexing → sequential scans, slow reads.
- Rule of thumb: index what you filter and sort by; not every column.

## F. Interview Lens
- "Why does `SELECT * WHERE email = ?` use the email index but not `SELECT email WHERE name = ?`?" — left-most prefix; need index on name.
- "What's a covering index?"
- "When does adding an index hurt?"
- Pitfalls: assuming indexes are free; not checking `EXPLAIN ANALYZE`.

## G. Real-World Mapping
- Postgres: B-tree default; supports GIN, GiST, BRIN.
- MySQL: InnoDB uses clustered B+ tree on primary key.
- Cassandra/DynamoDB: partition + clustering keys = the index.
- Elasticsearch: inverted index for text.

## H. Questions
**Beginner**: What does an index do? What's the cost?
**Intermediate**: What's a composite index? When does it help?
**Advanced**:
1. Design indexes for a table queried by 5 different patterns.
2. Why is full-text search impractical with B-trees? What data structure fits?

## I. Mini Design — "Index a social media table"
Table `posts(id, user_id, created_at, content, likes)`. Queries:
- By id (PK): already indexed.
- Feed for user: `WHERE user_id=? ORDER BY created_at DESC` → composite `(user_id, created_at DESC)`.
- Top liked: `ORDER BY likes DESC LIMIT 100` → partial index on `likes` if bounded.
Avoid indexing `content` with B-tree; use Elasticsearch for text search.

## J. Cross-Topic Connections
- [SQL](sql-databases.md), [NoSQL](nosql-databases.md), [Normalization](normalization-denormalization.md).

## K. Confidence Checklist
- [ ] Understands dense vs sparse.
- [ ] Knows left-most prefix rule.
- [ ] Can defend / reject each index.
- [ ] Reads query plans.

### Red flags
- ❌ "Just add an index" without understanding cost.
- ❌ Indexing high-cardinality + high-churn columns blindly.

## L. Potential Gaps & Improvements
- **BRIN (Block Range INdex)** — stores min/max values per block range instead of every row, so it stays tiny on huge, naturally-ordered tables (e.g. time-series); cheap to maintain when rows arrive in order.
- **GIN (Generalized Inverted Index)** — maps each contained value (words, JSONB keys, array elements) to the rows holding it; the index behind fast full-text search and `jsonb @>` containment queries. (→ see Advanced Questions)
- **GiST (Generalized Search Tree)** — a balanced-tree framework for "fuzzy" matches like geometric overlap, ranges, and nearest-neighbour search; learn it when B-tree equality/ordering isn't enough.
- **Index-only scan** — query is answered entirely from the index without touching the table heap; matters because skipping heap reads is a big latency win for covering queries. (→ see Interview Lens)
- **Bitmap scan** — builds an in-memory bitmap of matching row locations from one or more indexes, then visits the heap in physical order; bridges the gap when many rows match but a full table scan is still overkill.
- **Partial / filtered index** — an index built over only the rows matching a `WHERE` predicate (e.g. `WHERE active = true`); smaller and faster when you only ever query a subset.

**🔧 How to close:** Spin up Postgres (`docker run --rm -e POSTGRES_PASSWORD=pw -p 5432:5432 postgres`), create a table with a few hundred-thousand rows via `generate_series`, then compare `EXPLAIN (ANALYZE, BUFFERS) SELECT ...` before and after `CREATE INDEX` — watch the plan switch from `Seq Scan` to `Index Only Scan` / `Bitmap Heap Scan` and note the drop in shared-buffer reads.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🎯 Gap 1 — Partial & Index-Only Scans (squeezing more out of what you already know)
- 🔹 **What it is**: A *partial index* covers only rows matching a `WHERE` predicate (e.g. `WHERE active = true`); an *index-only scan* answers a query entirely from the index, never touching the table heap.
- 🔹 **Why it matters**: These are the two cheapest, highest-leverage optimizations on top of plain B-trees — smaller indexes and skipped heap reads — and both show up constantly in `EXPLAIN` tuning.
- 🔹 **Connection**: This file's "covering index" (§C) is exactly the prerequisite for an index-only scan; the partial index is the disciplined version of "index what you filter by" (§E).
- 🔹 **When needed**: 🟢 **Foundational** — most readers can apply these today on any real query.
- 🔹 **Intuition**: A partial index is a phone book that lists *only* the businesses still open — thinner, faster to flip through, useless for the closed ones you never look up.
- 🔹 **If you go deeper**: Read the Postgres docs on "Index-Only Scans and Covering Indexes" and "Partial Indexes"; build a table, add `WHERE deleted = false`, and watch the index size and plan change.
- 🔹 **Interview hook**: *"You query only active users out of 50M rows, 2% active. How do you index it?"* → partial index on the predicate, ideally covering the selected columns so it's index-only.

---

#### 🗺️ Gap 2 — Specialized Index Types: GIN, GiST, BRIN
- 🔹 **What it is**: Postgres index families for cases B-trees can't serve well — GIN (Generalized Inverted Index) for full-text/JSONB/array containment, GiST (Generalized Search Tree) for geometric/range/nearest-neighbour, BRIN (Block Range INdex) for huge naturally-ordered tables.
- 🔹 **Why it matters**: Knowing *which* structure fits *which* access pattern is the core skill the "why not just B-tree everything?" interview question probes.
- 🔹 **Connection**: §B already names inverted, spatial, and LSM indexes; this gap maps those abstract structures onto the concrete Postgres types you'll actually `CREATE INDEX ... USING`.
- 🔹 **When needed**: 🟡 **Mid-level** — relevant once you handle search, geo, or time-series data.
- 🔹 **Intuition**: Different tools for different jobs — a B-tree is a sorted dictionary, GIN is the index at the back of a textbook (word → pages), BRIN is the chapter-range summary on the spine.
- 🔹 **If you go deeper**: Try `CREATE INDEX USING GIN (to_tsvector('english', content))` for text, a GiST index on a `geometry`/`tsrange` column, and a BRIN index on a `created_at` time-series table; compare sizes.
- 🔹 **Interview hook**: *"Full-text search on a B-tree — why impractical, and what fits?"* → B-trees order whole values, not contained tokens; an inverted index (GIN/Lucene) maps each token to its rows.

---

#### ⚖️ Gap 3 — Bitmap Scans & How the Planner Chooses
- 🔹 **What it is**: A bitmap scan builds an in-memory bitmap of matching row locations from one or more indexes, then visits the heap in physical order; the planner picks it (vs index scan vs seq scan) based on estimated selectivity and statistics.
- 🔹 **Why it matters**: It explains *why an index you created isn't being used* — the most common real-world indexing surprise — and ties indexing to the cost-based optimizer.
- 🔹 **Connection**: §F warns against "not checking `EXPLAIN ANALYZE`"; this gap teaches you to *read* what the planner decided and why a Bitmap Heap Scan appeared instead of an Index Scan.
- 🔹 **When needed**: 🟡 **Mid-level** — essential once you're debugging slow queries in production.
- 🔹 **Intuition**: Instead of fetching books one-by-one as you find them in the catalog (random walking), you jot down every shelf location first, then sweep the aisles once in order — fewer back-and-forth trips.
- 🔹 **If you go deeper**: Read Postgres "Row Estimation Examples" and run `ANALYZE`; deliberately make a query match 30% of rows and watch the plan flip from Index Scan to Bitmap to Seq Scan as selectivity drops.
- 🔹 **Interview hook**: *"You added an index but the query still does a seq scan — why?"* → low selectivity / stale statistics; the planner estimates the heap fetches cost more than scanning.

---

#### 🧱 Gap 4 — Write Amplification & LSM-Tree Trade-offs
- 🔹 **What it is**: The hidden cost of indexing under heavy writes — every secondary B-tree must be updated and pages split, while LSM-trees (Log-Structured Merge) instead buffer writes in memory and merge sorted runs in the background, trading read amplification for write throughput.
- 🔹 **Why it matters**: At scale, the index *write* path, not the read path, becomes the bottleneck; this is the depth that separates "add an index" from designing a write-heavy store.
- 🔹 **Connection**: §C says "a table with 10 indexes pays 10× write cost" and §B names LSM-trees (Cassandra, RocksDB); this gap explains the mechanism behind both and when you'd choose one engine over the other.
- 🔹 **When needed**: 🔴 **Senior** — deep storage-engine territory, mostly for infra and high-write-volume design rounds.
- 🔹 **Intuition**: A B-tree is filing each document into the right cabinet immediately (tidy reads, slow filing); an LSM-tree is tossing papers into an inbox and sorting them in batches later (fast filing, slower lookups until merged).
- 🔹 **If you go deeper**: Read the original LSM-tree paper (O'Neil et al., 1996) and RocksDB's compaction docs; benchmark write throughput on a heavily-indexed InnoDB table vs RocksDB-backed MyRocks.
- 🔹 **Interview hook**: *"Why does Cassandra ingest writes faster than a B-tree RDBMS?"* → LSM appends to an in-memory memtable + WAL and defers sorting to background compaction, avoiding in-place page splits per write.

---

### 🏆 Start here if you have limited time
1. **Partial & index-only scans** — pure leverage on the B-trees you already understand; applies to almost every real query.
2. **Bitmap scans & planner choice** — the fastest way to stop being surprised by "my index isn't used."

---

### 🧭 Suggested Deep Dive Order
1. **Partial & index-only scans** (~45 min; immediate payoff on real queries).
2. **Bitmap scans & how the planner chooses** (~1h; turns `EXPLAIN` from noise into signal).
3. **Specialized index types — GIN/GiST/BRIN** (~1.5h; unlocks search, geo, and time-series work).
4. **Write amplification & LSM-trees** (~2h; senior storage-engine depth).
