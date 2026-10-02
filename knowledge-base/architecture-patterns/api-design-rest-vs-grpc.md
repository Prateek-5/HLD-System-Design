# API Design — REST vs gRPC vs GraphQL

> *"Every API is a contract that outlives the team that designed it. The protocol you choose isn't a technology decision — it's a bet about who your future clients are, what they'll need, and how much you can change without breaking them."*

---

## Topic Overview

API design is where the abstract architecture of "services that talk to each other" meets the brutal reality of "we need to add a field and we have 47 client teams." The protocol decision — REST, gRPC, GraphQL, or some hybrid — shapes everything downstream: latency profiles, debuggability, evolution semantics, error handling, observability, the number of meetings you'll have with consumers.

There is no universally right answer. **REST** dominates public APIs for its discoverability, ubiquity, and minimal client requirements. **gRPC** dominates internal microservice communication for its performance, strict typing, and code generation. **GraphQL** carved a niche where clients need flexible query capabilities — typically aggregator backends serving many heterogeneous frontends.

This is the topic where the difference between "we shipped fast" and "we can keep shipping" is decided. APIs are not just protocols; they're commitments. Versioning, deprecation, error semantics, idempotency, pagination — the unglamorous parts of API design are what determines whether your API ages well or becomes an albatross.

---

## Intuition Before Definitions

Three ways to ask a librarian for books.

**REST.** You walk to specific shelves: "Fiction → Mystery → A-F → Christie." Each step is a URL. The shelves and books are *resources*. To get information about a book, you go to the book's shelf and look at it. To borrow a book, you take it off the shelf. The library's organization is part of the agreement — you and the librarian both understand "shelves" and "books" and the cardinal directions.

**gRPC.** You hand the librarian a typed request form: "Library.GetBookInfo({ id: 12345 })." The form has exact fields; the response has exact fields. Both of you compiled the form template from the same source. You don't navigate; you ask specific questions and get specific answers. Faster. Less flexible.

**GraphQL.** You hand the librarian a custom query: "For book 12345, give me the title, the author's birthdate, and a list of similar books with their average ratings." One query, one response, exactly what you need. The librarian does whatever lookups are required; you don't care how. But the librarian must be willing to handle arbitrary queries, including expensive ones.

Each style optimizes different things. REST optimizes for *shared vocabulary* (resources). gRPC optimizes for *typed efficiency*. GraphQL optimizes for *client flexibility*. The right choice depends on who's reading and who's writing.

---

## Historical Evolution

**Era 1 — RPC and the network-as-local fantasy.**
1980s-90s. CORBA, DCOM, Sun RPC. The dream: remote calls look like local calls. The reality: they failed differently. Thick clients, opaque error modes, version pain. Mostly abandoned for inter-org APIs by 2005.

**Era 2 — SOAP / WSDL.**
Late 90s, 2000s. XML over HTTP with formal schemas. Heavy, verbose, hard to debug. Survived in enterprise integration. Largely displaced by REST in web APIs.

**Era 3 — REST's rise.**
Roy Fielding's dissertation (2000) framed REST as an architectural style. The principles — stateless, cacheable, layered, uniform interface — matched HTTP's strengths. By 2010, REST + JSON was the default for web APIs. Twitter, Stripe, GitHub, AWS — all REST.

**Era 4 — gRPC and the internal API renaissance.**
Google's internal Stubby system, generalized as gRPC (2015). HTTP/2-based, protobuf-encoded, code-generated clients. Performance and type safety made it the default choice for new microservice architectures. Adoption strongest where REST's overhead bothered teams: low-latency services, polyglot environments.

**Era 5 — GraphQL.**
Facebook (2012, public 2015). Solved the problem of "mobile clients need different data than web clients, and shipping new endpoints is slow." Single endpoint, declarative queries, strong typing. Adopted by GitHub, Shopify, Netflix, PayPal. Polarizing — beloved by frontend teams, suspected by infrastructure teams.

