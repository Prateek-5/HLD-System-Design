# Event Sourcing — State as a Log of Events

## A. Intuition First
Instead of storing the *current* state of an entity (a bank account balance = $100), store the **sequence of events** that produced it (deposited $200, withdrew $100). Current state = a fold over the events.

## B. Mental Model
- **Append-only event log** is the source of truth.
- Current state is a **projection** (derived).
- Nothing is ever deleted — corrections are new events.

## C. Internal Working
- Writes: append event to log (`money.deposited: $200`).
- Reads: replay events to reconstruct state (or maintain a materialized view that updates on each event).
- Snapshots periodically so replay is bounded.

## D. Visual Representation
```
Events (append-only):
  AccountCreated   → AccountId=123
  MoneyDeposited   → 100
  MoneyDeposited   → 200
  MoneyWithdrawn   → 50
Current state: balance=250  (reduce over events)
```

## E. Tradeoffs
**Pros**: full audit trail, temporal queries ("what was state last Tuesday?"), natural fit with EDA.
**Cons**: complexity (schema evolution for events is real), storage grows, snapshot cadence must be tuned, debugging is different.

## F. Interview Lens
- "When event sourcing?" — financial systems, audit-heavy, complex state evolution (e.g., insurance claims).
- "Schema evolution?" — upcast old events to new shapes on read.
- Pitfalls: naive event sourcing without snapshots → slow cold reads.

## G. Real-World Mapping
Trading systems, event-driven payment ledgers, Uber's dispatching, ES frameworks (EventStore, Axon).

## H. Questions
**Beginner**: Store state vs store events?
**Intermediate**: Why snapshots?
**Advanced**: Design event-sourced ledger for a fintech app. How do reversals/corrections work?

## I. Mini Design
Bank account: events = Deposited, Withdrawn, FeeCharged. Snapshot every 100 events. Balance query: replay from last snapshot. Reversal: new "Reversed X" event.

## J. Cross-Topic Connections
- [CQRS](cqrs.md) — natural pairing.
- [EDA](event-driven-architecture.md), [Pub-Sub](pub-sub.md).

## K. Confidence Checklist
- [ ] Can explain events vs state.
- [ ] Knows snapshots.
- [ ] Knows it's not one-size-fits-all.

## L. Potential Gaps & Improvements
- **Event schema evolution** — strategies (upcasting, versioned event types, weak schemas) for safely changing an event's shape over time without breaking old stored events; critical because events live forever.
- **Upcasting** — transforming an old event into the new schema as it is read back, so consumers only ever see the latest shape; lets you evolve without rewriting history.
- **Replay at scale** — re-deriving projections by reading the whole log; needs tooling and tests because replaying millions of events must be fast, idempotent, and deterministic.
- **Idempotent projections** — building read models so applying the same event twice has no extra effect; matters because replays and at-least-once delivery will re-deliver events.
- **GDPR (General Data Protection Regulation) right-to-be-forgotten** — deleting a user's personal data is hard on an append-only log; learn crypto-shredding (store data encrypted, throw away the key) so you can "forget" without rewriting history.
- **Snapshotting cadence** — how often to save a precomputed state so replay starts from a checkpoint instead of event zero; tune it to bound cold-read latency (→ see Interview Lens).
- **CDC (Change Data Capture)** — tools like Debezium stream every database change as events, a common way to bootstrap an event log from an existing state-based system.

