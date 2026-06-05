# Sharding & Partitioning Strategies

> *"You cannot scale what you have not partitioned. You cannot partition what you have not understood. The hardest part of scaling is not the partitioning itself — it's the conversation, three years before, where someone designed a schema without thinking about it."*

---

## 🎯 Start Here — Intuition

> **In one line:** when your data no longer fits on one machine, you split it across many — and the whole game is *choosing how to split it* so the queries you run most stay fast.
>
> **Analogy:** a single library that's overflowing opens branch locations. The crucial question isn't "do we split?" — it's "what rule decides which book goes to which branch?" Split alphabetically and one branch drowns in popular authors; split by neighborhood and most reads stay local but national bestsellers cause chaos. Same data, very different outcomes depending on the rule.
>
> **New to this?** Build the basics first in [`learn/data/sharding.md`](../../learn/data/sharding.md) — *then* come back for the depth.
>
> **Level:** this file is 🟡 overall, leaning 🔴 in the internals. Sections below are tagged. If the basics feel shaky, that tag is your signal to slow down — **you are not behind.**

---

## Topic Overview 🟢

Every system that exceeds the capacity of a single machine eventually faces the same question: how do we split the data — and the work — across multiple machines? The answer is *partitioning* (also called *sharding*, depending on dialect): a strategy for dividing data so that each partition fits on one machine, can be queried locally, and can scale by adding more partitions.

The decision sounds operational. It isn't. **The partitioning key is a design decision baked into the schema, the query patterns, the failure modes, and the operational complexity for the lifetime of the system.** Choose well, and you scale by adding nodes. Choose badly, and you're rewriting your data model under load five years later, in production, while customers complain.

This is the topic where database internals, distributed systems, and product requirements meet. It's also the topic where most teams discover too late that "we'll shard later" was a false promise — because by the time you need to, the queries that worked on a single node fight against the partitioning you finally choose.

---

## Intuition Before Definitions 🟢

Imagine a city library with 50 million books, all in one building. The building is full. You can't add more shelves. Performance is degrading — there are too many people in the aisles.

You decide to split into branch libraries. The hard question is: *how do we decide which books go where?*

**Option 1 — Alphabetical.** Branch 1 gets A–F, Branch 2 gets G–M, etc. Easy to find a book by title. But "all books by author 'Asimov'" hits one branch heavily; "Smith" overwhelms another. Some branches are crowded; some are empty. If "Harry Potter" books all live in one branch, that branch is a hotspot.

**Option 2 — By topic.** Branch 1 gets science, Branch 2 gets literature, etc. Better for browsing within a topic, terrible for cross-topic searches.

**Option 3 — By a hash of the title.** Each book goes to a branch determined by `hash(title) % 5`. Even distribution. But "all books by Asimov" requires checking every branch.

**Option 4 — Geographic (by where readers live).** Local books for local readers. Most reads stay local. But moving — or popular national books — creates problems.

There is no "right" answer. Each option optimizes for different access patterns. The librarian's job — and the database engineer's job — is to know the access patterns *before* committing to the split. Once committed, changing the partitioning means physically moving books — slow, error-prone, expensive.

That's the entire field. Choose the right partitioning key for your access patterns. Pay forever for getting it wrong.

---

## Historical Evolution 🟡

**Era 1 — The single big database.**
1990s and early 2000s. Scale up: bigger boxes, more RAM, faster disks. Worked beautifully until it didn't. Mainframes set the upper bound; "downsizing to commodity hardware" started bumping into single-node limits.

**Era 2 — Manual sharding.**
The application layer learned to compute "which database does this user live on?" Painful but real. Friendster, MySpace, early Facebook all manually sharded by user ID, with all the operational pain that implies (cross-shard queries, rebalancing, schema migrations multiplied by N).

**Era 3 — Vitess and the early sharding middleware.**
YouTube's MySQL operations evolved into Vitess (open-sourced 2012). The pattern: a routing layer above multiple MySQL instances, hiding sharding from the application. Cross-shard queries became possible (with caveats). The application could pretend it was talking to one database.

**Era 4 — Native distributed databases.**
Google's Bigtable (2006) and the wave of NoSQL (Not Only SQL): Cassandra, DynamoDB, MongoDB. Sharding built into the system, not bolted on. Tradeoffs explicit: no cross-shard transactions, no joins, but linear scaling.

