# NoSQL Databases — Non-Relational, Different Tradeoffs

## A. Intuition First
"NoSQL" = any DB that doesn't use SQL as the primary interface. It's a blanket term for databases optimized for **horizontal scale**, **flexible schema**, or **specialized workloads** (time-series, graph, key-value), typically trading ACID for speed and scale.

**Why they exist**: web-scale workloads hit the limits of vertical-scale SQL. You need data stores that scale horizontally *by design*.

## B. Mental Model — The five shapes
| Type | Shape | Example | When |
|---|---|---|---|
| **Document** | JSON-like docs in collections | MongoDB, CouchDB, DocumentDB | Flexible entities (user profiles, content) |
| **Key-Value** | `k → v`, nothing else | Redis, Memcached, DynamoDB | Sessions, caches, simple lookups |
| **Wide-column** | Row key + sparse columns in families | Cassandra, HBase, BigTable, ScyllaDB | Massive write-heavy time-series / analytics |
| **Graph** | Nodes + edges | Neo4j, Neptune, JanusGraph | Traversal-heavy (social, fraud, recommendations) |
| **Time-series** | Time-indexed metrics | InfluxDB, TimescaleDB, Druid | Metrics, IoT, observability |

## C. Internal Working

### Document stores
- BSON/JSON documents; nested structure natural.
- Secondary indexes per field.
- Queries: filter, project, aggregate pipelines.
- Typical: MongoDB with replica sets + sharded clusters.

### Key-value stores
- Hash-based lookup; O(1) get/put.
- Limited query (often only by key). DynamoDB adds GSIs (secondary indexes) for other access patterns.
- Redis adds data structures (hash, list, sorted set) making it more than KV.

### Wide-column
- Row key + column families; sparse (missing columns cost nothing).
- Written sequentially (LSM-tree); great for write-heavy.
- Read amplification higher than B-tree systems.
- Cassandra: masterless, gossip-based, tunable consistency per query.

### Graph
- First-class relationships as edges.
- Traversal queries (Cypher, Gremlin) are cheap for deep joins ("friends of friends of friends").

### Time-series
- Optimized for append-only, time-bucketed queries (rollups, downsampling).
- Compression is huge (delta-of-delta encoding on timestamps, Gorilla compression on values).

## D. Visual Representation
```
Document:  { "_id":1, "name":"Peter", "tags":["a","b"] }
K-V:       "user:1" → "Peter"
Wide-col:  row key "user:1" | name:Peter | age:30 | email:x@y
Graph:     (User:1) -[FOLLOWS]-> (User:2) -[POSTED]-> (Photo:9)
```

## E. Tradeoffs
- **Flexible schema**: helpful early, risky at scale (inconsistent shapes, bad queries).
- **Horizontal scale** by default: great, but joins across nodes are expensive or not supported.
- **Tunable consistency**: Cassandra lets you pick per-query (e.g., QUORUM write, QUORUM read).
- **No complex joins**: shape the data model to the query, not the other way around.

## F. Interview Lens
- "When would you pick NoSQL over SQL?" → need flexible schema, horizontal scale, or one of the specialized shapes.
- "Why Cassandra for a time-series-like write-heavy workload?" → LSM, linear write scale, tunable consistency.
- "Why Redis for session storage?" → RAM-fast, TTL support, simple KV.
- Pitfalls: picking MongoDB for "relationships heavy" data; picking Cassandra for ad-hoc analytics.

## G. Real-World Mapping
- MongoDB: Stack Overflow-like content, B2B SaaS.
- Cassandra: Netflix time-series, Apple messaging.
- Redis: sessions, rate limits, feed caches, leaderboards (sorted sets).
- DynamoDB: Amazon's everything-store.
- Neo4j: LinkedIn-like traversal, fraud rings.

## H. Questions
**Beginner**: What are the 5 types of NoSQL?
**Intermediate**: Why does Cassandra write so fast? Why does Mongo not support joins across collections easily?
**Advanced**: Design a data model for Netflix's watch-history in Cassandra (partition key, clustering key, compaction strategy).

## I. Mini Design
"Instagram feed in Cassandra": table keyed by `(user_id, timestamp DESC)`. Inserts cheap (append). Reads: scan for last N rows of a user. Scales to billions of rows linearly.

## J. Cross-Topic Connections
- [ACID/BASE](acid-base.md), [Sharding](sharding.md), [Consistent Hashing](consistent-hashing.md), [CAP](cap-theorem.md), [Replication](database-replication.md).

## K. Confidence Checklist
- [ ] Can pick the right NoSQL shape for a given problem.
- [ ] Knows that "flexible schema" has governance costs.
- [ ] Can discuss Cassandra's tunable consistency.

### Red flags
- ❌ Treating "NoSQL" as one thing.
- ❌ Picking MongoDB for heavily relational data.

## L. Potential Gaps & Improvements
- LSM-tree vs B-tree is a critical deep-dive I only touched.
- DynamoDB partition + sort key design is its own topic.
- Graph DB query languages deserve hands-on.
