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

### 🧯 Hot-key mitigation playbook (senior-level)

When one key takes 80% of traffic (celebrity tweet, viral meme, Black Friday SKU):

1. **Detect**: per-key QPS metric. Alert on outliers.
2. **Replicate**: store the hot key on N shards (N=3–10). Client picks a random replica per read. Works for read-heavy skew.
3. **Salt**: break the key into sub-keys — `user:celeb:0`, `user:celeb:1`, ..., `user:celeb:9` — and fan out reads across them. Used for counters (10× Redis `INCR`, sum on read).
4. **Two-tier cache**: promote hottest N keys to an app-local cache with shorter TTL.
5. **Back-pressure**: if a shard is melting, throttle writes to that key from upstream.

> **🧠 What if you *only* rely on consistent hashing and no hot-key strategy?**
> Consistent hashing gives *uniform hash distribution*, not *uniform query distribution*. A single celebrity key maps to one shard and that shard dies under load — no matter how good your hashing is.
>
> **🔎 Quick Check** — Justin Bieber tweets. Twitter's shard for `user:bieber` hits 50× normal QPS. Best fix?
> **🎯 Recall** — Replicate the celebrity's recent-tweets cache across multiple shards and fan-out reads.

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

---

### 🧭 Guided Deep-Learning Layer

#### 🔧 Gap 1 — Vitess Resharding
- 🔹 **What it is**: Vitess (from YouTube) is a MySQL-sharding orchestrator. Its resharding workflow is the gold standard: dual-write, backfill historical data, cutover, validate, retire old shards.
- 🔹 **Why it matters**: Actual resharding is where theory meets pain. Vitess is how Slack, GitHub, and YouTube did it without downtime.
- 🔹 **Connection**: This file mentions rebalancing is painful but doesn't show *how*. Vitess is the canonical operational playbook.
- 🔹 **When needed**: 🔴 **Important for senior interviews** designing at-scale SQL systems.
- 🔹 **Intuition**: Moving a house while everyone still lives there. You build the new house, gradually move furniture, then one day everyone sleeps in the new house — no one "moves out first".
- 🔹 **If you go deeper**: Read Vitess's documentation on horizontal resharding. Understand split tablet, source/target keyspaces, and the migration phases.
- 🔹 **Interview hook**: *"Your sharded MySQL is at 90% capacity on one shard. How do you reshard without downtime?"* → Vitess workflow: dual-write + backfill + cutover + validate.

---

#### 🔄 Gap 2 — Zero-Downtime Resharding (generic dual-write + backfill + cutover)
- 🔹 **What it is**: The generic resharding pattern: for each key, write to both old AND new shard; backfill historical data; once confirmed in sync, cut over reads; delete old.
- 🔹 **Why it matters**: Real systems need to move data while serving traffic. This pattern works for ANY sharded system, not just Vitess.
- 🔹 **Connection**: This is the sequence of operations that makes consistent-hashing rebalancing practical.
- 🔹 **When needed**: 🔴 **Important for senior interviews** on data migrations.
- 🔹 **Intuition**: 4-phase surgery: clone, sync, switch, remove. Every phase is verified before the next.
- 🔹 **If you go deeper**: Study phases: (1) deploy dual-write code; (2) backfill historical data (batch); (3) reconcile (compare new vs old); (4) cut reads over; (5) retire old. Each needs rollback paths.
- 🔹 **Interview hook**: *"Migrate 100M users from 4 shards to 16 shards with zero downtime."* → walk the 4 phases.

---

#### 🗺️ Gap 3 — Sharding Metadata / Topology Service
- 🔹 **What it is**: A service that maintains the mapping "which shard owns which keyspace" — consulted by clients/proxies to route queries.
- 🔹 **Why it matters**: Without it, you hard-code shard assignments and can't rebalance. With it, you become cloud-native.
- 🔹 **Connection**: The "lookup table" sharding strategy in this file implies a metadata service; this explains how to build one.
- 🔹 **When needed**: 🔴 **Important for senior infra interviews**.
- 🔹 **Intuition**: The librarian's index card system — tells you which room (shard) the book lives in. Updating the index lets you move books without re-indexing the whole library.
- 🔹 **If you go deeper**: Study ZooKeeper / etcd (consistent metadata stores), Vitess's VTGate topology service. Understand how clients cache routing info and handle stale routes (retry with fresh fetch).
- 🔹 **Interview hook**: *"How do clients know which shard owns a given user_id?"* → metadata service (etcd / Zanzibar-style) cached at client with invalidation on reshard.

---

### 🏆 Start here if you have limited time

1. **Zero-downtime dual-write + backfill + cutover** — universal pattern; comes up in every real migration.
2. **Topology/metadata service** — senior-level architectural fluency.

Skip deep Vitess internals unless the role is MySQL-scale infra.

---

### 🧭 Suggested Deep Dive Order

1. **Dual-write + backfill + cutover** (~1h; universal playbook).
2. **Topology / metadata service** (~1h; architectural depth).
3. **Vitess specifics** (~2h; only if MySQL-scale role).
