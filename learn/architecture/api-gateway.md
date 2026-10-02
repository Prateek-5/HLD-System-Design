# API Gateway — One Front Door to Many Services

## A. Intuition First
In a microservices world, the client wants a single entry point. An API gateway is that front door: routes requests, handles auth, rate limits, rewrites, and sometimes aggregates multiple backend calls into one response.

## B. Mental Model
An API gateway is a specialized reverse proxy with **API-awareness**:
- Auth (verify JWT, API keys).
- Rate limiting (per-key / per-endpoint).
- Routing (`/users/*` → users service).
- Aggregation ("BFF" — Backend For Frontend — collapses multiple backend calls).
- Observability (metrics, tracing, logging).
- Versioning (`/v1/`, `/v2/`).

## C. Internal Working
1. Request arrives → TLS termination.
2. Auth check (JWT validation, API key lookup).
3. Rate limit check (Redis counter).
4. Route match.
5. Forward to backend; optionally aggregate.
6. Response → possibly transform → back to client.

## D. Visual Representation
```
[Client] → [API Gateway (auth, rate, route)] →  Users
                                                Orders
                                                Catalog
                                                …
```

### 🧱 What the gateway *should* know (and NOT know)

| ✅ Should know | ❌ Should NOT know |
|---|---|
| Auth (JWT validation, API key) | Domain business logic |
| Rate limits, quotas | How users are stored |
| Routing rules (`/api/v1/*` → svc A) | Which DB a service uses |
| Request/response transformation | Internal service contracts (unless you're building a BFF) |
| Aggregation for BFF (only if BFF pattern) | Service-to-service routing (use mesh) |

**Warning — the "god gateway" anti-pattern**: teams start shoveling business logic into the gateway because it's centralized. Two years later, deploying the gateway becomes scarier than any service deploy. Keep it dumb.

> **🔎 Quick Check** — Where should you validate the *shape* of an order payload: gateway or order service?
> **🎯 Recall** — Order service. Schema validation is business logic.

## E. Tradeoffs
**Pros**: one place for cross-cutting concerns, simpler clients.
**Cons**: SPOF without HA, can become a monolith of itself, latency added, team coupling risk.

## F. Interview Lens
- "API gateway vs reverse proxy?" — gateway is application-aware; reverse proxy generic.
- "Where does auth go?" — gateway for coarse, services re-check for fine-grained.
- Pitfalls: trying to put too much logic in the gateway.

## G. Real-World Mapping
AWS API Gateway, Kong, Apigee, Tyk, Zuul, Spring Cloud Gateway, Envoy.

## H. Questions
**Beginner**: What does an API gateway do?
**Intermediate**: BFF pattern?
**Advanced**:
1. Design a multi-tenant API gateway with per-tenant rate limits and custom auth.
2. Gateway vs service mesh — when each?

## I. Mini Design
Multi-service e-commerce:
- Gateway at edge; JWT auth; per-endpoint rate limiting (Redis sliding window).
- Routes: `/users`, `/orders`, `/catalog`, `/search`.
- Aggregates `/home` into users + cart + featured products → 1 client call.

## J. Cross-Topic Connections
- [Proxy](../foundations/networking/proxy.md), [Load Balancing](../foundations/scaling/load-balancing.md), [Rate Limiting](../reliability/rate-limiting.md), [Microservices](monolith-vs-microservices.md).

## K. Confidence Checklist
- [ ] Can name cross-cutting concerns.
- [ ] Knows BFF.

## L. Potential Gaps & Improvements
- Service mesh (Istio) overlap.
- GraphQL as an aggregation layer replacement.

---

### 🧭 Guided Deep-Learning Layer

#### 🕸️ Gap 1 — Service Mesh Overlap with API Gateway
- 🔹 **What it is**: Service mesh (Istio, Linkerd) handles east-west (service-to-service) traffic. API Gateway handles north-south (external-to-internal). Both do auth, retry, mTLS, observability — overlap at the boundary.
- 🔹 **Why it matters**: In 2026 architectures, the two coexist. Engineers often confuse them. The gateway sees public clients; the mesh sees internal services.
- 🔹 **Connection**: This file introduces API Gateway. Mesh is its internal counterpart — both are specialized reverse proxies at different positions.
- 🔹 **When needed**: 🔴 **Important for senior interviews** on microservice architectures.
- 🔹 **Intuition**: Gateway = hotel front desk. Mesh = internal phone system between hotel departments. Both handle "routing calls" but at different boundaries.
- 🔹 **If you go deeper**: Study how Istio's gateway (north-south) and Envoy sidecar (east-west) complement each other. Understand that both run Envoy under the hood, just configured differently.
- 🔹 **Interview hook**: *"Where does the gateway end and the service mesh begin?"* → gateway terminates external TLS + handles external concerns; mesh handles internal reliability + security.

---

#### 📊 Gap 2 — GraphQL as Aggregation Replacement (BFF alternative)
- 🔹 **What it is**: GraphQL can collapse multiple backend calls into one client request, replacing the "BFF" aggregation pattern of traditional API Gateways.
- 🔹 **Why it matters**: Modern mobile/web apps often prefer GraphQL over REST-with-BFF. Gateway's aggregation value decreases; its cross-cutting concerns stay.
- 🔹 **Connection**: The "aggregation" bullet in this file (BFF pattern) is sometimes better served by GraphQL. Know when each wins.
- 🔹 **When needed**: 🔴 **Important for frontend/mobile-facing senior interviews**.
- 🔹 **Intuition**: BFF = custom API tailored to one client. GraphQL = self-service; client picks what it needs. Same goal, different mechanism.
- 🔹 **If you go deeper**: Understand where GraphQL hurts — N+1 query problem, CDN caching, rate limiting per endpoint. Tools: Apollo Federation, GraphQL gateway.
- 🔹 **Interview hook**: *"You have 5 services and 3 client types (web, iOS, Android). Design the aggregation layer."* → BFF per client vs one GraphQL gateway; discuss tradeoffs.

---

### 🏆 Start here if you have limited time

Both gaps matter at senior level. **Service mesh overlap** is higher frequency — it comes up whenever microservices are mentioned.

---

### 🧭 Suggested Deep Dive Order

1. **Gateway vs Service Mesh boundaries** (~1h; frequent question).
2. **GraphQL vs BFF** (~1h; modern frontend interviews).
