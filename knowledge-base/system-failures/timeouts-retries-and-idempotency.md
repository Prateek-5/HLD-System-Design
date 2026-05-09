# Timeouts, Retries & Idempotency

> *"In a distributed system, every request has three possible outcomes: success, failure, and 'we'll never know.' Engineering for production means building for all three — especially the third."*

---

## Topic Overview

The three primitives — timeouts, retries, idempotency — are often discussed in isolation. They shouldn't be. Together they form the *minimum viable contract* for any service that talks to another service across a network. Get any one wrong and the others become weapons against you. Get all three right and most of distributed systems' nastiest bugs cease to exist.

Timeouts bound the duration any operation can hold resources. Retries recover from transient failures. Idempotency makes retries safe. The triple is the engineering response to a single, unavoidable fact about networks: **you cannot tell the difference between "the request failed" and "the request succeeded but the response was lost."** Once you accept that, your code changes shape.

This is the topic where every microservices war story converges. The retry storm, the duplicate charge, the timeout-too-long, the operation that "definitely shouldn't run twice but did" — they're all variations of the same lesson, learned again and again, badly, in production. The discipline is treating the triple as non-optional infrastructure, like authentication or logging.

---

## Intuition Before Definitions

You send your friend a check for $100 in the mail. A week passes. No acknowledgment.

Three possible truths:
1. The check arrived. Your friend forgot to thank you.
2. The check was lost in the mail. They never received it.
3. The check arrived but the thank-you note got lost on the way back.

You cannot tell which one happened. From your end, the situation is identical.

What do you do?
- Wait forever? You'll never know. You can't proceed.
- Send another check? If the first one *did* arrive, they now have $200 — possibly cashed twice if the bank doesn't notice.
- Call them? Now you've added a side channel to verify state.

This is *every* network call. The check is the request. The thank-you note is the response. The mail is the network. The unknown is irreducible.

The engineering response is to design for it. **The check has a memo line**: "Birthday gift, ID 12345." If your friend cashes a check, they note its ID. The bank, if asked to cash a check with the same ID twice, refuses. That's idempotency.

If you don't hear back in two weeks, you call. That's a timeout.

If they say "I never got it," you mail another check, with the same ID. They cash it; the bank sees the same ID; everything's clean. That's a safe retry.

That's the entire pattern. The "uncertain" outcome is built into every external call you'll ever make. You either design for it explicitly, or your system breaks the moment the network misbehaves.

---

## Historical Evolution

**Era 1 — RPC's "let's pretend the network isn't there."**
1980s and 90s. CORBA, DCOM, early SOAP. The premise: remote calls should look like local calls. The reality: they didn't fail like local calls. Catastrophic in production. Spawned Peter Deutsch's "Eight Fallacies of Distributed Computing" (1994), still required reading.

**Era 2 — TCP and the first timeouts.**
TCP itself has timeouts at the protocol level. Application code mostly ignored them or set absurd values (default infinite timeouts in many HTTP clients persisted into the 2010s). Production outages followed.

**Era 3 — REST and the explicit retry.**
HTTP idempotency semantics formalized: GET, PUT, DELETE are idempotent; POST is not. The REST community built up a culture of "design for retry." Most teams still got it wrong because POST endpoints did everything.

**Era 4 — Stripe's idempotency keys (2015-ish).**
Stripe's API documented per-request idempotency keys for POST endpoints. Industry-wide imitation followed. The pattern moved from "advanced practice" to "table stakes for any payment-style API."

**Era 5 — Service meshes and infrastructure timeouts.**
Envoy, Linkerd, Istio brought timeouts and retries into the network layer. Application code stopped being the only place to configure them. The flip side: hidden retries at the mesh layer caused new categories of bugs (retry amplification through the stack).

**Era 6 — The retry-budget era.**
Modern service meshes and SDKs implement retry budgets — caps on retries as a fraction of base traffic — to prevent retry storms. Adaptive retries that back off when downstream signals saturation. Idempotency-aware retries that only retry safe operations. The pattern matures into infrastructure.

The arc: each generation rediscovered that the network can fail in ways the application cannot distinguish, and that the *combination* of timeout + retry + idempotency must be addressed together — getting one without the others creates new bugs.

---

## Core Mental Models

