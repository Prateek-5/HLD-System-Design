# CAP, Consistency Models & Replication

> *"There is no such thing as a distributed system that's always available, always consistent, and tolerant of network failures. There are only systems that have decided which two of those they're willing to ship to production, and which one they're going to lie to themselves about."*

---

## Topic Overview

You can't talk about distributed databases for ten minutes without someone mentioning CAP. You also can't talk about CAP for ten minutes without someone misquoting it. The theorem is simple, profound, and almost always cited at the wrong moment by people who haven't internalized what it actually says.

The deeper truth: distributed systems are not about choosing two of three letters. They're about **making a contract with your application about what it sees during failures**, and that contract is the *consistency model*. CAP is the impossibility result that frames the conversation. Consistency models are the menu. Replication and consensus are the machinery.

This is the topic where databases, networks, and distributed systems collapse into one body of theory. It's also the topic where the gap between "I read a blog post about CAP" and "I have shipped a globally-replicated system that didn't lose money" is widest.

---

## Intuition Before Definitions

Three nodes hold a copy of your bank balance. You have $100.

- You deposit $50 in New York. Node A updates to $150.
- The link between New York and Frankfurt drops. Node A can't tell Node C anything.
- You log in from Frankfurt and ask: "what's my balance?"

The system has three options:

1. **Show you $100** (the value Node C has). You're confused, but the system answered immediately. **Available, not consistent.**
2. **Refuse to answer until the network heals.** Eventually you get the right answer. **Consistent, not available.**
3. **Pretend the network is fine and risk both.** This is what bad systems do. They pretend partitions don't exist until they do.

That's the trilemma. In a partitioned network, you must choose: serve a possibly-stale answer, or refuse to answer.

Now stretch the picture: 50 nodes, geographic distribution, varying latency, partial partitions where some nodes can talk to some others. The "two clean choices" of CAP are an oversimplification of a continuous landscape of tradeoffs. That landscape is the world senior distributed systems engineers actually live in.

---

## Historical Evolution

**Era 1 — Single-master replication.**
Postgres, MySQL pre-2010: one primary, N read replicas. Writes go to the primary. Replicas trail asynchronously. Strong consistency on the primary, eventual consistency on replicas. The whole architecture is built around a single point of write coordination — and a single point of failure.

**Era 2 — Synchronous replication and the latency tax.**
"Just make replication synchronous!" Each write waits for replicas to ack. Now your write latency = network latency to the slowest replica. Cross-continent? 100ms+ on every write. The cure becomes worse than the disease.

**Era 3 — Eventual consistency at scale.**
Amazon Dynamo (2007), Cassandra, Riak. Drop strong consistency entirely. Multi-master, write to any replica, anti-entropy converges later. Massive write throughput. Application-level pain — concurrent writes can conflict, and the application now has to think about *vector clocks*, *last-write-wins*, *CRDTs*. The problem moved up the stack.

**Era 4 — Consensus protocols mature.**
Paxos was published in 1989; nobody understood it. Raft (2013) made consensus comprehensible. ZooKeeper, etcd, Consul ship. Suddenly *strong consistency on a small subset of state* (configuration, leadership) is a primitive engineers can build on.

**Era 5 — NewSQL and global consistency.**
Spanner (2012, paper 2013) cracked the global-consistency-at-scale problem with TrueTime — atomic clocks plus GPS in every datacenter. CockroachDB, FoundationDB, YugabyteDB followed without TrueTime, using HLCs (hybrid logical clocks) and clever protocols. Strong consistency at planet scale, at the cost of latency and operational complexity.

**Era 6 — The "right tool for the job" era.**
Modern architectures use multiple consistency models in one system. Consensus for metadata; eventual consistency for high-volume write paths; strong consistency for financial transactions; CRDTs for collaborative editing. The single-model database is a museum piece for serious infrastructure.

---

## Core Mental Models

**1. CAP is about partitions specifically.**
The "you must give up A or C" choice only applies *during a network partition*. When the network is healthy, you can have all three. The interesting design question is "what happens during a partition?" — not "what do I optimize for in steady state?"

