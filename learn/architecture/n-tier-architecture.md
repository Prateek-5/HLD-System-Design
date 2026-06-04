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

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🧱 Gap 1 — Tier vs. Layer (Physical vs. Logical Separation)
- 🔹 **What it is**: A *layer* is a logical grouping of code (presentation, business, data) inside one process; a *tier* is a physical/deployable boundary that runs on separate machines or containers.
- 🔹 **Why it matters**: People say "3-tier" when they really mean "3-layer" — and the distinction changes how you scale, deploy, and reason about failure.
- 🔹 **Connection**: Section A lists Presentation/Business/Data as "tiers", but a single monolith can contain all three as *layers* in one deployable. The network hops in Section C only exist once layers become tiers.
- 🔹 **When needed**: 🟢 **Foundational** — clears up a confusion almost every learner hits early.
- 🔹 **Intuition**: A house has logical *rooms* (kitchen, bedroom) — those are layers. Putting the kitchen in a separate building you walk to is a tier: more isolation, but now you cross the yard every meal.
- 🔹 **If you go deeper**: Read Martin Fowler's *Patterns of Enterprise Application Architecture* on the "Layering" pattern, and his article "PresentationDomainDataLayering".
- 🔹 **Interview hook**: *"Is a 3-layer monolith the same as a 3-tier system?"* → No — layers are logical groupings in one process; tiers are physically separated deployables that communicate over the network.

---

#### 🔌 Gap 2 — Clean / Hexagonal Architecture + Dependency Inversion
- 🔹 **What it is**: Layering styles (Hexagonal / Ports & Adapters, Clean Architecture) that put business logic in the center and let UIs and databases plug in at the edges, enforced by the DIP (Dependency Inversion Principle) — high-level code depends on interfaces, not concrete lower tiers.
- 🔹 **Why it matters**: It makes the data tier swappable and the business tier testable without spinning up a real DB, which is the difference between a brittle and a maintainable system.
- 🔹 **Connection**: This file's data tier is a hard dependency below the business tier. Clean/Hexagonal *inverts* that — the business tier defines a repository interface and the Postgres adapter implements it, so you can mock the data tier in tests.
- 🔹 **When needed**: 🟡 **Mid-level** — expected once you own a service's structure or discuss testability in interviews.
- 🔹 **Intuition**: A power tool with swappable bits. The motor (business logic) is fixed; you snap in a drill bit or a sander (Postgres or an in-memory fake) without rebuilding the motor.
- 🔹 **If you go deeper**: Robert C. Martin's *Clean Architecture* book and his 2012 "The Clean Architecture" blog post; Alistair Cockburn's original "Hexagonal Architecture" article.
- 🔹 **Interview hook**: *"How do you test business logic without a real database?"* → Depend on a repository interface (DIP); inject a fake adapter in tests and the Postgres adapter in production.

---

#### ⚖️ Gap 3 — Scaling the Middle Tier: Statelessness vs. Session Affinity
- 🔹 **What it is**: Running many app-tier instances behind a load balancer; this only works cleanly if the tier is *stateless* (session data lives externally) rather than relying on *session affinity* ("sticky sessions") that pin a user to one server.
- 🔹 **Why it matters**: A stateless app tier scales horizontally with no coordination; sticky sessions create hot spots and lose user state when an instance dies.
- 🔹 **Connection**: The "How to close" exercise scales `app=3` behind nginx round-robin — that only behaves correctly if each instance can serve *any* user, which requires moving session state out of the app tier (Section E's "independent scaling").
- 🔹 **When needed**: 🟡 **Mid-level** — directly relevant to almost any "how do I scale this web app" question.
- 🔹 **Intuition**: A bank where any teller can serve you because your account lives in the shared vault (external store), versus one where only "your" teller has your file in their drawer (sticky session) — and if they go on break, you're stuck.
- 🔹 **If you go deeper**: Read the "Twelve-Factor App" factor VI ("Processes — stateless"); push sessions into Redis or use signed JWTs, and compare against nginx `ip_hash` sticky sessions.
- 🔹 **Interview hook**: *"User logins break randomly after you add a second app server — why?"* → Sticky-session state lived in-process; externalize sessions (Redis/JWT) so the tier is stateless.

---

### 🏆 Start here if you have limited time
1. **Tier vs. Layer** — fixes the single most common vocabulary mistake and reframes everything else in this file.
2. **Statelessness vs. session affinity** — the practical key to actually scaling the middle tier you just drew.

---

### 🧭 Suggested Deep Dive Order
1. **Tier vs. Layer** (~20 min; clears conceptual fog before anything else lands).
2. **Statelessness vs. session affinity** (~45 min; immediately applicable to scaling work and interviews).
3. **Clean / Hexagonal + DIP** (~1.5h; longer payoff in maintainability and testing-focused interviews).