**1. Every external call has three possible outcomes.**
Success, failure, unknown. The unknown is the dangerous one. Code that branches only on success/failure is incomplete.

**2. Timeouts must decrease from outer to inner.**
The user-facing call has the longest timeout; each inner call has a shorter one. This way, when something is slow, the inner call fails first, the outer call has time to handle the failure, and resources unwind cleanly.

**3. Retries amplify load.**
A 3-retry policy can multiply traffic by 4× under failure. Three layers of retries (client, gateway, service mesh) compound to 64×. This is the retry storm. Mitigations: backoff, jitter, retry budgets, circuit breakers.

**4. Idempotency is a precondition for retry.**
If your operation cannot be retried safely, you cannot retry it — period. Designing for idempotency means designing the API up front, not bolting it on later.

**5. The hardest part is the operation that is "almost" idempotent.**
"Send email" is idempotent on the sender's side (we already sent it) but not on the receiver's (they got two emails). "Charge card" with idempotency keys is safe at the gateway but the bank's behavior matters. *Idempotency is end-to-end; you can only guarantee it as far as your own system extends*.

---

## Deep Technical Explanation

### Timeouts — the most important number

Every network call needs a timeout. Without exception. The defaults in many libraries are *infinite* — a deliberate choice that makes simple programs simple but production code dangerous.

Setting a timeout requires answering:

- **What's the dependency's normal p99 latency?** Lower bound for the timeout.
- **How long can I wait while still serving the user?** Upper bound, derived from end-to-end SLO.
- **What's my upstream timeout?** Mine must be shorter, with margin.

**The timeout chain rule:**

```
Client (5s) → Gateway (4s) → Service A (3s) → Service B (2s) → Database (1s)
```

Each layer's timeout < the layer above's timeout, with margin for processing. This way:
- Database times out at 1s.
- Service B's caller (Service A) sees a 1s response (the timeout) and has 2s of its 3s budget remaining for fallback or graceful failure.
- Each layer has time to handle the failure before its own caller times out.

Anti-pattern: same timeout at every layer. The outer timeout fires before the inner has a chance to handle the failure cleanly. The work that did happen is wasted.

**Connection vs read vs total:**

Most HTTP clients distinguish:
- **Connection timeout:** time to establish TCP/TLS.
- **Read timeout:** time between bytes received.
- **Total timeout:** time for the entire operation.

A "read timeout of 5s" doesn't bound total time — a slow trickle of bytes can keep the connection alive indefinitely. Always set a total timeout.

**The "deadline" pattern (gRPC, Go context):**

Instead of per-call timeouts, propagate a *deadline* — an absolute time by which the operation must complete. Each layer subtracts processing time from the budget. This naturally enforces the timeout chain rule without manual coordination.

Go's `context.WithDeadline` and gRPC's deadline propagation are the model implementations. Modern systems should use deadlines, not per-call timeouts, when they have the option.

### Retries — done right, done wrong

A naive retry policy:

```python
for attempt in range(MAX_RETRIES):
    try:
        return call()
    except Exception:
        continue
```

What's wrong:
- **No backoff.** Hammers the dependency immediately.
- **No jitter.** All clients retry at the same instant. Synchronization storms.
- **No idempotency check.** Non-idempotent operations may execute multiple times.
- **No circuit awareness.** Retries into known-broken dependencies.
- **No retry budget.** Each call can retry independently; aggregate amplification is unbounded.

**Exponential backoff with jitter:**

```python
def retry_with_backoff(call, max_retries=3, base_delay=0.1):
    for attempt in range(max_retries):
        try:
            return call()
        except RetryableError:
            if attempt == max_retries - 1:
                raise
            delay = base_delay * (2 ** attempt)
            delay = delay * (0.5 + random.random())  # 50%-150% jitter
            time.sleep(delay)
```

Properties:
- Exponential backoff: 100ms, 200ms, 400ms, 800ms... gives the dependency time to recover.
- Jitter: spreads retries across time, preventing synchronized storms.
- Bounded retries: 3 is typical. More than that is rarely useful and accelerates amplification.

**What to retry:**

- **Connection failures, timeouts, 503s:** typically safe to retry.
- **5xx server errors:** sometimes safe (depends on whether the operation is idempotent).
- **4xx client errors:** generally not retryable — the request is wrong.
- **Network errors mid-response:** *the response might have been received*. Retry only with idempotency.

