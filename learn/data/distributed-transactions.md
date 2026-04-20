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
- Paxos / Raft as backing consensus for distributed ACID (Spanner, CockroachDB).
- Idempotency + outbox pattern for saga steps.
- Try-Cancel-Confirm (TCC) pattern.
