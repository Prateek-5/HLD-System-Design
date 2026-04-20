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
