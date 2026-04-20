# Sharding — Horizontal Partitioning of Data

## A. Intuition First
One DB node has a ceiling. When you hit it, split the data across multiple nodes ("shards"). Each shard holds a subset; the whole system serves the combined dataset.

## B. Mental Model
- **Shard key**: the column(s) used to decide which shard a row lives on.
- **Shard strategy**: how keys map to shards.
- Each shard is a full DB (schema, indexes); together they cover the dataset with no overlap.

## C. Internal Working — Partitioning strategies

### Hash-based
`shard = hash(key) mod N`. Spreads evenly. Adding/removing shards remaps nearly all keys → expensive rebalance. **Fix**: use **consistent hashing** to minimize reshuffle.

### Range-based
`shard by key range: A–F → S1, G–M → S2, ...`. Great for range queries. Hot spots when ranges are skewed (e.g., user_id incrementing → newest shard is always hot).

### List-based
Explicit mapping: `region = us → S1, eu → S2`. Good for regulatory/geography constraints.

### Composite
Hash first (even spread), then range (time ordering) inside a hash bucket. Cassandra does exactly this (partition key hashed, clustering key sorted).

### Directory-based / Lookup table
Maintain `shard_map[key] → shard`. Very flexible (you can re-route individual hot keys) but the map is a SPOF.

## D. Visual Representation
```
shards:    S1        S2        S3
keys:     1,4,7    2,5,8     3,6,9    (hash mod 3)

Add S4:   everything remaps → migration nightmare
(Consistent hashing: only ~1/n keys move)
```

## E. Tradeoffs
### Pros
- Linear horizontal write scale.
- Isolation of hot data from cold.
- Per-shard backup, reindex, schema changes.

### Cons
- **Joins across shards**: painful or forbidden.
- **Distributed transactions**: see [distributed-transactions](distributed-transactions.md).
- **Rebalance** on node add/remove.
- **Operational complexity** (routing, backup per shard, cross-shard queries).
- **Hot shards** when the shard key is skewed.

## F. Interview Lens
- "When do you shard?" — when a single node's write throughput / storage is saturated.
- "What's a shard key? How to pick one?" — high cardinality, evenly distributed, queryable.
- "What's the problem with `user_id` as a shard key?" — might be fine; but if you query by `email`, you'd need a lookup table.
- "What happens if a shard fills up?" — resharding. Consistent hashing is your friend.
- Pitfalls: sharding too early (premature optimization); picking a shard key you'll later regret; hot partitions.

## G. Real-World Mapping
- **Instagram, Uber, Slack**: sharded Postgres/MySQL.
- **Cassandra, DynamoDB**: sharding baked in.
- **Vitess**: transparent sharding on top of MySQL (YouTube, Slack).

## H. Questions
**Beginner**: What is sharding? What's a shard key?
**Intermediate**:
1. Hash vs range — when each?
2. What is a hot shard?
**Advanced**:
1. Pick a shard key for Twitter's tweets. Defend.
2. How do you reshard a live DB without downtime?

## I. Mini Design — "Shard a users table"
10B rows. Shard key = `hash(user_id) mod N_shards` using consistent hashing. Each shard = 1B rows, indexed. Queries by user_id: route to one shard. Queries by email: secondary lookup table mapping `email → user_id` (globally replicated or queried via all shards). Transactions across users: sagas.

## J. Cross-Topic Connections
- [Consistent Hashing](consistent-hashing.md), [Replication](database-replication.md), [Distributed Transactions](distributed-transactions.md), [NoSQL](nosql-databases.md).

## K. Confidence Checklist
- [ ] Can pick a shard key for a given workload.
- [ ] Knows the four sharding strategies.
- [ ] Understands hot shards + cross-shard joins.

### Red flags
- ❌ Sharding before you've exhausted a single-node + replicas.
- ❌ Picking a shard key that doesn't match the dominant query pattern.

## L. Potential Gaps & Improvements
- Vitess-style resharding workflow.
- Re-sharding with zero downtime (dual-write + backfill + cutover).
- Sharding metadata / topology service design.
