# Caching — The Single Biggest Performance Lever

> **Prereq**: [IP](../networking/ip.md), [DNS](../networking/dns.md)
> **What you will understand by the end**: why almost every fast system in production has a cache in front of a slower store, the three write strategies, invalidation strategies, eviction policies, and why "cache invalidation" is famously one of the two hardest problems in CS.

---

## A. Intuition First

### The analogy
You're a librarian. A reader asks for *Hamlet*. You walk to Archive Building 3 (10 minutes) and come back. Two minutes later, another reader asks for *Hamlet*. You walk again.

Obviously stupid. Keep a shelf near the front desk with your 50 most-requested books. The first request cost 10 minutes, every subsequent one costs 5 seconds.

**That shelf is a cache.** The archive is your database.

### Why caches exist
One axiom drives all caching: **fast memory is expensive, slow memory is cheap. Access is not uniform — a small fraction of data is requested constantly** (locality of reference). Keep that fraction in fast memory. Pay the slow cost only on the first hit (cache miss) or when the fast copy goes stale.

The latency gap is huge:
- RAM: ~100 ns
- SSD: ~100 μs (1000×)
- Disk: ~10 ms (100,000×)
- Cross-datacenter: ~100 ms (1,000,000×)

A cache collapses six orders of magnitude of latency for the 95%+ of requests that hit.

---

## B. Mental Model

A cache is a **fast, size-limited key-value store** layered in front of a slower, authoritative store. Three questions define any cache design:

1. **Where** does it live? (client, CDN edge, LB, app-local, distributed Redis, DB buffer pool — you have a cache at *every* tier whether you notice or not)
2. **Write strategy**: how do writes propagate to the backing store?
3. **Invalidation strategy**: when does a cache entry become wrong, and how is that detected?

---

## C. Internal Working

### Cache hit / miss flow
```
                       yes → return cached value
request → cache lookup ┤
                       no  → fetch from source → store in cache → return
```

### The three write strategies

**Write-through**: write goes to cache and DB in the same operation.
- ✅ Cache always consistent with DB.
- ❌ Every write pays both cache + DB cost.
- Good for: read-heavy workloads where you want read hits to be reliable.

**Write-around**: write skips cache, goes only to DB.
- ✅ Fewer cache writes, cache only holds "actually read" data.
- ❌ First read after a write is a miss (cold re-read).
- Good for: write-once-read-rarely data.

**Write-back (write-behind)**: write goes to cache, cache asynchronously flushes to DB.
- ✅ Write latency is RAM-fast.
- ❌ Cache crash = data loss.
- Good for: absorbing write bursts; must be combined with replication for durability.

Chosen-based-on-workload, not one-size-fits-all.

### Cache invalidation — the hard part
Two strategies, both imperfect:

**TTL (time to live)**: cached entries expire after N seconds. Simple. Tolerates staleness for N seconds.

**Active invalidation**: on every write to DB, delete/update the cache entry. Harder — you need to know every cache key affected, and your cache-delete might fail, leaving stale data.

Real systems combine: short TTL + active invalidation on writes.

### Eviction policies — when cache is full

| Policy | What it does | When it's right |
|---|---|---|
| **LRU** | Evict least-recently-used | General-purpose default. Redis defaults to this. |
| **LFU** | Evict least-frequently-used | Strong long-tail data (hot keys stay hot for days) |
| **FIFO** | First in, first out | Rarely best; simple to implement |
| **Random** | Drop random entry | Surprisingly ok; avoids LRU's metadata cost |
| **TTL-only** | Don't evict, just expire | Bounded data with predictable age |

### Where caches live (the cache hierarchy)

```
Client (browser cache, HTTP cache headers)
   ↓
CDN (edge nodes)
   ↓
Reverse proxy (Nginx/Varnish)
   ↓
Application cache (in-process: Guava, Caffeine)
   ↓
Distributed cache (Redis, Memcached)
   ↓
Database buffer pool (Postgres shared_buffers)
   ↓
Disk
```

Every tier is a cache. Senior engineers design their stack by asking: "at which layer do I add the cache?"

### Local vs distributed cache

**Local (in-process)**: memory inside your app. Fastest (nanoseconds). Problem: each app instance has its own → inconsistency + cache-stampede on cold start of a new instance.

**Distributed (Redis/Memcached)**: shared cluster. Consistent across app instances. Cost: network hop (~0.5–1 ms). Usually worth it.

Both can coexist: local cache for microsecond-hot keys, Redis for the rest.

### Cache stampede / thundering herd

Scenario: a hot key expires. 1000 concurrent requests all miss → all hit DB → DB dies.

Fixes:
- **Request coalescing**: only one request refetches; others wait for the single in-flight fetch.
- **Staggered TTL**: small random jitter on TTLs so not all keys expire at once.
- **Stale-while-revalidate**: serve stale data for a few seconds while one request refreshes in the background.

---

## D. Visual Representation

```
[App] ─ miss ─→ [Redis] ─ miss ─→ [DB]
          ↑                           │
          └───────── populate ────────┘
                      TTL=300s

Write flow (write-through):
[App] ──→ [Redis] ───→ [DB]  (both before returning)
```

