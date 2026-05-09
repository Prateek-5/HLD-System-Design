# CQRS & Event Sourcing

> *"Event sourcing is what happens when you stop lying to yourself about state. State is just the latest snapshot of a story your system has been telling all along — you've just been throwing the story away after each chapter."*

---

## Topic Overview

CQRS (Command Query Responsibility Segregation) and Event Sourcing are usually mentioned together — sometimes as if they're the same thing — but they're separate ideas that compose. CQRS says: *"the model you use for writing should not be the same as the model you use for reading."* Event Sourcing says: *"don't store the current state of things; store the sequence of events that produced it, and derive state by replaying the events."*

Each is useful alone. Together, they form an architectural style that addresses some of the hardest problems in software: scaling reads independently from writes, providing audit trails by construction, supporting historical analysis trivially, and allowing the read model to evolve without re-migrating data.

The catch — and it's a serious one — is operational complexity. Event Sourcing in particular trades a familiar problem (mutable state, well-understood) for an unfamiliar one (immutable event logs, schema evolution of events, replay performance, projections that lag, read models out of sync). Most teams that adopt event sourcing because of a blog post regret it. Teams that adopt it for the *right* reasons — financial systems, audit-heavy domains, collaborative editing, business processes with complex state evolution — sometimes can't imagine going back.

This is the topic where MVCC's "log of versions" idea, distributed systems' "consistency models," and software architecture's "separation of concerns" converge. It's also the topic where "good idea badly applied" is most expensive.

---

## Intuition Before Definitions

Picture two ways to keep a bank account balance.

**Method 1 (state).** A row in a table: `balance = $1,000`. Each transaction updates the row: `balance = balance - $50`. The current balance is always readable in O(1). The history is gone.

**Method 2 (events).** An append-only log of transactions: `+$1000 (deposit)`, `-$50 (withdraw)`, `-$200 (rent)`, `+$500 (deposit)`. The balance is derived: `sum of all events`. The history is the data. The current balance is a *projection* — a function applied to the log.

Method 1 is what almost every database does by default. Method 2 is event sourcing.

If your bank used Method 1, the question "what was my balance on March 15th?" would be impossible to answer without external logs. The question "did anything happen between 11:55pm and midnight on March 15th?" would be unanswerable. The question "let's audit the last six months of transactions" would require complex change-tracking infrastructure bolted on top.

If your bank used Method 2, all of those questions become trivial: just replay the events up to the moment in question. The audit log isn't bolted on — it *is* the database.

Now layer CQRS on top: the *write side* receives commands like "Withdraw $50" and appends events to the log. The *read side* maintains a separate, fast-read-optimized view (a balance table, a transaction history, a daily statement) updated as events flow through. Two databases, two models, one source of truth.

That's the entire idea. The interesting parts are everything that happens when you actually try to ship it.

---

## Historical Evolution

**Era 1 — Banking and finance, forever.**
Double-entry bookkeeping is event sourcing in disguise. You don't erase a debit; you record a corresponding credit. The ledger *is* the audit log. This pattern is centuries old.

**Era 2 — CRUD becomes the default.**
Relational databases and OO design produced a generation of "current state in a table" applications. Easy to start, easy to query, easy to lose history. Most enterprise software still works this way.

**Era 3 — DDD and Greg Young (mid-2000s).**
Greg Young popularizes CQRS and event sourcing in the Domain-Driven Design community. The arguments: complex domains have complex state transitions; CRUD forces shoe-horning these into "update X, set Y." Events are the natural language of domain experts.

**Era 4 — Microservices and event-driven architecture.**
The pattern of services communicating via events — Kafka, EventBridge, NATS — makes "events as a first-class citizen" mainstream. Many teams now use events for inter-service communication without doing event sourcing within a service. The terminology blurs.

**Era 5 — Specialized event stores.**
EventStoreDB, Axon Server, Marten (Postgres-backed). Tools designed specifically for event-sourced systems with optimistic concurrency, projections, and replays as first-class operations. Adoption remains niche but committed.

