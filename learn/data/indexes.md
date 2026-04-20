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
- BRIN, GIN, GiST details.
- Index-only scans, bitmap scans.
- Partial / filtered indexes.