**Era 5 — NewSQL.**
CockroachDB (2014), Spanner, YugabyteDB. Distributed SQL with cross-shard transactions, automatic rebalancing, geographic replication. The promise: SQL ergonomics with NoSQL scale. The cost: latency on cross-shard operations, operational complexity, and price.

**Era 6 — The pragmatic era.**
Most production architectures today combine: a primary OLTP (Online Transaction Processing) database (sharded or not), specialized stores for specific workloads (Elasticsearch for search, ClickHouse for analytics, Redis for caching), and a clear story for which data lives where. The "one database to rule them all" ambition has faded; specialization wins.

The pattern: each generation pushed sharding from application code, into middleware, into the database itself, into infrastructure that's invisible. Each step reduced application complexity at the cost of operational complexity at a deeper layer.

---

## Deep Technical Explanation 🔴

⚠️ The rest assumes the basics above are solid.

### Partitioning strategies

**Range partitioning.**
Data is split into contiguous ranges by key. Partition 1: keys A–F. Partition 2: keys G–M. Etc.

Pros: range queries are fast (a few partitions, contiguous). Natural for time-series data.
Cons: hot ranges become hot shards. Sequential keys (timestamps, autoincrement IDs) write to the most recent partition only — write hotspot.

Used by: Bigtable, HBase, Spanner (with care), CockroachDB.

**Hash partitioning.**
Data is split by `hash(key) % N` (or similar). Distribution is even.

Pros: load balanced by design. No write hotspot.
Cons: range queries scatter to all partitions. Adjacent keys aren't co-located.

Used by: Cassandra, DynamoDB (default), most "shard by user_id" architectures.

**Hash + range (composite).**
Hash on a primary key (user ID), range within (timestamp). Each user's data is local; within a user, time-series queries are fast.

Pros: combines benefits. Most flexible.
Cons: requires the primary key to be in queries. Cross-user queries scatter.

Used by: Cassandra, DynamoDB, ScyllaDB.

**Consistent hashing.**
Hash partitioning with a twist: nodes are placed on a hash ring; keys hash to the ring; the closest node clockwise owns the key. Adding a node moves only the keys between the new node and its predecessor — typically 1/N of total data, not 100%.

Pros: minimal data movement on rebalance. Industry standard for distributed caches and databases.
Cons: still vulnerable to hot keys (one node owns the ring slice for that key).

Used by: Cassandra, DynamoDB, Memcached client-side, every modern distributed cache.

**Virtual nodes (vnodes).**
An evolution of consistent hashing: each physical node owns multiple virtual slots on the ring. A node failure spreads its load across many other nodes (better recovery); rebalancing is finer-grained.

Used by: modern Cassandra, ScyllaDB.

**Directory-based partitioning.**
A lookup service maps keys to partitions explicitly. Maximum flexibility — partitions can be moved without changing the routing logic in clients.

Pros: arbitrary partitioning logic; easy to evolve.
Cons: the directory is a critical dependency and a potential bottleneck.

### Partition key selection — the crucial decision

The partition key must:
1. **Distribute load evenly.** No hot keys.
2. **Be present in hot queries.** So they don't scatter.
3. **Co-locate naturally-joined data.** Avoid cross-shard joins.
4. **Be stable.** Changing partition key for a row means moving it.

Common patterns:
- **By user/tenant ID.** Each user's data is local. Per-user queries fast. Cross-user analytics scatter. Default for SaaS (Software-as-a-Service).
- **By time.** Recent data on the "hot" partition; old data archived. Natural for logs, metrics, events. Hot-write problem unless combined with another key.
- **By geographic region.** Data near users. Compliance-friendly (GDPR (General Data Protection Regulation)). Cross-region queries expensive.
- **By hash of a unique ID.** Maximum distribution. Cross-key queries scatter.

The decision is downstream of the *most frequent and most performance-sensitive queries*. Build the read pattern first; choose the partition key to make it fast.

### Hot keys — the killer problem

A "celebrity" user with 10,000× the activity of an average user. A "hot" sensor pushing data every millisecond. A "popular" product viewed by every customer. These create partitions that are vastly more loaded than others.