**Era 6 — The reaction.**
A wave of "we tried event sourcing and regretted it" posts. Common themes: schema evolution is harder than expected, projections are eventually consistent in surprising ways, debugging is unfamiliar, the team didn't actually need it. The pattern matures: event sourcing becomes a tool for specific problems, not a default architecture.

The pattern: *event sourcing is finance's pattern, periodically rediscovered by software for cases where the audit log matters as much as the current state*.

---

## Core Mental Models

**1. State is a function of events.**
`state = fold(events, initial)`. Once you accept this, the question "where is the source of truth?" answers itself: the events. Everything else is derivable.

**2. Commands ≠ events.**
A command is a *request* — "Place this order." It can be rejected, validated, or transformed. An event is a *fact* — "Order placed." Events are immutable; they happened. This distinction is fundamental and often violated by teams new to the pattern.

**3. Reads and writes have different shapes.**
Writes are about *invariants*: "this order can only be cancelled if it's not yet shipped." Reads are about *projections*: "show me all of my orders this year, sorted by date." Forcing both into the same data model is what makes complex systems painful. CQRS separates them by design.

**4. Eventual consistency between command and query.**
The read side updates from events. There's a delay — usually milliseconds, sometimes seconds. After a successful command, the user might not immediately see the effect in the query side. This is a UX and engineering problem you must explicitly handle.

**5. Events are forever.**
Once written, an event is immutable. You don't update events. You don't delete events (mostly — see GDPR concerns). New requirements produce *new events*, not edits to old ones. This is a contract with the future.

---

## Deep Technical Explanation

### CQRS without event sourcing

You can have CQRS without event sourcing. Many teams do.

- **Write model**: a normalized relational database optimized for transactional integrity.
- **Read model**: a separate database (Elasticsearch, a denormalized SQL view, Redis cache, materialized views) optimized for query patterns.
- **Synchronization**: Change Data Capture (CDC) like Debezium, or application-level dual writes, or batch ETL.

Benefits without event sourcing:
- Read scaling independent of write scaling.
- Read schemas tailored to UI needs without polluting the domain model.
- Multiple read views of the same data.

Costs:
- Eventual consistency between write and read.
- Synchronization machinery to maintain.
- Two schemas to evolve.

This is where most "CQRS" systems in practice live. It's a pragmatic separation, not a metaphysical commitment.

### Event sourcing — the storage model

Each domain entity (an *aggregate* in DDD terms) has its own *stream*: an append-only sequence of events.

```
Account-12345 stream:
  Event 1: AccountOpened   { ownerName: "Alice", currency: "USD" }
  Event 2: Deposited        { amount: 1000 }
  Event 3: Withdrawn        { amount: 50 }
  Event 4: Withdrawn        { amount: 200 }
  Event 5: Deposited        { amount: 500 }
```

To get the current state of Account-12345:

```
state = { balance: 0, isOpen: false }
for event in stream:
    state = apply(state, event)
return state
```

Every command goes through:

1. Load events for the aggregate (the stream).
2. Replay to reconstruct current state.
3. Validate the command against state.
4. If valid: append new event(s).
5. If invalid: reject.

### Optimistic concurrency

When two commands arrive concurrently for the same aggregate:

1. Each loads the stream at version N.
2. Each computes new events.
3. Each tries to append: "I expect the next event to be at version N+1."
4. The first to commit succeeds. The second sees a version mismatch and must retry — reload, re-validate, re-append.

This is *optimistic concurrency*. No locks, no blocking, just a check-and-retry. Works well for low-contention aggregates. For hot aggregates (a single account with thousands of concurrent commands), it becomes a bottleneck — same problem as MVCC under write contention.

### Snapshots

Loading and replaying an entire stream on every command is expensive for long-lived aggregates. Snapshot optimization:

