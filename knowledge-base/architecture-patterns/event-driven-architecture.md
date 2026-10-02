# Event-Driven Architecture

> *"Events are statements about the past. Commands are requests about the future. Architecting around events instead of commands is a way of saying: 'I trust the past more than I trust the request that just arrived.' Done right, this produces systems with looser coupling, better history, and more reliability. Done wrong, it produces a distributed mess where nobody knows what's happening."*

---

## Topic Overview

Event-driven architecture (EDA) is the pattern where services communicate by emitting and consuming *events* — facts about things that happened — rather than calling each other directly. "Order placed." "Payment received." "Inventory reserved." Each event is a message published to a broker; interested services consume it asynchronously.

The pattern decouples producers from consumers. The order service doesn't know who consumes "OrderPlaced" events; it just emits them. New consumers can be added without changing the producer. Consumers can fail and restart without blocking producers. The temporal coupling typical of synchronous APIs disappears.

The cost is operational complexity. Eventual consistency is the norm. Debugging "why did this happen?" requires distributed tracing across many services. Schema evolution is harder. Order-of-events matters but is hard to enforce. Many teams adopt EDA expecting simplicity and find a different kind of complexity.

This is the topic where Kafka, queues, sagas, CQRS, and event sourcing meet. Done well, EDA is the substrate for resilient, scalable distributed systems. Done badly, it's a mass of moving parts nobody understands.

---

## Intuition Before Definitions

Imagine running a magazine subscription service.

**Synchronous (request/response).** A customer subscribes; the subscription service calls the billing service; billing returns success or failure; subscription service calls the fulfillment service; fulfillment returns success or failure; subscription service confirms to customer. Every step is in-line. If any service is down, the whole flow fails.

**Event-driven.** Customer subscribes; subscription service emits "SubscriptionCreated" event. Billing service consumes the event; charges the card; emits "PaymentCompleted" or "PaymentFailed." Fulfillment service consumes "PaymentCompleted"; ships first issue; emits "OrderShipped." Email service consumes "PaymentCompleted" and "OrderShipped"; sends emails.

Each service does its piece. None calls another directly. If billing is down briefly, events queue; processing resumes. If fulfillment is slow, billing isn't blocked. New consumers (analytics, fraud detection) can be added by subscribing to existing events.

That's event-driven architecture. The flow is the same; the coupling is different. Resilience, evolvability, and observability change shape.

---

## Historical Evolution

**Era 1 — Pub/sub on message brokers.**
1990s, 2000s. JMS, MQ, RabbitMQ. Publisher-subscriber decoupling. Used in enterprise; less in web.

**Era 2 — SOA and message buses.**
2000s. Enterprise Service Bus pattern. Heavy, often centralized. Mixed track record.

**Era 3 — Microservices + simple queues.**
~2014. Microservices boom; many used simple queues (RabbitMQ, SQS) for async work.

**Era 4 — Kafka and event streaming.**
~2015. Kafka's adoption transformed thinking. Events as durable, replayable streams. Confluent, enterprise adoption.

**Era 5 — Modern EDA patterns.**
2018+. Event sourcing, CQRS, sagas as named patterns. Tooling matures (Schema Registry, Kafka Streams, Flink).

**Era 6 — Cloud-native eventing.**
AWS EventBridge, Google Eventarc, Azure Event Grid. Managed eventing as part of cloud platforms. CloudEvents spec for standardization.

The pattern: each generation made event-driven easier and more reliable. The fundamentals — pub/sub, async processing, eventual consistency — remain.

---

## Core Mental Models

**1. Events are facts about the past.**
"OrderPlaced" — this happened. Immutable. Other services react. Events are *not* commands; nobody is being told what to do.

**2. Producers and consumers are decoupled.**
Producer doesn't know who's listening. Consumers don't know who emitted. They share a contract: the event schema.

**3. Temporal decoupling.**
Producer can be down; events queue. Consumer can be down; producer keeps emitting. Eventually they sync.

**4. Eventual consistency is the default.**
"OrderPlaced" emitted; consumers process at their own pace. The state across the system is briefly inconsistent. Designs must accommodate this.

**5. Order of events matters but is hard.**
Events from one producer to one partition are typically ordered. Events across producers, across partitions, across consumers are not. Reasoning about ordering is real work.

---

## Deep Technical Explanation

### Events vs commands vs messages

- **Event**: a fact about something that happened. "OrderPlaced." Past-tense.
- **Command**: a request to do something. "PlaceOrder." Imperative.
- **Message**: generic; can be either, plus replies, queries, etc.

Event-driven architectures are built around events. Commands fit better in synchronous request/response patterns.

