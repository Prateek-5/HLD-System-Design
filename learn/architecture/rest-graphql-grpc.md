# REST, GraphQL, gRPC — Picking an API Style

## A. Intuition First
Three dominant API styles:
- **REST**: HTTP + resource URLs + verbs (GET/POST/PUT/DELETE). Public web default.
- **GraphQL**: client specifies exactly what it needs; one endpoint.
- **gRPC**: binary (protobuf) + HTTP/2; typed contracts; fast. Internal microservices default.

## B. Mental Model
| Style | Encoding | Schema | Discovery | Typical use |
|---|---|---|---|---|
| REST | JSON over HTTP | Informal (OpenAPI optional) | URL conventions | Public APIs |
| GraphQL | JSON, one endpoint | Schema (SDL) mandatory | Introspection | Mobile/frontend, complex aggregation |
| gRPC | Protobuf, HTTP/2 | .proto mandatory | Code-gen | Internal high-perf |

## C. Internal Working

### REST
- URLs = nouns, HTTP verbs = actions.
- Stateless.
- Caching via HTTP headers is free (`Cache-Control`, `ETag`).

### GraphQL
- Single endpoint `/graphql`.
- Client sends query specifying fields.
- Resolver functions fetch each field.
- Introspectable schema.
- N+1 problem common → dataloaders.

### gRPC
- Define service in `.proto`.
- Code-gen client + server for many languages.
- Binary encoding (small + fast).
- HTTP/2 → multiplexed streams, bi-directional streaming.

## D. Visual Representation
```
REST:     GET /users/123
GraphQL:  { user(id:123) { name, email, posts { title } } }
gRPC:     UserService.GetUser({id: 123})
```

## E. Tradeoffs
- **REST**: simple, cacheable, over- or under-fetches.
- **GraphQL**: flexible, no versioning (field deprecation instead), but complex server (N+1), hard to cache at CDN, harder to rate limit.
- **gRPC**: fast, typed, not browser-friendly (needs gRPC-web gateway), harder to debug manually (binary).

## F. Interview Lens
- "Public API: which?" — REST default, GraphQL if clients are diverse.
- "Internal services: which?" — gRPC default.
- "GraphQL N+1 problem?" — dataloader batching.
- Pitfalls: GraphQL for everything; REST for high-throughput internal microservices.

## G. Real-World Mapping
- REST: Stripe, Twilio, GitHub (v3).
- GraphQL: Facebook, GitHub (v4), Shopify Storefront.
- gRPC: Google internal, Uber, Netflix, k8s components.

## H. Questions
**Beginner**: REST methods (GET/POST/PUT/DELETE).
**Intermediate**:
1. Why gRPC faster than REST?
2. GraphQL vs REST on a mobile client.
**Advanced**:
1. Versioning strategies for REST (URL vs header).
2. GraphQL caching at scale.

## I. Mini Design
Public API: REST for simplicity + CDN caching. Mobile app: GraphQL to reduce round-trips. Internal service mesh: gRPC with protobuf contracts.

## J. Cross-Topic Connections
- [API Gateway](api-gateway.md), [Microservices](monolith-vs-microservices.md), [Caching](../foundations/scaling/caching.md).

## K. Confidence Checklist
- [ ] Can pick the right style per use case.
- [ ] Knows GraphQL N+1 fix.
- [ ] Knows gRPC's bindings/use case.

## L. Potential Gaps & Improvements
- REST maturity model (Richardson).
- gRPC-web and transcoding.
- OpenAPI / Swagger for REST contracts.