1. Periodically (every N events), persist the current state.
2. To load the aggregate: load the latest snapshot, replay events *after* it.

Snapshots are caches. They can be regenerated. They must be invalidated when the aggregate's logic changes (because the snapshot reflects the *old* fold function's interpretation of events).

### Projections — building the read model

A projection is a function that consumes events and produces a read model.

```python
def update_account_summary(state, event):
    if event.type == "AccountOpened":
        state[event.account_id] = {"balance": 0, "owner": event.owner}
    elif event.type == "Deposited":
        state[event.account_id]["balance"] += event.amount
    elif event.type == "Withdrawn":
        state[event.account_id]["balance"] -= event.amount
    return state
```

This projection runs on every event and updates a `account_summary` table. UI queries hit the table.

Properties:
- **Multiple projections** can consume the same events. A `daily_balance` projection, a `transaction_history` projection, a `risk_analytics` projection — all driven by the same event stream.
- **Replay**: a new projection can be built by replaying the entire event log. This is the killer feature. Want a new view? Code the projection; replay; it's now in production.
- **Eventual consistency**: projections lag the event log by some amount. UIs must accommodate this.
- **Idempotency**: projections must handle replay without corrupting state (running the same event twice should produce the same result).

### Schema evolution — the hard part

Events are immutable. But your code that interprets events is not. Common scenarios:

- **Add a new field to an existing event type.** Old events lack the field. The aggregate logic must handle "missing field" → some default.
- **Rename a field.** Old events use the old name. Either upcast at read time, or migrate (rewrite) the event log (expensive, breaks immutability principles).
- **Split one event into two.** A single `OrderUpdated` event might evolve into `OrderItemAdded` + `OrderShippingChanged`. Old events still produce the old type.
- **Change the meaning of an event.** Almost always wrong; usually requires a new event type.

The discipline: **never change the meaning of an event**. Add new event types for new behavior. Translate old events at read time when necessary. Document the event schema as a versioned, durable contract.

This is the part where teams struggle. The "events forever" property is the source of both event sourcing's power and its operational difficulty.

### GDPR and the immutable log

What about deletion? "Right to be forgotten" requires deleting personal data. But events are immutable.

Patterns:
- **Crypto-shredding**: encrypt PII in events with per-user keys. Delete the key on a delete request. The event remains, but the PII is unrecoverable.
- **Compaction with safe metadata**: replace deleted user's identifiers with anonymous tokens, retain the *shape* of the events for accounting.
- **Tombstone events**: explicit `UserAnonymized` events that projections honor.

You will have to design for this. Don't assume immutability solves regulatory needs without thought.

### CQRS + Event Sourcing — the full pattern

```
[Client]
   │
   │ Command
   ▼
[Command Handler] ── loads ──▶ [Event Store]
   │                                │
   │ append events                  │
   ▼                                │
[Event Store] ◀──── reads ──────────┘
   │
   │ stream
   ▼
[Projections] ──▶ [Read Model A] (Postgres)
   │           ──▶ [Read Model B] (Elasticsearch)
   │           ──▶ [Read Model C] (Cache)
   │
   ▼
[Other Services] (subscribe to events)

[Client]
   │ Query
   ▼
[Read Model] (fast, denormalized)
```

The system has two paths:
- **Write path**: command → handler → event store. Strongly consistent within an aggregate.
- **Read path**: query → read model. Eventually consistent with the event store.

---

## Real Engineering Analogies

**The accountant's ledger.**
A traditional ledger (event sourcing): every transaction is a new line; corrections are *new* lines (a credit to reverse a debit); the current balance is computed by summing. You can audit any moment in history. You can produce any view (annual statement, by-account, by-payee) by reading the same ledger differently. You don't *update* old lines — that would be falsifying records.

A CRUD database is the accountant who keeps a running total on a whiteboard and erases it after each transaction. Faster to read the current balance. Useless for audit. Hostile to history.

