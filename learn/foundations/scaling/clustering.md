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
- Raft / Paxos deserve their own file (consensus is foundational).
- Gossip protocols (SWIM) — missing.
- Quorum math (R + W > N) — belongs here or in replication.
