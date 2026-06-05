# Replication Strategies

> *"Data has only one truly safe place: the place from which you have a copy elsewhere. Replication is the engineering of 'elsewhere' — the act of putting data in multiple places fast enough to survive failures, slow enough to maintain consistency, and cheaply enough to actually deploy."*

---

## 🎯 Start Here — Intuition

> **In one line:** how to keep copies of your data on more than one machine, so that if one dies your service keeps running and doesn't lose what people just saved.
>
> **Analogy:** like keeping a backup of important photos on your phone *and* in the cloud — if your phone is lost you still have them, but the cloud copy might be a few minutes behind the very last photo you took. Replication is choosing how many copies, how spread out, and how up-to-date each one is.
>
> **New to this?** Build the basics first in [`learn/data/database-replication.md`](../../learn/data/database-replication.md) — *then* come back for the depth.
>
> **Level:** this file is 🟡 overall, with 🔴 deep-internals sections. Sections below are tagged. If the basics feel shaky, that tag is your signal to slow down — **you are not behind.**

---

## Topic Overview 🟢

Database replication is how copies of data live on multiple machines, kept in sync to varying degrees. It's the foundation of every reliable production database — single-instance databases are toys; production runs on replicas. The choice of replication strategy shapes everything: read scalability, failover speed, consistency guarantees, write latency, operational complexity.

The fundamental dimensions: **synchronous vs asynchronous**, **single-leader vs multi-leader vs leaderless**, **per-row vs per-statement**. Each combination is a different point in the consistency-availability-latency space, with different operational characteristics. There's no single best choice; there are workload-fits.

This is the topic that operationalizes CAP (Consistency, Availability, Partition tolerance) theorem, MVCC (Multi-Version Concurrency Control), and consensus into actual database architectures. Postgres's streaming replication, MySQL's various replication modes, Cassandra's quorum-based writes, Kafka's ISR (In-Sync Replicas) — all are specific designs in this space. Understanding them shapes both database selection and operational practice.

---

## Intuition Before Definitions 🟢

Imagine a corporate ledger maintained by multiple secretaries.

**Single-leader async.** One head secretary writes the master copy. Others have copies, updated periodically. If the head is unreachable, you can't write — but you can read from copies. If the head's office burns down, the most recent updates may be lost (the copies were a few minutes behind).

**Single-leader sync.** Same, but the head secretary won't acknowledge a write until at least one copy-holder has confirmed receipt. Slower per write; no data loss on head failure.

**Multi-leader.** Several secretaries can write. They sync changes to each other. Faster (writes happen anywhere); but two secretaries might write conflicting entries about the same account simultaneously. Reconciliation is needed.

**Leaderless.** Anyone can write to any copy-holder. Reads consult multiple holders to get an up-to-date answer. Highly available; consistency is harder.

Each model has pros and cons. The right choice depends on what you need: low write latency, strict consistency, geographic distribution, simple operations. Real systems pick a strategy and then live with the implications.

---

## Historical Evolution 🟡

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

## Deep Technical Explanation 🔴

> ⚠️ The rest assumes the basics above are solid.

### Single-leader replication

The classic model. One primary handles all writes; one or more replicas receive a stream of changes.

**Mechanism:**
- WAL (Write-Ahead Log) streaming (Postgres): replicas tail the primary's WAL.
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
- Sync replication: zero-data-loss promise; per-write latency = primary commit + slowest replica RTT (Round-Trip Time).
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
- **CRDTs (Conflict-free Replicated Data Types)**: data structures that merge cleanly.

**Operational reality:**
- Multi-leader is operationally complex.
- Schema changes are hard (requires coordinated DDL (Data Definition Language)).
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

**Logical**: replicate as logical changes (INSERT, UPDATE, DELETE). Different versions possible. Subset of tables can be replicated. CDC (Change Data Capture) tools (Debezium) work on logical replication.

