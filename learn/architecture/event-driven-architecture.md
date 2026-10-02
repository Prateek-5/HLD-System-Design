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
- Event schema governance (Avro + Schema Registry).
- Outbox pattern for atomic DB+event writes.
