# Message Brokers — Decoupling Producers and Consumers

## A. Intuition First
A broker is a post office between services. Producers drop messages in, consumers pick them up, on their own schedule.

Decouples senders from receivers (time, availability, speed).

## B. Mental Model
Two fundamental patterns:
- **Queue (point-to-point)**: one message → one consumer.
- **Pub-Sub (topic)**: one message → many subscribers.

## C. Internal Working
- Broker durably stores messages.
- Consumers poll or subscribe.
- Ack required (or auto) before broker deletes.

## D. Visual Representation
```
[Producer] → [Broker: queue/topic] → [Consumer(s)]
```

## E. Tradeoffs
**Pros**: decoupling, smoothing bursts, async processing, retries.
**Cons**: ordering, exactly-once semantics, operational overhead, debugging.

## F. Interview Lens
- "Why add a queue?" — decouple, buffer, retry, fan-out.
- "At-most-once vs at-least-once vs exactly-once?"
- Pitfalls: assuming ordering across partitions; ignoring poison messages.

## G. Real-World Mapping
Kafka, RabbitMQ, ActiveMQ, AWS SQS/SNS, Google Pub/Sub, NATS.

## H. Questions
**Beginner**: Queue vs topic?
**Intermediate**: At-least-once semantics?
**Advanced**: Design a fault-tolerant broker. How does Kafka get its throughput?

## I. Mini Design
Order → Payment service: put order on queue; payment worker consumes; on success, publish `order.paid` event; inventory and shipping subscribe.

## J. Cross-Topic Connections
- [Queues](message-queues.md), [Pub-Sub](pub-sub.md), [EDA](event-driven-architecture.md).

## K. Confidence Checklist
- [ ] Knows queue vs pub-sub.
- [ ] Understands delivery semantics.

## L. Potential Gaps & Improvements
- Kafka internals (partitions, offsets, ISR).
- Dead-letter queues.
- Schema evolution (Avro, Protobuf).
