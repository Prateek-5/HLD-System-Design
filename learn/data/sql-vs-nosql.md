# SQL vs NoSQL — How to Actually Decide

## A. Intuition First
Stop framing "SQL vs NoSQL" as a war. Ask: *what shape is my data, what are my access patterns, what consistency do I need, what scale do I expect?*

## B. Mental Model — The decision checklist
| If you need… | Lean toward |
|---|---|
| Complex joins, strict schema, transactions | **SQL** |
| Flexible/evolving schema, document nesting | **Document NoSQL** (Mongo) |
| Fast key lookup, cache, sessions | **Key-Value** (Redis, DynamoDB) |
| Write-heavy time-series at scale | **Wide-column** (Cassandra) |
| Graph traversal (friends-of-friends) | **Graph** (Neo4j) |
| Metrics / time-series | **TSDB** (Influx, Timescale) |
| ACID across multiple entities | **SQL** (still the default) |

## C. Internal Working — Why they differ
SQL uses a B-tree row-store and pessimistic schema; joins via the optimizer; ACID via 2PL or MVCC.

NoSQL varies:
- Document: BSON storage, per-doc indexes.
- KV: hash or LSM, nothing else.
- Wide-column: LSM, append-heavy.
- Graph: adjacency lists / index-free adjacency.

## D. Visual Representation
```
Workload:          Complex joins       High write rate    Key lookups     Graph
                        ↓                    ↓                 ↓             ↓
Pick:                  SQL               Wide-col / Doc      KV           Graph
```

## E. Tradeoffs — side-by-side
| Axis | SQL | NoSQL |
|---|---|---|
| Schema | Strict | Flexible |
| Scale pattern | Vertical, then read replicas, then shard | Horizontal by design |
| Consistency | ACID | BASE (varies; Dynamo/Mongo support ACID options) |
| Joins | First-class | Denormalized / app-side |
| Query language | Universal SQL | Per-DB DSL |
| Tooling maturity | Deepest | Newer but broad |

## F. Interview Lens
- Expect: "design X. Pick a DB. Justify."
- The right answer is almost always a **combination**:
  - Postgres for orders/users (transactional core),
  - Cassandra/DynamoDB for time-series events,
  - Redis for cache/sessions,
  - Elasticsearch for search,
  - S3 for blobs.

Pitfalls:
- Dogma ("we use Mongo for everything").
- Picking before knowing access patterns.
- Ignoring the operational cost of polyglot persistence.

## G. Real-World Mapping
- **Instagram**: Postgres for accounts + Cassandra for feed + Redis for cache.
- **Uber**: MySQL/Postgres for financial core + Cassandra for rider/driver tracking.
- **Netflix**: Cassandra everywhere, with MySQL for billing.
- **Stack Overflow**: Postgres, famously, even at scale — with heavy caching.

## H. Questions
**Beginner**: Three reasons to pick SQL. Three reasons NoSQL.
**Intermediate**: Design the DB layer for a hotel booking site. Which DBs? Why each?
**Advanced**: Migrate a large SQL table to Cassandra. What breaks? What do you rewrite?

## I. Mini Design — "Pick DBs for an e-commerce site"
- **Orders, inventory, payments**: Postgres (ACID).
- **Product catalog**: Postgres OR Mongo (depends on variant complexity).
- **Sessions, cart cache**: Redis.
- **Click events, recommendations input**: Kafka → Cassandra / S3.
- **Search**: Elasticsearch.
- **Images**: S3 + CDN.

## J. Cross-Topic Connections
- [SQL](sql-databases.md), [NoSQL](nosql-databases.md), [CAP](cap-theorem.md), [ACID/BASE](acid-base.md).

## K. Confidence Checklist
- [ ] Can pick a DB for each tier of a real architecture.
- [ ] Knows polyglot persistence is normal.

### Red flags
- ❌ "Use X for everything."

## L. Potential Gaps & Improvements
- **Cost-per-ops comparison** — comparing RDS (Relational Database Service) vs DynamoDB pricing at scale; matters because the "cheaper" engine flips depending on read/write volume and storage.
- **Migration strategies (SQL↔NoSQL)** — planned ways to move data between a relational and a non-relational store without downtime; central to "we outgrew our database" questions. (→ see Advanced Questions)
- **Dual-write** — the app writes the same change to both the old and new database at once during a migration; simple but risky because the two writes can drift if one fails.
- **CDC (Change Data Capture)** — tools like Debezium stream every row change out of a database so a second store stays in sync; the safer alternative to dual-write for keeping two stores consistent.

**🔧 How to close:** Run `docker run --rm -p 8000:8000 amazon/dynamodb-local`, then with the AWS CLI create one table, `put-item` a few records, and `query` them — feel the no-JOIN, single-key access pattern firsthand, then contrast it by modeling the same data in a quick `sqlite3 demo.db` schema with a JOIN.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 💰 Gap 1 — Cost-per-Operation at Scale
- 🔹 **What it is**: Comparing the real bill of a managed relational engine (e.g. RDS) versus a serverless NoSQL one (e.g. DynamoDB) as read/write/storage volume grows.
- 🔹 **Why it matters**: The "cheaper" engine flips depending on workload — provisioned capacity wins for steady high throughput, pay-per-request wins for spiky/low traffic. Picking wrong can 10× the bill.
- 🔹 **Connection**: This file's decision checklist (§B) and e-commerce mini-design (§I) pick engines by data shape and access pattern — cost is the fourth axis interviewers add once the shape fits.
- 🔹 **When needed**: 🟡 **Mid-level** — common in product/architecture rounds and any "why did you choose this DB?" follow-up.
- 🔹 **Intuition**: Renting a car. A flat daily rate (provisioned) is cheaper if you drive all day every day; per-mile pricing (on-demand) is cheaper for the occasional errand. Your mistake is choosing before you know how much you'll drive.
- 🔹 **If you go deeper**: Read the AWS DynamoDB capacity-modes docs (on-demand vs provisioned + auto-scaling) and model a real workload in the AWS Pricing Calculator against an RDS instance of equivalent throughput.
- 🔹 **Interview hook**: *"When does DynamoDB become more expensive than Postgres?"* → at sustained, predictable high throughput where provisioned RDS amortizes a fixed instance cost, while DynamoDB charges per request/RCU-WCU and storage; bursty or low-volume traffic favors DynamoDB's pay-per-use.