**2. Consistency is a continuum, not a binary.**
Linearizable > sequential > causal > eventual > none. Each step down is a small lie about reality in exchange for a real performance gain. Pick the strongest consistency you can afford for the values you're storing. Stronger consistency for money; weaker for likes.

**3. Replication is a copy problem; consensus is an agreement problem.**
You can replicate without consensus (async streaming). You can have consensus without classical replication (single-leader systems use it for leader election). The two compose into the systems we actually ship.

**4. Latency is the tax on consistency.**
Every consistency guarantee costs round trips. Synchronous replication = 1 RTT to replicas. Quorum reads/writes = depends on quorum size. Linearizability = at least 1 RTT to the leader. There is no consistency model that's both strong and free of latency.

**5. The clock problem is at the heart of everything.**
"Did A happen before B?" is the question every distributed system spends its life answering. Physical clocks drift. Logical clocks (Lamport) lose causality. Vector clocks scale poorly. Hybrid clocks (HLCs), TrueTime, and consensus-derived ordering are all attempts to give a globally meaningful answer.

---

## Deep Technical Explanation

### CAP, precisely

**Brewer's CAP theorem (formally proven by Gilbert & Lynch, 2002):** In a distributed system that must tolerate network partitions, you cannot simultaneously guarantee linearizable consistency and full availability for *every* request.

Three terms with specific meanings:
- **Consistency (C in CAP):** linearizability. Every read sees the most recent write.
- **Availability (A in CAP):** every non-failing node responds successfully to every request.
- **Partition tolerance (P):** the system continues operating despite messages being lost between nodes.

The "choose 2 of 3" framing is misleading. **P is not optional in real systems** — partitions happen. So the real choice is C-or-A *during a partition*. The "CA" point on the triangle is largely fictional in a multi-machine system.

### PACELC — the better framing

Daniel Abadi's refinement (2010):
- **If Partition: A or C?**
- **Else: Latency or Consistency?**

Now you have a 2×2: PA/EL, PA/EC, PC/EL, PC/EC. Real systems are characterized by both halves:
- DynamoDB: PA/EL — favors availability under partition, favors latency at all times.
- Spanner: PC/EC — strong consistency, both during partitions and in steady state.
- Cassandra: PA/EL by default; tunable.
- HBase: PC/EC.

PACELC is what you want to actually use when designing a system, because it acknowledges that consistency-vs-latency is a *steady-state* tradeoff too — partitions are just the dramatic case.

### Consistency models, from strongest to weakest

| Model | Guarantee | Cost |
|---|---|---|
| **Linearizable** | Reads see most recent write, in real time order | Coordination per operation; high latency |
| **Sequential** | All processes see operations in same order; not necessarily real-time | Slightly cheaper; hard to reason about |
| **Causal** | Causally related operations are seen in order; concurrent operations may differ | Coordination only on causal chains |
| **Read your writes** | A client sees its own writes | Per-client coordination |
| **Monotonic reads** | A client never sees data go backward in time | Sticky sessions or tracking |
| **Eventual** | All replicas converge eventually if writes stop | Cheapest; weakest |

The art is matching the model to the value. Bank balance: linearizable. Profile picture: read-your-writes. View counter: eventual.

### Replication topologies

**Single-leader:**
- All writes go to one node; replicas catch up.
- Consistency: strong on the leader, eventual on replicas (unless sync replication).
- Failure mode: leader fails → who's the new leader? (Consensus needed.)

**Multi-leader:**
- Multiple nodes accept writes; they replicate to each other.
- Consistency: needs conflict resolution (LWW, CRDTs, application logic).
- Failure mode: concurrent writes on different leaders create conflicts.

**Leaderless (Dynamo-style):**
- Any node accepts any write; replicates to N replicas; reads consult R replicas; writes ack from W replicas.
- If R + W > N: strong consistency under failures (mostly).
- Read repair and anti-entropy converge divergent state.

