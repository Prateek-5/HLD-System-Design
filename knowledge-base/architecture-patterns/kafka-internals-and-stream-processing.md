# Kafka Internals & Stream Processing

> *"Kafka is a distributed log dressed up as a message broker. The 'log' is the central abstraction: append-only, partitioned, replicated, retained for arbitrary duration. Once you see Kafka as 'a database that you query by reading forward in time,' the design choices that confuse first-time users — offsets, partitions, retention, consumer groups — become obvious. Kafka is the substrate of nearly every modern event-driven architecture."*

---

## Topic Overview

Apache Kafka is the dominant open-source streaming platform. It's used as a message broker, an event store, a CDC pipeline, an audit log, a buffer between services. The design — partitioned, replicated, append-only logs — has shaped the industry's thinking about events.

Internals: **topics** divided into **partitions**; partitions replicated across **brokers**; producers write to partitions; consumers read at their own pace; offsets track position. Replication via in-sync replicas (ISR); consensus for metadata via Raft (KRaft) or ZooKeeper (legacy).

Stream processing extends Kafka: Kafka Streams (library), Apache Flink, ksqlDB. Built on the log; treat events as a continuous flow; transform, aggregate, join in real time.

This is the topic where event-driven architecture meets the storage primitive that enables it. Understanding Kafka — partitioning, replication, consumer offsets, stream processing — is what makes "event-driven" a viable architecture rather than a design pattern in slides.

---

## Intuition Before Definitions

Imagine a newspaper that publishes continuously. Every story is appended to a single issue (the topic). The issue has multiple sections (partitions), each in its own queue.

Subscribers (consumers) read at their own pace. Some read every story (sequential). Some skip ahead. Each subscriber tracks where they are.

The newspaper keeps every story for a configurable duration (retention). Want last week's news? Still there. Want yesterday's? Re-read it. The "newspaper" is an immutable log.

Multiple subscribers can read the same story. Each at their own pace. The newspaper doesn't know or care.

Now imagine the newspaper has multiple printing presses (brokers). Each press handles some sections. If a press fails, another has a copy (replication).

That's Kafka. Topics, partitions, brokers, consumer offsets — the newspaper analogy. The genius: the newspaper isn't deleted after consumption; it's a permanent log everyone can read.

---

## Historical Evolution

**Era 1 — LinkedIn's pain.**
~2010. LinkedIn needed to move data between systems reliably. Existing solutions (queues, databases) didn't fit.

**Era 2 — Kafka's birth.**
2011. Kreps, Narkhede, Rao open-source Kafka. Designed around the log abstraction.

**Era 3 — Adoption.**
~2014. Confluent founded. Kafka adopted at LinkedIn, Netflix, Twitter, Uber, etc.

**Era 4 — Kafka Streams (2016).**
Stream processing library on Kafka. State stores. Joins. Windowing.

**Era 5 — KRaft (2021).**
Replace ZooKeeper dependency with internal Raft. Operational simplification.

**Era 6 — Mature platform.**
2024+. Industry-standard substrate for event-driven architecture. Kafka Connect; Schema Registry; ksqlDB; thriving ecosystem.

The pattern: Kafka won by treating "the log" as a first-class primitive and building everything around it.

---

## Core Mental Models

**1. The log is the primary abstraction.**
Topics are logs; partitions are independent logs; everything else is bookkeeping.

**2. Partitions enable parallelism.**
A topic with 100 partitions can be consumed by up to 100 parallel consumers per consumer group.

**3. Consumers track their own offsets.**
Consumers commit offsets back to Kafka. Each consumer group has its own offset per partition.

**4. Replication for durability.**
Each partition has N replicas; one leader, N-1 followers. Writes go to leader; replicate to followers.

**5. Retention is time- or size-based.**
Old data is deleted. The log isn't infinite; it's configurable.

---

## Deep Technical Explanation

### Topics, partitions, brokers

A **topic** is a logical category of events. "user-events", "order-events".

A topic has **partitions**. Each partition is an ordered, immutable log. Order is per-partition; not across partitions.

**Brokers** are servers in a cluster. Each partition lives on multiple brokers (one leader, N-1 followers).

### Producers

Send records to topics. Per record:
- **Key** (optional): used to partition.
- **Value**: the payload.
- **Timestamp**.
- **Headers**: metadata.

Partitioning:
- If key: `hash(key) % num_partitions`. Same key → same partition.
- If no key: round-robin or sticky.

Acks:
- `acks=0`: fire and forget.
- `acks=1`: leader ack.
- `acks=all` (or `-1`): all in-sync replicas ack.

Idempotent producer: each producer assigned an ID; sequence numbers per partition; broker dedupes retries.

### Consumers

Read records from partitions. Per consumer:
- **Subscribe** to topics.
- **Poll** for records.
- **Commit** offsets.

Consumer groups:
- Multiple consumers in a group share work.
- Each partition is consumed by exactly one consumer in the group.
- Adding consumers up to partition count = parallelism.

Consumer offsets are stored in the `__consumer_offsets` topic (also a log).

