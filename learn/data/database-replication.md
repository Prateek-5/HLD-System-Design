# Database Replication — Many Copies, One Truth

## A. Intuition First
Replication = keep more than one copy of the data, on different machines. Why? Read scale, fault tolerance, geographic latency, and disaster recovery.

## B. Mental Model
- **Primary-replica (master-slave)**: one writer, many readers.
- **Primary-primary (multi-master)**: multiple writers, must reconcile conflicts.
- **Sync vs async**: does the primary wait for the replica to ack before returning?

## C. Internal Working

### Primary-replica flow (async)
1. Client writes to primary.
2. Primary appends to its WAL, commits, responds OK.
3. WAL shipped to replica(s) asynchronously.
4. Replica applies WAL, becomes consistent (with lag).

### Sync replication
Same as above but step 2 also waits for at least one replica to ack. Durability ↑, latency ↑.

### Replication lag
The time between primary commit and replica catching up. Usually ms; can blow up under load or network hiccup. Causes "read-after-write" anomalies: you posted a comment but it's not visible when you refresh (you're reading from a lagged replica).

### 🪜 Read-after-write anomaly — the flow
1. **T=0ms** — User posts comment → hits primary → commit.
2. **T=5ms** — Primary acks.
3. **T=10ms** — User's browser auto-refreshes.
4. **T=12ms** — Refresh reads from a lagged replica which hasn't yet received the write.
5. **User sees empty comment list** and thinks the post failed. They post again.
6. **T=100ms** — Replica catches up. Now there are 2 duplicate comments. 😱

**Fixes** (in order of simplicity):
- Route the user's *own* reads to the primary for N seconds after their write (sticky-to-primary).
- Route all reads of the user's own session to one replica and wait for its lag.
- Client-side: keep the just-posted data in local state, merge on refresh.

> **🔎 Quick Check** — In 10 seconds: what metric do you alert on for replication health?
> **🎯 Recall** — Replication lag (seconds behind primary). Postgres: `pg_stat_replication.replay_lag`.

### Multi-master
Two+ writers. Must resolve conflicts:
- **Last-write-wins (LWW)**: simple, can lose data.
- **Vector clocks / CRDTs**: richer, more complex.
- **App-level resolution**: app decides.
Very hard to get right — most teams avoid.

## D. Visual Representation
```
     [Primary]  ──WAL──▶ [Replica 1]  ──WAL──▶ [Replica 2]
         │
         └──writes from clients
         
   reads can go to replicas (with lag)
```

## E. Tradeoffs
- **Primary-replica**: simple; SPOF on primary (until promotion); replicas can be taken offline.
- **Primary-primary**: always available for writes; conflict resolution is the devil.
- **Async** wins on latency/throughput; loses data on primary crash.
- **Sync** loses no data; pays RTT on every commit.

## F. Interview Lens
- "What's replication lag and why does it matter?" — stale reads.
- "Sync vs async — when do you pick which?" — banks lean sync; feeds lean async.
- "How do you fail over?" — promote replica, reconfigure clients, fix old primary.
- Pitfalls: reading from replica in read-after-write flows (post-comment-refresh).

## G. Real-World Mapping
- Postgres streaming replication (async / sync).
- MySQL async replication.
- AWS Aurora: log-structured shared storage, replicas read from same log.
- Cassandra: masterless, quorum-based; every node is a replica of some range.

## H. Questions
**Beginner**: Why replicate?
**Intermediate**: What is replication lag? When does it hurt?
**Advanced**:
1. Design primary failover: health check + promotion + client reconfiguration.
2. Why does Postgres not offer multi-master out of the box?

## I. Mini Design — "Handle replication lag after write"
User posts comment, navigates back → sometimes comment missing (read hit lagged replica).
Fixes:
- **Read-your-writes**: after a write, route reads for that user to primary for N seconds.
- **Session consistency**: stick the user to one replica (or primary) for a session.
- **Fetch from primary** for critical paths; replicas for everything else.

## J. Cross-Topic Connections
- [CAP](cap-theorem.md), [PACELC](pacelc-theorem.md), [Consistency models](acid-base.md), [Sharding](sharding.md), [Disaster Recovery](../reliability/disaster-recovery.md).

## K. Confidence Checklist
- [ ] Can explain primary-replica vs primary-primary.
- [ ] Knows replication lag and its effects.
- [ ] Can design a simple failover.

