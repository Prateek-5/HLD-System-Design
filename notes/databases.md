# Databases — SQL, NoSQL, Replication, Sharding

> **📎 Prereqs** — If rusty:
> - [`learn/data/db-and-dbms.md`](../learn/data/db-and-dbms.md) — what a DBMS is.
> - [`learn/data/acid-base.md`](../learn/data/acid-base.md) — ACID/BASE basics.
> - [`learn/data/cap-theorem.md`](../learn/data/cap-theorem.md) — C/A tradeoff.
> - Basic SQL + SELECT/JOIN.

### 🔹 1. What This Topic Actually Is
Durable, queryable stores for structured (SQL) or flexible (NoSQL) data. The default answer to "where does it go?" in every system design.

### 🔹 2. Why It Exists
- Build from raw files, you re-implement concurrency, crash recovery, indexing, schema, query planning. Nobody has time.
- SQL exists for strict-schema + ACID. NoSQL exists for horizontal scale + flexible shapes.

### 🔹 3. Core Concepts (High Signal)
- **SQL (Postgres, MySQL)**: schema-on-write, ACID, strong joins, B-tree indexes, MVCC, vertical-scale-first.
- **NoSQL families**:
  - *Document* (Mongo) — JSON-ish, per-field indexes.
  - *Key-value* (Redis, DynamoDB) — O(1) lookup, minimal query.
  - *Wide-column* (Cassandra, BigTable) — row key + sparse columns, LSM, write-heavy.
  - *Graph* (Neo4j) — traversal-native.
  - *Time-series* (Influx, Druid, Gorilla) — compressed time-indexed metrics.
- **ACID**: Atomic, Consistent, Isolated, Durable. **BASE**: Basically-Available, Soft-state, Eventual.
- **Isolation levels**: Read Uncommitted < Read Committed < Repeatable Read < Serializable. Pick lowest that's correct.
- **Indexes**: B-tree for range/equality, hash for equality, LSM for write-heavy, inverted for text. **Left-most-prefix rule** for composite indexes. **Covering index** avoids row fetch.
- **Replication**:
  - *Primary-replica (async)* — reads scale, writes to primary, risk of lag/data loss.
  - *Primary-replica (sync)* — no data loss, higher write latency.
  - *Multi-master* — high complexity, conflict resolution required.

> **🪔 Vocabulary note**: "primary", "leader", and "master" mean the same thing in DB literature. Same for "replica", "follower", "slave". Modern docs prefer primary/replica — mentally translate older docs.

