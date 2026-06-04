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
- **Kafka internals (partitions, offsets, ISR (In-Sync Replicas))** — partitions shard a topic for parallelism, offsets track each consumer's read position, and ISR is the set of replicas caught up enough to be promoted on failure; understanding these explains Kafka's throughput and durability guarantees. (→ see Advanced Questions)
- **DLQ (Dead Letter Queue)** — a side queue where messages land after repeatedly failing processing, so a single poison message doesn't block the pipeline or get lost silently; essential for any "what happens when a consumer can't handle a message?" question. (→ see Interview Lens)
- **Schema evolution (Avro, Protobuf)** — versioned message formats that let producers and consumers add or change fields without breaking each other, so you can deploy services independently; key for long-lived event streams.
- **EOS (Exactly-Once Semantics)** — broker plus idempotent-producer and transactional features that ensure a message is neither lost nor processed twice, unlike cheaper at-least-once delivery; matters whenever duplicates corrupt results (e.g. billing). (→ see Interview Lens)

**🔧 How to close:** Spin up Kafka locally with `docker run -p 9092:9092 apache/kafka:latest`, then create a 3-partition topic with `kafka-topics.sh --create --topic demo --partitions 3 --bootstrap-server localhost:9092`, produce a few messages, and watch how `kafka-consumer-groups.sh --describe --group g1 --bootstrap-server localhost:9092` shows per-partition offsets and lag move.
