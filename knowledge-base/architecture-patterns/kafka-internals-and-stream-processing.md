# Kafka Internals & Stream Processing

> *"Kafka is a distributed log dressed up as a message broker. The 'log' is the central abstraction: append-only, partitioned, replicated, retained for arbitrary duration. Once you see Kafka as 'a database that you query by reading forward in time,' the design choices that confuse first-time users — offsets, partitions, retention, consumer groups — become obvious. Kafka is the substrate of nearly every modern event-driven architecture."*

---

## 🎯 Start Here — Intuition

> **In one line:** Kafka lets one part of a system hand events to many other parts reliably, keeping a durable record so each reader can consume them at its own pace — even days later.
>
> **Analogy:** Think of a newspaper that never throws away an issue. Stories are appended in order, kept on the shelf for a set time, and any number of subscribers can read at their own pace — some read every issue, some skip ahead — and each just remembers which page they were on.
>
> **New to this?** Build the basics first in [`learn/architecture/message-brokers.md`](../../learn/architecture/message-brokers.md) — *then* come back for the depth.
>
> **Level:** this file is 🔴 overall — it's a senior/staff deep-dive into Kafka's internals. The opening sections are approachable; the storage, replication, EOS (Exactly-Once Semantics), and stream-processing sections assume real distributed-systems comfort. If the basics feel shaky, that tag is your signal to slow down — **you are not behind.**

---

## Topic Overview 🟢

Apache Kafka is the dominant open-source streaming platform. It's used as a message broker, an event store, a CDC (Change Data Capture) pipeline, an audit log, a buffer between services. The design — partitioned, replicated, append-only logs — has shaped the industry's thinking about events.

Internals: **topics** divided into **partitions**; partitions replicated across **brokers**; producers write to partitions; consumers read at their own pace; offsets track position. Replication via in-sync replicas (ISR); consensus for metadata via Raft (KRaft, Kafka Raft) or ZooKeeper (legacy).

Stream processing extends Kafka: Kafka Streams (library), Apache Flink, ksqlDB. Built on the log; treat events as a continuous flow; transform, aggregate, join in real time.

This is the topic where event-driven architecture meets the storage primitive that enables it. Understanding Kafka — partitioning, replication, consumer offsets, stream processing — is what makes "event-driven" a viable architecture rather than a design pattern in slides.

---

## Intuition Before Definitions 🟢

Imagine a newspaper that publishes continuously. Every story is appended to a single issue (the topic). The issue has multiple sections (partitions), each in its own queue.

Subscribers (consumers) read at their own pace. Some read every story (sequential). Some skip ahead. Each subscriber tracks where they are.

The newspaper keeps every story for a configurable duration (retention). Want last week's news? Still there. Want yesterday's? Re-read it. The "newspaper" is an immutable log.

Multiple subscribers can read the same story. Each at their own pace. The newspaper doesn't know or care.

Now imagine the newspaper has multiple printing presses (brokers). Each press handles some sections. If a press fails, another has a copy (replication).

That's Kafka. Topics, partitions, brokers, consumer offsets — the newspaper analogy. The genius: the newspaper isn't deleted after consumption; it's a permanent log everyone can read.

---

## Historical Evolution 🟢

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

## Deep Technical Explanation 🔴

⚠️ The rest assumes the basics above are solid.

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
- Sequential disk writes (very fast on HDD (Hard Disk Drive) / SSD (Solid-State Drive)).
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

**Lag monitoring**: consumer lag is the canonical SLI (Service Level Indicator).

**ISR shrinkage**: followers falling out of ISR signals problems.

**Controller**: one broker is the cluster controller; metadata changes go through it. Monitor controller health.

**Rebalances**: storms degrade throughput.

**Disk space**: retention drives disk usage; plan capacity.

### The durability knob: `min.insync.replicas` + `acks=all` 🔴

`acks=all` alone is not durable. It means "wait for all replicas *currently in the ISR* to ack" — but the ISR can shrink to **one** (just the leader) under follower lag or broker failure. In that state, `acks=all` degrades to `acks=1`: the leader acks its own write, then dies, and the data is gone. The producer got a success.

`min.insync.replicas` (a topic/broker config) closes this hole. It sets the *minimum* ISR size that must exist for a write to be accepted. If the ISR has fewer than this many replicas, the leader **rejects the produce request** with `NotEnoughReplicasException` rather than accepting an under-replicated write. The producer sees the error and can retry/alert instead of silently losing data.

The three settings only achieve durability **together**:
- `acks=all` — wait for the whole ISR (without it, `min.insync.replicas` is ignored; a leader-only ack never consults the ISR).
- `min.insync.replicas=2` — require at least 2 replicas in sync before accepting.
- `replication.factor=3` — so the cluster can lose one broker and still satisfy `min.insync=2`.

The canonical safe config is **RF=3, min.insync.replicas=2**. This guarantees every acked write lives on ≥2 brokers, so a single broker loss never loses acknowledged data, *and* the topic stays writable through one broker failure (2 of 3 still in sync). Setting `min.insync.replicas` equal to `replication.factor` (3 here) is more durable but means **any** single broker loss makes the partition unavailable for writes — a common over-tightening mistake. Note this knob governs *acknowledged-write durability*, not availability; it deliberately chooses to reject writes (CP-leaning) over accepting unsafe ones.