Mitigations:
- **Composite keys with bucketing.** Instead of `user_id`, partition by `(user_id, bucket)` where bucket is a small random number. Spreads load across N partitions. Reads must scatter to all buckets.
- **Replication of hot keys.** Special-case popular keys: replicate them to multiple partitions so reads can be load-balanced.
- **Caching upstream.** Hot keys are often read-heavy; a cache absorbs most reads, leaving only writes hitting the partition.
- **Application-level sharding** for hot keys: a logical "user" that's actually multiple physical entries.

There is no automatic answer. Hot-key handling is engineering work specific to the workload.

### Cross-shard queries

The expensive operations:

- **Cross-shard joins**: scatter the primary query, gather, join in memory. Fine for small result sets; brutal for large ones.
- **Cross-shard transactions**: 2PC (Two-Phase Commit) (or distributed consensus) across shards. Latency multiplied; conflicts amplified. Avoid unless essential.
- **Global aggregations**: count distinct users across all shards. Approximated with HyperLogLog (HLL); exact answers are expensive.
- **Cross-shard ordering**: top-K queries across all shards. Fan-out to each shard, gather, reduce. Always slower than single-shard equivalent.

The discipline: **design the schema so that hot queries don't cross shards.** Denormalize if necessary. Replicate small reference data to every shard. Keep cross-shard work in batch jobs, not request paths.

### Rebalancing

Adding or removing shards requires moving data. Strategies:

- **Stop the world.** Take system offline; redistribute. Used in early sharded systems. Outrageous downtime.
- **Live rebalancing with double-writes.** New node is brought up; writes go to both old and new locations during migration; reads switch over when migration completes.
- **Consistent hashing's gift.** Adding a node only moves keys in one ring slice. Other partitions unaffected.
- **Range splits.** Range partitions can be split when too large; the system migrates the upper half to a new node.

Modern systems do this online, throttled to limit impact on production traffic. Cassandra's "bootstrap," CockroachDB's "rebalancing," Vitess's "reshard" — same idea, different terminology.

The operational reality: rebalancing is *slow* for large datasets. A petabyte-scale rebalance takes days. Plan capacity well ahead.

### Shard count selection

Common question: "how many shards should I have?"

Considerations:
- **Too few**: each shard is large. Failure of one shard is high-impact. Rebalancing moves more data.
- **Too many**: operational overhead. Cross-shard fan-out is wider. Per-shard utilization is low.
- **Powers of 2** are common: doubling capacity is a clean operation.
- **Many small shards** are easier to migrate and rebalance than few large ones.
- **Vnode-style systems** abstract the count; you pick a logical partition count, the system maps to physical nodes.

A typical pattern: start with 64 or 128 logical partitions, even if running on 4 physical nodes. As you scale, partitions move to new nodes without changing the partition count. The application's partition routing stays stable.

### The "shard later" antipattern

Teams often say "we'll add sharding when we need it." The problem: by the time you need it, the queries you've written assume single-database semantics. Cross-table joins, transactions across all data, queries without partition keys. Adding sharding then means rewriting your data layer.

The pragmatic alternative: **design the schema as if it were sharded from day one**, even if you run on a single database initially. Always include a partition-eligible key in your tables. Avoid queries that span the entire dataset. Then sharding is an operational migration, not an application rewrite.

---

## Real Engineering Analogies 🟢

**The post office sorting hierarchy.**
National post offices route mail by ZIP code prefixes. Mail to 02xxx goes to one regional center; 90xxx to another. Each regional center subdivides by full ZIP code. Each local office subdivides by street. Multiple levels of partitioning, each based on a different aspect of the address.

This is exactly hierarchical partitioning. The "address" is the partition key; the "level" is the granularity. Routing is deterministic and decentralized. No central coordinator decides where each letter goes.

**The chain of grocery stores.**
A national grocery chain doesn't keep all inventory in one warehouse. Regional warehouses serve regional stores. Each store has local inventory. A request for a specific product is routed by region first, then store. Stock moves between regions during seasonal patterns. New regions are added by building new warehouses, not redesigning the supply chain.

This is consistent hashing with regional hierarchy. Adding a region (a node) doesn't disrupt other regions. Stock movement (rebalancing) is throttled to avoid disrupting deliveries.

---

## Production Engineering Perspective 🔴

What goes wrong with sharding in production:

