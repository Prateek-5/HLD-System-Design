# MVCC & Isolation Levels

> *"Concurrency is not a feature you add to a database. It's a war the database has been quietly fighting with itself since the first time two transactions tried to touch the same row."*

---

## Topic Overview

MVCC — Multi-Version Concurrency Control — is the answer to a question that, on the surface, looks innocent: *"What should a database do when two people try to read and write the same row at the same time?"*

The naive answer is locking. Make readers wait for writers. Make writers wait for readers. This works. It also collapses under the slightest production load, because real workloads are not 50% reads and 50% writes — they are 95% reads, 5% writes, and the moment readers start blocking on writers, your p99 latency falls off a cliff and your support inbox lights up.

MVCC exists because somebody, decades ago, looked at this and said: *what if readers never had to wait?* What if every write produced a *new version* of the row, and every reader got to see a consistent snapshot of the database as it existed at some moment in the past — without holding a single lock?

That single idea — versions instead of locks for reads — is the reason Postgres, Oracle, MySQL/InnoDB, MongoDB WiredTiger, CockroachDB, and almost every serious modern database has converged on the same architecture. It's the reason your `SELECT` doesn't block, the reason `pg_dump` can run on a busy primary, and the reason long-running analytical queries don't bring OLTP traffic to its knees.

Isolation levels are the *user-facing knobs* on top of this machinery — the contract between you and the database about which kinds of concurrency anomalies you're willing to tolerate in exchange for performance.

---

## Intuition Before Definitions

Forget transactions for a second. Imagine a wiki.

Every time someone edits a page, the wiki doesn't *overwrite* the page — it stores a new revision and bumps the version number. If you start reading the page at 10:00:00 and someone edits it at 10:00:01, you still see the version that existed at 10:00:00 until you refresh. You and the editor are not fighting for a lock on the page. You're each looking at a different snapshot of history.

That's MVCC. The database is a wiki. Rows have versions. Transactions read from a *snapshot* — a consistent view of "what the database looked like at a specific instant" — and that snapshot doesn't change underneath them no matter how many other transactions commit in the meantime.

The hard part isn't the idea. The hard part is:

- How do you efficiently store all those versions?
- How do you decide which version a given transaction should see?
- How do you eventually garbage-collect old versions before they eat your disk?
- What happens when two transactions try to *write* the same row?
- And how do you reason about *which anomalies are still possible* even with snapshots?

That last question is the entire field of isolation levels.

---

## Historical Evolution

The path here is a story of pain.

**Era 1 — Strict two-phase locking (2PL).**
Every read takes a shared lock; every write takes an exclusive lock; you hold all locks until commit. Beautifully correct. Operationally a disaster. Long-running reports lock out OLTP traffic. Deadlocks multiply. The database spends more time managing the lock table than executing queries. DBAs in the 80s and 90s lived in fear of `sp_lock`.

**Era 2 — Read committed without snapshots.**
Drop read locks early; only hold write locks to commit. Better throughput, but now you get *non-repeatable reads* — the same `SELECT` inside one transaction returns different rows on the second execution, because someone committed in between. This becomes the de facto default for many databases (still is for Postgres) and the source of an entire genre of subtle bugs.

