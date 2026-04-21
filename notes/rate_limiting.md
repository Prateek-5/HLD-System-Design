# Rate Limiting

> **📎 Prereqs** — If rusty:
> - [`redis.md`](redis.md) — atomic Lua scripts (used for distributed limiters).
> - HTTP status codes (especially 429) + `Retry-After` semantics.

### 🔹 1. What This Topic Actually Is
Capping request rate per key (user, IP, API key, endpoint) over a window. Protects backends from overload and abuse.

### 🔹 2. Why It Exists
- Protect against: abuse, DoS, runaway clients, noisy neighbors.
- Ensure fair-use of shared resources.
- Without it: one bad actor or bug can melt the system.

### 🔹 3. Core Concepts (High Signal)
- **Algorithms**:
  - *Fixed window* — count per [t, t+W). Edge bursts (2× at boundary).
  - *Sliding window log* — timestamps in a log; accurate; memory-heavy.
  - *Sliding window counter* — weighted prev + current windows; approximate; low memory. Default.
  - *Token bucket* — bucket refills at rate R, cap B; burst-friendly. Default at most APIs.
  - *Leaky bucket* — queue drains at fixed rate; smooths output, no burst.
- **Where to enforce**: CDN/WAF → API gateway → service-level. Layered.
- **Distributed correctness**: Redis + atomic Lua script is canonical (atomic refill + consume).
- **Fail policy**: usually **fail-open** (allow + alert) rather than fail-closed (deny everything) when limiter itself is down.
- **Circuit breaker (related, not identical)**: a breaker protects *you* from a sick downstream; a rate limiter protects *downstream* from you.

### 🔹 4. Internal Working (token bucket in Redis)
For each request:
1. Compute current bucket: `tokens = min(cap, tokens + (now - last_refill) * rate)`.
2. If `tokens >= 1`: decrement and allow.
3. Else: reject with 429.
4. Persist `(tokens, now)` atomically via Lua.
Cost: one Redis round trip per request (~1 ms).

**Failure points:** limiter store (Redis) down; race conditions without atomicity; hot key on Redis node; limits bypassed if configured per-IP for shared NAT.

### 🔹 5. Key Tradeoffs
- Token bucket: simple, bursts up to cap — default choice.
- Leaky bucket: smoothest output but no burst — good for fair-share.
- Sliding window counter: approximate, cheap, widely used.
- **Client-side limit** (SDK) reduces edge load but untrusted — needs server enforcement too.
- **Local (in-process) token bucket** avoids network hop but not consistent across instances — can over-limit or under-limit.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. Why rate limit?
2. What's a 429 response?

**Intermediate 🟡**
1. Compare fixed window vs sliding window.
2. How do you implement token bucket in Redis safely?

**Advanced 🔴**
1. Design rate limiter for 100k QPS across 100 regions — consistency vs latency tradeoff.
2. How do you handle the hot-key problem on the limiter itself?

### 🔹 7. Real System Mapping
- **Stripe**: layered rate limits — coarse at gateway + fine per endpoint.
- **Twitter API**: buckets per window (15 min).
- **Cloudflare**: edge rate limiting with anycast.
- **Uber Go ratelimit** (github.com/uber-go/ratelimit): classic leaky-bucket library.
- **Martin Fowler's Circuit Breaker** article: must-read companion.

### 🔹 8. What Most People Miss
- **Rate limit ≠ circuit breaker**. Both often coexist.
- **Fail-open is the right default** for the limiter infrastructure — otherwise a Redis blip takes down your whole platform.
- **Global + local hybrid**: local token bucket sized generously, sync to global via periodic top-up. Reduces Redis QPS drastically.
- **Per-IP limits hurt shared-NAT users** (office networks, mobile carriers). Require auth + per-user limits for precision.
- **429 should include `Retry-After`** header; clients should respect it with jitter.
- **Budget** is also a rate-limit concept at the service level (e.g., cron job → "only burn 10% of my daily budget"). Google SRE does this well.

### 🔹 9. 30-Second Revision
Token bucket in Redis (atomic Lua) is the default distributed limiter. Fixed-window has edge bursts. Sliding-window-counter is cheap approximation. Fail-open when the limiter itself is sick. Tier: edge → gateway → service. Send 429 + Retry-After.

---

## 🔗 Cross-Topic Connections
- **Load Balancing**: LBs often do basic rate limits; gateways do richer ones.
- **Caching**: Redis caches and Redis rate-limits share the same ops burden.
- **Databases**: DB connection pool limits are a form of rate limiting for downstream DB.
- **Circuit Breaker**: complementary — one protects you, one protects them.

---

### Confidence Check
- [ ] Can I implement token bucket pseudocode in 5 lines?
- [ ] Can I design a 3-layer limiting strategy?

### Gaps
- Gossip-based distributed rate limiting (Lyft Envoy's approach).
- ML-based adaptive limits.
- Correctness under Redis failover.
