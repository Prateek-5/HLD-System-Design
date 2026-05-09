# Query Optimization & Execution Plans

> *"SQL is a declarative lie. You write what you want; the database decides how to do it. The 'how' is where minutes turn into milliseconds, where indexes earn their keep, where a missing statistic becomes a 4-hour outage."*

---

## Topic Overview

A SQL query is a question; an execution plan is the answer to *how* the database is going to compute it. The same query — `SELECT * FROM orders WHERE customer_id = ? AND status = 'paid'` — can take 1ms or 1000ms depending on which indexes the planner uses, what join order it picks, whether it streams or buffers, whether it estimates 10 rows or 10 million.

The query planner is a small compiler that translates declarative SQL into a concrete plan, guided by *statistics* about the data and a cost model that predicts which plan will be cheapest. When the planner is right, life is good. When it's wrong — outdated statistics, a skewed value distribution, an unexpected join — performance can degrade by orders of magnitude with no schema change, no code change, no obvious culprit.

This is the topic where indexes, MVCC, and storage internals come together in the engineer's daily life. Understanding execution plans is the difference between "the query is slow" (helpless) and "the planner picked a hash join when it should have used a merge join because the row estimate was off by 1000×" (actionable).

---

## Intuition Before Definitions

Imagine asking a librarian: "find all books written by authors born in France between 1850 and 1900, that were bestsellers, in the romance genre."

A naive librarian reads every book in the library, checks each criterion, returns matches. With a million books, you're waiting forever.

A clever librarian thinks first:
- "How many French-born authors do I have? Probably 5%. Let me start there."
- "Of those, how many were born 1850-1900? Maybe 20%. So 1% of total."
- "Of those, how many wrote bestsellers? Maybe 10%. Now down to 0.1%."
- "Romance? Filter to a few hundred candidates. Easy."

The clever librarian *plans* the search before searching. They start with the most selective filter (the one that eliminates the most candidates fastest), build up from there. They use whatever indexes (the card catalog by author birthplace, by birth year, by genre) make the filtering cheap.

A query planner does this. It looks at your SELECT, examines the available indexes, estimates how selective each filter is using statistics, and constructs a *plan tree* that minimizes total work. When it estimates well, it's fast. When estimates lie — "I thought there were 100 matches but there are 100,000" — the chosen plan breaks down.

The cleverness — and the failure modes — both live in the planner's estimates.

---

## Historical Evolution

**Era 1 — Heuristic optimizers.**
Early relational databases (System R, Ingres in the 1970s) used rule-based optimization: a fixed sequence of plan transformations. Predictable. Fragile. Could not adapt to data.

**Era 2 — Cost-based optimization.**
System R (IBM, 1979) introduced cost-based optimization with statistics-driven cardinality estimates. The blueprint for every modern planner. Postgres, MySQL, SQL Server, Oracle — all descendants.

**Era 3 — The estimation problem.**
1990s-2000s. The bottleneck became cardinality estimation. Real data has skew, correlations, and oddities that statistics histograms miss. Planners would generate beautiful plans for *estimated* row counts and disasters for *actual* row counts.

