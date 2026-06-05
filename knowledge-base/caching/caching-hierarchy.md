# The Caching Hierarchy

> *"There are only two hard things in computer science: cache invalidation and naming things." — Phil Karlton. He left out the third: convincing yourself you've actually solved the first."*

---

## 🎯 Start Here — Intuition

> **In one line:** Keep a copy of slow-to-fetch data somewhere fast and close, so you don't pay the full cost of looking it up every single time.
>
> **Analogy:** Your kitchen. You don't walk to the grocery store every time you want milk — you keep some in the fridge (fast, small, nearby) and restock from the store (slow, huge, far) only when you run out. A cache is the fridge; the database is the store. The tricky part: if the store changes the price and your fridge label is old, you're now wrong without knowing it.
>
> **New to this?** Build the basics first in [`learn/foundations/scaling/caching.md`](../../learn/foundations/scaling/caching.md) — *then* come back for the depth.
>
> **Level:** this file is 🟡 overall, climbing to 🔴 in the internals. Sections below are tagged. If the basics feel shaky, that tag is your signal to slow down — **you are not behind.**

---

## Topic Overview 🟢

Caching is the most powerful performance technique in software, and the most dangerous. Done well, it turns a 200ms database query into a 200μs in-memory lookup. Done badly, it gives you correct answers 99% of the time and a 1% chance of showing one customer another customer's billing data.

The discipline isn't really one technique — it's a *hierarchy* of caches at every layer of every system, each making the same fundamental tradeoff: **trade some freshness for a lot of speed**. CPU caches (L1/L2/L3), TLB (Translation Lookaside Buffer), page cache, application-level memoization, in-memory key-value stores (Redis), CDN (Content Delivery Network), browser cache. Same idea, six orders of magnitude apart.

The senior engineer's job is not to know "how Redis works." It's to know **where in the hierarchy a given piece of data should live**, and what the cost of getting it wrong looks like at 3am.

---

## Intuition Before Definitions 🟢

Imagine your desk.

The book you're actively reading is *on the desk*. Reach: zero seconds.
Books from this project are *on the shelf above the desk*. Reach: 5 seconds.
Older project books are *in the bookshelf across the room*. Reach: 30 seconds.
Reference books are *in the library down the street*. Reach: 30 minutes.

Every workspace is a cache hierarchy. The closer something is, the faster you reach it, the less of it fits, and the more often you have to decide what to swap out.

You don't go to the library every time you need to look up a fact, because the cost is enormous. You also don't keep every book on your desk, because there's no room. You're constantly making cache eviction decisions. You're sometimes wrong — you put the book away and need it again ten minutes later.

That's caching. The library is your database. The desk is your CPU's L1 cache. Everything in between is intermediate storage. The art is figuring out **what belongs where, given how often you need it and how much it costs to fetch from the next level down**.

The hard part isn't the desk. The hard part is when someone *changes the book in the library* and your copy on the desk is now wrong, but you don't know it. That's cache invalidation, and it's the unsolved problem.

---

## Historical Evolution 🟢

**Era 1 — CPU caches.**
Mainframes had memory hierarchies before "cache" was a software word. SRAM (Static Random-Access Memory) close to the CPU, DRAM (Dynamic Random-Access Memory) further out, disk further still. The principle: locality of reference. Programs tend to access the same memory repeatedly (temporal locality) and nearby memory next (spatial locality). The hardware exploits this with on-chip caches measured in kilobytes.

**Era 2 — Operating system page cache.**
Filesystems learned to cache disk blocks in RAM. A file read might never touch the disk if the same data was read recently. This is invisible to applications and accounts for a huge fraction of "fast" file I/O on modern systems.

**Era 3 — Application-level caching.**
Web 1.0 era. Memcached (2003). LiveJournal needed to scale a database-backed site. The pattern: cache rendered query results in memory, hit cache before database. Throughput went up 10×, originally because the database was the bottleneck and most queries were repeats.

**Era 4 — Distributed in-memory stores.**
Redis (2009). Multi-purpose: cache, queue, pub/sub, primary store. Suddenly you have a cache that supports complex data types, transactions, persistence, replication. The line between "cache" and "database" blurs.

**Era 5 — CDN and edge caching.**
Akamai (1998), CloudFront, Cloudflare, Fastly. Move static assets — and increasingly dynamic ones — to edge nodes geographically close to users. Cuts cross-continent latency from 150ms to 5ms. The economics: serve once from origin, cache at every PoP (Point of Presence).