**Era 3 — MVCC arrives.**
Postgres (descended from Berkeley's POSTGRES project) and Oracle independently land on the same idea: store row versions, give each transaction a snapshot, never block readers. Suddenly long reports and OLTP can coexist. Throughput on read-heavy workloads jumps by an order of magnitude.

**Era 4 — Snapshot isolation's hidden bug.**
Engineers initially thought snapshot isolation was equivalent to serializability. It isn't. *Write skew* anomalies — two transactions reading the same set, making disjoint writes that together violate an invariant — slip through. The famous example: two doctors simultaneously taking themselves off-call when the constraint was "at least one must be on call." Each transaction sees a snapshot where the other is still on call. Both commit. Hospital has nobody on call.

**Era 5 — Serializable Snapshot Isolation (SSI).**
Postgres 9.1 ships SSI: snapshot isolation plus runtime detection of dangerous read-write dependency cycles. You get true serializability without the lock-everything pain of 2PL. CockroachDB, FoundationDB, and others build on this lineage.

The lesson: every step of this evolution was driven by *operational pain*, not theoretical elegance. Locking failed under load. Read committed failed correctness. Snapshot isolation failed certain invariants. Each generation traded one pain for a smaller one.

---

## Core Mental Models

**1. Time, not state.**
A transaction doesn't see "the database." It sees "the database *as of* a specific timestamp." Once you internalize this, half of MVCC clicks. Reads are *time travel queries* into immutable history.

**2. Versions are append-only; deletes are tombstones.**
Under the hood, an `UPDATE` is `INSERT new version + mark old version as superseded`. A `DELETE` is `mark this version as dead at time T`. The database is fundamentally an append log with garbage collection.

**3. Visibility is a function, not a property.**
"Is row version V visible?" is computed from (V's creation txid, V's deletion txid, my snapshot, the set of in-flight transactions when my snapshot was taken). It's not a flag on the row. It's a runtime decision per (version, observer) pair.

**4. Isolation levels are a contract about anomalies, not a magic shield.**
They name *which classes of anomalies you tolerate* in exchange for *which performance properties*. Picking one is a business decision dressed up in database vocabulary.

**5. Writers still need to coordinate.**
MVCC lets readers off the hook. It does not let writers off the hook. Two transactions writing the same row still need *some* form of conflict resolution — either first-writer-wins with abort, last-writer-wins with risk, or row-level locking on write paths.

---

## Deep Technical Explanation

### How a row version is stored (Postgres flavor)

Each tuple (row version) carries hidden system columns:

- `xmin`: the transaction ID that created this version.
- `xmax`: the transaction ID that deleted/superseded this version (0 if still alive).
- `ctid`: physical location pointer.

When you update a row:
1. The old tuple's `xmax` is set to your txid.
2. A new tuple is inserted with `xmin = your txid`, `xmax = 0`.
3. Both tuples coexist in the heap. Indexes are updated to point at the new one (with HOT optimizations when possible).

### How visibility is determined

When transaction T with snapshot S looks at a tuple:

```
visible(tuple, S) =
    tuple.xmin committed before S    AND
    tuple.xmin not in S.in_flight     AND
    (tuple.xmax == 0
     OR tuple.xmax aborted
     OR tuple.xmax committed after S
     OR tuple.xmax in S.in_flight)
```

A snapshot S is essentially `(latest_committed_txid_at_snapshot_start, set_of_in_flight_txids_at_snapshot_start)`. That's it. From these two pieces of information the database can answer "did you exist for me?" for any version it encounters.

### Tradeoffs

| Concern | MVCC's answer | The price |
|---|---|---|
| Reader-writer blocking | Eliminated | Storage bloat from versions |
| Writer-writer conflicts | Still need locks/abort | Same as before |
| Long-running reads | Don't block OLTP | But pin old versions, blocking GC |
| Crash recovery | WAL still required | Versions complicate redo/undo |
| Index scans | Must check visibility per tuple | Extra CPU per row returned |

### Scaling implications

- **Storage grows with write volume + retention of oldest snapshot.** A single idle transaction holding a snapshot for hours can prevent vacuuming millions of dead tuples. This is the #1 operational pain of Postgres MVCC.
- **Index bloat** from updates: every update potentially touches every index on the row.
- **Vacuum is on the critical path.** Tune autovacuum or die.

### Concurrency implications

- Readers scale linearly with cores until I/O saturates.
- Writers contend on the row level, not the snapshot level.
- Long readers can starve vacuum, which then can't reclaim space, which then forces emergency vacuums that *do* take aggressive locks. Death spiral.

### Latency implications

- Snapshot creation is cheap (a couple of atomics + copying the in-flight set).
- Visibility check is per-tuple but branch-predictable and CPU-cache-friendly.
- The hidden latency cost is *index maintenance* and *vacuum I/O*.

### Consistency implications

This is where isolation levels live. See the next section.

### Failure modes

- **Transaction ID wraparound.** Postgres txids are 32-bit. After ~2 billion transactions, IDs wrap. If old tuples aren't frozen by vacuum first, the database refuses writes to protect itself. This has taken down major production systems (Sentry's famous incident).
- **Vacuum starvation.** A forgotten `BEGIN` in a connection pool holds a snapshot indefinitely. Bloat explodes.
- **Index-only scans missing visibility info** without a current visibility map, falling back to heap fetches and tanking performance.

