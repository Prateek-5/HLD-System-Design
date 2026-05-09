# gRPC Internals & Streaming

> *"gRPC took the best ideas from Google's internal Stubby — binary serialization, code generation, streaming, deadlines — and shipped them as the open-source default for service-to-service RPC. Where REST is a convention layered over HTTP, gRPC is an opinionated framework with the wire format, the runtime, and the API contract all carefully co-designed."*

---

## Topic Overview

gRPC is a high-performance RPC framework. The pieces: **Protocol Buffers** for schema and serialization; **HTTP/2** as transport; **code generation** for client/server stubs; **streaming** as a first-class primitive (server-side, client-side, bidirectional). Used internally at Google for years; open-sourced 2015; now standard for modern microservice communication.

The wins over REST: significantly less wire overhead (binary vs text); cross-language type safety (one schema, generated code in every language); built-in streaming; built-in deadlines and metadata; HTTP/2 multiplexing (one connection, many concurrent calls).

The trade-offs: less browser-friendly (gRPC-Web is a workaround); harder to debug without tooling (binary on the wire); tighter coupling to schema (clients and servers must regenerate on changes).

This is the topic that explains why "gRPC for internal, REST for external" is the modern default. Understanding the internals — protobuf wire format, HTTP/2 streams, deadline propagation — shapes architecture choices and debugging skills.

---

## Intuition Before Definitions

Imagine two ways for a customer to order from a restaurant.

**REST.** Customer says in plain English: "I'd like a burger, medium, with fries." Waiter writes it down. Goes to kitchen. Cook reads the order. Confirms it. Plain language; flexible; verbose.