### Red flags
- ❌ Treating replicas as always up-to-date.
- ❌ Forgetting failover promotes data loss risk with async.

## L. Potential Gaps & Improvements
- CDC (Change Data Capture) via Debezium / Kafka Connect — missing.
- Quorum-based replication math (W+R>N) — belongs near CAP.
- Group replication / Paxos-based (Spanner, CockroachDB) — missing.

---

### 🧭 Guided Deep-Learning Layer

#### 🛰️ Gap 1 — CDC via Debezium / Kafka Connect
- 🔹 **What it is**: Framework for capturing database changes as a Kafka event stream in real time, by tailing the WAL/binlog.
- 🔹 **Why it matters**: Makes "sync DB to search index / cache / warehouse" trivial without dual-writes. Industry-standard for event-driven architectures.
- 🔹 **Connection**: This file introduces CDC conceptually. Debezium is *how* you deploy it. Kafka Connect is the generic framework hosting it.
- 🔹 **When needed**: 🔴 **Important for senior interviews** in data pipelines, event-driven microservices, search-index sync.
- 🔹 **Intuition**: Put a tap on the DB's internal change log. Everything flowing through it goes out as an event stream. The DB doesn't know or care.
- 🔹 **If you go deeper**: Read Debezium docs for Postgres (logical replication slot), MySQL (binlog), MongoDB (oplog). Understand at-least-once delivery + schema evolution concerns.
- 🔹 **Interview hook**: *"How do you keep Elasticsearch in sync with Postgres without dual-writes?"* → Debezium streams CDC events to Kafka → indexer consumer updates ES.

---

#### 📐 Gap 2 — Quorum-based Replication (W+R>N)
- 🔹 **What it is**: Configurable replication where writes need W acks and reads query R replicas. When W+R>N, reads always see the latest write.
- 🔹 **Why it matters**: Lets you tune per-query consistency vs latency. Default for Cassandra, DynamoDB, Riak, etc.
- 🔹 **Connection**: This file covers primary-replica replication; quorum is the next level — nobody is "the primary" per se, and reads/writes are voted.
- 🔹 **When needed**: 🔴 **Important for senior interviews** on NoSQL databases.
- 🔹 **Intuition**: A jury. Writes need W votes. Reads need R. If W+R>N (total jurors), every read jury includes at least one who saw the last write.
- 🔹 **If you go deeper**: Try N=3 W=2 R=2 (strong) vs N=3 W=1 R=1 (fastest, stale reads possible). Understand ONE, QUORUM, ALL levels in Cassandra.
- 🔹 **Interview hook**: *"In Cassandra with RF=3, when would you use CL=QUORUM vs CL=ONE?"* → QUORUM for critical reads needing consistency; ONE for speed-first workloads accepting staleness.

---

#### 🤝 Gap 3 — Paxos/Raft-based Replication (Spanner, CockroachDB)
- 🔹 **What it is**: Replication where every write requires majority consensus via Paxos or Raft. Guarantees linearizable writes + strong leader.
- 🔹 **Why it matters**: How true cross-region strong consistency works — Spanner (Paxos), CockroachDB (Raft), etcd (Raft). Not the usual primary-replica async.
- 🔹 **Connection**: Primary-replica is simple but has data-loss window. Consensus-replicated systems close that — at latency cost.
- 🔹 **When needed**: 🔴 **Important for senior infra interviews**.
- 🔹 **Intuition**: Every write requires a majority vote before being "committed". Crashes can't lose data (the majority persisted it) — but each write pays the vote RTT.
- 🔹 **If you go deeper**: Study how Spanner uses **TrueTime** (GPS + atomic clocks) to make Paxos-replicated writes globally serializable with minimal latency. Read the Spanner paper (2012).
- 🔹 **Interview hook**: *"How does Spanner provide global ACID transactions?"* → Paxos-replicated tablets + TrueTime for serializable ordering.

---

### 🏆 Start here if you have limited time

1. **CDC via Debezium** — practical, reusable, instant interview payoff.
2. **W+R>N math** — core interview question for NoSQL.

Paxos/Raft is foundational but already covered in `clustering.md` and distributed consensus files.

---

### 🧭 Suggested Deep Dive Order

1. **CDC via Debezium** (~1h; pragmatic value).
2. **W+R>N quorum math** (~30 min; interview staple).
3. **Raft/Paxos-based replication + Spanner's TrueTime** (~2–3h; senior infra depth).