The choice maps directly to consistency model: leader-based systems naturally provide stronger consistency at the cost of write availability under partition.

### Consensus — the machinery

**Paxos and Raft solve:** "Given a set of nodes, agree on a single value, even if some nodes fail."

In practice:
- **Leader election** uses consensus to pick a unique leader.
- **Log replication** uses consensus to agree on the order of operations.
- A consensus round needs a majority quorum: in a 5-node cluster, 3 must agree. This is why **odd-numbered cluster sizes** are standard (3, 5, 7) — you can't have a majority of an even number.

**Raft's contribution:** decomposed Paxos into "leader election + log replication + safety" with clear phase boundaries. The papers are readable. The implementations are still hard.

**FLP impossibility result (1985):** in a fully asynchronous system with even one faulty process, no deterministic consensus algorithm can guarantee progress. Real systems sidestep this with timeouts and randomized protocols — accepting "almost always" liveness.

### Quorum reads and writes (Dynamo-style)

Three numbers:
- **N**: replicas per key.
- **W**: write acks required.
- **R**: read acks required.

Properties:
- **W + R > N** ⇒ overlapping read/write quorums ⇒ a read sees the latest write (strong-ish consistency, modulo replica failures).
- **W = N**: maximum durability, fragile availability.
- **W = 1, R = 1**: maximum availability, weakest consistency.
- **W = quorum, R = quorum** is the common balanced choice.

Cassandra's `QUORUM` consistency level is exactly this: W = R = ⌈(N+1)/2⌉.

### CRDTs — eventual consistency without conflicts

Conflict-free Replicated Data Types: data structures designed so that *any* sequence of merges produces the same result.

- **G-Counter** (grow-only counter): each node maintains its own counter; merge takes the max per node; total is the sum. Increment-only; no conflict possible.
- **OR-Set**: tag each insert/delete with a unique ID; merges are union/intersection over tags.
- **LWW-Element-Set**: each operation tagged with timestamp; last write wins.

Used in: Riak, Redis (some types), collaborative editing (Yjs, Automerge), Figma, Linear, AWS DynamoDB Streams patterns. Where the math works, CRDTs eliminate the conflict-resolution problem entirely.

### Time and ordering

- **Lamport clocks**: each node has a counter; events get a (counter, node) timestamp; counters update on receive. Provides a total order *consistent with causality*. Doesn't capture concurrency.
- **Vector clocks**: each node carries a vector of all node counters; can distinguish concurrent from causally ordered events. Doesn't scale — vector size = number of nodes ever seen.
- **HLC (Hybrid Logical Clocks)**: combine physical time with logical counter; bounded skew if physical clocks are bounded.
- **TrueTime (Spanner)**: GPS + atomic clocks in every datacenter give a globally-bounded uncertainty interval; system waits out the interval to ensure no real-time inversion. Hardware-dependent; the secret sauce of Spanner.

Whoever owns the clock owns the consistency story.

---

## Real Engineering Analogies

**The orchestra without a conductor.**
A symphony with one conductor (single leader) — everyone plays at the same tempo, but if the conductor falls, the music stops. A jam session (multi-leader, eventual consistency) — everyone improvises and the music *mostly* works, but occasional discords need to be resolved later. A military band (consensus) — everyone watches everyone else and synchronizes through agreed-upon signals; works without a single conductor but has overhead in coordination.

**The branch office analogy.**
A bank with branches. The headquarters has the master ledger. Branches have local copies. A wire transfer from one branch to another:
- Synchronous replication = the cashier waits for HQ confirmation before handing you the receipt. Slow.
- Asynchronous replication = the cashier hands the receipt immediately, syncs later. Fast, but you might walk out, the link drops, and the transfer fails.
- Two-phase commit = the cashier holds the funds while HQ checks; if HQ doesn't respond, the funds are stuck. Reliable but blocking.
- Saga pattern = a series of local transactions, each with a compensating action if a later step fails. Eventual consistency, application-managed.

