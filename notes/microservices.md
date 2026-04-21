# Microservices & Software Architectures

> **📎 Prereqs** — If rusty:
> - [`learn/architecture/n-tier-architecture.md`](../learn/architecture/n-tier-architecture.md) — basic tier separation.
> - [`distributed_transactions.md`](distributed_transactions.md) — cross-service coordination pain.
> - Basic CI/CD understanding.

### 🔹 1. What This Topic Actually Is
Style of organizing an app as many small services, each with own deploy, data, team — as opposed to a monolith (one deployable).

### 🔹 2. Why It Exists
- Scale **teams** (parallel deploys, independent release cadence) more than scale **traffic**.
- Fault isolation: one service's bug doesn't break everything.
- Polyglot: right tool per domain.

Start with a monolith. Split only when coupling or team size demands it.

### 🔹 3. Core Concepts (High Signal)
- **Domain-oriented microservices (Uber)**: each service owns a bounded context (DDD); aligns services with teams.
- **Nanoservices antipattern**: too small → network hop per function call → chaos.
- **Modular monolith**: a middle ground — one deploy, clear module boundaries. Often the right answer.
- **Hexagonal / Ports & Adapters (Alistair Cockburn, Netflix)**: domain logic in the center, adapters for DB/HTTP/queue on the edge. Makes testing + tech swap easier.
- **Clean Architecture (Uncle Bob)**: concentric layers, dependencies inward.
- **DDD (Domain-Driven Design)**: ubiquitous language, bounded contexts, aggregates.
- **CQRS (Martin Fowler)**: split reads from writes; each optimized independently.
- **Strangler fig pattern**: extract features from monolith one at a time.

### 🔹 4. Internal Working (what microservices require at scale)
- **Service discovery** (Consul, k8s DNS).
- **API Gateway / BFF** at the edge.
- **Distributed tracing** (Jaeger / OpenTelemetry).
- **Schema registry** for events.
- **Centralized logging + metrics**.
- **Circuit breakers + retries with jitter**.
- **CI/CD per service**.
- **Shared libs kept tiny** to avoid coupling.

**Failure points:** distributed monolith (tight coupling + many deploys), SPOF in shared DBs, data consistency (sagas needed), operational cost explosion.

### 🔹 5. Key Tradeoffs
- Monolith: simplest; bottleneck is team size + deploy risk.
- Microservices: parallel scale; cost = ops maturity + distributed complexity.
- Nanoservices: always wrong.
- Modular monolith: often correct middle.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. Monolith vs microservices — when each?
2. What's a bounded context?

**Intermediate 🟡**
1. Signs of "distributed monolith"?
2. What infrastructure do you need before going microservices?

**Advanced 🔴**
1. Extract payments service from monolith with zero downtime. (strangler + dual-write + cutover)
2. Microservice too chatty — how do you reduce N+1 cross-service calls?

### 🔹 7. Real System Mapping
- **Uber domain-oriented microservices** (thousands of services).
- **Netflix**: 1000+ services + Hexagonal Architecture.
- **Amazon**: 2-pizza teams → service-per-team.
- **Basecamp / Shopify / Stack Overflow**: highly productive on modular monoliths.

### 🔹 8. What Most People Miss
- **Conway's Law**: your architecture mirrors your org chart. Split services along team boundaries.
- **Microservices require 3× the ops maturity**: observability, deploy automation, on-call. Without them, outages multiply.
- **Shared-DB-between-services is an anti-pattern**: services must own their data.
- **Distributed monolith** = many services, tight coupling, coordinated deploys. Worst of both worlds.
- **Microservices ≠ small services**: it's about independent deploy + team, not line count.

### 🔹 9. 30-Second Revision
Start monolith. Go microservices when team size + domain complexity demand it. Align services to bounded contexts (DDD). Own your data. Hexagonal Architecture keeps domain clean. Avoid nanoservices, avoid distributed monolith. Strangler-fig to migrate safely. Requires serious observability investment.

---

## 🔗 Cross-Topic Connections
- **Service mesh**: sidecars (Envoy) handle cross-cutting concerns.
- **Messaging/EDA**: async between services.
- **Distributed transactions/saga**: cross-service consistency.
- **API Gateway**: one front door.

---

### Confidence Check
- [ ] Can I justify when NOT to use microservices?
- [ ] Can I sketch a migration plan from monolith?

### Gaps
- Concrete k8s + Istio setup for a microservice fleet.
- DDD tactical patterns practice.
