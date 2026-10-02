# Sagas & Distributed Transactions

> *"A distributed transaction is a contract you can't always honor. A saga is the engineering discipline of admitting that — and writing the apology in code, ahead of time."*

---

## Topic Overview

A transaction, in a single database, is a beautiful thing. ACID guarantees you a clean abstraction: a unit of work that either fully succeeds or fully reverses, with no in-between states visible. Two-decade-old SQL syntax — `BEGIN; …; COMMIT;` — gives you a primitive that's mathematically rigorous and operationally robust.

A *distributed* transaction — across multiple databases, services, or systems — is a different beast. The classical answer (Two-Phase Commit, 2PC) works in theory, fails in practice. Coordinator failures hold resources indefinitely. Network partitions block forever. Performance is unacceptable. Most distributed systems quietly abandoned 2PC two decades ago.

The replacement is the **saga**: a long-running transaction modeled as a sequence of local transactions, each with a *compensating action* that semantically undoes it. Order placed → payment charged → inventory reserved → shipping arranged. If shipping fails, you don't roll back — you *compensate*: refund payment, release inventory. The saga is eventually consistent; intermediate states are visible; failure recovery is application logic, not database magic.

This is the topic where distributed systems theory, transaction semantics, and business processes meet. It's also the topic where the difference between "we tried microservices and it was a disaster" and "we shipped microservices that work" gets decided. Sagas are not a feature you bolt on — they're a way of thinking about state changes across boundaries.

---

## Intuition Before Definitions

Imagine booking a vacation: flight, hotel, rental car, all from different providers.

**The 2PC fantasy**: you click "book trip." A coordinator contacts the airline, hotel, and car rental, asks each "can you reserve this for me, and hold it pending my final word?" All three say yes. The coordinator says "commit." All three confirm. Done.

What can go wrong:
- The hotel says "yes" but the airline times out. The hotel is holding your reservation. Other guests can't book it. You're not booked yet.
- The coordinator crashes between asking and confirming. The hotel waits indefinitely.
- The network partitions during commit. Two systems committed; one didn't. Now you're partially booked.

In real life, you'd never accept this. You book the flight, then the hotel, then the car. If the car rental falls through, you call the hotel and cancel. You don't expect everyone to coordinate atomically; you expect to *handle the messy middle* with retries, calls, refunds, apologies.

That's a saga. A sequence of local commitments, each with a way to back out semantically when something downstream fails. The system is *never* in an "all or nothing" state — it's frequently in "partway through" states. The discipline is making "partway through" *correct* and *recoverable*.

---

## Historical Evolution

**Era 1 — Single-database transactions.**
ACID transactions on a single RDBMS. Beautiful, well-understood. Solved most application needs through the 1990s.

**Era 2 — XA and 2PC.**
The X/Open XA standard formalized distributed transactions in the 1990s. JTA in Java. Microsoft DTC. The promise: ACID across multiple resource managers. The practice: blocking, slow, brittle.

**Era 3 — The saga paper.**
Hector Garcia-Molina and Kenneth Salem publish "Sagas" in 1987 — a long-transaction technique using compensation. Largely ignored in transactional database literature, rediscovered as foundational by the microservices community decades later.

**Era 4 — The microservices reckoning (2010s).**
Service-per-database becomes idiomatic. 2PC across services is rejected as too coupled. Teams reach for sagas, often without naming them. Compensation handlers, idempotency keys, retry queues become part of the operational toolkit.

**Era 5 — Orchestration vs choreography.**
Two saga patterns emerge: an explicit *orchestrator* directs the sequence; or *choreography* via events lets each service react. Both have advantages; both have failure modes. Dedicated tools emerge: Temporal, Camunda, AWS Step Functions, Zeebe.

**Era 6 — The mature view.**
Distributed transactions exist on a spectrum. ACID 2PC for tightly-bounded use cases (cross-shard within a database). Sagas for cross-service workflows. Eventual consistency with reconciliation jobs for data sync. The decision is about coupling, latency, and consistency requirements — not about a single "right answer."

The pattern: each generation realized that ACID guarantees across distrust boundaries are a leaky abstraction, and shifted toward making the *partial-failure path* explicit in design.

---

## Core Mental Models

