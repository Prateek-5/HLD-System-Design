# Leader Election & Consensus

> *"Consensus is the act of getting a group of computers to agree on a single fact, in a world where any of them can fail at any moment, the network can lie or partition, and even time itself is unreliable. The fact that we can do this at all is one of the quiet miracles of computer science."*

---

## Topic Overview

Consensus is the foundation primitive of distributed systems. Every system that needs to make a binding decision across multiple nodes — who's the leader? what's the order of operations? did this transaction commit? — eventually reduces to a consensus problem. Without it, "distributed" is just "multiple computers that disagree about reality."

The two algorithms that matter — **Paxos** (Lamport, 1989) and **Raft** (Ongaro & Ousterhout, 2013) — solve the same problem with different presentations. Paxos is mathematically beautiful and famously hard to understand. Raft is engineered specifically to be understandable while remaining correct. Most modern systems (etcd, Consul, CockroachDB, TiKV, RethinkDB) use Raft. The principles are the same.

This is the topic that powers leader election in Kubernetes, the durability of every transactional distributed database, the configuration agreement of every service mesh. It's also the topic where the gap between "I read about Raft" and "I deployed Raft and survived its failure modes" is enormous. Consensus is conceptually simple and operationally treacherous.

---

## Intuition Before Definitions

Imagine a group of friends trying to agree on a restaurant for dinner — by text message, on a flaky group chat where messages occasionally get dropped, delivered out of order, or reach only some recipients.

The naive approach: someone proposes, everyone says yes or no, the proposer counts votes. Doesn't work — what if the proposer's phone dies before sending the result? Half the group thinks "Italian"; half thinks "still deciding."

Better approach: pick one friend (the *leader*) to drive the decision. They poll the group, count responses, announce the answer. Everyone else just waits for the announcement. Simple, fast, decisive.

But what if the leader's phone dies? Now nobody's driving. The group must pick a new leader. How? Everyone whose phone hasn't died notices the silence and... races to volunteer? With messages getting reordered, two people might simultaneously think "I'll lead." Now there are two leaders and they might disagree.

