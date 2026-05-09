# Postgres Internals — A Deep Dive

> *"PostgreSQL is the most under-appreciated piece of infrastructure in production. Thirty years of engineering produced a database that does almost everything correctly, scales further than people expect, and exposes more knobs than any single operator can master. Understanding its internals — the process model, MVCC implementation, vacuum mechanics, planner, replication — is what separates 'I use Postgres' from 'I operate Postgres at scale.'"*

---

## Topic Overview

PostgreSQL is the workhorse open-source relational database. Used at every scale from startups to Apple. Its design — process-per-connection, MVCC with vacuum, cost-based planner, WAL-based recovery, streaming replication — is the result of three decades of careful engineering.

This artifact extends the corpus's MVCC, WAL, indexing, query optimization, and replication pieces with Postgres-specific detail. Concepts already covered are summarized; what's unique to Postgres gets the focus.

This is the topic where general database concepts become concrete. Operating Postgres at scale demands understanding the specifics: how autovacuum works (and fails); when planner statistics drift; what `synchronous_commit` actually does; why you don't put 50,000 tables in one database.

---

## Intuition Before Definitions

Imagine an old library that started with a few patrons and grew over thirty years.

The library has its own approach to operations. Each visitor (connection) gets a personal librarian (process). Books are versioned: when a book is updated, a new version is shelved alongside the old; old versions are eventually cleaned up by a periodic janitor (vacuum).

The librarians follow a careful logbook (WAL): every action recorded before the action is performed. A fire wouldn't lose any committed work — the logbook tells you what happened.

Other libraries (replicas) tail the master library's logbook, applying each entry. They serve readers who don't need the absolute latest information.

That's Postgres. Process per connection; MVCC with vacuum; WAL-based recovery; streaming replication. The architecture is internally coherent; understanding one part illuminates the others.

---

## Historical Evolution

**Era 1 — Berkeley POSTGRES (1986).**
Michael Stonebraker's research project. Object-relational. PostQUEL query language.

**Era 2 — PostgreSQL (1996+).**
Open-source community fork. Switched to SQL. Steady evolution.

**Era 3 — Production maturity (2000s).**
WAL-based recovery; full SQL compliance; replication; performance improvements.

**Era 4 — Streaming replication (9.0, 2010).**
Built-in physical replication. Game-changer for HA.

**Era 5 — Logical replication, JIT, parallel query (10.x-12.x).**
Modern features: JIT compilation, declarative partitioning, logical replication, parallel queries.

**Era 6 — Modern Postgres (14+).**
Performance work continues; JSON improvements; better partitioning; enhanced replication.

The pattern: each release adds capability without breaking compatibility. Postgres is the slowest-moving database but compounds.

---

## Core Mental Models

**1. Process per connection.**
Each connection is an OS process. Cheap to fork; not free. Hundreds of connections is fine; thousands stress the system. Use a connection pooler.

**2. MVCC with vacuum.**
Versions accumulate; vacuum reclaims. Long-running transactions block vacuum; bloat accumulates. The #1 operational concern.

**3. WAL is the truth.**
Every change is WAL-logged before applied. Recovery is replay. Replication ships WAL.

**4. The planner is statistics-driven.**
Run `ANALYZE` after bulk loads. Watch for plan flips when stats drift.

**5. Postgres is configurable; defaults are conservative.**
Production tuning matters. Not "set and forget."

---

## Deep Technical Explanation

### The process architecture

When a client connects, Postgres forks a new "backend" process to handle that connection. Other processes:

- **Postmaster**: the parent; accepts new connections.
- **Backend**: per-connection.
- **Background writer**: flushes dirty buffers.
- **Checkpointer**: triggers checkpoints (writes all dirty buffers).
- **WAL writer**: flushes WAL buffers.
- **Autovacuum launcher / workers**: vacuum dead tuples.
- **Stats collector**: accumulates per-table statistics.
- **Replication processes**: WAL sender/receiver.

