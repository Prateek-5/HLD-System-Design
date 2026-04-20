# Distributed Transactions — Sagas & Outbox

### 🔹 1. What This Topic Actually Is
Coordinating state changes across multiple services/DBs as a logical unit. You want atomic-or-nothing across system boundaries.

### 🔹 2. Why It Exists
- In microservices, a single business action touches multiple services (order → payment → inventory → shipping).
- 2PC is theoretically correct but blocking + SPOF. Sagas trade strict ACID for scalable "eventual atomicity" with compensations.

### 🔹 3. Core Concepts (High Signal)
- **2PC (Two-Phase Commit)**: coordinator asks all participants "prepare"; if all OK → "commit". Blocking on coordinator crash. Avoid in modern microservices.
- **3PC**: adds pre-commit phase; mostly academic.
- **Saga**: sequence of local transactions. On failure, execute **compensating transactions** to undo prior steps.
  - *Choreography*: services publish/subscribe to events; each decides next step. Decentralized.
  - *Orchestration*: central workflow engine (Temporal, Step Functions) drives the steps. Easier to debug.
- **Compensations are not rollbacks**: you cannot un-send a payment; you issue a **refund**. Model reality.
- **Outbox pattern**: write DB change + event to a local outbox table in the same DB tx. A relay publishes events from outbox → Kafka. Solves the dual-write (DB + broker) atomicity problem.
- **Idempotency keys**: every mutating endpoint accepts a client-generated key; server dedupes retries. Required to make at-least-once delivery safe.
- **TCC (Try-Confirm-Cancel)**: two-phase with explicit reserve + confirm. Fits ops like inventory reservation.

### 🔹 4. Internal Working
**Saga (orchestration):**
1. Orchestrator starts workflow (Temporal persists state in DB).
2. Step 1 (reserve inventory) → success → persist state → Step 2.
3. Step 2 (charge card) → success → Step 3.
4. Step 3 (book shipping) → fails → orchestrator triggers compensations: refund card → release inventory.

**Outbox + CDC:**
1. Service writes DB change + event row to `outbox` table in same tx.
2. Debezium reads WAL, publishes outbox row as event on Kafka.
3. Consumers react.

> **🧱 What a saga orchestrator knows (and doesn't)**
> ✅ Current step, success/failure of each step, the durable workflow state.
> ❌ Business correctness of the step (it only knows "returned OK"), whether the compensation actually reversed external effects (if the refund API is flaky, nobody knows).
>
> **🪜 Concrete worked saga: "Book a hotel room"**
> 1. Reserve room (hotel service) → success → state `ROOM_RESERVED`.
> 2. Charge card (payment service) → success → state `PAID`.
> 3. Send confirmation email (notification service) → success → state `DONE`.
>
> If step 2 fails:
> - Orchestrator runs compensation for step 1 → release room.
> - Email "sorry, payment failed" (idempotent — user may have retried).
> - State `CANCELLED`.
>
> If step 3 fails (after payment succeeded):
> - Room + payment are already committed. Retry email, don't roll back. → state `PARTIAL_OK`.
> - This is a **business decision**, not a technical one: you don't refund just because the email didn't send.

**Failure points:** orchestrator dies (workflow engine must persist state durably), duplicate events (idempotency), compensation itself fails (alert + manual), partial completion visible (no isolation across saga).

### 🔹 5. Key Tradeoffs
- **2PC**: atomic but blocking + coordinator SPOF + poor scale.
- **Saga**: scalable, no distributed locks, but **no isolation** (other tx see intermediate states). Compensations can be complex / non-trivial.
- **Outbox**: solves dual-write. Needs CDC infra.
- **TCC**: reserve + confirm pattern. Good for inventory / booking.

### 🔹 6. Interview Questions
**Beginner**
1. Why are cross-service transactions hard?
2. What's a compensating transaction?

**Intermediate**
1. Choreography vs orchestration — when each?
2. What problem does the outbox pattern solve?

**Advanced**
1. Design checkout flow: cart → payment → inventory → shipping. Saga + compensations.
2. How do you handle a compensation that itself fails? (Manual escalation + durable retry.)
3. Outbox vs log tailing vs dual-write — tradeoffs.

### 🔹 7. Real System Mapping
- **Airbnb payments**: idempotency keys (classic blog post).
- **Uber payments / trips**: sagas with Temporal-like orchestration.
- **Netflix Conductor**: workflow orchestrator for sagas.
- **AWS Step Functions, Temporal, Cadence**: orchestrators.
- **Debezium**: CDC engine for outbox.
- **Microservices.io SAGA pattern**: reference.

### 🔹 8. What Most People Miss
- **Sagas lack isolation** — another transaction may read partially-completed state. Model your UI/consumers to tolerate it.
- **Outbox relay must be exactly-once or deduped** — Kafka event dedup via event ID.
- **Orchestration engines are a dependency** — Temporal/Conductor themselves must be HA.
- **Timeouts in saga steps** are crucial: a "pending" payment that never resolves blocks forever.
- **Compensations are business decisions** — refunding a $10 payment may incur $2 fees; sometimes acceptable, sometimes not.
- **Idempotency keys** must be scoped correctly (per user per API) — TTL them in Redis.

### 🔹 9. 30-Second Revision
Don't 2PC across services. Use sagas (choreography or orchestration) with compensations. Outbox pattern kills the DB+Kafka dual-write race. Idempotency keys make retries safe. Sagas have no isolation — design UIs to tolerate intermediate states. Temporal / Step Functions run orchestrators for you.

---

## 🔗 Cross-Topic Connections
- **Databases**: transactional outbox is one DB tx + one event emitted.
- **Messaging**: Kafka is the saga + CDC transport.
- **Replication**: CDC builds on replication tech.
- **Consensus**: orchestrator HA often sits on top of etcd/Raft.

---

### Confidence Check
- [ ] Can I design a 4-step saga with compensations?
- [ ] Can I justify outbox over dual-write?

### Gaps
- Exactly-once with outbox + Kafka EOS combined.
- Comparison of Temporal vs Cadence vs Step Functions operational cost.
- When TCC beats saga.
