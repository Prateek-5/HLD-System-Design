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

🔗 **Related Questions**: [Q13: stampede fixes](../../03_interview_mode.md#q13-three-fixes-for-cache-stampede-) · [Q16: cold cache](../../03_interview_mode.md#q16-cold-cache-after-deploy--why-dangerous-) · ❗ [Confusion: "cache miss just means reading DB"](../../04_confusion_resolver.md#-a-cache-miss-just-means-reading-from-db) · ❗ [Confusion: "high hit rate is sufficient"](../../04_confusion_resolver.md#-high-cache-hit-rate-is-sufficient)

### Cache stampede / thundering herd

Scenario: a hot key expires. 1000 concurrent requests all miss → all hit DB → DB dies.

Fixes:
- **Request coalescing**: only one request refetches; others wait for the single in-flight fetch.
- **Staggered TTL**: small random jitter on TTLs so not all keys expire at once.
- **Stale-while-revalidate**: serve stale data for a few seconds while one request refreshes in the background.

> **❓ Why is this called "thundering herd"?**
>
> **The problem, visualized:** picture a herd of 1000 cows sleeping peacefully. Someone opens a gate. All 1000 stampede through at once. That's what your DB looks like when a hot cache key expires: all users simultaneously "miss" and rush the DB. The DB, sized for steady-state load, can't handle the spike — it falls over, which makes the miss *longer*, which keeps the stampede going. This is a **cache-induced incident** pattern familiar to every SRE.
>
> **The three fixes, concretely:**
>
> **1. Request coalescing (also called "singleflight" or "promise-based")** —
> ```python
> # Pseudocode:
> if key in in_flight_requests:
>     wait for the result of that single fetch
> else:
>     register the fetch as in-flight, do it once, broadcast result
> ```
> The Go `singleflight` package does this; Facebook's leases (in the Memcached paper) do this at scale.
>
> **2. TTL jitter** — instead of TTL=300 for everyone, use `TTL = 300 + random(0, 30)`. Keys expire over a 30s window instead of at the same instant. Cheap, effective, almost always combined with other fixes.
>
> **3. Stale-while-revalidate (SWR)** — RFC 5861. Serve the expired value to 999 requests while 1 request refreshes in the background. Users see a 1s-stale value; the DB sees *one* extra query. This is what HTTP's `Cache-Control: stale-while-revalidate=30` does, and what Next.js / Vercel apply by default.
>
> **🔄 Micro reinforcement**:
> 1. *Recall*: under thundering herd, what's the main metric that spikes? *(DB QPS and connection count.)*
> 2. *Recall*: which fix keeps the UI freshness unchanged? *(Request coalescing — others see the single fetch's result.)*
> 3. *What if* you add TTL jitter but skip coalescing, and one celebrity key still expires? *(You still get a stampede on that one key — jitter only helps when many keys would have expired together. Hot-key scenarios need coalescing or replication.)*

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

> **🟢 Beginner → 🟡 Intermediate — concrete stale-read example:**
> 1. **T=0s**: Alice posts a comment. Writes to DB. TTL on the feed cache is 60s.
> 2. **T=1s**: Bob loads the feed. Cache hit — Bob sees the feed WITHOUT Alice's comment.
> 3. **T=60s**: Cache expires.
> 4. **T=61s**: Bob reloads. Now sees Alice's comment.
>
> During T=0 to T=60s, the system is **eventually consistent** — the truth (DB) and the view (cache) disagree. For a comments feed, this is fine. For an account balance, it would be a bug.
>
> **🧠 What if you wanted strong consistency with a cache?** On every write, you'd have to invalidate every copy of the relevant cache key in every region atomically — either give up the cache or pay coordination overhead that defeats the point of having one.

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

---

### 🧭 Guided Deep-Learning Layer

#### 🔄 Gap 1 — Cache-aside vs Read-through
- 🔹 **What they are**: Two read-path strategies. **Cache-aside**: app explicitly checks cache, on miss fetches from DB, populates cache. **Read-through**: cache library transparently fetches from source on miss.
- 🔹 **Why it matters**: Cache-aside is the de-facto default (~80% of real deployments). Read-through hides complexity at the cost of less control.
- 🔹 **Connection**: The "write-through / around / back" trio in this file are about writes; this gap is the missing read-side counterpart.
- 🔹 **When needed**: 🔴 **Important for any interview** — you will be asked "what cache pattern would you use and why?"
- 🔹 **Intuition**: Cache-aside = you as the chef check the fridge, then the pantry. Read-through = you ask a butler who handles both; you never know where the food came from.
- 🔹 **If you go deeper**: Understand the Caffeine / Guava `Loader` pattern (read-through) vs typical Redis usage (cache-aside). Read why most teams prefer cache-aside: visibility, control, no library lock-in.
- 🔹 **Interview hook**: *"Which cache pattern for a read-heavy feed?"* → cache-aside with 5-min TTL + active invalidation on write. Justify: control + debuggability.

---

#### ❌ Gap 2 — Negative Caching
- 🔹 **What it is**: Caching the *absence* of data — e.g., "user 42 doesn't exist" — with a short TTL, so repeated lookups don't hammer the DB.
- 🔹 **Why it matters**: Without it, a scanner hitting nonexistent IDs (scraping, attack, bug) hits your DB millions of times. A 30-second negative cache absorbs it.
- 🔹 **Connection**: The stampede section in this file addresses existing hot keys. Negative caching addresses *nonexistent* keys — a different DoS vector.
- 🔹 **When needed**: 🟡 **Useful for mid-level**, 🔴 **Important for high-traffic public APIs**.
- 🔹 **Intuition**: Your brain remembers "that restaurant is closed on Mondays" so you don't walk there again. Negative caching stores the null.
- 🔹 **If you go deeper**: Set *shorter* TTL than positive entries (so a newly-created entity becomes visible quickly). DNS does this for NXDOMAIN — read RFC 2308.
- 🔹 **Interview hook**: *"Attacker probes random user IDs at 10k QPS. DB dies. Fix?"* → negative caching, rate limit, auth early.

---

#### 🧩 Gap 3 — Cache Partitioning / Sharding (Redis Cluster)
- 🔹 **What it is**: Splitting the keyspace across N Redis nodes. Redis Cluster uses 16384 hash slots; clients hash each key to a slot and route directly.
- 🔹 **Why it matters**: Single-node Redis caps at ~100k QPS and ~100GB RAM. Clusters let you go to 1M+ QPS and TB-scale.
- 🔹 **Connection**: The distributed-cache section in this file is underspecified — this fills in *how* multi-node actually works.
- 🔹 **When needed**: 🔴 **Important for senior interviews** designing high-scale systems.
- 🔹 **Intuition**: Instead of one warehouse, build 10 smaller warehouses keyed by the first letter of the product name. Clients know which warehouse owns which letters.
- 🔹 **If you go deeper**: Learn hash slots (CRC16 mod 16384), MOVED redirect, ASK during resharding, hash tags for multi-key ops `{tag}key`, gossip-based membership.
- 🔹 **Interview hook**: *"Your Redis node hits 90% memory. Options?"* → 1) Increase TTL pressure, 2) Shard across a cluster, 3) Tiered cache with spillover. Senior answer names the tradeoffs.