**Era 6 — Pragmatic mixing.**
Modern systems often use *all three*: REST for public APIs (discoverability, ubiquity), gRPC for internal service-to-service (performance), GraphQL at the edge for client aggregation. The protocol choice is now a per-boundary decision, not an architectural commitment.

The pattern: each generation responded to the previous's failures. CORBA's complexity → SOAP's standardization → REST's simplicity → gRPC's performance → GraphQL's flexibility. The pendulum swings; the boundaries between styles blur.

---

## Core Mental Models

**1. APIs are contracts, not implementations.**
The contract — what fields exist, what they mean, when they change — is the durable thing. The implementation can be anything. Treat the contract as a first-class artifact: documented, versioned, owned.

**2. Backward compatibility is the most expensive feature you ship.**
Adding a field is cheap. Removing a field is a year-long migration. Renaming a field is the same. Every breaking change costs many client-team-weeks. Design APIs assuming you cannot break them.

**3. Latency budgets shape the protocol.**
A REST call is typically 100-500ms (TLS, JSON parsing, routing). A gRPC call is 10-50ms internal. A GraphQL query may aggregate dozens of upstream calls. Pick based on where you sit in the latency budget.

**4. Discoverability vs efficiency is the central tradeoff.**
REST's strength is a curl command works. gRPC's strength is wire-format and type efficiency. The difference shows up at scale and at the boundary between organizations.

**5. The protocol does not solve evolution; design does.**
Versioning, deprecation, additive evolution — these matter regardless of protocol. A poorly-designed REST API ages worse than a well-designed gRPC one, and vice versa.

---

## Deep Technical Explanation

### REST in detail

REST (Representational State Transfer) principles:
- **Resources identified by URLs**: `/users/123`, `/users/123/orders`.
- **HTTP methods as verbs**: GET (read), POST (create), PUT/PATCH (update), DELETE (delete).
- **Stateless**: each request is independent.
- **Cacheable**: responses indicate whether they can be cached.
- **HATEOAS** (Hypermedia as the Engine of Application State): responses include links to related resources. Almost universally ignored in practice; "REST" in production usually means "URLs + HTTP verbs + JSON."

Strengths:
- **Universal tooling**. curl, Postman, browsers, every language.
- **HTTP semantics**: caching, status codes, ranges, ETags.
- **Easy to debug**: text-based, human-readable.
- **No code generation** required.

Weaknesses:
- **Verbose** (JSON over HTTP/1.1).
- **No type safety** at the wire level. Clients and servers can drift.
- **N+1 patterns** common (fetch user, then fetch each order, then each item).
- **Versioning is hard** (URL versioning, header versioning — no consensus).

### REST status codes — the language

A canonical mapping:
- **200 OK** — success.
- **201 Created** — resource created (use for POST that creates).
- **204 No Content** — success, no body (DELETE confirmations).
- **400 Bad Request** — client error (malformed input).
- **401 Unauthorized** — missing or invalid auth.
- **403 Forbidden** — authenticated, but not allowed.
- **404 Not Found** — resource doesn't exist.
- **409 Conflict** — state conflict (e.g., version mismatch).
- **422 Unprocessable Entity** — validation error.
- **429 Too Many Requests** — rate limited.
- **500 Internal Server Error** — server bug.
- **502/503/504** — gateway/service unavailable.

Misusing status codes (returning 200 with `{ "error": "..." }`) is a common antipattern that breaks tooling and caching. Use the status codes the protocol gives you.

### gRPC in detail

gRPC = HTTP/2 + Protocol Buffers + code generation.

Define services in `.proto` files:

```proto
service UserService {
  rpc GetUser(GetUserRequest) returns (User);
  rpc StreamUsers(StreamRequest) returns (stream User);
}

message User {
  string id = 1;
  string email = 2;
  int64 created_at = 3;
}
```

The compiler generates client and server stubs in any supported language (Go, Java, Python, C++, JS, etc.). Clients call methods like local function calls; the framework handles serialization, networking, and error propagation.