---

## Isolation Levels — The Contract Layer

The SQL standard defines four levels by which anomalies they forbid. The truth in real databases is messier and more interesting.

### Anomalies (the vocabulary)

- **Dirty read** — see uncommitted data from another transaction.
- **Non-repeatable read** — same row reads differently the second time within your transaction.
- **Phantom read** — same range query returns different *sets of rows* the second time.
- **Lost update** — two transactions read X, both write X+1, one is silently overwritten.
- **Write skew** — two transactions read overlapping data, write disjoint data, together violate an invariant.
- **Read skew** — read row A at time T1, read row B at T2, A and B no longer satisfy a constraint between them.

### The four levels

| Level | Forbids | Allows | Typical implementation |
|---|---|---|---|
| Read Uncommitted | Nothing useful | Everything including dirty reads | (Mostly historical) |
| Read Committed | Dirty reads | Non-repeatable, phantoms, write skew, lost updates | Per-statement snapshot |
| Repeatable Read / Snapshot Isolation | + non-repeatable, phantoms* | Write skew, lost updates** | Per-transaction snapshot |
| Serializable | Everything | Nothing | SSI / 2PL / serial execution |

*Phantoms: standard SQL allows them at RR; many MVCC implementations forbid them in practice.
**Lost updates: most MVCC implementations detect and abort one of the conflicting writers.

### What different databases actually do

- **Postgres**: Read Committed is the default and uses a fresh snapshot *per statement*. Repeatable Read = true snapshot isolation (one snapshot for the whole transaction). Serializable = SSI.
- **MySQL/InnoDB**: Repeatable Read is default, with a quirk — it uses *consistent reads* for SELECTs but *current reads* with locking for `SELECT ... FOR UPDATE` and DML. This subtle blend prevents some phantoms but creates other surprises.
- **Oracle**: Read Committed and Serializable. Oracle's "Serializable" is actually snapshot isolation — not true serializability. Many shops have shipped to production assuming otherwise.
- **SQL Server**: Defaults to a 2PL-flavored Read Committed. Snapshot isolation must be enabled explicitly.

The takeaway: **the name of the isolation level tells you almost nothing**. You must read your specific database's documentation. The same words mean different things across vendors.

---

## Real Engineering Analogies

**The newspaper archive analogy.**
Imagine a newspaper archive where every article is filed by date. A historian (transaction) walks in and says "I want to research Tuesday's news." The archivist hands them a sealed packet of everything published *up to and including Tuesday*. The historian can read for hours. Meanwhile, journalists keep filing new stories — Wednesday's edition, Thursday's edition. None of that touches the historian's packet. That's snapshot isolation.

Now suppose two historians both pull "Tuesday's packet," each independently writes a *new article* about Tuesday based on what they read, and they both try to file simultaneously. The archive has to decide whose article goes in. That's the write conflict MVCC can't avoid.

**The ledger analogy.**
A bank ledger where you never erase entries — you only append corrections. The current balance is the result of applying every entry up to "now." MVCC is exactly this, scaled to every row in the database, with a garbage-collection process that periodically deletes entries everyone agrees are no longer needed.

---

## Production Engineering Perspective

Things that break at 3am because of MVCC:

- **Long-running transactions on the read replica** that prevent the primary from vacuuming. Symptom: disk usage on primary climbs steadily, query plans get worse, and nobody can figure out why until someone runs `pg_stat_activity` and finds a 14-hour-old `idle in transaction`.
- **`hot_standby_feedback = on`** turned on for safety, then forgotten — replicas now extend the visibility window on the primary, blocking vacuum the same way local long readers do.
- **Bloat on hot tables.** A status table updated every second with 1M rows can grow to 100GB in a week if vacuum can't keep up. Sequential scans go from 200ms to 20s.
- **Index bloat** specifically. Updates touch indexes; indexes don't have HOT optimization. Rebuilding indexes online (`REINDEX CONCURRENTLY`) becomes a routine operational chore.
- **Snapshot too old errors** (Oracle) when a query holds a snapshot longer than undo retention permits.
- **Serializable retry loops.** SSI aborts transactions when it detects dangerous patterns. Your application *must* retry. If it doesn't, your error rate spikes during traffic peaks and your team spends a week blaming the network.