Use cases:
- **Physical**: HA (High Availability) replicas; fast.
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
- Storage replicates the WAL across multiple AZs (Availability Zones).
- Compute instances are stateless; failover is fast (just point to the same storage).

Properties:
- Fast failover (seconds, not minutes).
- High durability (storage layer replicates, not the database).
- Decoupled scaling (more compute without more storage).

---

## Real Engineering Analogies 🟢

**The newspaper editions.**
A newspaper has a master copy at HQ. Regional offices receive printed editions, slightly delayed. Subscribers in remote regions read yesterday's news. If HQ burns down, regional copies are slightly out of date.

That's async replication. Faster delivery (regional printing); some staleness (lag); resilience (HQ failure doesn't lose all data).

**The bank's branch network.**
A bank's transactions are eventually-consistent: branches share information overnight. A withdrawal at one branch may not show up at another for hours. Multi-leader: any branch can transact. Resolution: occasional reconciliation.

Modern banking has moved to real-time replication (sync) for fraud reasons, but the original model was async multi-leader. The shift was driven by regulatory and customer-facing concerns.

---

## Production Engineering Perspective 🔴

What goes wrong:

- **The replica lag explosion.** A heavy reporting query on a replica grew slow; replica fell behind by 20 minutes. Failover during incident: 20 minutes of data loss. Lesson: monitor lag; consider replica isolation.
- **The split-brain disaster.** Network partition; both sides promote a replica; writes diverge; reconciliation is days of work. Lesson: consensus-backed failover; never auto-promote without quorum.
- **The "read replica isn't seeing my data" surprise.** Application reads from replica immediately after write; replica hasn't caught up; gets old data. Surprised support tickets. Fix: stickiness or primary reads.
- **The synchronous replication availability hit.** Sync replication configured for HA; one replica's network hiccups; primary refuses to commit. Production halts. Mitigation: timeout to drop slow replicas; or multiple sync candidates with quorum-style logic.
- **The schema change cascade.** DDL on primary; replicas must apply same DDL. If not coordinated (different versions, online vs offline DDL), replicas fall behind dramatically.
- **The logical replication slot growth.** A logical replication consumer is paused; primary's WAL grows because it can't be cleaned up. Disk fills. Production halts.
- **The cross-region failover that hadn't been tested.** First time exercising it: discovers a configuration bug. RTO (recovery time objective) wildly exceeded. Lesson: test failover regularly.

---

## Failure Scenarios 🔴

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

## Performance Perspective 🟡

- **Async replication**: minimal write latency overhead; replica processing is asynchronous.
- **Sync replication**: latency = primary commit + slowest sync replica RTT.
- **Read replicas**: read scalability scales linearly with replica count, until network or coordination overhead limits.
- **Lag impact**: lag is bandwidth-limited; high write rate = high lag possibility.

---

## Scaling Perspective 🟡

- **Vertical**: bigger primary handles more writes.
- **Read scaling**: add replicas; trivial.
- **Write scaling**: requires sharding; replication is per-shard.
- **Geographic**: cross-region async typical; cross-region sync expensive.
- **At hyperscale**: multi-shard, multi-region, with consensus per shard (Spanner, Cockroach).

---

## Cross-Domain Connections 🔴

- **CAP**: replication strategy determines CAP position. (See [cap-consistency-and-replication.md](../distributed-systems/cap-consistency-and-replication.md).)
- **WAL**: physical replication is WAL streaming. (See [wal-and-crash-recovery.md](./wal-and-crash-recovery.md).)
- **Consensus**: synchronous replication often uses consensus for failover. (See [leader-election-and-consensus.md](../distributed-systems/leader-election-and-consensus.md).)
- **MVCC**: replicas serve consistent snapshots; vacuum interacts with replication. (See [mvcc-and-isolation-levels.md](./mvcc-and-isolation-levels.md).)
- **Sharding**: replication and sharding compose; replica sets per shard. (See [sharding-and-partitioning-strategies.md](../scalability/sharding-and-partitioning-strategies.md).)
- **Disaster recovery**: replication is the foundation of DR (Disaster Recovery). (See [disaster-recovery-and-rto-rpo.md](../system-failures/disaster-recovery-and-rto-rpo.md).)

