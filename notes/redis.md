# Redis — The Swiss-Army In-Memory Store

> **📎 Prereqs** — If rusty:
> - [`caching.md`](caching.md) — why caches exist.
> - Data structure basics: hash, set, sorted set, list.
> - Single-threaded event-loop intuition (Redis is single-threaded per node).

### 🔹 1. What This Topic Actually Is
Single-threaded in-memory data structure server. Not just a KV — supports hashes, lists, sets, sorted sets, streams, HyperLogLog, bitfields, pub-sub, geo sets.

### 🔹 2. Why It Exists
- RAM access is 100 ns; SSD is 100 μs. Redis gives you ~1 ms latency at 100k+ QPS per node.
- Beyond cache: rate limiters, leaderboards, sessions, feeds, job queues, geo-lookup.

### 🔹 3. Core Concepts (High Signal)
- **Single-threaded** — one command at a time per node. Simple, no locks, but `KEYS *` blocks everything.
- **Data structures**:
  - String (basic + bitops), List (LPUSH/LPOP), Hash, Set, Sorted Set (ZADD, ZRANGE — leaderboards, feeds), HyperLogLog (cardinality), Stream (Kafka-lite), Geo, Bitfield.
- **Persistence**: RDB snapshots (fast but loses window), AOF (append-only log, more durable). Combine.
- **Replication**: async primary-replica. Sentinel manages failover.
- **Cluster mode**: 16384 hash slots across nodes. Clients aware; CRC16(key) % 16384 → slot → node.
- **Pipelining**: batch commands in one round trip.
- **Lua scripts**: atomic multi-command ops. Essential for rate limiters, distributed locks.
- **RedLock (distributed lock)**: controversial; Aphyr and others showed unsafe under clock skew. Prefer alternatives (fencing tokens, Zookeeper/etcd) for correctness-critical locks.

> **🧠 What if Redis were multi-threaded per connection?**
> Every command would need locks; atomic multi-step ops (Lua scripts, transactions) would need coordination overhead. The current single-threaded-per-node design trades concurrency-per-node for *simplicity + predictability*. Redis scales *out* via cluster/sharding, not via threading.

### 🔹 4. Internal Working
Command arrives → single thread executes → reply. O(log N) for sorted sets, O(1) for hashes/lists at head. Async replication streams to replicas. Cluster: gossip every few hundred ms; node ping failure → failover via slave promotion.

**Failure points:** memory exhaustion (OOM kill), single-thread blocking (slow command), cluster split-brain during partition, async lag on failover losing writes.

### 🔹 5. Key Tradeoffs
- Works: cache, session, counters, ephemeral queues, leaderboards, rate limits.
- Breaks: primary DB (volatile RAM), long-blocking ops, huge hot keys, strong durability needs (AOF helps but async).
- Alternatives: Memcached (simpler, multi-threaded, KV-only), Hazelcast, Aerospike.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. Why is Redis fast?
2. What's a sorted set good for?

**Intermediate 🟡**
1. Cluster vs sentinel — when each?
2. RDB vs AOF persistence?

**Advanced 🔴**
1. Implement atomic token bucket via Lua.
2. Build a leaderboard that handles a viral spike to 1M users.
3. Why is RedLock controversial — explain the fencing token argument.

### 🔹 7. Real System Mapping
- **Twitter, GitHub, Instagram**: heavy Redis usage.
- **Stack Overflow**: sessions + cache.
- **Uber**: geo sets for driver lookup.
- **Discord**: Redis Streams for some event flows.

### 🔹 8. What Most People Miss
- **Redis is single-threaded** — big keys and big commands kill latency for every user.
- **Big hash / big set** over ~10k members = O(N) and blocks. Shard them.
- **Expiry is lazy + active sampling** — memory may not be freed when you think.
- **Keyspace notifications** let you react to expiry/deletes as pseudo-events.
- **`SCAN` not `KEYS`** for production iteration.
- **TTL jitter** to avoid cache-stampede coincident expiries.
- **Redis Streams** is a legit Kafka-lite for smaller scale.

### 🔹 9. 30-Second Revision
Single-threaded, in-memory, rich data structures. Cache + session + leaderboard + rate limit + geo + pub-sub. Cluster shards via 16384 slots. AOF + RDB for persistence. Watch memory + big keys + blocking commands. Pipeline and Lua for atomic ops. Don't use RedLock for correctness-critical locks.

---

## 🔗 Cross-Topic Connections
- **Caching**: Redis is *the* distributed cache default.
- **Rate Limiting**: token bucket in Redis via Lua.
- **Messaging**: Redis Streams, Pub-Sub.
- **Location**: Redis GEO.
- **Databases**: often used as session + hot-KV layer in front of SQL.

---

### Confidence Check
- [ ] Can I pick the right Redis data structure per use case?
- [ ] Can I reason about memory + single-thread pitfalls?

### Gaps
- Redis on Flash (tiered memory).
- RDB + AOF combined operational playbook.
- Redis 7+ Function support.
