# 🔍 Audit — `caching/`

**Reviewed:** 1 file (~554 lines) · **Lens:** brutal-honest, held to the corpus's own "senior/staff 3000+ word deep dive" claim · **Avg score: 3.8/5**

---

## Verdict in one line
A genuinely strong single deep-dive that gets the usually-botched marquee concepts right (write-through vs write-behind, the double-delete race, stampede mitigations) — dragged down by one **wrong-and-repeated** claim about hit rates, a **misordered latency table**, and a conspicuous **absence of negative caching and Redis-vs-Memcached specifics** that a true staff-level treatment would not skip.

## Per-file scores (out of 5)

| File | Score | One-liner |
|---|---|---|
| `caching-hierarchy.md` | **3.8** | Accurate on the parts that bite; wrong on "90% hit rate"; missing negative caching + Redis/Memcached internals; padded with 5 overlapping summary sections |

**Sub-scores for `caching-hierarchy.md`:** accuracy **3.8**, depth-vs-3000-word-claim **4.2** (it genuinely is long and substantive), interview usefulness **4.3**, clarity/structure **3.8**, originality/signal-to-noise **3.2**.

## Concrete errors found (must-fix)

- 🚩 **WRONG — "90% hit rate is barely faster than no cache."** Line 66: *"A cache with 99% hit rate is fast on average. A cache with 90% hit rate is *barely faster than no cache* — because the 10% miss path probably checks the cache first, then falls through to the source."* This is false. The miss path only adds the *cache-check* overhead (sub-millisecond), not the full miss cost on every request. With hit=1ms, miss=50ms, a 90% hit rate gives avg ≈ 0.9×1 + 0.1×(1+50) ≈ 6ms vs 50ms uncached — **~8x faster, not "barely faster."** The correct staff point is about *origin load* (90% hit = origin sees 10% of traffic = 10x reduction), not user latency. The doc itself states this correctly later (line 270: "A 90% hit rate means the source sees 10% of traffic"), which **contradicts** line 66. **Repeated 3x** as a headline claim: line 66, line 316 ("a 90% hit rate is barely worth the complexity"), line 534 ("99% hit rate >> 90% hit rate, by orders of magnitude").

- 🚩 **Latency table is out of order**, undermining the whole "hierarchy" framing it's selling. Lines 92–99 list `~10 ms Database (warm)` and `~50 ms Database (cold)` *above* `~5 ms CDN edge` and `~50–200 ms Origin cross-continent`. A table explicitly captioned "Latency / Layer" and meant to teach the ascending hierarchy should be monotonic. CDN edge (~5ms) belongs above the 10–50ms DB rows.

- 🚩 **Negative caching is entirely absent** — and it's a core caching concept (explicitly a fact-check hint). There is no mention of caching nulls/404s/"not found" results to stop repeated misses hammering the source, nor the related **cache penetration** attack (flooding requests for keys that don't exist to bypass the cache). For a doc that dwells on stampedes and cold-start cascades, omitting negative caching is a real depth gap, not a nitpick.

- 🚩 **Redis-vs-Memcached specifics are missing** (also a fact-check hint). Memcached appears only as 2003 history (line 45); Redis as 2009 (line 48). Nowhere does the doc contrast the two on the points interviews actually probe: Memcached's **multi-threaded** model + slab allocation vs Redis's **single-threaded event loop** + rich data types, persistence (AOF/RDB), and differing eviction behavior. "Senior/staff deep dive" should not leave this on the table.

- 🚩 **`redis.delete_pattern(...)` presented as a primitive** (line 425). There is no native `DELETE BY PATTERN` in Redis — pattern deletion requires `SCAN`+`DEL` (or a Lua script), and the `KEYS`-style glob is a well-known production foot-gun (O(N) blocking scan on a single-threaded server). Presenting it as a one-liner alongside real commands like `redis.set(... ex=300)` reads as fact and would mislead.

- 🚩 **LFU "Best for: Stable workloads" is too rosy** (line 153). Plain LFU's classic failure is **cache pollution**: keys that were historically hot but are now cold never get evicted because their frequency counter stayed high. This is precisely why Redis's LFU implementation uses a probabilistic counter *with decay* (`lfu-decay-time`) and why W-TinyLFU adds an admission filter. The table flags none of this — it's the exact tradeoff a staff candidate is expected to surface.