**What NOT to retry:**

- **Authentication errors (401/403).** Retrying won't help; you need new credentials.
- **Validation errors (400, 422).** The request is malformed. Retrying gives the same response.
- **404.** The resource isn't there. Retrying doesn't make it appear.
- **429 (rate limit).** Retry only after the `Retry-After` header.

**Retry budgets:**

Modern service meshes implement *retry budgets*: retries are capped as a fraction of base traffic (e.g., 10%). If retry rate exceeds the budget, retries are disabled until it recovers. This prevents amplification cascades.

Linkerd's documentation has good public examples. AWS SDKs have similar behavior in their adaptive retry mode.

### The retry-amplification math

Three layers of retries, each retrying 3 times:
- 1 user request → up to 3 service calls (client retries) → up to 9 service-to-service calls → up to 27 database calls.

This is what kills production during partial outages. A 1% downstream failure rate becomes a 27% load amplification with naive retries — and the increased load makes the failure worse.

The mitigations:
- **Retry at one layer only**, typically the outermost.
- **Disable mesh-level retries** when application-level retries exist (or vice versa).
- **Use retry budgets** to cap aggregate retry traffic.
- **Stop retrying when circuit is open**.

### Idempotency — the unsung hero

An operation is *idempotent* if executing it once or many times produces the same result. Examples:
- `SET name = 'Alice'` — idempotent. Second execution is a no-op.
- `INCREMENT counter BY 1` — *not* idempotent. Each call changes state.
- `DELETE order 12345` — idempotent (deleting an already-deleted order is a no-op).
- `INSERT order` — *not* idempotent unless you handle duplicates.

**The idempotency key pattern:**

The client generates a unique key per logical operation. The server, on receiving a request with a key, checks whether it's already processed:

```
POST /charges
Idempotency-Key: ck_abc123def456

Server flow:
  1. lookup(idempotency_key) -- have we seen this?
  2. if yes: return cached response
  3. if no: process request; store (idempotency_key, response); return
```

Properties:
- Same idempotency key + same request → same response, same side effects (executed once).
- Same idempotency key + *different* request → typically an error (key reuse with mismatched payload is a client bug).
- Idempotency keys eventually expire (24h is common).

This is the Stripe pattern. It's now standard for any "you really shouldn't run this twice" API.

**Idempotency layers:**

- **At the API gateway:** dedup by idempotency key before reaching the service.
- **At the service:** dedup against a database-backed idempotency table.
- **At the database:** unique constraints on operation IDs.

End-to-end idempotency requires *every layer* to participate. A missed layer means duplicate operations slip through.

**Idempotency for operations you don't fully control:**

What about "send email"? Once it's handed to the SMTP server, it's out of your hands. Mitigation: dedup *before* the handoff. Idempotency keys in the queue ensure the same email isn't enqueued twice; the queue worker dedupes against a "sent" log; emails sent are recorded with their idempotency key.

The principle: *idempotency at the boundaries of your system*. Beyond that, you're trusting external behavior.

### The exactly-once myth

"Exactly-once delivery" is the fool's gold of distributed systems. It's mathematically impossible in the general case — you cannot guarantee a message is delivered exactly once across a network with possible failures.