The financial industry chose ledgers because the regulatory and trust implications were obvious. Software is slowly catching up where similar properties matter.

**The version-controlled document.**
Git is event sourcing for code. Each commit is an event; the current state of the working tree is a fold. You can check out any historical version. You can branch (create a new projection of history). You can diff (compare two states). You can rewrite history (with care). And the storage cost is roughly proportional to *changes*, not snapshots.

If software state were git, you'd never lose data, you'd always know who changed what, and "show me the system as of last Tuesday" would be trivial.

---

## Production Engineering Perspective

What event-sourced systems look like at 3am:

- **The projection lag spike.** A bug in a projection's update logic causes it to throw on certain events. Projection falls behind. Reads return stale data. The fix is a code change *and* a replay — and replay can take hours.
- **The schema evolution crisis.** A new feature requires changing an event's interpretation. Old events in the log don't have the new field. The team realizes too late that they need an upcast layer, and shipping it requires testing every event ever written. Discovery happens during a release window, not the design.
- **The hot aggregate.** A single account with thousands of concurrent commands. Optimistic concurrency causes constant retries. Throughput drops to nothing. Mitigation: redesign the aggregate boundary (split by sub-account?), or accept the contention as a domain-level constraint.
- **The "what is the truth" debugging problem.** A read model shows X. The user says it should be Y. Is the projection wrong? The event store wrong? The original command wrong? The new engineer doesn't know where to start. Tooling for "show me the events that produced this state" is essential.
- **The replay-takes-forever problem.** The event log has 500M events. Rebuilding a projection from scratch takes 8 hours. The team needs incremental backfill mechanisms to evolve projections without long downtime.
- **The dual-write inconsistency** (in non-event-sourced CQRS): write to the database succeeded; write to the message bus failed. Database has the new state; downstream read models don't. The "outbox pattern" exists to solve exactly this.
- **The over-eager event design.** Early team designed events at too low a level (`FieldXChanged`, `FieldYChanged`). Now adding a feature requires understanding the entire event log to compose an aggregate's state. Domain-level events (`OrderShipped`, `RefundIssued`) age much better.

The senior engineer's habits:
- **Design events around domain language**, not technical state changes.
- **Version events from day one** — `OrderShipped.v1`, `OrderShipped.v2`. Every event includes a version.
- **Have a replay tool** before going live.
- **Monitor projection lag** as a primary metric.
- **Build the upcast layer before you need it** — not after.
- **Treat the event store as a forever-immutable contract**.

---

## Failure Scenarios

**Scenario 1 — The projection that ate the database.**
A projection emits 1 row to the read model per event. After 6 months and 100M events, the read model has 100M rows, half of which are obsolete states overridden by later events. Disk full. Realization: projections must produce *current state*, not historical state — that's what the event log is for.

**Scenario 2 — The command-query timing UI bug.**
User submits "delete this comment" command. UI redirects to "all my comments." The list shows the just-deleted comment because the projection hasn't caught up. User submits the delete again. Now there's a duplicate command (idempotent? maybe not). Pattern: explicitly handle this in UI — show optimistic state, indicate "syncing," or wait for the read model to confirm.

**Scenario 3 — The schema rename disaster.**
A field name changes in the domain. New code emits events with the new name. Reading old events fails because the parser doesn't know the old name. Production stops. Recovery: emergency upcast layer, deployed at 2am, testing on a subset of historical events. Deeper lesson: "rename" is not allowed in event schemas — it's "deprecate + introduce new event."

**Scenario 4 — The optimistic concurrency thrash.**
A "global counter" aggregate (which should never have been a single aggregate) has 10K commands per second. Optimistic concurrency causes 99% retry rate. CPU melts on retries. Recovery: accept that "global counter" is not a domain concept; redesign as "per-region counter" with eventual aggregation.

**Scenario 5 — The event explosion.**
Early decision: emit events for every "atomic" state change at the field level. Five years in, the event log has billions of events. Replays take 24 hours. Adding new projections requires planning. Refactoring towards higher-level events requires an upcast layer reading low-level events as if they were high-level. Painful migration, lasting months.