The single most important operational lesson: **monitor the age of your oldest snapshot**. In Postgres: `SELECT max(now() - xact_start) FROM pg_stat_activity WHERE state IN ('idle in transaction', 'active');`. Alert at 5 minutes. Page at 30.

---

## Failure Scenarios

**Scenario 1 — The vacuum apocalypse.**
A reporting tool opens a transaction at 8am for a "long-running migration check" and gets distracted. By 8pm, every UPDATE on the primary has produced a new version that vacuum cannot reclaim because of that one open transaction. Disk fills. Database goes read-only. The team kills the connection — vacuum now has 12 hours of dead tuples to chase, which takes another 6 hours during which performance is degraded.

**Scenario 2 — The serializable surprise.**
A team migrates from MySQL to Postgres, sets isolation to Serializable for safety. Everything works in dev. In prod under load, ~3% of transactions abort with serialization failures. The application has no retry logic. Conversion rate drops 3% overnight. Root cause: SSI is doing its job; the application was built assuming abort-free transactions.

**Scenario 3 — Write skew in the wild.**
A two-step inventory check: read available stock, then decrement if positive. Two simultaneous orders both see "1 in stock," both decrement to 0, then to -1. Inventory goes negative. Snapshot isolation didn't save you — you needed `SELECT ... FOR UPDATE` or serializable, or an explicit constraint.

**Scenario 4 — TXID wraparound.**
A high-write system runs autovacuum at default settings. Vacuum can't keep up. Eventually the database refuses writes to protect itself: "database is not accepting commands to avoid wraparound." Site is down. Recovery requires running an aggressive single-user vacuum for hours.

---

## Performance Perspective

- **Reads:** essentially free under MVCC. A snapshot is a few words of memory. Visibility checks are CPU-cache resident. The bottleneck moves to I/O bandwidth and index efficiency, not concurrency.
- **Writes:** pay the version-creation cost (extra writes to the heap, extra index updates) and any conflict-detection overhead. On contended rows, this can be substantial.
- **Vacuum:** pure overhead, paid in I/O and CPU. The cost is *deferred*, but the deferral is bounded by your tolerance for bloat. There is no free lunch — you pay either at write time (locking) or at clean-up time (vacuum).
- **Cache behavior:** old versions still occupy buffer cache pages until vacuumed. Bloat directly degrades cache hit rate, which is often the *real* reason a "slow" database feels slow.

---

## Scaling Perspective

- **Vertical:** MVCC scales beautifully on a single node up to the limit of the slowest writer or the I/O subsystem. A well-tuned Postgres on modern hardware hits hundreds of thousands of reads/sec on a single primary.
- **Horizontal reads:** physical replicas inherit MVCC properties — readers don't block on each other. But they create a new problem: how do you reconcile snapshots across replicas? Replicas may have a slightly older view than the primary; queries with cross-replica reads see read skew.
- **Horizontal writes:** this is where it gets hard. Distributed MVCC requires a *globally agreed timestamp* for snapshots. Spanner uses TrueTime + atomic clocks; CockroachDB uses HLCs (hybrid logical clocks); FoundationDB uses a centralized sequencer. Each comes with tradeoffs around clock skew, commit latency, and operational complexity.
- **The deep insight:** MVCC at scale is a clock problem. Whoever you trust to assign timestamps becomes your bottleneck or your single point of correctness.

---

## Cross-Domain Connections

- **Distributed systems:** snapshot isolation is the single-node ancestor of *consistency models* in distributed databases. Linearizability is "real time + serializability"; serializability is "snapshot + cycle detection"; eventual consistency is "we gave up on snapshots." Every distributed consistency model has a single-node analog in the isolation hierarchy.
- **Caching:** the "stale read" problem in distributed caches is exactly the same shape as non-repeatable read. Cache invalidation strategies are isolation levels in disguise.
- **JavaScript runtime:** the event loop's task ordering — tasks running atomically, microtasks draining before the next macrotask — is a cousin of snapshot isolation. Each task sees a "snapshot" of the world that doesn't change mid-execution because the runtime is single-threaded.
- **Operating systems:** copy-on-write fork, journaling filesystems, and log-structured merge trees are all expressions of the same idea — *don't mutate; append and version*.
- **Software architecture:** event sourcing is MVCC promoted to the application layer. Same instinct: keep history, derive state.

