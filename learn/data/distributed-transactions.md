# Distributed Transactions — ACID Across Boundaries

## A. Intuition First
Transactions across multiple DBs or services need coordination. Two-phase commit is the textbook answer; sagas are the real-world answer.

## B. Mental Model
Goal: **atomicity** across participants — either all commit or all roll back.

Approaches:
- **2PC (Two-Phase Commit)** — synchronous, with a coordinator.
- **3PC (Three-Phase Commit)** — 2PC + extra ack phase; solves some blocking but rarely used.
- **Sagas** — break the transaction into a sequence of local transactions, with compensating actions.

## C. Internal Working

### 2PC
Phase 1 (Prepare): coordinator asks each participant "can you commit?" Each prepares (writes to durable log), answers yes/no.
Phase 2 (Commit): if all said yes → commit to all. If any said no → abort all.

Failure modes:
- Coordinator crashes between phase 1 and 2 → participants in "prepared" state hold locks indefinitely ("blocked"). Manual intervention.
- Participant crashes → retry / timeout.

### 3PC
Splits phase 2 into "pre-commit" and "commit" — participants can timeout and make progress. Assumes no network partitions (academically). Rarely used in practice.

### Sagas
Each local transaction publishes an event triggering the next. If a step fails, run compensating transactions to undo earlier steps.

Two flavors:
- **Choreography**: each service listens for events, decides next step. Decentralized.
- **Orchestration**: a central orchestrator calls each step. Easier to debug.

## D. Visual Representation
```
2PC:       Coord ──prepare──▶ [P1, P2, P3]  (all say yes)
           Coord ──commit ──▶ [P1, P2, P3]  (all commit)
                                      
Saga:      T1 → event → T2 → event → T3 → (fail!) → T2-comp → T1-comp
```

## E. Tradeoffs
- **2PC**: atomic, but blocking + latency + coordinator SPOF.
- **Sagas**: asynchronous, no distributed locks; but **no isolation** (other transactions see intermediate states), and compensation logic is hard (refunds, reversals).
- For microservices, sagas dominate.

## F. Interview Lens
- "How do you ensure atomicity across two services?" — 2PC (rarely in microservices), saga (commonly).
- "Why is 2PC blocking?" — coordinator fault leaves participants waiting.
- "Design a payment + inventory + shipping flow with sagas."
- Pitfalls: trying to add distributed ACID where eventual consistency would suffice.

## G. Real-World Mapping
- **Payment flows** at Stripe, Uber: sagas (via Kafka / Temporal / AWS Step Functions).
- **Spanner / CockroachDB**: use Paxos-based distributed ACID transactions internally.
- **XA transactions** (2PC in JEE): legacy; ops nightmare.

## H. Questions
**Beginner**: Why are distributed transactions harder than single-DB?
**Intermediate**: Explain 2PC. Why does it block?
**Advanced**:
1. Design a saga for book-a-trip (flight + hotel + car). What are compensations?
2. When would you pick 2PC over sagas?

## I. Mini Design — "Book-a-trip saga"
Steps: reserve flight → reserve hotel → charge card.
Compensations: cancel hotel → cancel flight → (no card charge to undo).
Orchestrator: Temporal/Step Functions workflow; stores state durably; retries each step; on failure invokes compensation chain.

## J. Cross-Topic Connections
- [Transactions](transactions.md), [Message Queues](../architecture/message-queues.md), [Event-Driven Architecture](../architecture/event-driven-architecture.md).

## K. Confidence Checklist
- [ ] Can explain 2PC including failure modes.
- [ ] Can draft a saga with compensations.

### Red flags
- ❌ Proposing 2PC for modern microservice systems without good reason.

## L. Potential Gaps & Improvements
- **Paxos / Raft** — consensus protocols that get many nodes to agree on one value despite failures; they underpin distributed **ACID (Atomicity, Consistency, Isolation, Durability)** in Spanner and CockroachDB, so learn them to explain how those DBs stay consistent.
- **Idempotency** — designing a saga step so retrying it produces the same result, never a double charge; essential because networks retry and you must avoid duplicate side effects.
- **Outbox pattern** — write the event to an "outbox" table in the same DB transaction as the business data, then publish it later, so you never lose or duplicate events when crossing the DB/message-broker boundary.
- **TCC (Try-Confirm-Cancel)** — a saga variant that first reserves resources ("Try"), then either "Confirms" or "Cancels"; useful when you need a tentative hold (e.g. seat reservation) before committing.

