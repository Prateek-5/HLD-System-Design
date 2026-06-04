# Microservices vs Monolith

> *"The microservices vs monolith debate is the most exhausting argument in software architecture, partly because both sides are right and partly because the question is wrong. The real question is: where do the boundaries between services give you more than they cost you?"*

---

## Topic Overview

A monolith is a single deployable unit containing all of your application's code. A microservice is one of many small, independently-deployable services that together make up the application. The architectural choice between them shapes everything: team structure, deployment cadence, latency characteristics, debugging difficulty, operational complexity, and the kinds of failures you encounter.

The conversation has cycled through fashion. In 2014, every team rewrote their monolith into microservices "because Netflix." In 2020, half of those teams quietly merged services back together because the operational overhead exceeded the benefits. Today, mature teams reach for whichever fits the *team's* constraints — recognizing that the architectural decision is downstream of organizational realities, not a technology choice in isolation.

This is the topic where Conway's Law meets distributed systems. The question isn't "is microservices better?" but "given our team size, our domain complexity, our deployment requirements, and our operational maturity, where should service boundaries live?" Answering that well is one of the most consequential decisions an engineering organization makes.

---

## Intuition Before Definitions

Imagine running a restaurant.

**The monolithic kitchen.** One head chef does everything: takes orders, cooks, plates, runs to deliver. As the restaurant grows, you hire more chefs, but they all share the same kitchen, the same tools, the same recipe book. Coordination is easy (you can yell across the kitchen). Specialization is limited. When the restaurant gets very busy, the kitchen becomes chaos — too many chefs, one stove, one prep counter.

**The microservice food court.** Multiple independent kitchens, each making one cuisine. Italian over there, sushi here, burgers there. Each kitchen has its own tools, recipes, staff. They serve a common dining hall. To order food from multiple cuisines, the customer (or a runner) goes to each kitchen.

The food court scales: each kitchen specializes; failures are localized (the sushi place is down, but you can still get burgers). The overhead: signage, payments, coordination, more space. For a small restaurant with one cuisine and ten customers a day, the food court is absurd. For an airport food court serving thousands of meals, the monolithic kitchen would never work.

The right answer is *fit to scale and complexity*. Most teams don't need a food court. Some absolutely do. Many start with a kitchen and graduate to a food court as they grow.

---

## Historical Evolution

**Era 1 — The monolithic web application.**
1990s, 2000s. PHP/Java/Rails monoliths shipped as single artifacts. Worked beautifully at the scale most companies operated at.

**Era 2 — SOA (Service-Oriented Architecture).**
Late 1990s, 2000s. Enterprises split monoliths into services connected by ESBs and SOAP. Heavyweight, often centrally orchestrated, mixed track record.

**Era 3 — Microservices emerge.**
~2011-2014. Netflix, Amazon, others articulate "microservices" as small, independently-deployable services with HTTP/REST interfaces. Influential blog posts (Lewis & Fowler, 2014) crystallize the pattern.

**Era 4 — The microservices boom.**
2014-2018. Every conference talk is microservices. Companies large and small split monoliths. Many succeed; many discover the operational reality is harder than the diagrams suggested.

**Era 5 — The reaction.**
2018-2022. Posts like "Don't Start with Microservices — Do This Instead" (Stefan Tilkov), "Goodbye Microservices" (Segment, 2018, who consolidated their microservices back), and "Microservices Were the Wrong Choice" warnings proliferate. Teams realize the operational tax is significant; not every team can afford it.

**Era 6 — Pragmatic synthesis.**
2022+. The mature view: monoliths are fine for most teams; microservices are the right answer when *the team's organizational structure* and *the operational maturity* support them. Modular monoliths get attention as a middle ground. The decision becomes contextual.

The pattern: the industry oscillated between centralized (monolith), decentralized (SOA, microservices), and centralized again (modular monolith). Each cycle clarified what each approach is actually good for.

---

## Deep Technical Explanation

### The monolith — clarified

A monolith is:
- One codebase.
- One deployable artifact (binary, JAR, container, etc.).
- One database (typically; sometimes a few).
- One process (or many identical processes).
- All inter-component calls are in-process function calls.

Monolith strengths:
- **Simple deployment.** Push once.
- **In-process performance.** No serialization, no network.
- **Strong consistency by default.** Single transactional database.
- **Easy refactoring.** Compiler/IDE can find all callers.
- **One observability surface.** Logs, metrics, traces in one place.
- **Lower operational overhead.** One service to monitor, one to scale, one to alert on.

