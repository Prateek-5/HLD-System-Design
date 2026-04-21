# Database Replication

> **📎 Prereqs** — If rusty:
> - [`databases.md`](databases.md) — ACID basics.
> - [`learn/data/acid-base.md`](../learn/data/acid-base.md), [`learn/data/cap-theorem.md`](../learn/data/cap-theorem.md).
> - WAL (Write-Ahead Log) concept.

### 🔹 1. What This Topic Actually Is
Keeping multiple copies of data on different nodes. Core lever for read scaling, HA, and geo distribution.

### 🔹 2. Why It Exists
- Single node: SPOF + read ceiling.
- Replication gives HA (failover), read scaling (replicas serve reads), geo locality (regional replicas), and backup source.

### 🔹 3. Core Concepts (High Signal)
- **Primary-replica (master-slave)**: one writer, many readers. Default for SQL.
- **Primary-primary**: multiple writers; must resolve conflicts. Rare; hard.
- **Sync vs async**: sync = no data loss on primary crash, higher write latency. Async = fast, risk of lost writes.
- **Semi-sync**: at least one replica must ack. Good middle ground.
- **Replication lag**: replicas are behind primary by ms to seconds. Causes **read-after-write** anomalies.
- **Logical vs physical**: physical = WAL shipping (byte-level). Logical = row/column changes. Logical more flexible (cross-version, CDC, selective replication).
- **Change Data Capture (CDC)**: read the WAL/oplog and publish changes to a stream (Kafka). **Debezium** and **Netflix DBLog** are the canonical tools. Enables event-driven sync to caches, search indexes, warehouses without dual-writes.

> **❓ What CDC *actually does* under the hood:**
> 1. DB already writes every change to a WAL (for crash recovery). That log is **free, accurate, ordered**.
> 2. A connector (Debezium) connects to the DB as a "replica" and tails the WAL.
> 3. Each row change → a structured event `{op: UPDATE, before: {...}, after: {...}, ts: ...}`.
> 4. Connector publishes to a Kafka topic (often one topic per table).
> 5. Downstream consumers (Elasticsearch, warehouse, cache invalidator) react.
>
> The win: the DB is the single source of truth; downstream systems *derive* their state from the event stream. No dual-writes → no dual-write race conditions.

> **🧱 Primary vs replica — who knows what**
> Primary: latest writes, unacked in-flight transactions, all active clients.
> Replica: everything primary has committed *and* successfully replicated. **Lag window**: replica does NOT know about writes from the last N ms. Critical-path reads must go to primary.

> **🧠 What if async replication didn't exist (only sync)?**
> Every write would pay cross-AZ or cross-region RTT before ack. A write to a US-EU replica pair would cost ~100ms per write. Throughput drops to the point most systems couldn't meet latency targets. Async exists because latency matters — we accept a small data-loss window on primary failure.

### 🔹 4. Internal Working
**Primary write:** client → primary commits to WAL → fsync → ack → WAL streamed to replicas → replicas apply → replicas now current (with lag).
**Failover:** detect primary down (health check quorum) → promote replica (smallest-lag one) → redirect clients (DNS / proxy reconfigure) → old primary rejoins as replica after recovery.
**CDC:** external process tails WAL → transforms records into topic events → consumers build derived state.
**Failure points:** split brain (two primaries), losing writes on async replica, slow replicas lagging unbounded, failover routing stale clients.

### 🔹 5. Key Tradeoffs
- Sync replication: correctness, latency cost.
- Async replication: speed, risk of loss.
- Read-from-replica: scale reads, but stale reads possible. Route critical-read paths to primary.
- Multi-master: last-write-wins (loses data) vs CRDT (complex).

### 🔹 6. Interview Questions
**Beginner**
1. Why replicate?
2. What's replication lag?

**Intermediate**
1. Read-after-write — how to guarantee it with replicas?
2. Compare physical vs logical replication.

**Advanced**
1. Design failover with zero data loss and <1 min RTO.
2. What's the outbox pattern and why does it solve dual-write?

### 🔹 7. Real System Mapping
- **Postgres streaming replication** (physical), **logical replication** (since v10).
- **MySQL row-based replication** + GTIDs.
- **AWS Aurora**: log-structured shared storage; 6-copy across 3 AZs; replicas read from log.
- **Netflix DBLog**: generic CDC framework.
- **LinkedIn Databus**: pioneered CDC for data infra.
- **Uber LedgerStore**: trillions of indexes, all kept in sync via async replication + strong durability.

### 🔹 8. What Most People Miss
- **Failover is usually how you lose data** — async replica misses recent writes. Sync replication + Raft/Paxos needed for zero-RPO.
- **Read-your-writes** via session stickiness OR "route to primary for N seconds after a write".
- **The outbox pattern** solves the "write to DB and to Kafka" dual-write problem: write both in one local tx, relay publishes to Kafka from the outbox table. Without it, you lose or duplicate events.
- **Replica promotion isn't magic** — choose correct replica, stop streaming, update topology, re-point app config, drain old primary. Document + practice.
- **Log compaction** in some systems (Kafka with `compact` policy) replaces updates in place — different from DB WAL compaction.

### 🔹 9. 30-Second Revision
Primary-replica is default. Async = fast + lossy; sync = safe + slow. Lag causes read-after-write issues — route critical reads to primary or stick session. CDC = tail WAL, publish events. Outbox pattern avoids dual-write hell. Failover ≠ free (practice it).

---

## 🔗 Cross-Topic Connections
- **Databases**: replication is a property of every real DB.
- **Messaging**: CDC + Kafka is the glue between DBs and downstream.
- **Caching**: replicas feed read caches; CDC invalidates them.
- **Consensus**: multi-region primary elections need Raft/Paxos to avoid split brain.

---

### Confidence Check
- [ ] Can I describe async vs sync tradeoffs in one breath?
- [ ] Can I design a failover procedure + explain data-loss risk?

### Gaps
- Aurora's log-structured storage details.
- Spanner/CockroachDB synchronous commit.
- Real CDC at >100k events/s operational cost.