**Era 6 — The reactive era and cache-aside everywhere.**
Service meshes, function-level memoization, GraphQL response caching, edge computing with cache-aware logic. The hierarchy now reaches from the CPU up to the user's browser, with caches at every hop.

The pattern: each generation pushed the cache *closer to the consumer* of the data, because round trips are expensive and getting more expensive (relative to compute) every year.

---

## Deep Technical Explanation 🔴

⚠️ The rest assumes the basics above are solid.

### The full hierarchy (modern web app)

```
┌─────────────────────────────────────────────────────┐
│  Latency       Layer                                  │
├─────────────────────────────────────────────────────┤
│  ~1 ns         CPU registers                          │
│  ~1 ns         L1 cache (~64 KB)                      │
│  ~3 ns         L2 cache (~1 MB)                       │
│  ~10 ns        L3 cache (~32 MB shared)               │
│  ~100 ns       Main memory (DRAM)                     │
│  ~10 μs        OS page cache (in RAM, file-backed)    │
│  ~100 μs       Local in-process cache (object cache)  │
│  ~500 μs       Local Redis on same host               │
│  ~1 ms         Redis on same DC                       │
│  ~5 ms         CDN edge (POP near user)               │
│  ~10 ms        Database query (warm cache)            │
│  ~50 ms        Database query (cold)                  │
│  ~50–200 ms    Origin server cross-continent          │
└─────────────────────────────────────────────────────┘
```

A *single user request* may consult 4–8 of these layers. Latency budget is a sum across the whole path. The lowest two or three orders of magnitude of latency are entirely the property of the cache layer chosen.

### Caching patterns

**1. Cache-aside (lazy loading).**
Application checks cache; if miss, fetches from source; writes to cache; returns.

```
def get_user(id):
    user = cache.get(f"user:{id}")
    if user is None:
        user = db.query("SELECT * FROM users WHERE id = ?", id)
        cache.set(f"user:{id}", user, ttl=300)
    return user
```

Pros: simple, only caches what's actually requested.
Cons: every miss is a full DB query. Cache stampedes on hot keys.

**2. Read-through.**
Cache itself knows how to load from the source. Application talks only to cache.

Pros: encapsulates the loading logic; consistent miss path.
Cons: cache becomes a critical dependency.

**3. Write-through.**
Writes go to the cache, which synchronously writes to the source.

Pros: cache is always consistent with the source.
Cons: write latency = cache + source. No write-availability gain.

**4. Write-behind (write-back).**
Writes go to the cache; cache asynchronously flushes to source.

Pros: enormous write throughput.
Cons: data loss if cache fails before flush. Complex consistency.

**5. Refresh-ahead.**
Cache proactively refreshes hot keys before expiration.

Pros: hides cache misses for popular data.
Cons: potentially wasted refreshes; complexity in identifying "hot."

### Eviction policies

When the cache is full, which entry leaves?

