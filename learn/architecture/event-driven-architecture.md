# Event-Driven Architecture (EDA)

## A. Intuition First
Services react to **events** (things that happened) rather than call each other directly. Loose coupling, natural async, great fit for microservices.

## B. Mental Model
- **Event producer** — emits "something happened" (e.g., `order.placed`).
- **Event router / broker** — delivers.
- **Event consumer(s)** — react independently.

Contrast with command-driven: command = "do this now"; event = "this happened".

## C. Internal Working
Two common topologies:
- **Mediator / orchestrator**: central brain sequences steps (Step Functions, Temporal).
- **Choreography**: each service listens for events and fires its own.

### 🪜 Same example, both styles — order checkout

**Choreography:**
1. `Order.Placed` → Inventory listens; reserves stock → publishes `Inventory.Reserved`.
2. `Inventory.Reserved` → Payment listens; charges card → publishes `Payment.Succeeded`.
3. `Payment.Succeeded` → Shipping listens; books carrier → publishes `Shipping.Booked`.
- Pro: no central brain; teams own their piece.
- Con: "where does the order stand?" requires scanning logs across services. Hard to debug.

**Orchestration (Temporal-style):**
1. Orchestrator workflow receives `PlaceOrder` request.
2. Calls `Inventory.Reserve` → waits → success.
3. Calls `Payment.Charge` → waits → success.
4. Calls `Shipping.Book` → waits → success.
5. Orchestrator stores state at every step; on crash, resumes.
- Pro: workflow visible in one place; compensations easy to express.
- Con: orchestrator is a central dependency.

> **🔎 Quick Check** — For a 10-step workflow with complex conditional branches and compensations, which fits better?
> **🎯 Recall** — Orchestration. Debugging a 10-step choreography is a nightmare.

## D. Visual Representation
```
[Order service] ─emit `order.placed`─▶ [Topic]
                                         ├─▶ [Inventory service]
                                         ├─▶ [Payment service]
                                         └─▶ [Notification service]
```

## E. Tradeoffs
**Pros**: loose coupling, scale independently, natural audit trail, extensible (new subscribers drop in).
**Cons**: harder to reason about end-to-end flows, debugging (trace IDs essential), eventual consistency, duplicate event handling (idempotency required).

## F. Interview Lens
- "EDA vs request/response?" — async vs sync.
- "Sagas vs orchestration?" — covered in [Distributed Transactions](../data/distributed-transactions.md).
- "How do you debug?" — correlation IDs, distributed tracing.
- Pitfalls: no schema discipline → event chaos.

## G. Real-World Mapping
Netflix uses EDA heavily; AWS EventBridge/SNS/SQS; Uber's internal event bus.

## H. Questions
**Beginner**: Events vs commands?
**Intermediate**: Orchestration vs choreography?
**Advanced**: Design an event-driven order processing pipeline with retries and DLQ.

## I. Mini Design
E-commerce: `OrderPlaced` → inventory reserves, payment charges, shipping schedules. Compensations on failure via saga choreography.

## J. Cross-Topic Connections
- [Pub-Sub](pub-sub.md), [Event Sourcing](event-sourcing.md), [CQRS](cqrs.md), [Message Brokers](message-brokers.md), [Microservices](monolith-vs-microservices.md).

## K. Confidence Checklist
- [ ] Knows event vs command distinction.
- [ ] Knows orchestration vs choreography.
- [ ] Knows idempotency/dedup is required.

## L. Potential Gaps & Improvements
- **Event schema governance (Avro + Schema Registry)** — Avro is a compact binary format with a defined schema, and a Schema Registry stores and version-checks those schemas so producers can't break consumers; vital for evolving events safely over time.
- **Outbox pattern for atomic DB+event writes** — write the event into an "outbox" table in the same database transaction as your business change, then relay it to the broker; guarantees you never save data without publishing its event (no lost messages).
- **CDC (Change Data Capture)** — tools like Debezium tail the database transaction log and emit every row change as an event; a popular way to power the outbox relay and keep downstream systems in sync.
- **DLQ (Dead Letter Queue)** — a side queue where messages land after repeatedly failing processing, so one poison event doesn't block the whole stream and you can inspect/replay it later.
- **Idempotent consumers** — design handlers so processing the same event twice has no extra effect (e.g. dedupe by event ID); essential because most brokers deliver "at-least-once" and will sometimes redeliver.
- **EOS (Exactly-Once Semantics)** — broker features (like Kafka transactions) that ensure each event is processed once even with retries; useful when duplicate side effects (double charges) are unacceptable (→ see Interview Lens).

**🔧 How to close:** Spin up Kafka locally and watch redelivery happen: `docker run -p 9092:9092 apache/kafka:latest`, then in two terminals run `kafka-console-producer.sh --topic demo --bootstrap-server localhost:9092` and `kafka-console-consumer.sh --topic demo --from-beginning --bootstrap-server localhost:9092`; kill the consumer mid-batch before it commits offsets, restart it, and observe the same messages replay — proving why you need idempotent consumers.
