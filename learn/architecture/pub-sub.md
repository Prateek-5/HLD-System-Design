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
- **Schema Registry** — a central service that stores and versions the message format (e.g. Avro/Protobuf) so producers and consumers agree on structure; matters because it stops a renamed field from silently breaking every downstream consumer.
- **EOS (Exactly-Once Semantics)** — Kafka transactions plus idempotent producers guarantee each message is processed once even after retries or crashes; learners care because "at-least-once" defaults can cause duplicate charges or double-counted events. (→ see Advanced Questions)
- **DLQ (Dead Letter Queue)** — a side topic/queue where messages that repeatedly fail processing get parked instead of blocking the stream; essential so one poison message doesn't stall the whole consumer.
- **Idempotent consumers** — designing handlers so reprocessing the same message has no extra effect (via dedup keys); the practical answer to "what if a message is delivered twice?".

**🔧 How to close:** Spin up Kafka locally and watch ordering and consumer-group rebalancing firsthand: `docker run -d --name=kafka -p 9092:9092 apache/kafka:latest`, then create a 3-partition topic with `kafka-topics.sh --create --topic demo --partitions 3 --bootstrap-server localhost:9092`, produce keyed messages with `kafka-console-producer.sh --topic demo --property "parse.key=true" --property "key.separator=:" --bootstrap-server localhost:9092`, and start two `kafka-console-consumer.sh --topic demo --group g1` instances to see partitions split across the group.
