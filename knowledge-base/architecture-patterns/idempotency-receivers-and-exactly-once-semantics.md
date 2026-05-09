# Idempotency Receivers & "Exactly-Once" Semantics

> *"Exactly-once delivery is impossible. Effectively-once processing is achievable. The art is knowing the difference, and designing the receivers that turn an at-least-once world into an effectively-once application."*

---

## Topic Overview

"Exactly-once" is the holy grail of message-based systems and distributed transactions. The customer gets charged once. The email is sent once. The order is fulfilled once. Anything else is broken.

The bad news: exactly-once *delivery* across a network with possible failures is mathematically impossible. The network cannot tell you whether your message was delivered when no acknowledgment came back. You can deliver at-least-once (retry until acked) or at-most-once (don't retry; accept loss). But not both, deterministically, in a real network.

The good news: exactly-once *effects* are achievable. The trick: at-least-once delivery + idempotent receivers. The receiver detects duplicates and ignores them. From the application's perspective, every message has effect *exactly once*, regardless of how many copies the network delivered.

This is the topic that transforms the impossible into the practical. Idempotency keys, dedup tables, sequence numbers, transactional outboxes, idempotent receivers — these are the engineering techniques that build effectively-once semantics out of an at-least-once foundation. Every payment system, every reliable queue consumer, every reliable event handler depends on these patterns.

---

## Intuition Before Definitions

Imagine a hotel taking room reservations.

Customer calls and books a room. The connection drops mid-call before the agent confirms. The customer doesn't know if it went through. They call again, give the same details.

**Bad receiver:** the agent books a *second* room for the same dates. Customer is charged twice.

**Good receiver:** the agent has a system. Each request includes a confirmation number — "Reservation 12345." When the second call comes in with the same number, the agent says "I see this is already booked; here's the confirmation." No second booking. No double-charge.

That's idempotency. The confirmation number is the idempotency key. The agent is the idempotency receiver. The fact that the customer called twice doesn't matter — the system processed exactly one reservation.

Exactly-once delivery would have meant the call never dropped, the customer never had to redial. That's impossible (the phone network can fail). But exactly-once *outcome* — one reservation, one charge — is achievable through the receiver's discipline.

---

## Historical Evolution

**Era 1 — At-most-once.**
Early systems didn't retry. Lost messages were lost. Acceptable for some use cases (telemetry, logs); unacceptable for state changes (payments, orders).

**Era 2 — At-least-once.**
Retry until acknowledged. Reliable for delivery; unreliable for application semantics (duplicates).

**Era 3 — Application-level dedup.**
Custom code in receivers to detect duplicates. Stripe's idempotency-key API (~2015) productizes the pattern.

**Era 4 — Kafka's "exactly-once" (2017).**
Kafka EOS combines transactional producers + idempotent consumers + transactional consumer offsets. Within Kafka, effectively-once semantics. Across Kafka boundaries, still requires idempotent receivers.

**Era 5 — End-to-end patterns.**
Modern: idempotency keys propagate from request through saga steps; outbox patterns; CDC with idempotent consumers. Effectively-once at the application architecture level.

**Era 6 — Industry-standard patterns.**
2020+. Stripe's idempotency-key documentation has become a model. AWS SDKs default to retries with idempotency hints. Industry has converged on a small set of patterns that work.

The pattern: each generation made effectively-once easier. The impossibility of true exactly-once delivery is now well-understood; the engineering response (idempotent receivers) is now standard practice.

---

## Core Mental Models

**1. At-least-once + idempotent processing = effectively-once.**
This is the key formula. Network gives you at-least-once. Application code gives you idempotency. Together, the visible effect is exactly-once.

**2. Idempotency is end-to-end.**
At every boundary of your system. The HTTP handler dedupes. The queue consumer dedupes. The downstream API call dedupes. Anywhere a retry could occur, the receiver must dedupe.

**3. Exactly-once delivery is impossible; don't promise it.**
"Our system delivers exactly once" is a marketing claim that hides the engineering reality. Real systems are at-least-once with idempotent receivers.

**4. Idempotency keys must be unique per logical operation.**
"This is the same call you already made" requires identifying *the same call*. Naming the operation correctly is essential.

**5. The dedup window matters.**
Keep idempotency records long enough for retries to be deduped. Too short: real duplicates re-execute. Too long: storage grows. 24 hours is typical.

---

## Deep Technical Explanation

### The impossibility theorem (informal)

If A sends a message to B over an unreliable network and asks "did B receive it?":
- A receives no ack: maybe B got it; maybe not. A can't tell.
- A re-sends; B may receive twice or once.
- B acks; A may not receive the ack; A re-sends; same problem.

There's no protocol that achieves exactly-once delivery in finite time over a network with possible failures. (FLP impossibility for related problem of consensus.)

The escape: shift from "exactly-once delivery" to "exactly-once effect." Allow at-least-once delivery; make the receiver detect duplicates. Now the application sees exactly-once semantics regardless of how many duplicates the network produced.

### The idempotency key pattern

```
POST /charges
Idempotency-Key: ck_abc123def456
Content-Type: application/json

{ "amount": 1000, "currency": "usd", "source": "tok_xyz" }
```

Server-side flow:

```
def handle_charge(request):
    key = request.headers["Idempotency-Key"]
    
    # Acquire lock on key (e.g., DB row insert with UNIQUE constraint)
    if not acquire_idempotency_lock(key):
        # Existing key: return cached response
        return get_cached_response(key)
    
    try:
        result = process_charge(request.body)
        save_response(key, result)
        return result
    except Exception as e:
        save_error(key, e)
        raise
    finally:
        release_idempotency_lock(key)
```

Properties:
- Same key + same payload → same response, processed once.
- Same key + *different* payload → typically an error (key reuse with different content is a client bug).
- Same key, second request before first finishes → wait or return "in progress" status.
- After TTL expires, key is forgotten; new request with same key creates new operation.

Stripe's pattern, widely imitated.

### Idempotency at every layer

For end-to-end effectively-once:

- **API gateway**: dedup by idempotency key before reaching the service.
- **Application code**: persistent dedup table.
- **Queue consumer**: dedup by message ID.
- **Downstream API call**: include idempotency key.
- **Database INSERT**: use unique constraint on operation ID.

Missing any layer: duplicates can leak through. "I have idempotency at the API layer" isn't enough if the queue consumer doesn't dedup.

### Sequence numbers

An alternative to keys: monotonic per-source sequence numbers.

```
Producer A sends: msg(seq=1), msg(seq=2), msg(seq=3)
Consumer tracks: highest seen seq from A.
Duplicate (seq < highest): drop.
```

Used in TCP (sequence numbers ensure in-order, no-duplicate delivery within a connection). Also in transactional protocols.

Limitations:
- Per-source state on the consumer.
- Out-of-order delivery: must buffer or have stricter ordering.

Idempotency keys are more flexible (no ordering); sequence numbers are simpler when ordering is natural.

### Kafka's exactly-once semantics (EOS)

Kafka 0.11+ supports "exactly-once" within Kafka workflows:

1. **Idempotent producer**: each producer assigned a producer ID; sequence numbers per partition. Duplicate sends (from retries) are detected and discarded by brokers.
2. **Transactional producer**: writes to multiple topics atomically. Either all writes succeed or none.
3. **Transactional consumer**: reads only committed messages; advance offset and consume in same transaction.

Combined: producer writes to multiple topics + consumer reads + writes to other topics, all atomic.

Limitations:
- Within Kafka. External systems still need idempotent receivers.
- Performance cost compared to at-least-once.
- Operationally complex.

### The outbox pattern

For services that emit events on database changes, the dual-write problem: write to database + write to message bus, but you can't atomically do both across systems.

The outbox pattern:

```
BEGIN;
INSERT INTO orders (...) VALUES (...);
INSERT INTO outbox (event_type, payload, ...) VALUES (...);
COMMIT;
```

Both writes in one transaction. Then a separate process polls the outbox and publishes events:

```
SELECT * FROM outbox WHERE published = false;
for each row:
    publish_to_kafka(row.payload);
    UPDATE outbox SET published = true WHERE id = row.id;
```

Properties:
- At-least-once: if the publishing process crashes after publishing but before updating, the row is published again on retry.
- Combined with idempotent consumers: effectively-once.
- The dual-write problem is solved within the database transaction.

### Idempotent consumers

A queue consumer must handle duplicates:

```python
def handle_message(msg):
    msg_id = msg.headers["message-id"]
    if already_processed(msg_id):
        return  # already done
    
    with transaction:
        do_business_logic(msg)
        mark_processed(msg_id)
```

The `mark_processed` and the business logic must be atomic. Otherwise: business logic succeeds, mark fails, message reprocessed.

Approach: use the same database transaction for both. Or: use the message's effect itself as the dedup mechanism (e.g., the database operation has a unique constraint on the message ID).

### CRDTs as idempotent operations

Conflict-free Replicated Data Types are inherently idempotent:
- G-Counter: increment is idempotent if you track which increments by ID.
- LWW-Set: insert with timestamp is idempotent.
- OR-Set: insert with unique ID is idempotent.

Replaying any CRDT operation is safe. Particularly useful for distributed systems where retries are common.

### Idempotency vs commutativity

Idempotent: doing twice = doing once.
Commutative: order doesn't matter (a + b = b + a).

Both are useful. CRDTs are both. Many real operations are idempotent but not commutative.

For at-least-once, idempotency is sufficient. For out-of-order delivery, commutativity is also helpful. Designs that have both are most robust.

### Common pitfalls

**The non-unique key.** Idempotency key generated client-side without sufficient entropy. Two genuinely different operations get the same key. Second is treated as duplicate of first. Silent data loss. Mitigation: UUIDs.

**The mutable payload.** Same idempotency key + different payload — what to do? Typically: error. The client is misusing the protocol. Don't silently process the new payload.

**The race condition.** Two concurrent requests with the same key, neither has completed yet. Both check "is this processed?" — both see no; both proceed. Mitigation: atomic upsert; pessimistic lock.

**The expired key.** TTL too short. Real retries (after partial failures) re-process. Set TTL to cover the longest realistic retry window.

**The mid-process crash.** Server processes message, crashes before recording dedup. On retry, processes again. Mitigation: transactional save of dedup record + business effect.

---

## Real Engineering Analogies

**The check with a memo number.**
You write a check with a memo number. The bank deposits it. If you accidentally write a duplicate check (same memo), the bank's system detects the duplicate and rejects. The check itself has the idempotency key. The bank is the idempotent receiver.

**The package tracking number.**
A shipping company gives each package a tracking number. If you (or the sender) initiate a duplicate shipment, the system detects it ("we already have this in transit") and reuses the existing record. Many real-world reliable processes work this way.

---

## Production Engineering Perspective

What goes wrong:

- **The double charge.** No idempotency keys. Network glitch; client retries; payment processed twice. Customer support; reputation damage. Fix: mandatory idempotency keys for charges.
- **The duplicate email.** Email sender retries on transient failure. No dedup. Customer gets two emails. Annoying; sometimes confusing. Fix: dedup before sending; idempotent send tokens.
- **The redundant order.** Order API doesn't dedup. Customer double-clicks; two orders created. Fix: client-side disable button; server-side idempotency.
- **The outbox pattern that wasn't.** Service writes to DB and Kafka separately. DB succeeds; Kafka fails. Inconsistent state. Fix: outbox pattern.
- **The message replay disaster.** Consumer reprocesses messages from a checkpoint; not idempotent; effects applied twice. Fix: idempotent processing.
- **The "exactly once" misclaim.** Vendor claims exactly-once delivery. Customer relies on this. Edge case (network blip during commit) produces duplicates. Lawsuit. Lesson: be precise about semantics.

The senior engineer's habits:
- **Idempotency keys mandatory** for every state-changing API.
- **Dedup at every layer**: API, queue, database.
- **Outbox pattern** for reliable event emission.
- **Test with simulated retries**.
- **TTL idempotency records** with audit logs.
- **Document semantics precisely** (at-least-once + idempotent).

---

## Failure Scenarios

**Scenario 1 — The double-charge incident.**
A flaky network during payment. Client retries without idempotency key (legacy code). Two charges. Customer complains. Refund issued; customer churns. Lesson: enforce idempotency keys.

**Scenario 2 — The unconstrained retry storm.**
Service consumer has bug; throws exception; queue retries; bug persists; same message processed thousands of times. Effects are non-idempotent. Recovery: investigation; partial reversal of effects; emergency fix.

**Scenario 3 — The outbox-less dual-write.**
Service writes order to DB and event to Kafka separately. DB commits; Kafka write fails; rolling back DB is too late. Inconsistent state visible to other services. Recovery: reconciliation job; eventually outbox pattern adopted.

**Scenario 4 — The non-atomic dedup.**
Consumer marks message processed *after* business logic. Crashes between business logic and mark. Retry: business logic re-executed. Mitigation: same-transaction dedup record.

**Scenario 5 — The expired key reuse.**
TTL set to 5 minutes. Customer retries after 10 minutes (slow connectivity). Key has expired. Operation re-executed. Double-effect. Mitigation: longer TTL (24h+); audit logs.

---

## Performance Perspective

- **Dedup lookup**: typically a fast in-memory or Redis lookup. Microseconds.
- **Persistent dedup**: DB row with unique constraint. Millisecond-class.
- **Outbox polling**: trade-off frequency vs latency. Sub-second polling is common.
- **Idempotent producers**: small bandwidth overhead for sequence numbers.

---

## Scaling Perspective

- **Idempotency store**: scales horizontally (sharded by key).
- **Outbox**: per-service; scales with service.
- **Kafka EOS**: well-tested at large scale; performance cost ~10-30%.
- **At hyperscale**: dedicated dedup services; specialized stores.

---

## Cross-Domain Connections

- **Timeouts/retries**: idempotency makes retries safe. (See [timeouts-retries-and-idempotency.md](../system-failures/timeouts-retries-and-idempotency.md).)
- **Sagas**: each saga step is idempotent. (See [saga-pattern-and-distributed-transactions.md](./saga-pattern-and-distributed-transactions.md).)
- **CQRS / event sourcing**: events with unique IDs are naturally idempotent. (See [cqrs-and-event-sourcing.md](./cqrs-and-event-sourcing.md).)
- **API design**: idempotency keys are a standard API contract element. (See [api-design-rest-vs-grpc.md](./api-design-rest-vs-grpc.md).)
- **Cascading failures**: idempotency makes retry-based recovery safe. (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)

The unifying observation: **idempotency is the application-layer compensation for the network's inability to deliver exactly once. Every reliable distributed system depends on this pattern, somewhere.**

---

## Real Production Scenarios

- **Stripe's idempotency-key documentation**: industry-shaping reference.
- **AWS SDK retry patterns**: idempotency hints throughout.
- **Kafka exactly-once semantics**: documented design and trade-offs.
- **Database CDC + idempotent consumers**: pattern in many event-driven architectures.
- **The "we promised exactly-once and shipped duplicates" stories**: numerous public postmortems.

---

## What Junior Engineers Usually Miss

- That **exactly-once delivery is impossible**.
- That **at-least-once + idempotent = effectively-once**.
- That **idempotency must be at every layer**.
- That **idempotency keys must be unique** per operation.
- That **the dedup window TTL matters**.
- That **mid-process crashes** can cause re-execution if dedup isn't atomic with business effect.
- That **commutativity is also useful** for out-of-order delivery.
- That **CRDTs are inherently idempotent**.

---

## What Senior Engineers Instinctively Notice

- They **enforce idempotency keys** on state-changing APIs.
- They **dedup at every retry boundary**.
- They **use outbox pattern** for reliable event emission.
- They **test with chaos-injected retries**.
- They **set sensible TTLs** on dedup records.
- They **distinguish delivery semantics from effect semantics**.
- They **never claim exactly-once delivery**.

---

## Interview Perspective

What gets tested:

1. **"Exactly-once vs at-least-once?"** Tests fundamental literacy.
2. **"What's an idempotency key?"** Tests practical knowledge.
3. **"Outbox pattern?"** Tests dual-write awareness.
4. **"How does Kafka EOS work?"** Tests Kafka-specific.
5. **"How would you make a payment API idempotent?"** Tests applied design.
6. **"What's atomic dedup?"** Tests subtle correctness.

Common traps:
- Believing exactly-once delivery is achievable.
- Not knowing about outbox.
- Skipping idempotency at one layer.

---

## 20% Knowledge Giving 80% Understanding

1. **Exactly-once delivery is impossible.**
2. **At-least-once + idempotent = effectively-once.**
3. **Idempotency keys** for state-changing APIs.
4. **Dedup at every layer**: API, queue, database.
5. **Outbox pattern** for reliable event emission.
6. **Kafka EOS** for in-Kafka effectively-once.
7. **Atomic dedup record** with business effect.
8. **TTL idempotency records** appropriately.
9. **CRDTs are inherently idempotent**.
10. **Document semantics precisely** to users.

---

## Final Mental Model

> **The network gives you at-least-once. Your application, with discipline, gives you effectively-once. The discipline is idempotency keys, atomic dedup, outbox patterns, and idempotent consumers. The reward is application-level correctness in the face of network unreliability — and the immunity to a class of bugs that would otherwise haunt you forever.**

The senior engineer designing reliable systems treats idempotency as a foundation, not an enhancement. Every API with side effects has idempotency. Every queue consumer dedupes. Every retried operation is safe. The cost is a small amount of plumbing; the benefit is correctness even under arbitrary failure.

The systems that handle billions of dollars without double-charging customers are the ones with this discipline. The systems that have made the news for double-charging or losing data are the ones that didn't. The technique is well-understood; the discipline of applying it everywhere is what separates teams.

That's idempotency receivers. That's effectively-once semantics. That's how you build correctness on top of an unreliable network — and the foundation under every payment, every transaction, every reliable distributed action you've ever depended on.