---

## E. Tradeoffs

### When caching is wrong
- **Low repetition**: each request is unique → cache never hits → wasted memory.
- **Data changes fast**: constant invalidation → more overhead than saved work.
- **Cache access is as slow as source**: no point.

### Consistency vs performance
Caches are a direct **availability/consistency tradeoff**. Eventual consistency (TTL expiry) is what lets caches be useful; strong consistency would require invalidating every copy on every write (expensive).

### Cold-cache problem
After deploy / restart / flush, every request is a miss → DB overwhelmed. Mitigations:
- **Cache warming** — preload hot keys during deploy.
- **Gradual rollout** — only shift 1% of traffic at a time until cache fills.

---

## F. Interview Lens

### The classic prompts
- "Design a system where reads are 100× writes."
- "What eviction policy for X workload?"
- "How would you avoid cache stampede?"
- "Compare write-through, write-around, write-back."
- "How do you keep cache and DB consistent?"

### Expected depth
- **Junior**: knows cache = fast storage in front of slow storage; can name Redis.
- **Mid**: explains three write strategies; LRU; TTL.
- **Senior**: discusses stampede mitigations, staleness budget, cache layering, hot-key problems (hotspot mitigation via sharding or replication), and explicit consistency model.

### Pitfalls
- "Just add Redis" without a consistency story.
- Forgetting that a Redis cluster is itself a distributed system with its own failure modes.
- Treating cache hit ratio as sufficient — p99 latency is what users feel.
- Not considering memory cost: caching 1 TB of data needs 1 TB of RAM (or a tiered cache).

---

## G. Real-World Mapping

- **Redis** at Twitter, GitHub, Snapchat, Stack Overflow.
- **Memcached** at Facebook (they wrote the "Scaling Memcache at Facebook" paper — required reading).
- **CDN** = a geographically distributed cache.
- **DB buffer pool** (Postgres `shared_buffers`, MySQL InnoDB buffer) = page cache.
- **Browser HTTP cache** = client-side cache respecting `Cache-Control` headers.

---

## H. Questions

### Beginner
1. Why does caching make systems faster?
2. What's a cache hit vs a cache miss?
3. What's TTL?

### Intermediate
1. Compare write-through, write-around, write-back.
2. When is LRU a bad choice?
3. Why do distributed caches exist if local caches are faster?

### Advanced (interview)
1. A hot key expires under load and your DB falls over. Design two fixes.
2. Explain the tradeoff between cache consistency and write throughput.
3. Design the cache layer for a news site: 10M DAU, 500 articles/day, each article viewed millions of times.
4. How would you size a Redis cluster for 200 GB of working set + 100k QPS?

---

## I. Mini Design Problem — "Cache Instagram-like feed"

Requirements: 50M DAU, each user loads feed on app open; feed is a list of 50 recent posts from followed users. 95% read, 5% write (post creation, like, follow).

**Approach**
1. **Push model** (fan-out on write): on post, update every follower's feed cache. Good for low-follower-count users, brutal for celebrities.
2. **Pull model** (fan-out on read): on feed-open, query posts from every user you follow. Simple but slow.
3. **Hybrid (Twitter's approach)**: push for normal users; pull for celebrity posts; merge at read time.

**Cache layout (Redis)**
- Key: `feed:{user_id}` → sorted set of (post_id, timestamp), capped at 500 entries.
- TTL: unset — kept hot as long as user is active.
- Invalidation: active — on new post, push into followers' sorted sets.

**Stampede protection**: on cache miss (cold feed), use Redis `SETNX` lock so only one worker rebuilds; others wait briefly and re-read.

This is a microcosm of a real Twitter-scale feed.

---

## J. Cross-Topic Connections
- **[CDN](cdn.md)** — edge caching.
- **[DNS](../networking/dns.md)** — a massive cache hierarchy.
- **[Consistent Hashing](../../data/consistent-hashing.md)** — used inside Redis Cluster / Memcached clients.
- **[Database Replication](../../data/database-replication.md)** — read replicas are a kind of cache.
- **[CQRS](../../architecture/cqrs.md)** — the query side is often cache-backed.

---

## K. Confidence Checklist
- [ ] I can distinguish write-through / around / back with tradeoffs.
- [ ] I can name 3 eviction policies and when each wins.
- [ ] I can design a fix for cache stampede.
- [ ] I know why cold-cache is dangerous and how to mitigate.
- [ ] I can defend "cache here, not there" for a given architecture.

### Red flags
- ❌ "Cache = Redis, done" — no consistency story.
- ❌ Forgetting cache invalidation entirely.
- ❌ Using cache for durable data.

---

## L. Potential Gaps & Improvements
- **Read-through / lazy-loading** patterns deserve explicit sections (I implied but did not contrast explicitly).
- **Cache-aside** vs write-through — cache-aside is the most common pattern in practice; deserves formal coverage.
- **Negative caching** (caching NOT-FOUND answers) — missing.
- **Cache partitioning / sharding** across Redis cluster — deserves math treatment.
- **Secondary indexes inside cache** — real pattern, not covered.