The unifying observation: **replication is the bridge between durability (one machine) and availability (many machines). Every choice in the strategy maps to a specific position in the consistency-latency-availability space.**

---

## Real Production Scenarios 🟡

- **Postgres streaming replication**: industry standard for HA Postgres. Documented operational practices.
- **MySQL group replication**: more recent multi-leader. Public adoption stories.
- **Cassandra at Netflix**: large-scale leaderless replication. Public engineering.
- **Spanner's TrueTime + Paxos**: documented design.
- **Aurora's storage-decoupled architecture**: published papers.
- **Discord's database evolution**: from MongoDB to Cassandra to ScyllaDB; replication choices documented.

---

## Key Takeaways

- **Sync vs async is the central trade-off.** Sync: write isn't done until replicas confirm — strong durability, latency cost, and an availability trade-off (if a sync replica is down, can you still commit?). Async: write completes locally and replicas catch up — low latency, but a data-loss window equal to replication lag on primary failure.
- **Read replicas scale reads, not writes.** Adding replicas helps a read-bound bottleneck only; write scaling requires sharding (replication is per-shard). Easy to misdiagnose.
- **Lag is a first-class concern.** Async replicas always trail the primary; reading a lagged replica returns stale data. Every async-replicated system needs continuous lag monitoring (bytes-behind and time-behind).
- **Failover is a separate problem from replication.** Replication ships data; failover decides what to do when the primary fails. Different failure modes; one can work without the other. Test failover regularly (monthly) and document failover runbooks — untested cross-region failover blows your RTO.
- **The consistency model is what your application sees.** Code that assumes strong consistency on eventually-consistent replicas will have bugs. Plan stickiness or explicit primary reads for read-after-write consistency.
- **Split-brain is catastrophic.** A partition that promotes two primaries diverges data on the same keys; recovery is manual and lossy. Prevent with consensus-backed failover — never auto-promote without quorum.
- **Multi-leader is operationally complex.** Performance is good; correctness (conflict resolution: LWW, per-field merge, app callbacks, CRDTs) and coordinated schema changes are the hard parts.
- **Quorum (W + R > N)** gives leaderless reads that see the latest write under non-failure conditions; W and R are tunable consistency knobs.
- **Logical vs physical replication is a granularity choice.** Physical: byte-level WAL/binlog, same version, whole cluster, fast HA. Logical: row-level changes, cross-version, selective tables, powers CDC. Watch logical replication slots — a paused consumer pins WAL and can fill the disk.
- **Isolate read replicas** from the primary's vacuum needs (`hot_standby_feedback` can pin WAL), and treat replication as a foundational part of disaster recovery.

> **Mental model: replication is how you make data available somewhere it isn't already. The strategy determines what "somewhere" means — a hot standby (sync), a slightly-delayed read replica (async), a peer that can also accept writes (multi-leader), or a quorum of equals (leaderless). Each model has a workload that fits, chosen against consistency requirements, latency budget, operational maturity, geographic distribution, and failure tolerance.**

---

## Interview Angle 🟡

What gets tested:

1. **"Sync vs async replication?"** The fundamental trade-off.
2. **"How does Postgres streaming replication work?"** Practical knowledge (WAL streaming to replicas; `synchronous_commit`, `synchronous_standby_names`).
3. **"What's split-brain?"** Two primaries; data divergence.
4. **"What's read-after-write consistency?"** Stickiness; primary reads.
5. **"Multi-leader's challenges?"** Conflict resolution; operational complexity.
6. **"How do quorum reads work?"** R + W > N.
7. **"What's logical vs physical replication?"** Logical: row-level; physical: byte-level.

Common traps: believing replicas auto-scale writes; underestimating lag impact; not knowing about split-brain.