- **The unanticipated hot tenant.** A B2B (Business-to-Business) SaaS with one million tenants, sharded by tenant ID. One enterprise customer signs on. They generate 50% of total load. Their partition is overwhelmed. Recovery: split their data across multiple "sub-shards"; treat them as a special case.
- **The cross-shard join you didn't expect.** A new feature requires joining users with their orders. Users sharded by user ID; orders sharded by order ID. The join now scatters to all shards. Latency goes from 50ms to 5s. Fix: re-shard orders by user ID, denormalize user data into orders, or precompute the join offline.
- **The partition key that made sense at the time.** Sharding by `customer_email` seemed unique. Then the company supported "guest checkout" with NULL emails. Now all NULL-email orders pile into one partition. Schema migration needed.
- **The rebalance that took down the cluster.** Doubling capacity from 8 to 16 nodes. Default rebalancing throttle was too high. Network saturated. Application timed out. Customers saw errors during a 4-hour migration. Fix: lower rebalance rate, longer migration, less impact.
- **The shard that grew to 10× the others.** Range partitioning by date. The current partition keeps growing. By month 6, it's 10× larger than older partitions. Splits manually triggered. Operational overhead per month. Better to use hash + range from the start.
- **The cross-shard transaction that hung.** A "rare" operation that updates two users' balances. Implemented with 2PC. Coordinator died. Locks held on both shards. Production stalled. Fix: redesign as a saga.
- **The query that "worked in dev."** Dev had 1 shard. Prod has 64. Query without partition key scatter-gathered. Local: 5ms. Production: 500ms. Discovered after deploy.

---

## Failure Scenarios 🔴

**Scenario 1 — The celebrity account.**
A social platform shards user data by user ID. A new celebrity user accumulates 50M followers. Their feed reads dominate one shard. p99 (99th percentile) latency on that shard is 10× others. Mitigation: replicate the celebrity's writes to multiple read replicas; cache hot follower lists; eventually, treat as a special case in the routing layer.

**Scenario 2 — The black-friday range hot spot.**
Time-series data range-partitioned. The "current month" partition is the only one being written to. During Black Friday, write QPS (Queries Per Second) exceeds the partition's capacity. Older partitions are idle. Recovery: switch to hash + range partitioning so writes spread across shards within the current month.

**Scenario 3 — The schema migration across shards.**
Adding a column to a table. The schema migration runs per-shard. 64 shards, 100GB each. Sequential: 6+ hours. The team runs migrations in parallel; some shards have replication lag spikes; one fails midway. Inconsistent schema across shards. Recovery: replay the migration on the failed shard; tighter monitoring; staged rollouts.

**Scenario 4 — The misrouted query.**
A new microservice queries the shared database without knowing about sharding. It uses the connection string of one shard but expects all data. Returns partial results. Bug discovered when a customer reports "my orders are missing."

**Scenario 5 — The 2PC across shards that came back.**
A team adds a "transfer balance between users" feature. Implements as 2PC across shards. Under load, prepared transactions accumulate during a network blip. Throughput collapses. Recovery: redesign as a saga with idempotent operations.

---

## Performance Perspective 🟡

- **Single-shard query latency** ≈ unsharded latency. Sharding doesn't help individual queries; it scales aggregate throughput.
- **Cross-shard fan-out latency** = max(individual shard latencies) + coordination overhead. Tail latency is amplified.
- **Rebalancing impact** is real. Throttle aggressively in production.
- **Connection management**: applications need connections to all shards (or to a routing layer). Connection-pool sizing multiplies with shard count.
- **Hot partition is a single-thread bottleneck.** No amount of cluster capacity helps if one partition is overwhelmed.

---

## Scaling Perspective 🟡

- **Vertical:** larger nodes per shard delays the need for more shards but eventually hits limits.
- **Horizontal:** add shards. Application must accommodate new partitions.
- **Geographic:** each region runs its own shards; cross-region replication for HA (High Availability). Geographic partitioning often coincides with compliance boundaries (GDPR).
- **Multi-tenancy:** tenants as natural shard boundaries. Easy if tenants are independent; hard if cross-tenant queries are needed.
- **The hardest scale:** a single tenant or single key that exceeds one node's capacity. Requires application-level sharding above the database's sharding.

---

## Cross-Domain Connections 🔴