Strengths:
- **Strong typing** at the wire level. Field tag numbers preserve compatibility across versions.
- **Efficient encoding** (binary protobuf, not text JSON). Often 5-10× smaller and faster.
- **HTTP/2 multiplexing** (no head-of-line blocking; many concurrent calls per connection).
- **Streaming** (server-side, client-side, bidirectional) as a first-class primitive.
- **Code generation** keeps clients and servers in sync.

Weaknesses:
- **Browser support** is limited (gRPC-Web is a workaround but not full parity).
- **Binary format** harder to debug without tooling.
- **Tighter coupling** to the schema — both ends must regenerate code on schema changes.
- **Tooling ecosystem** thinner than REST's.

### Protobuf evolution rules

The schema can evolve safely if you follow rules:
- **Never reuse field tag numbers.** A removed field's tag is reserved forever.
- **New fields must be optional**. Default to a sensible zero value.
- **Don't change field types.** Adding a new field with a new tag is the way.
- **Removing required fields** is a breaking change; make fields optional or use markers.

These rules are battle-tested at Google scale. Followed religiously, they let services evolve indefinitely without breaking clients.

### GraphQL in detail

A typed schema describes available types and operations:

```graphql
type User {
  id: ID!
  email: String!
  orders: [Order!]!
}

type Query {
  user(id: ID!): User
}
```

Clients send queries describing exactly what they want:

```graphql
{
  user(id: "123") {
    email
    orders {
      total
      items { name price }
    }
  }
}
```

The server resolves each field by calling the appropriate backend (often other services). Returns exactly the requested shape.

Strengths:
- **Client-driven shape**. No over-fetching, no under-fetching.
- **One endpoint** instead of many.
- **Strong typing** with introspection.
- **Single round-trip** for related data.

Weaknesses:
- **Server complexity**. Each field needs a resolver; resolvers can fan out unbounded.
- **Caching is hard**. HTTP-level caching doesn't apply (everything is POST to one URL).
- **N+1 patterns** appear at the resolver level if not careful (DataLoader pattern is essential).
- **Authorization complexity**. Field-level auth is harder than endpoint-level auth.
- **Queries can be expensive**. Clients can request deeply nested or wide queries; protection (depth limits, complexity scoring) is necessary.

### Versioning strategies

REST:
- **URL-based**: `/v1/users`, `/v2/users`. Easy. Clutters the URL space.
- **Header-based**: `Accept: application/vnd.api+json; version=2`. Cleaner. Less discoverable.
- **No version, additive only**: add fields; never remove. Risky long-term.

gRPC:
- **New service version as a new package**: `users.v1.UserService`, `users.v2.UserService`. Clean.
- **Field tag discipline**: protobuf rules enable additive evolution within a version.

GraphQL:
- **Deprecation, not versioning**: add new fields; mark old ones `@deprecated`. Schema is forever-additive. Old fields linger but are signaled out.

The deeper truth: **all evolution is the same problem regardless of protocol.** Add new things; don't break old things; deprecate clearly; remove only after everyone's migrated.

### Pagination

Three common patterns:

1. **Offset-based**: `?offset=20&limit=10`. Easy. Brittle: if items are added/removed mid-iteration, offsets shift. Bad for deep pagination (offset=10000 means database scans 10000 rows).
2. **Cursor-based**: server returns an opaque cursor; client sends it for next page. Stable across modifications. Standard for any non-trivial list.
3. **Keyset-based**: client sends the last seen ID; server returns items after it. Simple, fast, stable. Doesn't allow "page 5 directly."

Cursor pagination is the production-grade choice. Don't use offset for anything you might paginate deeply.

### Idempotency in API design

State-changing operations need idempotency keys. Pattern:

```
POST /charges
Idempotency-Key: ck_abc123def456
{
  "amount": 1000,
  "currency": "usd"
}
```

The server stores the response keyed by `Idempotency-Key` for some window (24h). Subsequent requests with the same key return the cached response without re-executing.