### ISR membership mechanics 🔴

A follower is **in-sync** if it has fully caught up to the leader's log recently enough. The governing config is **`replica.lag.time.max.ms`** (default 30s). The rule is time-based, not message-count-based (the old `replica.lag.max.messages` was removed because a fixed message threshold mis-handled bursty traffic):

- A follower stays in the ISR as long as it has sent a fetch request that caught up to the leader's log-end-offset within the last `replica.lag.time.max.ms`.
- If a follower stops fetching, or keeps fetching but **can't keep pace** with incoming writes (its fetch position lags the leader's end offset for longer than the window), the leader **removes it from the ISR**. This shrinks the ISR.
- When the lagging follower catches back up (its fetched offset reaches the leader's high-water mark within the window), the leader re-adds it. ISR membership is continuously recomputed by the leader and persisted via the controller.

Why it matters: a slow disk, GC pause, network saturation, or simply a partition whose write rate exceeds follower fetch throughput all cause ISR shrinkage. That directly interacts with the durability knobs above — if the ISR shrinks below `min.insync.replicas`, writes start failing; if it shrinks to 1 and you allowed `unclean.leader.election=true`, you're one failure away from data loss. The **high-water mark** (the offset replicated to all ISR members) is the highest offset a consumer can read — under-replication can also stall consumer-visible progress.

### Log compaction in detail 🔴

`cleanup.policy` accepts `delete` (default), `compact`, or both (`compact,delete`). The three are different retention models, not interchangeable:

- **`delete`** — drop whole segments once they exceed `log.retention.ms`/`log.retention.bytes`. Time/size-based; oblivious to keys.
- **`compact`** — retain **the latest value for every key, forever** (or until further updated), discarding superseded older values for the same key. This turns the topic into a changelog/materialized "current state" — the backing store for `KTable`s, Kafka Streams state-store changelogs, and `__consumer_offsets` itself.

Mechanics of compaction:
- A background **log cleaner** thread rewrites segments, keeping only the most recent record per key. It only ever compacts the "tail" — records before the active segment and before the cleaner point — so the most recent writes (the "head") are always retained in arrival order.
- **Tombstones**: to *delete* a key from a compacted topic, you produce a record with that key and a **null value**. The cleaner treats it as a delete marker, removes prior values for the key, then after `delete.retention.ms` (default 24h) removes the tombstone itself — the delay gives consumers time to observe the delete before it's garbage-collected.
- Compaction guarantees the *latest* state per key survives but makes **no offset-contiguity guarantee** — offsets become sparse as superseded records are removed; consumers must not assume consecutive offsets.

A key requirement: compacted topics need **keyed** records (a null key has nothing to compact on). Use `compact` for state/changelog topics; use `delete` for event streams where history matters; `compact,delete` bounds a changelog's size while still compacting.

### Adding partitions breaks key→partition routing 🔴

This is the most-missed Kafka gotcha. The default partitioner computes `partition = hash(key) % num_partitions`. The ordering guarantee Kafka actually offers is **per-partition**, and keyed producers rely on "same key → same partition" to preserve per-entity order (all events for `user-42` land together, in order).

The moment you **increase the partition count** (Kafka only allows growing, never shrinking), `num_partitions` changes, so `hash(key) % N` changes for most keys. A key that mapped to partition 3 under `% 6` may map to partition 1 under `% 10`. Concretely:

- **Key→partition routing changes for existing keys.** New events for `user-42` may now go to a *different* partition than its historical events.
- **Per-key ordering breaks across the boundary.** Old events for the key sit in the old partition; new events land in a new partition; two consumers process them concurrently with no ordering relationship. An event-sourced or CDC consumer can now apply updates out of order.
- It is **not** a modulo-friendly resize like consistent hashing — there is no rebalancing of already-written records; history stays where it was written.

Practical consequences and mitigations:
- **Over-provision partitions up front.** Choose a partition count for your *future* peak parallelism; it's far cheaper to start with more partitions than to repartition a live keyed topic.
- If you must repartition, accept an **ordering discontinuity** at the cutover, or do it via a **new topic + reprocessing** (consume old → produce to a fresh topic with the new partition count) so you control the migration rather than mutating a live topic.
- Compacted topics are especially hostile to partition growth: a key's old value lives in its old partition and its new value in a new one, so the "latest value per key" invariant the topic exists to provide is silently violated.

---

## Real Engineering Analogies 🟢

**The newspaper archive.**
(Already used.) The log is permanent; subscribers read at their pace; multiple subscribers see the same stories; old archives eventually purged.

**The black box flight recorder.**
Append-only; durably stores everything; can be replayed; survives the original system. Kafka is the same idea, scaled to production data.

---

## Failure Scenarios 🟡

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

## Performance Perspective 🟡

- **Producer throughput**: tens of MB/s per producer instance; hundreds with batching.
- **Broker throughput**: hundreds of MB/s per broker.
- **Consumer throughput**: bounded by processing.
- **End-to-end latency**: ms to seconds depending on config.
- **Disk usage**: scales with data + retention.

---

## Scaling Perspective 🟡

- **Single cluster**: hundreds of TB (Terabytes); thousands of topics.
- **Multi-cluster**: MirrorMaker for cross-region.
- **At hyperscale**: dedicated Kafka teams; specialized tooling (LinkedIn, Uber).

---

## Cross-Domain Connections 🔴

- **Event-driven architecture**: Kafka is the substrate. (See [event-driven-architecture.md](./event-driven-architecture.md).)
- **Idempotency**: at-least-once + idempotent consumers. (See [idempotency-receivers-and-exactly-once-semantics.md](./idempotency-receivers-and-exactly-once-semantics.md).)
- **Sagas**: orchestrated via Kafka often. (See [saga-pattern-and-distributed-transactions.md](./saga-pattern-and-distributed-transactions.md).)
- **Backpressure**: consumer lag is the metric. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Replication**: Kafka's design. (See [replication-strategies.md](../database-internals/replication-strategies.md).)
- **WAL (Write-Ahead Log)**: Kafka is essentially a distributed WAL. (See [wal-and-crash-recovery.md](../database-internals/wal-and-crash-recovery.md).)

The unifying observation: **Kafka is a distributed log treated as a primary primitive. Once you see this, the design choices — partitions, offsets, replication, retention — become coherent. Kafka is what happens when "the log is the database" is taken seriously.**

---

## Real Production Scenarios 🟡

- **LinkedIn's origin**: extensively documented.
- **Netflix's adoption**: public engineering posts.
- **Uber's Kafka usage**: one of the largest deployments; Uber has publicly described processing on the order of trillions of messages (multiple petabytes) per day.
- **Slack, Pinterest, etc.**: many public case studies.

---

## Key Takeaways

- **Kafka is a distributed log, not a queue.** "The log is the database" taken as architectural truth: partitioned, replicated, retained logs become the substrate of event-driven systems. The patterns built on top — sagas, CQRS (Command Query Responsibility Segregation), CDC, stream processing — all rely on Kafka's primitives.
- **The hierarchy is topic → partitions → segments.** A topic is a logical category; partitions are independent ordered logs; each partition is a series of append-only segment files on disk.
- **Partitions are the unit of parallelism.** A topic with 100 partitions can be consumed by up to 100 parallel consumers per consumer group. Plan partition counts for max parallelism.
- **Consumer groups give both fan-out and parallelism.** Each partition is consumed by exactly one consumer in a group; each group tracks its own offset per partition (stored in `__consumer_offsets`).
- **Ordering is per-partition, never global.** Believing global ordering exists is a common trap; partition by access pattern / key to get the ordering you actually need.
- **Replication is ISR-based.** Leader + N-1 followers; only in-sync replicas can be elected. Avoid `unclean.leader.election=true` for critical topics — it trades data safety for availability and causes silent data loss on failover.
- **Retention is configurable by time or size** (`cleanup.policy=delete`), while **compaction** (`cleanup.policy=compact`) keeps the latest value per key forever — the backing model for changelogs, KTables, and `__consumer_offsets`. Deletes in a compacted topic are **tombstones** (null-value records); offsets become sparse after compaction.
- **Durability needs three settings together, not just `acks=all`.** The safe config is **RF=3 + `min.insync.replicas=2` + `acks=all`**: every acked write lands on ≥2 brokers and the topic survives one broker loss. `acks=all` alone degrades to `acks=1` when the ISR shrinks to the leader; `min.insync.replicas` rejects under-replicated writes instead of silently losing them. A replica leaves the ISR when it lags past `replica.lag.time.max.ms` (default 30s).
- **Adding partitions breaks key→partition routing.** `hash(key) % N` changes when `N` grows, so existing keys remap and per-key ordering breaks across the cutover (and compacted-topic "latest per key" is silently violated). Over-provision partitions up front, or repartition via a new topic + reprocessing.
- **Schema registry is mandatory in practice** — it enforces backward compatibility and prevents producer changes from silently breaking consumers.
- **Consumer lag is the canonical SLI** — monitor it continuously; runaway lag plus finite retention means unconsumed events get purged and lost.
- **Test failover regularly**, prefer **cooperative (incremental) rebalancing** when available to avoid rebalance-storm throughput halts, and **plan retention against disk capacity** to avoid storage exhaustion.
- **Operational watch-outs unique to Kafka:** ISR shrinkage signals trouble, the controller broker's health gates all metadata changes, and pre-KRaft a ZooKeeper outage makes the whole cluster unavailable (KRaft removes that dependency).

## Interview angle

- **"What's a Kafka topic?"** Logical category; a partitioned, append-only log.
- **"What are partitions?"** Independent ordered logs; the unit of parallelism.
- **"How do consumers track position?"** Offsets, committed per consumer group.
- **"How does replication work?"** Leader plus in-sync replica (ISR) followers.
- **"How does exactly-once work?"** Idempotent + transactional producers within Kafka (external systems still need idempotent receivers).
- **Common traps to avoid:** treating Kafka as a queue, and assuming global ordering across partitions.
