# Normalization and Denormalization — Split for Integrity, Merge for Speed

## A. Intuition First
**Normalization** = split data into many small tables so each fact lives in one place. Protects against inconsistency.
**Denormalization** = duplicate data across tables to avoid joins. Trades storage + write-complexity for read speed.

Both are valid. Almost every large system does some of both.

## B. Mental Model
### Anomalies that normalization prevents
- **Insert anomaly**: can't insert new entity without unrelated data.
- **Update anomaly**: same fact in many places → inconsistency after partial update.
- **Delete anomaly**: deleting one row deletes unrelated info.

### Normal forms (just enough)
- **1NF**: atomic values, no repeating groups.
- **2NF**: 1NF + no partial dependency on composite PK.
- **3NF**: 2NF + no transitive dependency (non-key → non-key).
- **BCNF**: stronger 3NF; every determinant is a super key.

3NF is the practical target.

### Denormalization patterns
- **Pre-joined tables / materialized views**: sales report tables.
- **Redundant columns**: store `user_name` in orders table to avoid a join (accept update cost).
- **Wide-column NoSQL data models**: often one table per access pattern, heavily denormalized.

## C. Internal Working
Example (un-normalized):
```
ID | Name  | Role              | Team
1  | Peter | SWE               | A
2  | Brian | DevOps            | B
3  | Hailey| PM                | C
4  | Hailey| PM                | C  ← redundancy
```
Hailey appearing twice leads to update anomalies.

Normalize to 3 tables: `people`, `roles`, `teams`, with FKs. Now each fact lives in one place.

## D. Visual Representation
```
Normalized (3 tables + FKs):        Denormalized (1 table):
 people ── roles                     people_roles_teams
   └── teams                           (flat, redundant)

READ: JOIN                           READ: single table
WRITE: 3 targeted writes            WRITE: update redundant copies
```

## E. Tradeoffs
| | Normalized | Denormalized |
|---|---|---|
| Storage | Low | Higher |
| Writes | Simple, fast | Must update duplicates |
| Reads | Joins cost | Fast, no joins |
| Data integrity | High | Manual enforcement |
| Scale with sharding | Joins across shards painful | Fewer cross-shard ops |

## F. Interview Lens
- "What's 3NF?" — know it.
- "When do you denormalize?" — read-heavy path, joins too costly, sharded DB, or precomputed views.
- "What's a materialized view?"
- Pitfalls: cargo-culting 3NF into a read-heavy system; over-denormalizing a transactional system.

## G. Real-World Mapping
- **Normalized**: transactional cores (banking, payments, inventory).
- **Denormalized**: feeds (Twitter home timeline is a denormalized per-user list), OLAP stars/snowflakes, Cassandra tables per access pattern.

## H. Questions
**Beginner**: What's a primary key? A foreign key? Why normalize?
**Intermediate**: When should you denormalize?
**Advanced**: Design both normalized and denormalized schemas for an e-commerce "product view" page. Compare.

## I. Mini Design
A reporting system reads "top 10 products per region, this week" 10k times per second. Normalized schema needs 3 joins + aggregate. Denormalize into a `top_products_weekly(region, product_id, rank, updated_at)` precomputed table refreshed every 10 min → cheap reads.

## J. Cross-Topic Connections
- [SQL](sql-databases.md), [Sharding](sharding.md), [CQRS](../architecture/cqrs.md), [Indexes](indexes.md).

## K. Confidence Checklist
- [ ] Can recite 1NF, 2NF, 3NF roughly.
- [ ] Can articulate when to denormalize.
- [ ] Knows materialized view is denormalization with a refresh policy.

### Red flags
- ❌ Always normalizing or always denormalizing.

## L. Potential Gaps & Improvements
- **OLTP (Online Transaction Processing)** — workloads with many small reads/writes (orders, payments) that favor normalized schemas for integrity; the default for app databases.
- **OLAP (Online Analytical Processing)** — workloads that scan huge ranges to aggregate (reports, dashboards) and favor denormalized layouts for fast reads.
- **Star / snowflake schema** — OLAP table layouts where one central fact table links to dimension tables; the star is flat, the snowflake further normalizes dimensions, so know which trades reads for storage.
- **CDC (Change Data Capture)** — tools like Debezium stream every row change out of a database so you can rebuild denormalized copies or materialized views without re-querying the source; key for any "keep two stores in sync" question.
- **Materialized view refresh strategy** — how often a precomputed denormalized table is rebuilt (on-demand, scheduled, or incremental); the policy decides how stale your fast reads can get (→ see Interview Lens).