---

#### 📇 Gap 4 — Secondary Indexes Inside Cache
- 🔹 **What it is**: Additional lookup structures in Redis (e.g., `user:email:foo@bar.com → user_id`) enabling non-primary-key lookups.
- 🔹 **Why it matters**: Redis is primary-key oriented; without secondary indexes, "find user by email" means a DB hit even if you have the user cached.
- 🔹 **Connection**: Fleshes out "a cache is a KV store" — real systems build richer indexing on top.
- 🔹 **When needed**: 🟡 **Useful for mid-level**, 🔴 **Important for senior designs using Redis beyond simple cache**.
- 🔹 **Intuition**: Your library catalog has books indexed by shelf number (primary) but also an author-name index (secondary) pointing to shelf numbers.
- 🔹 **If you go deeper**: Redis sorted sets (`ZADD` for ranked indexes), hashes for structured records, set intersection for multi-tag lookups. Study how Twitter's early tweet-id-by-user timeline used sorted sets.
- 🔹 **Interview hook**: *"Design a leaderboard for 100M users updating in real-time."* → Redis sorted set (`ZADD`) + per-user hash for profile data. Secondary indexing is implicit in the design.

---

#### 🦥 Gap 5 — Lazy Loading
- 🔹 **What it is**: Another name for cache-aside. Data only reaches the cache on first read. Popular/important data stays; rarely-accessed data stays out.
- 🔹 **Why it matters**: Minimizes cache size; self-tuning. The natural default for applications.
- 🔹 **Connection**: Complements the "write-through populates on write" approach — lazy loading populates on read.
- 🔹 **When needed**: 🟡 **Useful to know the terminology** — interviewers use "lazy loading" and "cache-aside" interchangeably.
- 🔹 **Intuition**: You don't pre-fetch every book in the library; you fetch when asked and keep a copy if it might be asked again.
- 🔹 **If you go deeper**: Combine with active invalidation on write — "lazy read, active write". This is basically the default pattern across modern apps.
- 🔹 **Interview hook**: Usually comes up during *"describe your cache strategy"* — use the term confidently.

---

### 🏆 Start here if you have limited time

1. **Cache-aside vs Read-through** — you WILL be asked which pattern.
2. **Cache Partitioning / Redis Cluster** — senior-level scale justification.

Skip negative caching unless you design public APIs. Secondary indexes mostly come up if the interviewer dives into Redis specifics.

---

### 🧭 Suggested Deep Dive Order

1. **Cache-aside vs Read-through** (~30 min; interview-critical).
2. **Redis Cluster hash slots + resharding** (~1h; senior-scale discussions).
3. **Negative caching** (~30 min; specific but widely applicable).
4. **Secondary indexes in cache** (~1h; real-world Redis mastery).
5. **Lazy loading terminology** (~10 min; nomenclature only).