- **CAP (Consistency, Availability, Partition tolerance)**: sharding is a flavor of partitioning that interacts with consistency. Cross-shard transactions are distributed transactions. (See [cap-consistency-and-replication.md](../distributed-systems/cap-consistency-and-replication.md).)
- **Indexing**: each shard has its own indexes. Cross-shard queries must consult multiple indexes. (See [indexing-and-storage-engines.md](../database-internals/indexing-and-storage-engines.md).)
- **Caching**: distributed caches use consistent hashing — exactly the same algorithm. (See [caching-hierarchy.md](../caching/caching-hierarchy.md).)
- **Sagas**: cross-shard transactions almost always require saga-style flows. (See [saga-pattern-and-distributed-transactions.md](../architecture-patterns/saga-pattern-and-distributed-transactions.md).)
- **Locks**: per-shard locking is local; cross-shard coordination is distributed locking, with all its problems. (See [locks-mutexes-and-lock-free.md](../concurrency/locks-mutexes-and-lock-free.md).)
- **Cascading failures**: a hot shard cascades like an overloaded service. (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)

The unifying observation: **sharding is divide-and-conquer applied to data, with all the standard caveats — communication overhead, uneven distribution, coordination cost.** The same insights apply at every layer where state must be partitioned.

---

## Real Production Scenarios 🟡

- **YouTube's Vitess origin**: MySQL sharding at YouTube scale, abstracted into a routing layer. Open-sourced; used by Slack, GitHub, Square, others.
- **Discord's Cassandra → ScyllaDB migration**: documented case of dealing with hot partitions at billions of messages scale. Architectural insights about partition key choice (per-channel) and bucketing.
- **GitHub's MySQL sharding journey**: public engineering posts about sharding repos and users, the operational complexity of online schema migrations across shards.
- **Stripe's "rate-limited rebalances"**: documented patterns for minimizing impact during shard rebalancing in their high-throughput payment infrastructure.
- **Pinterest's MySQL sharding**: well-known case study of "shard by user ID" for billions of pins, with the inherent cross-user-query challenges.
- **Cassandra at Netflix scale**: documented case studies on partition key selection, hot key mitigations, and capacity planning.

---

## Worked Example — Sharding a Multi-Tenant SaaS 🔴

A multi-tenant SaaS app. Currently 100GB Postgres; growing fast. 50K tenants, varying sizes (a few enterprise tenants are 1000× larger than the median).

### Step 1: Analyze the workload

```sql
-- Query patterns (from pg_stat_statements)
-- 1. SELECT * FROM tickets WHERE tenant_id = ? AND id = ?       (40%)
-- 2. SELECT * FROM tickets WHERE tenant_id = ? ORDER BY ...     (30%)
-- 3. SELECT * FROM users WHERE tenant_id = ? AND email = ?      (15%)
-- 4. Cross-tenant analytics (5%) — runs on a separate warehouse already
-- 5. Other tenant-specific queries (10%)
```

Conclusion: 95% of queries include `tenant_id`. Partition by `tenant_id`.

### Step 2: Distribution analysis

```python
# Tenant size distribution (rows of `tickets` table, log scale):
# - Median tenant: 1,000 tickets
# - 90th percentile: 10,000
# - 99th percentile: 100,000
# - Top 5 tenants: 1M+ each
# - Largest single tenant: 50M tickets
```

A direct `hash(tenant_id) % N` would put the largest tenant entirely on one shard. That shard would be 100× the others. Hot shard.

### Step 3: Sharding strategy

For most tenants: hash by tenant_id with vnodes. For enterprise tenants: dedicated shards.

```python
ENTERPRISE_TENANT_IDS = load_enterprise_tenant_set()  # ~50 tenants
NUM_VNODES = 1024
NUM_PHYSICAL_SHARDS = 16

def shard_for_tenant(tenant_id: str) -> Shard:
    if tenant_id in ENTERPRISE_TENANT_IDS:
        # Dedicated shards for enterprise (silo model for them)
        return enterprise_shard_map[tenant_id]
    
    # Hash-based with vnodes for small/medium tenants
    vnode = hash_for_partitioning(tenant_id) % NUM_VNODES
    return shared_shards[vnode % NUM_PHYSICAL_SHARDS]
```

This is a **hybrid multi-tenancy model**: silo for enterprise; pool for everyone else.

### Step 4: Schema design for sharding

Every table includes `tenant_id` as first column of every primary key:

