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
- **Clean Architecture / Hexagonal Architecture (Ports & Adapters)** — layering styles where business logic sits in the center and databases/UIs plug in at the edges; care because it makes tiers swappable and testable without rewiring core code.
- **Dependency Inversion Principle (DIP)** — higher tiers depend on interfaces, not concrete lower tiers; matters because it lets you mock the data tier in tests and swap implementations.
- **Tier vs. Layer distinction** — a "layer" is a logical grouping of code while a "tier" is a physical/deployable boundary; knowing this avoids confusing a 3-layer codebase with a 3-tier deployment.
- **Horizontal scaling of the middle tier** — running many stateless app-tier instances behind a load balancer; key for handling traffic growth without scaling the database.
- **Session affinity vs. stateless app tier** — whether requests stick to one server or any server can serve any user; matters because shared/external session state is what lets the app tier scale freely.

**🔧 How to close:** Spin up a 3-tier stack locally with `docker-compose up` using three services (an `nginx` web tier, a small `node`/`flask` app tier, and a `postgres` data tier), then scale the app tier with `docker-compose up --scale app=3` and watch nginx round-robin requests across the instances.
