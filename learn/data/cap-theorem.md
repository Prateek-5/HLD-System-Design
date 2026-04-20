# CAP Theorem — Pick Two (But Really, P is Free)

## A. Intuition First
In a distributed system, if the network partitions (nodes can't talk), you must choose: **keep serving stale/divergent data (AP)** or **reject requests to stay consistent (CP)**.

You can never actually "give up P" — partitions happen on any real network. So CAP is really about what you do *when* a partition happens.

## B. Mental Model
- **C (Consistency)**: every read sees the latest write (linearizable).
- **A (Availability)**: every request receives a (non-error) response.
- **P (Partition tolerance)**: the system continues despite message loss.

Classic triangle: pick any two. In practice, P is required; pick C or A under partition.

## C. Internal Working
### CP system behavior under partition
- Minority side refuses writes (and possibly reads) to preserve consistency.
- Majority side continues; upon partition heal, minority catches up.
- Example: MongoDB's default, HBase, etcd.

### AP system behavior under partition
- Both sides keep accepting reads/writes.
- Data diverges.
- On heal, reconcile via LWW, vector clocks, CRDTs, or app logic.
- Example: Cassandra, DynamoDB (default), Riak.

### CA systems
- Assume no partitions; give up when one happens. Single-node SQL is "CA" within itself.
- No real distributed system is CA — it's a marketing term at best.

## D. Visual Representation
```
                      C
                     /|\
                    / | \
                   /  X  \        ← single-node SQL
                  /  P(no)\
                 /_________\
                A           P
          (Cassandra)      (All real systems)
              (AP)          (MongoDB - CP)
```

## E. Tradeoffs
- CP: hard consistency, but availability drops during partitions.
- AP: always up, but stale/divergent data is possible.
- The choice should depend on the data:
  - Account balance → CP.
  - Shopping cart → AP with merge logic.
  - Likes counter → AP, eventual.

## F. Interview Lens
- "Is Cassandra AP or CP?" — default AP, but tunable per-query (CL=ALL → CP-like).
- "Is Postgres CP or AP?" — single-node → N/A; with async replication → AP on the replica side; sync replication → more CP.
- Pitfalls: claiming CA for a distributed system.

## G. Real-World Mapping
- **AP**: Cassandra, Riak, Couchbase (default).
- **CP**: MongoDB (default), HBase, etcd, ZooKeeper.
- **Tunable** (per-request): Cassandra, DynamoDB.

## H. Questions
**Beginner**: What are C, A, P?
**Intermediate**: Why is "CA" not really an option?
**Advanced**:
1. Design a system with CP for payments and AP for activity feed.
2. Explain CRDTs as a way to get convergence without coordination.

## I. Mini Design
Multi-region write system. CP: primary in one region, replicas in others, writes always go to primary. AP: per-region writes with async replication + CRDT merges. Pick based on correctness requirements.

## J. Cross-Topic Connections
- [PACELC](pacelc-theorem.md) — adds latency.
- [Replication](database-replication.md), [ACID/BASE](acid-base.md), [Transactions](transactions.md).

## K. Confidence Checklist
- [ ] Can explain choice under partition.
- [ ] Knows CAP-ness is often per-query, not per-DB.

### Red flags
- ❌ Treating "pick two" as dogma.
- ❌ Ignoring that P is effectively required.

## L. Potential Gaps & Improvements
- CRDTs deserve a standalone section.
- Linearizability vs eventual — more formal coverage.
- Jepsen findings on real DBs (Aphyr) — great reading.