```sql
-- Before:
CREATE TABLE tickets (
    id BIGINT PRIMARY KEY,
    tenant_id BIGINT,
    title TEXT,
    ...
);

-- After (sharding-friendly):
CREATE TABLE tickets (
    tenant_id BIGINT,
    id BIGINT,
    title TEXT,
    ...,
    PRIMARY KEY (tenant_id, id)
);

CREATE INDEX idx_tickets_tenant_assignee 
    ON tickets (tenant_id, assignee_id);  -- composite, tenant-scoped
```

Benefit: every index is tenant-scoped; tenant data co-located physically.

### Step 5: Migration plan

This is *not* a weekend project. Realistic timeline: 6-12 months.

**Phase 1 (months 1-2): Schema preparation.**
- Add `tenant_id` to all tables that lack it.
- Update all queries to include `WHERE tenant_id = ?`.
- Add a `Shard` abstraction in the data layer.
- All queries currently route to a single DB.

**Phase 2 (months 3-4): Dual-database setup.**
- Provision new sharded database cluster (16 shards initially).
- Build CDC (Change Data Capture) pipeline to backfill historical data per-tenant.
- Application reads still go to old DB; writes go to both.

**Phase 3 (months 5-6): Shadow reads.**
- Application reads compare old vs new responses; log diffs.
- Discover correctness bugs without customer impact.
- Iterate until diffs are zero.

**Phase 4 (months 7-8): Tenant-by-tenant cutover.**
- Migrate small tenants first (lowest risk).
- Per-tenant: stop writes briefly; finalize backfill; switch reads; resume writes.
- Each migration is ~5 minutes of read-only window for that tenant.
- Parallelize migrations.

**Phase 5 (months 9-10): Migrate enterprise.**
- Each enterprise tenant migrated to its dedicated shard.
- More careful; more testing; longer windows; sometimes scheduled.

**Phase 6 (months 11-12): Decommission old.**
- All traffic on new architecture.
- Remove dual-write code.
- Decommission old database.
- Document operational procedures.

### Step 6: Cross-tenant queries (analytics, admin)

```python
# Internal admin queries that need cross-tenant data
def admin_search_users(email_pattern):
    # Scatter-gather across all shards
    futures = [
        executor.submit(shard.search_users_by_email, email_pattern)
        for shard in all_shards
    ]
    return [u for f in futures for u in f.result()]

# Better: keep an indexed search system (Elasticsearch) for these queries
# Driven by CDC from each shard
def admin_search_users_v2(email_pattern):
    return elasticsearch.search({"query": {"wildcard": {"email": email_pattern}}})
```

Cross-shard analytics goes to a warehouse (BigQuery / Snowflake). Not the OLTP shards.

### Operational state after migration

```
- 16 OLTP Postgres shards: each ~10TB, each at <40% capacity (room to grow).
- ~50 enterprise dedicated shards (one per enterprise tenant).
- Per-tenant routing via consistent-hashing + dedicated overrides.
- CDC pipeline → Elasticsearch (admin search) + Snowflake (analytics).
- Operational dashboards: per-shard metrics; hottest tenants per shard.
- Capacity planning: monthly review per-shard; rebalance enterprise tenants when needed.
```

### Lessons learned (real-world)

- **Migration takes longer than estimated.** Always.
- **Discoveries during shadow reads** save outages later.
- **Hot enterprise tenants** are predictable in retrospect; identify early.
- **Cross-shard queries must be excluded** from OLTP shards.
- **Operational complexity grows** — dedicated team often needed.

---

## Recent Production References (2023-2024) 🟡

- **Notion's 2023 sharding migration**: documented public engineering. Sharded a single Postgres DB to a sharded architecture. Used Citus.
- **Figma's database migration (2023)**: documented case of sharding their giant Postgres.
- **GitHub's MySQL Vitess migration (ongoing)**: long-running effort to shard their MySQL workloads.
- **Discord's ScyllaDB migration**: from Cassandra to ScyllaDB; partition key choices documented.
- **Pinterest's MySQL sharding (long-published)**: foundational reference.
- **Slack's sharding journey**: well-documented; multiple iterations.
- **Stripe's sharding patterns**: public engineering on sharded financial workloads.

---

## Reference Architecture 🔴