**1. Atomicity is a property bought with coordination.**
2PC achieves atomicity by holding locks across nodes until everyone agrees. This is expensive and fragile. Sagas achieve a *weaker* property — eventual consistency with semantic recovery — at much lower coordination cost.

**2. Compensation is not rollback.**
A rolled-back transaction is invisible. A compensated saga is *visible* — both the committed step and the compensating step are recorded. If you charged a customer and refunded them, the books show both. This is fundamental and often missed by teams transitioning from monolith.

**3. Idempotency is the prerequisite.**
Every saga step must be idempotent. Re-running it must produce the same effect. Without idempotency, retries create duplicates. With idempotency, retries are safe.

**4. Saga steps must commit local state changes immediately.**
Unlike 2PC, sagas don't hold locks across steps. Each step commits. The world sees intermediate state. Designs must accept this — there is no "isolation" property, full stop.

**5. Failure is normal, not exceptional.**
A saga is a recipe for handling failures, not just for happy-path flow. The compensation logic is *most* of the engineering effort. Treating it as an afterthought guarantees production pain.

---

## Deep Technical Explanation

### Two-Phase Commit (2PC) — for context

The classical algorithm:

**Phase 1 — Prepare:**
- Coordinator: "Can you commit transaction T?"
- Each participant: prepare resources, write to durable log, reply "yes" or "no."

**Phase 2 — Commit/Abort:**
- If all "yes": coordinator says "commit"; participants commit and ack.
- If any "no" or timeout: coordinator says "abort"; participants roll back.

Properties:
- **Atomicity**: either all commit or all abort.
- **Blocking**: participants holding "prepared" state cannot release until coordinator decides. If coordinator dies, they wait. Forever, in the worst case.
- **Performance**: 2 RTTs per transaction; locks held for both rounds.
- **Failure modes**: coordinator failure leaves participants in *prepared* state; participant failure aborts the transaction.

3PC (Three-Phase Commit) adds a "pre-commit" round to avoid the blocking failure. In practice, 3PC's added complexity isn't worth it; modern systems either do 2PC carefully (with consensus-backed coordinators) or skip distributed transactions entirely.

### Where 2PC still works

Within a *single trust boundary* with a *consensus-backed coordinator*:
- Spanner uses 2PC across shards, with Paxos providing coordinator durability.
- CockroachDB uses a similar approach via its transaction coordinator.
- Distributed file systems sometimes use 2PC for metadata operations.

The key: the coordinator's state must itself be replicated and durable. With consensus, you avoid the "lost coordinator" failure mode.

Across services or organizations: don't.

### The saga pattern

A saga is a sequence of local transactions T1, T2, ..., Tn, each with a corresponding compensation C1, C2, ..., Cn-1 (no compensation needed for the final step).

Execution:
1. Run T1. If fails, abort (no compensation needed).
2. Run T2. If fails, run C1.
3. Run T3. If fails, run C2, then C1.
4. ... and so on.

Compensations run in reverse order. Each undoes the *semantic* effect of its corresponding transaction.

Example — order processing saga:

| Step | Transaction | Compensation |
|---|---|---|
| 1 | Create order (status: pending) | Mark order cancelled |
| 2 | Charge payment | Refund payment |
| 3 | Reserve inventory | Release inventory |
| 4 | Schedule shipping | Cancel shipment |
| 5 | Mark order confirmed | (none — last step) |

If step 4 fails: release inventory, refund payment, cancel order. The customer ends up with money back and no order — semantically equivalent to "didn't happen," even though the *log* shows everything that occurred.

### Orchestration vs choreography

**Orchestration:** a central orchestrator service drives the saga.

```
Orchestrator → CreateOrder → OrderService
            ← OrderCreated
Orchestrator → ChargePayment → PaymentService
            ← PaymentFailed
Orchestrator → CancelOrder → OrderService
```

Pros: explicit, easy to monitor, clear failure flow, easy to add new steps.
Cons: orchestrator is a coupling point; orchestrator failure handling itself.

Tools: Temporal, AWS Step Functions, Camunda, Cadence.

**Choreography:** services emit events; downstream services react.

```
OrderService emits OrderCreated
PaymentService consumes; emits PaymentCompleted (or PaymentFailed)
InventoryService consumes; emits InventoryReserved (or InventoryFailed)
ShippingService consumes; emits ShippingScheduled (or ShippingFailed)
```