The naming matters. "OrderPlaceRequested" (event) vs "PlaceOrder" (command) — different semantics. Events imply "this happened; react if relevant"; commands imply "do this thing."

### Pub/sub semantics

A producer publishes to a *topic*. Consumers *subscribe* to topics.

Two delivery models:
- **At-most-once**: messages may be lost; never duplicated. Rare in modern systems.
- **At-least-once**: messages may be duplicated; never lost. Standard. Requires idempotent consumers.
- **Effectively-once**: at-least-once + idempotent consumers + careful design.

(See [idempotency-receivers-and-exactly-once-semantics.md](./idempotency-receivers-and-exactly-once-semantics.md).)

### Brokers

The infrastructure that holds events:
- **Kafka**: log-based; durable; ordered within partitions; replay possible.
- **RabbitMQ**: queue-based; flexible routing; less suited for replay.
- **AWS SQS**: simple queues; managed; no ordering guarantees in standard mode.
- **AWS Kinesis, Google Pub/Sub**: managed log-based.
- **NATS**: lightweight; many delivery modes.

The choice shapes the architecture. Kafka's persistence enables event sourcing; SQS's simplicity is fine for transient work queues.

### Schema management

Events have schemas. Schemas evolve. Producers and consumers may have different versions. Without management:
- Producer changes schema; consumer breaks.
- Old events are unparseable.
- Coordination is painful.

Solutions:
- **Schema registry** (Confluent): producers register schema; consumers fetch by ID. Compatibility checks (backward, forward, full).
- **Versioned events**: separate `OrderPlaced.v1`, `OrderPlaced.v2` topics. Old consumers see v1; new ones can opt into v2.
- **Schema languages**: Avro, Protobuf, JSON Schema. Each has trade-offs.

The discipline: events are forever-additive; never break old consumers.

### Choreography vs orchestration

**Choreography:** services react to events independently. No central coordinator.

```
OrderService emits OrderPlaced
  → PaymentService consumes; emits PaymentCompleted
    → FulfillmentService consumes; emits OrderShipped
      → EmailService consumes; sends email
```

Pros: decentralized; loose coupling.
Cons: hard to see the big picture; debugging "what's the state of order X?" requires aggregating across services.

**Orchestration:** a central orchestrator drives the flow.

```
Orchestrator → OrderService.PlaceOrder
            ← OrderPlaced
Orchestrator → PaymentService.Charge
            ← PaymentCompleted
Orchestrator → FulfillmentService.Ship
            ← OrderShipped
```

Pros: visible flow; easier to monitor.
Cons: central point of coupling; orchestrator must be highly available.

Many modern systems use both: orchestrator for complex business flows; choreography for simple reactions.

### Event sourcing

A specific use of EDA: instead of storing current state, store the *log of events*. Current state is a fold over events. (See [cqrs-and-event-sourcing.md](./cqrs-and-event-sourcing.md).)

Powerful but operationally expensive. Most EDA isn't event sourcing.

### Sagas

Multi-step business flows expressed as sequences of events with compensation. (See [saga-pattern-and-distributed-transactions.md](./saga-pattern-and-distributed-transactions.md).)

A natural fit for event-driven architectures.

### The outbox pattern

Database transaction + event emission must be atomic. Without atomic dual-writes, inconsistency is possible.

The outbox pattern: in the same transaction, write business state + write event to an outbox table. A separate process polls the outbox and publishes events. (Detailed in [saga-pattern-and-distributed-transactions.md](./saga-pattern-and-distributed-transactions.md).)

This is the standard pattern for reliable event emission in EDA.

### Ordering

Events from one producer to one partition arrive in order. Across partitions: not.

Implications:
- **Per-key ordering**: hash by key (e.g., user_id) so all events for one user are in the same partition.
- **Cross-key ordering**: not maintained; designs must not assume.
- **Causal ordering**: track explicitly with sequence numbers or HLCs.

A common bug: assuming global order. Real systems rarely have it.

### Consumer patterns

**Consumer group**: multiple instances of one consumer share work. Each event delivered to exactly one instance in the group.

**Multiple consumer groups**: each group sees every event. Multiple services can subscribe independently.

**Replay**: consume events from the beginning of the topic; rebuild state. Powerful for recovering from bugs or building new views.

### Backpressure in event systems

What if the consumer can't keep up?

- **Kafka**: events accumulate in the broker. Lag grows. Producer is unaffected. Consumer can fall arbitrarily behind (until retention boundary).
- **SQS**: similar; queue fills.
- **RabbitMQ**: depends on configuration; can apply backpressure to producer.

Operational metric: **consumer lag**. Lag is the canonical signal for "consumer is overloaded or stuck."

### Failure modes

