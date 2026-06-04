# Monoliths vs Microservices

## A. Intuition First
- **Monolith**: one deployable, one codebase. Everything in one process.
- **Microservices**: many small services, each with its own deploy, data, and team.

Microservices are not "better". They trade simplicity for flexibility + team independence + fault isolation.

### 🪜 Prerequisite investment ladder (you need ALL of these before going micro)

| Capability | Why before going micro |
|---|---|
| CI/CD per service | Otherwise deploying 20 services means 20 hours of manual work |
| Centralized logging with trace IDs | Without it, debugging a 5-service request is impossible |
| Distributed tracing (Jaeger/Tempo) | See latency across services |
| Service discovery + sidecars | Endpoints change dynamically |
| Circuit breakers + timeouts | Cascade failures will happen |
| Feature flags / gradual rollout | Deploy risky changes safely |
| On-call rotation + runbooks | More moving parts = more pages |

> **🧠 What if you skip this?** You end up with a **distributed monolith**: many services, all coupled, all deploy together, nothing easier to reason about. Worst of both worlds.
>
> **🔎 Quick Check** — Your team of 5 is arguing about splitting a 50k LOC app into 15 microservices. Your first question should be?
> **🎯 Recall** — "Do we have CI/CD, tracing, discovery, and on-call set up?" If no to any, **don't split yet**.

## B. Mental Model
- Start with a monolith. Split only when coupling or scaling forces it.
- Each microservice owns its data; services communicate over network (HTTP/gRPC/events).

## C. Internal Working
### Monolith
- Shared codebase, shared DB, in-process calls.
- Simple to reason about, deploy atomic.
- Scales by running more copies behind LB.

### Microservices
- Each service = its own repo or module, deployment pipeline, DB.
- Communicate via REST/gRPC for sync, queue/pub-sub for async.
- Requires: service discovery, distributed tracing, centralized logging, API gateway, observability from day 1.

## D. Visual Representation
```
Monolith:         [Web + Svc + DB-client]──→ [DB]
Micro:     [Web] → [Orders] → [Orders DB]
                → [Inventory] → [Inv DB]
                → [Payment] → [Pay DB]
```

## E. Tradeoffs
| | Monolith | Microservices |
|---|---|---|
| Complexity | Low (1 service) | High (N services) |
| Deploy | Atomic, sometimes risky | Independent |
| Team scaling | One team bottleneck | Parallel teams |
| Fault isolation | One bug breaks all | Isolated |
| Ops cost | Low | High |
| Data consistency | Trivial | Hard (distributed tx / sagas) |

## F. Interview Lens
- "When do you split?" — when team size + domain complexity outgrow one codebase.
- "Shared DB anti-pattern?" — yes, each service must own its data.
- "Distributed monolith?" — many services but tightly coupled deploys = worst of both worlds.
- Pitfalls: starting with microservices for a team of 3.

## G. Real-World Mapping
- Amazon, Netflix, Uber: heavy microservices.
- Basecamp, Stack Overflow, Shopify: monolith-majuscule for most of their life.

## H. Questions
**Beginner**: Monolith vs microservices pros/cons.
**Intermediate**: When to split?
**Advanced**:
1. Extract a service from a monolith with zero downtime.
2. Describe the distributed monolith anti-pattern.

## I. Mini Design
A 5-year-old monolith: extract the payments module into a service. Steps: isolate module, add API boundary, dual-write in both old and new for a week, shift reads, remove from monolith.

## J. Cross-Topic Connections
- [API Gateway](api-gateway.md), [Service Discovery](../reliability/service-discovery.md), [Distributed Transactions](../data/distributed-transactions.md), [Event-Driven Architecture](event-driven-architecture.md).

## K. Confidence Checklist
- [ ] Can defend when to NOT use microservices.
- [ ] Knows the operational prerequisites (observability, tracing, CI/CD).

## L. Potential Gaps & Improvements
- **Modular Monolith** — a single deployable app whose code is split into strict, well-bounded modules; gives you clean boundaries without distributed-systems pain, so it's often the right first answer before microservices.
- **Strangler Fig Pattern** — incrementally route slices of traffic from an old monolith to new services until the old one is fully replaced; lets you migrate safely with no big-bang rewrite.
- **Bounded Context (Domain-Driven Design)** — a clear ownership boundary around a business capability that decides where one service ends and the next begins; getting this wrong is the top cause of "distributed monolith" pain.
- **Distributed Monolith** — services that are deployed separately but still tightly coupled and must ship together; the worst of both worlds, and the trap microservices migrations fall into. (→ see Advanced Questions)

**🔧 How to close:** Spin up a 2-service `docker-compose` (e.g. an `orders` and a `payments` service plus one Postgres each), then deliberately add a synchronous HTTP call from `orders` to `payments`; stop the `payments` container with `docker compose stop payments` and watch `orders` fail — that failure is the coupling cost you must justify when you choose microservices.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🧱 Gap 1 — Modular Monolith
- 🔹 **What it is**: One deployable app whose code is split into strict, independently-owned modules with enforced boundaries — clean internal separation without the network in between.
- 🔹 **Why it matters**: It's the answer that wins most "should we go microservices?" debates: you get team ownership and clear boundaries while keeping atomic deploys, in-process calls, and trivial transactions.
- 🔹 **Connection**: §A's prerequisite ladder shows everything you must buy *before* going micro. A modular monolith lets you defer that bill while still organizing the code the way §B suggests ("start with a monolith").
- 🔹 **When needed**: 🟢 **Foundational** — almost every team should reach for this before splitting; it's increasingly the recommended default answer.
- 🔹 **Intuition**: An open-plan office with clearly painted floor zones for each team. Same building, one front door, one fire drill — but everyone knows whose desk is whose.
- 🔹 **If you go deeper**: Read Shopify's "Deconstructing the Monolith" engineering post and try Spring Modulith (Java) or .NET's module-boundary analyzers, which fail the build when one module reaches into another's internals.
- 🔹 **Interview hook**: *"Team of 8, growing fast — microservices or not?"* → Modular monolith first: enforce module boundaries, keep one deploy, and split out only the modules that prove they need independent scaling or release cadence.

