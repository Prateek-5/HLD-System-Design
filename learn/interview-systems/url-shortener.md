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
- URL safety (phishing detection).
- Rate limiting abusers.
- Multi-region active-active complication.