This is mandatory for any non-idempotent operation that retries are possible against. (See [timeouts-retries-and-idempotency.md](../system-failures/timeouts-retries-and-idempotency.md).)

### Errors

REST: HTTP status code + structured body:

```json
{
  "error": {
    "code": "card_declined",
    "message": "The card was declined.",
    "doc_url": "https://docs.example.com/errors/card_declined"
  }
}
```

gRPC: status codes (OK, INVALID_ARGUMENT, NOT_FOUND, PERMISSION_DENIED, RESOURCE_EXHAUSTED, etc.) + structured details via `google.rpc.Status`.

GraphQL: errors in the response body alongside data. Partial success is possible — some fields fail while others succeed.

The principle: **errors should be machine-actionable**. A code that the client can branch on. A message for humans. A doc link for debugging. Stack traces only in dev.

---

## Real Engineering Analogies

**The restaurant menu vs the chef's table.**
REST is the menu — explicit dishes, discoverable, with a printed price. Anyone can walk in and order. Standardized.

gRPC is the chef's table — you and the chef use a shared vocabulary; you say "the usual" and the chef knows. Less accessible to strangers; far more efficient for regulars.

GraphQL is the buffet — you pick exactly what you want, in any combination. Costs more to operate (you have to keep everything ready); empowers the diner.

Real businesses run all three: a public menu, a chef's table for VIPs, a buffet for events. The "right" model depends on who's eating.

**The driving directions analogy.**
REST: turn-by-turn directions, with named landmarks. You know where you are, where you're going, and the streets between.

gRPC: GPS coordinates and a teleporter. Direct, fast, no scenery.

GraphQL: a custom helicopter route to your exact destination. Fastest for your specific trip; expensive infrastructure.

---

## Production Engineering Perspective

What goes wrong in API design:

- **The breaking change that wasn't supposed to break.** A team renames a field "for clarity." Old clients break. Production incident. Lesson: any wire-visible change is a breaking change.
- **The error format inconsistency.** Three teams, three error formats. Clients write three error parsers. Effort wasted on parsing. Standardize early.
- **The unbounded GraphQL query.** Client requests `user.friends.friends.friends.posts.comments.author.friends`. Server fans out millions of database calls. Database melts. Mitigation: query depth limits, complexity scoring, persisted queries.
- **The N+1 in REST.** Client fetches `/orders`, then for each order fetches `/users/{userId}`. 100 orders = 101 requests. Mitigation: include user info in the orders response (denormalization), or provide a batch endpoint.
- **The protobuf field tag reuse.** A removed field's tag is reused for a new field. Old clients deserialize garbage. Lesson: tags are forever; use `reserved` to enforce this.
- **The version proliferation.** v1, v2, v3, v4... five versions of every endpoint, all maintained. Eventually impossible. Aggressively migrate clients off old versions; communicate deprecation timelines.
- **The auth confusion in GraphQL.** A query joins data from sources with different auth requirements. Some fields are accessible; others aren't. The query partial-fails in surprising ways. Mitigation: field-level authorization, careful resolver design.
- **The latency cliff.** REST endpoint at p99=200ms. New "convenience endpoint" aggregates 5 internal calls. p99=900ms (the slowest of 5 + overhead). Surprised teams.
- **The cache poisoning via vary headers.** Caching layer keys responses on URL only. Different `Accept-Language` headers produce different content; cache returns wrong language to wrong users. Always include relevant `Vary` headers or use cache keys that account for them.

The senior API designer's habits:
- **Document the contract** as a first-class artifact (OpenAPI for REST, .proto for gRPC, schema for GraphQL).
- **Version explicitly** from day one, even for internal APIs.
- **Always paginate** with cursors.
- **Always idempotency-key** for state changes.
- **Define errors** with codes, not just status.
- **Limit GraphQL query complexity** in production.
- **Generate clients** from the schema in supported languages.
- **Track deprecation** with metrics — when can you remove a field?

