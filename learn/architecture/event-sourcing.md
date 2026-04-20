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
- Event schema evolution strategies.
- Replay at scale — tooling, tests.
- GDPR + event sourcing (right to be forgotten is tricky on append-only).
