# Edge Computing & CDNs

> *"Latency is a property of physics. Light travels 200 km per millisecond through fiber. To shave latency below physics, you don't make the network faster — you move the work closer. Edge computing is the engineering response to the speed of light."*

---

## Topic Overview

A CDN (Content Delivery Network) moves static content close to users. Edge computing extends the idea: run *application logic* close to users, not just serve files. Cloudflare Workers, AWS Lambda@Edge, Vercel Edge Functions, Fastly Compute@Edge — each is a different take on "execute code at hundreds of locations worldwide, milliseconds from any user."

The technical challenge is profound. Edge runtimes have constraints that traditional servers don't: memory caps, time limits, no persistent disk, restricted runtimes (no native code, no full Node.js). The benefit is dramatic: a request that would take 200ms cross-continent can complete in 5ms at the edge.

This is the topic that bridges networking, distributed systems, and architecture. Edge computing isn't "the cloud, but global" — it's a different deployment model with different design constraints. Understanding when to use it (and when not to) is becoming a routine architectural decision.

---

## Intuition Before Definitions

Imagine a global pizza chain.

The naive setup: one giant kitchen in Chicago. Anyone in the world ordering pizza must have it shipped from Chicago. Pizza arrives cold; delivery takes hours. Customers in Sydney leave.

The CDN setup: 200 distribution kitchens worldwide, each storing pre-made pizzas (cached content). When you order, the nearest kitchen ships within minutes. Pizzas are warm; customers happy.

The edge-compute setup: 200 kitchens, each capable of *making* pizzas (not just shipping). They have raw ingredients (small dataset), recipe (your code), oven (compute). When you order a custom pizza, the nearest kitchen makes it from scratch. Faster than shipping from Chicago; capable of customization.

