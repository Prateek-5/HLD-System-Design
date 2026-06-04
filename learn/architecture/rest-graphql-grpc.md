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
- **Richardson Maturity Model** — a 4-level scale (0–3) that grades how "RESTful" an API really is, from plain RPC up to hypermedia (HATEOAS); helps you argue whether an API is truly REST in an interview.
- **HATEOAS (Hypermedia As The Engine Of Application State)** — responses embed links telling the client what actions it can do next, so clients don't hardcode URLs; the top rung of the maturity model and rarely fully implemented in practice.
- **gRPC-Web** — a browser-friendly variant of gRPC that runs over normal HTTP/1.1 via a proxy, because browsers can't speak raw HTTP/2 gRPC frames; matters when you want gRPC but the client is a web page.
- **Protocol Transcoding (gRPC ↔ JSON/REST)** — a gateway auto-translates incoming REST/JSON calls into backend gRPC calls; lets you expose one service as both REST and gRPC without rewriting it.
- **OpenAPI / Swagger** — a machine-readable spec format describing REST endpoints, params, and schemas so you can auto-generate docs, client SDKs, and mock servers; the standard "contract" for REST.
- **Protocol Buffers (protobuf) / IDL (Interface Definition Language)** — the strongly-typed `.proto` schema that defines gRPC messages and generates client/server code; the gRPC equivalent of OpenAPI's contract.

**🔧 How to close:** Spin up a tiny gRPC server with reflection enabled, then explore it from the CLI with `grpcurl -plaintext localhost:50051 list` and `grpcurl -plaintext localhost:50051 describe` to see the protobuf-defined services; compare that to running `curl http://localhost:8080/openapi.json | jq '.paths'` against a REST service to feel how IDL-driven (gRPC) versus document-driven (OpenAPI) contracts differ.