Monolith weaknesses (at scale):
- **Slow deploys.** Build takes longer; deploys risk-of-breakage grows.
- **Coordination overhead.** Many teams committing to one repo; merge conflicts, breaking changes.
- **Scaling indivisibility.** Memory-hungry feature forces all instances to be memory-sized, even those serving lightweight features.
- **Technology lock-in.** One language, one framework, one stack.
- **Long test cycles.** Full test suite for any change.

These weaknesses appear at *some scale*. The scale varies by team, by domain, by operational maturity. Many companies hit them at 50-200 engineers; some never do; some hit them earlier.

### Microservices — clarified

Microservices are:
- Multiple independently-deployable services.
- Each owned by one team (typically).
- Each with its own database (the "shared-nothing" rule).
- Each communicating via well-defined APIs (REST, gRPC, async events).
- Each has its own deployment, scaling, and observability.

Microservices strengths:
- **Independent deployment.** Teams ship without coordinating with others.
- **Independent scaling.** Each service sized to its load.
- **Technology diversity.** Right tool per service.
- **Fault isolation (in theory).** A bug in one service doesn't compile-break others.
- **Team autonomy.** Each team owns their service end-to-end.
- **Smaller cognitive load** per service.

Microservices weaknesses:
- **Distributed-systems complexity.** Network failures, retries, idempotency, sagas.
- **Operational overhead.** N services to deploy, monitor, alert on, scale.
- **Latency penalty.** In-process calls are nanoseconds; HTTP calls are milliseconds.
- **Data consistency challenges.** No cross-service transactions.
- **Debugging difficulty.** A request flows through many services; tracing is essential.
- **Higher infrastructure costs.** Multiple databases, more network egress, more compute overhead.
- **Observability investment** is non-negotiable.

These costs are real. Many teams underestimate them and discover them post-migration.

### The modular monolith

A middle ground: one deployable artifact, but with strict internal boundaries enforced at code level.