| Policy | Mechanism | Best for |
|---|---|---|
| **LRU** (least recently used) | Evict the entry not accessed longest | General purpose |
| **LFU** (least frequently used) | Evict the entry accessed least overall | Stable workloads; plain LFU suffers cache pollution (once-hot keys never evict), so use decay (Redis's `lfu-decay-time`) or W-TinyLFU |
| **FIFO** (First In, First Out) | Evict in arrival order | Simplistic; rarely best |
| **TLRU** (Time-aware Least Recently Used) | LRU with TTL (Time To Live) filter | When freshness matters |
| **W-TinyLFU** (Window TinyLFU) | Hybrid; admission filter + LRU | Modern (Caffeine) |
| **2Q / ARC** (Adaptive Replacement Cache) | Adaptive between recency and frequency | Mixed workloads |

The default in Redis is `noeviction` (errors when full), with `allkeys-lru` and `volatile-lru` as common alternatives. The choice changes hit rate by 10–30% on real workloads — not a small knob.

### TTL strategies

- **Fixed TTL**: simplest. Sets a hard upper bound on staleness.
- **Sliding TTL**: refresh expiration on access. Hot keys live longer.
- **Stale-while-revalidate**: serve stale data while async-refreshing in the background. Hides backend latency.
- **Dependency-based invalidation**: explicitly invalidate when the source changes. Most correct, hardest to implement.

The TTL is your primary lever on the freshness-vs-throughput tradeoff. A 10-second TTL with 1000 RPS (Requests Per Second) = 99.99% reduction in DB load on that key.

### The thundering herd / cache stampede problem

A popular cache key expires. 1000 concurrent requests miss simultaneously. All 1000 hit the database. Database gets 1000 identical queries in milliseconds. CPU spikes, latency spikes, sometimes the database falls over.

Mitigations:
- **Probabilistic early refresh**: the first request to "almost-expired" cache triggers a refresh.
- **Mutex / single-flight**: only one request rebuilds; others wait.
- **Stale-while-revalidate**: serve stale data while one request rebuilds.
- **Soft TTL + hard TTL**: serve stale up to hard TTL while refreshing.

This is *the* classic caching production bug. Every team rediscovers it.

### Cache invalidation strategies

The hard problem. Options:

1. **TTL-based.** Accept staleness up to TTL. Simple. Always wrong sometimes.
2. **Write-through.** Cache always reflects source. Tightly coupled writes. Loses some write throughput.
3. **Explicit invalidation on write.** Write the source, then `DELETE` the cache key. Race condition: another reader can repopulate stale data between source write and cache delete. Mitigation: delete before AND after the source write, or use versioned keys.
4. **Versioned keys.** Cache by `user:{id}:v{version}` — bump version on writes. Old keys eventually evict. No race conditions, at the cost of cache space.
5. **Pub/sub invalidation.** Source-of-truth publishes "key X changed"; caches subscribe and evict. Eventually consistent across cache nodes.
6. **Change Data Capture (CDC).** Stream database changes; consumers update caches. Industrial-grade; complex.

The dirty secret: most "cache invalidation bugs" are race conditions in option 3. Reading the cache before invalidation, then writing back stale data after invalidation, all within a 10ms window. Defending against this is a real engineering effort.

### CDN caching specifics

CDNs add a layer of complexity:
- **Cache headers** (`Cache-Control`, `ETag` (Entity Tag), `Last-Modified`) drive behavior.
- **Edge cache vs origin shield**: a hierarchy *within* the CDN to reduce origin load.
- **Purge** is eventually consistent across PoPs — global purge takes seconds to minutes.
- **Cache key normalization**: query string ordering, cookies, geo headers — getting this wrong causes either zero cache hits or *cross-user data leakage*.
- **Surrogate keys** (Fastly's superpower): tag responses with logical keys, purge by tag — invalidate "all pages mentioning product 12345" in one call.

CDN caching is where "cache invalidation" becomes a distributed-systems problem with hundreds of nodes worldwide.

---

## Real Engineering Analogies 🟢

**The grocery store back room.**
The shelves (cache) are stocked from the back room (database). When a popular item runs out, an employee (the cache miss) goes to the back room and refills. The shelf is faster to access than the back room. If the back room is also empty, an employee drives to the warehouse (origin). The hierarchy continues all the way to the supplier.

The store's rules:
- Don't keep slow-moving items on the shelf (eviction).
- Reorder before running out for popular items (refresh-ahead).
- If you're rearranging the back room, keep the shelf consistent (invalidation).
- If a thousand customers ask for the same item simultaneously, don't send a thousand employees to the warehouse (single-flight).

This isn't a metaphor — it's the same problem, with different units.

**The newsroom morgue (archive) analogy.**
A newspaper has a *morgue* — its archive of every published article. When journalists need facts, they don't always go to the morgue; they might check the editor's desk, their own notes, or recent issues nearby. Each layer of "where is this fact?" is a cache. The morgue is the source of truth. The journalist's notes are an L1 cache — fast, small, frequently wrong. Senior journalists know which sources are reliable when.

---

## Production Engineering Perspective 🔴

What goes wrong in real caching systems:

- **The stampede when the cache restarts.** Redis OOM (Out Of Memory)-killed and restarted. Cache is empty. Every request misses. Database is overwhelmed. Cascading failure. Mitigation: warm caches before serving traffic; pre-populate from snapshots; rate-limit to backend during cold starts.
- **Cache key collisions.** A bug in key generation (`user:{id}` instead of `tenant:{tid}:user:{id}`) leaks data across tenants. Catastrophic security incident.
- **Memory bloat from large values.** A "cache user profile" key contains the user's *entire post history* by accident. Each key is 5MB. Redis OOMs at 10K users. Always cap value sizes.
- **TTL drift across replicas.** Multi-region cache replicas have slight clock skew. TTLs expire at different times. Some users see fresh data, others don't.
- **Thundering herd hidden in seemingly innocent code.** A worker process refreshes a cache key once per second. The worker dies. The TTL expires. 100K concurrent requests all rebuild simultaneously. Database melts.
- **Cache-as-database sins.** Storing data only in Redis without persistence. Redis crashes. Data lost. "I thought it was a cache." (Redis *can* persist, but the team didn't enable AOF (Append Only File) or RDB (Redis Database snapshot) correctly.)
- **The "stale forever" bug.** Background refresh has been failing silently for 3 weeks. Cache TTLs are sliding because of access. Users see 3-week-old data. Discovered when prices haven't updated despite the catalog change.
- **CDN purge eventual consistency.** Marketing announces a launch. Pushed update. Purged CDN. Some users in some regions see the old version for 90 seconds. Complaints flood support.

The senior engineer's habits:
- Treat the cache as **untrusted state**. Never assume it's correct or present.
- Monitor **hit rate, miss rate, eviction rate, memory usage, p99 latency**.
- Always have a **degraded path** — what does the system do if Redis is down?
- **Cap value sizes** at the cache layer. Reject oversized writes loudly.
- **Test cache cold-start** as part of capacity planning. The cold path determines your survival.

---

## Failure Scenarios 🔴

**Scenario 1 — Cold start cascade.**
Black Friday morning. Cache cluster restart deployed Thursday night accidentally cleared persistence. Cache is empty when traffic ramps. Every request misses. Database CPU 100%. Latency goes from 20ms to 5s. Auto-scaler can't help — it's CPU-bound on the database. Site degrades for 90 minutes until cache warms organically.

**Scenario 2 — The double-write race.**
Code: write DB, then `DELETE` cache. Two requests arrive nearly simultaneously: A writes new value to DB, A's cache delete is delayed. B reads cache (still old), writes computed result back, repopulating with stale data. A's delete finally runs. B's stale write remains. Caused 4 hours of incorrect billing.

**Scenario 3 — Cross-tenant key collision.**
A bug in key serialization caused two tenants' user IDs to collide. Cache served Tenant A's data when Tenant B requested it. Discovered when Tenant B saw Tenant A's username. Security incident, customer notifications, regulatory disclosure.

**Scenario 4 — The infinite-TTL silent drift.**
A migration set certain cache keys to TTL=0 (no expiration) "temporarily." The temporary became permanent. Six months later, a database schema change. Cache still serving old shape. Production errors looked random. RCA (Root Cause Analysis) traced to those zero-TTL keys.

**Scenario 5 — CDN purge missed a node.**
Global purge issued. 99.9% of edge nodes purged. One node in São Paulo had a connectivity issue and missed the purge. Brazilian users saw stale content for 6 hours. Discovered through customer reports.

---

## Performance Perspective 🟡

- **Latency reduction is multiplicative through the stack.** Saving 50ms at one layer saves 50ms on every request that hits that layer.
- **Cache hit rate compounds.** A 90% hit rate means the source sees 10% of traffic. A 99% hit rate means 1%. The capacity savings on the source are usually the biggest economic win, not the user-facing latency.
- **Memory cost is the limit.** RAM is expensive. Cache footprint must be sized against value. Big caches with low hit rates are pure waste.
- **Network is in the path.** A "fast" cache that's a network hop away can be slower than recomputation for cheap operations. In-process caches beat Redis when the value is cheap to compute and the working set is small.
- **Serialization cost matters.** A Redis hit at 0.5ms with 5ms of JSON deserialization is a 5.5ms operation, not 0.5ms.

---

## Scaling Perspective 🔴

- **Vertical:** add RAM. Redis can hold tens of GB on one node, hundreds on a beefy box.
- **Horizontal:** Redis Cluster, partitioned across N nodes. Sharding by key hash. Cross-shard transactions become hard.
- **Replication:** read replicas for reads; primary for writes. Same primary-replica architecture as databases.
- **Geographic:** edge caching, regional caches, hierarchical fanout. Cache invalidation becomes a distributed-systems problem in itself.
- **The hard problems at scale:**
  - **Hot keys.** A single key receiving 100K req/s pins one shard. Mitigations: replication, request coalescing, key sharding.
  - **Cluster topology changes.** Adding a node rebalances data; many implementations have "blackout" periods during rebalance.
  - **Failover behavior.** Primary fails, replica promotes — what happens to in-flight writes?

---

## Cross-Domain Connections 🟡

- **MVCC (Multi-Version Concurrency Control):** the buffer pool is a cache. Bloated indexes lower its hit rate. The principle (keep the working set in fast storage) is identical.
- **Distributed consistency:** cache invalidation is consistency-model design. Stale reads in a cache hierarchy are *exactly* the eventual consistency problem from distributed databases. Same theory, different name. (See [cap-consistency-and-replication.md](../distributed-systems/cap-consistency-and-replication.md).)
- **Event loop:** memoization within a request is the smallest cache. Same logic, microsecond timescale.
- **Operating systems:** TLB is a cache for virtual-to-physical address translations; page cache is a cache for disk blocks; instruction cache is a cache for code. The OS *is* a stack of caches.
- **Networking:** DNS (Domain Name System) caching at every level (browser, OS, recursive resolver, root). The Internet wouldn't function without this hierarchy.
- **Database query plans:** prepared statements cache plans. Plan cache invalidation when statistics change is the database's version of cache invalidation.

The unifying observation: **caching is what every layer does when the layer below is too slow to talk to every time.** It's not a technique — it's a *property of layered systems with latency asymmetry*.

---

## Real Production Scenarios 🔴

- **Facebook/Memcached at scale:** the famous "Scaling Memcache at Facebook" paper covers thundering herds, leases, and cluster-aware caching at billion-user scale. Required reading.
- **Netflix's EVCache:** distributed Memcached with multi-region replication. Their public engineering posts document the *operational* reality of large-scale caching.
- **Twitter's cache stampedes during traffic spikes:** historically, follower-list caching had thundering herd issues during celebrity tweet events. Mitigations: probabilistic early refresh, single-flight per key.
- **Cloudflare's Tiered Cache:** introduces an intermediate cache between edge and origin specifically to reduce origin load when edge caches miss. Same hierarchy logic, applied at the network layer.
- **GitHub's view counter cache bug (multiple postmortems):** counters are notoriously cache-hostile because every update invalidates. Solutions involve write-behind and per-counter sharding.

---

## Worked Example — Multi-Tier Caching for a Product Page 🔴

A high-traffic e-commerce product page. Goal: low latency globally, low origin load, fresh-enough data.

### Latency budget

- User-perceived: <300ms total.
- TTFB (Time To First Byte) target: <100ms at edge.
- Backend budget when miss: ~1s.

### Tier breakdown

```
Tier 1: Browser cache (HTTP cache headers)
  - Static assets (CSS, JS, images): 1 year, immutable.
  - Product HTML: 60s with `stale-while-revalidate=300`.

Tier 2: CDN edge cache (Cloudflare/Fastly)
  - Product page HTML: 5 min TTL; surrogate key per product ID.
  - Product images: 1 day; immutable.
  - API responses (JSON): 30s for catalog reads.
  - Cache key: includes country, device-type; not user-specific.

Tier 3: Application cache (in-process)
  - Product objects: 30s TTL.
  - Hot product: refresh-ahead at 80% of TTL.

Tier 4: Distributed cache (Redis)
  - Product objects: 5 min TTL.
  - Inventory snapshots: 10s TTL (eventually consistent with primary).

Tier 5: Database (Postgres + read replicas)
  - Source of truth.
  - Read replicas for read scaling.
```

### Cache key design

For the product page:

```
Cache Key = "product:{id}:{country}:{device_type}:{currency}"
  Example: "product:12345:US:mobile:USD"
```

Cardinality concerns:
- `id`: thousands.
- `country`: ~200.
- `device_type`: 3 (mobile/tablet/desktop).
- `currency`: ~50.
- Total: thousands × 200 × 3 × 50 = ~30M unique keys.

Acceptable; high hit rate likely because access concentrates on popular products.

### Invalidation strategy

When a product is updated:

```python
def update_product(product_id, changes):
    db.update_product(product_id, changes)

    # Clear application caches (best-effort)
    publish_event("product.updated", {"id": product_id})
    # Other instances of the service receive event; clear their in-process cache.

    # Clear Redis. There is no native "delete by pattern" command;
    # iterate with SCAN (non-blocking) and DEL the matches. Never use
    # KEYS * in production — it's an O(N) blocking scan on a single-threaded server.
    for key in redis.scan_iter(match=f"product:{product_id}:*"):
        redis.delete(key)

    # Purge CDN by surrogate key (eventually consistent globally)
    cdn.purge_surrogate(f"product-{product_id}")
    # Returns immediately; takes 5-30s to propagate globally.

    # Browser caches: respect TTL; up to 60s stale possible.
```

For a price change, this is acceptable: brief staleness during propagation.

For an inventory "out of stock" change, more aggressive:

```python
def mark_out_of_stock(product_id):
    db.update_product(product_id, {"in_stock": False})

    # Aggressive CDN purge
    cdn.purge_surrogate(f"product-{product_id}")

    # Update Redis directly with the new state (faster than purging)
    redis.set(f"product:{product_id}:status", "OUT_OF_STOCK", ex=300)
```

### Stampede protection

Popular products will have many concurrent misses on TTL expiry. Single-flight + probabilistic refresh:

```python
def get_product(id):
    cached = redis.get(cache_key(id))

    if cached:
        ttl_remaining = redis.ttl(cache_key(id))
        # Probabilistic early refresh: more likely as TTL approaches expiry
        if random.random() < (1 - ttl_remaining / 300) ** 2:
            background_refresh(id)
        return json.loads(cached)

    # Miss: single-flight to prevent stampede
    return single_flight(id, lambda: fetch_and_cache(id))
```

A popular product gets refreshed *before* it expires; cache stampedes don't happen.

### Performance result

- 95% of requests served from CDN edge: ~10ms.
- 4% from application/Redis cache: ~30ms.
- 1% from database: ~150ms.
- Origin load: ~1% of total RPS. Database easily handles.

The hierarchy collapses load by 100×; user-perceived latency is dominated by network, not backend processing.

### Reference architecture

```
                ┌──────────────────────┐
                │     User browser      │
                │  (HTTP cache: 60s)    │
                └──────────┬───────────┘
                           │ ~5ms
                           ▼
                ┌──────────────────────┐
                │  CDN edge (Tier 2)    │
                │  - Anycast routing    │
                │  - Surrogate-key purge│
                │  - Hit rate: 90%+     │
                └──────────┬───────────┘
                           │ on miss: ~30ms
                           ▼
                ┌──────────────────────┐
                │  Application server   │
                │  (in-process cache)   │
                │   Tier 3              │
                └──────────┬───────────┘
                           │ on miss: ~5ms
                           ▼
                ┌──────────────────────┐
                │  Redis cluster        │
                │  (Tier 4)             │
                │   Hit rate: 95%       │
                └──────────┬───────────┘
                           │ on miss: ~50ms
                           ▼
                ┌──────────────────────┐
                │  Database             │
                │  (read replicas)      │
                │   Source of truth     │
                └──────────────────────┘
```

---

## Recent Production References (2023-2024) 🟡

- **Cloudflare's tiered-cache architecture**: published documentation on edge → regional → origin cache hierarchy; reduces origin load dramatically.
- **The 2022 Fastly outage**: a config bug took down significant fraction of internet briefly. Postmortem covers recovery and customer trust.
- **Discord's read-through cache architecture**: extensively documented at scale.
- **The Hacker News effect**: small sites get suddenly popular; cache cold-start surfaces issues. A standard chaos scenario.
- **Stripe's idempotency cache**: documented patterns for caching idempotency keys efficiently.
- **AWS CloudFront Functions / Lambda@Edge**: edge-compute that integrates with caching; growing usage.
- **Vercel's Edge Network**: cache-then-revalidate at edge for ISR (Incremental Static Regeneration); Next.js standard.

---

## Negative Caching & Cache Penetration 🔴

Stampede protects against hot keys that *exist*. **Cache penetration** is the opposite failure: requests for keys that *don't* exist. An attacker (or a buggy client) hammers `user:99999999` — a row that isn't in the DB. Cache-aside checks the cache (miss, because there's nothing to store), queries the DB (miss), stores nothing, and returns null. Every single request falls through to the database. The cache provides zero protection precisely because the data is absent. A scripted attack iterating non-existent IDs can drive 100% of traffic to the DB.

**Negative caching** is the fix: cache the *negative result itself*. On a DB miss, store a tombstone (an empty/sentinel value) under the key with a **short TTL** — typically much shorter than positive TTLs, e.g. 10-30s versus 5min.

```python
def get_user(id):
    val = cache.get(f"user:{id}")
    if val is not None:
        return None if val == NULL_SENTINEL else val
    user = db.query("SELECT * FROM users WHERE id = ?", id)
    if user is None:
        cache.set(f"user:{id}", NULL_SENTINEL, ttl=30)   # negative entry
        return None
    cache.set(f"user:{id}", user, ttl=300)
    return user
```

The short TTL is the whole design tension: long enough to absorb a penetration burst, short enough that a key created *after* the negative entry isn't invisible for too long. If creation must be instantly visible, explicitly delete the negative entry on the insert path (write-side invalidation of the tombstone).

**Bloom filter as the alternative guard.** Maintain a Bloom filter of all keys that *do* exist. Check it before touching the cache or DB: if the filter says "not present," the key definitively does not exist — short-circuit and return null with no DB query. Bloom filters have **no false negatives** (a real key always passes) but **tunable false positives** (a small fraction of non-existent keys leak through to the DB — acceptable). They are extremely compact: ~1.2 GB holds ~1 billion keys at a 1% false-positive rate (roughly 9.6 bits/key), versus storing a tombstone per probed key. The catch: standard Bloom filters don't support deletion, so a deleted key still reports "present" — use a counting/cuckoo filter or periodic rebuild if keys are removed. Negative caching and a Bloom filter are complementary: the filter blocks the bulk of garbage IDs cheaply; negative entries catch the false-positive remainder.

## Redis vs Memcached — Internals & When to Pick Which 🔴

Both are in-memory key-value stores reached over the network. The architectural differences decide the choice.

| | **Redis** | **Memcached** |
|---|---|---|
| **Threading** | Single-threaded command execution on an event loop (epoll/kqueue); I/O threads since 6.0 only offload socket read/write, not command logic | Multi-threaded; scales vertically across cores natively |
| **Memory mgmt** | jemalloc; per-type encodings (ziplist/listpack, intset) | **Slab allocator** — memory carved into fixed size-classes; objects rounded up to the nearest class |
| **Data model** | Rich types: strings, hashes, lists, sets, sorted sets, bitmaps, HyperLogLog, streams, geo | Opaque bytes only — string keys to string/blob values |
| **Persistence** | Optional **RDB** (point-in-time snapshot/fork) and **AOF** (append-only command log, `appendfsync everysec` default) | None — purely volatile |
| **Eviction** | Configurable (`noeviction`, `allkeys-lru`, `allkeys-lfu`, etc.) | LRU within each slab class |
| **Replication / HA** | Async primary-replica, Sentinel, Redis Cluster (16384 hash slots) | None natively; client-side sharding (consistent hashing) |

**Why single-threaded matters (Redis).** Command execution is serialized, so individual commands are atomic with no locking — but one slow command (`KEYS *`, a large `SORT`, a big `SMEMBERS`) blocks *every* other client for its full duration. This is why the worked example forbids `KEYS *` and uses `SCAN`. A single Redis instance saturates roughly one core; you scale out with Cluster, not threads.

**Why the slab allocator matters (Memcached).** Fixed size-classes mean a 1.1 KB object lands in (say) a 1.2 KB slab, wasting ~100 bytes — **slab calcification**: memory assigned to one class can't easily move to another, so a workload whose object-size distribution shifts can have free memory it cannot use. Upside: zero fragmentation churn, trivially multi-threaded, very high raw throughput for uniform small objects.

**When to pick which.**
- **Memcached** when you want a *pure*, volatile, look-aside cache of small uniform objects (rendered fragments, session blobs, query results), need to saturate many cores from a single node, and want operational simplicity. It does one thing.
- **Redis** when you need anything beyond opaque get/set: server-side data structures (leaderboards via sorted sets, rate-limiter counters, queues, pub/sub), atomic multi-step operations (Lua/`MULTI`), persistence or replication/failover, or eviction-policy control. The cost is a more complex operational surface and the single-threaded hot-path constraint.

The honest senior framing: Memcached is a cache; Redis is a data structure server that is frequently *used* as a cache. If your only requirement is "fast key-value with TTL," both work and Memcached is simpler; the moment a second requirement appears (a counter, a sorted set, durability), it's Redis.

---

## Key Takeaways

- **Caching trades freshness for speed.** Every cache decision is a freshness budget. If you can't tolerate any staleness, you don't have a cache — you have a slower indirection.
- **The cost of staleness varies wildly by data type.** Stale marketing page: nobody cares. Stale checkout balance: someone is suing you. The same infrastructure is right or wrong depending on the data — distinguish acceptable staleness per data type and choose TTLs accordingly.
- **Hit rate is the dominant metric, and its biggest payoff is origin-load reduction, not user latency.** 90% hit means the source sees 10% of traffic (10× reduction); 99% means 1% (100× reduction). Monitor it as a primary metric, not a vanity stat.
- **Three patterns: cache-aside, write-through, write-behind.** Everything else (read-through, refresh-ahead) is a variant.
- **TTL is your primary knob.** Tune per-data-type. Sliding (access-based) TTLs can keep stale data alive forever under steady load.
- **Cache stampedes are the rule, not the edge case, on hot keys.** Use single-flight, probabilistic early refresh, or stale-while-revalidate — reach for these on hot keys without being asked.
- **Cache invalidation is distributed-systems consistency design.** Once the cache lives outside the source's memory space, it's a consistency problem with a different name. Design it explicitly.
- **Versioned keys beat delete-then-write race conditions.** `DELETE`-then-`SET` ordering creates races that look like ghosts in production.
- **Always have a fallback.** The cache is not always available; cache unavailability must not equal application unavailability. Every cache call needs a fallback path, and you should reflexively check what happens when the cache is cold during capacity planning.
- **Cap value sizes (and key sizes) at the cache layer.** Unbounded values OOM the cache at the worst possible time.
- **Never store data only in a cache** without explicit persistence guarantees.
- **Cache the misses too.** Requests for non-existent keys (cache penetration) bypass an ordinary cache entirely. Store short-TTL negative entries, or front the cache with a Bloom filter, to stop garbage IDs from hammering the DB.
- **Redis vs Memcached is an internals decision, not a brand preference.** Memcached: multi-threaded, slab allocator, volatile — a pure cache. Redis: single-threaded command loop, rich data structures, optional RDB/AOF persistence — a data-structure server used as a cache. Default to Memcached for plain volatile key-value at high per-node throughput; reach for Redis the moment you need a second capability (structures, durability, replication, atomic multi-step ops).
- **Know whether your cache is in-process or out-of-process** and the cost difference — a network-hop cache can be slower than recomputation for cheap values.
- **The cache is at every layer.** CPU, OS, app, Redis, CDN, browser. Same idea, six orders of magnitude apart. Every cache is a small distributed system; every invalidation is a small consistency problem.

The senior instinct, looking at any system, is to scan the latency hierarchy and ask: *where is the slow layer? what's the working set above it? what's the freshness requirement of the data?* The right cache, in the right place, with the right TTL, hides almost any backend problem. The wrong one becomes the next outage. The senior engineer treats cache invalidation as a *design problem*, not an implementation detail.

---

## Interview angle 🟡

What gets tested:

1. **"How would you cache user profile data?"** Junior: "use Redis." Senior: "cache-aside with TTL, key by user ID, value-size cap, invalidate on profile updates with versioned keys to avoid the stale-write race, fallback to DB if cache is unavailable."
2. **"What happens during a cache stampede?"** Tests whether the candidate knows the problem exists and can name a mitigation (mutex, probabilistic refresh, stale-while-revalidate).
3. **"How do you invalidate a cache?"** A trap. The right answer is "depending on consistency requirements, here are the options" — not a single technique.
4. **"What's your eviction policy?"** Tests whether the candidate has thought about hit-rate optimization or just defaulted to LRU.
5. **"How do you handle cache-database write ordering?"** Tests understanding of the race conditions. Bonus for naming the "double delete" pattern or versioned keys.
6. **"Design a CDN."** Tests whether the candidate sees CDN as a distributed cache hierarchy with edge nodes, origin shields, and invalidation challenges.
7. **"When wouldn't you cache?"** Tests engineering judgment: cheap-to-compute values, low hit rate, high invalidation cost, security-sensitive data.

Common traps: treating cache invalidation as trivial; assuming Redis is always available; storing complex objects without size limits; using cache-aside with no protection against stampedes.