```
                   ┌─────────────────────────────────┐
                   │       Application servers        │
                   │  Each request includes tenant_id │
                   └────────────────┬────────────────┘
                                    │
                                    ▼
                   ┌─────────────────────────────────┐
                   │       Routing layer (Vitess /    │
                   │       Citus / custom)            │
                   │       hash(tenant_id) → shard    │
                   └─┬──────────┬──────────┬─────────┘
                     │          │          │
            ┌────────┘          │          └────────────┐
            ▼                   ▼                       ▼
    ┌───────────────┐  ┌───────────────┐    ┌───────────────┐
    │  Shard 1      │  │  Shard 2 ... 16│    │  Enterprise    │
    │  (small/med   │  │                │    │  dedicated     │
    │   tenants;    │  │                │    │  shards (1     │
    │   pool model) │  │                │    │  per tenant)   │
    └───────────────┘  └───────────────┘    └───────────────┘
            │                   │                       │
            └────────┬──────────┴───────────────────────┘
                     │ CDC streams
                     ▼
            ┌───────────────────────────┐
            │  Search index (ES,        │
            │   Elasticsearch)          │
            │  Analytics warehouse (BQ, │
            │   BigQuery)                │
            │  for cross-tenant queries  │
            └───────────────────────────┘
```

The OLTP path stays clean (per-tenant sharded). Cross-tenant data is aggregated downstream.

---

## Key Takeaways

- **The partition key is a contract with your queries — forever.** Queries that include it hit one shard (fast); queries that don't scatter-gather across all shards (slow). It must be present in your hot-path queries by design, and it's hard to change later — treat it as an architectural constraint / ABI (Application Binary Interface), not a tunable.
- **Choose the partition key by analyzing query patterns first.** A senior engineer asks "what will the hot queries look like?" before "what columns do we need?" — the key falls out of the access-pattern analysis. The key must distribute load evenly, be present in hot queries, co-locate naturally-joined data, and be stable.
- **Hot keys break partitioning entirely.** A disproportionately loaded partition is a single-shard (single-thread) bottleneck no cluster capacity can fix. Design for them: bucketing/composite keys, caching, replication of hot keys, application-level special-casing. Monitor per-shard load as a primary scaling metric.
- **Cross-shard queries are second-class citizens.** Joins, transactions, and aggregations across shards are dramatically more expensive than local equivalents. Design the schema to keep hot queries on one shard; denormalize, replicate small reference data, push cross-shard work to batch jobs/warehouses. Test cross-shard queries under realistic shard counts — what works in single-shard dev scatters in production.
- **Cross-shard transactions (2PC) are rarely worth it.** Latency multiplied, conflicts amplified, locks held on failure. Use sagas with idempotent operations instead. Avoid by design, not by exception.
- **Range partitioning has write hotspots** for sequential data (timestamps, autoincrement IDs all hit the newest partition). Hash distributes evenly but scatters range queries. **Composite (hash + range)** often combines the best of both.
- **Consistent hashing minimizes rebalance movement** (only ~1/N of keys move when adding a node); vnodes refine this and spread a failed node's load. **Rebalancing is slow and impactful** at scale (petabyte rebalances take days) — throttle aggressively and plan capacity well ahead.
- **Distinguish logical from physical partition counts.** Many small shards beat few large ones for operational flexibility; powers of 2 ease doubling. Start with many logical partitions (e.g. 64-128) even on few physical nodes so routing stays stable as you scale.
- **Design schemas as if sharded from day one**, even on a single node — always include a partition-eligible key, avoid full-dataset queries. Then sharding is an operational migration, not an application rewrite ("shard later" is the antipattern). The right partitioning makes your system look like N independent systems: each partition's failure, load, and scaling are its own.

## Interview angle

- **"How would you shard a social network's user data?"** Hash by user ID, watch for celebrity accounts, replicate small reference data, accept cross-user queries as expensive.
- **"What's consistent hashing?"** Tests algorithm literacy; bonus for explaining vnodes and minimal-movement properties.
- **"How would you handle a hot partition?"** Bucketing, caching, application-level special-casing.
- **"Why not just shard by random number?"** Distribution is even, but every query without a key scatters — useless in practice.
- **"How do you do cross-shard transactions?"** Avoid them; use sagas; pre-aggregate.
- **"Range vs hash partitioning?"** Range for time-series and ordered queries; hash for even distribution; composite often best.
- **"What's the operational cost of sharding?"** Rebalancing, schema migrations multiplied by N, cross-shard queries, monitoring complexity.
- **Common traps:** recommending sharding without considering query patterns; believing sharding is "free scalability"; not knowing about hot keys; recommending 2PC across shards.