**gRPC.** Customer and waiter share a printed menu with codes. Customer says "B-2-M-F" (Burger #2, Medium, with Fries). Waiter writes the code. Cook reads codes. Concise; less ambiguity; both sides must understand the code system.

In return: faster service, fewer translation errors, no language barriers between customer and cook. The cost: rigid; if the menu changes, both sides must update.

That's gRPC vs REST. Schema (the menu); binary encoding (the codes); code generation (everyone reads from the same printed menu). For internal services where speed and correctness matter more than discoverability, gRPC wins.

---

## Historical Evolution

**Era 1 — Stubby (Google internal, 2001+).**
Google's internal RPC framework. Polyglot, performant, used everywhere. Inaccessible to the outside.

**Era 2 — Protocol Buffers open-sourced (2008).**
Google releases protobuf — the schema/serialization layer. Adopted broadly even outside RPC contexts.

**Era 3 — gRPC open-sourced (2015).**
The RPC framework on top of protobuf, using HTTP/2. Steady adoption.

**Era 4 — CNCF graduation (2019).**
gRPC becomes a CNCF graduated project. Production use at Netflix, Square, Lyft, many others.

**Era 5 — Service mesh integration.**
Envoy speaks gRPC natively; Istio routes gRPC like HTTP/2; observability tooling matures.

**Era 6 — Modern usage.**
gRPC is the default for new internal microservices in many shops. REST remains for external APIs. GraphQL fills client-aggregator role.

The pattern: gRPC won the internal-RPC race. The combination of protobuf + HTTP/2 + code generation is hard to beat for service-to-service.

---

## Core Mental Models

**1. gRPC = HTTP/2 + protobuf + code generation.**
Each piece is independently useful; together they're a coherent framework.

**2. Streaming is first-class.**
Four call types: unary, server streaming, client streaming, bidirectional streaming. Use the right one for the work.

**3. Deadlines propagate.**
A request with a 1-second deadline tells every downstream call: "you have ≤1 second from when this started." Naturally bounds end-to-end latency.

**4. Schema is the contract.**
Both sides regenerate code from the same `.proto`. Type safety enforced at compile time.

**5. Wire format is binary.**
Protobuf's tag-and-value encoding is compact, fast, schema-driven. Powerful but harder to debug than JSON.

---

## Deep Technical Explanation

### Protocol Buffers

A schema language:

```protobuf
syntax = "proto3";

message User {
  string id = 1;
  string email = 2;
  int64 created_at = 3;
  repeated string roles = 4;
}

service UserService {
  rpc GetUser(GetUserRequest) returns (User);
  rpc ListUsers(ListUsersRequest) returns (stream User);
  rpc UpdateUsers(stream User) returns (UpdateUsersResponse);
  rpc Chat(stream ChatMessage) returns (stream ChatMessage);
}
```

Properties:
- Each field has a *tag number* (1, 2, 3, ...) — the on-the-wire identifier.
- Fields are *optional* by default in proto3.
- Schema evolution rules: never reuse tag numbers; new fields are optional with defaults; never change types.

Code generation: `protoc` produces client and server stubs in any supported language (C++, Java, Python, Go, JS, Rust, etc.).

### Wire format

Each field on the wire: `(tag_number, wire_type)` + value.

Wire types:
- 0: varint (int32, int64, bool, enum)
- 1: 64-bit (fixed64, double)
- 2: length-delimited (string, bytes, embedded messages, repeated fields)
- 5: 32-bit (fixed32, float)

Varint encoding: small integers take 1 byte; large take more. Bandwidth-efficient for typical values.

A `User { id: "abc", email: "a@b.com" }` is roughly 15-20 bytes. The same JSON: 50+ bytes. Difference compounds at scale.

### HTTP/2 transport

gRPC uses HTTP/2 for transport:
- One connection per server (typically); many concurrent streams.
- Each RPC = one HTTP/2 stream.
- Headers in HPACK; body is the protobuf bytes.
- Trailers carry status (success or error code).

A unary call: client opens stream → sends request frame → server responds with response frame + trailers → stream closes.

A streaming call: stream stays open; multiple data frames; trailers when done.

### The four call types

**Unary.** Standard request-response.

```protobuf
rpc GetUser(GetUserRequest) returns (User);
```

```python
user = await stub.GetUser(GetUserRequest(id="123"))
```

**Server streaming.** Client sends one request; server sends a stream of responses.

```protobuf
rpc ListUsers(ListUsersRequest) returns (stream User);
```

```python
async for user in stub.ListUsers(ListUsersRequest(limit=1000)):
    print(user)
```

Used for: large result sets; live updates; long-running queries.

**Client streaming.** Client sends a stream; server sends one response.

```protobuf
rpc UpdateUsers(stream User) returns (UpdateUsersResponse);
```

```python
async def updates():
    for u in batch:
        yield u
response = await stub.UpdateUsers(updates())
```

Used for: bulk uploads; aggregation.

**Bidirectional streaming.** Both sides stream concurrently.

```protobuf
rpc Chat(stream ChatMessage) returns (stream ChatMessage);
```

```python
async def send():
    async for msg in user_input:
        yield msg

async for msg in stub.Chat(send()):
    display(msg)
```

Used for: chat; real-time collaboration; long-lived conversational interactions.

### Deadlines

Every gRPC call has a deadline (or none, by default — which is bad practice).

```python
user = await stub.GetUser(
    GetUserRequest(id="123"),
    timeout=0.5  # seconds
)
```

The deadline propagates: when this server calls another service, it passes a deadline ≤ remaining time. Naturally bounds end-to-end latency; no infinite waits.

In Go:
```go
ctx, cancel := context.WithTimeout(ctx, 500*time.Millisecond)
defer cancel()
user, err := client.GetUser(ctx, &pb.GetUserRequest{Id: "123"})
```

Setting deadlines is non-negotiable in production. The default is "wait forever," which produces well-known cascading-failure modes.

### Status codes

gRPC has its own status codes, not HTTP:

- `OK` (0)
- `CANCELLED` (1)
- `INVALID_ARGUMENT` (3)
- `DEADLINE_EXCEEDED` (4)
- `NOT_FOUND` (5)
- `ALREADY_EXISTS` (6)
- `PERMISSION_DENIED` (7)
- `RESOURCE_EXHAUSTED` (8) — rate limited
- `FAILED_PRECONDITION` (9)
- `ABORTED` (10)
- `OUT_OF_RANGE` (11)
- `UNIMPLEMENTED` (12)
- `INTERNAL` (13)
- `UNAVAILABLE` (14)
- `UNAUTHENTICATED` (16)

Each maps to a clear semantic. Clients can distinguish "retry-safe" (`UNAVAILABLE`) from "give up" (`INVALID_ARGUMENT`).

### Metadata

gRPC equivalent of HTTP headers:

```python
metadata = (("authorization", "Bearer ..."), ("trace-id", "abc123"))
user = await stub.GetUser(req, metadata=metadata)
```

Used for: auth tokens, tracing context, custom headers. Travels in HTTP/2 headers; can also be in trailers.

### Interceptors

Middleware for cross-cutting concerns:

```python
class AuthInterceptor:
    async def intercept_unary_unary(self, continuation, client_call_details, request):
        new_metadata = add_auth(client_call_details.metadata)
        new_details = client_call_details._replace(metadata=new_metadata)
        return await continuation(new_details, request)
```

Common interceptors: auth, logging, metrics, retry, circuit breaker, distributed tracing.

### Load balancing

gRPC supports multiple LB strategies:

**pick_first**: connect to the first reachable server; stay until it fails.

**round_robin**: rotate across servers.

**xds**: use xDS protocol (Envoy/service mesh).

Client-side LB is common: client knows the list of servers; picks each call. Avoids middlebox latency.

In Kubernetes: gRPC clients need a "headless" service to see individual pod IPs (otherwise load balancing happens once at DNS lookup, not per call).

### Retry and circuit breaking

gRPC has built-in retry policy via service config:

```json
{
  "methodConfig": [{
    "name": [{"service": "user.UserService", "method": "GetUser"}],
    "retryPolicy": {
      "maxAttempts": 3,
      "initialBackoff": "0.1s",
      "maxBackoff": "1s",
      "backoffMultiplier": 2,
      "retryableStatusCodes": ["UNAVAILABLE"]
    }
  }]
}
```

Service mesh (Envoy) provides retries at the proxy level. Avoid double-retrying.

### gRPC-Web

Browsers don't support HTTP/2 trailers correctly for gRPC. gRPC-Web is a translation:
- Browser sends gRPC-Web format (similar to gRPC but adapted).
- Proxy (Envoy) translates to gRPC for the backend.

Works; less efficient than native gRPC; use cases where gRPC is desirable from frontend.

Connect (by Buf) is an alternative that simplifies this further.

### gRPC vs alternatives

**vs REST**: gRPC is faster, more strongly typed, better at streaming. REST is more discoverable, browser-friendly, simpler to debug.

**vs GraphQL**: GraphQL is client-driven; gRPC is server-defined. GraphQL aggregates; gRPC RPCs are simple calls. Different use cases.

**vs custom binary protocols**: gRPC has the ecosystem, the tooling, the multi-language support. Roll-your-own is rarely worth it.

### Production challenges

**Schema evolution.** Tags are forever. Forget that → silent corruption.

**Connection pooling.** Each gRPC client should have one connection per server, multiplexing many calls. New connection per call defeats the purpose.

**Error handling.** Status codes vs HTTP codes confuse newcomers. Map carefully.

**Debugging.** Binary on the wire; hard without `grpcurl` or similar.

**Browser support.** Need gRPC-Web or Connect for browsers.

---

## Real Engineering Analogies

**The pre-printed restaurant ticket.**
Servers and cooks share a pre-printed menu. Server fills out a ticket (just numbers); cook reads the codes. Faster than handwritten orders; less ambiguity. Cost: menu changes require reprinting.

**The pneumatic tube system.**
Old buildings used tubes for binary signals between rooms. Concise; pre-defined codes; high throughput. The vocabulary is fixed; both ends must agree. That's gRPC's wire-format philosophy.

---

## Production Engineering Perspective

What goes wrong:

- **The reused tag number.** Field removed; tag reused later for a new field. Old clients deserialize garbage. Silent bug. Lesson: `reserved` keyword in protobuf.
- **The infinite deadline.** Service-to-service calls without deadlines. Slow downstream pegs the caller. Cascading failure. Mitigation: enforce deadlines in code review.
- **The Kubernetes load-balancing trap.** gRPC client connects to the service VIP once; reuses the connection forever; never load-balances across pods. Mitigation: headless service + client-side round-robin.
- **The schema-break disaster.** Schema change shipped; clients with old generated code can't parse new responses. Mitigation: schema registry; rolling deploys with both versions supported.
- **The streaming connection leak.** Long-lived streaming RPC; client crashes; server doesn't notice; resources leak. Mitigation: heartbeats; deadline; close detection.
- **The metadata size.** Unbounded header growth; HPACK fills; performance degrades. Mitigation: cap metadata size.

The senior gRPC engineer's habits:
- **Always set deadlines**.
- **Use schema registry** or strong code review for proto changes.
- **Connection pooling** — one connection per service, not per call.
- **Headless services** in Kubernetes for load balancing.
- **Interceptors** for cross-cutting concerns.
- **Test with `grpcurl`** for manual debugging.

---

## Failure Scenarios

**Scenario 1 — The infinite deadline.**
Service A calls Service B without a deadline. B's database is slow; calls take 30s. A's threads pile up; A becomes slow. Cascade. Recovery: enforce deadlines; emergency timeout in service mesh.

**Scenario 2 — The K8s load-balance miss.**
gRPC client → Service VIP. K8s LB resolves once; client opens connection to one pod. All client traffic goes to one pod. Other pods idle. Fix: headless service; client does its own round-robin across pod IPs.

**Scenario 3 — The protobuf compatibility break.**
Field removed; tag 7 reassigned to a new int field. Old clients sending the old field as a string deserialize as garbage int. Subtle; weeks to discover. Lesson: `reserved` tags forever.

**Scenario 4 — The streaming back-pressure miss.**
Bidirectional stream; client sends faster than server processes; server's buffer fills; OOM. Mitigation: flow control via `MaxConcurrentStreams`; backpressure in application code.

**Scenario 5 — The browser-meets-gRPC reality.**
Engineering picks gRPC for a service used by browser. Discovers no native browser support. Adds gRPC-Web; needs Envoy proxy; complexity. Decision: was REST or Connect a better fit?

---

## Performance Perspective

- **Wire size**: typically 30-70% of equivalent JSON.
- **Latency**: parse/serialize 5-10× faster than JSON.
- **Connection overhead**: HTTP/2 multiplexing; one connection serves many concurrent calls.
- **Streaming throughput**: high; ideal for large datasets.

---

## Scaling Perspective

- **Per-service**: handles tens of thousands of requests/sec on commodity hardware.
- **Cross-region**: HTTP/2 + TLS handshake costs amortize over multiplexed calls.
- **Service mesh**: Envoy-based proxies scale gRPC routing.
- **At hyperscale**: dedicated implementations (Google's internal Stubby; bespoke).

---

## Cross-Domain Connections

- **API Design**: gRPC is one of three primary API styles. (See [api-design-rest-vs-grpc.md](./api-design-rest-vs-grpc.md).)
- **HTTP/2**: gRPC's transport. (See [http-2-and-http-3.md](../networking/http-2-and-http-3.md).)
- **TLS**: encryption layer. (See [tls-and-mtls.md](../networking/tls-and-mtls.md).)
- **Microservices**: typical communication style. (See [microservices-vs-monolith.md](./microservices-vs-monolith.md).)
- **Distributed tracing**: deadline + metadata propagation. (See [distributed-tracing-deep-dive.md](../observability/distributed-tracing-deep-dive.md).)
- **Load balancing**: client-side LB. (See [load-balancing-strategies.md](../scalability/load-balancing-strategies.md).)

The unifying observation: **gRPC is what happens when you take the cost of inter-service communication seriously and build the framework that minimizes it. The opinions (binary, schema, code-gen, HTTP/2, deadlines) are the framework's value.**

---

## Real Production Scenarios

- **Google's Stubby and gRPC migration**: documented design.
- **Lyft's Envoy + gRPC**: extensively documented service mesh.
- **Square's gRPC adoption**: case studies.
- **Buf's Connect protocol**: simpler alternative for browser use.

---

## What Junior Engineers Usually Miss

- That **proto tags are forever**.
- That **deadlines must be set**.
- That **Kubernetes LB doesn't work natively for gRPC**.
- That **gRPC-Web exists** for browser interop.
- That **status codes differ** from HTTP.

---

## What Senior Engineers Instinctively Notice

- They **enforce deadlines**.
- They **use schema discipline** for proto evolution.
- They **configure client-side LB**.
- They **add interceptors** for tracing/metrics.
- They **avoid streaming** for simple request-response.

---

## Interview Perspective

What gets tested:

1. **"gRPC vs REST?"** Tests fundamental.
2. **"Streaming types?"** Unary, server, client, bidirectional.
3. **"Deadlines?"** Propagated through call chain.
4. **"Schema evolution?"** Tag numbers forever.
5. **"Load balancing?"** Client-side typically.

Common traps:
- Reusing tag numbers.
- No deadlines.

---

## 20% Knowledge Giving 80% Understanding

1. **gRPC = HTTP/2 + protobuf + codegen**.
2. **Four call types**: unary + 3 streaming.
3. **Deadlines propagate**.
4. **Schema is the contract**; tags are forever.
5. **Wire format is compact** binary.
6. **Status codes are gRPC-specific**.
7. **Client-side LB** is typical.
8. **Interceptors** for cross-cutting concerns.
9. **gRPC-Web** for browsers.
10. **Connection pooling** is mandatory.

---

## Final Mental Model

> **gRPC is opinionated infrastructure for service-to-service communication. The opinions — binary serialization, schema-first, code generation, HTTP/2, streaming, deadlines — together form a framework that's hard to match with hand-rolled REST. For internal service communication at scale, gRPC is the default choice; understanding why it's defaulted is understanding what it solves.**

The senior engineer using gRPC treats schema as a long-lived contract; deadlines as mandatory; load balancing as client-side; debugging as tooling-assisted. The framework rewards discipline; production gRPC at scale is well-trodden ground.

That's gRPC. That's the framework under most modern microservice deployments. That's what service-to-service RPC looks like when correctness, performance, and tooling are co-designed.
