# Publish-Subscribe — One Event, Many Subscribers

## A. Intuition First
Publisher emits an event. Many subscribers receive it, independently. Core of event-driven architecture.

## B. Mental Model
- **Topic / Channel**: named stream.
- **Publishers** send; **subscribers** receive.
- Each subscriber has its own offset / state.

## C. Internal Working
Kafka-ish:
- Messages appended to a log per topic (partitioned for parallelism).
- Each consumer group tracks its own offset → independent progress.
- Retention-based: messages live for days/weeks, can be re-read.

## D. Visual Representation
```
[Publisher] → [Topic: order.created]
                  ├→ [Inventory subscriber]
                  ├→ [Notification subscriber]
                  └→ [Analytics subscriber]
```

## E. Tradeoffs
**Pros**: loose coupling, fan-out, replayable events.
**Cons**: at-least-once implies idempotent consumers; exactly-once is hard; operational complexity (Kafka clusters aren't simple).

## F. Interview Lens
- "Queue vs pub-sub?" — queue: one consumer per message. Pub-sub: many.
- "Kafka vs RabbitMQ?" — Kafka: persistent log, high throughput, replay. Rabbit: traditional broker, better complex routing semantics, lower throughput.
- Pitfalls: relying on strict ordering across partitions (each partition is ordered; across partitions, no).

## G. Real-World Mapping
Kafka, Google Pub/Sub, SNS, Redis Streams, NATS.

## H. Questions
**Beginner**: Pub-sub vs queue?
**Intermediate**: How do consumer groups work?
**Advanced**:
1. Design event fan-out for order processing.
2. Exactly-once in Kafka — how is it achieved?

## I. Mini Design
User signs up → publish `user.created` → email service, CRM sync, analytics all subscribe. New consumer added later can replay history if retention allows.

## J. Cross-Topic Connections
- [Message Brokers](message-brokers.md), [EDA](event-driven-architecture.md), [Event Sourcing](event-sourcing.md).

## K. Confidence Checklist
- [ ] Knows partitions and consumer groups.
- [ ] Knows ordering guarantees.

## L. Potential Gaps & Improvements
- Schema registry.
- Exactly-once semantics (EOS) in Kafka transactions.
