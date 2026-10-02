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
- FIFO-strict queues (SQS FIFO, Kafka single-partition).
- Priority queues.