What you can have:
- **At-least-once delivery + idempotent processing = effectively-once semantics.** This is what real systems use.
- **At-most-once delivery** (don't retry) — sometimes acceptable for non-critical operations.

Kafka's "exactly-once semantics" is at-least-once delivery + transactional consumer offsets — effectively-once *within Kafka*. Once data leaves Kafka, the application must continue the discipline.

### Common bugs

**The duplicate charge.** Network blip during payment. Client retries without idempotency key. Two charges. Customer ticket. Refund. Reputation damage. Always use idempotency keys for charges.

**The lost timeout.** Client times out at 5s. Server is processing. Server commits. Server tries to respond — connection is gone. Client retries. Server processes again. Without idempotency, two operations.

**The success-with-error response.** Server commits. Returns 500 due to a bug in the response logic. Client interprets as failure. Retries. Now two operations. Idempotency saves you here too.

**The orphaned operation.** Client times out. Server is still processing. Operation eventually completes. Client thinks it failed. State is inconsistent — server has the new state; client is operating on old state. Reconciliation jobs catch some of these; idempotent retries catch others.

---

## Real Engineering Analogies

**The certified mail receipt.**
Send a check by certified mail with return receipt. The receipt is the success acknowledgment. If you don't get the receipt, you can:
- Wait (but how long?).
- Send another check with the same memo line (idempotency).
- Call the recipient (out-of-band confirmation).

Every safe protocol — credit card networks, ACH transfers, freight tracking — works this way. Idempotency keys are tracking numbers. Timeouts are how long you wait before assuming the package is lost. Retries are sending another package with the same tracking number.

**The order ticket at a busy restaurant.**
The waiter writes the order on a ticket with a unique number. The kitchen sees the ticket. If the waiter checks "is order #247 ready?" twice, the kitchen doesn't make two of them. The ticket number is the idempotency key. The kitchen's ticket queue is the deduplication layer. If the waiter never gets the food (timeout), they ask the kitchen — and the kitchen knows whether #247 was made or not.

---

## Production Engineering Perspective

Things that break:

- **The infinite timeout.** Default in many HTTP clients. A slow downstream pegs the calling service forever. Always set explicit timeouts.
- **The "we already retry at the SDK level" problem.** Application also retries. Service mesh also retries. Three layers of retries, undocumented, fighting each other. Discovery happens during outages.
- **The idempotency key without a window.** Keys retained forever. Storage explodes. Solution: TTL on idempotency keys.
- **The idempotency key collision.** Two genuinely different operations get the same key (e.g., a buggy ID generator). Second is treated as a duplicate of the first. Silent data loss. Mitigation: globally unique keys, validate payload matches on idempotency hit.
- **The retry that wasn't safe.** A POST with no idempotency key was retried by the SDK. Two operations executed. Discovered when reconciling.
- **The deadline that didn't propagate.** Client sets 5s deadline. Service-to-service call doesn't propagate it. Inner service waits 30s on its own DB query. Client times out long before; server keeps working on a request nobody is waiting for.
- **The "retry storm" autoscaler.** Service slows. Retries amplify load. Auto-scaler interprets as need for capacity; spins up new instances. New instances also slow. Auto-scaler adds more. Cost explodes; service is still degraded. Recovery: rate-limit at the edge, disable retries until the backlog drains.

The senior engineer's habits:
- **Explicit timeouts on every external call.** Default-infinite is unacceptable.
- **Decreasing timeouts** down the call chain.
- **Idempotency keys** on every state-changing API.
- **Single retry layer**, ideally the outermost.
- **Retry budgets** in service mesh.
- **Audit retry policies** in every SDK and integration.
- **Deadlines, not timeouts**, where the language supports them.

---

## Failure Scenarios

**Scenario 1 — The double-charged customer.**
Customer clicks "buy." Network blip during checkout. Client retries. Server processes the second request — same operation, no idempotency key. Two charges. Customer finds out the next day. Refund issued; goodwill lost. Cause: missing idempotency key.

**Scenario 2 — The retry storm partial outage.**
A downstream API has 1% error rate. Three layers of retries with no budget. Effective request rate is 1× × 4 × 4 × 4 = 64×. Downstream now has 64% load increase. Falls over completely. Recovery requires shedding load at the edge.

**Scenario 3 — The orphaned operation.**
Client times out at 3s. Server takes 5s. Server commits. Client retries. Server commits again. Without idempotency: two operations. Reconciliation job reveals it days later.

**Scenario 4 — The infinite-timeout cascade.**
Service A → Service B → Service C → External API. External API hangs. C waits indefinitely (no timeout). B waits indefinitely (waiting on C). A waits indefinitely. All services appear up, all are stuck. Customer requests pile up. Fix: timeouts at every layer.

**Scenario 5 — The idempotency key reused across requests.**
A bug in ID generation produces collisions in idempotency keys (e.g., based on `request_id` that was reused after a restart). Different operations get the same key. Server treats them as duplicates. Some operations silently dropped. Discovered during a financial audit weeks later.

---

## Performance Perspective

- **Timeouts have negligible runtime cost** but bound resource holding. Cheap insurance.
- **Retries with backoff add latency** to the failure path. Acceptable; the alternative is the user seeing the failure faster.
- **Idempotency key lookup adds latency** to every request — typically a fast in-memory or Redis lookup, but it's not free. At very high QPS, the dedup store can be the bottleneck.
- **Deadline propagation is essentially free** at runtime; the cost is implementation complexity.
- **Retry storms are the silent latency tax** during partial outages — average latency stays okay, p99 explodes.

---

## Scaling Perspective

- **Timeouts must be tuned per dependency** as the system grows. Latencies change; static timeouts age badly.
- **Idempotency stores must scale** with request volume. Sharded by key; high QPS workloads use Redis cluster or DynamoDB.
- **Retry budgets become more important** at scale — amplification effects compound.
- **At very high scale**, idempotency key TTLs become a storage cost lever; tradeoff between dedup window and storage volume.
- **Deadline propagation across service boundaries** must be honored by libraries and SDKs; ad-hoc implementations create silent inconsistencies.

---

## Cross-Domain Connections

- **Sagas:** every saga step is a retry-with-idempotency operation. The triple is fundamental to saga design. (See [saga-pattern-and-distributed-transactions.md](../architecture-patterns/saga-pattern-and-distributed-transactions.md).)
- **Cascading failures:** timeouts and circuit breakers are the same family of pattern; retries without budgets are the cascade-amplifier. (See [cascading-failures-and-circuit-breakers.md](./cascading-failures-and-circuit-breakers.md).)
- **Backpressure:** retries violate backpressure; budgets restore it. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Distributed consistency:** the "uncertain" outcome is an artifact of the same network-partition reality CAP theorem describes. (See [cap-consistency-and-replication.md](../distributed-systems/cap-consistency-and-replication.md).)
- **MVCC:** idempotent SQL UPDATEs interact with snapshot isolation; the same row may be UPDATEd twice from a retry, but the second is a no-op if the value matches.
- **Caching:** cache-aside patterns benefit from idempotency on the cache-fill path — concurrent fillers should not duplicate work.

The unifying observation: **the network's "uncertain" outcome is the foundation problem of distributed systems, and the timeout/retry/idempotency triple is the foundation defense.** Every other distributed pattern assumes you've gotten this right.

---

## Real Production Scenarios

- **Stripe's idempotency key documentation**: arguably the canonical public reference. Their API design has shaped how the industry thinks about safe POSTs.
- **AWS SDK adaptive retries**: documented behavior includes exponential backoff with jitter, retry budgets, and integration with throttling signals.
- **Google's gRPC deadlines**: deadline propagation is a first-class feature, used internally and externally. Documented patterns for setting deadlines at the edge and respecting them deep in the stack.
- **Linkerd / Envoy retry budgets**: open-source documentation of retry budget mechanics in modern service meshes.
- **The 2017 GitHub incident**: cascading retries amplified a small backend issue into a 24-hour partial outage. Postmortem highlights retry budget and timeout discipline.
- **Cloudflare's request lifecycle**: public engineering posts describe their layered timeout and retry architecture, including how they prevent amplification at edge scale.

---

## What Junior Engineers Usually Miss

- That **default timeouts are often infinite** — the library doesn't help you.
- That **POST is not idempotent** by default and must be designed to be.
- That **retries amplify load** and require budgets.
- That **the outer timeout must exceed the inner**, not match it.
- That **"the request failed"** is a state distinct from "the request did not happen."
- That **idempotency keys must be unique** — collisions are silent disasters.
- That **multiple retry layers** combine multiplicatively.
- That **deadline propagation** is the right model in modern stacks.

---

## What Senior Engineers Instinctively Notice

- They **demand explicit timeouts** in every external call.
- They **propagate deadlines** end-to-end where the language supports it.
- They **audit retry policies** at each layer and consolidate to one.
- They **require idempotency keys** for state-changing APIs.
- They **size retry budgets** to prevent amplification.
- They **distinguish "retryable"** from "non-retryable" errors carefully.
- They **build for the unknown outcome**, not just success/failure.
- They **treat idempotency as end-to-end**, including external dependencies.

---

## Interview Perspective

What gets tested:

1. **"What are the three possible outcomes of a network call?"** Tests fundamental thinking. Junior says two; senior says three.
2. **"How do you implement a safe retry?"** Senior answer: exponential backoff with jitter, idempotency, bounded count, retry budget.
3. **"What's an idempotency key?"** Tests practical knowledge. Bonus for explaining the dedup window and key uniqueness.
4. **"What's wrong with this code?"** Given a retry loop without backoff or jitter, the candidate should call out amplification.
5. **"How do you handle a slow downstream?"** Senior answer: timeouts, circuit breakers, fallbacks, retries only with idempotency.
6. **"What's the difference between at-least-once and exactly-once?"** Tests delivery semantics literacy. Effectively-once = at-least-once + idempotent.
7. **"How do you design a payment API?"** Tests applied design — idempotency keys, retries, timeouts, deadline propagation.

Common traps:
- Confusing "we retry" with "we retry safely."
- Believing exactly-once delivery is achievable.
- Setting same timeout at every layer.
- Not knowing about retry storms.

---

## Worked Example — Designing the Timeout Chain for a Request

A user-facing checkout request flows through 4 services. Designing timeouts that compose correctly.

### The flow

```
[Client] → [API gateway] → [Order service] → [Payment service] → [External payment provider]
```

### User expectations

- User-facing latency budget: 3 seconds end-to-end (research-derived).
- Beyond 3s, abandonment rises sharply.

### Working backwards from the user

```
Total budget:               3000ms
Client → Gateway network:    50ms (round trip)
Client-side timeout:       2900ms

Gateway processing overhead: 50ms
Gateway → Order timeout:   2800ms

Order service processing:    50ms
Order → Payment timeout:   2700ms

Payment service processing:  50ms
Payment → External timeout: 2600ms

External provider:           Network + their processing
```

Each layer's timeout is *less than* the layer above's. Each layer leaves room for its own processing.

If the external provider takes 2700ms (over the 2600ms budget), Payment service times out and returns failure to Order service, which has 100ms of budget remaining (its 2700ms budget minus the 2600ms it gave to Payment) to handle the failure: log, return error, etc.

### Implementation with deadlines (Go example)

```go
// At the gateway entry point
func handleCheckout(w http.ResponseWriter, r *http.Request) {
    ctx, cancel := context.WithTimeout(r.Context(), 2800*time.Millisecond)
    defer cancel()

    result, err := orderClient.PlaceOrder(ctx, request)
    if err != nil {
        if errors.Is(err, context.DeadlineExceeded) {
            http.Error(w, "Request timeout", 504)
        } else {
            http.Error(w, "Order failed", 500)
        }
        return
    }
    json.NewEncoder(w).Encode(result)
}

// Inside Order service
func (s *OrderService) PlaceOrder(ctx context.Context, req *Request) (*Response, error) {
    // Subtract our processing time; pass deadline downstream
    paymentCtx, cancel := context.WithTimeout(ctx, 2700*time.Millisecond)
    defer cancel()

    paymentResult, err := s.paymentClient.Charge(paymentCtx, ...)
    // ... handle ...
}
```

The deadline propagates through `context.Context`. Each layer can `WithTimeout` to add its own bound. The earliest deadline wins.

### Adding retries

Retries must fit within the timeout chain:

```go
func (s *OrderService) PlaceOrder(ctx context.Context, req *Request) (*Response, error) {
    // Generate idempotency key for this logical operation
    idempotencyKey := generateIdempotencyKey(req)

    var paymentResult *Response
    var err error
    
    for attempt := 0; attempt < 3; attempt++ {
        // Bound each attempt; leave room for retries
        attemptCtx, cancel := context.WithTimeout(ctx, time.Second)
        
        paymentResult, err = s.paymentClient.Charge(attemptCtx, &Request{
            ...,
            IdempotencyKey: idempotencyKey,  // same key on every retry
        })
        cancel()

        if err == nil {
            return paymentResult, nil  // success
        }
        if !isRetryable(err) {
            return nil, err  // permanent error; don't retry
        }
        if ctx.Err() != nil {
            return nil, ctx.Err()  // outer deadline exceeded; stop
        }

        // Exponential backoff with jitter
        backoff := time.Duration(100 * (1 << attempt) + rand.Intn(100)) * time.Millisecond
        select {
        case <-time.After(backoff):
        case <-ctx.Done():
            return nil, ctx.Err()
        }
    }
    return nil, err
}

func isRetryable(err error) bool {
    if errors.Is(err, context.DeadlineExceeded) {
        return false  // we already burned our budget
    }
    var grpcErr *grpcError
    if errors.As(err, &grpcErr) {
        switch grpcErr.Code {
        case codes.Unavailable, codes.ResourceExhausted, codes.DeadlineExceeded:
            return true  // transient
        case codes.InvalidArgument, codes.NotFound, codes.PermissionDenied:
            return false  // permanent
        }
    }
    return false
}
```

Critical: **same idempotency key on every retry**. Server dedupes; charges only once even if the client thinks it failed and retried.

### What this prevents

**Without timeouts**: a slow downstream pegs the caller indefinitely; cascading failure.

**Without idempotency**: retries cause duplicate charges; customer billed twice.

**Without retry budgets**: client retries 3×, gateway retries 3×, order retries 3× = 27× amplification under failure.

**Without proper status-code classification**: retrying on 4xx (permanent client errors) wastes budget; retrying on 503 (transient) recovers.

### Reference architecture — A defended distributed call

```
[Caller]                              [Callee]
  │                                       │
  │  Generate idempotency_key             │
  │                                       │
  │  Set deadline (e.g., 2.7s)            │
  │  Set retry policy (max 3, exp+jitter) │
  │  Set circuit breaker                   │
  │                                       │
  ├──── attempt 1 ─────────────►          │
  │     headers: idempotency-key=X        │
  │              deadline=2.7s            │
  │                                       │
  │     ◄── 503 Service Unavailable ──────┤
  │                                       │
  │  Wait 100ms (+ jitter)                │
  │                                       │
  ├──── attempt 2 ─────────────►          │
  │     headers: idempotency-key=X        │
  │              deadline=2.5s (less)     │
  │                                       │
  │     ◄── 200 OK (cached response) ──────┤
  │                                       │
  │  Return success                       │
```

Each retry uses the same idempotency key. The server's first call processes; subsequent retries return the cached response from the first call. Effectively-once semantics.

---

## Recent Production References (2023-2024)

- **AWS SDKs' adaptive retry mode (2023+)**: documented; combines retry budgets with jitter.
- **gRPC's deadline propagation**: deeply integrated; recent improvements to client libraries.
- **Stripe's idempotency-key documentation**: continues to be the canonical reference.
- **Cloudflare's request-handling architecture**: documented timeout chains.
- **Linkerd / Envoy retry budgets**: production-ready open-source implementations.
- **Temporal's workflow retry policies**: documented patterns for long-running operation retries.
- **The "deadline budget" concept in service mesh**: increasingly enforced at infrastructure layer.

---

## 20% Knowledge Giving 80% Understanding

1. **Three outcomes: success, failure, unknown.** Design for all three.
2. **Every external call needs a timeout.** No exceptions.
3. **Timeouts decrease from outer to inner.** Margin at each layer.
4. **Retries with exponential backoff and jitter.** Always.
5. **Retry budgets** prevent amplification.
6. **Idempotency keys** are required for state-changing APIs.
7. **Idempotency is end-to-end.** Boundaries matter.
8. **Single retry layer**, not multiple.
9. **Effectively-once = at-least-once + idempotent.** Exactly-once is a myth.
10. **Deadlines propagate, timeouts don't.** Use deadlines where you can.

---

## Final Mental Model

> **Networks fail in ways your code cannot distinguish. The triple — timeout, retry, idempotency — is the engineering vocabulary for handling that fact. Without all three, your system is one network blip away from a production incident.**

The senior engineer designing a service treats every external call as a small saga. Set the timeout. Plan the retry. Generate an idempotency key. Propagate the deadline. Each line of code is small; together they encode a contract about how this service behaves when the world gets weird.

The systems that survive are the ones where this discipline is automatic — built into the SDK, enforced by the service mesh, baked into code review checklists. The systems that fail are the ones that "didn't think about timeouts," "added retries to fix the flakiness," and "always meant to add idempotency keys." The triple is not advanced engineering. It's the foundation, and the systems that don't have it are the systems that will eventually need it, painfully, in production.

That's timeouts. That's retries. That's idempotency. That's the foundation contract every distributed call must honor — because the network already broke its end of the contract when you weren't looking.
