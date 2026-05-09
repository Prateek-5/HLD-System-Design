# Replication Strategies

> *"Data has only one truly safe place: the place from which you have a copy elsewhere. Replication is the engineering of 'elsewhere' — the act of putting data in multiple places fast enough to survive failures, slow enough to maintain consistency, and cheaply enough to actually deploy."*

---

## Topic Overview

Database replication is how copies of data live on multiple machines, kept in sync to varying degrees. It's the foundation of every reliable production database — single-instance databases are toys; production runs on replicas. The choice of replication strategy shapes everything: read scalability, failover speed, consistency guarantees, write latency, operational complexity.

The fundamental dimensions: **synchronous vs asynchronous**, **single-leader vs multi-leader vs leaderless**, **per-row vs per-statement**. Each combination is a different point in the consistency-availability-latency space, with different operational characteristics. There's no single best choice; there are workload-fits.

This is the topic that operationalizes CAP theorem, MVCC, and consensus into actual database architectures. Postgres's streaming replication, MySQL's various replication modes, Cassandra's quorum-based writes, Kafka's ISR — all are specific designs in this space. Understanding them shapes both database selection and operational practice.

---

## Intuition Before Definitions

Imagine a corporate ledger maintained by multiple secretaries.

**Single-leader async.** One head secretary writes the master copy. Others have copies, updated periodically. If the head is unreachable, you can't write — but you can read from copies. If the head's office burns down, the most recent updates may be lost (the copies were a few minutes behind).

**Single-leader sync.** Same, but the head secretary won't acknowledge a write until at least one copy-holder has confirmed receipt. Slower per write; no data loss on head failure.

**Multi-leader.** Several secretaries can write. They sync changes to each other. Faster (writes happen anywhere); but two secretaries might write conflicting entries about the same account simultaneously. Reconciliation is needed.

**Leaderless.** Anyone can write to any copy-holder. Reads consult multiple holders to get an up-to-date answer. Highly available; consistency is harder.

Each model has pros and cons. The right choice depends on what you need: low write latency, strict consistency, geographic distribution, simple operations. Real systems pick a strategy and then live with the implications.

---

## Historical Evolution

**Era 1 — Single-master.**
1990s, early 2000s. Postgres, MySQL, Oracle. One primary; periodic backups; no online replicas. Failure recovery was hours of restore.

**Era 2 — Streaming replication.**
~2005. Async replication via log shipping. Read replicas for scaling reads. Primary still single point of failure for writes.

**Era 3 — Synchronous replication options.**
Late 2000s. Postgres synchronous replication; MySQL semi-sync. Primary waits for replica acks before commit. Stronger durability; latency cost.

**Era 4 — Multi-master systems.**
2010s. MySQL Group Replication, Postgres BDR, Galera. True multi-leader writes. Operational complexity high; conflict resolution often tricky.

**Era 5 — Distributed-by-design databases.**
~2014 onward. Cassandra, DynamoDB, CockroachDB, Spanner. Replication is built-in, not added on. Quorum-based, leaderless, or consensus-driven.

**Era 6 — Cloud-native replication.**
Modern: managed services that abstract replication (Aurora, AlloyDB, PlanetScale). Storage decoupled from compute; replication is a property of the storage layer.

The pattern: each generation pushed replication deeper into the database design — from external tooling, to first-class feature, to architectural foundation.

---

## Core Mental Models

**1. Sync vs async is the most important dimension.**
Sync: write isn't done until replicas confirm. Strong durability; latency cost; availability trade-off (if a replica is down, can you commit?).
Async: write completes locally; replicas catch up. Low latency; window of data loss on primary failure.

**2. Read replicas don't scale writes; they scale reads.**
Adding read replicas helps if your bottleneck is read load. Doesn't help if it's writes. Easy to misdiagnose.

**3. Lag is a first-class concern.**
Async replicas trail the primary. Lag varies. Reading from a lagged replica gives stale data. Every async-replicated system needs lag monitoring.

**4. Failover is a separate problem from replication.**
Replication ships data; failover decides what to do when the primary fails. The two often have different failure modes; one can work without the other.

**5. The consistency model is what your application sees.**
Replication strategy determines consistency. Application code that expects strong consistency on a system with eventually-consistent replicas will have bugs.

---

## Deep Technical Explanation

### Single-leader replication

The classic model. One primary handles all writes; one or more replicas receive a stream of changes.

**Mechanism:**
- WAL streaming (Postgres): replicas tail the primary's WAL.
- Binlog streaming (MySQL): primary's binary log shipped to replicas.
- Statement-based: SQL statements re-executed on replicas (deprecated; non-deterministic statements break this).
- Row-based: actual row changes replicated (preferred).

