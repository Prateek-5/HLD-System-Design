# Distributed Consensus — Paxos & Raft

### 🔹 1. What This Topic Actually Is
Protocols that let a group of nodes agree on a value (or a sequence of values) despite failures and network partitions. The foundation of any strongly-consistent distributed system.

### 🔹 2. Why It Exists
- Without consensus: split brain, divergent replicas, lost writes, double-spends.
- Anything that needs a single authoritative leader (distributed lock, metadata service, linearizable KV, ordered log) needs consensus.

### 🔹 3. Core Concepts (High Signal)
- **Quorum**: you need a **majority** (N/2+1) of nodes to commit. 3 nodes → tolerate 1 failure; 5 → tolerate 2.
- **Paxos**: original (Leslie Lamport, 1998). Roles: Proposer, Acceptor, Learner. Two phases (Prepare, Accept). Notoriously hard to understand; hard to implement correctly.
- **Raft**: (Ongaro & Ousterhout, 2013). Designed for understandability. Leader-based; leader election + log replication + safety.
- **Raft phases**:
  1. *Leader election*: on timeout, candidate requests votes; majority → leader.
  2. *Log replication*: leader appends entries, replicates to followers; commit when majority acks.
  3. *Safety*: only up-to-date candidates can win; committed entries never lost.
- **Terms** (Raft): each leader has a monotonic term number; older-term messages rejected.
- **Split vote**: randomized election timeouts (150–300 ms) prevent repeat splits.
- **Byzantine fault tolerance (BFT)**: different problem — nodes may lie, not just crash. PBFT, Tendermint, blockchain. Overkill for trusted DC.

### 🔹 4. Internal Working (Raft leader election)
1. Each follower has a random election timeout (150–300ms).
2. If no heartbeat from leader → become candidate, increment term, vote for self, request votes.
3. On majority votes → become leader, send heartbeats.
4. On seeing higher term → step down.

**Log replication:** client sends cmd to leader → leader appends locally → replicates to followers → when majority ack → leader commits + notifies followers → client gets ack.

**Failure points:** leader dies (new election, ~500 ms), minority partition unable to elect, network flapping causes repeated elections, slow follower falls behind.

### 🔹 5. Key Tradeoffs
- Consensus requires majority reachable → partitioned minority **cannot make progress** (CP in CAP).
- Latency: every commit needs at least one RTT to majority.
- Can't scale throughput by adding nodes — more nodes = more ack coordination. Typically 3 or 5 nodes.
- Paxos is powerful (multi-Paxos can be leaderless); Raft is simpler but leader-centric.

### 🔹 6. Interview Questions
**Beginner**
1. Why do distributed systems need consensus?
2. What's a quorum?

**Intermediate**
1. Walk through Raft leader election.
2. Why 3 or 5 nodes, not 4 or 6? (Same fault tolerance but more messages.)

**Advanced**
1. Why does Raft use randomized election timeouts?
2. How does Spanner get global consensus with low latency? (TrueTime + Paxos)
3. CAP: where do Raft-backed systems fall? (CP — reject writes under partition.)

### 🔹 7. Real System Mapping
- **etcd** (Kubernetes control plane): Raft.
- **Consul**: Raft.
- **ZooKeeper**: Zab (Paxos-variant).
- **CockroachDB, TiDB, YugabyteDB**: Raft per range.
- **Spanner**: Paxos per shard + TrueTime for global consistency.
- **Kafka KRaft**: replaced ZooKeeper with Raft for metadata.

### 🔹 8. What Most People Miss
- **Consensus ≠ agreement on everything**: it's agreement on the *next log entry*, not on any data. Replicated state machines are built by applying the log deterministically.
- **Read linearizability is not free** — even with Raft, serving a read from a follower gives you stale data. Leader reads (with a lease or "read index") give linearizability.
- **Jepsen tests** (Aphyr) have found real bugs in most implementations. Never trust an unverified consensus library.
- **Consensus doesn't solve CAP**: it picks CP. Under partition, the minority side is unavailable.
- **TLA+** (Lamport) — formal spec language — is used to verify Raft/Paxos implementations at places like AWS, Azure.

### 🔹 9. 30-Second Revision
Consensus = majority agreement despite failures. Raft = understandable leader-based Paxos. 3 or 5 nodes, tolerate floor(N/2). Randomized timeouts avoid split votes. Linearizable reads need leader or leases. CP under CAP — minority unavailable during partition. Every strongly-consistent system has this underneath.

---

## 🔗 Cross-Topic Connections
- **Databases**: strongly-consistent distributed DBs (Spanner, Cockroach) use consensus per shard.
- **Messaging**: Kafka KRaft, BookKeeper use Raft/Paxos for metadata.
- **Replication**: multi-region primary elections need consensus to avoid split brain.
- **Caching**: rarely uses consensus (caches are OK stale), but cache metadata (which shard) does.

---

### Confidence Check
- [ ] Can I walk through Raft election + replication?
- [ ] Can I identify systems that need consensus vs systems that don't?

### Gaps
- Multi-Paxos vs classic Paxos.
- TLA+ spec practice.
- Witness / flexible-quorum Paxos variants.