- **One process, one deploy, one observability surface** (monolith benefits).
- **Strict module boundaries** with explicit interfaces (microservices benefits).
- **Database isolation by module** (each module owns its tables; modules talk via APIs, not by joining each other's tables).
- **No shared mutable state across modules.**

Done well, a modular monolith can later be split into microservices module-by-module — the boundaries are already there. Done badly (without enforced boundaries), it becomes a tangled monolith that's harder to extract from than a normal one.

Languages/frameworks help: Java's modules, Rust's crates, .NET's assemblies, Go's packages all support module-level boundaries. The discipline must be enforced — it's all too easy to violate boundaries when nothing forces you to use APIs.

### When microservices make sense

Specific pre-conditions:
- **Team size large enough** that coordination costs in the monolith exceed microservices' overhead. Often 50+ engineers; sometimes much more.
- **Independent deployment cadences** are required. Different teams need to ship at different rates.
- **Different scaling profiles**. One feature is read-heavy, another write-heavy, another batch — different scaling needs justify different services.
- **Different reliability requirements**. The checkout flow needs more 9s than the recommendations service.
- **Operational maturity exists**. CI/CD, observability, on-call, chaos engineering, service mesh — these are prerequisites, not nice-to-haves.

If most of these aren't true, microservices are likely premature.

### When monoliths make sense

Pre-conditions:
- **Small to medium team.** 5-50 engineers is often the sweet spot.
- **Cohesive domain.** Most features touch the same data.
- **Modest deployment frequency.** Daily or less.
- **Limited operational resources.** Don't have a platform team.
- **Simple scaling needs.** Horizontal scaling of the whole monolith works.
- **Strong consistency requirements** that would be expensive across services.

Most startups should start here. So should most enterprise applications below a certain complexity threshold.

### Service boundaries — the real work

Where to draw lines:
- **Bounded contexts** (DDD): a context is a set of related concepts with a single, consistent vocabulary and model.
- **Team ownership**: one team can fully own one service.
- **Data ownership**: each piece of data has one source of truth in one service.
- **Change frequency**: things that change together belong together; things that change independently belong apart.

Anti-patterns to avoid:
- **By tier**: separate "API layer," "business logic," "data layer" services. Distributed monolith.
- **CRUD-per-entity**: one service per database table. Tons of cross-service calls; no real autonomy.
- **Anemic services**: services that just proxy data; add latency without adding value.
- **Shared database**: multiple services reading/writing the same tables. Coupling without the benefits of separation.

The Goldilocks principle: services should be *just big enough* to own a meaningful capability, *just small enough* to be one team's manageable scope.

### Communication patterns

**Synchronous (REST, gRPC):** simple to reason about; tight coupling at runtime. Failures cascade unless circuit-broken.

**Asynchronous (events, queues):** decoupled; harder to reason about; eventual consistency. Saga patterns for cross-service flows.

**Hybrid:** synchronous for queries; async for state changes. Common in mature architectures.

The choice shapes failure modes, latency, complexity. Each call is a chance for things to go wrong.

### The operational tax

Things microservices teams must build (or buy):
- **Service discovery** (Consul, Kubernetes, etc.).
- **Load balancing** at the service mesh.
- **Distributed tracing** (OpenTelemetry, Jaeger).
- **Centralized logging.**
- **Centralized metrics.**
- **CI/CD per service** (with consistency policies).
- **Schema/contract management** (protobuf, OpenAPI).
- **Cross-service authentication** (mTLS, JWT, etc.).
- **Network policies and security.**
- **Chaos engineering practices.**
- **Documentation and discoverability.**

A team without these is doing distributed monolith — the worst of both worlds.

---

## Real Engineering Analogies

**The single-restaurant chef vs the food court.**
(Already used above.) Small team, simple menu → one kitchen. Large operation, diverse offerings → food court. Trying to run a food court with two staff total is absurd; trying to run a thousand-person food festival from one kitchen is impossible.

**The general store vs the mall.**
A small town has a general store. It sells everything. The owner knows every customer. Inventory management is straightforward.

A mall has dozens of specialized stores. Each store is expert at its category. Coordination between stores is minimal but visible (mall management, food court, parking). The mall serves more customers, more variety; it costs more to operate.

A small town that builds a mall fails. A growing city that stays with one general store also fails. Same logic applies to software architecture.

---

## Production Engineering Perspective

What goes wrong:

- **The premature microservices migration.** A team of 8 splits a monolith into 12 services. Deploy times grow (now must coordinate across services for many features). Bugs multiply (network failures, version mismatches). Productivity drops. After a year, they consolidate back.
- **The distributed monolith.** Microservices that share a database. Or that have synchronous chains 5 levels deep. A tiny change requires deploying 5 services in lockstep. The benefits of microservices weren't realized; the costs absolutely were.
- **The 1000-microservice landscape.** A team grew to thousands of engineers. Service count exploded. New engineers can't understand which service does what. Service-to-service auth gaps surface. Some services are owned by no one. Cleanup takes years.
- **The "Conway's Law violation."** A team that's actually one team owns ten services. Communication overhead between modules is now communication overhead between deploys. The team gets slower, not faster.
- **The synchronous chain that failed.** Service A → B → C → D → E. E has a 1% error rate. A's effective error rate is much higher (compounding). Long chains of synchronous calls are fragile.
- **The shared-database nightmare.** Two services both write to the same table. Schema changes require coordinated deploys. Race conditions appear. The "microservices" are conjoined twins.
- **The rebuild that wasn't necessary.** A team rewrites a monolith into microservices "to scale." The actual scaling problem was a single slow query. Adding an index would have fixed it. Two years and tens of millions later, the microservices version doesn't even scale better.

The senior architect's habits:
- **Start with the team structure.** Architecture follows.
- **Default to monolith** for small/medium teams.
- **Modular monolith** as a stepping stone.
- **Extract services only when the pain is real**, not anticipated.
- **Audit service-to-service coupling** as a primary concern.
- **Invest in observability** before extracting services.
- **Resist "service per developer"** instinct.

---

## Failure Scenarios

**Scenario 1 — The premature split.**
A 10-engineer startup splits into 8 services. Each service has its own deploy, its own logging, its own database. Operational overhead explodes. CI takes hours. Engineers spend more time on infrastructure than features. After 18 months, they consolidate to 3 services and recover velocity.

**Scenario 2 — The distributed monolith.**
20 services, but every business operation touches 8 of them. Deploys must be coordinated. Schema changes are weeks of work. The "microservices" architecture has all the costs and none of the benefits — because services can't actually deploy independently.

**Scenario 3 — The latency cliff.**
A monolith with sub-ms internal calls is split into microservices with 50ms HTTP calls. Per-request latency grows from 200ms to 800ms. User-facing performance degrades. Mitigation: aggressive caching at every boundary; some boundaries reverted.

**Scenario 4 — The auth gap discovery.**
500 services. A new attack reveals that 30 services don't enforce auth on internal endpoints — assumed network was trusted. Frantic patching. Lesson: zero-trust networking from the start.

**Scenario 5 — The cascading deployment.**
Service A's API change requires updating clients in B, C, D. Schema migration in B requires data migration in A. A bug in C blocks the whole release. What was supposed to be one feature ends up taking a month. Lesson: contract-first design; backward-compatible changes only.

---

## Performance Perspective

- **Monolith function calls**: nanoseconds (in-process, no serialization or network).
- **Microservice network calls**: add a per-hop overhead — on a LAN, sub-millisecond to a few milliseconds of round-trip plus serialization, more across zones/regions. The key point is the *added* cost of crossing a process/network boundary versus an in-process call, not a fixed floor.
- **Latency budgets**: easier in monoliths; in microservices, the boundary-crossing cost compounds with each hop and must be carefully apportioned across services.
- **Throughput**: monoliths can saturate a single machine; microservices distribute the load but pay coordination costs.

---

## Scaling Perspective

- **Vertical**: monoliths scale to the size of the largest sensible machine — often hundreds of cores, terabytes of RAM.
- **Horizontal (monolith)**: replicate the whole thing. Memory and CPU usage uniform.
- **Horizontal (microservices)**: scale each service independently. Better resource utilization at high scale.
- **Team scaling**: monoliths struggle past ~50 engineers (rough); microservices enable 100s or 1000s with appropriate org structure.
- **At hyperscale**: microservices (or some equivalent) are inevitable. Below that, options exist.

---

## Cross-Domain Connections

- **Sagas**: cross-service workflows in microservices require sagas; monoliths can use database transactions. (See [saga-pattern-and-distributed-transactions.md](./saga-pattern-and-distributed-transactions.md).)
- **Cascading failures**: microservices' failure modes; monoliths fail differently (whole-process). (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)
- **API design**: every microservice exposes an API; monoliths have internal APIs. (See [api-design-rest-vs-grpc.md](./api-design-rest-vs-grpc.md).)
- **Distributed tracing**: essential for microservices; nice-to-have for monoliths. (See [distributed-tracing-deep-dive.md](../observability/distributed-tracing-deep-dive.md).)
- **Sharding**: a service-oriented architecture is sharding-of-functionality; same tradeoffs around cross-shard work. (See [sharding-and-partitioning-strategies.md](../scalability/sharding-and-partitioning-strategies.md).)
- **CQRS**: a natural fit in microservice architectures where read and write paths can be different services. (See [cqrs-and-event-sourcing.md](./cqrs-and-event-sourcing.md).)

The unifying observation: **microservices are a distributed system; monoliths are not. Every distributed-systems concept in this knowledge base applies to microservices and largely doesn't to monoliths. That's the real cost.**

---

## Real Production Scenarios

- **Netflix's microservices journey**: the canonical case. Public engineering posts span 15+ years. Netflix's scale and engineering investment are both unusual.
- **Amazon's "two-pizza teams"**: famous organizational pattern that Conway's-Lawed Amazon into microservices.
- **Segment's consolidation (2018)**: documented case of going from microservices back to a monolith for operational simplicity.
- **GitHub's mostly-monolith**: large engineering org, mostly Ruby monolith, few extracted services. Demonstrates that "scale" doesn't always demand microservices.
- **Shopify's modular monolith**: 5000+ engineers, primarily one Ruby on Rails app, with strict module boundaries. A reference for "modular monolith at scale."
- **Stack Overflow's monolith**: famously runs on a small number of beefy servers. Public talks describe their architecture.
- **The "rewrite from microservices" stories**: numerous startups have shared experiences of consolidating after over-microservicing.

---

## Worked Example — When to Extract

You have a Rails monolith. 30 engineers, growing to 50. The team is feeling pain: 30-minute CI; merge conflicts daily; deploys touch all features; one team's bug crashes others. Should you extract services?

### The wrong evaluation

"Microservices because Netflix has them." Doesn't follow.

### The right evaluation

Identify the *actual* pain:

```
Pain audit:
1. CI takes 30 min       → split tests, parallelize, faster machines (cheap)
2. Merge conflicts        → more PRs, smaller, better trunk-based dev
3. Deploys touch all      → feature flags decouple deploy from release
4. Cross-team bugs        → modules with strict boundaries; ownership
```

Most "we need microservices" pains have monolith-friendly fixes. Try those first.

### When extraction makes sense

Specific, identifiable pains that monolith can't fix:

```
Concrete cases:
- "Image processing crashes the web app's memory."
  → Extract image service. Its memory pressure no longer affects others.

- "Search needs ML libraries that bloat the deploy."
  → Extract search. Different runtime; different deploy cadence.

- "Recommendations team has different ship velocity."
  → Extract recommendations. They ship daily; rest of monolith ships weekly.

- "Mobile API and web API need different evolution."
  → Extract a Backend-For-Frontend per channel.
```

Each is a *specific* extraction with a clear win. Not "let's microservice everything."

### Extraction process (strangler fig style)

Concrete steps for extracting Image Service:

```
Phase 1 (week 1-2): Establish boundary in monolith
  - Move all image code to one module.
  - Define interface (function calls).
  - Other monolith code calls via the interface.

Phase 2 (week 3-4): Build new service
  - Create images-service repo.
  - Copy logic; expose HTTP API matching the interface.
  - Test in isolation.

Phase 3 (week 5-6): Route traffic gradually
  - In monolith, behind feature flag, route 1% of traffic to new service.
  - Compare results (shadow mode initially).
  - Ramp 10%, 50%, 100%.

Phase 4 (week 7+): Cleanup
  - Remove old code from monolith.
  - Service is independent.
  - Old code is gone, not just unreferenced.
```

Total: ~2 months for one service. Not "the year of the rewrite."

### Decision framework — concrete signals to extract

| Signal | Extract? |
|---|---|
| Different deploy frequency | Yes |
| Different scaling needs | Yes |
| Different reliability requirements | Yes |
| Different language fit | Sometimes |
| Different team owner | Strong yes |
| "It's getting big" | No (modular monolith) |
| "Microservices is best practice" | No |
| "Different programming style" | No (use modules) |

### The reverse — when to consolidate

Sometimes you discover you over-extracted. Signs:

- Two services almost always deploy together.
- A change requires 5 service deploys.
- Cross-service traces show 90% of time in serialization.
- Service ownership is unclear.
- "We have a microservice for this trivial thing."

Consolidating two services back into one is sometimes the right move. Don't be precious about service count.

### Reference — the modular monolith

A modular monolith is the recommended starting architecture for most teams. Looks like:

```
my-app/
├── modules/
│   ├── orders/
│   │   ├── api/         (only public functions)
│   │   ├── domain/       (private)
│   │   ├── infra/        (private)
│   │   └── tests/
│   ├── inventory/
│   │   ├── api/
│   │   └── ...
│   ├── payments/
│   └── shipping/
├── lib/                  (shared utilities)
└── shared/
    └── domain-events/    (cross-module communication)
```

Rules enforced in code review (or compile-time if language allows):
- Modules talk only via `api/` exports.
- No direct DB access across modules.
- Cross-module flow uses domain events.
- Each module owns its tables (via prefix or schema).

When extraction time comes, the boundaries are already there. Migration is "deploy module X as separate service" — not "untangle everything first."

---

## Recent Production References (2023-2024)

- **Shopify's modular monolith at scale (2024)**: 6000+ engineers; primarily one Rails app. Public engineering posts on enforcing module boundaries.
- **Amazon Prime Video moving from microservices to monolith (2023)**: blog post. Their video-monitoring service consolidated services for 90% cost reduction. Caveat: this was a specific workload (video analysis); not a universal lesson, but it's a counterpoint to "always microservice."
- **Segment's consolidation (2018, still cited)**: documented case of microservices → modular monolith.
- **DHH's "Majestic Monolith" essays**: continuing influence; backbone of Rails-community thinking.
- **Stack Overflow's architecture (always cited)**: famously runs on a small number of beefy servers; mostly monolith.
- **The "distributed monolith" antipattern**: continues to be the dominant cautionary tale.
- **Conway's Law as ongoing guidance**: still the most-cited principle in architecture decisions.

---

## Reference Architecture — When You're Ready

```
   ┌──────────────────────────────────────────────────────┐
   │                 MOST TEAMS START HERE                  │
   │                                                        │
   │              ┌─────────────────────────┐               │
   │              │     Modular Monolith     │               │
   │              │                          │               │
   │              │  ┌────┐ ┌────┐ ┌────┐    │               │
   │              │  │Mod1│ │Mod2│ │Mod3│    │               │
   │              │  └────┘ └────┘ └────┘    │               │
   │              │  Strict boundaries        │               │
   │              │  Single deploy            │               │
   │              │  One DB or DB-per-module  │               │
   │              └─────────────────────────┘               │
   └──────────────────────────────────────────────────────┘
                            │
                            ▼
                Pain demands extraction
                            │
                            ▼
   ┌──────────────────────────────────────────────────────┐
   │            EXTRACT WHAT NEEDS EXTRACTING               │
   │                                                        │
   │     ┌──────┐  ┌──────────┐  ┌──────────────────┐     │
   │     │Module│  │Extracted  │  │ Modular Monolith │     │
   │     │ 1    │  │Service A  │  │ (Mod 2, 3, ...)  │     │
   │     │      │  │           │  │                   │     │
   │     └──────┘  └──────────┘  └──────────────────┘     │
   │                                                        │
   │  Some modules extracted; rest stays in monolith.      │
   │  Each extraction has a concrete reason.               │
   └──────────────────────────────────────────────────────┘
                            │
                            ▼
                Continue evolving as needed
                            │
                            ▼
   ┌──────────────────────────────────────────────────────┐
   │           MICROSERVICES ARRIVED ORGANICALLY            │
   │                                                        │
   │   8-12 services with clear boundaries and ownership.   │
   │   Most teams that need this never reach 50+ services.  │
   └──────────────────────────────────────────────────────┘
```

The path is incremental. The end state is bespoke to your needs. The companies with 1000+ services are unusual; if you're not them, you probably won't be them.

---

## Key Takeaways

- **Architecture follows team structure (Conway's Law).** Organizations design systems that mirror their communication structures. Start from the org chart, not the architecture diagram; fighting Conway's Law produces systems that look right on paper and feel wrong in practice.
- **Microservices are a distributed system; monoliths are not.** Every distributed-systems concept — network failures, retries, idempotency, sagas, tracing — applies to microservices and largely doesn't to monoliths. That's the real cost.
- **The cost of microservices is mostly operational** — deployment infrastructure, observability, networking, on-call rotations, integration testing — none of which the architecture diagram shows, and which teams routinely underestimate.
- **Service boundaries follow domain, not technology.** Splitting by business capability (Orders, Payments, Inventory) is microservices; splitting "by tier" (frontend/backend/database service) is a distributed monolith — all the costs, none of the benefits.
- **Small services are easier to reason about; large systems of small services are harder.** Complexity moves from inside services to between them. The right granularity is not "as small as possible" — it's the smallest unit one team can develop, deploy, and operate independently.
- **The modular monolith is the recommended starting point** for most teams and a middle ground: one deploy, but strict enforced module boundaries that make later extraction module-by-module straightforward.
- **Default to monolith until real pain forces a split.** Resist premature splitting and the "service per developer" / "microservices because Netflix" instinct; most "we need microservices" pains have monolith-friendly fixes (parallelize CI, feature flags, modules with ownership).
- **The distributed monolith is the worst of both worlds** — services that share a database or chain synchronously such that they can't deploy independently.
- **Synchronous chains amplify failures**: A→B→C→D→E with a 1% error rate at E gives A a much higher effective error rate.
- **Each service should be one team's scope**, with one source of truth for each piece of data.
- **Consolidation is sometimes the right move** — don't be precious about service count. Senior engineers measure architectural overhead (CI time, deploy coordination, debugging difficulty) and know when to merge services back.
- **There is no architecture that's better in a vacuum — only architecture that fits** the team, domain, operational maturity, and the scale you're at *and* heading toward. The question is never "should we be microservices?" but "where do the costs and benefits flip for us?" Ask: what's hard now, what's hard 12 months out, what does the team and org look like?

---

## Interview angle

What gets tested:

1. **"Microservices vs monolith — when each?"** Senior answer covers team size, operational maturity, deployment requirements, domain shape.
2. **"What's a distributed monolith and why is it bad?"** Tests anti-pattern awareness.
3. **"How would you split a monolith?"** Bounded contexts, ownership, change frequency.
4. **"What's the operational cost of microservices?"** Network, observability, deployment, debugging.
5. **"What's Conway's Law?"** Tests classic literacy.
6. **"When would you NOT use microservices?"** Senior candidates volunteer "most of the time."
7. **"How do microservices change failure modes?"** Cascading failures; need for circuit breakers, retries, sagas.

Common traps: saying microservices are "always more scalable"; recommending splitting based on technology rather than domain; underestimating operational cost; believing small services solve every problem.
