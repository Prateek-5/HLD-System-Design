# Message Queues & Pub-Sub

### 🔹 1. What This Topic Actually Is
Async messaging layers. **Queue** = 1 message → 1 consumer (work distribution). **Pub-Sub** = 1 message → N subscribers (broadcast/fan-out).

### 🔹 2. Why It Exists
- Sync HTTP couples producer + consumer: same availability, same throughput, same schedule.
- Queues/pub-sub **decouple**: buffer bursts, smooth spikes, fan out events, enable retries.
- Without them: distributed systems collapse under load spikes and cascading failures.

### 🔹 3. Core Concepts (High Signal)
- **Delivery semantics**:
  - *At-most-once* — fire and forget; may lose.
  - *At-least-once* — default; consumers must be **idempotent**.
  - *Exactly-once* — possible only with transactional brokers (Kafka EOS) + careful dedup.
- **Visibility timeout / ack** — consumer "leases" a message; must ack in time or it re-appears.
- **Ordering**: within a single partition only. Cross-partition → no guarantee.
- **Partitions**: unit of parallelism. Producers key messages → same key → same partition → ordered.
- **Consumer groups** (Kafka): group of consumers sharing work; each partition owned by one consumer in a group at a time.
- **DLQ (Dead-Letter Queue)**: poison messages land here after N retries; alert on depth.
- **Retention**:
  - Queue (SQS/Rabbit): delete on ack.
  - Kafka: append-only log, retention by time or size; replay-able.
- **Outbox pattern**: DB write + event write in same tx; relay publishes. Solves dual-write.
- **DB-as-queue anti-pattern**: row-locking contention, indexing issues, vacuum pressure. Don't do it for high throughput.

> **🧱 What a broker knows (and doesn't)**
> ✅ Message bytes, partition/offset metadata, consumer group offsets, retention policy, replication state.
> ❌ Business semantics of the message, whether a consumer "successfully" processed (just whether it acked), whether a message is "duplicate" (consumer must dedupe on its own).
>
> **🧠 What if we skip idempotency in consumers?**
> At-least-once delivery means the broker may redeliver on network hiccup / consumer crash mid-ack. If your consumer charges a credit card on each delivery, you double-charge. Idempotency isn't optional — it's the price of at-least-once.

### 🔹 4. Internal Working
**Producer → broker:** send (optionally keyed) → broker writes to a partition log (durable). Ack returned.
**Consumer:** poll broker → get batch → process → commit offset (Kafka) or ack (SQS/Rabbit).
**Kafka specifics:** each partition = ordered log. Leaders per partition replicate to followers (ISR — in-sync replicas). Consumer reads from leader at an offset.
**Failure points:** broker crash (failover via ISR), consumer crash (another in group takes over at last offset — may redeliver), poison messages (DLQ), unbounded consumer lag (scale consumers or partition more).

### 🔹 5. Key Tradeoffs
- **Kafka**: high throughput, persistent log, replay, complex ops. Winner for event pipelines.
- **RabbitMQ / ActiveMQ**: flexible routing, complex exchanges, lower throughput.
- **SQS (AWS)**: fully managed, no ops, no cross-message ordering (FIFO queue costs throughput).
- **NATS / Redis Streams**: lightweight.

Exactly-once is a myth without transactional producer + idempotent consumer + dedup store. Plan for at-least-once.

### 🔹 6. Interview Questions
> **🪜 Step-chunked Kafka end-to-end flow (with reasoning)**:
> 1. **Producer sends with a key** → reason: key hashes to a specific partition; same key → same partition → order preserved *within that key*.
> 2. **Leader of that partition writes to its log** → durable append to disk.
> 3. **Followers replicate the log** → in-sync replicas (ISR). Broker only acks once ISR write satisfies `acks=all`.
> 4. **Producer receives ack** → safe to move on.
> 5. **Consumer group assignment**: each partition is owned by exactly one consumer in a group. If 4 consumers, 4 partitions → one each. 8 partitions → two each.
> 6. **Consumer polls**, processes, commits offset → offset becomes the durable bookmark.
> 7. **Crash recovery**: a new consumer resumes from the last committed offset. If it crashed between processing and committing, that message is replayed → consumer must be idempotent.

**Beginner 🟢**
1. Queue vs pub-sub?
2. Why is idempotency required?

**Intermediate 🟡**
1. Why does ordering only hold per-partition?
2. How do DLQs work and why are they needed?

**Advanced 🔴**
1. Design a broker that absorbs 1M events/s with at-least-once + retention.
2. Explain Kafka EOS (exactly-once semantics): transactional producer + idempotent writes + read-process-write tx.
3. Transactional outbox — why, and how is it implemented?

### 🔹 7. Real System Mapping
- **Kafka**: LinkedIn (pioneer), Netflix event pipeline, Uber, Airbnb.
- **SQS**: everywhere on AWS.
- **Google Pub/Sub, AWS SNS/SQS, EventBridge**: managed pub-sub.
- **Airbnb idempotency** (payment de-dup): classic blog post.
- **Meta Async Task Computing**: their internal async processing infra.

### 🔹 8. What Most People Miss
- **Ordering is per-partition, not global.** To keep related events in order, key them by a shared id (user_id).
- **Consumer lag** is the single most important metric. High lag → backpressure → alert.
- **Poison messages** crash consumers forever without DLQ. Put a retry cap, then move.
- **Rebalance storms** in Kafka consumer groups can pause everyone on membership change; use cooperative rebalancing.
- **DB-as-queue works at small scale** but becomes the bottleneck. Graduate to Kafka/SQS before you regret it.
- **Request-response over async** is possible (correlation IDs + reply topics) but rare; usually add an HTTP layer or use temporary workflow state (Temporal).

### 🔹 9. 30-Second Revision
Queue = 1-to-1 work; pub-sub = 1-to-N. Default is at-least-once → idempotent consumers. Ordering per-partition. DLQ for poison. Outbox + CDC kills dual-write. Kafka for high-throughput persistent logs; SQS for fully-managed; Rabbit for rich routing. Don't use DB as queue at scale.

---

## 🔗 Cross-Topic Connections
- **Databases**: outbox + CDC ties DB state to events.
- **Caching**: CDC events invalidate caches.
- **Load Balancing**: queues provide async load balancing via work distribution.
- **Consensus**: Kafka uses Raft (KRaft) or ZooKeeper for metadata consensus.

---

### Confidence Check
- [ ] Can I explain at-least-once + idempotency pattern?
- [ ] Can I design a durable async worker pool with DLQ?

### Gaps
- Kafka EOS full protocol (producer epoch, transaction coordinator).
- Rabbit exchange types (topic, fanout, headers).
- Streaming window semantics in Kafka Streams / Flink.