This is a real pattern in financial systems. The choices have names like "synchronous gross settlement" vs "deferred net settlement," but they map to the same underlying tradeoffs.

---

## Production Engineering Perspective

What actually breaks in distributed systems:

- **Partial partitions.** The textbook diagram is "two halves of the cluster can't talk." Reality: node A can talk to B but not C; B can talk to A and C; C can talk to B but not A. Half the consensus protocols you read about become hostile under partial partitions. (Jepsen tests reveal this routinely.)
- **Network is not eventual; it's adversarial.** Packet loss, reordering, duplication, asymmetric latency, full corruption. Anything you assume the network won't do, it will eventually.
- **Clock skew is real and dangerous.** A node with a fast clock can claim writes are "newer" than they are, winning LWW conflicts unfairly. Default clock-sync (NTP) is precise to ~10ms; not precise enough for fine-grained ordering.
- **Replication lag is invisible until it's a 4-hour outage.** A read replica falls behind by hours; nobody notices because the metric isn't dashboarded; an admin promotes the replica during failover; data loss.
- **Quorum sizing under failures.** If you tune for `R+W > N` and one node is down, your quorum requirements may not be satisfiable. The system goes from "available" to "throwing errors" silently.
- **Split-brain.** Two leaders, both accepting writes, both convinced they're the only leader. Recovery is a manual diff-and-merge. This is the operational nightmare of multi-leader replication done wrong.
- **The "I'll just add a new datacenter" surprise.** Quorums become harder. Consensus latency goes up. Application timeouts that worked locally fail across regions.

The senior operator's habits:
- Run **Jepsen tests** (or read them) for any system you depend on.
- Monitor **replication lag** as a primary metric.
- Track **clock skew** between nodes.
- Test failover regularly. Untested failover is broken failover.
- Document the **consistency model your application assumes** and audit against it.

---

## Failure Scenarios

**Scenario 1 — Split-brain at 3am.**
A network partition isolates the primary in MySQL replication. Failover script promotes a replica. Network heals. Now there are two primaries with diverging data. Resolution: a 12-hour manual data reconciliation, plus a partial customer refund.

**Scenario 2 — The eventual consistency surprise.**
A user updates their profile on the West Coast. Reads it back from an East Coast replica before replication catches up. Sees old data. Files a support ticket. Engineering "can't reproduce" because their dev environment uses a single replica. The bug only manifests under load and geography.

**Scenario 3 — The consensus-cluster size disaster.**
A 4-node etcd cluster (someone added a fourth node "for capacity"). Loses 2 nodes. Quorum is 3. The cluster cannot make progress. Every write hangs. Kubernetes API stops responding. Cascading failure across hundreds of services. Lesson: keep consensus clusters odd-sized.

**Scenario 4 — The clock-skew financial bug.**
Two transactions on different nodes; LWW based on wall clocks. One node's clock is 50ms ahead. The "earlier" transaction wins the conflict. A customer is double-charged. Fixed by switching to HLCs and adding clock-skew monitoring with paging thresholds.

**Scenario 5 — The Jepsen finding.**
A distributed database advertises "linearizable consistency." A Jepsen test under partial partitions discovers stale reads. The database team patches the bug, but in the meantime, every customer who built on the linearizability guarantee has potential silent corruption.

---

## Performance Perspective

- **Latency is paid in round trips.** Each consistency level costs a specific number of RTTs. Linearizable read = at least 1 RTT to leader. Quorum write = 1 RTT to quorum size. Multi-region write = inter-region RTT (typically 50–150ms).
- **Throughput is bounded by the slowest replica** in synchronous replication; the *coordinator* in single-leader; the *quorum* in Dynamo-style.
- **Read scalability** is straightforward via replicas; **write scalability** is the hard problem. Sharding is the usual answer.
- **Consensus has a per-operation lower bound** of 1 RTT to a quorum. Scaling consensus often means partitioning *the consensus group itself* (Raft groups per shard).
- **Network is the bottleneck**, not CPU or disk, in well-tuned distributed systems. Optimize for batch-and-pipeline, not parallelism within a node.

