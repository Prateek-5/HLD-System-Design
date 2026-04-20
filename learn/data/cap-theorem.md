# CAP Theorem — Pick Two (But Really, P is Free)

## A. Intuition First
In a distributed system, if the network partitions (nodes can't talk), you must choose: **keep serving stale/divergent data (AP)** or **reject requests to stay consistent (CP)**.

You can never actually "give up P" — partitions happen on any real network. So CAP is really about what you do *when* a partition happens.

## B. Mental Model
- **C (Consistency)**: every read sees the latest write (linearizable).
- **A (Availability)**: every request receives a (non-error) response.
- **P (Partition tolerance)**: the system continues despite message loss.

> **❓ What's a "partition", concretely? And why is P often treated as "not optional"?**
>
> **The problem:** two nodes of your cluster may lose the ability to talk to each other — not because they crashed, but because the *network between them* broke. Reasons: switch fails, fiber cut, misconfigured firewall, transient flap, one AZ's cross-link goes down. Each half is alive, but they can't hear each other.
>
> **Intuition — the "bad phone line" analogy:** Alice and Bob are both at their desks. But the phone line between their desks is dead. Each thinks the other is unresponsive and has to decide: *(a)* keep making decisions alone (risk disagreement later), or *(b)* stop until the line works again (safe but unresponsive).
>
> **Why it's "not optional":** on *any real network*, partitions eventually happen. Fiber gets cut. A misconfigured iptables rule blocks traffic. A cloud provider's AZ-to-AZ link dips. The question is never "if" but "when" — so every distributed system must choose its behavior *during* a partition. That's why "pick C or A" in CAP is the real decision — P is the pre-condition.
>
> **The fallacy of "CA":** engineers sometimes say "my system is CA — consistent + available". That's only true when the network *never* fails. On a single machine, sure. Across a real network, never. Any multi-node "CA" claim is marketing.
>
> **🔄 Micro reinforcement**:
> 1. *Recall*: what causes a real-world partition? *(Network link/switch failure, misconfigured firewall, AZ-to-AZ outage.)*
> 2. *Recall*: why can't a true distributed system be "CA"? *(Because partitions will happen, and during one you must pick C or A.)*
> 3. *What if* you told CAP you'd use a super-reliable network and pick CA? *(You've defined away P; at the first real partition, your system behaves undefined — losing data or going down entirely.)*

Classic triangle: pick any two. In practice, P is required; pick C or A under partition.

## C. Internal Working

### 🪜 Concrete partition scenario (the one example that makes CAP click)

Bank account balance. 3 nodes: A, B, C. Alice's balance is $100, replicated to all 3.

1. **T=0s** — network partition: A is isolated; B+C can still talk.
2. **T=1s** — Alice (connected to A) tries to withdraw $80.
3. **T=1s** — simultaneously, Bob (Alice's spouse, connected to B) tries to withdraw $80 too.
4. **What happens?**
   - **CP choice** (MongoDB, HBase): only the majority side (B+C) accepts writes. A refuses Alice's request with an error. Bob's withdrawal succeeds on B+C. Alice is told to try later. ✅ Consistent, ❌ partially unavailable.
   - **AP choice** (Cassandra default): both A and B accept their respective $80 withdrawals. Balance now shows $20 on A, $20 on B+C. At T=10s when partition heals, you have a conflict — both sides think $20 is correct but really the account is over-drawn. ✅ Available, ❌ inconsistent.

**The interview punchline**: CAP isn't a debate about which is "right". It's a *decision about what your app's data can tolerate*. Money → CP. Social feed likes → AP.

> **🧠 What if there were no partition?** Then you'd never need to choose — both C and A would hold. CAP is about the *failure mode*, not the steady state. (That's exactly what PACELC addresses.)

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
