# Clustering — Many Machines, One Apparent System

> **Prereq**: [Load Balancing](load-balancing.md)

## A. Intuition First
A cluster is a group of machines working as if they were one. The user requests the "service"; the cluster decides internally who handles it, how data is shared, and how to recover from a node failure.

**Why it exists**: one machine has a ceiling — RAM, CPU, disk, network. To go beyond, you combine machines. But you can't present N machines to users; you present **one system** that happens to be N under the hood.

## B. Mental Model
- **Nodes** — the machines.
- **Leader / coordinator** — the node that decides work distribution (not always present; Cassandra is masterless, Kubernetes has a control plane, Redis Cluster uses gossip).
- **Shared-nothing vs shared-storage** — each node has its own data, or all share a backing store.
- **Configurations**: active-active (all serving) vs active-passive (standby).

## C. Internal Working
1. Cluster membership: nodes know each other via a service registry / gossip protocol.
2. Work distribution: by hash, by range, by explicit assignment.
3. Failure detection: heartbeats / gossip; consensus (Raft/Paxos) to agree on "X is dead".
4. Rebalance: on node add/remove, work is reshuffled (consistent hashing minimizes churn).
5. Client sees one endpoint (via LB or discovery service).

## D. Visual Representation
```
            [ Load Balancer ]
                 │
   ┌─────────────┼─────────────┐
   ▼             ▼             ▼
 [Node A] ──── [Node B] ──── [Node C]
        (gossip / heartbeats)
```

## E. Tradeoffs
- **Load balancing vs clustering** — overlapping but not identical. LB routes traffic; cluster coordinates state + membership + failover. A load-balanced set of identical stateless web servers is arguably not a "cluster"; a Cassandra ring definitely is.
- **Homogeneous vs heterogeneous** — mixing node sizes works but complicates scheduling.
- **Active-active** gives throughput + redundancy; **active-passive** gives failover only (passive is wasted capacity).
- Operational complexity: you now have a distributed system; you own its problems (split-brain, consensus failures, slow rebalance).

## F. Interview Lens
- "Difference between clustering and load balancing?" → Clusters are aware of each other and share state; LB'd servers need not be.
- "Active-active vs active-passive?" → Throughput vs simplicity.
- "What is split brain?" → Network partition such that two nodes each think they're the leader. Resolved via quorum / fencing.

> **❓ "Quorum" — what is that, exactly?**
>
> **The problem it solves:** in a distributed cluster, a network partition can split the cluster in half. If both halves keep accepting writes thinking they're the "real" one, you get inconsistent data (split brain). You need a rule guaranteeing *at most one half* continues making authoritative decisions.
>
> **Intuition — the voting analogy:** every important action requires a **majority vote**. Just like democracy — if you have 5 senators and 3 vote yes, that's a quorum.
>
> **Formal rule:** quorum = ⌊N/2⌋ + 1 (strict majority of N nodes).
>
> | Cluster size (N) | Quorum | Tolerates failures |
> |---|---|---|
> | 3 | 2 | 1 |
> | 5 | 3 | 2 |
> | 7 | 4 | 3 |
> | 2 | 2 | **0** (any failure → unavailable) |
> | 4 | 3 | 1 (same as N=3, but more comms — avoid even N) |
>
> **Why odd numbers?** An even-node cluster gains no extra fault tolerance vs N−1, and costs more messages. 3, 5, 7 are canonical.
>
> **How this kills split brain:** if 5 nodes split 3–2, only the 3-side has quorum → the 2-side refuses writes until partition heals. Impossible for both halves to think they're authoritative.
>
> **Read/write quorums (Cassandra, Dynamo-style):** with replication factor R, you can configure:
> - `W` = number of replicas that must ack a write
> - `R` = number of replicas queried on read
> - As long as **W + R > N**, every read overlaps with the last write → consistency guaranteed.
> - Example: N=3, W=2, R=2 → 2+2 > 3 → strong consistency per-key.
>
> **🔄 Micro reinforcement**:
> 1. *Recall*: a 7-node cluster survives how many failures and still decides? *(3 failures; need 4 to form quorum.)*
> 2. *Recall*: why don't we use a 4-node cluster? *(Tolerates same 1 failure as 3 nodes but with more traffic.)*
> 3. *What if* we required *all* nodes to agree (W=N)? *(Any single failure halts progress — Cassandra calls this consistency level `ALL`; strong but fragile.)*
- Pitfalls: thinking clustering "just works" without a consensus story.

## G. Real-World Mapping
- **Kubernetes** — control plane (etcd cluster, kube-apiserver) + data plane (node cluster).
- **Cassandra, MongoDB, Redis Cluster, Elasticsearch** — database/cache clusters.
- **Kafka** — cluster of brokers with ZooKeeper or KRaft for metadata consensus.