---

## Scaling Perspective

- **Vertical:** add bigger nodes. Helps until coordination overhead dominates.
- **Horizontal reads:** trivial via replicas.
- **Horizontal writes:** sharding. Each shard's consistency is local; cross-shard transactions require 2PC, sagas, or weaker guarantees.
- **Geographic scale:** different consistency choices per region. Strong locally, eventual across regions, with explicit conflict resolution.
- **Operational scale:** as the cluster grows, the probability of *some* node being down at any moment approaches 1. Design for this.

The hardest scaling jump is **regional → global**. Latency goes from sub-ms to 100+ms. The consistency models you could afford locally become unaffordable. Either you accept eventual consistency, or you pay the latency tax (Spanner, CockroachDB), or you design *boundaries* in your data — some data is strongly consistent within a region, eventually consistent across.

---

## Cross-Domain Connections

- **MVCC:** snapshot isolation is the single-node ancestor of distributed consistency. Linearizability ≈ "real-time + serializable." The same anomalies (stale reads, write skew) generalize to distributed settings.
- **Caching:** every cache is a small distributed system with its own consistency model. Cache invalidation is Phil Karlton's hardest problem because it's *distributed consistency in disguise*.
- **Event loop:** within a process, the single-threaded event loop gives you trivial linearizability — no two operations interleave. Distribution is the act of giving up that property.
- **Filesystems:** distributed filesystems (HDFS, Ceph, GFS) are entire distributed systems with their own CAP positions. Same theory, file-shaped.
- **Networking:** TCP is a "consistency model" for a byte stream — ordered, no gaps, eventually delivered. UDP is "eventual" or worse. Application protocols layer on top.
- **OS scheduling:** SMP scheduling deals with cache coherence (MESI protocol), which is essentially a hardware-level eventual consistency problem. The same theory recurs at the silicon layer.

The unifying observation: **consistency is the price of replication, replication is the price of availability, and availability is the price of partition tolerance.** The same triangle keeps appearing because it reflects a fundamental property of information systems with state and physical separation.

---

## Real Production Scenarios

- **GitHub's MySQL split-brain (2018):** a network glitch + Orchestrator failover + replication topology changes ⇒ 24 hours of data inconsistency. A textbook case of how multi-leader replication's pathologies manifest at scale.
- **Cloudflare's Postgres replica lag during AWS region issues:** documented postmortems of read replicas falling behind under write surges, surfacing the eventual-consistency-as-bug class.
- **Spanner's TrueTime in production:** Google publicized that they wait out the uncertainty interval (~7ms typical) before committing. The latency cost is real and visible in the design.
- **Cassandra's "consistency level" knob:** every Cassandra deployment has a story about choosing the wrong level — usually `ONE` for performance, then discovering that quorum reads under failures still see stale data.
- **etcd's quorum-loss cascading failures in Kubernetes:** documented across multiple major outages where etcd cluster issues took down entire Kubernetes control planes.
- **Jepsen's series of analyses** (Kyle Kingsbury): reading these is the closest thing to graduate-school distributed systems education available outside academia. Cassandra, MongoDB, Riak, FoundationDB, CockroachDB — all have been tested, all have been found wanting at some point, all have improved as a result.

---

## What Junior Engineers Usually Miss

- That **CAP isn't a steady-state choice** — it only applies during partitions.
- That **eventual consistency is not a synonym for "broken"** — it's a contract, with specific semantics, and applications can be designed for it.
- That **synchronous replication isn't a free upgrade** to single-leader async — it can multiply write latency by 10× and reduce write availability to the AND of all replicas.
- That **even-numbered consensus clusters are an anti-pattern**.
- That **clock-based ordering is fragile** and silently wrong under skew.
- That **multi-leader without conflict resolution is split-brain waiting to happen**.
- That **reads from replicas can be stale**, even on systems advertising "strong consistency on the primary."

---

## What Senior Engineers Instinctively Notice

