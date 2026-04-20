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
- OLTP vs OLAP schema styles (star/snowflake) deserve a pass.
- CDC as a denormalization feeder.