---

## Real Production Scenarios

- **Sentry, 2015-ish:** TXID wraparound near-miss in Postgres. Forced a deep refactor of vacuum strategy. Now a textbook case for high-write Postgres operations.
- **GitHub MySQL operations:** documented incidents around `gh-ost`-style online schema changes interacting with InnoDB's repeatable-read snapshots and producing confusing replication lag.
- **Heap-style analytics on Postgres:** entire companies have hit walls because long analytical transactions on the primary blocked vacuum until a logical replica architecture was introduced.
- **CockroachDB's serializable-by-default decision:** drove a wave of "why is my transaction retrying" support tickets that Cockroach turned into developer education content.

These aren't edge cases. They're the predictable consequences of MVCC's tradeoffs meeting real workloads.

---

## What Junior Engineers Usually Miss

- That the *default* isolation level in their database is probably **not** what they think it is.
- That `SELECT` doesn't lock — but `SELECT ... FOR UPDATE` does, and using it casually creates lock storms.
- That vacuum isn't a database luxury; it's on the critical path of correctness.
- That snapshot isolation does **not** prevent write skew, and the example almost always sounds like "but surely that can't happen in production" right up until it does.
- That a forgotten `BEGIN` in a connection pool can take down a database 12 hours later.
- That ORM-generated transactions can hold snapshots far longer than the developer realizes.

---

## What Senior Engineers Instinctively Notice

- They check `pg_stat_activity` for the oldest transaction *before* looking at slow queries.
- They reach for `SELECT ... FOR UPDATE` *or* an explicit `SERIALIZABLE` block when they see a read-modify-write pattern, and they wire in retry logic from day one.
- They understand that "the database is slow" usually means "the buffer cache is bloated with dead tuples."
- They treat retention of the oldest snapshot as a first-class capacity-planning metric.
- They know the difference between their isolation level's *standard meaning* and their *vendor's actual behavior* — and they read the docs.
- They design schemas to minimize update frequency on hot rows because they understand the version-creation cost.

---

## Interview Perspective

What interviewers actually want when they ask about isolation:

1. **Can you reason about anomalies from first principles?** Given a workload, can you identify which anomalies it's exposed to and what isolation level prevents them?
2. **Do you understand that MVCC is not free?** A candidate who says "just use MVCC" without mentioning bloat or vacuum has only read the marketing material.
3. **Can you handle the write skew question?** It's the canonical "are they actually senior" filter. Snapshot isolation prevents most things; the candidate who can articulate exactly what it doesn't prevent has thought about this seriously.
4. **Do you know your database's actual defaults?** Bonus points for "Postgres defaults to Read Committed which is per-statement snapshot, MySQL defaults to Repeatable Read which is per-transaction snapshot, and that difference matters."
5. **Can you connect MVCC to distributed consistency?** Staff-level reasoning is recognizing that snapshot isolation is the foundation that distributed databases extend with timestamp protocols.

