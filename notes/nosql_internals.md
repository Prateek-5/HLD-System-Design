# NoSQL Internals — LSM, SSTables, Compaction, Bloom Filters

### 🔹 1. What This Topic Actually Is
The storage-engine-level tricks that let NoSQL (Cassandra, BigTable, RocksDB, Scylla, LevelDB) absorb massive write throughput and still read fast.

### 🔹 2. Why It Exists
- B-tree updates in place → random I/O → write throughput ceiling.
- LSM converts random writes into sequential appends → orders of magnitude more writes/sec.

### 🔹 3. Core Concepts (High Signal)
- **LSM Tree (Log-Structured Merge)**: writes go to a commit log (durability) + in-memory **memtable** (sorted). When memtable fills, flush to disk as an immutable **SSTable**. Periodic **compaction** merges SSTables.
- **SSTable**: sorted string table on disk. Immutable. Contains data + index block + bloom filter + compression metadata.
- **Bloom filter**: probabilistic "is key possibly here?" check before scanning an SSTable. Zero false negatives, small false positives.
- **Compaction strategies**:
  - *Size-tiered (STCS)*: merge SSTables of similar size. Good for write-heavy, worse read amp.
  - *Leveled (LCS)*: tiered levels, each level ~10× prev size; bounds read amp. Higher write amp.
  - *Time-window (TWCS)*: group by time window — ideal for time-series with TTL.
- **Read path**: bloom filter check per SSTable → index block → read data block → possibly merge across SSTables + memtable.
- **Write amp vs read amp** tradeoff is the central knob.
- **Hyperloglog**: probabilistic cardinality (unique count) in ~12KB of memory, ~1% error. Used for "unique visitors" at massive scale.

### 🔹 4. Internal Working
**Write flow:** client → append to commit log → insert into sorted memtable → ack. No disk seek on write path (append-only).
**Memtable fills:** flush to L0 as SSTable (sorted, immutable).
**Compaction (background):** read K SSTables, merge-sort, write 1 new SSTable, delete inputs. Reclaims tombstoned/overwritten data.
**Read flow:** check memtable + each SSTable (newest first) → stop at first hit → bloom filter avoids unnecessary reads.
**Failure points:** compaction backlog (write amp explodes), bloom filter false positive cost, hot SSTables, tombstones eating space until compaction.

### 🔹 5. Key Tradeoffs
- LSM wins on writes (sequential, batched).
- LSM loses on reads (may scan multiple SSTables) — bloom filters + leveled compaction mitigate.
- B-tree wins on read-heavy OLTP with random point reads.
- Chose: Cassandra/RocksDB/LevelDB = LSM; Postgres/MySQL (InnoDB) = B+Tree.

### 🔹 6. Interview Questions
**Beginner**
1. Why is LSM good for writes?
2. What does a bloom filter do?

**Intermediate**
1. Explain SSTables and compaction.
2. Size-tiered vs leveled compaction — tradeoffs?

**Advanced**
1. Design compaction strategy for a 10 TB time-series table with 30-day TTL. (TWCS fits.)
2. Trace a read with 7 SSTables and a partially-purged tombstone.

### 🔹 7. Real System Mapping
- **Cassandra / ScyllaDB**: LSM core.
- **BigTable**: LSM (original inspiration — OSDI 2006 paper).
- **RocksDB**: Facebook's fork of LevelDB; embedded in Kafka Streams, CockroachDB, TiDB, MyRocks, Cassandra-4+.
- **DynamoDB**: storage engine is LSM-based.
- **ClickHouse**: column-store with LSM-like merging.

### 🔹 8. What Most People Miss
- **Compaction is a queue** with its own backpressure. If writes outpace compaction, read amp balloons and disk fills with stale data. Monitor it.
- **Tombstones** (markers for deletes) stay until a major compaction. Reading a partition with 10k tombstones = 10k skipped entries. Known issue in Cassandra.
- **Bloom filter sizing** — 1% FP ≈ 10 bits/key. For 1B keys that's 1.25 GB of bloom-filter RAM per replica. Real.
- **Hyperloglog merges** are associative — you can shard count, merge later. How Redis does `PFCOUNT` across nodes.
- **MemTable format** matters — skip-list or sorted array — affects write latency vs lookup speed.

### 🔹 9. 30-Second Revision
LSM = append-only write, background merge. Memtable → SSTable → compaction. Bloom filter avoids pointless SSTable reads. Size-tiered: write-friendly. Leveled: read-friendly. TWCS: time-series. Compaction is a backpressured queue — watch it. Hyperloglog = cardinality for cheap.

---

## 🔗 Cross-Topic Connections
- **Databases**: LSM is the reason write-heavy NoSQL exists.
- **Caching**: memtable is basically a write-cache backed by commit log.
- **Messaging**: Kafka uses append-only log + compaction — same philosophy.
- **Consistent hashing**: partitions LSM data across nodes.

---

### Confidence Check
- [ ] Can I sketch the LSM write and read paths?
- [ ] Can I explain bloom filter math?

### Gaps
- Exact RocksDB tuning knobs.
- Cassandra tombstone live-data ratio alert thresholds.
- Column-family-level compaction strategies.
