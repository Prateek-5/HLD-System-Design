# API Design

> **📎 Prereqs** — If rusty:
> - HTTP status codes + verbs.
> - [`learn/architecture/rest-graphql-grpc.md`](../learn/architecture/rest-graphql-grpc.md) — style comparison.
> - JSON / JWT basics.

### 🔹 1. What This Topic Actually Is
Designing the shape of APIs that clients consume. Choice of style (REST/GraphQL/gRPC), versioning, contracts, errors, pagination, idempotency.

### 🔹 2. Why It Exists
- Bad APIs are forever — clients pin on them.
- Good API design is the visible face of system design.

### 🔹 3. Core Concepts (High Signal)
- **REST**: HTTP + resources + verbs. Default for public APIs.
  - Resources are nouns; `/users/123/orders`, not `/getUserOrders`.
  - Use correct status codes (200/201/204/400/401/403/404/409/422/429/500/503).
  - Pagination: offset+limit (hurts at scale) vs **cursor/keyset** (scalable).
- **GraphQL**: one endpoint, client specifies fields. Great for mobile / heterogeneous clients. Server costs: N+1, caching harder.
- **gRPC**: protobuf + HTTP/2. Internal microservices default.
- **Idempotency keys**: required for mutating endpoints; client-generated; server deduplicates within TTL.
- **Versioning**:
  - URL: `/v1/…` (explicit, public APIs).
  - Header: `Accept: application/vnd.app.v2+json` (cleaner for some).
  - GraphQL: field deprecation + schema evolution, no versioning URL.
- **Error contracts**: structured errors ({code, message, details}) — let clients handle programmatically.
- **Rate limits**: expose `X-RateLimit-*` headers + 429 + `Retry-After`.
- **HATEOAS**: links in responses → self-documenting API. Few real deployments use it.

### 🔹 4. Internal Working (good REST resource)
```
POST /v1/orders
Idempotency-Key: uuid-xyz
{ "items": [...], "address": {...} }

201 Created
Location: /v1/orders/42
{ "id": 42, "status": "pending", ... }
```

Retry-safe: client sends same Idempotency-Key → server returns cached 201 response from the first successful create.

### 🔹 5. Key Tradeoffs
- REST: simple, cacheable, verbose at scale.
- GraphQL: flexible, N+1 hazard, harder to cache at CDN.
- gRPC: fast + typed, not browser-native.
- Versioning in URL = explicit; in header = cleaner but invisible in logs.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. REST status codes for common cases.
2. Pagination — offset vs cursor.

**Intermediate 🟡**
1. Why idempotency keys?
2. Version REST via URL or header — tradeoffs.

**Advanced 🔴**
1. Design pagination for a 100M-row feed. (cursor, not offset.)
2. GraphQL at CDN — how do you cache?
3. Retry storms — client + server cooperation.

### 🔹 7. Real System Mapping
- **Stripe, GitHub, Twilio**: canonical REST APIs.
- **Shopify, GitHub v4**: GraphQL.
- **Google internal**: gRPC everywhere.
- **AirBnB "Building Services" blog**: classic API design write-up.

### 🔹 8. What Most People Miss
- **Idempotency is not optional** for mutating endpoints at scale.
- **Cursor pagination** is often overlooked — offset 1,000,000 is a killer query.
- **Rate limit headers** set client expectations — without them clients assume forever.
- **Backward compatibility** — adding fields is safe; removing is painful. Deprecate + sunset gracefully.
- **Small consistent error envelope** beats bespoke error shapes per endpoint.

### 🔹 9. 30-Second Revision
REST default public; GraphQL for flexible clients; gRPC internal. Idempotency keys on every mutating endpoint. Cursor pagination for scale. Structured error envelope. Version via URL for public. 429 + Retry-After for rate limit. Never break existing clients — deprecate.

---

## 🔗 Cross-Topic Connections
- **API Gateway**: enforces versioning, auth, rate limit.
- **Caching**: cacheability is an API design decision.
- **Microservices**: internal API contracts.
- **Rate limiting**: communicated via headers + 429.

---

### Confidence Check
- [ ] Can I pick style + design a resource in 5 min?
- [ ] Can I justify cursor over offset pagination?

### Gaps
- OpenAPI/Swagger codegen pipelines.
- gRPC streaming patterns.
