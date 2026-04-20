# Consistent Hashing — Sharding Without Remapping Everything

## A. Intuition First
Naive hashing `shard = hash(key) % N` means: if N changes, almost every key goes to a different shard. Expensive. Consistent hashing makes key-to-shard mapping **mostly stable** — adding/removing a shard only moves ~1/N of keys.

## B. Mental Model
- Imagine a ring of values 0 → 2^32 − 1.
- Each **shard** is a point on the ring (hash of its identifier).
- Each **key** is a point on the ring (hash of its value).
- A key belongs to the **first shard clockwise** from it.
- Add a shard → steal keys only from the next shard clockwise. Remove a shard → those keys migrate to the next. Rest untouched.

### Virtual nodes

**The problem they solve**: with just 3 physical nodes placed randomly on a ring, you often get *very uneven arcs*. Node A might own 50% of the ring, Node B 10%, Node C 40%. Load distribution = disaster.

**The fix**: each physical node owns **many** points on the ring (e.g., 200 virtual nodes per shard). With 3 × 200 = 600 points, the arcs become statistically uniform.

Each physical shard owns **many** points on the ring (e.g., 200 virtual nodes per shard). Smooths out load and gives finer control when removing/adding a physical node.

> **🧠 What if you skipped virtual nodes?**
> - Uneven load → some servers idle, others melting.
> - Removing a node transfers *all* its keys to one neighbor — instant hot shard.
> With virtual nodes, those keys disperse across many neighbors proportional to their current load.
>
> **🔎 Quick Check** — 10 physical nodes × 150 virtual nodes each = 1500 ring points. Removing 1 physical node moves what fraction of keys?
> **🎯 Recall** — ~10% (1/N), spread across the remaining 9 nodes, not dumped on one.

## C. Internal Working
Client (or proxy) on each request:
1. `h = hash(key)`.
2. Binary-search the sorted list of (ring_position, shard_id) for the first position ≥ h; wrap around if past the largest.
3. Forward to that shard.

Rebalance on node add:
- Compute new node's ring positions.
- For each position, identify next existing node clockwise (that's where these keys currently live).
- Migrate only the keys in that arc.
- Update the ring.

## D. Visual Representation
```
      0
      │
      │   [Shard A at 100]
      │
 2^32 ──────────  Ring
      │
      │    [Shard B at 1B]    ← keys with hash in (100, 1B] belong to B
      │
      │   [Shard C at 3B]
      ▼
```

## E. Tradeoffs
- Solves the remap-everything problem of mod hashing.
- Slightly uneven loads without virtual nodes → use them.
- Hot key is still hot — consistent hashing doesn't help skew; only node count changes.

## F. Interview Lens
- "How does adding a node behave with consistent hashing vs modulo?" — modulo remaps nearly all keys; CH moves ~1/N.
- "What are virtual nodes?"
- "How do you handle a hot key?" — replicate the key (consistent hashing + replication factor R), or application-level sharding of that key.
- Pitfalls: forgetting virtual nodes → uneven load.

## G. Real-World Mapping
- Amazon Dynamo and descendants (DynamoDB, Cassandra, Riak).
- Memcached client-side hashing (Ketama).
- CDN request routing to origin pools.
- Envoy's ring-hash load balancer.

## H. Questions
**Beginner**: What problem does consistent hashing solve?
**Intermediate**: Virtual nodes and why?
**Advanced**:
1. Design a consistent hashing scheme for a cache with 1M keys and 20 nodes.
2. With replication factor 3, where do copies go on the ring?

## I. Mini Design — "Redis cluster replacement"
- 10 cache nodes. Each gets 200 virtual ring positions.
- Client hashes request key, finds owning node.
- Replication: store on the next R nodes clockwise for redundancy (R=2).
- Adding node 11: migrates ~1/11 of keys. Downtime: none.

## J. Cross-Topic Connections
- [Sharding](sharding.md), [Replication](database-replication.md), [Caching](../foundations/scaling/caching.md), [Load Balancing](../foundations/scaling/load-balancing.md).

## K. Confidence Checklist
- [ ] Can draw the ring and explain placement.
- [ ] Knows virtual nodes and why.
- [ ] Can reason about add/remove impact (1/N).

### Red flags
- ❌ Believing CH fixes hot keys.
- ❌ Forgetting virtual nodes.

## L. Potential Gaps & Improvements
- Rendezvous hashing (HRW) — a competing scheme, sometimes better.
- Jump hash — simpler alternative for stable N+1 scaling.
- Load-aware hashing.