The constraints: each kitchen is small. Limited storage (no walk-in freezer). Limited menu (can't make every dish). Some ingredients (like fresh truffles) only exist in Chicago — orders requiring them go back to HQ.

That's edge computing. The kitchens are edge nodes. The recipe is your code. The ingredient constraints are real (no full database at the edge). The latency win is real (closer = faster). The architecture demands designing within the constraints.

---

## Historical Evolution

**Era 1 — Akamai and the CDN birth.**
1998. Akamai pioneers CDN. Static asset caching at edge. Massive performance wins for media-heavy sites. Industry-changing.

**Era 2 — CDN expansion.**
2000s-2010s. Cloudflare (2010), CloudFront (2008), Fastly (2011). Cheaper, more programmable, more services beyond caching (DDoS protection, WAF, etc.).

**Era 3 — Edge programmability.**
~2015. Cloudflare Workers (2017), Lambda@Edge (2017). Run code at the edge, not just serve cached content.

**Era 4 — Edge-native frameworks.**
~2020. Vercel, Netlify, Deno Deploy. Frameworks designed for edge deployment from day one. SSR, ISR, edge-rendered React.

**Era 5 — Edge databases.**
2022+. Cloudflare D1, Turso, Fauna. Moving state closer to users. Solves the "edge compute but central data" latency problem for many workloads.

**Era 6 — Convergence.**
The line between "CDN" and "compute platform" blurs. Cloud providers compete on edge presence; edge providers add database services. The architectural question becomes "how much of my application can run at the edge?"

The pattern: each generation moved more capability to the edge. Static → dynamic compute → state. Each step expanded what's possible; each constrained what fits.

---

## Core Mental Models

**1. Latency is bounded by light speed.**
Frankfurt to Sydney is ~16,000 km. Round trip at light speed in fiber: 160ms. Real networks add 30-50%. You cannot beat this with software. Edge moves the endpoint.

**2. The edge is geographically distributed.**
Hundreds to thousands of points-of-presence (PoPs) globally. Each PoP serves users in its region. The architecture must work in this distributed model.

**3. Edge runtimes are constrained.**
Memory limits (often 128MB). Time limits (often 50ms). No filesystem. No native code (V8 isolates, not full Node.js). Designs that depend on these don't work at the edge.

**4. Caching is the basic edge primitive.**
Even with compute at the edge, the highest-leverage edge work is *caching*. Avoiding origin trips altogether is faster than any compute.

**5. State at the edge is hard.**
The edge runs in many places simultaneously. State coherence across PoPs is a distributed-systems problem. Most edge architectures push state to a central origin or use eventually-consistent edge databases.

---

## Deep Technical Explanation

### CDN basics

A CDN consists of:
- **Origin**: your servers (where content originates).
- **Edge nodes (PoPs)**: distributed worldwide. Each caches content.
- **Routing**: DNS or anycast directs users to the nearest PoP.

Cache headers (`Cache-Control`, `ETag`, `Last-Modified`) drive behavior:
- `Cache-Control: max-age=3600`: cache for 1 hour.
- `Cache-Control: s-maxage=86400`: shared cache (CDN) caches for 1 day, even if browser cache is shorter.
- `Cache-Control: no-store`: never cache.
- `ETag` or `Last-Modified`: enable revalidation; CDN re-checks origin only if content might have changed.

Cache hierarchies (origin → regional cache → edge cache) reduce origin load. Tiered caching: edge misses go to a regional cache; regional misses go to origin. A small fraction of requests reach origin even at low cache hit rates.

### Cache key design

By default, the cache key is the URL. But:
- **Query parameters**: include or strip? Stripping unifies cache; including respects parameters.
- **Headers**: `Accept-Language`, `Accept-Encoding`, `User-Agent`. The `Vary` header tells the cache which headers to consider in the key.
- **Cookies**: typically excluded; including cookies often means zero cache hits.

Misconfigured cache keys are a common source of either zero hit rate (everything is unique) or cross-user data leakage (different users see each other's cached content).

### Cache invalidation

The hard part. Options:
- **TTL-based**: items expire. Cheap; staleness up to TTL.
- **Purge by URL**: explicit invalidation. Eventually consistent across PoPs (seconds to minutes).
- **Surrogate keys (Fastly)**: tag content with logical keys; purge by tag. "Invalidate all pages mentioning product 12345" in one call.
- **Stale-while-revalidate**: serve stale; refresh in background.

CDN purges are eventually consistent globally. A purge issued at 10:00 may take 30 seconds to propagate across all PoPs. For some use cases (e-commerce inventory), this matters.

### Edge compute platforms

**Cloudflare Workers**: V8 isolates per request. Sub-millisecond cold starts. JavaScript/TypeScript/WASM. 50ms CPU time per request (paid tiers higher). Global by default — your worker runs in 300+ PoPs.

**AWS Lambda@Edge**: Node.js or Python runtime. Higher cold-start latency than Workers (V8 isolates) but more compute time. Tighter integration with AWS services.

**Vercel Edge Functions / Netlify Edge**: similar V8-isolate model. Tightly integrated with their hosting platforms.

**Fastly Compute@Edge**: WebAssembly-based. Very fast cold starts. Polyglot via WASM.

The runtime model matters:
- **V8 isolates** (Workers, Vercel): instant cold starts, JS/TS/WASM only, restricted APIs.
- **Container-based** (Lambda@Edge): full Node/Python, slower cold starts, more memory.
- **WASM-based** (Fastly): fast, polyglot, requires WASM compilation toolchain.

### Use cases

**Personalization at the edge.**
Detect user (cookie, header), serve personalized content from cache. Avoid trips to origin for personalization decisions.

**A/B testing.**
Bucket users at the edge; route to A or B variants. Faster than client-side bucketing; works for SEO-relevant content.

**Authentication.**
Verify JWT, session cookie at the edge. Reject unauthenticated requests before they reach origin. Reduces origin load.

**Geo-routing and compliance.**
Detect user country; route to appropriate region (GDPR for EU users, etc.).

**Rate limiting.**
Per-IP rate limits enforced at edge. Far cheaper than origin-side rate limiting.

**API aggregation.**
Combine multiple backend calls into one edge response. Reduces client round-trips.

**SSR (server-side rendering).**
Render React/Vue at the edge. Faster TTFB than origin-side rendering for global users.

**Image optimization.**
Resize, format-convert, optimize images at edge based on device. Imgix and Cloudflare Images do this.

### What doesn't fit at the edge

**Heavy compute.** Time limits prevent long-running work.

**Large datasets.** Memory limits prevent loading big tables.

**Stateful long sessions.** Edge nodes are stateless and short-lived.

**Strict consistency.** Multi-PoP coordination is expensive.

**Complex database queries.** Most state lives at origin; complex queries need to round-trip there.

The architecture: edge handles the request lifecycle (auth, routing, simple decisions, caching), origin handles the heavy lifting.

### State at the edge

Approaches:
- **Read-only from origin.** Cache or replicate config/data to edge. Stale by some bounded amount.
- **Edge KV stores** (Cloudflare KV, Workers Durable Objects). Eventually consistent, low-latency reads.
- **Edge databases** (Cloudflare D1, Turso, libSQL). SQLite-based, replicated across PoPs.
- **Strong-consistency origin**: fall through to origin for any state-changing operation.

The pattern: reads at edge with TTL or eventual consistency; writes at origin with read replicas at edge. State is the hardest edge architecture decision.

### Anycast routing

Most CDNs use anycast: the same IP address advertised from many PoPs; the network routes the user to the closest one (BGP-determined). The user does no DNS magic; they connect to "1.1.1.1" and reach the nearest Cloudflare PoP.

Properties:
- **Failover is automatic**: if a PoP fails, traffic reroutes to the next-nearest.
- **No DNS TTL issues**: routing is at the network layer.
- **Geo-precision varies**: BGP routes by network topology, not strictly by physical distance.

### Latency math

Why edge matters:

| Scenario | Latency |
|---|---|
| Local LAN | <1 ms |
| Same data center | 1-5 ms |
| Same region | 10-30 ms |
| Cross-continent | 70-150 ms |
| Cross-globe | 150-300 ms |
| Geosynchronous satellite | 600+ ms |

A user in Australia hitting a US-only origin: ~200ms RTT *just* for one round trip. With TLS handshake (multiple RTTs) plus TCP handshake plus actual request: 800ms before first byte returned.

A CDN PoP in Sydney: maybe 5-10ms RTT. The same request: tens of ms total. The user-perceived difference is dramatic.

---

## Real Engineering Analogies

**The library system.**
Public libraries don't keep one giant collection — they have branch libraries with the most-popular books, and the central library for everything else. Books popular at one branch are stocked there; rare books are requested from central. The hierarchy is exactly CDN architecture.

**The franchise model.**
McDonald's doesn't ship every burger from one kitchen. Every restaurant is an "edge node" — local production, central recipe (code). The corporation provides standardization (configuration). The local restaurant adapts to local conditions (regional menu items, local sourcing). Edge computing replicates this.

---

## Production Engineering Perspective

What goes wrong:

- **The cache key explosion.** Cache key includes session cookies. Every user has a unique session. Hit rate near zero. Origin load identical to no-CDN.
- **The PII leak via cache.** Cache key didn't account for `Authorization` header. User A's authenticated content cached; served to User B's request that hit the same key. Catastrophic.
- **The purge that didn't.** Marketing pushed an update, requested a purge. Purge took 90 seconds globally. Some users saw old content for 90 seconds. Edge case revealed at launch.
- **The edge runtime constraint surprise.** Code worked locally; deployed to Workers; failed because it imported a library using Node's `fs` (not available in V8 isolates). Lesson: edge runtimes are constrained; test against the actual runtime.
- **The cold start at the edge.** Even Workers' "instant" cold starts add 5-50ms for V8 initialization on first hit at a PoP. For very latency-sensitive apps, this matters.
- **The state-at-edge consistency bug.** Edge KV is eventually consistent. Code assumed strong consistency. Race conditions across PoPs caused incorrect behavior.
- **The edge-deploy cost surprise.** Moving heavy compute to edge: per-request CPU billed. Higher than origin. Bills triple. Not all workloads are economic at edge.

The senior engineer's habits:
- **Plan cache keys** carefully; minimize variation.
- **Use surrogate keys** for tag-based purging.
- **Size content for edge runtimes** explicitly.
- **Measure cold-start and warm-path latency**.
- **Handle eventual consistency at edge state**.
- **Cost-model edge usage**; not always cheaper than origin.

---

## Failure Scenarios

**Scenario 1 — The cache poisoning.**
Cache key didn't include `Accept-Language`. User in France requested page; got German version cached. All subsequent users hit that PoP got German content. Recovery: purge; add `Vary: Accept-Language`.

**Scenario 2 — The Black Friday purge.**
Pricing page caches for 5 minutes. Black Friday sale starts at midnight. Purge issued at 23:59:30. Most PoPs purged by 23:59:45. A few stragglers kept old prices for another minute. Customers complain. Lesson: pre-warm critical pages; explicit cache strategies for time-sensitive content.

**Scenario 3 — The Worker timeout cascade.**
Worker calls origin; origin is slow; Worker times out at 50ms (CPU limit). User sees error. Origin completes the work but no one's waiting. Database has been updated but client is told it failed. Idempotency saves the day; client retries; double-charged otherwise.

**Scenario 4 — The edge config rollout disaster.**
Engineer pushes new edge config. Some PoPs receive it in seconds; others in 30 seconds. During those 30s, users see inconsistent behavior. A bug in the new config crashes 1% of Workers. Mitigation: progressive rollout of edge config; canary PoPs; SLO-monitoring auto-rollback.

**Scenario 5 — The edge compute cost shock.**
Team moves CPU-heavy logic to edge for latency. Bill triples — edge compute is 5× origin compute on a per-CPU-second basis. Latency improves but ROI is negative for non-customer-facing workloads. Lesson: edge for latency-critical paths; origin for batch/heavy work.

---

## Performance Perspective

- **CDN cache hit**: 5-50ms (PoP to user); zero origin work.
- **CDN cache miss + origin trip**: 100-300ms typical.
- **Edge compute**: 5-50ms warm path; cold start adds 5-50ms.
- **Origin trip**: dominated by inter-continent latency.
- **Cache hit ratio**: aim for 90%+; below 70% indicates configuration problems.

---

## Scaling Perspective

- **Vertical (per PoP)**: limited; PoPs are small relative to origin.
- **Horizontal (PoPs)**: hundreds to thousands of PoPs globally; auto-scales with provider.
- **Geographic**: latency wins from proximity; cost wins from PoP density.
- **At hyperscale**: own your CDN (Netflix's Open Connect; large social networks).

---

## Cross-Domain Connections

- **Caching hierarchy**: CDN is the topmost layer of the cache hierarchy. (See [caching-hierarchy.md](../caching/caching-hierarchy.md).)
- **Load balancing**: Anycast routes users to PoPs; PoPs load-balance to origins. (See [load-balancing-strategies.md](./load-balancing-strategies.md).)
- **CAP / consistency**: edge state is eventually consistent; designs must accommodate. (See [cap-consistency-and-replication.md](../distributed-systems/cap-consistency-and-replication.md).)
- **API design**: edge-aware APIs distinguish cacheable from uncacheable; HTTP semantics matter. (See [api-design-rest-vs-grpc.md](../architecture-patterns/api-design-rest-vs-grpc.md).)
- **V8 internals**: Workers are V8 isolates; understanding V8 helps optimize edge code. (See [v8-internals-and-hidden-classes.md](../js-runtime/v8-internals-and-hidden-classes.md).)
- **Capacity planning**: edge moves capacity from origin to provider. (See [auto-scaling-and-capacity-planning.md](./auto-scaling-and-capacity-planning.md).)

The unifying observation: **edge computing is the geographic dimension of distributed systems. Every other distributed-systems trade-off (consistency, latency, replication, partitioning) gets sharper at edge scale because the network distances are fundamental.**

---

## Real Production Scenarios

- **Cloudflare's global network**: 300+ PoPs; canonical reference for CDN at scale.
- **Netflix Open Connect**: their custom CDN appliances co-located with ISPs. Massive bandwidth savings.
- **Akamai's tradition**: longest-running large CDN; mainstream client base.
- **Vercel's framework integration**: Next.js + edge runtime, deeply integrated.
- **Cloudflare D1 (SQLite at edge)**: documented case studies of distributed SQLite for edge state.
- **The 2021 Fastly outage**: a config bug took down a significant fraction of the internet briefly. Postmortem available.

---

## What Junior Engineers Usually Miss

- That **edge runtimes are constrained** (memory, time, APIs).
- That **cache keys must be designed**.
- That **purges are eventually consistent globally**.
- That **edge state has weak consistency** by default.
- That **edge compute costs more per CPU-second** than origin.
- That **`Vary` header** controls cache key variation.
- That **anycast routing** is the typical CDN dispatch mechanism.
- That **cold starts exist** even at edge (V8 isolate init).

---

## What Senior Engineers Instinctively Notice

- They **design cache keys** explicitly.
- They **use surrogate keys** for batch invalidation.
- They **size content for edge runtimes** before deploying.
- They **measure latency at edge vs origin** continuously.
- They **plan for eventual consistency** of edge state.
- They **cost-model edge usage** vs origin.
- They **distinguish what fits at edge** from what doesn't.
- They **monitor cache hit rate** as a primary metric.

---

## Interview Perspective

What gets tested:

1. **"What's a CDN?"** Tests basic literacy.
2. **"What's edge computing?"** Compute at PoPs; differs from CDN by running code, not just serving cache.
3. **"How do you design a cache key?"** Avoid uniqueness explosion; use `Vary`; include only what matters.
4. **"What can't run at the edge?"** Long compute; full DBs; large memory; native code.
5. **"How does state work at edge?"** Eventually consistent; KV stores; or fall through to origin.
6. **"Anycast vs DNS?"** Anycast for failover and latency; DNS for routing decisions.
7. **"When wouldn't you use edge?"** Heavy compute; not latency-sensitive; cost ineffective.

Common traps:
- Believing edge is always faster.
- Not knowing about runtime constraints.
- Treating purge as instantaneous.

---

## 20% Knowledge Giving 80% Understanding

1. **Latency is bounded by light speed; edge moves the endpoint closer.**
2. **CDN = static caching; edge compute = code at PoPs.**
3. **Cache keys must avoid uniqueness explosion.**
4. **Edge runtimes are constrained** (memory, time, APIs).
5. **Edge state is eventually consistent.**
6. **Surrogate keys** for batch purging.
7. **Anycast routing** for automatic failover.
8. **Cold starts exist** at edge but are fast (V8 isolates).
9. **Edge compute costs more** per CPU-second than origin.
10. **Tiered caching** (edge → regional → origin) reduces origin load.

---

## Final Mental Model

> **Edge computing is geography weaponized for latency. The constraints (small runtime, weak state) are the price of being everywhere. The benefit (5ms instead of 200ms) is worth it for user-facing paths and only sometimes worth it for everything else.**

The senior architect designing for global scale doesn't put everything at the edge — they put the *latency-critical, cacheable, lightweight* logic there, and leave the heavy lifting at origin. Auth checks, geo-routing, A/B bucketing, image optimization, simple personalization: edge. Complex queries, large transactions, ML inference: origin. The architecture matches the constraints.

Teams that "go all-in on edge" without considering constraints discover them painfully — runtime limits, state coherence, cost models. Teams that ignore the edge entirely leave latency on the table for global users. The mature middle is using edge where it pays and origin where it doesn't.

That's edge computing. That's CDNs. That's the geographic axis of system design — the one that turns "the internet is global, but my server is in Virginia" into "users in Singapore see 5ms responses too."