## H. Questions
**Beginner**: What's a cluster? Active vs passive node?
**Intermediate**: How do nodes discover each other? How do they know if one is dead?
**Advanced**:
1. Explain split brain and two defenses (quorum, STONITH).
2. Design a leader election protocol for a 5-node cluster.
3. What changes when you go from 3 nodes to 300?

## I. Mini Design — "3-node Redis cluster"
- Use Redis Cluster mode: 16384 hash slots distributed across 3 primaries.
- Each primary has a replica (6 processes total).
- Client library hashes the key, routes to the right primary.
- On primary failure, replica is promoted via gossip consensus.
- Rebalancing: move slots (with small amount of data per slot) to new nodes.

## J. Cross-Topic Connections
- [Load Balancing](load-balancing.md) — often in front of clusters.
- [Database Replication](../../data/database-replication.md) — clusters rely on replication.
- [Consistent Hashing](../../data/consistent-hashing.md) — used for sharding work.
- [Service Discovery](../../reliability/service-discovery.md) — finds cluster nodes.

## K. Confidence Checklist
- [ ] Active-active vs active-passive.
- [ ] I know what split brain is.
- [ ] I can distinguish clustering from LB.
- [ ] I know one concrete clustered system (e.g., Cassandra) and how its nodes cooperate.

### Red flags
- ❌ "Just add more servers" — doesn't answer how they coordinate state.
- ❌ No mention of failure detection or consensus.

## L. Potential Gaps & Improvements
- **Raft / Paxos (consensus algorithms)** — protocols that let a cluster agree on one value/leader even when nodes crash; foundational for any "how do nodes stay consistent" question and deserve their own deep-dive file.
- **Gossip protocols (e.g. SWIM — Scalable Weakly-consistent Infection-style process group Membership)** — nodes randomly exchange state with peers so membership and failures spread epidemically without a central coordinator; how big clusters track who's alive.
- **Quorum math (R + W > N)** — requiring read replicas (R) plus write replicas (W) to exceed total replicas (N) guarantees overlap so reads see the latest write; the tuning knob behind consistency-vs-availability tradeoffs (belongs here or in replication). (→ see Interview Lens)
- **Split-brain & fencing** — when a network partition makes two halves each think they're the leader; fencing tokens / quorum prevent both from writing and corrupting data — a classic clustering failure mode worth naming. (→ see Interview Lens)

**🔧 How to close:** Spin up a 3-node Raft cluster locally and watch leader election: `docker run -d --name etcd1 quay.io/coreos/etcd etcd --name n1` (repeat for n2/n3 with `--initial-cluster`), then `etcdctl endpoint status --cluster -w table` to see the leader, kill the leader container with `docker stop`, and re-run the command to watch a new leader get elected within seconds.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🗳️ Gap 1 — Consensus: Raft & Paxos
- 🔹 **What it is**: Algorithms that let a group of nodes agree on a single value (e.g. "who is leader?", "what's the next log entry?") even when some nodes crash or messages are lost.
- 🔹 **Why it matters**: Almost every clustered system you'll name in an interview (etcd, Kubernetes, Kafka with KRaft, CockroachDB) has consensus at its core; "how do nodes agree?" is the question hiding behind most clustering follow-ups.
- 🔹 **Connection**: Section C lists "consensus (Raft/Paxos)" as the step that agrees "X is dead," and the Mini Design promotes a replica "via gossip consensus." This gap is the *how* behind that one line.
- 🔹 **When needed**: 🟡 **Mid-level** to explain Raft at a high level; 🔴 **Senior** to reason about log replication, term numbers, and corner cases.
- 🔹 **Intuition**: A committee where every decision needs a majority show of hands before it's recorded in the official minutes — if half the room walks out, the remaining majority can still keep meeting, but a lone member can't rewrite history.
- 🔹 **If you go deeper**: Read the Raft paper ("In Search of an Understandable Consensus Algorithm," Ongaro & Ousterhout) and play with the visualization at thesecretlivesofdata.com/raft; then skim Paxos via Lamport's "Paxos Made Simple."
- 🔹 **Interview hook**: *"How does a cluster pick a new leader after the old one dies?"* → Followers time out, become candidates, request votes for a new term; whoever gets a majority (quorum) wins and starts replicating its log.

---