Implications:
- Per-connection memory (~10-20MB minimum).
- Connection setup is expensive (fork + process init).
- Connection pooler (PgBouncer, pgcat) is essential past ~100 connections.
- Process count is visible in `ps`; useful for diagnosis.

### Connection pooling

Without a pooler:
- Each app connection = one Postgres process.
- 1000 app instances × 5 connections each = 5000 backends. Memory + scheduler overhead.

With PgBouncer:
- Many app connections share fewer Postgres backends.
- Pooling modes: session, transaction, statement (most aggressive).
- Transaction-pooled mode is typical: app connections share Postgres backends, multiplexed per transaction.

Impact: 10-100× connection scalability.

### MVCC details (Postgres-specific)

(See [MVCC & Isolation Levels](./mvcc-and-isolation-levels.md) for general concepts.)

Each tuple has:
- `xmin`: txid that created it.
- `xmax`: txid that deleted/superseded it (0 if alive).
- `cmin`/`cmax`: command IDs within transaction.
- `ctid`: physical (page, offset).

Visibility rule (simplified): tuple visible to snapshot S if `xmin` committed before S and (`xmax = 0` or committed after S or aborted).

A snapshot is essentially `(xmax_committed_at_snapshot, in_progress_txids_at_snapshot)`. Cheap to take.

### Vacuum mechanics

Vacuum's jobs:
1. **Reclaim dead tuples**: their space can be reused.
2. **Update statistics** (with `ANALYZE`).
3. **Freeze old txids**: prevent transaction-ID wraparound.
4. **Update visibility map**: enables index-only scans.

Vacuum types:
- **Lazy vacuum** (default): in-place; doesn't lock the table for long.
- **Vacuum FULL**: rewrites the table; reclaims space; takes exclusive lock; *don't run this in production*.

Autovacuum:
- Background workers triggered by tuple turnover (`autovacuum_vacuum_scale_factor` threshold).
- Per-table tunable.
- Can fall behind under heavy write load.