---

## Performance Perspective

- **Append-only writes are fast.** Event stores are essentially log-structured. Throughput is high.
- **Replays are linear.** O(events). Projections must be efficient, idempotent, and parallelizable when possible.
- **Snapshots cap replay cost.** O(events since snapshot).
- **Projection workers can scale horizontally** by partitioning the event log (e.g., by aggregate ID).
- **Read models are denormalized**, designed for the queries they serve. Read performance is essentially database performance for the chosen read model.
- **The dominant cost is operational complexity**, not raw performance.

---

## Scaling Perspective

- **Vertical:** event store throughput is bounded by the disk's append rate. Tens of thousands of events per second on a single node easily.
- **Horizontal:** partition the event log by aggregate ID. Each partition is an ordered log; cross-partition is unordered.
- **Multiple read models** scale reads orthogonally. Add a new one for a new query pattern; never affects writes.
- **The hard problem**: cross-aggregate consistency. Event sourcing within an aggregate is strongly consistent; *between* aggregates, you're back to distributed-systems consistency models. *Sagas* (a sequence of local transactions with compensations) are the typical pattern.
- **At very large scale**: event sourcing meets stream processing — Kafka Streams, Flink. The event store *is* the stream. Projections are stream consumers.

---

## Cross-Domain Connections

- **MVCC**: event sourcing is MVCC promoted to the application layer. Both keep history; both derive state from versions. The vacuum/compaction problem is the snapshot problem. (See [mvcc-and-isolation-levels.md](../database-internals/mvcc-and-isolation-levels.md).)
- **Distributed systems**: cross-aggregate consistency is the same as distributed consistency. Sagas, event-driven microservices, eventual consistency — all the same theory. (See [cap-consistency-and-replication.md](../distributed-systems/cap-consistency-and-replication.md).)
- **Caching**: read models are caches. Projection lag is cache staleness. Same patterns, same anti-patterns. (See [caching-hierarchy.md](../caching/caching-hierarchy.md).)
- **Backpressure**: projection workers are consumers of an event stream; they need backpressure handling like any stream consumer. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Functional programming**: `state = fold(events, initial)` is a pure function. Event sourcing is what happens when you take immutability seriously at the architecture level.
- **Filesystems**: log-structured filesystems (F2FS, ZFS) are filesystem-level event sourcing. Same insight — append is fast, in-place mutation is slow, derive current state on read.

The deep insight: **event sourcing is the architectural expression of "state is dangerous; history is data"**. The pattern recurs at every layer where mutability becomes operationally expensive.

---

## Real Production Scenarios

- **Stripe's ledger.** Stripe's internal financial ledger is event-sourced (publicly described in their engineering blog). The motivations are obvious: regulatory compliance, audit, correctness across currencies and time zones. They have an entire team building tools for projection management.
- **Walmart's order management.** Public talks describe an event-sourced approach to order state machines, with explicit events for each transition. The audit and history requirements made it obvious.
- **Eventual Consistency at Amazon.** Multiple Amazon services use event-driven architectures with read models that lag behind writes. Public design discussions describe explicit handling of "stale reads after writes" in user-facing code.
- **The CQRS-without-event-sourcing common case.** Most "CQRS" implementations in industry are actually database + Elasticsearch with a CDC pipeline. The pattern works without the full event-sourcing commitment.
- **The "we tried event sourcing" anti-pattern stories.** Multiple public postmortems describe teams that adopted event sourcing for CRUD-shaped problems and regretted it after schema evolution and operational complexity ate their velocity. The lesson is consistent: *match the pattern to the problem*.

---

## What Junior Engineers Usually Miss

