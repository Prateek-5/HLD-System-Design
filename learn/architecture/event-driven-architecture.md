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

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔁 Gap 1 — Idempotent Consumers & At-Least-Once Delivery
- 🔹 **What it is**: Designing event handlers so processing the same event twice produces no extra effect — usually by recording each handled event ID and skipping repeats.
- 🔹 **Why it matters**: Almost every broker (Kafka, SNS/SQS, RabbitMQ) guarantees *at-least-once*, not *exactly-once*, delivery — so duplicates are normal, not exceptional, and a naive handler will double-charge or double-ship.
- 🔹 **Connection**: This file's Tradeoffs and Confidence Checklist both insist "idempotency/dedup is required"; the How-to-close exercise literally makes you watch the same message replay.
- 🔹 **When needed**: 🟢 **Foundational** — the moment you consume real events, you need this; it shows up in almost any EDA interview.
- 🔹 **Intuition**: A hotel front desk that stamps each room key request with a ticket number — if the same ticket comes back, they hand over nothing new instead of charging the guest again.
- 🔹 **If you go deeper**: Implement a dedupe table keyed by event ID with a unique constraint; read Kafka's consumer offset/commit semantics and how SQS visibility timeouts cause redelivery.
- 🔹 **Interview hook**: *"Your payment service sometimes charges customers twice — why, and how do you fix it?"* → at-least-once redelivery; make the handler idempotent by deduping on event ID before charging.

---

#### 📤 Gap 2 — The Outbox Pattern & the Dual-Write Problem
- 🔹 **What it is**: Writing the event into an "outbox" table inside the *same* database transaction as the business change, then a relay reads that table and publishes to the broker.
- 🔹 **Why it matters**: Saving to your DB and publishing to a broker are two separate systems; if you do them as two independent calls, a crash between them silently loses the event or emits a phantom one — the classic dual-write bug.
- 🔹 **Connection**: Builds directly on this file's "Outbox pattern for atomic DB+event writes" gap and underpins the choreography flows in Section C (each step must reliably emit its next event).
- 🔹 **When needed**: 🟡 **Mid-level** — essential once your events trigger money or inventory, and a favorite mid-level system-design follow-up.
- 🔹 **Intuition**: A restaurant kitchen that writes every order onto a spike in the same motion it plates the food — the runner later picks orders off the spike, so an order is never cooked-but-unannounced.
- 🔹 **If you go deeper**: Read the microservices.io "Transactional Outbox" pattern; build a Postgres outbox table plus a polling relay, then upgrade the relay to Debezium (next gap).
- 🔹 **Interview hook**: *"How do you guarantee that saving an order and publishing OrderPlaced either both happen or neither does?"* → write the event to an outbox row in the same transaction, relay it asynchronously.

---

#### 🛰️ Gap 3 — CDC (Change Data Capture) as the Outbox Relay
- 🔹 **What it is**: Tools like Debezium tail the database's write-ahead/transaction log and emit every committed row change as an event — turning your DB itself into an event source.
- 🔹 **Why it matters**: It lets you publish events with no application code in the hot path and no risk of forgetting; it's the most popular production way to drive the outbox relay and keep search indexes, caches, and downstream stores in sync.
- 🔹 **Connection**: Directly extends this file's "CDC (Change Data Capture)" gap and is the natural relay for the Outbox pattern in Gap 2.
- 🔹 **When needed**: 🔴 **Senior** — it's infrastructure plumbing; powerful, but most readers should understand outbox + idempotency first.
- 🔹 **Intuition**: A security camera pointed at the accounting ledger — every time someone writes a line, the camera broadcasts exactly what changed, without the accountant lifting a finger.
- 🔹 **If you go deeper**: Run the Debezium + Postgres + Kafka docker-compose quickstart, make an `UPDATE`, and watch the change event land on a topic; read how log-based CDC differs from query-based polling.
- 🔹 **Interview hook**: *"How would you keep an Elasticsearch index in sync with your Postgres orders table without dual writes?"* → log-based CDC streams every row change as an event the indexer consumes.

---

#### ☠️ Gap 4 — Dead Letter Queues, Retries & Poison Messages
- 🔹 **What it is**: A DLQ (Dead Letter Queue) is a side queue where a message lands after it fails processing too many times, so one bad ("poison") event doesn't block the whole stream.
- 🔹 **Why it matters**: Without it, a single un-processable event stalls a partition or blocks redelivery forever; the DLQ plus a retry/backoff policy keeps the pipeline flowing while preserving the failures for inspection and replay.
- 🔹 **Connection**: This file's Advanced Question explicitly asks you to "design an event-driven order processing pipeline with retries and DLQ," and lists "duplicate event handling" as a core con.
- 🔹 **When needed**: 🟡 **Mid-level** — expected in any production consumer design and a common interview probe.
- 🔹 **Intuition**: A mail sorting line with a "returns" bin — a parcel with an unreadable label gets set aside so the rest of the mail keeps moving, and a human reviews the bin later.
- 🔹 **If you go deeper**: Configure an SQS redrive policy with a `maxReceiveCount` and a DLQ, or a Kafka dead-letter topic via a consumer error handler; add exponential backoff and study retry storms.
- 🔹 **Interview hook**: *"One malformed event keeps crashing your consumer — what happens to everything behind it, and how do you contain the damage?"* → route to a DLQ after N retries so the stream keeps flowing; replay after a fix.

---

### 🏆 Start here if you have limited time
1. **Idempotent consumers (Gap 1)** — at-least-once delivery is universal; every EDA system breaks without dedup, and it's the most-asked question here.
2. **Outbox pattern (Gap 2)** — the cleanest answer to the dual-write problem that interviewers love to poke at.

---

### 🧭 Suggested Deep Dive Order
1. **Idempotent consumers** (~45 min; foundational, unlocks every other topic).
2. **Outbox pattern** (~1h; solves reliable event publishing, common mid-level question).
3. **Dead Letter Queues & retries** (~1h; required for any production consumer design).
4. **CDC as the outbox relay** (~half a day with docker-compose; senior-infra depth that ties outbox + brokers together).