**🔧 How to close:** Build a tiny event-sourced bank account in any language: define `Deposited`/`Withdrawn` events, append them to an in-memory list, and write a `replay(events)` function that folds them into a balance. Then add a `snapshot` after every 5 events and prove that replaying from the snapshot yields the same balance as replaying from zero — `assert replay(all) == snapshot.balance + replay(events_after_snapshot)`.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🧬 Gap 1 — Event Schema Evolution & Upcasting
- 🔹 **What it is**: Strategies (versioned event types, weak schemas, and **upcasting** — transforming an old event into the new shape as it's read) for changing an event's structure without breaking the events already stored.
- 🔹 **Why it matters**: In a state-based system you migrate a table once; in event sourcing the log is the source of truth and *every old event lives forever*, so v1 events written years ago must still deserialize into today's code.
- 🔹 **Connection**: This file's Cons call schema evolution "real," and Interview Lens says "upcast old events to new shapes on read." This is the mechanism behind that one-liner.
- 🔹 **When needed**: 🟡 **Mid-level** — any real event-sourced system hits this on its first feature change; common in EDA design rounds.
- 🔹 **Intuition**: Old letters written in cursive your grandparent's handwriting. You don't rewrite the letters — you keep a translator who reads the old script and hands you a clean typed copy every time.
- 🔹 **If you go deeper**: Read Greg Young's "Versioning in an Event Sourced System" (free PDF); study how Axon Framework and EventStoreDB implement upcaster chains.
- 🔹 **Interview hook**: *"You need to add a `currency` field to a `MoneyDeposited` event that has 10M stored instances — how?"* → don't migrate; register an upcaster that injects a default currency when old-version events are read, and start writing v2 going forward.

---

#### ♻️ Gap 2 — Idempotent Projections & Deterministic Replay
- 🔹 **What it is**: Building read models so that applying the same event twice produces no extra effect, and re-deriving a projection by reading the whole log yields the exact same result every time.
- 🔹 **Why it matters**: Replays (after a bug or schema change) and at-least-once delivery both re-deliver events; if a projection double-counts a deposit on the second delivery, your read model silently drifts from the log.
- 🔹 **Connection**: This file says reads can "maintain a materialized view that updates on each event" and mentions replaying the log — this gap is what keeps those views correct when events arrive more than once.
- 🔹 **When needed**: 🟢 **Foundational** — the moment you maintain any materialized view from a log, idempotency is unavoidable; reachable as soon as you've built the mini bank account.
- 🔹 **Intuition**: A hotel front desk that records "room 204 occupied" rather than "+1 guest." If the same check-in message arrives twice, the room is still just occupied — no drift.
- 🔹 **If you go deeper**: Implement a `processed_event_ids` dedupe table or use the event's monotonic sequence number as a high-water mark; study how Kafka Streams uses offsets for exactly-once-ish projection state.
- 🔹 **Interview hook**: *"At-least-once delivery re-sends an event — how do you stop your read model double-counting?"* → make handlers idempotent: dedupe by event ID, or write set-state ("balance = X") instead of delta ("balance += X").

---

#### 🗑️ Gap 3 — GDPR Right-to-Be-Forgotten via Crypto-Shredding
- 🔹 **What it is**: Deleting a user's personal data on an append-only log is hard because you never mutate or delete events; **crypto-shredding** stores personal fields encrypted with a per-user key and "forgets" the data by throwing away that key.
- 🔹 **Why it matters**: GDPR (General Data Protection Regulation) and similar laws grant a right to erasure, which directly contradicts "nothing is ever deleted" — crypto-shredding reconciles legal deletion with an immutable history.
- 🔹 **Connection**: This file's Mental Model insists "nothing is ever deleted — corrections are new events." This gap is the honest answer to the obvious follow-up: *what about data you're legally required to destroy?*
- 🔹 **When needed**: 🔴 **Senior** — surfaces in compliance-heavy fintech/health design rounds and real production architecture, not in basics.
- 🔹 **Intuition**: A locked diary written in a private cipher. To "erase" it you don't burn the diary — you destroy the single key, and every page becomes permanent gibberish.
- 🔹 **If you go deeper**: Read Michiel Rook's "Forgettable payload with crypto-shredding"; look at how a per-subject key vault (one AES key per user) maps to event encryption.
- 🔹 **Interview hook**: *"How do you honor a GDPR delete request on an immutable event log?"* → crypto-shredding: encrypt personal data per-user, delete the key so the ciphertext in history is unrecoverable, no log rewrite needed.

---

#### 🔌 Gap 4 — Bootstrapping an Event Log with CDC
- 🔹 **What it is**: CDC (Change Data Capture) tools like Debezium read a database's transaction log and stream every insert/update/delete as an event — a common way to grow an event log out of an existing state-based system.
- 🔹 **Why it matters**: Most teams don't start greenfield; they have a legacy CRUD database and want event-sourcing benefits (audit trail, projections, EDA) without rewriting the app first. CDC turns the existing DB into an event source.
- 🔹 **Connection**: This file's Real-World Mapping lists event-driven ledgers and EDA; CDC is the bridge that lets a state-based system feed those event-driven consumers.
- 🔹 **When needed**: 🟡 **Mid-level** — frequent in "how do we migrate to events / keep two stores in sync" interview and migration scenarios.
- 🔹 **Intuition**: A security camera pointed at a cash register's receipt printer — you didn't change how the register works, but now every transaction is also a streamed event someone else can react to.
- 🔹 **If you go deeper**: Run Postgres + Debezium + Kafka in docker compose, do an `UPDATE`, and watch the change event land on a topic; read Debezium's "outbox pattern" docs to avoid dual-write inconsistency.
- 🔹 **Interview hook**: *"We have a legacy SQL app and want an event stream without rewriting it — how?"* → CDC (e.g., Debezium) tails the DB transaction log and emits row changes as events; pair with the outbox pattern for clean domain events.

---

### 🏆 Start here if you have limited time
1. **Idempotent projections & replay** — 🟢 foundational; the instant you build a materialized view this bites you, and it cements how the log relates to read models.
2. **Event schema evolution & upcasting** — every real event-sourced system needs it on its first feature change, and it's the most common ES interview follow-up.

---

### 🧭 Suggested Deep Dive Order
1. **Idempotent projections & deterministic replay** (~45 min; foundational, unlocks safe replays).
2. **Event schema evolution & upcasting** (~1h; high interview payoff, every system needs it).
3. **Bootstrapping with CDC** (~1h incl. a docker compose demo; migration-scenario payoff).
4. **GDPR crypto-shredding** (~45 min reading; senior compliance signaling).