---

## Failure Scenarios

**Scenario 1 — The silent breaking change.**
A team renames `customerId` to `customer_id` "for consistency." Frontend deploys break. Mobile clients have stored the old field name. Hours of incident. Recovery: revert; add an alias for backward compatibility; coordinate a long deprecation.

**Scenario 2 — The runaway GraphQL query.**
A debugging client constructs a 10-level-deep query. Server resolvers fan out to thousands of database calls. Database CPU 100%. Other queries fail. Mitigation: depth limits at the GraphQL gateway; persisted queries (only allow pre-registered queries in production).

**Scenario 3 — The retry storm via misuse.**
Client treats 500 errors as retryable. A bug returns 500 for permanent failures (e.g., "user not found"). Client retries indefinitely. Effective DoS. Lesson: 5xx is retryable; 4xx is not. Don't return 500 for client errors.

**Scenario 4 — The protobuf compatibility break.**
A field is changed from `int32` to `string`. Old clients now see corrupted data (silently, no error). Discovered weeks later when reports look wrong. Lesson: type changes are breaking; add a new field with a new tag.

**Scenario 5 — The pagination drift.**
Offset-based pagination over a list that changes. Client fetches pages 1, 2, 3. Items added to the list shift the offsets. Page 2 contains items already seen on page 1. Items skipped or duplicated. Mitigation: cursor-based pagination.

---

## Performance Perspective

- **gRPC is typically 5-10× faster** than REST for equivalent payloads (binary vs JSON, HTTP/2 vs HTTP/1.1).
- **JSON parsing is non-trivial CPU cost** at high QPS.
- **HTTP/2 multiplexing** means many parallel requests on one connection — both REST-over-HTTP/2 and gRPC benefit.
- **GraphQL adds a hop** (client → GraphQL gateway → backends) that costs latency.
- **TLS handshake** is a latency cost; connection pooling mitigates.
- **Compression** (gzip, brotli) trades CPU for network. Often net win.

---

## Scaling Perspective

- **Stateless APIs scale horizontally** by load balancing.
- **GraphQL federation** (Apollo Federation) splits a unified schema across multiple services. Powerful and operationally complex.
- **Rate limiting** at the API gateway protects backends.
- **Caching at the edge** (CDN) for cacheable REST responses.
- **API gateway as bottleneck**: every API call hits it. Sized accordingly.
- **At very large scale**: REST/gRPC/GraphQL all cap out at network throughput per service; horizontal scale is the answer.

---

## Cross-Domain Connections

- **Idempotency**: every state-changing API needs idempotency keys. (See [timeouts-retries-and-idempotency.md](../system-failures/timeouts-retries-and-idempotency.md).)
- **Caching**: REST's HTTP semantics enable edge caching; gRPC and GraphQL require application-level caching. (See [caching-hierarchy.md](../caching/caching-hierarchy.md).)
- **Backpressure**: API gateway is where rate limiting and concurrency limits are enforced. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Observability**: traces propagate across API boundaries via headers (`traceparent`). (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)
- **Sagas**: APIs are often the entry points for sagas; idempotency keys flow from the API to the saga steps. (See [saga-pattern-and-distributed-transactions.md](./saga-pattern-and-distributed-transactions.md).)
- **CQRS**: GraphQL fits well with CQRS read models — flexible queries on denormalized data. (See [cqrs-and-event-sourcing.md](./cqrs-and-event-sourcing.md).)

The unifying observation: **APIs are where the rest of distributed systems theory becomes user-visible.** Latency, idempotency, error handling, retries — they all manifest in the API contract.

---

## Real Production Scenarios

