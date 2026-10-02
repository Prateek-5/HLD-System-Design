# N-Tier Architecture

## A. Intuition First
Separate responsibilities into tiers, deployed independently. Each tier can scale on its own.

Typical 3-tier:
- **Presentation** (UI / API handler)
- **Business logic** (services)
- **Data** (DBs, caches)

## B. Mental Model
Tiers communicate over the network; each tier can be replicated; each can have different scaling characteristics.

## C. Internal Working
- Browser → Load balancer → web/API tier → business tier → DB.
- Between tiers: HTTP, gRPC, or message queues.

## D. Visual Representation
```
[Client] → [Web/API] → [Service] → [DB]
```

## E. Tradeoffs
**Pros**: clean separation, independent scaling, fault isolation.
**Cons**: network hops add latency; operational complexity; more moving parts.

## F. Interview Lens
- "2-tier vs 3-tier vs N-tier?" — know them.
- "Why not put everything in one tier?" — scaling, fault isolation, clean boundaries.

## G. Real-World Mapping
Essentially every modern web app. Microservices are N-tier with finer granularity.

## H. Questions
**Beginner**: What are the tiers of a web app?
**Intermediate**: When do you split a monolith tier?
**Advanced**: What determines the number of tiers?

## I. Mini Design
A basic blog: browser + SPA → API tier → DB. Add cache tier (Redis) when reads dominate.

## J. Cross-Topic Connections
- [Monoliths vs Microservices](monolith-vs-microservices.md), [Load Balancing](../foundations/scaling/load-balancing.md).

## K. Confidence Checklist
- [ ] Can draw 3-tier.

## L. Potential Gaps & Improvements
- Clean architecture / hexagonal architecture — specific-layer patterns.