> **🧮 Worked example — quorum consistency (Cassandra/Dynamo style)**:
> - Replication factor N = 3.
> - Writer waits for W=2 acks before returning success.
> - Reader queries R=2 replicas and takes the freshest value.
> - Because W + R = 4 > N = 3, **at least one replica in R overlaps with W** → reader always sees the last write.
> - Try N=3, W=1, R=1 (fast but "AP"): 1+1 < 3 → stale reads possible.
- **Sharding**: hash / range / list / lookup. Use **consistent hashing** to minimize rebalance churn.
  - 🔗 **Related Questions**: [Q15: shard key for Twitter](03_interview_mode.md#q15-pick-a-shard-key-for-twitter-tweets-defend-), [Q20: why consistent hashing](03_interview_mode.md#q20-why-consistent-hashing-over-hashkey--n-), [Q22: hot key mitigation](03_interview_mode.md#q22-hot-key-on-a-sharded-system--mitigation-) · ❗ [Confusion: "sharding is horizontal scale"](04_confusion_resolver.md#-sharding-is-how-you-make-a-sql-database-horizontal)
- **Normalization** for integrity; **denormalization** for read performance + cross-shard join avoidance.
- **CAP / PACELC**: choose per workload, not per system.
  - 🔗 **Related Questions**: [Q46: honest CAP](03_interview_mode.md#q46-pick-two--honest-version-), [Q47: classify Cassandra/Mongo](03_interview_mode.md#q47-classify-cassandra--mongodb-in-pacelc-), [Q48: when eventual is wrong](03_interview_mode.md#q48-when-is-eventual-consistency-the-wrong-choice-) · ❗ [Confusion: "CAP says pick two"](04_confusion_resolver.md#-cap-says-pick-two)

### 🔹 4. Internal Working
**SQL write (MVCC, Postgres):** begin tx → execute statements → write WAL (durability) → fsync → commit log → apply to data pages in background → replica streams WAL.
**NoSQL write (Cassandra):** write to commit log + memtable → ack → memtable flushed to SSTable (immutable) → compaction merges SSTables.
**Read:** cache → primary/replica → page → index → row; for NoSQL read-path: bloom filters → SSTables → memtable merged.
**Failure points:** replication lag, split-brain multi-master, hot shards, lost writes on async replica.

### 🔹 5. Key Tradeoffs
- SQL: correct & joinable, but horizontal scale is hard.
- NoSQL: scale & flexibility, but joins are app-side, ACID often weakened.
- Replication: reads up, writes same; **replication lag causes read-after-write anomalies**.
- Sharding: throughput up, but joins across shards and cross-shard tx are painful.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. SQL vs NoSQL — decision criteria?
2. Why do we need indexes?

**Intermediate 🟡**
1. Explain MVCC vs locking.
2. What's replication lag and how do you mitigate read-after-write anomalies?

**Advanced 🔴**
1. Pick a shard key for Twitter tweets. Defend.
2. Explain LSM vs B-tree storage engines — when each wins.
3. How does Spanner provide global ACID? (TrueTime, Paxos)

### 🔹 7. Real System Mapping
- **Postgres/MySQL/Aurora**: transactional cores everywhere (Stripe, Shopify, SO).
- **Cassandra**: Netflix time-series, Apple messaging, Discord messages (moved to ScyllaDB).
- **DynamoDB**: Amazon's backbone; paper is a must-read.
- **BigTable**: Google; underpinning of Gmail, Search, Maps.
- **Spanner/CockroachDB**: global ACID via Paxos + TrueTime.
- **Uber LedgerStore**: trillions of secondary indexes; interesting engineering.

### 🔹 8. What Most People Miss
- **Hot rows** kill even good sharding. Monitor per-key QPS.
- **Indexes cost writes** — each secondary index = extra write amplification.
- **SSTable compaction** (Cassandra/RocksDB) is write amp + read amp tradeoff; Leveled vs Size-tiered compaction is a real decision.
- **CDC (Change Data Capture)** — Debezium / Netflix DBLog — is how you sync DBs to caches, search, and warehouses without dual-writes.
- **Transactional outbox**: write DB change + event atomically in same tx; Kafka ships the event later. Solves dual-write.
- **"NoSQL = no transactions" is outdated**: Mongo, DynamoDB, Cassandra now support transactions (with caveats).

### 🔹 9. 30-Second Revision
SQL for strict schema + joins + ACID; NoSQL for scale + flexible shapes. Replicate for read scale; shard when one node can't absorb writes (use consistent hashing). Index the dominant query; composite index left-most prefix. Denormalize when joins are too slow. LSM writes fast, B-tree reads balanced. Use outbox + CDC to avoid dual-write hell.

---

## 🔗 Cross-Topic Connections
- **Caching**: DB in front of cache; invalidation via CDC.
- **Load Balancing**: in front of replicas for read scaling.
- **Messaging**: CDC publishes DB changes as events.
- **Consensus**: strong-consistency distributed DBs (Spanner, CockroachDB, etcd) use Paxos/Raft.

---

### Confidence Check
- [ ] Can I pick the right DB per tier of a real system?
- [ ] Can I reason about shard key + its hot-spot risk?

### Gaps
- Spanner TrueTime internals.
- Distributed SQL (Vitess, YugabyteDB, CockroachDB) specifics.
- LedgerStore-style secondary index replication.