The famous Postgres wraparound:
- Txid is 32-bit (~4 billion). After ~2 billion, it wraps.
- Tuples must be "frozen" (their xmin marked permanent) before wraparound.
- If vacuum can't keep up, Postgres refuses writes to protect itself.
- This has caused major production outages (Sentry's famous one).

Modern Postgres has 64-bit transaction IDs in some contexts; freezing is still a concern at very high write rates.

### Tuple bloat

Updates create new tuples, leave old ones. Vacuum reclaims old space *for reuse* but doesn't shrink the file. Heavy update tables can grow much larger than their live data.

Diagnosis: `pgstattuple` extension; `pg_stat_user_tables.n_dead_tup`.

Mitigation:
- Aggressive autovacuum (lower thresholds).
- HOT (Heap-Only Tuple) updates: when no indexed column changes, update can stay on the same page; indexes don't need updating.
- `fillfactor` < 100% leaves space on each page for HOT updates.
- `pg_repack` for online compaction (Postgres extension).

### The query planner

Cost-based optimizer:

```sql
EXPLAIN ANALYZE
SELECT * FROM orders WHERE customer_id = 42 AND status = 'paid';
```

Planner considers:
- **Filtering**: how selective is each predicate?
- **Index choice**: which index best fits?
- **Join order**: which order minimizes intermediate result size?
- **Join algorithms**: nested loop, hash join, merge join.
- **Parallelism**: split work across worker processes?

Statistics:
- `n_distinct`: distinct values per column.
- Most-common-values (MCV) list.
- Histogram for distribution.
- `correlation`: physical-to-logical ordering (helps decide index usefulness).

Maintained by `ANALYZE` (manual or autovacuum-triggered).

### Extended statistics

For correlated columns, Postgres 10+ supports CREATE STATISTICS:

```sql
CREATE STATISTICS users_country_state ON country, state FROM users;
```

Now the planner knows country and state are correlated; doesn't multiply independent estimates. Fixes a major class of misestimates.

### Indexes

Postgres index types:
- **B-tree** (default): general-purpose.
- **Hash**: equality only; usually not useful.
- **GIN**: arrays, JSONB, full-text.
- **GiST**: geometric, custom types, range types.
- **SP-GiST**: space-partitioned GiST.
- **BRIN**: block range; for sequentially-correlated columns.
- **BLOOM**: extension; bloom filter for multi-column equality.

Indexes are themselves MVCC-aware. They contain pointers to tuples; the executor checks tuple visibility.

`CREATE INDEX CONCURRENTLY`: builds without blocking writes. Slower; required for production schema changes.

### Partitioning

Declarative partitioning (Postgres 10+):

```sql
CREATE TABLE measurements (
    id SERIAL,
    device_id INTEGER,
    measured_at TIMESTAMP,
    value FLOAT
) PARTITION BY RANGE (measured_at);

CREATE TABLE measurements_2024_q1
    PARTITION OF measurements
    FOR VALUES FROM ('2024-01-01') TO ('2024-04-01');
```

Benefits:
- Partition pruning (only relevant partitions scanned).
- Detach old partitions instantly (cheap retention).
- Per-partition operations.

Use cases: time-series, multi-tenant. Limits: cross-partition uniqueness is hard; foreign keys to partitioned tables are complex.

### TOAST

Large field values (typically >2KB) are stored out-of-line in TOAST (The Oversized-Attribute Storage Technique) tables. Compressed by default.

Implications:
- Tables with large fields have invisible TOAST tables.
- Operations on TOASTed columns have I/O overhead.
- TOAST table size can dwarf the main table.

### WAL and replication

(See [WAL & Crash Recovery](./wal-and-crash-recovery.md) for general concepts.)

Postgres WAL:
- Files in `pg_wal/` directory; 16MB segments by default.
- LSN (Log Sequence Number) is the position.

Replication:
- **Streaming replication**: replica tails primary's WAL.
- **Logical replication**: replicates as logical changes (INSERT/UPDATE/DELETE).
- **Synchronous**: primary waits for replica ack.
- **Asynchronous** (default): primary commits immediately; replica catches up.

`synchronous_commit` settings:
- `on`: WAL fsynced locally before commit returns.
- `off`: commit returns immediately; ~milliseconds at risk in a crash.
- `remote_apply`: wait for replica to apply.
- `remote_write`: wait for replica to receive (not apply).

### Failover

Manual or via tools:
- **Patroni**: HA via etcd or Consul.
- **pg_auto_failover**: native HA tool.
- **Cloud-managed**: RDS, Aurora, Cloud SQL handle failover.

Considerations:
- Async replication: data loss equal to lag.
- Sync replication: zero loss; potential availability impact if replica is down.
- Failover triggers: process death, network partition.

### Logical replication

Replicates logical changes; possible across versions; possible to subset tables.

Use cases:
- Major version upgrades (replicate to new version; cut over).
- ETL to data warehouse.
- Multi-region with selective replication.

Limitations:
- DDL not replicated (must run on both sides).
- Sequences need special handling.
- Logical replication slots can fill disk if subscriber is down.

### Performance tuning

Key parameters:
- `shared_buffers`: 25% of RAM typical.
- `effective_cache_size`: estimate of total OS + DB cache; ~75% of RAM.
- `work_mem`: per-query operation memory; tuning affects sort/hash performance.
- `maintenance_work_mem`: for VACUUM, CREATE INDEX, etc.
- `max_connections`: upper bound; use a pooler.
- `wal_buffers`: WAL buffering; default usually fine.
- `checkpoint_timeout`, `max_wal_size`: checkpoint frequency.
- `autovacuum_vacuum_scale_factor`: how aggressively autovacuum runs.

Heuristic: Don't reach for tuning until you've measured a problem.

### Monitoring

Essential:
- `pg_stat_activity`: current sessions; long-running transactions.
- `pg_stat_user_tables`: per-table stats (dead tuples, vacuum age).
- `pg_stat_user_indexes`: per-index usage (find unused indexes).
- `pg_stat_statements` extension: aggregated query statistics.
- `pg_locks`: current locks; deadlock diagnosis.
- WAL volume; replication lag; connection count.

External: pg_stat_kcache (kernel-level stats), pgwatch2, Datadog/Grafana dashboards.

### Common production issues

**Connection limit exhaustion.** App connects directly without pooler; connection storms; new app instances can't connect.

**Vacuum-blocking long transactions.** Forgotten `BEGIN`; bloat accumulates; performance degrades.

**Wraparound emergency.** Autovacuum can't keep up; database refuses writes. Recovery is hours of single-user vacuum.

**Slow query, planner-related.** Stale statistics; planner picks bad plan; latency spike. Fix: `ANALYZE`.

**Replication lag explosion.** Replica disk slow; falls behind; failover would lose data; primary's WAL accumulates.

**Index bloat.** Index size grows beyond table; performance degrades. `REINDEX CONCURRENTLY` to recover.

---

## Real Engineering Analogies

**The library with periodic stocktaking.**
The library always has more books than expected because returned books aren't removed; the staff periodically does stocktake (vacuum). If staff is short or distracted (long-running transactions), the library overflows. Routine stocktaking is mandatory, not optional.

**The bank's transaction journal.**
A bank records every transaction in a journal (WAL) before applying. The journal is the source of truth; the account balances are derived. Branches (replicas) maintain their own copies by tailing the journal. This system has worked for centuries.

---

## Production Engineering Perspective

What goes wrong:

- **The connection storm.** App scaled to 100 instances; each opens 50 connections. 5000 connections × 20MB = 100GB of overhead. Recovery: introduce PgBouncer.
- **The wraparound near-miss.** Vacuum disabled "for performance." TXID approaches wraparound. Database emergency-vacuums for hours. Lesson: don't disable autovacuum.
- **The plan flip.** Stats drift after migration; planner switches from index scan to seq scan; query goes from 5ms to 5s. Fix: `ANALYZE`.
- **The sync-replication latency.** Sync replication enabled across regions; commit latency 200ms instead of 5ms. Mitigation: only sync to local replica; async to remote.
- **The orphaned slot.** Logical replication slot for a deleted subscriber; WAL accumulates; disk fills. Mitigation: monitor `pg_replication_slots`; drop unused.
- **The TOAST surprise.** Large JSON column; TOAST table is 10× the heap; queries slow because of TOAST decompression. Mitigation: query without large columns; consider separate table.

The senior Postgres operator's habits:
- **Connection pooler** mandatory.
- **Monitor `pg_stat_activity`** for long transactions.
- **`ANALYZE`** after bulk operations.
- **Watch replication lag**.
- **Tune autovacuum** for workload.
- **`pg_repack`** for periodic compaction.

---

## Failure Scenarios

**Scenario 1 — The wraparound.**
Autovacuum tuned too gently; high write rate. TXID approaches 2 billion. Database emergency-vacuums; refuses writes for safety. 6 hours of single-user mode. Recovery, plus permanent autovacuum tuning.

**Scenario 2 — The pgbouncer behavior surprise.**
Transaction-pooling mode; app code uses session-level features (prepared statements, temporary tables, advisory locks). Random failures. Mitigation: use compatible features; or session pooling.

**Scenario 3 — The replication slot disk fill.**
Logical replication slot for an obsolete subscriber. WAL accumulates indefinitely. Disk fills; database stops. Recovery: drop the slot; `pg_replication_slots` audit.

**Scenario 4 — The slow query after deploy.**
Migration loaded 100M new rows; statistics not updated. Planner thinks the table is small; chooses nested loop on huge data. Query takes hours. Fix: `ANALYZE`.

**Scenario 5 — The synchronous-replication availability hit.**
Sync replication to one replica. Replica's network blips. Primary blocks all commits waiting for ack. Production stalls. Mitigation: timeout to drop slow sync replica; multi-replica sync.

---

## Performance Perspective

- **Single connection throughput**: thousands of small queries/sec.
- **Concurrent throughput**: scales with cores until contention; 10K+ commits/sec on good hardware.
- **WAL bandwidth**: hundreds of MB/sec on NVMe.
- **Replication lag**: sub-second typical; can spike under load.

---

## Scaling Perspective

- **Vertical**: scales to large machines; tens of TB databases.
- **Read replicas**: trivially scale reads.
- **Sharding**: not native; Citus extension or application-level.
- **Logical replication**: cross-version, selective.
- **Cloud-managed**: RDS, Aurora handle much of the operations.

---

## Cross-Domain Connections

- **MVCC**: Postgres is MVCC-canonical. (See [mvcc-and-isolation-levels.md](./mvcc-and-isolation-levels.md).)
- **WAL**: Postgres WAL implementation. (See [wal-and-crash-recovery.md](./wal-and-crash-recovery.md).)
- **Indexing**: Postgres has rich index types. (See [indexing-and-storage-engines.md](./indexing-and-storage-engines.md).)
- **Query Optimization**: Postgres planner. (See [query-optimization-and-execution-plans.md](./query-optimization-and-execution-plans.md).)
- **Replication**: streaming and logical. (See [replication-strategies.md](./replication-strategies.md).)
- **DR**: PITR via WAL. (See [disaster-recovery-and-rto-rpo.md](../system-failures/disaster-recovery-and-rto-rpo.md).)

The unifying observation: **Postgres is a coherent system. The pieces — process model, MVCC, WAL, planner, replication — fit together; understanding one informs the others.**

---

## Real Production Scenarios

- **Sentry's wraparound near-miss**: famous incident; required reading.
- **GitLab's data loss**: backup/replication misconfiguration; documented postmortem.
- **Heap's analytics on Postgres**: extensive engineering on long-transaction blocking vacuum.
- **Many startup-to-scale migrations**: PostgreSQL handles surprisingly far before you need to migrate.

---

## What Junior Engineers Usually Miss

- That **vacuum is mandatory**.
- That **long transactions block vacuum**.
- That **connection limits are real**.
- That **`ANALYZE`** after bulk loads.
- That **synchronous_commit has options**.
- That **replication slots can fill disk**.

---

## What Senior Engineers Instinctively Notice

- They **monitor `pg_stat_activity`** for long transactions.
- They **use connection poolers**.
- They **tune autovacuum** for workload.
- They **read execution plans**.
- They **monitor replication lag**.
- They **plan PITR** as part of DR.

---

## Interview Perspective

What gets tested:

1. **"How does Postgres MVCC work?"** Tuple versions; visibility; vacuum.
2. **"What's autovacuum?"** Background reclamation.
3. **"How does Postgres replicate?"** WAL streaming; sync vs async.
4. **"What's the planner doing?"** Statistics + cost model.
5. **"Why use a connection pooler?"** Process-per-connection limits.

Common traps:
- Disabling autovacuum.
- No connection pooler.

---

## 20% Knowledge Giving 80% Understanding

1. **Process per connection** — pool with PgBouncer.
2. **MVCC with vacuum** — long transactions are the enemy.
3. **WAL is durable** — synchronous_commit is the boundary.
4. **Streaming replication** for HA.
5. **Logical replication** for cross-version.
6. **Cost-based planner** — `ANALYZE` after bulk.
7. **Index types matter** — B-tree, GIN, GiST, BRIN.
8. **TOAST** for large fields.
9. **Wraparound is real** — autovacuum mandatory.
10. **Monitoring** is non-optional.

---

## Final Mental Model

> **Postgres is what an open-source database looks like after thirty years of disciplined engineering. Its architecture is internally coherent; its trade-offs are documented; its pitfalls are well-known. Operating it well is a discipline; operating it badly is the cause of most "Postgres is slow" stories.**

The senior Postgres operator respects vacuum, uses a connection pooler, tunes autovacuum, monitors lag, plans PITR. The database rewards discipline; the alternative is slow degradation.

That's Postgres internals. That's the workhorse open-source RDBMS. That's the database under more production systems than people realize — handling far more than its critics expect, with the right operational care.