### Replication

Each partition has a leader and followers. Followers fetch from leader; apply.

In-Sync Replica (ISR): followers caught up "close enough" to leader. Configurable.

Failover: if leader dies, an ISR is elected new leader. Out-of-sync replicas can't be elected (would lose data).

`unclean.leader.election` controls whether non-ISR can be elected (false = data safety; true = availability).

### Storage

Each partition is a series of segment files on disk. Append-only:
- Producer writes: append to active segment.
- Segment fills (size or time): close; new active segment.
- Old segments deleted per retention.

Reads: sequential disk I/O; very fast (zero-copy via `sendfile`).

Compression: producer compresses batches; broker stores compressed.

### Throughput

Kafka is designed for high throughput:
- Sequential disk writes (very fast on HDD/SSD).
- Zero-copy reads.
- Batching at producer and broker.
- No random I/O.

Single broker: hundreds of MB/s sustainable.

Cluster: multi-GB/s aggregate.

### Retention

`log.retention.hours`: keep messages for N hours.
`log.retention.bytes`: keep up to N bytes per partition.
`log.cleanup.policy=compact`: keep latest message per key (used for state storage).

Compaction is its own beast. Used for "current state" topics (e.g., user profile).

### Consumer offsets and rebalancing

Consumer commits offsets after processing. On crash, restart resumes from last committed.

Consumer group rebalance:
- Triggered by: new consumer, consumer leave, partition count change.
- Stop processing; partitions reassigned; resume.
- During rebalance: throughput halt.

Modern Kafka has cooperative rebalancing: incremental, doesn't stop everything.

### Exactly-once semantics (EOS)

Kafka 0.11+ supports EOS within Kafka:
1. Idempotent producer: dedupes retries.
2. Transactional producer: atomic writes to multiple partitions.
3. Read-committed consumer: skips uncommitted.
4. Transactional consume-process-produce: read offset + writes in one transaction.

Limitations: within Kafka. External systems still need idempotent receivers. (See [idempotency-receivers-and-exactly-once-semantics.md](./idempotency-receivers-and-exactly-once-semantics.md).)

### KRaft (replacing ZooKeeper)

Pre-3.0: Kafka used ZooKeeper for cluster metadata.

3.0+: KRaft mode uses internal Raft. Eliminates ZooKeeper dependency. Operational simplification.

Production deployments are migrating; new clusters default to KRaft.

### Stream processing

**Kafka Streams**: library. Embedded in apps; stateful transformations.

```java
KStream<String, Order> orders = builder.stream("orders");
KStream<String, Aggregated> totals = orders
    .groupByKey()
    .windowedBy(TimeWindows.of(Duration.ofMinutes(5)))
    .aggregate(...)
    .toStream();
totals.to("aggregated-totals");
```

**ksqlDB**: SQL on streams. Runs on Kafka Streams underneath.

**Apache Flink**: dedicated stream processing engine. Often outperforms Kafka Streams for complex jobs.

Common patterns: filter, transform, aggregate, join, window.

### Stream-table duality

A stream is a sequence of changes; a table is a snapshot of state. They're dual:
- **Stream → table**: aggregate the stream.
- **Table → stream**: emit changes (CDC).

Kafka Streams models this directly; KStream and KTable.

### Schema Registry

Manages event schemas. Producers register; consumers fetch by ID. Compatibility checks (backward, forward, full).

Without schema management: producer changes; consumer breaks. With registry: changes validated; backward compatibility enforced.

Confluent's Schema Registry is standard; alternatives exist.

### Kafka Connect

Pre-built connectors for moving data in/out of Kafka:
- Source connectors: from DB to Kafka (e.g., Debezium for CDC).
- Sink connectors: from Kafka to DB / search / etc.

Eliminates writing custom integrators. Battle-tested for many systems.

### Operational concerns

**Lag monitoring**: consumer lag is the canonical SLI.

**ISR shrinkage**: followers falling out of ISR signals problems.

**Controller**: one broker is the cluster controller; metadata changes go through it. Monitor controller health.

**Rebalances**: storms degrade throughput.

**Disk space**: retention drives disk usage; plan capacity.

---

## Real Engineering Analogies

**The newspaper archive.**
(Already used.) The log is permanent; subscribers read at their pace; multiple subscribers see the same stories; old archives eventually purged.

**The black box flight recorder.**
Append-only; durably stores everything; can be replayed; survives the original system. Kafka is the same idea, scaled to production data.

---

## Production Engineering Perspective

What goes wrong:

- **The lag explosion.** Consumer falls behind; lag grows; eventually retention purges unconsumed events. Data lost.
- **The rebalance storm.** Frequent consumer changes cause repeated rebalances; throughput suffers.
- **The hot partition.** Skewed key distribution; one partition does most work; consumer of that partition lagged.
- **The unclean election data loss.** `unclean.leader.election=true`; out-of-sync replica elected; data loss.
- **The storage explosion.** Retention misconfigured or compaction broken; disk fills.
- **The schema break.** Producer changes; consumer breaks. Schema registry would have caught.
- **The disconnected ZK.** Pre-KRaft: ZooKeeper outage = Kafka unavailable.

