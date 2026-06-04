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

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔁 Gap 1 — Idempotent Consumers & Deduplication
- 🔹 **What it is**: Designing a consumer so that processing the same message twice produces the same result as processing it once — usually via a dedup key or an "already-seen" store.
- 🔹 **Why it matters**: Almost every real queue is at-least-once, so duplicates *will* happen; without idempotency you get double-charges, double-emails, and corrupted counts.
- 🔹 **Connection**: Section E says "design consumers to be **idempotent**" and the Interview Lens asks "Why are queues idempotent?" — this is the *how*, not just the *why*.
- 🔹 **When needed**: 🟢 **Foundational** — the single most-asked queue follow-up; every backend engineer should be able to do this.
- 🔹 **Intuition**: An elevator's "floor 5" button — pressing it five times still takes you to floor 5 once. The button records "5 is requested," not "add a trip."
- 🔹 **If you go deeper**: Build a dedup table keyed on a message ID (or a natural business key) with a unique constraint; read Stripe's idempotency-key API docs and how SQS FIFO uses a `MessageDeduplicationId`.
- 🔹 **Interview hook**: *"Your worker charges a card from a queue and the message is redelivered — how do you avoid a double charge?"* → store the idempotency key + result in the same DB transaction as the charge; on replay, detect the key and return the prior result.

---

#### 🥇 Gap 2 — Ordering Guarantees: FIFO vs Priority
- 🔹 **What it is**: Two ways arrival order can deviate — strict FIFO (exact send order, e.g. SQS FIFO or a single Kafka partition) and priority queues (urgent messages jump the line).
- 🔹 **Why it matters**: Ordering is a correctness property for things like "deposit before withdrawal," and priority is a fairness/SLA property for paid-tier or urgent work.
- 🔹 **Connection**: Section E warns "ordering can be lost at scale (multiple consumers pulling in parallel)" — FIFO and priority are the two knobs that fight that, each with its own throughput cost.
- 🔹 **When needed**: 🟡 **Mid-level** — comes up whenever the interviewer adds a "but the order matters" or "but premium users come first" twist.
- 🔹 **Intuition**: FIFO is a single supermarket checkout line; priority is the airport security lane where TSA-Pre passengers skip ahead of the general queue.
- 🔹 **If you go deeper**: Compare SQS FIFO message *groups* (per-group ordering, parallelism across groups) with Kafka partition keys; look at RabbitMQ priority queues and why strict global priority caps throughput.
- 🔹 **Interview hook**: *"How do you keep per-customer order while still scaling consumers?"* → partition by customer key so each key is single-threaded, but different keys run in parallel.

---

#### ☠️ Gap 3 — Dead Letter Queues & Poison-Message Handling
- 🔹 **What it is**: A side queue where messages that fail processing N times are parked instead of being retried forever or silently dropped.
- 🔹 **Why it matters**: One un-processable "poison" message can otherwise block a partition, burn retries, and page you at 3 a.m.; a DLQ turns that into an inspect-and-replay workflow.
- 🔹 **Connection**: The Mini Design (Section I) literally ends "retry 3x, DLQ, alert" — this gap is the operational discipline behind that one line.
- 🔹 **When needed**: 🟢 **Foundational** — DLQ is named in the Mental Model, Interview Lens, and Mini Design; you must be able to talk through redrive and replay.
- 🔹 **Intuition**: A post office's undeliverable-mail bin — letters with bad addresses don't clog the sorting line; they sit aside until a human reviews them.
- 🔹 **If you go deeper**: Configure an SQS redrive policy (`maxReceiveCount` → DLQ), then build a replay job that moves messages back after a fix; read how Kafka consumers implement DLQs via a separate topic since Kafka has no native one.
- 🔹 **Interview hook**: *"What happens to a message your worker can never process?"* → after `maxReceiveCount` it lands in the DLQ with alerting; you fix the bug, then redrive.

---

#### 🎯 Gap 4 — Exactly-Once Semantics (EOS) & the Transactional Outbox
- 🔹 **What it is**: A stronger guarantee that a message's effect happens once and only once, achieved not by magic delivery but by combining at-least-once delivery with idempotency or transactional writes.
- 🔹 **Why it matters**: Some side effects (charging a card, decrementing inventory) are intolerable to duplicate, and naïvely "send a message then commit to the DB" can lose or double messages on crash.
- 🔹 **Connection**: Section E calls at-least-once "the common default"; EOS is the seed bullet that asks what it costs to do better, and the outbox pattern is how you actually wire it.
- 🔹 **When needed**: 🔴 **Senior** — genuinely deep; expected in payments/streaming-infra rounds, not entry-level.
- 🔹 **Intuition**: A restaurant writes the order on the same ticket it stamps "paid" — one slip of paper, so you can't pay without an order or order without paying. The outbox is that shared ticket.
- 🔹 **If you go deeper**: Implement the transactional-outbox pattern (write the event to an `outbox` table in the same DB transaction, relay it to the broker via CDC/Debezium); read how Kafka's `enable.idempotence` + transactions provide EOS within Kafka only.
- 🔹 **Interview hook**: *"Is exactly-once delivery real?"* → exactly-once *delivery* is largely a myth; exactly-once *processing* is achievable via idempotency or transactional outbox + at-least-once delivery.

---

#### 🌊 Gap 5 — Backpressure & Queue-Depth Autoscaling
- 🔹 **What it is**: Mechanisms that stop a fast producer from drowning a slow consumer — bounded queues, consumer-driven flow control, and scaling worker count off queue depth/age.
- 🔹 **Why it matters**: Without it, a backlog grows unbounded until memory/disk fills and the whole system topples; this is the classic "what happens under a traffic spike" question.
- 🔹 **Connection**: Section E describes absorbing bursts and the Interview Lens asks "How do you scale workers? — autoscale on queue depth," which is exactly this gap.
- 🔹 **When needed**: 🟡 **Mid-level** — central to any capacity/scaling discussion once you've got the basics down.
- 🔹 **Intuition**: A bathtub with a slow drain — if water (messages) pours in faster than it drains, you either widen the drain (add workers) or close the tap (backpressure) before it overflows.
- 🔹 **If you go deeper**: Set up KEDA or an SQS-`ApproximateNumberOfMessages` CloudWatch alarm to autoscale workers; read about RabbitMQ's `basic.qos` prefetch limit and reactive-streams backpressure.
- 🔹 **Interview hook**: *"Your queue depth keeps climbing — what do you do?"* → first autoscale consumers on depth/age; if producers still outpace, apply backpressure or shed/degrade load at the producer.

---

### 🏆 Start here if you have limited time
1. **Idempotent consumers & dedup** — the #1 queue follow-up; without it your at-least-once design is wrong.
2. **Dead letter queues** — named everywhere in this file; cheap to learn, always asked.

---

### 🧭 Suggested Deep Dive Order
1. **Idempotent consumers & deduplication** (~45 min; unlocks every "duplicate message" follow-up).
2. **Dead letter queues & poison messages** (~30 min; operational must-have).
3. **Ordering: FIFO vs priority** (~1h; the "order matters" / "premium first" twist).
4. **Backpressure & queue-depth autoscaling** (~1h; the scaling/spike question).
5. **Exactly-once semantics & transactional outbox** (~2h; senior payments/streaming depth).