**Sync modes:**
- **Asynchronous**: primary commits locally; replicas catch up. Default in most systems.
- **Synchronous**: primary waits for at least one replica to ack. Stronger durability.
- **Semi-synchronous**: primary waits for an ack, but doesn't wait for the replica to actually apply (just receive). Middle ground.

Postgres-specific:
- `synchronous_commit = on`: wait for local fsync.
- `synchronous_commit = remote_apply`: wait for replica to apply.
- `synchronous_standby_names`: which replicas count.

**Trade-offs:**
- Sync replication: zero-data-loss promise; per-write latency = primary commit + slowest replica RTT.
- Async: low latency; possible data loss equal to replication lag.

### Read scaling

Replicas serve reads:
- Application routes reads to replicas; writes to primary.
- Driver-level routing (e.g., Postgres's pgpool, ProxySQL for MySQL).
- Application-level routing (manual).

Pitfalls:
- **Read-after-write inconsistency.** Write to primary; read from replica before replication catches up; see old data.
- **Replica lag spikes** make this worse.
- Mitigations: stickiness (recent writers read from primary for some time); explicit primary reads when consistency matters; "read your own writes" tracking.

### Multi-leader replication

Multiple primaries; writes can occur on any. Replicas exchange updates.

**Use cases:**
- Multi-datacenter active-active.
- Offline-tolerant applications (write locally; sync later).

**Conflict resolution:**
- **Last-write-wins (LWW)**: timestamp-based. Issues with clock skew.
- **Per-field merge**: merge changes if they don't overlap.
- **Application-level resolution**: callback to resolve conflicts.
- **CRDTs**: data structures that merge cleanly.

**Operational reality:**
- Multi-leader is operationally complex.
- Schema changes are hard (requires coordinated DDL).
- Performance is good; correctness is the challenge.

### Leaderless replication

Cassandra, DynamoDB, Riak. No designated primary; clients write to N replicas; read from R replicas.

**Quorum:**
- N: replication factor.
- W: writes acknowledged.
- R: reads consulted.
- W + R > N: overlapping quorums; reads see latest write (under non-failure).

**Read repair, anti-entropy:**
- Read repair: when a read sees stale data on one replica, the system updates it.
- Anti-entropy: periodic background sync to converge replicas.

**Properties:**
- High availability (any node can serve writes).
- Tunable consistency (W and R are knobs).
- Eventually consistent by default; tunable to stronger.

### Replication topology

How replicas are arranged:
- **Star**: one primary, multiple replicas direct.
- **Chain**: primary → replica → replica.
- **Tree**: primary → multiple intermediates → many leaves.
- **Mesh**: multi-leader peer-to-peer.

Choices affect propagation latency, fault tolerance, bandwidth.

### Replication lag

Async replicas always trail the primary. Lag is measured in:
- **Bytes behind**: how much WAL/binlog hasn't been applied.
- **Time behind**: how stale is the replica's data.

Causes:
- Slow replica disk/CPU.
- Network bandwidth.
- Heavy primary write rate.
- Replica running queries (Postgres: replica is read-only but queries take resources).

Operational implications:
- **Failover risk**: lag = potential data loss in async mode.
- **Read consistency**: lagged replica returns old data.
- **Vacuum lag**: long-running queries on replica can pin WAL on primary (with `hot_standby_feedback`).

### Failover

Process of promoting a replica when primary fails:
1. Detect primary failure (timeout, health check).
2. Choose new primary (typically the replica with the most recent data).
3. Promote: replica becomes writable.
4. Reconfigure: clients route to new primary.
5. Old primary, when it returns, must reconcile.

Pitfalls:
- **Split-brain**: two primaries simultaneously. Catastrophic.
- **Data loss**: async replication may lose recent writes.
- **Reconfiguration time**: clients need to know about new primary.

Tools: Patroni (Postgres), Orchestrator (MySQL), built-in (managed services).

### Synchronous replication's hidden cost

It's not just latency. It's:
- **Availability**: if a synchronous replica is down, you can't commit (waiting forever). Most systems have logic to drop slow replicas, but the trade-off is real.
- **Compounded latency**: each layer adds. Cross-region sync replication: 50-200ms per write minimum.
- **Operational complexity**: which replicas count? What's the quorum?

Most production systems run async with very low typical lag (milliseconds), accepting the small data-loss window for the latency win.

### Logical vs physical replication

**Physical**: replicate WAL/binlog at the byte level. Same database version required. Whole cluster replicated.

**Logical**: replicate as logical changes (INSERT, UPDATE, DELETE). Different versions possible. Subset of tables can be replicated. CDC tools (Debezium) work on logical replication.

Use cases:
- **Physical**: HA replicas; fast.
- **Logical**: heterogeneous replication (e.g., to data warehouse); selective; cross-version.

### Cross-region replication

Same patterns at larger scale:
- Async typically (latency between regions is too high for sync).
- Replication lag measured in seconds during incidents.
- Failover across regions is a major operational event.

Multi-region active-active requires multi-leader, with all its complexity.

### Storage-decoupled replication (Aurora-style)

Modern cloud databases (Amazon Aurora, Google AlloyDB) decouple compute from storage:
- WAL is shipped to a distributed storage layer.
- Storage replicates the WAL across multiple AZs.
- Compute instances are stateless; failover is fast (just point to the same storage).

Properties:
- Fast failover (seconds, not minutes).
- High durability (storage layer replicates, not the database).
- Decoupled scaling (more compute without more storage).

---

## Real Engineering Analogies

**The newspaper editions.**
A newspaper has a master copy at HQ. Regional offices receive printed editions, slightly delayed. Subscribers in remote regions read yesterday's news. If HQ burns down, regional copies are slightly out of date.

That's async replication. Faster delivery (regional printing); some staleness (lag); resilience (HQ failure doesn't lose all data).