The protocol must handle:
- Leaders dying.
- Multiple candidates at once.
- Messages dropped or reordered.
- Network partitions (some friends can't reach others).
- A formerly-dead leader returning (zombie leader).

Solving this — *correctly*, in all corner cases — is consensus. The remarkable result of theoretical CS is that it can be solved (under reasonable assumptions), and the protocols, while subtle, are now well-understood.

---

## Historical Evolution

**Era 1 — The dream of synchronization.**
1970s. Lamport's "Time, Clocks, and the Ordering of Events" (1978) establishes logical clocks. The realization: total ordering of events in a distributed system is the prerequisite to any agreement.

**Era 2 — The FLP impossibility.**
Fischer, Lynch, Paterson (1985): in a fully asynchronous system with even *one* faulty node, no deterministic consensus algorithm guarantees both safety and liveness. The result is foundational. It says consensus *cannot* be solved if you're paranoid about timing — meaning practical algorithms must make timing assumptions.

**Era 3 — Paxos.**
Leslie Lamport's "The Part-Time Parliament" (1989, finally published 1998) describes Paxos. Notoriously hard to read. The 2001 follow-up "Paxos Made Simple" tried to clarify; many engineers still found it hard. Used internally at Google (Chubby, Spanner) but the implementations remained closed-source for years.

**Era 4 — ZooKeeper and Multi-Paxos in production.**
ZooKeeper (Yahoo, 2008) ships a usable consensus-backed coordination service. Used by Hadoop, Kafka, and countless others. The pattern: outsource consensus to a small specialized cluster; let everyone else use it for leader election, configuration, and locks.

**Era 5 — Raft.**
Ongaro and Ousterhout (Stanford, 2013): "In Search of an Understandable Consensus Algorithm." Raft restructures Paxos's primitives into clearly-named phases (leader election, log replication, safety) with explicit state machines. Adoption is rapid: etcd, Consul, CockroachDB, TiKV, MongoDB (later versions), Kafka KRaft. Within five years, Raft becomes the default choice for new systems.

**Era 6 — Specialization and refinement.**
Variants and improvements: Multi-Raft (sharded Raft groups for scaling writes), Joint Consensus (safe membership changes), Raft + leases (read scaling), EPaxos (leaderless variant). The field remains active research; production systems are conservative.

The pattern: consensus moved from theoretical curiosity (Paxos, hard to understand) to industrial primitive (Raft, infrastructure layer). Engineers no longer write consensus algorithms; they use battle-tested libraries.

---

## Core Mental Models

**1. Consensus is about a quorum agreeing.**
Not unanimity (impossible if some nodes are down) but a majority. With 5 nodes, 3 must agree. With 3 nodes, 2 must agree. The math is identical to Dynamo-style quorums (R+W > N).

**2. The leader is a performance optimization.**
Pure Paxos has no leader; every operation is a multi-round consensus. Multi-Paxos and Raft elect a leader to handle most operations efficiently — once a leader is established, subsequent operations need just one round of agreement. Leader election is itself a consensus problem.

**3. Safety vs liveness.**
*Safety*: the algorithm never produces a wrong answer (e.g., two leaders simultaneously). *Liveness*: the algorithm eventually makes progress. FLP says you can't always have both perfectly. Real systems prioritize safety; liveness is achieved with timeouts and randomization.

**4. The log is the consensus.**
In Raft, what gets replicated isn't a single value — it's an *ordered log* of operations. Once a log entry is committed (replicated to a majority), it's durable forever. The replicated state machine is built by every node applying log entries in order.

**5. Membership changes are special.**
Adding or removing a node from a consensus group is itself a consensus decision. Doing it naively can violate safety (two majorities, two leaders). Joint consensus is the standard answer — a transitional configuration that overlaps old and new memberships.

---

## Deep Technical Explanation

### The consensus problem

Formally:
- A set of N nodes, each with a proposed value.
- Goals: all non-faulty nodes agree on a single value, and that value was proposed by some node.
- Constraints: nodes can fail (crash); messages can be lost, delayed, reordered.

Properties:
- **Agreement**: all non-faulty nodes decide the same value.
- **Validity**: the decided value was proposed by some node.
- **Termination**: all non-faulty nodes eventually decide.

FLP says termination is not guaranteed in fully asynchronous systems with a faulty node. Real systems sidestep with timeouts.

### Paxos in 30 seconds

Roles:
- **Proposer**: proposes values.
- **Acceptor**: votes on proposals.
- **Learner**: learns the chosen value.

Phases:
1. **Prepare**: proposer picks a unique number n, asks acceptors "promise not to accept proposals < n." Acceptors respond with the highest-numbered proposal they've already accepted (if any).
2. **Accept**: proposer picks a value (the previously-accepted one if any, else its own), tells acceptors "accept proposal (n, value)."
3. If a majority of acceptors accept, the value is *chosen*. Learners can be told.

The cleverness: the prepare phase ensures that any proposer with number n knows about earlier accepted values. This prevents safety violations even with concurrent proposers.

The pain: each value needs two round-trips (prepare + accept). Multi-Paxos amortizes this by having a leader skip the prepare phase for subsequent values until disrupted.

### Raft, more carefully

Raft decomposes consensus into three sub-problems:
1. **Leader election.**
2. **Log replication.**
3. **Safety.**

**Leader election.**

Each node is in one of three states: Follower, Candidate, Leader. Time is divided into *terms* — monotonically increasing numbers, each with at most one leader.

- All nodes start as Followers.
- Each Follower has an *election timeout* (typically 150-300ms). If it doesn't hear from a leader within the timeout, it becomes a Candidate.
- Candidates increment their term, vote for themselves, and request votes from peers.
- A Candidate becomes Leader if it receives votes from a majority.
- If two Candidates split the vote, neither wins; timeouts expire; new election with fresh randomization.

Randomized timeouts prevent endless split votes. Within a few rounds, one Candidate gets ahead.

**Log replication.**

Once a Leader is elected:
- Clients send commands to the Leader.
- The Leader appends commands to its log, sends `AppendEntries` RPCs to followers.
- Once a majority acks, the entry is *committed*.
- The Leader applies committed entries to its state machine and tells followers to do the same.

If a follower crashes or is slow, the Leader retries indefinitely. If a follower's log diverges from the Leader's, the Leader overwrites the divergent suffix.

**Safety.**

Critical invariants:
- A Leader for term T has all entries committed in any term ≤ T.
- This is enforced by the election protocol: a Candidate can only win if its log is at least as up-to-date as a majority's.
- Once an entry is committed, it cannot be lost — even if the current Leader crashes.

These rules feel obvious but are subtle. The Raft paper devotes significant space to proving them.

### Quorum size and N

Consensus requires majority quorums. With 2f+1 nodes, the system tolerates f failures.

| N | Majority | Failures tolerated |
|---|---|---|
| 1 | 1 | 0 |
| 3 | 2 | 1 |
| 5 | 3 | 2 |
| 7 | 4 | 3 |
| 9 | 5 | 4 |

Even N is *worse* than odd N: 4 nodes tolerates only 1 failure (need 3 for majority), same as 3 nodes — but with 4 nodes you have more failure surface. **Use odd cluster sizes**: 3, 5, 7. Production etcd defaults to 3 for small clusters, 5 for larger.

### Latency

Each consensus operation is *at least* one RTT to a majority. With 5 nodes spread across regions, this means crossing the slowest path to the third-fastest replica. Inter-region consensus has 50–200ms per operation. This is why distributed databases cap write throughput to "what one consensus group can sustain" per shard.

For reads:
- **Read from leader** (linearizable): one RTT, possibly less with leader leases.
- **Read from any replica** (stale): zero coordination, possibly stale data.
- **Lease-based reads**: leader gets a lease (time-bounded leadership); within the lease, leader can serve linearizable reads without coordination. Used for read scaling.

### Membership changes — joint consensus

Adding a node naively is unsafe. Suppose:
- Old cluster: A, B, C. Majority = 2.
- We add D, E. New cluster: A, B, C, D, E. Majority = 3.

If half the cluster thinks the membership is the old one and half thinks it's the new one, you can have two simultaneous majorities (e.g., {A, B} and {C, D, E}) — and two leaders. Safety violation.

Solution: **joint consensus** (Raft's approach). The cluster transitions through a phase where *both* old and new majorities are required for any decision. Once stable, transitions to the new configuration alone. No two-majorities window exists.

Implementations: etcd, CockroachDB, TiKV all use joint consensus or equivalent. Don't roll your own membership changes.

### Multi-Raft and scaling

A single Raft group has bounded throughput (limited by leader CPU and replication latency). To scale writes, partition data across many Raft groups, each with its own leader.

CockroachDB does this aggressively: each *range* (~64MB of key space) is a Raft group. A single cluster has tens of thousands of Raft groups, each handling a small portion of the key space.

This is why "consensus is slow" is misleading at scale: a single Raft group is slow, but a sharded multi-Raft system has aggregate throughput proportional to the number of groups.

### Leases and clock assumptions

To serve linearizable reads efficiently, leaders use *leases*: "I'm the leader for the next 9 seconds; nobody else can be." Within the lease, the leader doesn't need to consult others for reads.

The catch: leases assume bounded clock skew. If a leader's clock runs slow, its lease may have expired in real time while it still thinks it's valid. Spanner uses TrueTime (atomic clocks + GPS) to bound clock uncertainty; CockroachDB uses HLCs.

This is where consensus meets the clock problem from the [CAP file](./cap-consistency-and-replication.md). Whoever you trust on time, you trust on correctness.

---

## Real Engineering Analogies

**The corporate board vote.**
A board of directors decides whether to acquire a company. With 7 directors, 4 must agree. If 3 disagree but 4 don't, the motion passes. If the chairperson resigns mid-meeting, the remaining members must elect a new chair before continuing. If the meeting is interrupted (network partition), no decision can be made — but a partial group of 4 can continue if connected. A group of 3 cannot pass anything without the others.

This is consensus, in suit jackets. The rules — quorum, leadership, partition behavior — are the same.

**The Senate filibuster.**
Procedural rules ensure that a small minority cannot block decisions while preserving deliberation. Rules about quorum, recess, voice votes, recorded votes — all engineered over centuries. A consensus algorithm is similar: protocols designed so that even adversarial behavior produces eventually-correct outcomes.

---

## Production Engineering Perspective

What goes wrong with consensus in production:

- **The even-sized cluster.** A "4-node etcd cluster for capacity" is operationally disastrous. Loses 2 nodes → quorum lost → cluster cannot make progress → every write hangs. Documented Kubernetes outage cause.
- **The slow disk during election.** Raft requires durably persisting votes and log entries. If disk is slow (full, busy, network FS), elections take forever. Cluster appears stuck. Diagnosis: latency on `fsync` calls in Raft logs.
- **The asymmetric partition.** Node A can talk to B but not C. B can talk to both. Standard Raft handles this cleanly (B becomes leader). But edge cases exist — particularly around membership changes during partial partitions. Jepsen tests reveal these regularly.
- **The leader election storm.** A flaky network causes leader timeouts to fire repeatedly. Each new election produces a new leader briefly, then loses connectivity. No stable leader → no progress. Mitigation: longer election timeouts in flaky environments; Pre-Vote optimization (a node checks if it can win before incrementing its term).
- **The split-brain that wasn't.** Strict consensus prevents split-brain by quorum requirements — but membership changes done wrong can violate this. Always use library-implemented joint consensus.
- **The stale read.** Application reads from a replica. Replica is behind the leader. Application sees old data. If the application expected linearizability, this is a correctness bug. Mitigation: route reads through the leader, or use lease-based reads.
- **The recovery that took forever.** A node returns after long downtime; its log is far behind. Catching up via AppendEntries RPCs is slow. Modern systems use snapshot installation (transfer a state snapshot, then catch up incrementally).

The senior engineer's habits:
- **Never run even-sized consensus clusters.**
- **Monitor leader election rates.** Frequent re-elections = unstable cluster.
- **Disk health matters** for consensus throughput.
- **Use library-provided membership change procedures.**
- **Understand your read consistency model** — leader reads, lease reads, follower reads have different guarantees.
- **Test partition behavior** with chaos engineering.
- **Read Jepsen reports** for any consensus-backed system you depend on.

---

## Failure Scenarios

**Scenario 1 — The 4-node etcd cluster.**
Team adds a 4th node to "balance load." 2 nodes go offline (one for maintenance, one crashes). Remaining 2 nodes don't form quorum. Kubernetes API stops responding. Cluster is "down" until a node is restored.

**Scenario 2 — The election storm.**
Network experiencing high jitter. Election timeouts fire because heartbeats are delayed. Each new leader's heartbeats arrive late; new election. Cluster spends 10% of the time without a stable leader. Mitigations: longer timeouts, pre-vote optimization.

**Scenario 3 — The slow disk crisis.**
A consensus node's disk is failing — fsyncs take 500ms instead of 5ms. Raft requires fsync on each new entry. Throughput drops. Other nodes' heartbeats time out (because the slow node can't respond). Election triggered. New leader chosen. Old node continues to be slow. Production is degraded but functional.

**Scenario 4 — The membership-change accident.**
A team scripts node addition as "stop cluster, add node, restart cluster." During the restart, two halves of the cluster see different memberships. Two leaders elected. Inconsistent writes. Data divergence. Fix: rebuild from backup; use joint consensus going forward.

**Scenario 5 — The lease violation.**
A leader's clock is 500ms ahead of true time. Its lease appears to be valid for 9 more seconds, but a partition has elapsed. Another leader has been elected. The original leader serves a stale read from its lease. User sees inconsistency. Fix: bound clock skew with NTP discipline; consider TrueTime-style protocols for stricter guarantees.

---

## Performance Perspective

- **Per-operation latency** ≈ 1 RTT to majority. Geographically distributed clusters: 50–200ms.
- **Throughput** of a single Raft group: thousands of operations per second on commodity hardware.
- **Multi-Raft scales horizontally**: each shard has its own group. Aggregate throughput proportional to shard count.
- **Reads** can scale with lease-based reads or follower reads (with weaker consistency).
- **fsync is the bottleneck.** Each consensus operation requires a durable log write.

---

## Scaling Perspective

- **Vertical**: bigger nodes help log throughput and snapshot performance.
- **Horizontal (consensus group count)**: shard with multi-Raft. Each group scales independently.
- **Geographic**: 5-node clusters across 5 regions tolerate any 2-region failure but pay inter-region latency on every write.
- **Stretched clusters**: 3-node clusters across 3 regions with inter-region latency; minimum production HA topology.
- **Cell-based architectures**: independent consensus clusters per cell; cross-cell traffic uses sagas or eventual consistency.

---

## Cross-Domain Connections

- **CAP**: consensus is the *machinery* that implements consistent distributed systems. Raft is the practical "C" in CAP. (See [cap-consistency-and-replication.md](./cap-consistency-and-replication.md).)
- **WAL**: a Raft log is exactly a WAL replicated across nodes. Recovery semantics are identical. (See [wal-and-crash-recovery.md](../database-internals/wal-and-crash-recovery.md).)
- **Sharding**: multi-Raft is the standard scaling pattern for consensus-backed databases. (See [sharding-and-partitioning-strategies.md](../scalability/sharding-and-partitioning-strategies.md).)
- **Sagas**: consensus is the alternative to sagas — strong agreement vs eventual recovery. Pick based on consistency requirement. (See [saga-pattern-and-distributed-transactions.md](../architecture-patterns/saga-pattern-and-distributed-transactions.md).)
- **Observability**: leader election metrics, log replication lag, and apply latency are first-class signals for any consensus system. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)
- **Locks**: distributed locks built on consensus (etcd locks, ZooKeeper locks) inherit consensus's properties. (See [locks-mutexes-and-lock-free.md](../concurrency/locks-mutexes-and-lock-free.md).)

The unifying observation: **consensus is the ground truth primitive for distributed agreement.** Anywhere you need a binding decision across multiple machines, consensus or a derivative is doing the work — explicitly or implicitly.

---

## Real Production Scenarios

- **Kubernetes etcd outages**: numerous documented cases of even-sized clusters, slow disks, or network partitions causing API server outages. Required reading for any Kubernetes operator.
- **CockroachDB's design**: extensive public engineering posts on multi-Raft, range splits, leader leases, and the operational challenges of running consensus at scale.
- **MongoDB's replica set evolution**: moved from a custom protocol to Raft (with adaptations) in v3.6+. The migration's correctness was painstakingly proven.
- **Spanner's TrueTime**: enables externally-consistent transactions across consensus groups. Uses atomic clocks; one of the most ambitious consensus deployments.
- **Apache ZooKeeper at Hadoop scale**: a workhorse of pre-Raft consensus. Still widely used; its quirks (sequential consistency rather than linearizability for reads) are Hadoop ecosystem folklore.
- **Kafka KRaft**: replaced ZooKeeper dependency with internal Raft for Kafka's metadata. Significant architectural simplification.

---

## What Junior Engineers Usually Miss

- That **consensus requires majority quorum**, not all nodes.
- That **even-sized clusters are an anti-pattern**.
- That **consensus is slow per-operation** (1 RTT to majority).
- That **the leader is a performance optimization**, not a requirement.
- That **disk speed matters** for consensus throughput.
- That **reads have multiple consistency levels** (leader, lease, follower).
- That **membership changes need joint consensus**.
- That **untested partition behavior is broken** — Jepsen exists for this reason.

---

## What Senior Engineers Instinctively Notice

- They **insist on odd cluster sizes**.
- They **monitor leader election rates** as a stability signal.
- They **understand the read consistency they're getting** vs the one they want.
- They **never write their own consensus algorithm** — use a library.
- They **plan for membership changes carefully**.
- They **read Jepsen reports** before adopting any distributed system.
- They **distinguish multi-Raft systems** from single-Raft for scaling reasoning.
- They **test partition behavior** explicitly.

---

## Interview Perspective

What gets tested:

1. **"How does Raft work?"** Senior candidates explain leader election, log replication, and the safety invariants. Bonus for naming joint consensus.
2. **"Why odd cluster sizes?"** Tests fundamental literacy. Even sizes have the same fault tolerance as the smaller odd size.
3. **"What's the FLP impossibility?"** Tests theoretical depth. Real systems sidestep with timeouts.
4. **"How does a leader handle a follower that's far behind?"** AppendEntries with retries; snapshot installation if the follower is too far behind.
5. **"Why is consensus slow?"** Per-operation: 1 RTT to majority. Mitigations: leader leases for reads, multi-Raft for write throughput.
6. **"What's split-brain and how does Raft prevent it?"** Quorum requirement: only one majority can exist at a time. Membership changes preserve this via joint consensus.
7. **"Design a configuration store."** Tests applied design — likely outcome is "use etcd or Consul." Bonus for explaining why writing one yourself is unwise.

Common traps:
- Confusing "consensus" with "agreement" (informal sense).
- Believing larger clusters are always more available (each member adds latency, complexity).
- Not knowing about lease-based reads.

---

## 20% Knowledge Giving 80% Understanding

1. **Consensus = majority agreement** in the presence of failures.
2. **Odd cluster sizes**: 3, 5, 7. Never 4.
3. **2f+1 nodes tolerate f failures.**
4. **Raft = leader election + log replication + safety.**
5. **Each operation is 1 RTT to majority** (latency floor).
6. **Multi-Raft scales** by sharding consensus groups.
7. **Lease-based reads** scale linearizable reads without coordination.
8. **Membership changes need joint consensus.**
9. **Leader is an optimization**, not a requirement.
10. **Use libraries; don't roll your own.**

---

## Final Mental Model

> **Consensus is what computers do when humans aren't around to break ties. Every binding decision in a distributed system — who's the leader, what order did things happen, did this transaction commit — is either backed by consensus or quietly broken.**

The senior engineer working on a distributed system doesn't try to *avoid* consensus — they recognize where it's needed and use battle-tested implementations (etcd, ZooKeeper, the embedded Raft in CockroachDB or TiKV). Where consensus would be too slow, they use sagas or eventual consistency, with explicit acknowledgment of the weaker guarantees.

The remarkable thing about Raft is that, after decades of "consensus is hard," we now have algorithms understandable enough that engineers can read them, libraries trustworthy enough that engineers should use them, and operational experience refined enough that the common pitfalls are documented. The hard part isn't the algorithm anymore — it's *operating* the systems built on it: monitoring, capacity planning, partition testing, observability of the consensus layer.

That's leader election. That's consensus. That's the foundation primitive of every distributed system that ever made a binding decision and lived to tell the tale.