---

#### 🔀 Gap 2 — Zero-Downtime Migration Strategies (SQL ↔ NoSQL)
- 🔹 **What it is**: Planned techniques to move data between a relational and a non-relational store while the app keeps serving traffic.
- 🔹 **Why it matters**: This is the backbone of every "we outgrew our database" question — the interviewer wants a phased plan, not a `pg_dump` into Mongo.
- 🔹 **Connection**: §H's Advanced question ("Migrate a large SQL table to Cassandra — what breaks?") and the Cassandra/Postgres split in §G are exactly the scenarios these strategies solve.
- 🔹 **When needed**: 🟡 **Mid-level** for the high-level phases; 🔴 **Senior** for designing the cutover and rollback safely.
- 🔹 **Intuition**: Replacing a bridge while cars keep crossing. You build the new bridge alongside, divert a few cars to test it, then shift traffic lane by lane — never closing the road.
- 🔹 **If you go deeper**: Study the **expand/contract (parallel-change)** pattern and the **strangler fig** migration; read AWS DMS (Database Migration Service) docs for a concrete continuous-replication tool.
- 🔹 **Interview hook**: *"How do you migrate a live table with zero downtime?"* → backfill historical data, dual-read/dual-write or CDC to keep stores in sync, shadow-read to verify parity, flip reads to the new store behind a flag, then decommission the old one.

---

#### ⚖️ Gap 3 — Dual-Write vs CDC: Keeping Two Stores Consistent
- 🔹 **What it is**: Two ways to keep an old and new store in sync during migration — **dual-write** (app writes to both) versus **CDC (Change Data Capture)** (a tool like Debezium streams every committed row change to the second store).
- 🔹 **Why it matters**: Dual-write looks simple but silently drifts when one write fails (no shared transaction); CDC reads the source's commit log, so it inherits the database's own durability and can't half-apply.
- 🔹 **Connection**: Directly extends the migration plan in Gap 2 and the dual-write/CDC bullets in §L — the mechanism you pick decides whether your two stores stay truthful.
- 🔹 **When needed**: 🔴 **Senior** — dual-consistency and log-based replication are infra-level concerns.
- 🔹 **Intuition**: Updating two address books by hand means one gets stale the moment you're interrupted (dual-write). CDC is like a photocopier wired to the original — every edit to the master is automatically copied, in order.
- 🔹 **If you go deeper**: Read the Debezium architecture docs and the "transactional outbox" pattern (write the event in the same transaction, let CDC ship it) to fix dual-write's atomicity hole.
- 🔹 **Interview hook**: *"Why is dual-write risky and what's the fix?"* → the two writes aren't atomic, so a partial failure leaves the stores divergent; use a transactional outbox + CDC so the change and its propagation share one commit.

---

#### 🧩 Gap 4 — Operating Polyglot Persistence
- 🔹 **What it is**: The day-2 reality of running several databases at once (Postgres + Cassandra + Redis + Elasticsearch) and keeping them coherent.
- 🔹 **Why it matters**: §F flags "ignoring the operational cost of polyglot persistence" as a pitfall — choosing five engines is easy; backing up, monitoring, securing, and reconciling five engines is the actual job.
- 🔹 **Connection**: This file repeatedly recommends combinations (§F, §G, §I). This gap is the hidden cost of taking that advice.
- 🔹 **When needed**: 🔴 **Senior** — surfaces in staff/architect rounds and ownership discussions.
- 🔹 **Intuition**: A restaurant kitchen with a wood oven, a fryer, and a sous-vide bath. Each makes one dish brilliantly, but now you maintain three appliances, three cleaning routines, and staff trained on all three.
- 🔹 **If you go deeper**: Read about **eventual consistency across stores** (e.g. cache invalidation in Redis after a Postgres write) and Martin Kleppmann's *Designing Data-Intensive Applications* ch. on derived data and the "single source of truth" principle.
- 🔹 **Interview hook**: *"You proposed four databases — how do you keep them consistent?"* → designate one system of record, derive the others via CDC/event streams, and accept (and bound) eventual-consistency lag rather than dual-writing everywhere.

---

### 🏆 Start here if you have limited time
1. **Zero-downtime migration strategies** — the most-asked "we outgrew our DB" scenario; high payoff per minute.
2. **Cost-per-operation at scale** — turns a hand-wavy "we chose DynamoDB" into a defensible, quantified answer.

---

### 🧭 Suggested Deep Dive Order
1. **Cost-per-operation at scale** (~45 min; sharpens every "why this DB?" answer).
2. **Zero-downtime migration strategies** (~1h; unlocks the classic advanced question in §H).
3. **Dual-write vs CDC** (~1h; the mechanism behind safe migrations — senior signaling).
4. **Operating polyglot persistence** (~45 min; the day-2 cost that interviewers probe for ownership).