Common traps:
- Confusing snapshot isolation with serializability.
- Thinking "Repeatable Read" means the same thing in every database (it doesn't).
- Forgetting that writers still need conflict resolution.
- Missing that locks and snapshots can coexist (and frequently do, as in MySQL InnoDB).

---

## Worked Example — Diagnosing Write Skew

A doctors-on-call schedule. Constraint: at least one doctor must always be on call. Two doctors (Alice and Bob) are both currently on call. Each independently decides to take themselves off.

```sql
-- Snapshot Isolation. Both transactions start; both see Alice and Bob on call.

-- Transaction T_alice (in Alice's session):
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM doctors WHERE on_call = true;
-- Returns 2. "Bob is still on call; safe to remove myself."
UPDATE doctors SET on_call = false WHERE name = 'Alice';
COMMIT;

-- Transaction T_bob (in Bob's session, concurrent):
BEGIN ISOLATION LEVEL REPEATABLE READ;
SELECT COUNT(*) FROM doctors WHERE on_call = true;
-- Returns 2 (snapshot doesn't see Alice's pending update).
UPDATE doctors SET on_call = false WHERE name = 'Bob';
COMMIT;

-- Result: nobody on call. Constraint violated.
```

Why this happens: snapshot isolation prevents *concurrent updates to the same row* (one of Alice or Bob's update would conflict if they targeted the same row), but they target *different rows* — Alice updates her row, Bob updates his. Their reads (`COUNT(*)`) are from snapshots that don't see each other's writes. Both snapshots agreed "two are on call"; both writes are valid against their snapshots; both commit. Invariant violated.

**Fix 1 — `SERIALIZABLE`**:
```sql
BEGIN ISOLATION LEVEL SERIALIZABLE;
-- ... same logic ...
-- Postgres detects the dangerous pattern (read-write conflict cycle) and aborts one transaction.
-- The aborted transaction must retry; on retry, it sees the other's update and the COUNT returns 1; refuses to update.
```

**Fix 2 — `SELECT ... FOR UPDATE`** (advisory lock-based):
```sql
BEGIN;
SELECT COUNT(*) FROM doctors WHERE on_call = true FOR UPDATE;
-- Locks all currently-on-call rows. Other transaction waits; sees Alice's update; gets correct count.
```

**Fix 3 — Database constraint**:
```sql
ALTER TABLE schedule ADD CONSTRAINT check_on_call
    CHECK ((SELECT COUNT(*) FROM doctors WHERE on_call) >= 1);
-- (Postgres requires this via a trigger; constraints can't reference other rows directly.)
```

This is the canonical write-skew example. It's not academic — variants appear in inventory ("at least N items reserved"), banking ("balance ≥ 0"), seat reservation, and many others. The fix is choosing serializable, explicit locking, or constraint-level enforcement — never trusting snapshot isolation to handle multi-row invariants.

---

## Recent Production References (2023-2024)

- **Postgres 16 (2023)** added logical replication from standbys, addressing a long-standing limitation. CDC pipelines from replicas without primary load.
- **CockroachDB's serializable-by-default** continues to drive customer education on retry handling. Their public docs include a chapter on retry patterns.
- **The Sentry txid-wraparound near-miss postmortem** (originally 2015; periodically referenced) remains required reading for any high-write Postgres operator.
- **Notion's Postgres scaling journey (2023)**: documented sharding from a 200TB single Postgres to a sharded architecture. MVCC vacuum behavior figured prominently in the migration's performance characterization.
- **Discord's switch to ScyllaDB (2023)**: not a relational concurrency story, but the analysis of Cassandra → ScyllaDB documents the consistency model trade-offs explicitly.
- **The "Foundation DB record-layer" papers**: continued public engineering on snapshot-isolation semantics over a key-value store.

---

## 20% Knowledge Giving 80% Understanding

If you remember nothing else:

1. **MVCC = readers see snapshots, writers create versions, garbage collection cleans up.**
2. **A snapshot is a moment in time. Visibility is computed, not stored.**
3. **Read Committed uses per-statement snapshots; Repeatable Read / Snapshot Isolation uses per-transaction snapshots; Serializable adds cycle detection.**
4. **Snapshot Isolation does not prevent write skew. Period.**
5. **The operational cost of MVCC is vacuum. Long-running transactions are vacuum's nemesis.**
6. **Your database's isolation level names probably don't mean what the SQL standard says.**
7. **Distributed MVCC = MVCC + a timestamp protocol. Whoever owns the clock owns the bottleneck.**

That's the working set. Everything else is detail you can look up.

---

## Final Mental Model

> **The database isn't a state — it's a log of versions, and a transaction is a viewing angle into that log.**

When you see it that way, isolation levels stop feeling like arbitrary trivia and start feeling like what they are: *negotiations* between you and the database about how much of the log's complexity you want to deal with, in exchange for how much performance.

Locks are pessimism. Versions are optimism with bookkeeping.

The senior engineer's instinct is to reach for *neither blindly* — to look at the workload, identify the anomalies that actually matter to the business, pick the cheapest level that prevents them, and design the application to retry when the database says no.

That's MVCC. That's isolation. That's the rest of your career operating databases.