---

#### 🌿 Gap 2 — Strangler Fig Pattern (incremental migration)
- 🔹 **What it is**: Migrating off a monolith by routing slices of traffic to new services one feature at a time, growing the new system around the old until the old one can be deleted.
- 🔹 **Why it matters**: Big-bang rewrites are the classic way to kill a product. The strangler fig is how real companies migrate safely with rollback at every step.
- 🔹 **Connection**: §I's mini design (extract payments: API boundary → dual-write → shift reads → remove) *is* a strangler fig in miniature. This gap names the pattern and scales it up.
- 🔹 **When needed**: 🟡 **Mid-level** — comes up whenever an interviewer asks "how would you migrate a legacy system without downtime?"
- 🔹 **Intuition**: A strangler fig tree grows on a host tree, slowly enveloping it; eventually the host rots away and the fig stands on its own — but the forest never had a gap.
- 🔹 **If you go deeper**: Read Martin Fowler's "StranglerFigApplication" article, then study how a facade/proxy at the edge (API gateway or reverse proxy) routes per-route traffic between old and new during the cutover.
- 🔹 **Interview hook**: *"Extract a service from a monolith with zero downtime."* → Put a proxy in front, dual-write the data, shift reads behind a feature flag route-by-route, verify, then cut the old path — never a single flip.

---

#### 🗺️ Gap 3 — Bounded Context & Service Boundaries (DDD)
- 🔹 **What it is**: A bounded context is the explicit ownership boundary around one business capability (e.g. "Billing" vs "Shipping"), inside which a term like "Order" has exactly one meaning.
- 🔹 **Why it matters**: Where you draw these lines *is* your service decomposition. Drawing them wrong — splitting by technical layer or by database table — is the #1 cause of the distributed monolith.
- 🔹 **Connection**: §F warns against the "shared DB anti-pattern" and §E lists "data consistency: hard". Both are downstream of bad boundaries: services that share data weren't really separate contexts.
- 🔹 **When needed**: 🟡 **Mid-level** for service-decomposition questions; 🔴 **Senior** when an interviewer probes *how* you'd find the seams in a large domain.
- 🔹 **Intuition**: Departments in a hospital — Radiology, Billing, and Pharmacy each "own" the patient differently, with their own forms and language. You don't make Radiology ask Billing's permission to read an X-ray.
- 🔹 **If you go deeper**: Read Eric Evans' *Domain-Driven Design* (the Bounded Context chapter), then try an Event Storming workshop to discover boundaries from business events rather than from the existing schema.
- 🔹 **Interview hook**: *"How do you decide where one microservice ends and the next begins?"* → Along bounded contexts / business capabilities that change together and own their own data — never by sharing tables or splitting by tech layer.

---

#### 🪢 Gap 4 — Avoiding the Distributed Monolith
- 🔹 **What it is**: The failure mode where you have N separately-deployed services that are still so coupled they must be tested and released together — all the ops cost of microservices, none of the independence.
- 🔹 **Why it matters**: It's the trap most migrations fall into, and naming the warning signs (synchronous chains, shared databases, lockstep releases) is exactly what interviewers listen for.
- 🔹 **Connection**: §A's "🧠 What if you skip this?" callout and §F both flag it directly. This gap turns that warning into a concrete checklist of smells and fixes.
- 🔹 **When needed**: 🟢 **Foundational** — the concept is essential; the *cures* (async events, contract testing) are 🔴 **Senior**.
- 🔹 **Intuition**: A train where every carriage has its own engine — but they're all bolted together, so they still leave and arrive as one train. You paid for many engines and gained nothing.
- 🔹 **If you go deeper**: Study the cures — replace synchronous chains with events ([Event-Driven Architecture](event-driven-architecture.md)), give each service its own DB, and add consumer-driven contract testing (e.g. Pact) so services can deploy independently without breaking callers.
- 🔹 **Interview hook**: *"How do you know your microservices are actually a distributed monolith?"* → They share a database, call each other synchronously in long chains, and can't be deployed independently — fix with per-service data, async messaging, and contract tests.

---

### 🏆 Start here if you have limited time
1. **Modular Monolith** — the single most useful reframe; it changes your default answer to "should we split?" and applies to nearly every team.
2. **Avoiding the Distributed Monolith** — the trap this whole topic exists to help you dodge; high-signal in any microservices interview.

---

### 🧭 Suggested Deep Dive Order
1. **Modular Monolith** (~45 min; reshapes the core decision and is reachable now).
2. **Avoiding the Distributed Monolith** (~30 min; cements the failure mode you're trying to prevent).
3. **Bounded Context & Service Boundaries** (~1h; the theory behind *where* to split).
4. **Strangler Fig Pattern** (~1h; the safe *how* of migrating once you've decided to split).