The senior Kafka operator's habits:
- **Monitor lag** continuously.
- **Plan partition counts** for max parallelism.
- **Schema registry** mandatory.
- **Plan retention** with disk capacity.
- **Test failover** regularly.
- **Avoid unclean elections** unless availability demands.
- **Cooperative rebalancing** when available.

---

## Failure Scenarios

**Scenario 1 — The retention purge.**
Consumer down for 8 days; retention 7 days; events purged. Some lost. Recovery: extend retention; rebuild from upstream source.

**Scenario 2 — The hot key bottleneck.**
A "celebrity" customer drives 50% of events; all to one partition; consumer can't keep up. Mitigation: bucketing; rebalance partition count.

**Scenario 3 — The data-loss election.**
Network blip causes leader switch. Out-of-sync replica elected (unclean=true); data after last sync gone. Lesson: keep unclean=false for critical topics.

**Scenario 4 — The rebalance storm.**
Auto-scaling consumers; constant rebalances; throughput chaotic. Fix: stable consumer count; cooperative rebalance.

**Scenario 5 — The schema break.**
Producer drops a field; consumer expects it. Errors. Mitigation: schema registry with backward compatibility.

---

## Performance Perspective

- **Producer throughput**: tens of MB/s per producer instance; hundreds with batching.
- **Broker throughput**: hundreds of MB/s per broker.
- **Consumer throughput**: bounded by processing.
- **End-to-end latency**: ms to seconds depending on config.
- **Disk usage**: scales with data + retention.

---

## Scaling Perspective

- **Single cluster**: hundreds of TB; thousands of topics.
- **Multi-cluster**: MirrorMaker for cross-region.
- **At hyperscale**: dedicated Kafka teams; specialized tooling (LinkedIn, Uber).

---

## Cross-Domain Connections

- **Event-driven architecture**: Kafka is the substrate. (See [event-driven-architecture.md](./event-driven-architecture.md).)
- **Idempotency**: at-least-once + idempotent consumers. (See [idempotency-receivers-and-exactly-once-semantics.md](./idempotency-receivers-and-exactly-once-semantics.md).)
- **Sagas**: orchestrated via Kafka often. (See [saga-pattern-and-distributed-transactions.md](./saga-pattern-and-distributed-transactions.md).)
- **Backpressure**: consumer lag is the metric. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Replication**: Kafka's design. (See [replication-strategies.md](../database-internals/replication-strategies.md).)
- **WAL**: Kafka is essentially a distributed WAL. (See [wal-and-crash-recovery.md](../database-internals/wal-and-crash-recovery.md).)

The unifying observation: **Kafka is a distributed log treated as a primary primitive. Once you see this, the design choices — partitions, offsets, replication, retention — become coherent. Kafka is what happens when "the log is the database" is taken seriously.**

---

## Real Production Scenarios

- **LinkedIn's origin**: extensively documented.
- **Netflix's adoption**: public engineering posts.
- **Uber's Kafka usage**: trillions of events.
- **Slack, Pinterest, etc.**: many public case studies.

---

## What Junior Engineers Usually Miss

- That **Kafka is a log, not a queue**.
- That **partitions enable parallelism**.
- That **consumers track their own offsets**.
- That **retention is configurable**.
- That **partition order is per-partition**.

---

## What Senior Engineers Instinctively Notice

- They **monitor lag**.
- They **partition by access pattern**.
- They **use schema registry**.
- They **plan retention**.
- They **avoid unclean election** for critical topics.

---

## Interview Perspective

What gets tested:

1. **"What's a Kafka topic?"** Logical category; partitioned log.
2. **"Partitions?"** Independent ordered logs; parallelism unit.
3. **"How do consumers track position?"** Offsets; consumer group.
4. **"Replication?"** Leader + ISR followers.
5. **"Exactly-once?"** Idempotent + transactional within Kafka.

Common traps:
- Treating Kafka as a queue.
- Believing global ordering exists.

---

## 20% Knowledge Giving 80% Understanding

1. **Kafka = distributed log**.
2. **Topic → partitions → segments**.
3. **Partitions enable parallelism**.
4. **Consumer groups for fan-out + parallelism**.
5. **ISR-based replication**.
6. **Per-partition ordering**.
7. **Retention by time or size**.
8. **Compaction** for state-of-key topics.
9. **Schema registry** for evolution.
10. **Lag is the SLI**.

---

## Final Mental Model

> **Kafka is what happens when 'the log is the database' is taken as architectural truth. Partitioned, replicated, retained logs become the substrate of event-driven systems. The patterns built on top — sagas, CQRS, CDC, stream processing — all rely on Kafka's primitives. Master Kafka and you master a generation's worth of architectural patterns.**

The senior Kafka operator monitors lag continuously, plans partitioning carefully, uses schema registry rigorously. The platform rewards discipline; production Kafka clusters run for years.

That's Kafka. That's stream processing. That's the substrate under every event-driven architecture worth shipping.
