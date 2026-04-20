# SQL vs NoSQL — How to Actually Decide

## A. Intuition First
Stop framing "SQL vs NoSQL" as a war. Ask: *what shape is my data, what are my access patterns, what consistency do I need, what scale do I expect?*

## B. Mental Model — The decision checklist
| If you need… | Lean toward |
|---|---|
| Complex joins, strict schema, transactions | **SQL** |
| Flexible/evolving schema, document nesting | **Document NoSQL** (Mongo) |
| Fast key lookup, cache, sessions | **Key-Value** (Redis, DynamoDB) |
| Write-heavy time-series at scale | **Wide-column** (Cassandra) |
| Graph traversal (friends-of-friends) | **Graph** (Neo4j) |
| Metrics / time-series | **TSDB** (Influx, Timescale) |
| ACID across multiple entities | **SQL** (still the default) |

## C. Internal Working — Why they differ
SQL uses a B-tree row-store and pessimistic schema; joins via the optimizer; ACID via 2PL or MVCC.

NoSQL varies:
- Document: BSON storage, per-doc indexes.
- KV: hash or LSM, nothing else.
- Wide-column: LSM, append-heavy.
- Graph: adjacency lists / index-free adjacency.

## D. Visual Representation
```
Workload:          Complex joins       High write rate    Key lookups     Graph
                        ↓                    ↓                 ↓             ↓
Pick:                  SQL               Wide-col / Doc      KV           Graph
```

## E. Tradeoffs — side-by-side
| Axis | SQL | NoSQL |
|---|---|---|
| Schema | Strict | Flexible |
| Scale pattern | Vertical, then read replicas, then shard | Horizontal by design |
| Consistency | ACID | BASE (varies; Dynamo/Mongo support ACID options) |
| Joins | First-class | Denormalized / app-side |
| Query language | Universal SQL | Per-DB DSL |
| Tooling maturity | Deepest | Newer but broad |

## F. Interview Lens
- Expect: "design X. Pick a DB. Justify."
- The right answer is almost always a **combination**:
  - Postgres for orders/users (transactional core),
  - Cassandra/DynamoDB for time-series events,
  - Redis for cache/sessions,
  - Elasticsearch for search,
  - S3 for blobs.

Pitfalls:
- Dogma ("we use Mongo for everything").
- Picking before knowing access patterns.
- Ignoring the operational cost of polyglot persistence.

## G. Real-World Mapping
- **Instagram**: Postgres for accounts + Cassandra for feed + Redis for cache.
- **Uber**: MySQL/Postgres for financial core + Cassandra for rider/driver tracking.
- **Netflix**: Cassandra everywhere, with MySQL for billing.
- **Stack Overflow**: Postgres, famously, even at scale — with heavy caching.

## H. Questions
**Beginner**: Three reasons to pick SQL. Three reasons NoSQL.
**Intermediate**: Design the DB layer for a hotel booking site. Which DBs? Why each?
**Advanced**: Migrate a large SQL table to Cassandra. What breaks? What do you rewrite?

## I. Mini Design — "Pick DBs for an e-commerce site"
- **Orders, inventory, payments**: Postgres (ACID).
- **Product catalog**: Postgres OR Mongo (depends on variant complexity).
- **Sessions, cart cache**: Redis.
- **Click events, recommendations input**: Kafka → Cassandra / S3.
- **Search**: Elasticsearch.
- **Images**: S3 + CDN.

## J. Cross-Topic Connections
- [SQL](sql-databases.md), [NoSQL](nosql-databases.md), [CAP](cap-theorem.md), [ACID/BASE](acid-base.md).

## K. Confidence Checklist
- [ ] Can pick a DB for each tier of a real architecture.
- [ ] Knows polyglot persistence is normal.

### Red flags
- ❌ "Use X for everything."

## L. Potential Gaps & Improvements
- Cost-per-ops comparison (RDS vs DynamoDB pricing at scale).
- Migration strategies SQL↔NoSQL (dual-write, CDC).