**Era 4 — Adaptive query execution.**
Modern systems (Postgres `pg_hint_plan`, Spark adaptive execution, SQL Server's "Adaptive Query Processing") allow plans to *change at runtime* based on observed cardinalities. The plan is no longer fixed at compile time.

**Era 5 — Learned optimizers.**
Research and experimental implementations (DeepMind, Microsoft) using ML to predict plan costs. Promising; not yet mainstream. The fundamental problem of estimation in the presence of correlations is an active research area.

**Era 6 — Columnar and vectorized execution.**
Modern OLAP systems (ClickHouse, DuckDB, Snowflake) push beyond row-at-a-time. Vectorized execution processes batches; the optimizer plans for batch-friendly operations (hash joins over nested loops). A different cost model entirely.

The pattern: each generation pushed the optimizer to do more — more transformations, more accurate estimates, more runtime adaptation. The fundamental theory is half a century old; the engineering is constantly evolving.

---

## Core Mental Models

**1. The plan is a tree of physical operators.**
Each node is a specific algorithm: index scan, hash join, sort, filter, aggregate. Data flows up the tree. The plan is the *execution strategy*, not the SQL.

**2. The planner's job is to estimate cost.**
Cost = expected I/O + CPU + memory. Plans with lower estimated cost win. The estimates are only as good as the statistics.

**3. Statistics are the planner's lens on reality.**
Histograms, distinct counts, correlation coefficients. Without statistics — or with stale ones — the planner is guessing.

**4. The right operator depends on the data shape.**
Tiny join → nested loop. Medium join with sorted inputs → merge join. Large unsorted join → hash join. Index-friendly filter → index scan. Bulk filter → sequential scan. The plan reflects the data, or it should.

**5. Plan stability is desirable; plan choice is not always optimal.**
A "good enough" plan that runs reliably beats an "optimal" plan that occasionally turns into a disaster. Production tuning often means *constraining* the planner more than freeing it.

---

## Deep Technical Explanation

### Reading an execution plan

In Postgres, `EXPLAIN ANALYZE`:

```
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 42 AND status = 'paid';

Index Scan using idx_orders_customer_id on orders
  (cost=0.43..15.83 rows=12 width=88)
  (actual time=0.012..0.045 rows=11 loops=1)
  Index Cond: (customer_id = 42)
  Filter: (status = 'paid')
  Rows Removed by Filter: 3
Planning Time: 0.123 ms
Execution Time: 0.067 ms
```

Reading this:
- **Index Scan**: the chosen physical operator.
- **idx_orders_customer_id**: the index being used.
- **cost=0.43..15.83**: estimated startup cost..total cost. Arbitrary units; relative within a plan.
- **rows=12**: estimated row count.
- **actual time / rows / loops**: real measurements from running the query.
- **Index Cond**: filter pushed into the index.
- **Filter / Rows Removed**: post-index filter; bad if removing many rows.

The estimate-vs-actual comparison is critical. `rows=12 ... actual rows=11` is great. `rows=12 ... actual rows=120000` is a problem; the planner thought this was a tiny operation and chose accordingly.

### The physical operators

**Sequential Scan (Seq Scan)**: read every row of a table. O(N). Best for: small tables, large fraction of rows matching, no useful index.

**Index Scan**: navigate B-tree (or other index) to find matching rows; fetch from heap. Best for: high selectivity, small result sets.

**Index-Only Scan**: like Index Scan, but doesn't fetch the heap — all needed columns are in the index. Best for: covering indexes.

**Bitmap Index Scan + Heap Scan**: scan multiple indexes, build bitmap of matching pages, then read pages once. Best for: medium selectivity with multiple conditions.

**Nested Loop Join**: for each row of outer relation, scan/lookup matching rows in inner. Best for: small outer relation, indexed inner.

**Hash Join**: build hash table of one input, probe with the other. Best for: medium-to-large unsorted inputs, large memory.

**Merge Join**: requires both inputs sorted; walks them together. Best for: pre-sorted inputs (e.g., index-ordered data).

**Sort**: explicit sort, often before merge join or for ORDER BY. O(N log N). Memory-intensive; spills to disk if too big.

**Aggregate / HashAggregate**: GROUP BY computation. HashAggregate uses a hash table; faster but memory-bound.

**Materialize**: buffer rows from a child node so they can be re-read. Used in certain join scenarios.

Each operator has a cost model: estimated I/O + CPU + memory. The planner enumerates plan candidates and picks the cheapest.

### Cardinality estimation

The most important — and most fragile — part of optimization.

For a single-column predicate (`WHERE x = 42`):
- Use the column's histogram to estimate matching rows.
- Histograms are built by sampling and stored as statistics.

For multi-column predicates (`WHERE x = 42 AND y = 'foo'`):
- Default assumption: *independence*. P(x=42 AND y=foo) = P(x=42) × P(y=foo).
- *Disastrous when columns are correlated*. If x and y are perfectly correlated, the actual count can be 100× the estimate.

For joins:
- Estimate matched row count from per-column distributions and join condition.
- Heavy reliance on independence assumptions; can be wildly wrong on real data.

This is *the* problem. Real-world data has correlations the planner doesn't see. A 10× cardinality misestimate at one node propagates exponentially up the plan tree.

### Statistics

Postgres maintains per-column statistics:
- **n_distinct**: estimated distinct value count.
- **most_common_vals (MCV)**: top-K most frequent values.
- **histogram_bounds**: equi-depth histogram for the rest.
- **correlation**: physical-to-logical ordering correlation.

Updated by `ANALYZE` — manually or via autovacuum. Stale statistics are a leading cause of plan disasters. After a bulk load, *always* run ANALYZE.

Multi-column statistics (Postgres 10+) capture correlations between columns. Optional; must be created manually with `CREATE STATISTICS`. Underused in practice.

### When the planner gets it wrong

Common failure patterns:

**Stale statistics.**
A 1M-row table has stale statistics from when it had 10 rows. The planner thinks it's tiny, chooses nested loop, performs 1M index lookups. Disaster. Fix: ANALYZE.

**Correlated columns.**
`WHERE country = 'US' AND state = 'CA'`. Country and state are correlated. The planner multiplies independent estimates. Reality is much higher. Fix: extended statistics.

**Skew.**
99% of rows have status='completed'. A query for `WHERE status = 'pending'` should return 1%. The planner uses average selectivity. If 'pending' is rare, plan picks index scan. If 'pending' is the popular value (skewed), plan should pick seq scan. Fix: histograms with MCV catch this — *if* statistics are current.

**Subquery flattening missed.**
Some subqueries can be rewritten as joins; missing the rewrite costs orders of magnitude. Postgres handles many cases; some still trip it up.

**Bad parameter snapshots.**
A prepared statement plan was chosen for a typical parameter value. Now used with an atypical value. Plan is wrong for this execution. Postgres calls this "custom plan vs generic plan" and has heuristics; sometimes they fail.

**Missing indexes.**
Obvious: no index on the filter column. Planner must scan. Fix: add the index.

**Too-clever queries.**
Functions on columns (`WHERE upper(email) = ...`) defeat indexes unless functional indexes exist. Implicit type casts likewise.

### The N+1 antipattern

Not a planner problem per se — an application problem revealed by plans:

```python
orders = db.query("SELECT * FROM orders WHERE customer_id = ?", customer_id)
for order in orders:
    items = db.query("SELECT * FROM items WHERE order_id = ?", order.id)
```

Planner sees N+1 separate queries. Each is fine individually. Total is catastrophic. Fix: a join or a batch query (`WHERE order_id IN (...)`) — single round trip, single plan.

ORMs are particularly susceptible. Inspect the queries actually executed; ORM laziness can hide an N+1 in a single line of code.

### Hints and plan stability

Some databases support optimizer hints:
- Oracle: `/*+ USE_INDEX */`, etc.
- SQL Server: `WITH (INDEX(...))`.
- MySQL: `USE INDEX`, `FORCE INDEX`.
- Postgres: no native hints; `pg_hint_plan` extension.

Hints override the planner's choice. Useful when you *know* the planner is wrong; dangerous when you don't. A hint that's correct today may be wrong tomorrow as data changes.

Plan stability features (SQL Server's "plan guides," Oracle's "SQL plan baselines") freeze chosen plans for specific queries. Used in environments that prioritize predictability over optimal performance.

### Adaptive execution

Modern databases sometimes change plans mid-query:
- **Spark adaptive execution**: re-plans after each stage based on observed sizes.
- **SQL Server adaptive joins**: switches between hash join and nested loop based on actual row count.
- **Postgres**: limited adaptive features; plan is mostly fixed at planning.

For OLTP workloads, plan stability matters more than adaptation. For OLAP, adaptation prevents catastrophic plan choices on unfamiliar data.

### Vectorized vs row-at-a-time

Traditional databases process rows one at a time through the operator tree. Each row goes through every operator. Cache-unfriendly; CPU-inefficient.

Vectorized execution (ClickHouse, DuckDB, Snowflake) processes *batches* (typically 1024 rows). Better cache behavior; SIMD opportunities; orders-of-magnitude speedups for analytics. The optimizer must plan for batch-friendly operators.

This is mostly an OLAP innovation; OLTP databases process individual queries that benefit less.

---

## Real Engineering Analogies

**The freight forwarder.**
Shipping a container from Shanghai to Cleveland involves: ocean freight, port handling, customs, rail or truck, last-mile delivery. A naive shipper books each leg individually. A freight forwarder *plans* the route — choosing modes, stops, transfers — to minimize cost and time, given current conditions (port congestion, fuel prices, customs delays).

The plan changes when conditions change. A storm reroutes ships; congestion reroutes through different ports. Good freight forwarders monitor conditions and adapt.

That's a query planner. Conditions are statistics. Cost is the metric to minimize. The plan is the chosen route.

**The chess engine.**
A chess engine evaluates millions of move sequences and picks the best one. Each candidate is scored by an evaluation function. Pruning eliminates obviously-bad branches; depth bounds limit search. The engine sees moves the human doesn't because it can systematically explore.

A query planner explores plan space similarly: enumerate, score, prune, return the best. The "evaluation function" is the cost model. The "search depth" is bounded by complexity (10-table joins have factorial join orders; planners use heuristics to prune).

---

## Production Engineering Perspective

What goes wrong:

- **The plan flip after a deploy.** New release ships; queries that were fast are now slow. Investigation: a schema change subtly altered statistics; planner chose a different plan; the new plan is worse for production data shape.
- **The forgotten ANALYZE.** Bulk-load a table; statistics are still empty/stale. Subsequent queries get wildly bad plans. The "first query after migration" disaster.
- **The correlated columns trap.** `WHERE region = 'us-east' AND service = 'web'` — both heavily correlated in real data. Planner's independence assumption produces 100× misestimate. Plans cascade.
- **The parameter-sniffing problem.** Prepared statement first executed with an unusual parameter; that plan is cached. Subsequent calls with usual parameters get the bad plan.
- **The ORM laziness disaster.** A loop iterates orders, each access triggers a query. 1000 orders = 1001 queries. Page load times balloon. Fix: eager loading, joins, batched fetches.
- **The missing index discovery.** EXPLAIN reveals seq scan on a 100M-row table. Add index; query goes from 30s to 30ms.
- **The over-indexing surprise.** 12 indexes on a heavy-write table. INSERTs slow because every index updates. Audit shows 5 unused. Drop them; INSERTs accelerate.
- **The seq scan that was correct.** Junior engineer adds an index "to fix the seq scan." Index makes things slower because the table is small or selectivity is poor. Sometimes the planner is right and the seq scan is optimal.

The senior DBA's habits:
- **Read EXPLAIN ANALYZE** for slow queries.
- **Compare estimated vs actual rows** at each plan node.
- **Run ANALYZE** after bulk operations.
- **Audit unused indexes** periodically.
- **Watch query plan changes** in production.
- **Use extended statistics** for known correlations.
- **Consider plan stability features** for predictability-critical queries.

---

## Failure Scenarios

**Scenario 1 — The catastrophic plan flip.**
A query that ran in 50ms suddenly takes 5 minutes. No code change. Investigation: statistics on a key column drifted; planner now estimates 10 rows instead of 100K. Chose nested loop join. Each "fast" iteration is a full table scan. Recovery: ANALYZE; plan returns to normal.

**Scenario 2 — The N+1 in production.**
A page that previously loaded in 200ms now takes 8s. Nothing in the code changed, but a related table grew 100×. Investigation: the page issued 1 + N queries; N was 50; now it's 5000. Each query is fast but the round-trip latency dominates. Fix: refactor to eager-load with joins.

**Scenario 3 — The parameter-sniffing surprise.**
A reporting query uses prepared statements. First call after deploy runs with `customer_id = ?` for a new customer (no rows). Plan chosen: nested loop, expecting 0 rows. Cached. Subsequent calls for old customers (millions of rows) reuse the plan. Disaster. Fix: re-prepare; consider Postgres's custom-plan threshold.

**Scenario 4 — The forgotten autovacuum.**
A high-write table with autovacuum disabled. Statistics drift; bloat grows; plans degrade. Discovery only after weeks of slowly-degrading performance. Fix: re-enable autovacuum; manual VACUUM ANALYZE to recover.

**Scenario 5 — The "I'll just add a hint" mistake.**
Engineer adds `/*+ USE_INDEX(idx_status) */` to fix a slow query. It works. Six months later, data distribution shifts; the index is now wrong. Hint forces it anyway. Bug surfaces in production. Lesson: hints are last resorts, not first.

---

## Performance Perspective

- **Plan time matters for OLTP**, where queries are short. Postgres's plan time of 1-5ms is a real cost for sub-ms queries.
- **Prepared statements** amortize plan time across executions.
- **Estimate accuracy** dominates execution time for complex queries.
- **Statistics freshness** is a continuous cost (autovacuum I/O).
- **Memory limits** drive operator choice. `work_mem` setting bounds hash and sort sizes; insufficient triggers spilling to disk.

---

## Scaling Perspective

- **Vertical**: more memory enables hash joins over nested loops; more CPU enables parallel query.
- **Parallel query**: modern databases parallelize scans, sorts, and aggregates. Postgres parallel workers, Spark partitions, MPP databases.
- **Distributed planners**: distributed databases (CockroachDB, Spanner, ClickHouse) plan across shards. Data locality matters; cross-shard joins are expensive.
- **Query routing**: separate read replicas, OLAP replicas. Plan once per replica.
- **At hyperscale**: query planning itself becomes a system — caching plans, distributing planning work, learning from past executions.

---

## Cross-Domain Connections

- **Indexing**: the planner's most powerful lever. Wrong index = wrong plan. (See [indexing-and-storage-engines.md](./indexing-and-storage-engines.md).)
- **MVCC**: plans must consider visibility checks; bloated tables (high dead-tuple ratio) inflate estimated costs. (See [mvcc-and-isolation-levels.md](./mvcc-and-isolation-levels.md).)
- **Sharding**: distributed planners must consider data locality; cross-shard plans are expensive. (See [sharding-and-partitioning-strategies.md](../scalability/sharding-and-partitioning-strategies.md).)
- **Caching**: prepared statement caches are plan caches; same invalidation problems. (See [caching-hierarchy.md](../caching/caching-hierarchy.md).)
- **Observability**: query metrics (slow queries, plan changes, statistic freshness) are first-class signals. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)
- **WAL**: dirty buffers from heavy writes affect cost models — pages in dirty state may have different I/O profiles. (See [wal-and-crash-recovery.md](./wal-and-crash-recovery.md).)

