# Message Queues — Point-to-Point Async Work

## A. Intuition First
A queue holds work to be done. One producer pushes, one consumer (from a pool) pulls and processes. Decouple timing and scale producers/consumers independently.

## B. Mental Model
- **FIFO by default** (within a partition / single queue).
- **Visibility timeout / ack**: consumer "leases" a message; must ack within timeout or message reappears.
- **DLQ (Dead Letter Queue)**: where repeatedly-failing messages go.

## C. Internal Working
Classic flow:
1. Producer sends message → broker writes it durably.
2. Consumer polls / subscribes → broker leases one message.
3. Consumer processes.
4. On success, ack → broker deletes.
5. On failure or timeout, message becomes visible again (retry). After N retries, move to DLQ.

## D. Visual Representation
```
Producers ─→ [QUEUE] ─→ Worker 1
                  └──→ Worker 2  (work split, each msg → one worker)
```

## E. Tradeoffs
- **At-least-once** is the common default → design consumers to be **idempotent**.
- Ordering can be lost at scale (multiple consumers pulling in parallel).
- Backpressure: queue lets you absorb bursts; if persistent, workers scale up, or you degrade the producer.

## F. Interview Lens
- "Why are queues idempotent?" — because at-least-once causes duplicates.
- "What's a DLQ?" — for poison pills.
- "How do you scale workers?" — autoscale on queue depth.
- Pitfalls: no DLQ → retries forever; ignoring ordering guarantees.

## G. Real-World Mapping
SQS, RabbitMQ, Sidekiq/Resque (Redis-based), Celery.

## H. Questions
**Beginner**: What's a queue for?
**Intermediate**: Visibility timeout?
**Advanced**:
1. Design a job queue that handles 1M jobs/hr with retries and DLQ.
2. At-least-once + idempotency — worked example.

## I. Mini Design
Photo upload → queue → worker generates thumbnails → upload to S3 → DB updated with URLs. On failure: retry 3x, DLQ, alert.

## J. Cross-Topic Connections
- [Message Brokers](message-brokers.md), [Pub-Sub](pub-sub.md), [Circuit Breaker](../reliability/circuit-breaker.md).

## K. Confidence Checklist
- [ ] Can design a queue-backed worker pool.
- [ ] Understands idempotency.

## L. Potential Gaps & Improvements
- **FIFO-strict queues (First-In-First-Out)** — guarantee messages are delivered in the exact order sent (e.g. SQS FIFO, or a Kafka single-partition topic); matters when ordering is correctness-critical, like bank transactions, but it caps throughput.
- **Priority queues** — let urgent messages jump ahead of normal ones instead of strict arrival order; useful when some work (e.g. a paid-tier request) must be served before a backlog of low-priority jobs.
- **DLQ (Dead Letter Queue)** — a side queue where messages that repeatedly fail processing are parked instead of blocking the main queue; lets you inspect and replay "poison" messages without losing them. (→ see Interview Lens)
- **Idempotent consumers** — consumers that produce the same result even if the same message is delivered twice; essential because most queues guarantee at-least-once delivery, so duplicates are normal. (→ see Interview Lens)
- **EOS (Exactly-Once Semantics)** — a stronger guarantee (e.g. Kafka transactions) that a message is processed once and only once even across retries; valuable when duplicate side-effects (double-charging) are unacceptable.
- **Backpressure** — a way for a slow consumer to signal "slow down" so producers don't overwhelm it; without it, queues grow unbounded and the system falls over.
- **CDC (Change Data Capture)** — tools like Debezium stream every row change out of a database into a queue so downstream systems stay in sync; key for any "keep two stores consistent" question.

**🔧 How to close:** Run a local broker and watch ordering/duplication firsthand: `docker run -d --name rabbit -p 5672:5672 -p 15672:15672 rabbitmq:3-management`, open http://localhost:15672 (guest/guest), create a queue, publish 5 numbered messages, then attach two consumers and observe how messages spread across them versus a single-consumer FIFO order. Kill a consumer mid-ack to see redelivery (at-least-once) in action.