**The bank's branch network.**
A bank's transactions are eventually-consistent: branches share information overnight. A withdrawal at one branch may not show up at another for hours. Multi-leader: any branch can transact. Resolution: occasional reconciliation.

Modern banking has moved to real-time replication (sync) for fraud reasons, but the original model was async multi-leader. The shift was driven by regulatory and customer-facing concerns.

---

## Production Engineering Perspective

What goes wrong:

- **The replica lag explosion.** A heavy reporting query on a replica grew slow; replica fell behind by 20 minutes. Failover during incident: 20 minutes of data loss. Lesson: monitor lag; consider replica isolation.
- **The split-brain disaster.** Network partition; both sides promote a replica; writes diverge; reconciliation is days of work. Lesson: consensus-backed failover; never auto-promote without quorum.
- **The "read replica isn't seeing my data" surprise.** Application reads from replica immediately after write; replica hasn't caught up; gets old data. Surprised support tickets. Fix: stickiness or primary reads.
- **The synchronous replication availability hit.** Sync replication configured for HA; one replica's network hiccups; primary refuses to commit. Production halts. Mitigation: timeout to drop slow replicas; or multiple sync candidates with quorum-style logic.
- **The schema change cascade.** DDL on primary; replicas must apply same DDL. If not coordinated (different versions, online vs offline DDL), replicas fall behind dramatically.
- **The logical replication slot growth.** A logical replication consumer is paused; primary's WAL grows because it can't be cleaned up. Disk fills. Production halts.
- **The cross-region failover that hadn't been tested.** First time exercising it: discovers a configuration bug. RTO (recovery time objective) wildly exceeded. Lesson: test failover regularly.

The senior DBA's habits:
- **Monitor replication lag** as a primary metric.
- **Test failover regularly**.
- **Plan stickiness** for read-after-write consistency.
- **Use semi-sync or sync** for critical durability.
- **Document failover runbooks**.
- **Watch logical replication slots**.
- **Plan for cross-region failures**.

---

## Failure Scenarios

**Scenario 1 — The async data loss.**
Primary crashes; failover to replica. Replica was 30 seconds behind. 30 seconds of writes lost. Customer support: "I made a payment but it doesn't show up." Investigation; reconciliation. Lesson: sync or semi-sync for critical data.

**Scenario 2 — The split-brain.**
Network partition; both halves of the cluster believe they should be primary. Both accept writes. Partition heals; data has diverged on the same keys. Manual reconciliation; some writes lost. Recovery: consensus-based failover prevents this.

**Scenario 3 — The vacuum-pinned WAL.**
A reporting query on the replica with `hot_standby_feedback = on`. Primary cannot vacuum because the replica's snapshot pins WAL. Bloat grows; performance degrades; eventually disk fills.

**Scenario 4 — The cascading replication failure.**
Three-node Galera cluster. One node has a slow disk; falls behind. Other nodes throttle to keep it consistent. All nodes appear slow. Eventually slow node is dropped; cluster recovers. Discovery: synchronous replication's availability cost.

**Scenario 5 — The Logical replication slot disaster.**
CDC consumer (Debezium) pauses for maintenance. Postgres retains all WAL the consumer hasn't acknowledged. Disk grows by 100GB/day. Discovery: 5 days later, when disk is 90% full. Recovery: drop the slot; CDC must replay from a fresh start.

---

## Performance Perspective

- **Async replication**: minimal write latency overhead; replica processing is asynchronous.
- **Sync replication**: latency = primary commit + slowest sync replica RTT.
- **Read replicas**: read scalability scales linearly with replica count, until network or coordination overhead limits.
- **Lag impact**: lag is bandwidth-limited; high write rate = high lag possibility.

---

## Scaling Perspective

