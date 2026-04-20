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