**🔧 How to close:** Spin up the classic book-a-trip saga locally: run `docker compose up` with three tiny HTTP services (flight, hotel, payment) plus an orchestrator; deliberately make the payment service return HTTP 500 and watch the orchestrator fire the compensation chain (cancel hotel, cancel flight). Then add an idempotency key to each step and re-send a duplicate request to confirm no double-booking occurs.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔁 Gap 1 — Idempotency Keys for Saga Steps
- 🔹 **What it is**: Tagging each operation with a unique key so that retrying it produces the same result instead of running it twice (e.g. charging a card only once).
- 🔹 **Why it matters**: Networks drop responses and clients retry; without idempotency a single "charge card" step can double-bill a customer. This is the single most common follow-up after you mention sagas.
- 🔹 **Connection**: The file's saga relies on retrying each step; this section's failure modes (participant crash → retry) assume the retry is safe. Idempotency is what *makes* retry safe.
- 🔹 **When needed**: 🟢 **Foundational** — every payment/order system needs this, and it's expected even in mid-level interviews.
- 🔹 **Intuition**: A coat-check ticket. You hand over your coat once and get ticket #42; showing #42 ten more times never gives you ten coats — the ticket maps to exactly one coat.
- 🔹 **If you go deeper**: Read Stripe's "Designing robust and predictable APIs with idempotency" engineering post; implement an idempotency table keyed on `(key, request_hash)` that stores the first response and replays it on retries.
- 🔹 **Interview hook**: *"A client retries a payment request after a timeout — how do you avoid a double charge?"* → Client sends an idempotency key; server stores key → result on first success and returns the stored result for any retry instead of re-executing.

---

#### 📤 Gap 2 — Outbox Pattern (Atomic DB + Event Publish)
- 🔹 **What it is**: Writing the outgoing event into an "outbox" table inside the *same* local DB transaction as the business change, then a separate relayer reads that table and publishes to the broker.
- 🔹 **Why it matters**: It solves the dual-write problem — you can't atomically write to your DB *and* publish to Kafka, so naive code loses events on a crash between the two. Choreographed sagas live or die on this.
- 🔹 **Connection**: This file's choreography flavor has "each local transaction publishes an event triggering the next." The outbox is *how* you make that publish reliable instead of best-effort.
- 🔹 **When needed**: 🟡 **Mid-level** — essential once you build event-driven sagas for real, but you can describe sagas conceptually without it.
- 🔹 **Intuition**: A hotel front desk that writes your checkout *and* drops the room-cleaning slip into one outbox tray in a single motion. A runner later collects the tray; even if the runner is late, the slip is never lost.
- 🔹 **If you go deeper**: Read Chris Richardson's microservices.io "Transactional Outbox" pattern; pair it with Debezium CDC (Change Data Capture) to tail the outbox table straight into Kafka without a polling relayer.
- 🔹 **Interview hook**: *"How do you guarantee the event is published if and only if the DB commit succeeds?"* → Insert the event into an outbox table in the same transaction; a relayer (poller or CDC) publishes it afterward, giving at-least-once delivery.

---

#### 🎯 Gap 3 — TCC (Try-Confirm-Cancel)
- 🔹 **What it is**: A saga variant where each step first *reserves* resources ("Try"), and a later phase either *Confirms* (finalize) or *Cancels* (release the reservation).
- 🔹 **Why it matters**: It gives you a tentative hold — a seat, inventory, or credit reservation — so you avoid overselling without holding a distributed lock the way 2PC does.
- 🔹 **Connection**: It sits between this file's two poles: more structured than a free-form saga, but reservation-based rather than the lock-and-block of 2PC. Compensations become explicit Cancel methods instead of ad-hoc reversals.
- 🔹 **When needed**: 🟡 **Mid-level** — useful when you need provisional holds; common in booking/payment design rounds.
- 🔹 **Intuition**: Booking a flight seat. The site holds your seat for 10 minutes (Try), you pay to Confirm, or the hold expires and Cancels — the seat is never sold twice and never locked forever.
- 🔹 **If you go deeper**: Study Seata's TCC mode and Apache ServiceComb Saga/TCC; note how Confirm and Cancel must themselves be idempotent (ties back to Gap 1).
- 🔹 **Interview hook**: *"How is TCC different from a compensating saga?"* → TCC reserves up front (Try) then Confirms/Cancels, so resources are held tentatively; a plain saga commits each step fully and undoes with compensation only on failure.