Pros: decentralized, each service owns its part.
Cons: hard to see the big picture, ordering complexity, "where's the saga?" debugging difficulty.

Choice: orchestration for complex business flows; choreography for simpler event-driven processes. Many teams use both, in different parts of the system.

### Idempotency keys

Every saga step accepts an idempotency key — a unique ID for the operation. The receiver checks whether it's already processed this key:

```
process(operation, idempotency_key):
    if already_processed(idempotency_key):
        return cached_result(idempotency_key)
    result = do_operation(operation)
    record(idempotency_key, result)
    return result
```

This handles retries cleanly — the same idempotency key produces the same result without duplicating side effects. Stripe pioneered this pattern in its payment APIs; it's now industry standard.

The idempotency window matters: keys must be retained long enough to dedupe retries, but eventually expire to bound storage. 24 hours is a common default.

### Compensation, in detail

Compensation is *semantic* undo. Important properties:

- **Approximate, not exact.** A "refund payment" compensation undoes the *charge* but is recorded as a separate transaction. The ledger shows both.
- **May not be possible.** Some operations cannot be undone — sending an email, executing a real-world action. The saga must be designed to *avoid* unrecoverable steps until the saga is sure of success ("pivot transactions"), or the unrecoverable step is the final one.
- **May fail.** Compensation can itself fail. A robust saga retries compensation; in worst cases, alerts an operator. Compensation idempotency is required just like forward idempotency.
- **May be expensive.** Refunds may take days. Inventory release may be subject to other consumers. Compensation latency is part of the system's behavior.

### Pivot transactions

The "point of no return" in a saga. Before the pivot, all steps are reversible. After the pivot, the saga *must* succeed (steps after are retried until success).

Example: a saga that charges a customer and ships physical goods. The "ship" step is the pivot — once goods leave the warehouse, you can't unship. Design: don't ship until you're certain the rest will succeed.

This isn't always natural; the pivot must be designed in. Often pivot = "the step where compensation becomes a real-world action like a refund."

### Outbox pattern

A common saga primitive. To reliably emit an event after a database write, both must be atomic. But databases and message buses don't share transactions.

Solution: *outbox table* in the database. The transaction writes both the business state and an "event to send" row. A separate process polls the outbox, sends events, marks them sent.

```
BEGIN;
INSERT INTO orders (...) VALUES (...);
INSERT INTO outbox (event_type, payload, ...) VALUES (...);
COMMIT;

-- separate process:
SELECT * FROM outbox WHERE sent = false;
for each: publish to bus; UPDATE outbox SET sent = true;
```

This guarantees at-least-once delivery without requiring distributed transactions. Combined with idempotent consumers, it provides effective exactly-once *semantics*.

---

## Real Engineering Analogies

**The travel agent.**
Booking a multi-leg trip: flight, hotel, car rental. The travel agent doesn't expect everyone to coordinate atomically. They book each leg, knowing that if a later leg falls through, they'll call earlier providers and cancel — usually with a fee. That fee is the compensation cost.

The agent's whole job is *handling the partial-failure path*. Successful bookings are easy. The hard work is "the hotel cancelled at the last minute; what do we do?" That's exactly a saga's domain.