- They classify systems by **PACELC**, not CAP.
- They ask **"what's the consistency model?"** before "what database is this?"
- They check **replication lag dashboards** as part of routine health monitoring.
- They **never run consensus clusters with even node counts** without knowing exactly why they're doing it.
- They reach for **CRDTs or sagas** when 2PC is the obvious-but-wrong answer.
- They know which **operations cross consistency boundaries** in their system and design retry/idempotency accordingly.
- They **read Jepsen reports** before adopting a database.
- They distinguish **failover automation that's been tested** from failover automation that exists in a wiki.

---

## Interview Perspective

What gets tested:

1. **"Explain CAP."** Mid-level: states A, C, P. Senior: explains it only applies under partition, mentions PACELC, names systems on each side.
2. **"How does Raft work?"** Senior candidates explain leader election, log replication, and the safety property (committed entries are never lost). They mention the role of quorums and the cost of even-sized clusters.
3. **"Design a globally-distributed counter."** Tests whether the candidate reaches for CRDTs, accepts eventual consistency, or naively says "use a database transaction."
4. **"What is linearizability?"** Test: can the candidate distinguish it from sequential consistency? Bonus for explaining why linearizability is composable across objects but sequential is not.
5. **"Your replica is 30 minutes behind. What do you do?"** Tests operational instinct. Right answers: investigate why (long-running query? disk slow? network issue?), don't just promote it; check whether replication can catch up; consider whether the application is reading from the lagged replica.
6. **"Two-phase commit vs sagas?"** Senior reasoning: 2PC blocks resources and has a coordinator-failure problem; sagas are eventually consistent with explicit compensations. Pick based on whether you can tolerate intermediate inconsistency.

Common traps:
- Saying "we'll use synchronous replication" without noting the latency and availability cost.
- Confusing linearizability with serializability (related but distinct).
- Recommending eventual consistency for inherently transactional data.
- Not knowing that consensus is the foundation of "leader election."

---

## Worked Example — Designing the Consistency Model for an Inventory System

A multi-region e-commerce service tracking inventory. Multiple regions accept orders. Question: how to handle "is this item in stock?" when the answer changes constantly across regions.

### Naive design — globally synchronous

```
Order arrives in EU region:
  Lock global inventory row (cross-region, ~150ms RTT)
  Check stock; decrement; commit
  Unlock
```

Problem: every order pays 150ms of cross-region coordination. Throughput limited by the slowest replica. One region's failure stalls all orders globally.

### Better — eventual consistency with reservations

```
Each region maintains:
  inventory_local[item_id] = its allocated quantity
  reserved_local[item_id] = pending orders' reservations

Order arrives in EU region:
  if inventory_local[item_id] - reserved_local[item_id] > 0:
    reserved_local[item_id] += 1   // local; fast
    queue order for confirmation
    return "order accepted, awaiting confirmation"
  else:
    return "out of stock" (with possibility of allocation request)

Background: regional inventory is rebalanced periodically.
  Asynchronously redistribute global stock based on regional demand.
```

Properties:
- Order acceptance is fast (region-local).
- Most orders succeed immediately.
- Edge case: if regional stock gets exhausted before rebalance, "out of stock" returned even though other regions have stock.
- Mitigation: cross-region "allocation request" for low local stock.

### When stock is genuinely scarce — the right consistency

For the last 10 of an item, you want strong consistency:

```
if global_stock_for[item_id] < SCARCE_THRESHOLD:
  // Switch to consensus-backed atomic decrement
  consensus_group_for[item_id].atomic_decrement_if_positive()
else:
  // Use eventual consistency
  region_local_decrement()
```

This is **tunable consistency**: different consistency for different conditions. The architecture explicitly recognizes that one consistency model doesn't fit all scenarios within the same system.

### What this teaches

Real production systems don't pick "AP" or "CP" globally. They pick *per-operation* consistency:
- Bulk inventory: eventual.
- Last-units inventory: strong.
- Read access to product catalog: cached / eventual.
- Order placement: regional with reservation.
- Payment: strong (single region, transactional).

