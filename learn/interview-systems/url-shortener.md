# Case Study — Design a URL Shortener (bit.ly)

## A. Intuition First
Given long URL → return a short alias (`bit.ly/abc123`) that redirects. Deceptively simple: the interesting questions are scale, uniqueness, analytics.

## B. Requirements
**Functional**
- Shorten a URL.
- Redirect from short → long.
- Optional: custom alias, analytics (clicks), expiry.

**Non-functional**
- Very read-heavy (100:1).
- Low latency on redirect (<100 ms).
- Availability high.
- Short codes must be unique, short (6–8 chars).

## C. Estimation
- New URLs: 500M/month → ~200/s write.
- Reads: 100× → 20k/s.
- Storage: 500M × 500B ≈ 250 GB/month. Over 5 years ≈ 15 TB.
- Key space with 7 chars base62 = 62⁷ ≈ 3.5T combinations. Plenty.

## D. High-Level Architecture
```
Client → CDN/Proxy → API (shorten/redirect)
                      ├─ key-gen service
                      ├─ SQL DB (or KV store) for mappings
                      └─ Analytics → Kafka → ClickHouse
```

## E. Deep Dives

### Key generation
Three strategies:
1. **Random base62**: generate 7 random chars; check uniqueness (race). Needs DB uniqueness constraint + retry.
2. **Counter + base62 encode**: sequential counter → base62. Predictable (bad for guessing). Shard counters across N pre-allocated ranges.
3. **Hash (MD5 of long URL)** + truncate: deterministic; same long URL → same short. But collisions possible.

**Pick**: counter-based with pre-allocated ranges per shard. Sub-ms per gen.

### Storage
- Table `urls(short_key PK, long_url, created_at, user_id, expiry)`.
- KV works too (DynamoDB / Cassandra) — but SQL fine at this scale.
- Cache hot redirects in Redis (LRU, 10M entries).

### Redirect path
- Client hits `/{short_key}`.
- Redis lookup → hit: 301/302 to long URL, publish click event.
- Miss: DB lookup, populate cache, redirect.
- p99 target: < 50 ms. Achievable.

### Analytics
- Click event → Kafka → ClickHouse/Druid for aggregation.
- Dashboards served from materialized views.

### 301 vs 302
- 301 permanent → browsers cache → fewer analytics events.
- 302 temporary → every click hits server. Use 302 for accurate counts.

## F. Tradeoffs / Alternatives
- **Collisions** with random: DB unique + retry; rare but real.
- **Custom aliases**: reserve on write via DB constraint.
- **Expiry**: soft-delete + background sweep, or TTL in DB row.
- **GeoDNS**: regional reads; writes central to avoid key duplication.

## G. Interview Lens
- "How do you generate unique keys at 200/s without collisions?"
- "How do you cache?"
- "How do you analyze clicks at scale?"
- "What about abuse / phishing?" — URL safety scanning, blacklist.
- Pitfalls: generating IDs naively (e.g., hashing input); ignoring DB concurrency.

## H. Questions
**Beginner**: How does URL shortening work?
**Intermediate**: Collision avoidance?
**Advanced**:
1. Scale to 1B URLs. How do you shard?
2. Analytics at 100k clicks/s.

## I. Cross-Topic Connections
- [Sharding](../data/sharding.md), [Caching](../foundations/scaling/caching.md), [Consistent Hashing](../data/consistent-hashing.md), [CDN](../foundations/scaling/cdn.md), [Pub-Sub](../architecture/pub-sub.md).

## J. Confidence Checklist
- [ ] Full flow from long → short → redirect.
- [ ] Counter-based key gen.
- [ ] Read/write path in under 3 min.