- **Producer down**: events not emitted; consumers idle.
- **Broker down**: catastrophic; producers and consumers blocked.
- **Consumer down**: lag grows; if down too long, retention may purge unconsumed events.
- **Slow consumer**: lag grows; same as down at limit.
- **Bad event**: poison pill; consumer fails repeatedly. Mitigation: dead-letter queue.

Each failure has different mitigations. Production-ready EDA has thoughtful answers for all.

### Dead-letter queues

A queue for events that consistently fail processing. Move to DLQ; alert; investigate later. Prevents one bad event from blocking the queue indefinitely.

### Schema evolution patterns

- **Add fields**: optional; old consumers ignore.
- **Remove fields**: mark deprecated; eventually remove after consumers migrate.
- **Change semantics**: never. Add a new event type instead.
- **Versioning**: `OrderPlaced.v1`, `OrderPlaced.v2` as separate topics.

The discipline: events are a contract with downstream services. Treat schema changes as you'd treat API changes.

---

## Real Engineering Analogies

**The newspaper subscription.**
Newspapers publish; subscribers read at their own pace. Publishers don't know individual readers; readers don't talk back. New publications start; subscribers add them. Old publications cease; subscribers unsubscribe. The decoupling is total.

That's pub/sub. The publisher is the event producer; the newspaper is the topic; subscribers are consumers.

**The hotel front desk vs the radio dispatcher.**
A hotel front desk (synchronous): guest asks for service; front desk dispatches; waits for reply; tells guest. If anything is busy, the guest waits.

A radio dispatcher (event-driven): events broadcast on the radio. Maintenance hears "Room 401 needs towels." Front desk hears "Guest checking in." Each responds to its events. Nobody waits in line.

---

## Production Engineering Perspective

What goes wrong:

- **The poison pill.** A bad event causes a consumer to fail. Consumer retries; fails; retries forever. Other events queue. Mitigation: DLQ.
- **The schema-break disaster.** Producer ships a schema change; consumers can't parse. Either consumers fail (visible) or silently misinterpret (subtle). Recovery: roll back; education; schema registry.
- **The "where's my order" problem.** Customer support asks "where is order X?" In EDA, the answer requires aggregating events from many services. Tooling needed; ad-hoc queries painful.
- **The ordering bug.** Code assumed events arrived in order. Rare race condition: out-of-order; logic incorrect. Mitigation: per-key partitioning; explicit ordering with sequence numbers.
- **The duplicate-processing bug.** Consumer not idempotent. Network blip causes redelivery; double-processed. Effects compound. Mitigation: idempotent consumers.
- **The lag explosion.** Consumer can't keep up; lag grows; eventually retention purges unconsumed events. Data loss. Mitigation: lag alerts; auto-scale consumers; capacity planning.
- **The orphaned topic.** Topic created; no consumers ever attached; events accumulate forever; eventually disk pressure. Mitigation: ownership; retention policies.

The senior engineer's habits:
- **Schema registry** mandatory.
- **Idempotent consumers** by default.
- **Outbox pattern** for reliable emission.
- **Monitor lag** continuously.
- **DLQ** for poison pills.
- **Distributed tracing** across event flows.
- **Document event contracts** like APIs.
- **Treat events as forever** (additive evolution).

---

## Failure Scenarios

**Scenario 1 — The poison pill cascade.**
Producer ships malformed events. Consumer fails on each. Retries; no progress. Lag grows. Other (valid) events also blocked because they're behind the poison pill in the queue. Mitigation: skip-on-failure with DLQ.

**Scenario 2 — The schema mismatch.**
Producer adds a required field. Old consumers can't parse. Errors flood logs. Mitigation: schema registry with backward compatibility checks; field made optional with default.

**Scenario 3 — The dual-write inconsistency.**
Service writes order to DB; emits event to Kafka separately; DB succeeds; Kafka fails. Order in DB but no event published. Other services don't know. Mitigation: outbox pattern.

**Scenario 4 — The replay disaster.**
Engineer "replays" Kafka topic to rebuild a state. Consumer is non-idempotent. Side effects (emails sent again, payments re-processed). Mitigation: idempotent consumers; or test replays in staging only.

**Scenario 5 — The retention loss.**
Consumer down for maintenance. Topic retention is 7 days. Maintenance takes 8 days. Events purged. Data lost. Mitigation: longer retention; or robust failover.

---

## Performance Perspective

- **Producer latency**: ~milliseconds for Kafka; ~tens of microseconds for in-memory brokers.
- **End-to-end latency** in event flows: dominated by consumer processing time + lag.
- **Throughput**: Kafka scales to millions of events/sec per cluster.
- **Consumer scaling**: parallelize across partitions.
- **Operational overhead**: brokers, schema registry, observability — significant.

---