- That **CQRS doesn't require event sourcing**, and event sourcing without CQRS is rarely useful.
- That **events are immutable** — never edited, never deleted (mostly).
- That **schema evolution of events** is the hardest part and the one that ages the worst if not designed up front.
- That **projections are eventually consistent** and the UI must handle this explicitly.
- That **snapshots are caches** with all the cache invalidation problems.
- That **commands and events are different things**.
- That **debugging event-sourced systems is unfamiliar** and requires tools.
- That **event sourcing for CRUD problems is over-engineering**.

---

## What Senior Engineers Instinctively Notice

- They **ask "do you actually need history as a feature?"** before recommending event sourcing.
- They **design events at the domain level**, not the technical state-change level.
- They **version events from day one**.
- They **plan for schema evolution** before the first event ships.
- They **measure projection lag** as a primary system metric.
- They **distinguish CQRS from event sourcing** clearly.
- They **prepare replay tooling** before going live.
- They **see GDPR / data deletion** as a design problem, not an afterthought.
- They **know that the dominant cost is operational, not technical**.

---

## Interview Perspective

What gets tested:

1. **"Explain CQRS."** Tests whether the candidate understands it's a separation of read and write models, *separately* from event sourcing.
2. **"Explain event sourcing."** Tests whether the candidate understands events as the source of truth and state as a derived projection.
3. **"When would you NOT use event sourcing?"** Critical question. Senior candidates volunteer that simple CRUD apps don't benefit; the operational burden isn't worth it.
4. **"How do you handle schema evolution of events?"** Tests practical experience. Junior candidates haven't thought about it; senior candidates discuss versioning, upcasting, and the discipline of additive-only changes.
5. **"How do you handle command-query latency?"** UX patterns: optimistic UI, polling for confirmation, sticky read-from-write. Tests practical knowledge.
6. **"What about GDPR?"** A trap. Senior candidates name crypto-shredding or anonymization patterns.
7. **"How do you design event boundaries?"** Aggregate-level events, domain language, business-meaningful state transitions. Bonus for naming Domain-Driven Design.

Common traps:
- Conflating CQRS and event sourcing.
- Treating events as technical state changes ("FieldXChanged").
- Not knowing that projections are eventually consistent.
- Believing event sourcing is a default architectural choice.

---

## 20% Knowledge Giving 80% Understanding

1. **CQRS = separate read and write models.** Optional event sourcing.
2. **Event Sourcing = state is a fold over events.** Events are the source of truth.
3. **Events are immutable, forever.** Schema evolution is additive.
4. **Projections are eventually consistent.** UI must handle this.
5. **Snapshots cache the fold.** Same cache invalidation rules.
6. **Optimistic concurrency** for write conflicts; hot aggregates suffer.
7. **Cross-aggregate consistency is distributed consistency.** Sagas are the pattern.
8. **Event design at domain level**, not field-change level.
9. **Replay is the superpower.** Build new read models without re-migration.
10. **Use it when history is a feature.** Audit, finance, collaboration. Skip otherwise.

---

## Final Mental Model

> **Event sourcing is what you do when you take seriously that state is a story, not a snapshot. The story is the data. The snapshot is a convenience.**

A senior architect, looking at a problem, asks: *do we need to know how we got here, or only where we are?* For most CRUD applications, "where we are" is enough — and event sourcing's operational cost isn't worth it. For financial systems, audit-heavy domains, complex business workflows, collaborative editing, and any system where regulatory or trust requirements demand history — *the snapshot is the lie, and the story is the truth*.

CQRS is the lighter, more broadly useful pattern. Most teams should reach for it before they reach for event sourcing. The separation of read and write models is a generally good idea; making the events themselves the source of truth is a specific architectural commitment with specific costs.

The promise of event sourcing is reverse engineering the present from the past, perpetually. The cost is operational complexity that pays off only when the past is genuinely valuable. Engineering judgment is in distinguishing the two — *before* the system is built, not after.

That's CQRS. That's event sourcing. That's what happens when MVCC's idea — keep history, derive state — is promoted from a database trick to an architectural style.