- **Vertical**: bigger primary handles more writes.
- **Read scaling**: add replicas; trivial.
- **Write scaling**: requires sharding; replication is per-shard.
- **Geographic**: cross-region async typical; cross-region sync expensive.
- **At hyperscale**: multi-shard, multi-region, with consensus per shard (Spanner, Cockroach).

---

## Cross-Domain Connections

- **CAP**: replication strategy determines CAP position. (See [cap-consistency-and-replication.md](../distributed-systems/cap-consistency-and-replication.md).)
- **WAL**: physical replication is WAL streaming. (See [wal-and-crash-recovery.md](./wal-and-crash-recovery.md).)
- **Consensus**: synchronous replication often uses consensus for failover. (See [leader-election-and-consensus.md](../distributed-systems/leader-election-and-consensus.md).)
- **MVCC**: replicas serve consistent snapshots; vacuum interacts with replication. (See [mvcc-and-isolation-levels.md](./mvcc-and-isolation-levels.md).)
- **Sharding**: replication and sharding compose; replica sets per shard. (See [sharding-and-partitioning-strategies.md](../scalability/sharding-and-partitioning-strategies.md).)
- **Disaster recovery**: replication is the foundation of DR. (See [disaster-recovery-and-rto-rpo.md](../system-failures/disaster-recovery-and-rto-rpo.md).)

The unifying observation: **replication is the bridge between durability (one machine) and availability (many machines). Every choice in the strategy maps to a specific position in the consistency-latency-availability space.**

---

## Real Production Scenarios

- **Postgres streaming replication**: industry standard for HA Postgres. Documented operational practices.
- **MySQL group replication**: more recent multi-leader. Public adoption stories.
- **Cassandra at Netflix**: large-scale leaderless replication. Public engineering.
- **Spanner's TrueTime + Paxos**: documented design.
- **Aurora's storage-decoupled architecture**: published papers.
- **Discord's database evolution**: from MongoDB to Cassandra to ScyllaDB; replication choices documented.

---

## What Junior Engineers Usually Miss

- That **async replication has data-loss windows.**
- That **sync replication has availability costs.**
- That **read replicas don't scale writes.**
- That **lag matters** for read consistency.
- That **failover and replication are separate concerns.**
- That **multi-leader is operationally complex.**
- That **logical replication slots can fill disk.**
- That **schema changes** are hard in replicated systems.

---

## What Senior Engineers Instinctively Notice

- They **monitor replication lag** continuously.
- They **understand the data-loss window** of their setup.
- They **test failover** regularly.
- They **plan for split-brain prevention**.
- They **use semi-sync or quorum** for critical workloads.
- They **isolate read replicas** from primary's vacuum needs.
- They **track logical replication slots** as a metric.
- They **understand that replication is part of DR**.

---

## Interview Perspective

What gets tested:

1. **"Sync vs async replication?"** Tests fundamental.
2. **"How does Postgres streaming replication work?"** Tests practical knowledge.
3. **"What's split-brain?"** Two primaries; data divergence.
4. **"What's read-after-write consistency?"** Stickiness; primary reads.
5. **"Multi-leader's challenges?"** Conflict resolution; operational complexity.
6. **"How do quorum reads work?"** R + W > N.
7. **"What's logical vs physical replication?"** Logical: row-level; physical: byte-level.

Common traps:
- Believing replicas auto-scale writes.
- Underestimating lag impact.
- Not knowing about split-brain.

---

## 20% Knowledge Giving 80% Understanding

1. **Sync vs async** is the central trade-off.
2. **Read replicas scale reads, not writes.**
3. **Lag matters** for consistency.
4. **Async = data loss window** on primary failure.
5. **Sync = availability cost** if replica slow.
6. **Multi-leader has conflicts**; resolution is hard.
7. **Quorum (R+W > N)** for leaderless consistency.
8. **Failover is a separate concern** from replication.
9. **Test failover regularly.**
10. **Logical vs physical** replication: granularity choice.

---

## Final Mental Model

> **Replication is how you make data available somewhere it isn't already. The strategy determines what "somewhere" means: a hot standby (sync), a slightly-delayed read replica (async), a peer that can also accept writes (multi-leader), a quorum of equals (leaderless). Each model has a workload that fits.**

The senior DBA selecting a replication strategy considers the consistency requirements, latency budget, operational maturity, geographic distribution, and failure tolerance. They monitor lag continuously. They test failover monthly. They plan for split-brain. They size for both steady-state and recovery-mode.

The systems that survive failures gracefully are the ones with thoughtful replication. The systems that lose data, or freeze for hours, or split-brain are the ones where replication was an afterthought. The choice is consequential; the operational discipline more so.

That's replication. That's how data lives in multiple places, kept in sync to varying degrees. That's the foundation of every database that has ever survived a node failure — and the source of failures of every database that didn't.
