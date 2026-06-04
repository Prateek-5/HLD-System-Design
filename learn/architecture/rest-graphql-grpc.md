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

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 📜 Gap 1 — Contracts & Schema: OpenAPI vs Protobuf IDL
- 🔹 **What it is**: A machine-readable description of an API — OpenAPI/Swagger for REST, and `.proto` (Protocol Buffers IDL) for gRPC — that documents endpoints/messages and can auto-generate docs, client SDKs, and mock servers.
- 🔹 **Why it matters**: The contract is what actually lets teams build against an API without reading source code; "do you generate clients from a schema?" separates a hand-rolled JSON API from a production one.
- 🔹 **Connection**: Section B calls REST's schema "informal (OpenAPI optional)" while gRPC's `.proto` is mandatory — this gap explains *why* that single difference drives so much of the tooling, type-safety, and onboarding story.
- 🔹 **When needed**: 🟢 **Foundational** — almost every backend role touches an OpenAPI spec or a `.proto` file.
- 🔹 **Intuition**: A LEGO instruction booklet. With the booklet (schema) anyone can assemble the same model; without it, every builder guesses and the pieces don't fit.
- 🔹 **If you go deeper**: Read the OpenAPI 3.1 spec and the Protocol Buffers language guide; generate a typed client with `openapi-generator` and a gRPC stub with `protoc`, and compare the developer experience.
- 🔹 **Interview hook**: *"How do clients stay in sync with your API as it changes?"* → A versioned schema (OpenAPI/`.proto`) is the source of truth; codegen and CI contract-checks catch breaking changes before they ship.

---

#### 🪜 Gap 2 — Richardson Maturity Model & HATEOAS
- 🔹 **What it is**: A 4-level scale (0–3) grading how "RESTful" an API is — from plain RPC, through resources and HTTP verbs, up to HATEOAS, where responses embed links telling the client what it can do next.
- 🔹 **Why it matters**: It gives you precise language to argue whether an API is *truly* REST, and HATEOAS explains why "true REST" is rare — most "REST" APIs stop at level 2.
- 🔹 **Connection**: Section A calls REST "HTTP + resource URLs + verbs" — that's exactly Richardson level 2. This gap names the levels above and below so you can place any real API on the ladder.
- 🔹 **When needed**: 🟡 **Mid-level** — useful for API-design discussions; HATEOAS itself is mostly theory.
- 🔹 **Intuition**: A choose-your-own-adventure book. HATEOAS responses hand you the page numbers (links) for every next move, so you never memorize the whole book up front.
- 🔹 **If you go deeper**: Read Leonard Richardson's original talk and Roy Fielding's 2008 "REST APIs must be hypertext-driven" post; inspect a HATEOAS-style API like PayPal's or the GitHub API's `_links`/`url` fields.
- 🔹 **Interview hook**: *"Is your API actually REST?"* → Place it on the Richardson model; most stop at level 2 (resources + verbs), and that's usually the pragmatic right call.

---

#### 🌐 Gap 3 — gRPC in the Browser: gRPC-Web & Protocol Transcoding
- 🔹 **What it is**: Two bridges that make gRPC usable outside a service mesh — gRPC-Web lets browsers (which can't speak raw HTTP/2 gRPC frames) call gRPC via a proxy, and transcoding lets a gateway translate incoming REST/JSON into backend gRPC calls.
- 🔹 **Why it matters**: It resolves the file's stated gRPC weakness ("not browser-friendly") and lets one backend serve both internal gRPC clients and external REST/web clients without a rewrite.
- 🔹 **Connection**: Section E flags gRPC as "not browser-friendly (needs gRPC-web gateway)" — this gap is the concrete mechanism, plus the transcoding path that exposes the same service as REST.
- 🔹 **When needed**: 🟡 **Mid-level** — relevant the moment a gRPC backend needs a web or public-facing client.
- 🔹 **Intuition**: A hotel front desk that takes phone bookings (REST/JSON) and walk-ins, then relays both to the back office in its own internal shorthand (gRPC). Guests never learn the shorthand.
- 🔹 **If you go deeper**: Try the `grpc-web` project with Envoy as the proxy, and `grpc-gateway` (or Google Cloud Endpoints) for JSON↔gRPC transcoding driven by `google.api.http` annotations.
- 🔹 **Interview hook**: *"You picked gRPC internally but the frontend is a React app — now what?"* → gRPC-Web through an Envoy proxy, or a transcoding gateway exposing REST/JSON at the edge.

---

#### 🚦 Gap 4 — GraphQL at Scale: N+1, Caching, and Rate Limiting
- 🔹 **What it is**: The hard operational problems of running GraphQL in production — the N+1 resolver explosion (fixed with DataLoader batching), the loss of cheap HTTP/CDN caching, and the difficulty of rate-limiting a single flexible endpoint.
- 🔹 **Why it matters**: GraphQL's flexibility moves cost onto the server; "how do you cache and protect a GraphQL API?" is a classic senior follow-up that flat REST never raises.
- 🔹 **Connection**: Section C names the "N+1 problem → dataloaders" and Section E says GraphQL is "hard to cache at CDN, harder to rate limit" — this gap unifies all three into the full at-scale story.
- 🔹 **When needed**: 🔴 **Senior** — these tradeoffs surface in API-platform and performance design rounds.
- 🔹 **Intuition**: A build-your-own-burrito line. Customers love the freedom, but the kitchen can't pre-make trays (CDN cache) and must police anyone ordering 50 toppings (query-cost limits).
- 🔹 **If you go deeper**: Study DataLoader's batching/caching, persisted queries + APQ for CDN caching, and query-cost-analysis / depth-limiting (Apollo Server, GitHub's GraphQL point system).
- 🔹 **Interview hook**: *"Why is GraphQL harder to cache and rate-limit than REST?"* → One POST endpoint with a variable query body defeats URL-based CDN caching and per-route limits; you cache via persisted queries and limit by computed query cost.

---

### 🏆 Start here if you have limited time
1. **Contracts & schema (OpenAPI vs protobuf)** — foundational and shows up in nearly every backend interview and codebase.
2. **GraphQL at scale (N+1, caching, rate limiting)** — the highest-signal senior follow-up if you ever mention GraphQL.

---

### 🧭 Suggested Deep Dive Order
1. **Contracts & schema: OpenAPI vs protobuf IDL** (~45 min; foundational, unlocks codegen and contract-testing).
2. **Richardson Maturity Model & HATEOAS** (~30 min; sharpens your "is this really REST?" vocabulary).
3. **gRPC-Web & protocol transcoding** (~1h; the practical bridge for browser/public clients).
4. **GraphQL at scale: N+1, caching, rate limiting** (~1.5h; senior-level depth and the strongest interview payoff).