## K. Potential Gaps & Improvements
- **URL safety / phishing detection** — scan submitted long URLs against blocklists (e.g. Google Safe Browsing) so your shortener doesn't become a malware redirect; expected follow-up in any "what could go wrong" prompt.
- **Rate limiting** — cap how many short URLs an IP or API key can create per window (token-bucket / leaky-bucket) to stop spammers from exhausting your keyspace and quotas.
- **Multi-region active-active** — running writable replicas in several regions for low latency, but it forces you to solve write conflicts and key uniqueness across regions (→ see Interview Lens).
- **Key-generation collisions** — when two nodes pick the same short code; avoid with a central counter, pre-allocated key ranges (KGS, Key Generation Service), or base62-encoded unique IDs.
- **Cache stampede** — many requests miss the cache for the same hot short code at once and hammer the database; mitigate with request coalescing or a short TTL (Time To Live) lock.

**🔧 How to close:** Spin up a one-file shortener and prove base62 codes are collision-free: `python3 -c "import string; a=string.ascii_letters+string.digits; n=125; s=''; \nwhile n: s=a[n%62]+s; n//=62\nprint(s)"` to see ID 125 become a short code, then loop over 1,000,000 sequential IDs and assert the resulting codes are all unique.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔑 Gap 1 — Key Generation Service (KGS) & Collision-Free IDs
- 🔹 **What it is**: A dedicated service that hands out unique short codes — typically by pre-allocating disjoint ID ranges to each app node, or pre-generating a pool of keys, so no two nodes ever pick the same code.
- 🔹 **Why it matters**: The whole product breaks if `bit.ly/abc123` maps to two different long URLs. Interviewers probe uniqueness-at-scale because the naive "random + check DB" approach has a race condition and gets slower as the keyspace fills.
- 🔹 **Connection**: The Deep Dives section picks "counter-based with pre-allocated ranges per shard" — that *is* a KGS. This gap turns that one line into the real design: who owns the counter, how ranges are leased, what happens when a node dies mid-range.
- 🔹 **When needed**: 🟢 **Foundational** — this is the single most-asked part of the URL-shortener interview; you can reason about it now.
- 🔹 **Intuition**: A bakery's "take a number" dispenser. Each counter rips off a strip of 1,000 tickets at a time so two clerks never call the same number — and if a clerk goes home, their leftover tickets are simply wasted, not reused.
- 🔹 **If you go deeper**: Read the *Grokking the System Design Interview* "Designing a URL Shortener" KGS section, then study Twitter Snowflake (timestamp + machine-id + sequence) and Instagram's sharded-ID scheme for two production alternatives.
- 🔹 **Interview hook**: *"Two app servers need unique codes with no coordination per request — how?"* → each server leases a range (say IDs 1M–2M) from a central counter once, then issues base62 codes from its range locally; refill when the range runs low.

---

#### 🛡️ Gap 2 — URL Safety, Phishing Detection & Abuse Prevention
- 🔹 **What it is**: Screening submitted long URLs against blocklists (e.g. Google Safe Browsing) at write time, plus re-checking and rate-limiting so the shortener can't be weaponized to hide malware or phishing links behind a trusted domain.
- 🔹 **Why it matters**: A shortener launders reputation — a scam link looks safe as `yourdomain.co/x9k`. This is the classic "what could go wrong?" follow-up, and missing it signals you only thought about the happy path.
- 🔹 **Connection**: The Interview Lens explicitly lists "What about abuse / phishing? — URL safety scanning, blacklist," and the Gaps bullet names it. This gap makes it concrete: sync check on write vs async re-scan, and what to return when a link later turns malicious.
- 🔹 **When needed**: 🟡 **Mid-level** — expected once your core design is solid; product/security-leaning rounds push harder here.
- 🔹 **Intuition**: A nightclub bouncer. You check IDs at the door (write-time scan), but you also keep walking the floor to throw out people who turned rowdy after entry (async re-scan of already-shortened links).
- 🔹 **If you go deeper**: Integrate the Google Safe Browsing Lookup API into your toy shortener; read about domain-reputation services and how bit.ly publishes its abuse/anti-phishing pipeline.
- 🔹 **Interview hook**: *"A previously-clean link starts serving malware a week after shortening — what happens?"* → async re-scan flags it, the redirect serves an interstitial warning page (or 403) instead of the 302, and the key is quarantined, not deleted.