**The construction project.**
You don't pour the foundation atomically with the walls and the roof. Each phase commits. If the roofing contractor fails to deliver, you don't undo the foundation — you find a new roofer. Some commits are reversible (you can demolish a wall). Some are not (you can't unbuy the materials). Project management is, fundamentally, saga management: phased commits with compensation plans for the reversible parts and contingencies for the irreversible.

---

## Production Engineering Perspective

What goes wrong in distributed transactions:

- **The unmonitored saga.** Saga starts, step 3 fails silently, compensation fails too. The system is in a half-state nobody noticed. Days later, a customer calls. Discoverable only by reading saga logs. Fix: alert on every saga that fails to complete or compensate within a deadline.
- **The double charge.** Network blip during payment step. Client retries without idempotency key. Two charges. Customer support ticket. Refund issued. The cost is reputation, not just dollars.
- **The compensation that fails.** Refund step throws an exception. Saga retries; refund still fails (e.g., card was deleted). After max retries, alerts an operator. Manual intervention required. *Always design for compensation failure.*
- **The pivot that wasn't.** A saga charges first, reserves inventory second. Inventory unavailable. Need to refund. Refund takes 3 days due to bank processing. Customer is angry. Fix: reserve inventory *before* charging — make charging the pivot.
- **The ordering problem in choreography.** Service A emits event; B and C consume it; B's processing depends on C's, but events are delivered out of order. Bug surfaces only under load. Fix: explicit ordering, or orchestration, or per-key partition.
- **The 2PC that hung.** A team uses XA across two databases. Coordinator dies during a commit. One database has prepared; one has not. The prepared database holds locks. Other transactions queue. Service hangs until manual intervention.
- **The idempotency key that wasn't unique.** Same key generated for two genuinely different operations. The second is treated as a duplicate of the first. Silent data loss. Mitigation: globally unique keys, namespaced by operation type.

The senior engineer's habits:
- **Design compensations alongside transactions** — not as an afterthought.
- **Idempotency keys on every external call** that could be retried.
- **Outbox pattern** for any service that publishes events.
- **Saga timeouts** with alerting on incomplete sagas.
- **Manual compensation tools** for the inevitable cases where automated compensation fails.
- **Audit trail** of saga execution — for debugging and customer support.

---

## Failure Scenarios

**Scenario 1 — The 2PC hang at scale.**
A team uses XA transactions across two SQL databases. Under load, network blips cause coordinator timeouts. Prepared transactions accumulate. Each holds locks. Throughput plummets. Within hours, both databases are nearly unusable. Recovery: manually `ROLLBACK PREPARED` for thousands of stuck transactions. Migration to a saga-based design takes 6 months.

**Scenario 2 — The compensation cascade.**
An order saga has 7 steps. Step 6 fails. Compensations 5, 4, 3, 2, 1 must run. C5 fails. Retry; succeeds. C4 fails. Retry; succeeds. By C2, the system has spent 30 seconds compensating. The user is staring at a spinner. Lesson: design sagas for fast failure — fail early so compensation isn't long.

**Scenario 3 — The idempotency drift.**
A retry queue retries failed events. A new version of the consumer changes business logic. Replays of old events through new logic produce different results. Inconsistency surfaces in reports. Lesson: idempotency must be stable across versions, or events must be versioned.

**Scenario 4 — The choreography ordering bug.**
Three services consume an event. Two finish quickly; one is slow. The slow one's downstream effect arrives after a later event has been processed. Out-of-order causality. Discovered only because a user happens to refresh at the wrong moment. Fix: per-key serialization, or move to orchestration.

**Scenario 5 — The orchestrator outage.**
Orchestrator service goes down for 2 hours. All in-flight sagas paused. Some sagas were at step 3 of 5; their pivot transactions are committed; the world has visible intermediate state. When the orchestrator returns, sagas resume — but the customer has already been notified of "order placed" and is wondering why nothing's happened. Lesson: orchestrator durability and HA matter.

---

## Performance Perspective

- **Sagas have higher latency than 2PC** for the happy path — each step is a separate transaction, with separate latency.
- **Sagas have lower latency variance** — no waiting for slow participants in a prepare phase.
- **Compensation latency** is part of the cost model. A 5-step saga that fails at step 5 needs 4 compensations.
- **Throughput** is dominated by the slowest step in the chain. Saga step latency = pipeline latency, not parallelizable in general.
- **Outbox polling overhead** is real — high-frequency polling adds DB load. Tune carefully.

---

## Scaling Perspective

- **Vertical**: orchestrator and event bus capacity bound the saga rate.
- **Horizontal**: sagas scale by partition (per-customer, per-order). Dedicated workflow engines (Temporal, Cadence) handle horizontal scaling natively.
- **Cross-region**: sagas across regions add network latency at every step. Consider whether each step can be region-local, with the saga itself crossing regions only for the few operations that need it.
- **At very large scale**: workflow engines like Temporal handle billions of sagas with deterministic replay — the engine itself is event-sourced.

---

## Cross-Domain Connections

- **CAP**: sagas are the practical answer to "we need cross-shard semantics, but partitions exist." Eventual consistency with explicit recovery. (See [cap-consistency-and-replication.md](../distributed-systems/cap-consistency-and-replication.md).)
- **Event sourcing**: orchestrator state is naturally event-sourced; choreography uses events as the saga's coordination medium. (See [cqrs-and-event-sourcing.md](./cqrs-and-event-sourcing.md).)
- **MVCC**: snapshot isolation within an aggregate is the local-transaction semantics that each saga step depends on.
- **Backpressure**: saga retries must respect downstream backpressure; otherwise compensations storm during outages. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Cascading failures**: a saga without compensation handling cascades through dependent services on failure. Sagas with proper compensation contain the blast radius. (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)
- **Idempotency**: the saga's prerequisite. Without idempotent operations, retries create chaos.

The unifying observation: **sagas are how systems handle change across boundaries that cannot share a transaction**. The boundaries can be services, databases, organizations, or even physical processes. The same theory applies.

---

## Real Production Scenarios

- **Stripe's payment infrastructure**: extensive use of idempotency keys and what amounts to sagas for payment flows. Public engineering posts describe the patterns in detail.
- **Uber's Cadence (now Temporal)**: born from operational pain managing complex workflows at Uber's scale. Used for ride matching, dispatch, financial flows. Open-sourced; widely adopted.
- **AWS Step Functions**: the orchestration pattern as a managed service. Decoupled saga orchestration from saga steps.
- **Airbnb's payment system**: documented case of moving from synchronous distributed transactions to saga-based payment flows for reliability and clarity.
- **Booking.com's reservation system**: long-published examples of multi-provider sagas (flight + hotel + car) with compensation logic for partial bookings.
- **The XA-to-saga migration in finance**: many large financial institutions have moved from XA-coordinated cross-system transactions to saga-style flows for performance and operational reasons. Migration efforts spanning years are common.

---

## What Junior Engineers Usually Miss

- That **compensation is a separate transaction**, not a rollback.
- That **idempotency is a hard prerequisite** for every saga step.
- That **2PC blocks under coordinator failure** — not "edge case," routine.
- That **intermediate states are visible** in saga execution.
- That **compensation can itself fail** and must be designed for.
- That **the pivot transaction** is a real concept and matters.
- That **choreography looks simpler but is harder to debug** at scale.
- That **distributed transactions across organizations** are essentially impossible — you must use sagas.

---

## What Senior Engineers Instinctively Notice

- They **design compensations alongside transactions**, not after.
- They **identify pivots** in every multi-step flow.
- They **reach for idempotency keys** by reflex.
- They **prefer orchestration for complex flows**, choreography for simple ones.
- They **monitor incomplete sagas** as a primary signal.
- They **avoid 2PC across services** without exception.
- They **use the outbox pattern** for reliable event publication.
- They **recognize that "we need a transaction across these services" usually means "we need to redesign these services' boundaries."**

---

## Interview Perspective

What gets tested:

1. **"Why not 2PC?"** Senior candidates discuss blocking, coordinator failure, performance.
2. **"What's a saga?"** Tests basic literacy. Bonus for explaining compensation as semantic undo, not rollback.
3. **"Orchestration vs choreography?"** Both have merits; the candidate should articulate when each fits.
4. **"How do you handle a payment failure mid-saga?"** Tests practical thinking. Right answer: compensate prior steps; design pivot to make payment late or first.
5. **"What's an idempotency key?"** Tests retry-safety awareness. Right answer: a unique ID per operation that lets the receiver dedupe retries.
6. **"What's the outbox pattern?"** Senior candidates explain the dual-write problem and how the outbox solves it.
7. **"Design a checkout flow."** Tests applied saga design — order, payment, inventory, shipping, with compensation for each.

Common traps:
- Recommending 2PC for cross-service transactions.
- Treating saga compensation as rollback.
- Missing idempotency keys.
- Not handling compensation failures.

---

## Worked Example — Travel Booking Saga

A real-shaped saga: book flight + hotel + car rental for a trip. Each is a separate service. Each can fail. Money is involved.

### Schema

```python
@dataclass
class TravelBookingSagaState:
    booking_id: str
    customer_id: str
    flight_id: Optional[str] = None
    flight_reservation: Optional[str] = None
    hotel_reservation: Optional[str] = None
    car_reservation: Optional[str] = None
    payment_charge_id: Optional[str] = None
    status: str = "in_progress"  # in_progress, completed, compensating, failed
    completed_steps: list[str] = field(default_factory=list)
```

### Forward path

```python
async def book_travel_saga(request: TravelBookingRequest):
    state = TravelBookingSagaState(
        booking_id=str(uuid.uuid4()),
        customer_id=request.customer_id,
    )
    save_saga_state(state)  # durable

    try:
        # Step 1: Reserve flight (refundable hold)
        state.flight_reservation = await flight_service.reserve(
            flight_id=request.flight_id,
            passenger=request.passenger_info,
            idempotency_key=f"saga-{state.booking_id}-flight",
        )
        state.completed_steps.append("flight")
        save_saga_state(state)

        # Step 2: Reserve hotel (refundable hold)
        state.hotel_reservation = await hotel_service.reserve(
            hotel_id=request.hotel_id,
            dates=request.dates,
            guest=request.passenger_info,
            idempotency_key=f"saga-{state.booking_id}-hotel",
        )
        state.completed_steps.append("hotel")
        save_saga_state(state)

        # Step 3: Reserve car (refundable hold)
        state.car_reservation = await car_service.reserve(
            car_type=request.car_type,
            dates=request.dates,
            driver=request.passenger_info,
            idempotency_key=f"saga-{state.booking_id}-car",
        )
        state.completed_steps.append("car")
        save_saga_state(state)

        # Step 4: Charge payment (THE PIVOT — after this, all reservations must finalize)
        state.payment_charge_id = await payment_service.charge(
            customer=request.customer_id,
            amount=calculate_total(state),
            idempotency_key=f"saga-{state.booking_id}-payment",
        )
        state.completed_steps.append("payment")
        save_saga_state(state)

        # Step 5: Confirm all reservations (post-pivot — retry until success)
        await retry_until_success(
            lambda: flight_service.confirm(
                state.flight_reservation,
                idempotency_key=f"saga-{state.booking_id}-flight-confirm",
            )
        )
        state.completed_steps.append("flight_confirmed")
        save_saga_state(state)

        await retry_until_success(
            lambda: hotel_service.confirm(
                state.hotel_reservation,
                idempotency_key=f"saga-{state.booking_id}-hotel-confirm",
            )
        )
        state.completed_steps.append("hotel_confirmed")
        save_saga_state(state)

        await retry_until_success(
            lambda: car_service.confirm(
                state.car_reservation,
                idempotency_key=f"saga-{state.booking_id}-car-confirm",
            )
        )
        state.completed_steps.append("car_confirmed")
        save_saga_state(state)

        state.status = "completed"
        save_saga_state(state)

        return {"booking_id": state.booking_id, "status": "confirmed"}

    except Exception as e:
        state.status = "compensating"
        save_saga_state(state)
        await compensate(state)
        raise
```

### Compensation path

```python
async def compensate(state: TravelBookingSagaState):
    """Compensate in reverse order of completed steps."""
    completed = list(reversed(state.completed_steps))

    # Note: only PRE-PIVOT steps need compensation here.
    # Post-pivot (after payment), we keep retrying forward.

    for step in completed:
        try:
            if step == "payment":
                await retry_until_success(
                    lambda: payment_service.refund(
                        state.payment_charge_id,
                        idempotency_key=f"saga-{state.booking_id}-refund",
                    )
                )
            elif step == "car":
                await retry_until_success(
                    lambda: car_service.cancel_reservation(
                        state.car_reservation,
                        idempotency_key=f"saga-{state.booking_id}-car-cancel",
                    )
                )
            elif step == "hotel":
                await retry_until_success(
                    lambda: hotel_service.cancel_reservation(
                        state.hotel_reservation,
                        idempotency_key=f"saga-{state.booking_id}-hotel-cancel",
                    )
                )
            elif step == "flight":
                await retry_until_success(
                    lambda: flight_service.cancel_reservation(
                        state.flight_reservation,
                        idempotency_key=f"saga-{state.booking_id}-flight-cancel",
                    )
                )
        except UnrecoverableCompensationError:
            # Last resort: alert ops; manual handling
            alert_ops(state, step)
            state.status = "needs_manual_intervention"
            save_saga_state(state)
            raise

    state.status = "compensated"
    save_saga_state(state)
```

### Resumability

If the saga orchestrator crashes mid-flow:

```python
async def resume_pending_sagas():
    """Run on startup and periodically. Resume sagas from saved state."""
    pending = load_pending_sagas()
    for state in pending:
        if state.status == "in_progress":
            asyncio.create_task(resume_forward(state))
        elif state.status == "compensating":
            asyncio.create_task(resume_compensation(state))
```

Because state is saved after each step (and steps are idempotent), resumption is safe.

### Production-grade variants

In practice, use a workflow engine instead of hand-rolling:

- **Temporal**: takes the workflow code; handles state, retries, compensation. Battle-tested.
- **AWS Step Functions**: managed; visual workflow.
- **Cadence** (Temporal's predecessor; still used): similar.
- **Camunda**: enterprise focus.

Hand-rolling is educational; production usually warrants a framework.

---

## Recent Production References (2023-2024)

- **Stripe's payment-saga patterns**: extensive public engineering on saga-based payment flows.
- **Temporal's adoption (2023-2024)**: documented case studies at Coinbase, Snapchat, Box. Workflow engine has matured.
- **AWS Step Functions distributed-execution patterns**: documented on AWS architecture blog.
- **Uber's Cadence → Temporal migration**: documented; same pattern, evolved framework.
- **The "dual-write" antipattern**: continues to be the cautionary example for outbox pattern adoption.
- **Saga orchestration in event-driven architectures**: the prevailing pattern for cross-service workflows.

---

## Reference Architecture

```
                       ┌──────────────────────────┐
                       │    Saga Orchestrator       │
                       │   (Temporal / Step Fn)     │
                       │                            │
                       │   - Persists state         │
                       │   - Drives sequence        │
                       │   - Handles retries        │
                       │   - Triggers compensation  │
                       └─────┬────────┬─────────┬───┘
                             │        │         │
                  ┌──────────┘        │         └──────────┐
                  │                   │                     │
                  ▼                   ▼                     ▼
          ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
          │   Service A   │  │   Service B   │  │   Service C   │
          │               │  │               │  │               │
          │ Step:         │  │ Step:         │  │ Step:         │
          │   reserve()   │  │   reserve()   │  │   reserve()   │
          │   confirm()   │  │   confirm()   │  │   confirm()   │
          │   cancel()    │  │   cancel()    │  │   cancel()    │
          │               │  │               │  │               │
          │ All ops       │  │ All ops       │  │ All ops       │
          │ idempotent    │  │ idempotent    │  │ idempotent    │
          └──────────────┘  └──────────────┘  └──────────────┘
                  │                   │                     │
                  └───────┬───────────┴──────────┬──────────┘
                          │                       │
                          ▼                       ▼
                  ┌──────────────┐        ┌──────────────┐
                  │  Service A's  │        │  Service B's  │
                  │  database     │        │  database     │
                  └──────────────┘        └──────────────┘
```

Each service owns its database. Coordination is via the orchestrator's message-passing. No 2PC; no distributed locks; just idempotent operations and durable saga state.

---

## 20% Knowledge Giving 80% Understanding

1. **2PC blocks under coordinator failure.** Don't use across services.
2. **Sagas = sequence of local transactions + compensations.**
3. **Compensation is semantic undo**, not rollback.
4. **Idempotency keys are mandatory** for every step.
5. **Outbox pattern** for reliable event emission.
6. **Pivot transactions** mark the point of no return.
7. **Orchestration** for complex flows; **choreography** for simple ones.
8. **Compensation can fail** — design for that.
9. **Visible intermediate states** are inherent; UI must accommodate.
10. **Workflow engines** (Temporal, Step Functions) make sagas easier at scale.

---

## Final Mental Model

> **A distributed transaction is a comforting lie. A saga is the engineering work of telling the truth: "things happen in steps; sometimes steps fail; here's how we recover." That recovery, written as code, is the architecture.**

The senior engineer designing a system that crosses boundaries doesn't ask "how do I make this atomic?" — they ask "how do I handle each failure point?" The saga is the answer in code form. Compensation logic is engineering work, not a footnote.

ACID across a single database is a gift. ACID across services is a fantasy. The mature system accepts intermediate states, designs idempotent steps, plans compensations, and uses workflow engines or careful choreography to manage the long-running flow. The result isn't worse than ACID — it's *honest* about the realities of distribution.

That's sagas. That's how distributed transactions actually work in production. That's the pattern beneath every well-designed multi-service workflow that has ever survived its first major failure.
