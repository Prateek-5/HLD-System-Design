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

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔁 Gap 1 — Idempotent Consumers & Delivery Semantics
- 🔹 **What it is**: Writing message handlers so that processing the same message twice has the same effect as processing it once — usually via a dedup key or a "have I seen this ID?" check.
- 🔹 **Why it matters**: Pub-sub systems default to *at-least-once* delivery, so duplicates are normal, not exceptional. Without idempotency you get double charges, double emails, double-counted analytics.
- 🔹 **Connection**: §E warns that "at-least-once implies idempotent consumers," and Advanced Question 2 asks how exactly-once is achieved — this is the practical first line of defense.
- 🔹 **When needed**: 🟢 **Foundational** — almost every real consumer needs this; it shows up in interviews the moment you mention pub-sub or queues.
- 🔹 **Intuition**: A hotel front desk stamps each guest's keycard request with a ticket number; if the same request arrives twice, the desk sees the number is already filled and just hands back the same key instead of charging another night.
- 🔹 **If you go deeper**: Implement a dedup store (Redis `SETNX` on message ID, or a unique constraint in Postgres). Read about the "inbox pattern" / transactional inbox for tying dedup to your DB write.
- 🔹 **Interview hook**: *"A consumer crashed after processing but before committing the offset — what happens?"* → The message is redelivered; an idempotent handler makes the reprocess harmless.

---

#### 📜 Gap 2 — Schema Registry & Contract Evolution
- 🔹 **What it is**: A central service that stores and versions the message format (Avro/Protobuf/JSON Schema) so producers and consumers agree on structure and can evolve it safely.
- 🔹 **Why it matters**: In a fan-out world, one producer feeds many independent consumers (§D). A renamed or dropped field can silently break every downstream service; a registry enforces compatibility rules before a bad schema ships.
- 🔹 **Connection**: §I adds a new consumer that "replays history" — that replay only works if old messages still deserialize, which is exactly what schema compatibility guarantees.
- 🔹 **When needed**: 🟡 **Mid-level** — important once you have more than one team consuming a topic; rarely needed for a single-app prototype.
- 🔹 **Intuition**: A shared shipping-label standard — as long as every warehouse prints the address in the same boxes, you can add a "delivery note" field without breaking older scanners that just ignore it.
- 🔹 **If you go deeper**: Set up Confluent Schema Registry with Avro and test BACKWARD vs FORWARD vs FULL compatibility modes; compare with Protobuf's field-number rules.
- 🔹 **Interview hook**: *"How do you add a field to an event without breaking existing consumers?"* → Make it optional/backward-compatible and enforce it via a schema registry.

---

#### ☠️ Gap 3 — Dead Letter Queues & Poison Messages
- 🔹 **What it is**: A side topic/queue where messages that repeatedly fail processing are parked after N retries, instead of being retried forever and blocking the stream.
- 🔹 **Why it matters**: One malformed ("poison") message on a partition can stall every message behind it, halting the whole consumer. A DLQ isolates the bad one so the good ones keep flowing.
- 🔹 **Connection**: §C explains each consumer group tracks its own offset per partition — a poison message blocks offset progress on that partition until it's moved aside.
- 🔹 **When needed**: 🟡 **Mid-level** — essential for any production consumer; commonly probed in resilience/reliability interview rounds.
- 🔹 **Intuition**: A mail sorting line where an unreadable envelope gets tossed into a "manual review" bin so the rest of the mail keeps moving down the belt.
- 🔹 **If you go deeper**: Implement retry-with-backoff plus a DLQ topic in Kafka (or SQS's native `RedrivePolicy`); build a small dashboard to inspect and replay parked messages.
- 🔹 **Interview hook**: *"A single bad message keeps crashing your consumer — what do you do?"* → Cap retries, route to a DLQ, alert, and replay after a fix.

---

#### 🎯 Gap 4 — Exactly-Once Semantics (EOS) in Kafka
- 🔹 **What it is**: Kafka's combination of idempotent producers and transactions that lets a read-process-write pipeline behave as if each message were processed exactly once, even across retries and crashes.
- 🔹 **Why it matters**: Idempotent consumers handle duplicates at the application layer, but EOS pushes the guarantee into the broker so the consume→produce step is atomic — critical for financial or billing pipelines.
- 🔹 **Connection**: Directly answers §H Advanced Question 2 ("Exactly-once in Kafka — how is it achieved?") and addresses §E's note that "exactly-once is hard."
- 🔹 **When needed**: 🔴 **Senior** — genuinely deep; you reach for it in stream-processing and infra-heavy designs, not typical CRUD apps.
- 🔹 **Intuition**: A bank teller who only stamps "DONE" on the ledger after both the debit and the credit are written — if the power cuts midway, nothing is half-committed, so on reboot the transaction either fully happened or didn't.
- 🔹 **If you go deeper**: Read the Kafka EOS design (idempotent producer + `transactional.id` + `read_committed` isolation) and Kafka Streams' `processing.guarantee=exactly_once_v2`; compare with Flink's checkpoint-based exactly-once.
- 🔹 **Interview hook**: *"Is true end-to-end exactly-once possible?"* → Within Kafka's consume-transform-produce loop, yes; once an external side effect (email, third-party API) is involved, you fall back to idempotency.

---

### 🏆 Start here if you have limited time
1. **Idempotent consumers** — the single highest-leverage skill; every pub-sub design assumes at-least-once delivery, so duplicates will hit you first.
2. **Dead letter queues** — the most common production failure mode (one poison message stalling a partition) and an easy interview win.

---

### 🧭 Suggested Deep Dive Order
1. **Idempotent consumers & delivery semantics** (~45 min; foundational, applies everywhere).
2. **Dead letter queues** (~45 min; production resilience, quick to implement).
3. **Schema registry & contract evolution** (~1h; matters once multiple teams share a topic).
4. **Exactly-once semantics in Kafka** (~2h; senior-level depth, only after the above feel solid).