---

#### 🌍 Gap 3 — Multi-Region Active-Active & Global Key Uniqueness
- 🔹 **What it is**: Running writable copies of the service in multiple regions for low latency worldwide, which forces you to keep short codes globally unique and resolve conflicting writes without a single global lock.
- 🔹 **Why it matters**: A US user and an EU user creating links at the same instant must never collide, yet you can't pay a cross-Atlantic round-trip on every write. This is where the design separates juniors from seniors.
- 🔹 **Connection**: Estimation/Tradeoffs mention GeoDNS with "writes central to avoid key duplication." This gap challenges that compromise: how to go *active-active* (writable everywhere) by partitioning the keyspace per region.
- 🔹 **When needed**: 🔴 **Senior** — genuinely distributed-systems depth; only attempt after KGS and caching feel automatic.
- 🔹 **Intuition**: Two passport offices in different countries issuing IDs from non-overlapping number blocks (US gets 1–5 billion, EU gets 5–10 billion). No phone call needed, and no two passports ever share a number.
- 🔹 **If you go deeper**: Read the DynamoDB Global Tables and the Cassandra multi-DC replication docs; study how region-prefixed or range-partitioned IDs avoid coordination, and what "last-write-wins" vs CRDTs buy you for the rare custom-alias clash.
- 🔹 **Interview hook**: *"How do two regions both accept writes without colliding short codes?"* → give each region a disjoint slice of the ID space (encode region into the prefix or pre-assign ranges) so uniqueness needs zero cross-region coordination.

---

#### 🔥 Gap 4 — Cache Stampede & Hot-Key Protection on the Redirect Path
- 🔹 **What it is**: Preventing a flood of simultaneous cache misses for the *same* viral short code from all hitting the database at once, using request coalescing (single-flight), TTL jitter, or a short lock.
- 🔹 **Why it matters**: A link goes viral, its Redis entry expires, and 50k requests/sec stampede the DB in the same millisecond — potentially toppling it. This is the canonical caching-at-scale failure for a read-heavy system.
- 🔹 **Connection**: The Redirect-path Deep Dive describes "Miss: DB lookup, populate cache," and the Gaps bullet names cache stampede. This gap fixes the gap between those: what stops 50k misses from each doing that DB lookup.
- 🔹 **When needed**: 🟡 **Mid-level** — directly relevant given this system is explicitly "very read-heavy (100:1)."
- 🔹 **Intuition**: A popular restaurant where the kitchen has run out of today's special. Instead of every waiter sprinting to ask the chef, the first waiter asks and the rest wait for that one answer — single-flight.
- 🔹 **If you go deeper**: Implement Go's `singleflight` package or Redis-based locking (`SET key val NX PX`) around the DB fill; read about probabilistic early expiration (XFetch) and adding random jitter to TTLs.
- 🔹 **Interview hook**: *"A short code goes viral and its cache entry expires — what protects the DB?"* → request coalescing so only one request rebuilds the entry while the rest await it, plus TTL jitter so hot keys don't all expire on the same tick.

---

### 🏆 Start here if you have limited time
1. **Key Generation Service (Gap 1)** — it is the heart of every URL-shortener interview; nail uniqueness-at-scale first.
2. **Cache stampede (Gap 4)** — directly defends the 100:1 read-heavy redirect path this design is built around.

---

### 🧭 Suggested Deep Dive Order
1. **Key Generation Service & collision-free IDs** (~1h; foundational, highest interview payoff).
2. **Cache stampede / hot-key protection** (~45 min; protects the read path you already designed).
3. **URL safety & abuse prevention** (~45 min; the standard "what could go wrong" follow-up).
4. **Multi-region active-active** (~1.5h; senior distributed-systems signaling — do last).
