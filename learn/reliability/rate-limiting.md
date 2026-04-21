# Rate Limiting — Protecting Systems from Themselves and Abuse

## A. Intuition First
Cap how many requests a user (or key, IP, service) can make per unit time. Protects backends from overload, abuse, and runaway bugs.

## B. Mental Model
Five common algorithms:
| Algorithm | How | Pros | Cons |
|---|---|---|---|
| **Token bucket** | Bucket refills tokens at rate R, caps at B. Each req takes 1 token. | Simple, bursts allowed up to B | — |
| **Leaky bucket** | Queue drains at fixed rate. Over capacity → reject. | Smooth output | No bursts |
| **Fixed window** | Count per key in [t, t+W). | Simple | Edge bursts (2× at boundary) |
| **Sliding window log** | Store timestamps, count within last W. | Accurate | Memory-heavy |
| **Sliding window counter** | Approximate via weighted prev+current windows. | Low memory, low error | Approx |

## C. Internal Working (token bucket in Redis)
- Key: `rate:{user_id}`.
- Atomic Lua script: refill tokens = `min(B, tokens + (now - last) * R)`; if `tokens >= 1`, consume 1 and allow; else reject.

## D. Visual Representation
```
Token bucket:   Tokens refill →  [●●●●░░░░░░] cap=10, rate=1/s
                Request arrives → consume 1 or reject
```

## E. Tradeoffs
- Where to enforce: LB / API gateway (first line), per-service (fine-grained), per-endpoint.
- Per-user vs per-IP (IP bans shared NAT users; user requires auth).
- Distributed limiter needs shared store (Redis).

### 🪜 Idempotency — rate limiting's safety partner

Rate-limited APIs often return `429 Too Many Requests`. Clients retry. Without idempotency, retries re-apply side effects (double-charge!).

**Idempotency key flow:**
1. Client generates a UUID → `Idempotency-Key: abc123` header.
2. Server checks Redis: `SET idem:abc123 NX EX 86400 <response>` (atomic).
3. First call: runs the operation, stores the response.
4. Retry with same key: Redis hit → return stored response without re-running.
5. TTL expires → key reusable (typically 24h).

**Where to store**: Redis with `SETNX` or a DB unique constraint.
**Scope**: per-user + per-endpoint so different APIs don't collide.

> **🔎 Quick Check** — Client gets `429`, retries with same Idempotency-Key. Operation already succeeded on the first attempt. What does the server return?
> **🎯 Recall** — The stored success response from Redis. Retry is safe; no double-effect.

## F. Interview Lens
- "Design a rate limiter for 100k QPS."
- "Token bucket vs sliding window?"
- "How to avoid a single Redis bottleneck?" — shard by hash of key; or use local token buckets that sync periodically.
- Pitfalls: fixed window 2× at boundary; not persisting across pod restarts.

## G. Real-World Mapping
Stripe, Twitter, Cloudflare — tiered rate limits (global + per-key + per-endpoint).

## H. Questions
**Beginner**: Why rate limit?
**Intermediate**: Compare fixed and sliding window.
**Advanced**:
1. Design a rate limiter for 100 services × 1M users.
2. Handle distributed limit correctness vs performance.

## I. Mini Design
API gateway rate limit: 100 req/s per API key. Token bucket in Redis via Lua. If Redis unavailable, fail open (allow) with metric alert. DoS protection below at WAF layer.

## J. Cross-Topic Connections
- [API Gateway](../architecture/api-gateway.md), [Caching](../foundations/scaling/caching.md), [Circuit Breaker](circuit-breaker.md).

## K. Confidence Checklist
- [ ] Can implement token bucket in pseudocode.
- [ ] Knows fail-open vs fail-closed tradeoff.

## L. Potential Gaps & Improvements
- Distributed token bucket via gossip.
- Weighted limits by plan/tier.

---

### 🧭 Guided Deep-Learning Layer

#### 🗣️ Gap 1 — Distributed Token Bucket via Gossip
- 🔹 **What it is**: Each node maintains a local token bucket + gossips its consumption to peers; global limit is enforced approximately without central Redis dependency.
- 🔹 **Why it matters**: Central Redis limiter is a SPOF and latency bottleneck at 1M+ QPS across regions. Gossip-based distributed limiting scales and tolerates partitions.
- 🔹 **Connection**: This file's "Redis + Lua" approach is centralized. Gossip-based is the next tier for planet-scale.
- 🔹 **When needed**: 🔴 **Important for senior infra interviews** at planet-scale shops (Envoy, Istio, Lyft-scale).
- 🔹 **Intuition**: Instead of everyone asking the mayor for a permit, each neighborhood tracks its own permits and periodically tells neighbors "I've used X". Slight over-limit is accepted; no central SPOF.
- 🔹 **If you go deeper**: Read Lyft's Envoy global rate limit service + rate limit quota service (RLQS). Understand the precision-latency-availability tradeoff: gossip = less precise but no central dependency.
- 🔹 **Interview hook**: *"At 10M QPS globally, how do you rate-limit without a central limiter?"* → gossip-based distributed token bucket.

---

#### 🎫 Gap 2 — Weighted Limits by Plan/Tier
- 🔹 **What it is**: Different rate limits per user tier (free vs pro vs enterprise), endpoint priority (read vs write), or time-of-day.
- 🔹 **Why it matters**: Real SaaS products monetize rate limits. Simplistic flat limits leave money on the table and annoy power users.
- 🔹 **Connection**: This file treats rate limits as uniform. Real products multiply per-plan, per-endpoint, per-tenant.
- 🔹 **When needed**: 🟡 **Useful for mid-level**, 🔴 **Important for SaaS product design interviews**.
- 🔹 **Intuition**: Airline seats — economy, business, first. Same airplane, different quotas on WiFi, drinks, legroom. Rate limits work the same way.
- 🔹 **If you go deeper**: Study Stripe's tiered limit architecture — limits stored in user plan metadata, looked up at authn time, applied at gateway. Think about fair-share within a tenant's quota.
- 🔹 **Interview hook**: *"Design rate limits for a SaaS with free/pro/enterprise tiers."* → tier-aware bucket capacity + per-endpoint priorities.

---

### 🏆 Start here if you have limited time

1. **Weighted limits by tier** — directly applicable to most product interviews.
2. **Distributed gossip limiter** — senior-infra depth.

---

### 🧭 Suggested Deep Dive Order

1. **Weighted / tiered limits** (~45 min; widely applicable).
2. **Distributed gossip token bucket (Envoy style)** (~1h; senior-infra signaling).
