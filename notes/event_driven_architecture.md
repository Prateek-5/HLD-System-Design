# Event-Driven Architecture (EDA)

> **📎 Prereqs** — If rusty:
> - [`message_queues_and_pubsub.md`](message_queues_and_pubsub.md) — the transport.
> - [`microservices.md`](microservices.md) — why decoupling matters.
> - Async vs sync mental model.

### 🔹 1. What This Topic Actually Is
Services communicate by emitting and reacting to **events** ("something happened"), not by calling each other ("do this"). Loose coupling, natural async.

### 🔹 2. Why It Exists
- Sync RPC couples availability, scale, and deployment. Events decouple.
- New features (notifications, analytics, ML) can subscribe to existing events without changing producers.
- Natural fit for microservices and data pipelines.

### 🔹 3. Core Concepts (High Signal)
- **Event** = an immutable record of past fact (`OrderPlaced`, `UserSignedUp`).
- **Topology**:
  - *Choreography* — services publish & subscribe; no central brain.
  - *Orchestration* — a workflow engine drives steps.
- **Event sourcing** (related): persist *events* as source of truth, derive state by folding.
- **Eventually consistent** by default.
- **Event schema** is a contract — evolve carefully (Schema Registry, Avro/Protobuf, backward compatibility rules).

### 🔹 4. Internal Working
Producer emits event → broker (Kafka) → N subscribers process independently.
Each consumer owns its own offset and reacts at its own rate. Retries + DLQs per consumer.

**Failure points:** schema drift breaking old consumers; consumer lag bloating unbounded; duplicate processing without idempotency; ordering lost across partitions.

### 🔹 5. Key Tradeoffs
**Pros**: loose coupling, fan-out, replay for new features, natural audit trail.
**Cons**: harder end-to-end debugging, eventual consistency, schema governance required, duplicate handling is mandatory.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. Event vs command?
2. Why async is good for scale?

**Intermediate 🟡**
1. Choreography vs orchestration — when each?
2. Handle a new subscriber needing historical events.

**Advanced 🔴**
1. Design event contract versioning across 100 services.
2. Trace debug a cross-service outage with 20 events — how? (correlation IDs + tracing + schema registry)

### 🔹 7. Real System Mapping
- **Martin Fowler** Event-Driven Architecture article + talk.
- **Uber domain-oriented microservices** (uses EDA heavily).
- **Netflix event pipeline** (Keystone, Kafka, Flink).
- **AWS EventBridge**, **Google Eventarc**: managed event buses.

### 🔹 8. What Most People Miss
- **Events vs CRUD messages**: good events describe business facts; bad events are wrapped DB rows ("user updated with this JSON").
- **Schema registry** isn't optional at scale — without it, one producer change breaks N consumers silently.
- **Replayability** is the superpower: new consumers re-process history to build their view.
- **Event storming** (workshop technique) is how you discover the right events before building.
- **Debugging is different**: logs alone don't help; you need distributed tracing + event lineage.

### 🔹 9. 30-Second Revision
EDA = services publish facts; others react. Loose coupling + fan-out + replay. Schema registry mandatory. Idempotent consumers + correlation IDs. Choreography for simple flows; orchestration when you need visibility / complex compensation.

---

## 🔗 Cross-Topic Connections
- **Messaging (Kafka)**: the transport.
- **Databases**: event sourcing stores events instead of state.
- **Saga/distributed tx**: built on EDA.
- **Caching**: CDC events invalidate caches.

---

### Confidence Check
- [ ] Can I design a 3-service choreography with compensation?
- [ ] Can I explain schema evolution rules?

### Gaps
- Domain-driven design depth.
- Event storming workshop practice.