The unifying observation: **the query planner is a small compiler whose output is execution behavior. Its quality determines whether the same SQL runs in milliseconds or minutes — and its inputs (statistics, indexes, data shape) are operational concerns that change over time.**

---

## Real Production Scenarios

- **Postgres's planner evolution**: ongoing improvements to multi-column statistics, partition-aware planning, parallel query. Public mailing lists track every change.
- **MySQL's optimizer hints culture**: heavier reliance on hints than Postgres; community practice diverges.
- **Spark's adaptive query execution**: solved persistent shuffle-skew problems with runtime re-planning. Documented case studies.
- **Snowflake's micro-partition pruning**: planner's first job is eliminating partitions before any execution. Critical for petabyte-scale OLAP.
- **CockroachDB's distributed planner**: documented design for distributed plans with locality-awareness.
- **The "EXPLAIN-driven culture" at high-quality engineering shops**: code review includes EXPLAIN output for new queries.

---

## What Junior Engineers Usually Miss

- That **EXPLAIN ANALYZE is the diagnostic**, not just EXPLAIN.
- That **estimate vs actual rows** is the key signal.
- That **stale statistics cause plan disasters**.
- That **N+1 patterns are about the application, not the planner**.
- That **functions on columns defeat indexes**.
- That **prepared statements have parameter-sniffing risks**.
- That **the planner is sometimes right** when it picks seq scan.
- That **hints are dangerous** as a default tool.