---

#### 🗳️ Gap 4 — Consensus (Paxos / Raft) Behind Distributed ACID
- 🔹 **What it is**: Protocols that get a group of nodes to agree on a single value despite crashes and message loss — the replication backbone under databases that offer real distributed transactions.
- 🔹 **Why it matters**: It explains *how* Spanner and CockroachDB give you ACID across machines while the rest of us reach for sagas. Interviewers use it to separate "knows sagas" from "understands why distributed ACID is hard."
- 🔹 **Connection**: Section G says Spanner/CockroachDB "use Paxos-based distributed ACID transactions internally." This gap unpacks that one line — consensus replicates each shard, and a coordinator runs 2PC *across* the consensus groups.
- 🔹 **When needed**: 🔴 **Senior** — genuinely deep infra; signaling for senior/architect rounds, not day-one knowledge.
- 🔹 **Intuition**: A jury that must reach a unanimous-enough verdict (a majority quorum). Even if a few jurors step out, the remaining majority can still decide, and everyone records the same verdict.
- 🔹 **If you go deeper**: Read the Raft paper ("In Search of an Understandable Consensus Algorithm", Ongaro & Ousterhout) and the Google Spanner paper (TrueTime + Paxos groups + 2PC). Build a toy Raft with the visualizer at thesecretlivesofdata.com/raft.
- 🔹 **Interview hook**: *"How can Spanner offer global ACID transactions when 2PC is supposedly impractical?"* → Each data shard is a Paxos group (fault-tolerant), 2PC runs across the leaders, and TrueTime bounds clock uncertainty to order transactions globally.

---

#### 👻 Gap 5 — The Isolation Gap in Sagas
- 🔹 **What it is**: Sagas drop the "I" in ACID — between steps, partially-completed work is visible to other transactions, causing dirty reads, lost updates, and "fuzzy" anomalies.
- 🔹 **Why it matters**: It's the hidden cost the file names ("sagas: no isolation") but rarely the part people can *mitigate*. Knowing the countermeasures is what makes a saga answer production-grade.
- 🔹 **Connection**: Section E explicitly lists "no isolation (other transactions see intermediate states)" as the saga tradeoff. This gap turns that warning into concrete tactics.
- 🔹 **When needed**: 🟡 **Mid-level** — the moment you build a real saga you hit this; great differentiator in design rounds.
- 🔹 **Intuition**: Renovating one room of a hotel while guests still tour the building. Until you cordon it off (semantic lock) or hang a "work in progress" sign (status flag), visitors see a half-finished room.
- 🔹 **If you go deeper**: Read the original "Sagas" paper (Garcia-Molina & Salem, 1987) and Chris Richardson's countermeasures: semantic locks, commutative updates, pessimistic view ordering, and re-reads.
- 🔹 **Interview hook**: *"A user sees an order as 'confirmed' before payment clears in your saga — how do you handle it?"* → Use a semantic lock: mark the record `PENDING` so readers know it's tentative, and only flip to `CONFIRMED` after the final step (or compensate the status on failure).

---

### 🏆 Start here if you have limited time
1. **Idempotency keys** — the universal follow-up to any saga answer; cheap to learn, immediately useful, and prevents double charges.
2. **The isolation gap in sagas** — turns the file's "no isolation" warning into something you can actually mitigate, which most candidates can't.

---

### 🧭 Suggested Deep Dive Order
1. **Idempotency keys** (~45 min; foundational, unlocks safe retries everywhere).
2. **Isolation gap + countermeasures** (~1h; makes your saga answers production-grade).
3. **Outbox pattern** (~1h; the reliability glue for choreographed sagas).
4. **TCC (Try-Confirm-Cancel)** (~1h; the right tool for reservation/booking flows).
5. **Consensus (Paxos/Raft)** (~3–4h; senior-infra depth — explains how real distributed ACID works).
