# Caching

### 🔹 1. What This Topic Actually Is
A fast, size-limited key-value layer in front of slower storage. Absorbs repeated reads; trades freshness/storage for latency.

### 🔹 2. Why It Exists
- RAM ≈ 1000× faster than SSD, 100k× faster than cross-DC. Caches collapse that gap for the 95%+ of requests that hit.
- Without a cache: every read pays full DB/disk cost; hot keys melt DBs.

### 🔹 3. Core Concepts (High Signal)
- **Patterns**:
  - *Cache-aside (lazy)* — app reads cache, on miss fetches + populates. Most common.
  - *Read-through* — cache transparently fetches from source.
  - *Write-through* — write goes to both cache + DB. Consistent, slower.
  - *Write-around* — write bypasses cache; first read is a miss.
  - *Write-back* — write to cache, async to DB. Fast, durability risk.
- **Eviction**: LRU (default), LFU (long tail), FIFO, random, TTL.
- **Invalidation** (hard problem): TTL + active invalidation on writes.
- **Layers of cache**: browser → CDN → reverse proxy (Varnish/Nginx) → app-local (Caffeine/Guava) → distributed (Redis/Memcached) → DB buffer pool.
- **Stampede / thundering herd** fixes: request coalescing, TTL jitter, stale-while-revalidate.
- **Negative caching**: cache the "not found" answer with short TTL.
- **Hot key problem**: one key gets 90% of traffic → partition that key (add suffix, shard) or replicate.

### 🔹 4. Internal Working
**Read path:** client → cache lookup → hit (return) or miss → DB fetch → populate cache → return.
**Write path:** depends on pattern (see above).
**Redis cluster:** 16384 hash slots across nodes; clients aware; gossip + failover via replica promotion.
**Failure points:** cache down (all traffic hits DB → meltdown), stale data, hot shard, memory evictions faster than anticipated.

### 🔹 5. Key Tradeoffs
- Works well: repeated reads, bounded working set, tolerable staleness.
- Breaks: low repetition (waste), data changes constantly (invalidation overhead), working set >> cache size (low hit ratio).
- Alternatives: precomputed views, materialized views, CDN for static, DB-level caches.

### 🔹 6. Interview Questions
**Beginner**
1. What is a cache hit vs miss?
2. When should you NOT cache?

**Intermediate**
1. Compare write-through, write-around, write-back.
2. How do you handle cache stampede when a hot key expires?

**Advanced**
1. Design cache layer for 100M DAU social feed (Uber-like 40M RPS is the reference).
2. You have a Redis cluster at 95% memory. What are your options? (eviction tune, tiered cache, sharding, compression)

### 🔹 7. Real System Mapping
- **Facebook Memcached** — canonical paper "Scaling Memcache at Facebook".
- **Twitter, GitHub, Stack Overflow** — Redis-heavy.
- **Uber's integrated cache for 40M RPS** — tiered: L1 in-process + L2 Redis.
- **Caffeine / Guava Cache** — in-process with W-TinyLFU.
- **CDN** — geo-distributed cache.

### 🔹 8. What Most People Miss
- **Cold cache after deploy** can destroy your DB. Warm caches deliberately or route traffic gradually.
- **Tiered caches** (L1 in-process + L2 Redis) beat single-layer: sub-microsecond for hottest keys, 1 ms for rest.
- **Hit ratio alone lies** — a 99% hit rate with 1% pathological misses killing the DB is still bad.
- **Redis is single-threaded** for commands — one slow `KEYS *` blocks the whole instance.
- **Consistent hashing** for cache clients — adding/removing a node loses only 1/N of entries, not all.

### 🔹 9. 30-Second Revision
Cache-aside is default. TTL + active invalidation for freshness. LRU default eviction. Solve stampede with coalescing, jitter, stale-while-revalidate. Tiered caches (L1 local + L2 Redis) for best latency. Redis = single-thread per node, cluster for scale. Invalidation is the hard part.

---

## 🔗 Cross-Topic Connections
- **Load Balancing**: L7 LBs can cache responses — "cheap CDN" for headquarters.
- **Databases**: every DB has a buffer pool — an internal cache.
- **Messaging**: CDC can invalidate caches on DB changes via a topic.
- **Consistent hashing**: the distribution algorithm for multi-node caches.

---

### Confidence Check
- [ ] Can I list 4 write patterns and when each?
- [ ] Can I apply to a real problem (feed, catalog, session)?

### Gaps
- W-TinyLFU algorithm (Caffeine).
- Tiered cache eviction coherence.
- Exact Redis memory math for a given workload.