---

## What Senior Engineers Instinctively Notice

- They **read execution plans fluently**.
- They **compare estimate to actual** at every node.
- They **verify ANALYZE has run** after bulk operations.
- They **detect N+1 patterns** in code review.
- They **audit unused indexes**.
- They **use extended statistics** for known correlations.
- They **prefer schema changes to hints**.
- They **monitor plan changes** as a production signal.

---

## Interview Perspective

What gets tested:

1. **"Walk through this EXPLAIN output."** Tests fluency. Junior reads it; senior interprets it.
2. **"Why might this query be slow?"** Tests systematic thinking: stats, indexes, plan choice, N+1, etc.
3. **"What's the difference between nested loop and hash join?"** Tests algorithm awareness.
4. **"How does the planner estimate cost?"** Statistics + cost model + cardinality estimation.
5. **"What's parameter sniffing?"** Plan cached for first parameter; bad fit for later ones.
6. **"How would you fix an N+1?"** Joins, batching, or eager loading.
7. **"When wouldn't you add an index?"** Small tables; very high write rate; unused queries.

Common traps:
- Ignoring the difference between estimate and actual.
- Adding indexes without measuring.
- Using hints reflexively.
- Believing planner is always right or always wrong.

---

## 20% Knowledge Giving 80% Understanding