**🔧 How to close:** Spin up Postgres (`docker run -e POSTGRES_PASSWORD=pw -p 5432:5432 postgres`), create a normalized `orders`/`users` pair plus a denormalized `CREATE MATERIALIZED VIEW order_summary AS SELECT o.id, u.name, o.total FROM orders o JOIN users u ON ...`, then run `EXPLAIN ANALYZE` on the join query versus `SELECT * FROM order_summary` and compare the planning/execution times.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🗂️ Gap 1 — OLTP vs OLAP: Two Workloads, Two Schemas
- 🔹 **What it is**: OLTP (Online Transaction Processing) is many tiny reads/writes (place an order, pay a bill); OLAP (Online Analytical Processing) is wide scans that aggregate millions of rows (revenue by region this quarter).
- 🔹 **Why it matters**: The single most common "when do I normalize vs denormalize?" answer is "depends on the workload" — and OLTP/OLAP is the vocabulary that makes that answer sound senior instead of hand-wavy.
- 🔹 **Connection**: This file's Tradeoffs table says normalized wins on writes/integrity and denormalized wins on reads. OLTP *is* the write-heavy world that wants normalization; OLAP *is* the read-heavy world that wants the star/snowflake denormalization from the Gaps list.
- 🔹 **When needed**: 🟢 **Foundational** — almost every data-design interview opens here, and naming the two workloads frames every later answer.
- 🔹 **Intuition**: A bank teller (OLTP) does one precise transaction at a time and must never get a balance wrong. An accountant doing year-end (OLAP) flips through the whole ledger to total it up; they don't care if one entry is a few minutes stale.
- 🔹 **If you go deeper**: Read about column-oriented OLAP stores — Apache Parquet (storage format), ClickHouse, Snowflake, and BigQuery — and contrast their column layout with a row-oriented OLTP store like Postgres.
- 🔹 **Interview hook**: *"Should reporting run on the same database as checkout?"* → No: isolate the OLAP scans onto a denormalized warehouse so heavy aggregations don't starve the latency-sensitive OLTP transactions.

---

#### ⭐ Gap 2 — Star & Snowflake Schemas
- 🔹 **What it is**: A star schema is a central **fact** table (one row per event, e.g. a sale) surrounded by denormalized **dimension** tables (product, customer, date); a snowflake schema re-normalizes those dimensions into sub-tables.
- 🔹 **Why it matters**: It's the canonical answer to "how do you model an analytics/reporting database?" and shows you know denormalization isn't chaos — it has named, disciplined patterns.
- 🔹 **Connection**: This file mentions OLAP "stars/snowflakes" in Real-World Mapping. The star is exactly the "pre-joined tables" denormalization pattern from section B, applied to a whole reporting model.
- 🔹 **When needed**: 🟡 **Mid-level** — expected in data-engineering and analytics-flavored rounds; a backend-only role may only need to recognize the terms.
- 🔹 **Intuition**: A star is a recipe card that repeats "2 cups flour" in full every time so you never flip to a glossary. A snowflake adds a glossary page (normalized dimension) you must look up — less repetition, more flipping (joins).
- 🔹 **If you go deeper**: Read Ralph Kimball's *The Data Warehouse Toolkit* (dimensional modeling) and look at how dbt projects organize fact/dimension models.
- 🔹 **Interview hook**: *"Star or snowflake for a sales dashboard?"* → Star by default — fewer joins means faster reads, which is the whole point of OLAP; snowflake only when a dimension is huge and the storage savings genuinely matter.

---

#### 🔄 Gap 3 — Keeping Denormalized Copies Fresh (CDC + Refresh Strategy)
- 🔹 **What it is**: CDC (Change Data Capture) streams every row change out of the source database; a refresh strategy (on-demand, scheduled, or incremental) decides how and when your denormalized copy or materialized view catches up.
- 🔹 **Why it matters**: Denormalization's hidden cost is staleness and drift — the moment you duplicate data, you own the job of re-syncing it. Interviewers probe this to see if you understand the *price* of fast reads.
- 🔹 **Connection**: The file's Mini Design refreshes `top_products_weekly` "every 10 min" — that single phrase *is* a refresh strategy. CDC is the mechanism that lets you do it incrementally instead of recomputing the whole table.
- 🔹 **When needed**: 🟡 **Mid-level** for the refresh-policy tradeoff; 🔴 **Senior** for building a CDC pipeline (Debezium → Kafka → consumer) that survives failures and replays.
- 🔹 **Intuition**: A printed phone book (your denormalized table) is fast to read but goes stale the instant someone moves. You either reprint it on a schedule (full refresh) or mail out change slips as they happen (CDC + incremental refresh).
- 🔹 **If you go deeper**: Spin up Debezium against Postgres' logical replication, watch an `UPDATE` land on a Kafka topic, and read about Postgres' `REFRESH MATERIALIZED VIEW CONCURRENTLY`.
- 🔹 **Interview hook**: *"Your denormalized read model is 5 minutes behind the source — is that a bug?"* → Only if the product's freshness requirement is tighter than 5 minutes; staleness is a deliberate, tunable tradeoff, not an accident.

---

### 🏆 Start here if you have limited time
1. **OLTP vs OLAP** — it's the framing that turns every normalize-vs-denormalize question into a confident, structured answer.
2. **Keeping denormalized copies fresh** — interviewers love to expose the staleness cost most candidates forget once they say "just denormalize it."

---

### 🧭 Suggested Deep Dive Order
1. **OLTP vs OLAP** (~30 min; the vocabulary that anchors the whole topic).
2. **Star & snowflake schemas** (~45 min; the named patterns for disciplined denormalization).
3. **CDC + refresh strategy** (~1–2h; the operational reality of living with duplicated data).