## Scaling Perspective

- **Vertical**: bigger brokers; more partitions per broker.
- **Horizontal**: more brokers; more partitions; more consumers.
- **Geographic**: cross-region mirroring (Kafka MirrorMaker); higher latency.
- **At hyperscale**: dedicated streaming platform; integration with data infrastructure.

---

## Cross-Domain Connections

- **Sagas**: sagas built on events. (See [saga-pattern-and-distributed-transactions.md](./saga-pattern-and-distributed-transactions.md).)
- **CQRS / event sourcing**: event-driven naturally. (See [cqrs-and-event-sourcing.md](./cqrs-and-event-sourcing.md).)
- **Idempotency**: required for at-least-once consumers. (See [idempotency-receivers-and-exactly-once-semantics.md](./idempotency-receivers-and-exactly-once-semantics.md).)
- **Backpressure**: queues are backpressure mechanisms. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Distributed tracing**: critical for debugging EDA. (See [distributed-tracing-deep-dive.md](../observability/distributed-tracing-deep-dive.md).)
- **Microservices**: EDA is the typical communication style. (See [microservices-vs-monolith.md](./microservices-vs-monolith.md).)

The unifying observation: **event-driven architecture is loose coupling realized through asynchronous facts. Every distributed-systems pattern (idempotency, sagas, eventual consistency, distributed tracing) becomes more relevant in EDA.**

---

## Real Production Scenarios

- **LinkedIn's Kafka origin**: built for activity stream events; spawned the company.
- **Netflix's event-driven architecture**: extensive public engineering.
- **Uber's events at scale**: hundreds of services; trillions of events.
- **Stripe's event delivery**: customer-facing webhooks built on internal event streams.
- **Slack's job queues**: documented evolution from RabbitMQ to Kafka.
- **The Confluent ecosystem**: Schema Registry, Kafka Streams, ksqlDB.

---

## What Junior Engineers Usually Miss

- That **events are facts, not commands**.
- That **producers and consumers are decoupled** (don't know each other).
- That **eventual consistency is the default**.
- That **ordering is per-partition**, not global.
- That **at-least-once requires idempotent consumers**.
- That **schemas need management** at scale.
- That **debugging is harder** without tracing.
- That **outbox pattern** for atomic dual writes.

---

## What Senior Engineers Instinctively Notice

- They **use schema registry** by default.
- They **build idempotent consumers**.
- They **use outbox pattern** for reliability.
- They **monitor consumer lag** as primary signal.
- They **set up DLQs** for poison pills.
- They **distribute trace** across event flows.
- They **document events as forever-contracts**.
- They **distinguish choreography from orchestration**.

---

## Interview Perspective

What gets tested:

1. **"What's event-driven architecture?"** Tests fundamentals.
2. **"Pub/sub vs request/response?"** Decoupled vs coupled.
3. **"What's the outbox pattern?"** Atomic DB write + event emission.
4. **"Choreography vs orchestration?"** Decentralized vs central.
5. **"How do you handle schema evolution?"** Registry, backward compatibility.
6. **"What's a dead-letter queue?"** Quarantine for failed events.
7. **"How do you debug event flows?"** Distributed tracing; aggregated state.

Common traps:
- Confusing events with commands.
- Believing global ordering exists.
- Assuming exactly-once delivery.

---

## 20% Knowledge Giving 80% Understanding

1. **Events = past facts**; loose coupling.
2. **At-least-once + idempotent consumers** = reliable.
3. **Outbox pattern** for atomic dual writes.
4. **Schema registry** for evolution.
5. **DLQ** for poison pills.
6. **Per-key ordering**, not global.
7. **Consumer lag** is the canonical metric.
8. **Choreography** for simple flows; **orchestration** for complex.
9. **Distributed tracing** for debugging.
10. **Events are forever**: additive only.

---

## Final Mental Model

> **Event-driven architecture is the choice to decouple producers from consumers via durable facts. Every other distributed-systems concept — eventual consistency, idempotency, sagas, observability — becomes essential, not optional. The systems that thrive in EDA are the ones whose teams treat events as a contract; the systems that struggle are the ones that thought "we'll figure out the contract later."**

The senior architect designing EDA treats it as discipline, not just technology. Schema registry. Outbox pattern. Idempotent consumers. DLQs. Lag monitoring. Distributed tracing. Each is a small piece; together they form a foundation that scales to billions of events without losing comprehension.

Teams that succeed with EDA build these pieces deliberately. Teams that fail with EDA discover, after three years and two outages, that they should have. The pattern is powerful; the engineering investment is real.

That's event-driven architecture. That's the substrate of modern reactive systems. That's the design that lets services evolve independently — when you've done the work to make it actually evolvable.