1. **EXPLAIN ANALYZE** for slow queries. Read estimate vs actual.
2. **Stats drive plans.** ANALYZE after bulk ops.
3. **The plan tree is operators**: scans, joins, sorts, aggregates.
4. **Cardinality estimation** is the critical fragility.
5. **N+1 is an app problem**, not a planner problem.
6. **Functions on columns defeat indexes** unless functional indexes exist.
7. **Parameter sniffing** can lock in a bad plan.
8. **Extended statistics** for correlated columns.
9. **Hints last; schema changes first.**
10. **Plan stability** sometimes beats plan optimality.

---

## Final Mental Model

> **A SQL query is a goal; the execution plan is the strategy. Between them sits a small compiler making decisions you didn't write — driven by statistics that may be stale, cost models that may misestimate, and a search space too large to fully explore. Most query performance problems are statistics problems wearing a costume.**

The senior database engineer treats execution plans as the primary artifact when something is slow. Read the plan; compare estimates to actuals; identify the misjudgment. Fix the cause (stats, indexes, schema), not the symptom (hints). Build a habit of EXPLAIN-driven development for new queries.

The systems that scale gracefully are the ones where engineers know what their queries are doing under the hood. The systems that mysteriously slow down over time are the ones where nobody reads plans until customers complain.

That's query optimization. That's execution plans. That's the bridge between "what I asked for" and "what actually ran." It's the most useful skill no one teaches you in undergraduate databases — and the one that separates engineers who tune SQL from engineers who guess.