The CAP/PACELC framework guides each decision; the system as a whole exists across many points in the consistency space.

---

## Recent Production References (2023-2024)

- **Cloudflare's R2 object store**: published architecture documents. Strong consistency on metadata (consensus); eventual on data replication. PACELC: PC/EC for metadata; PA/EL for content.
- **CockroachDB Serverless (2022-2023)**: pay-per-request distributed SQL. Documented the trade-offs of multi-tenant isolation atop strongly-consistent infrastructure.
- **The 2023 GCP IAM outage**: a CP-system whose unavailability cascaded across services. Postmortem available.
- **DynamoDB Global Tables**: Amazon's pattern for multi-region eventual consistency with conflict resolution. Well-documented.
- **Discord's ScyllaDB migration (2023)**: tunable consistency in production at very high scale.
- **Spanner's external consistency**: continues to be the gold standard. Public engineering on TrueTime hardware.
- **The 2023 GitHub partial outage**: a network partition between regions exposed assumptions about consensus participants. Documented postmortem.

---

## Reference Architecture — Tunable Consistency

```
┌────────────────────────────────────────────────────────────────┐
│                    User-facing application                       │
└──────────────┬───────────────────────┬──────────────────────────┘
               │                        │
               ▼                        ▼
   ┌──────────────────┐    ┌────────────────────────┐
   │ Strong-consistency │    │ Eventually-consistent    │
   │ writes & reads     │    │ reads & async writes      │
   │                    │    │                            │
   │ - Payment          │    │ - Product catalog          │
   │ - Inventory < N    │    │ - Recommendations          │
   │ - User identity    │    │ - View counters            │
   │                    │    │ - User preferences         │
   └────────┬───────────┘    └──────────┬─────────────────┘
            │                            │
            ▼                            ▼
   ┌──────────────────┐    ┌─────────────────────────┐
   │ Consensus-backed   │    │ Multi-region async        │
   │ database           │    │ replicated cache          │
   │ (Spanner/Cockroach)│    │ (DynamoDB Global Tables)   │
   │                    │    │                            │
   │ Latency: 10-50ms   │    │ Latency: <5ms regional     │
   │ Throughput: bounded│    │ Throughput: very high      │
   │ by consensus       │    │                            │
   └────────────────────┘    └─────────────────────────┘
```

Most modern large-scale systems sit in this hybrid. The art is drawing the line correctly.

---

## 20% Knowledge Giving 80% Understanding

1. **CAP applies during partitions; PACELC adds the steady-state latency-vs-consistency tradeoff.**
2. **Consistency models form a hierarchy.** Pick the strongest you can afford for each piece of data.
3. **Replication is "copy"; consensus is "agree."** They compose.
4. **Quorums (R+W > N) give you strong-ish consistency in leaderless systems.**
5. **Consensus clusters must be odd-sized.** 3, 5, 7. Never 4.
6. **Eventual consistency is a contract, not a bug.** Design for it explicitly.
7. **CRDTs eliminate conflicts where the algebra works.**
8. **Clock-based ordering is fragile.** Use logical clocks (HLCs, vector clocks) for ordering that matters.
9. **Latency is the tax on consistency.** Every consistency level costs round trips.
10. **The hardest part is not the steady state — it's the partition behavior.** Test partitions explicitly.

---

## Final Mental Model

> **Distributed systems are not about computers talking to each other. They're about applications making promises about state in a world where messages get lost. The promise is the consistency model. The cost is the latency and complexity. The bug is what happens when the promise is louder than the implementation.**

Every design choice in distributed systems is downstream of a promise to the application. *"Your reads will see your writes." "Your transactions will be atomic globally." "Your counter will eventually be correct."* Each promise is a contract paid for in coordination.

The senior engineer doesn't pick "AP" or "CP" off a chart. They look at the data, decide what the application needs to be true, and pick the *cheapest* mechanism that delivers that truth. Money gets consensus. Likes get gossip. Profile pictures get last-write-wins.

That's distributed systems engineering. Everything else is implementation detail.