- **Stripe's API design philosophy**: extensive public engineering posts on REST, idempotency keys, error codes, deprecation strategy. Widely studied as a "how to do APIs right" reference.
- **GitHub's REST → GraphQL evolution**: introduced GraphQL alongside REST v3; now GraphQL v4 is preferred for many use cases. Public posts describe motivations and tradeoffs.
- **Google's gRPC adoption**: most internal services use gRPC. Public APIs often use REST for ecosystem compatibility.
- **Shopify's GraphQL Admin API**: large-scale GraphQL deployment. Documented patterns for query complexity, persisted queries, federation.
- **Twitter API v2**: complete redesign after years of v1 cruft. A case study in "how do you migrate clients off a legacy API?" — answer: very slowly, with overlap.
- **AWS API style**: REST-ish with AWS-specific quirks (signed requests, error formats). Reference point for "very large public API surface."

---

## What Junior Engineers Usually Miss

- That **API contracts outlive the team that designed them**.
- That **renaming a field is a breaking change**.
- That **status codes have semantic meaning** that tooling depends on.
- That **idempotency is mandatory** for retryable state-changing endpoints.
- That **offset pagination breaks** under modifications.
- That **GraphQL queries can be unbounded** without protection.
- That **field tag numbers in protobuf are forever**.
- That **versioning starts on day one**, not "when we need it."

---

## What Senior Engineers Instinctively Notice

- They **document the API contract** as a first-class artifact.
- They **version explicitly** and plan deprecations.
- They **use cursor pagination** by default.
- They **standardize error formats** across all APIs.
- They **enforce protobuf evolution rules** in code review.
- They **limit GraphQL complexity** at the gateway.
- They **provide idempotency keys** for state changes.
- They **distinguish public from internal API design** (different tradeoffs).

---

## Interview Perspective

What gets tested:

1. **"REST vs gRPC vs GraphQL — when each?"** Senior answer: public discoverability → REST; internal performance → gRPC; client-driven shape → GraphQL.
2. **"How would you version this API?"** Multiple acceptable answers; the candidate should articulate tradeoffs.
3. **"How do you handle pagination?"** Cursor-based; explain why.
4. **"How do you handle errors?"** Status code + structured body + machine-readable error code.
5. **"What's a breaking change?"** Anything that requires existing clients to update.
6. **"How would you migrate clients off a deprecated endpoint?"** Long deprecation window, metrics, deprecation headers, eventual hard cutoff.
7. **"How do you design an idempotent POST?"** Idempotency keys; explain.

Common traps:
- Returning 200 with `{ "error": "..." }`.
- Reusing protobuf field tags.
- Believing GraphQL "eliminates" backend complexity.
- Treating PUT as POST or vice versa.

---

## 20% Knowledge Giving 80% Understanding

1. **REST = resources + HTTP verbs**, public-facing.
2. **gRPC = HTTP/2 + protobuf + codegen**, internal, fast.
3. **GraphQL = client-driven queries**, edge aggregation.
4. **Versioning starts day one**. Use what your protocol supports.
5. **Cursor pagination only** for any non-trivial list.
6. **Idempotency keys** for state-changing ops.
7. **Status codes are semantic**. Don't return 200 for errors.
8. **Error formats: code + message + doc link**.
9. **Protobuf field tags are forever.**
10. **Limit GraphQL query complexity**.

---

## Final Mental Model

> **Pick the protocol for the boundary, not for the company. Public APIs need discoverability. Internal services need efficiency. Edge aggregators need flexibility. The right architecture often uses all three at once — and the engineering work is at the seams.**

The senior API designer thinks first about *who's calling*, then about *how often it'll change*, then about *what failures look like*, then about the protocol. Usually the protocol decision is straightforward once those questions are answered. The hard work is in the contract: pagination, idempotency, errors, versioning, deprecation. These are protocol-agnostic and arguably more important than the wire format.

The systems that age gracefully are the ones with disciplined API contracts. The systems that calcify under their own weight are the ones with inconsistent versions, ad-hoc errors, and breaking changes shipped under "small refactors." The protocol is a tool. The contract is the architecture.

That's API design. That's the layer between every two services in production. That's the part of the system that touches every user, every client, every integration — and the part where engineering discipline pays compound interest for years.
