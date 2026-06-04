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
- **LSM-tree (Log-Structured Merge-tree) vs B-tree** — two on-disk storage engines; LSM batches writes in memory then flushes sorted files (fast writes, used by Cassandra/RocksDB) while B-trees update in place (fast reads, used by most SQL DBs). Knowing the trade-off explains why a given NoSQL store is write- or read-optimized.
- **DynamoDB partition key + sort key design** — the partition key decides which physical shard a row lands on and the sort key orders rows within it; getting this wrong creates "hot partitions" and is the make-or-break of any DynamoDB schema question.
- **Graph DB query languages** — declarative languages like Cypher (Neo4j) or Gremlin that traverse relationships ("friends of friends") in a single query; worth hands-on practice because relational JOINs get painful for deep graph traversals.

**🔧 How to close:** Run a local NoSQL store and watch the engine behave — start one with `docker run -d -p 27017:27017 mongo`, then in `mongosh` insert 1000 docs in a loop and run `db.coll.find({...}).explain("executionStats")` to see whether a query hits an index or scans the collection; add an index with `db.coll.createIndex({field:1})` and re-run to watch the scanned-doc count drop.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🗃️ Gap 1 — LSM-tree vs B-tree Storage Engines
- 🔹 **What it is**: Two ways a database physically stores data on disk — LSM-trees (Log-Structured Merge-trees) batch writes in memory then flush sorted immutable files, while B-trees update pages in place.
- 🔹 **Why it matters**: It's the single fact that explains *why* a store is write-optimized or read-optimized — and interviewers love "why does Cassandra write so fast?"
- 🔹 **Connection**: Section C already said wide-column stores are "written sequentially (LSM-tree)" with "read amplification higher than B-tree systems" — this gap unpacks that one line.
- 🔹 **When needed**: 🟡 **Mid-level** — expected once you discuss DB internals; the basics are very reachable now.
- 🔹 **Intuition**: A B-tree is editing a single ledger book by erasing and rewriting lines in place; an LSM-tree is jotting every change on fresh sticky notes and periodically merging them into a clean sorted stack.
- 🔹 **If you go deeper**: Read the original 1996 O'Neil "Log-Structured Merge-Tree" paper, then explore RocksDB (the LSM engine inside Cassandra-alternatives, CockroachDB, Kafka Streams) and its compaction strategies (leveled vs size-tiered).
- 🔹 **Interview hook**: *"Why does Cassandra write faster than a SQL database?"* → writes are sequential appends to a memtable + commit log (no in-place page updates or random disk seeks), flushed later as sorted SSTables.

---

#### 🔑 Gap 2 — DynamoDB Partition Key + Sort Key Design
- 🔹 **What it is**: In a key-value/wide store, the partition key decides which physical shard a row lives on and the sort key orders rows within that shard — together they define every access pattern.
- 🔹 **Why it matters**: A bad key choice creates "hot partitions" (one shard overloaded while others idle), which is the make-or-break of nearly every DynamoDB/Cassandra schema question.
- 🔹 **Connection**: Section C noted KV stores are "limited query (often only by key)" and DynamoDB "adds GSIs"; Section I's Instagram-feed table keyed by `(user_id, timestamp DESC)` is exactly a partition+sort key design.
- 🔹 **When needed**: 🟡 **Mid-level** — central to data-modeling rounds; 🔴 **Senior** when reasoning about hot-partition mitigation at scale.
- 🔹 **Intuition**: A library where the partition key is the floor you walk to and the sort key is the shelf order. Pick a floor everyone visits at once (e.g. partition by `date`) and that floor jams while the rest sit empty.
- 🔹 **If you go deeper**: Read AWS's "single-table design" guidance and Rick Houlihan's re:Invent DynamoDB deep-dive talks; practice write-sharding a hot key (append a random suffix `0..N`).
- 🔹 **Interview hook**: *"How do you avoid hot partitions in DynamoDB?"* → choose a high-cardinality partition key spread evenly across access; write-shard unavoidable hot keys; never partition on a low-cardinality or monotonic value like a single date.

---

#### 🕸️ Gap 3 — Graph Query Languages (Cypher / Gremlin)
- 🔹 **What it is**: Declarative languages that traverse relationships ("friends of friends of friends") in one query — Cypher (Neo4j) and Gremlin (Apache TinkerPop / Neptune / JanusGraph).
- 🔹 **Why it matters**: Deep traversals that need many self-JOINs in SQL become a single short pattern in a graph language; knowing this justifies *when* a graph DB earns its keep.
- 🔹 **Connection**: Section C said graph traversals "are cheap for deep joins" and Section D shows `(User:1) -[FOLLOWS]-> (User:2)` — this gap is the query side of that data shape.
- 🔹 **When needed**: 🟢 **Foundational** — a few hours of hands-on Cypher is very reachable and clarifies when graphs beat relational JOINs.
- 🔹 **Intuition**: Asking "who can introduce me to this person?" — in SQL you'd photocopy and cross-reference the org chart repeatedly; in Cypher you just point and say "walk the KNOWS edges up to 3 hops."
- 🔹 **If you go deeper**: Do the free Neo4j Sandbox / GraphAcademy Cypher tutorial; model a small social graph and write a `MATCH (a)-[:FOLLOWS*1..3]->(b)` traversal, then express the same query in SQL to feel the difference.
- 🔹 **Interview hook**: *"When would you use Neo4j over Postgres?"* → when queries are dominated by multi-hop relationship traversals (social graphs, fraud rings, recommendations) that would otherwise need exploding recursive/self-JOINs.

---

#### 🧩 Gap 4 — Denormalization & Query-First Data Modeling
- 🔹 **What it is**: Designing tables/collections around the exact read queries you'll run — duplicating data across them — instead of normalizing into JOIN-able tables.
- 🔹 **Why it matters**: Because most NoSQL stores can't JOIN across nodes, the data model *is* the performance story; getting modeling right matters more than picking the product.
- 🔹 **Connection**: Section E's "shape the data model to the query, not the other way around" and the Section F pitfall ("picking MongoDB for relationships-heavy data") are both this skill in action.
- 🔹 **When needed**: 🟢 **Foundational** — every NoSQL design answer rests on this; learn it early.
- 🔹 **Intuition**: A fast-food menu lists pre-assembled combos (duplicated burger + fries + drink) so the cashier never has to walk to three counters — duplication trades storage for one-trip reads.
- 🔹 **If you go deeper**: Study MongoDB's embedding-vs-referencing guidance and the "one table per query" pattern in Cassandra data modeling; accept that the same datum lives in several places and reason about how you'll keep copies in sync on update.
- 🔹 **Interview hook**: *"How do you handle a many-to-many relationship without JOINs?"* → model per access pattern (e.g. separate `posts_by_user` and `users_by_post` tables), duplicate the data, and update all copies on write.

---

### 🏆 Start here if you have limited time
1. **Denormalization & query-first modeling** — it underpins every NoSQL design answer and is reachable now.
2. **LSM-tree vs B-tree** — one concept that answers the most common "why is this DB fast?" interview question.

---

### 🧭 Suggested Deep Dive Order
1. **Denormalization & query-first modeling** (~1h; foundational, applies to every store here).
2. **LSM-tree vs B-tree** (~45 min; explains the write/read tradeoff across all five shapes).
3. **DynamoDB partition + sort key design** (~1h; highest-frequency schema-design round).
4. **Graph query languages** (~2h hands-on; clarifies exactly when a graph DB wins).