## Genuine strengths (keep)

- **Write-through vs write-behind is correct and not conflated** (lines 128–138) — the single most common error the hints warn about. Write-through = synchronous to source; write-behind/write-back = async flush with explicit data-loss caveat ("data loss if cache fails before flush"). Clean.
- **The double-delete / stale-write race is nailed** (lines 188, 253–254): *"another reader can repopulate stale data between source write and cache delete"* with the correct mitigations (delete before AND after, or versioned keys). This is the bug most engineers ship; explaining it with a concrete billing-incident scenario is genuinely staff-level.
- **Stampede section is accurate and complete** (lines 170–180): names probabilistic early refresh, single-flight/mutex, stale-while-revalidate, and soft/hard TTL — and the worked `random.random() < (1 - ttl/300)**2` example (lines 459–460) is a faithful sketch of the XFetch-style probabilistic refresh.
- **Eviction table is largely correct**: W-TinyLFU↔Caffeine, ARC/2Q as adaptive recency+frequency, TLRU as LRU+TTL. Redis `noeviction` default (line 159) is correct, as are `allkeys-lru`/`volatile-lru`.
- **Historical dates check out**: Memcached 2003, Redis 2009, Akamai 1998.
- **Invalidation taxonomy (lines 182–193)** correctly escalates TTL → write-through → explicit-delete-with-race → versioned keys → pub/sub → CDC, and is honest that "most cache invalidation bugs are race conditions in option 3."
- **Cross-tenant key-collision** as a security incident (lines 231, 256–257) and the "treat the cache as untrusted state" instinct are high-signal.
- The worked multi-tier product-page example (lines 358–515) is concrete, internally consistent on tiers/TTLs, and interview-grade.

## 🛠️ Improvement plan (tailored to this directory)

**Theme: a strong file that's one wrong claim, two missing topics, and a round of de-padding away from a 4.5.**

1. **Kill the "90% hit rate is barely faster" claim** in all three places (lines 66, 316, 534). Replace with the correct framing the doc already uses at line 270: separate *user latency* (still much faster at 90%) from *origin-load reduction* (10x at 90%, 100x at 99%) — the latter is where the order-of-magnitude argument actually lives.
2. **Reorder the latency table** (lines 92–99) so it's strictly monotonic — move CDN edge above the database rows — or split it into "on-host hierarchy" vs "network/edge hierarchy" so the non-monotonic rows are explained rather than wrong.
3. **Add a negative-caching section.** Cache misses for nonexistent keys (null/404), short TTLs for negatives, and the cache-penetration attack + Bloom-filter/empty-sentinel defenses. This file's stampede/cold-start focus makes the omission glaring.
4. **Add a real Redis-vs-Memcached comparison.** Single-threaded event loop vs multi-threaded + slab allocation; data types; persistence (AOF/RDB); cluster/replication differences; when Memcached is still the right call (pure ephemeral LRU at huge scale). It's the most-asked caching interview contrast and is currently absent.
5. **Fix `redis.delete_pattern`** (line 425): show `SCAN`+`DEL` or a tagged/versioned-key invalidation instead, and explicitly warn against `KEYS *` in production. And nuance the LFU row (line 153) with the cache-pollution/decay caveat.
6. **De-pad (~25–30%).** Five sections — "Core Mental Models," "What Junior Engineers Miss," "What Senior Engineers Notice," "20% Knowledge," "Final Mental Model" — restate the same ~8 points (hit rate, invalidation = consistency, always-have-fallback, cap value size, versioned keys, stampedes-are-the-rule, TTL-per-data-type). Collapse into one "Key takeaways" block. Roughly 30–35% of the non-worked-example prose is restatement.
7. **This is a one-file directory.** A "caching hierarchy" doc this broad would be better as 2–3 focused files (the hierarchy/patterns deep dive; a Redis/Memcached operational file; an invalidation-and-consistency file) so each can go deep without the summary-section padding doing the page-count work.
