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