#### 📡 Gap 2 — Gossip Protocols & Membership (SWIM)
- 🔹 **What it is**: Instead of a central coordinator tracking who's alive, each node periodically exchanges state with a few random peers, so membership and failure info spreads epidemically across the whole cluster.
- 🔹 **Why it matters**: It's how clusters scale to hundreds/thousands of nodes without a bottleneck — and it's exactly why masterless systems like Cassandra and Redis Cluster can detect failures without a single leader.
- 🔹 **Connection**: Section B calls Cassandra "masterless" and Redis Cluster "uses gossip"; Section C step 3 lists "heartbeats / gossip" for failure detection. This gap unpacks that gossip box.
- 🔹 **When needed**: 🟡 **Mid-level** — useful once you can already explain heartbeats and want to know how big clusters avoid a central watcher.
- 🔹 **Intuition**: Office rumors — nobody emails everyone; each person tells a couple of coworkers, and within a few rounds the whole floor knows who's out sick. No central announcement needed.
- 🔹 **If you go deeper**: Read the SWIM paper (Das, Gupta, Motivala, 2002) and study HashiCorp's Serf/`memberlist` library, which implements SWIM in production.
- 🔹 **Interview hook**: *"How does a 300-node cluster know one node died without a central monitor?"* → Gossip: random peer pings + indirect probes mark a node suspect, then dead, and that verdict spreads epidemically.

---

#### ⚖️ Gap 3 — Tunable Quorums (R + W > N)
- 🔹 **What it is**: A consistency knob where you choose how many replicas must acknowledge a write (W) and how many you read from (R); if W + R exceeds the replica count N, every read is guaranteed to overlap the latest write.
- 🔹 **Why it matters**: It's the precise lever behind the consistency-vs-availability tradeoff — and a favorite interview spot for showing you can *quantify* a design instead of hand-waving "eventually consistent."
- 🔹 **Connection**: The Interview Lens quorum box already derives W + R > N (N=3, W=2, R=2). This gap reframes it as a *design dial* you turn per workload, not just split-brain defense.
- 🔹 **When needed**: 🟡 **Mid-level** for Cassandra/Dynamo-style design rounds; 🟢 **Foundational** to simply state the W + R > N rule.
- 🔹 **Intuition**: Signing off on a contract — if 2 of 3 partners must sign every edit, and you check with any 2 before trusting it, at least one signer you ask always saw the latest change.
- 🔹 **If you go deeper**: Read the Amazon Dynamo paper (DeCandia et al., 2007) and experiment with Cassandra consistency levels (`ONE`, `QUORUM`, `ALL`) on a local 3-node ring.
- 🔹 **Interview hook**: *"Cassandra with N=3 — how do you get strong consistency on a key?"* → Set W=2 and R=2 so W + R > N, guaranteeing read/write overlap (`QUORUM` on both).

---

#### 🔒 Gap 4 — Split-Brain Defenses: Fencing & STONITH
- 🔹 **What it is**: Mechanisms that stop a stale or partitioned node from continuing to act as leader and corrupt data — fencing tokens (monotonic IDs that let downstream resources reject the old leader) and STONITH ("Shoot The Other Node In The Head," forcibly powering off the suspect node).
- 🔹 **Why it matters**: Quorum prevents *two* leaders from forming, but a node that *was* leader may still hold a stale lease and issue writes; fencing/STONITH is the second line of defense interviewers probe after you say "quorum."
- 🔹 **Connection**: Section F and the Advanced Questions both name split brain and ask for "two defenses (quorum, STONITH)." This gap explains the *fencing* half that the quorum box doesn't cover.
- 🔹 **When needed**: 🔴 **Senior** — distributed-systems and infra/SRE rounds where data-corruption scenarios matter.
- 🔹 **Intuition**: A returned hotel keycard — when you check out, the front desk reissues the room to a new guest with a higher key version; your old card silently stops opening the door even if you still hold it.
- 🔹 **If you go deeper**: Read Martin Kleppmann's "How to do distributed locking" (the fencing-token argument against naive Redis locks) and study Pacemaker/Corosync STONITH agents.
- 🔹 **Interview hook**: *"Quorum elected a new leader, but the old leader didn't notice — how do you prevent it from writing?"* → Fencing tokens: each leadership term gets a higher number, and storage rejects any write carrying a stale token.

---

### 🏆 Start here if you have limited time
1. **Consensus (Raft)** — it's the engine behind nearly every clustered system you'll name; explaining leader election alone covers many follow-ups.
2. **Tunable quorums (R + W > N)** — small concept, high payoff; lets you quantify consistency in design rounds instead of hand-waving.

---

### 🧭 Suggested Deep Dive Order
1. **Consensus: Raft** (~1.5h; run the etcd lab in "How to close" alongside the Raft visualization).
2. **Tunable quorums** (~45 min; immediately reusable in any database-design question).
3. **Gossip & SWIM** (~1h; explains how masterless clusters scale failure detection).
4. **Fencing & STONITH** (~1h; senior-level depth on surviving the worst split-brain cases).
