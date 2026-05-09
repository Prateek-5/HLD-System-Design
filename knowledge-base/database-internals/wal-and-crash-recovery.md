# Write-Ahead Logging & Crash Recovery

> *"Every database makes a single, audacious promise: 'commit means it's safe.' Underneath that promise is a fragile dance with the operating system, the filesystem, and the disk firmware — and the first thing every database engineer learns is that all three of them lie."*

---

## Topic Overview

When a database tells you "your transaction is committed," it's making a contract with physics. The bytes are durable. A power failure now won't lose them. The chair you're sitting in could be hit by lightning, the building could burn down, and when the database comes back up, your money transfer will still be there.

Honoring that contract is harder than it sounds. Disks don't write atomically. The OS caches writes. The disk firmware caches writes. Power loss in the middle of any of these layers can leave half-written data, corrupted indexes, inconsistent metadata. The naive solution — "just write everything to disk" — is too slow by orders of magnitude. The actual solution is the **Write-Ahead Log (WAL)**: an append-only log of intentions, written *first*, durably, and used to reconstruct the database's state after any failure.

This is the topic that makes "ACID's D" — Durability — actually work. It's also the topic where engineers discover that what they thought was "writing to disk" was actually "putting bytes in a kernel buffer that may or may not survive a power cut." Understanding WAL is understanding the foundation that MVCC, indexing, replication, and every other database feature is built on.

---

## Intuition Before Definitions

Imagine you're a bank teller updating account balances by hand.

Every transaction is supposed to be permanent. But the actual ledger book is heavy, and you can only flip to one page at a time. So you do something clever: when a customer comes in, you first write a *short note* on a continuous scroll — "Account 1234: deposit $50, time 10:42." The scroll is always nearby; appending to it takes seconds. Then, at your leisure, you find the right page in the heavy ledger and update the balance.

If a fire breaks out and you must flee, the scroll is light enough to grab. Even if the heavy ledger is destroyed, you can rebuild it from the scroll: read every entry from the beginning, apply each one, and you have a fresh ledger. The scroll is the source of truth; the ledger is a *cache* of the scroll's effects.

That's a write-ahead log. The scroll is the WAL. The ledger is the data files. The fire is a crash. *Crash recovery* is the act of replaying the scroll to rebuild the ledger.

The discipline: **never update the ledger before writing to the scroll. Never tell the customer "you're done" until the scroll entry is durable.** Every database in production lives by this rule.

---

## Historical Evolution

**Era 1 — Direct page writes.**
Early databases wrote modified pages straight to disk. A crash mid-write left half-written pages. Recovery meant scanning everything, finding the corruption, and praying. Backups were the recovery mechanism, with hours-to-days of data loss.

**Era 2 — Shadow paging.**
Copy-on-write at the page level: write modified data to *new* pages, atomically swap pointers when done. Elegant. Slow because every commit must rewrite the pointer tree to the root. Kept alive in research databases and filesystems (WAFL, ZFS).

**Era 3 — ARIES (1992).**
IBM's recovery algorithm for relational databases. Three principles: write-ahead logging, repeat history during redo, log changes during undo. The blueprint for almost every modern transactional database. Postgres, MySQL InnoDB, SQL Server, Oracle — all implement variants of ARIES.

**Era 4 — Log-structured storage.**
LSM trees (LevelDB, RocksDB, Cassandra) take the WAL idea to its limit: the log is the *primary* storage, not just the recovery log. Reads check the log + sorted snapshots; writes are pure appends. The line between WAL and main storage blurs.

**Era 5 — Replicated logs.**
Kafka and the realization that a WAL is itself useful: an append-only, durable, replayable log of changes is exactly what distributed event systems need. Internal database WALs become external streaming primitives. Change Data Capture (CDC) reads the WAL and turns it into events.

**Era 6 — Cloud-native and beyond.**
Modern cloud databases (Amazon Aurora, Google AlloyDB) decouple compute from the storage layer entirely. The WAL is shipped to a distributed storage service; the database servers are stateless. Recovery becomes a property of the storage service, not the database process.

The pattern: every generation extended WAL further. Once an engineering primitive, now an architectural foundation that shapes everything from durability to replication to streaming.

---

## Core Mental Models

**1. Write-ahead means write *before*.**
Every change to the data files must be preceded by a durable log entry. If you crash, the log tells you what was in flight. If the log doesn't have it, it didn't happen — even if the data files show otherwise.

**2. Commit is the moment the log entry is durable.**
Not when the data file is written. The data file is updated lazily. The log is the source of truth. "Commit" = "the log entry is on stable storage." Everything else is bookkeeping.

**3. Recovery is replay.**
Power on after a crash, read the log from the last consistent point, replay every entry. The data files re-emerge in the correct state. This is conceptually a pure function: `state_after_crash = replay(log, state_before_crash)`.

**4. Durability is fsync.**
The OS doesn't write to disk by default — it writes to a buffer. The disk firmware doesn't write to platters by default — it writes to its own cache. `fsync()` is the syscall that says "actually push this through, all the way." The database's durability hinges on calling fsync at the right moments. Skipping it for performance is a famous source of "we lost data on a power outage" stories.

**5. Group commit amortizes the cost.**
fsync is slow (~milliseconds on rotational disks, ~hundreds of microseconds on SSDs). One fsync per transaction caps your throughput. Real systems batch many transactions' log entries and fsync them together. Throughput multiplies; per-transaction latency rises slightly. The tradeoff is universal.

---

## Deep Technical Explanation

### What's in a WAL record

Each WAL record describes a logical or physical change:

- **Logical**: "INSERT row X into table T."
- **Physical**: "On page 4231, at offset 88, change bytes [...] to [...]"
- **Physiological** (most common): logical at the page level, physical within the page.

Each record carries:
- **LSN (Log Sequence Number)**: monotonic identifier. Acts as a global timestamp for the database's mutations.
- **Transaction ID**: which transaction produced this.
- **Type**: INSERT, UPDATE, DELETE, BEGIN, COMMIT, CHECKPOINT.
- **Before/after images**: enough to redo (replay forward) and undo (roll back).

The log is **append-only**. Records are written sequentially. Disks like sequential writes. The log reaches gigabyte-per-second throughput on modern hardware.

### The protocol

```
Transaction T does:
  1. BEGIN: log entry { lsn, T, BEGIN }
  2. UPDATE row: log entry { lsn, T, UPDATE, page, before, after }
                  modify in-memory page (don't write to disk yet)
  3. COMMIT: log entry { lsn, T, COMMIT }
              FSYNC the log up to this LSN
              return success to client
```

After step 3's fsync returns, the client is told "committed." The actual page modifications might still be in memory only. That's fine — the log has them.

A background process (the *checkpointer*, sometimes called the *background writer* or *bgwriter* in Postgres) periodically:
- Identifies which pages have modifications not yet on disk (dirty pages).
- Writes them to data files.
- Records a checkpoint LSN: "all changes up to this point are in the data files."

The checkpoint matters for recovery: replay only needs to start from the last checkpoint, not the beginning of time.

### Recovery — the algorithm

After a crash, on startup:

1. **Find the last checkpoint.** The checkpoint record's LSN tells you where data files are known to be consistent.
2. **Redo phase.** Replay all log records from the checkpoint forward. For each, re-apply the change to the data file (skip if the page already has a higher LSN — meaning it was flushed before the crash).
3. **Undo phase.** Identify transactions that were active but not committed at crash time. Roll them back by applying compensating actions (the undo information from their log records).

The result: data files reflect exactly the committed transactions, nothing more.

This is conceptually simple but has subtle correctness requirements:
- **Idempotent redo.** Replaying a record twice must be safe. Achieved by checking page LSN before applying.
- **Compensation log records (CLRs).** Undo actions are themselves logged so that a crash *during recovery* can restart cleanly.
- **No-Force, Steal buffer policy.** The standard ARIES choice: dirty pages can be flushed before commit (steal), clean pages need not be flushed at commit (no-force). The WAL handles both.

### Group commit

A naive implementation fsyncs once per transaction. With ~1ms fsync latency, that caps throughput at ~1000 commits/second per single thread. For OLTP workloads, that's nowhere near enough.

Group commit:
1. Many transactions queue their COMMIT log records.
2. A batched fsync flushes all of them together.
3. All those transactions return success simultaneously.

Throughput goes from 1000/s to 10,000+/s on the same hardware. Per-transaction latency rises slightly (~few ms). Almost every modern database does this; it's invisible to applications.

### Checkpoints — the invisible work

A checkpoint is the moment "everything up to LSN X is durably in the data files." Properties:
- **Bounds recovery time.** Recovery starts from the checkpoint, not the beginning of the log.
- **Allows log truncation.** Older log records (those before the oldest in-flight transaction) can be deleted.
- **Costs I/O.** Forcing all dirty pages to disk is expensive; checkpoints typically run incrementally over many seconds to minutes.

Tuning checkpoints is a real DBA discipline:
- **Too frequent**: I/O overhead, more pages flushed than necessary.
- **Too rare**: huge log volume, long recovery times after a crash.
- **Postgres**: `checkpoint_timeout` (default 5 min), `max_wal_size` (default 1GB) — checkpoints triggered by either.

### The fsync controversy

fsync on Linux has a problematic history. Pre-2018, certain failure modes (e.g., I/O errors after fsync had already returned) led to the assumption that data was durable when it wasn't. The "fsyncgate" episode (2018) revealed that Postgres had been getting durability semantics subtly wrong for years on Linux because of fsync error reporting bugs.

Modern practice:
- **Always fsync the WAL.** Yes, it's slow. The alternative is data loss.
- **Trust verified hardware.** Some SSDs and RAID controllers lie about fsync — they ack writes before the data hits stable storage. Battery-backed cache mitigates; misconfigured systems silently lose data on power loss.
- **fsync errors are catastrophic.** A failed fsync can leave the database in an unrecoverable state. Postgres now panics on fsync failure rather than continuing with potentially corrupt data.

### WAL as a streaming primitive

The same WAL that powers crash recovery powers replication:
- **Synchronous replication**: commit waits until the WAL record is on N replicas.
- **Asynchronous replication**: commit waits only for the local WAL fsync; replicas catch up later.
- **Logical replication**: parses WAL records into logical changes (INSERT/UPDATE/DELETE) and ships them.

CDC tools like Debezium tail the WAL and turn it into Kafka events. The WAL becomes the change data stream — the canonical "what just happened in the database" signal.

This dual use is why WAL design constraints have evolved. Kafka-style durable logs and database WALs are converging architecturally. The "log is the database" motto, popularized by Jay Kreps, comes from this realization.

### LSM trees — WAL as primary storage

LSM trees (RocksDB, LevelDB, Cassandra) push the idea further:
- Writes go to a memtable (in-memory).
- A WAL records the same writes for durability.
- When the memtable fills, it's written to disk as an immutable SSTable.
- Reads check memtable first, then SSTables.

Here the WAL isn't an audit log of changes to a primary store — *it is* the primary durable storage of recent writes. The SSTables are checkpoints, taken much more aggressively than in B-tree systems.

The boundary between "WAL" and "data" blurs by design.

---

## Real Engineering Analogies

**The accountant's daybook.**
A traditional accounting practice: every transaction is recorded in a *daybook* (chronological journal) before being posted to ledger accounts. The daybook is the source of truth; the ledgers are summaries derivable from the daybook. If the ledger burns, you reconstruct it from the daybook. If the daybook burns, you have nothing.

This is centuries old. Databases borrowed the idea wholesale.

**The flight recorder (black box).**
An airplane records every input and event, durably, even when the plane crashes. After a crash, investigators replay the recording to understand what happened. The plane's controls and instruments are a complex system; the black box is the simple, robust, append-only record of inputs.

A database's WAL is the same idea: when the complex thing fails, the simple thing tells you what state to restore.

---

## Production Engineering Perspective

What goes wrong:

- **The fsync that didn't.** A misconfigured filesystem (e.g., `nobarrier` mount option) silently disables the durability semantics. Power outage; data loss; engineers can't reproduce because dev machines are configured correctly. Discovered painfully.
- **The full WAL disk.** WAL accumulates faster than checkpoints can clear it. Disk fills. Database refuses writes. Common cause: a long-running transaction prevents log truncation (any log records covering its lifetime can't be removed).
- **The replication lag spike.** A slow replica makes the WAL accumulate on the primary (some replication modes). Disk pressure on the primary.
- **The checkpoint storm.** A poorly-tuned checkpoint flushes hundreds of GB at once. I/O is saturated; latency spikes; users notice. Fix: spread the checkpoint over more time.
- **The recovery that took 6 hours.** A crash on a database with a 200GB WAL backlog. Replay is single-threaded in many systems. Hours of downtime. Mitigation: more frequent checkpoints in production, accept higher steady-state I/O.
- **The torn page.** Power loss mid-write to a single 8KB page leaves the page partially updated. Recovery from WAL alone may be insufficient if the page was being modified. Postgres's `full_page_writes = on` writes the entire page to WAL on first modification per checkpoint, so recovery can rebuild it. Disabling this for performance is a *known* hazard.
- **The replica that diverged.** Async replica falls behind. Primary fails over to a different replica. The first replica now has WAL records the new primary doesn't recognize. Promotion fails; full re-sync needed.

The senior DBA's habits:
- **Verify fsync semantics** of your hardware and filesystem.
- **Monitor WAL volume** and checkpoint behavior.
- **Watch the oldest active transaction** — it pins WAL.
- **Test recovery** regularly. Untested recovery is broken recovery.
- **Have a documented PITR (point-in-time recovery) procedure** for catastrophic cases.
- **Replicate the WAL off-host** for durability beyond a single machine.

---

## Failure Scenarios

**Scenario 1 — The fsync lie.**
A server uses an SSD that ignores fsync (acknowledges writes before they're durable). For months, the database has been "committing" without true durability. A power outage causes a crash. Recovery sees inconsistent state — pages reflect changes whose log entries didn't survive. Database refuses to start. Recovery from backup; ~6 hours of data loss.

**Scenario 2 — The full disk.**
A reporting query opens a transaction at 8am. WAL accumulates. The DBA forgets to commit. By 6pm, WAL has filled the disk. New writes fail. Production is down. Killing the rogue transaction frees the WAL; checkpoint catches up; recovery takes 30 minutes.

**Scenario 3 — The torn page on cheap hardware.**
A database without `full_page_writes` enabled runs on a server with no battery-backed cache. Power loss mid-write. One page is half-old, half-new. WAL says "apply UPDATE" but the page is in an inconsistent state — applying again is unsafe. Recovery fails. Manual intervention required.

**Scenario 4 — The recovery that wouldn't end.**
A primary crashes with 100GB of WAL ahead of the last checkpoint. Recovery replays single-threaded. ~4 hours of downtime. Mitigation, post-incident: more aggressive checkpointing in steady state, parallel recovery if available.

**Scenario 5 — The fsync error.**
fsync returns an error mid-runtime. The database now has dirty buffers it cannot durably flush. Postgres's modern behavior: PANIC and crash, forcing recovery from a clean state. Older behavior: continue operating with subtly inconsistent durability. The 2018 fsyncgate revealed this had been silently happening.

---

## Performance Perspective

- **Sequential write throughput** is the bottleneck for log-heavy workloads. Modern NVMe SSDs hit GB/s; rotational disks ~100 MB/s.
- **fsync latency is the per-commit cost.** Group commit amortizes this across many transactions.
- **Checkpoints are I/O burden** on data files; tuning balances WAL volume against page-write smoothness.
- **Page cache hit rate** matters: a working set that fits in RAM means most writes are to dirty pages, fsync'd lazily.
- **Compression of WAL** trades CPU for I/O bandwidth — often net win on modern hardware.

---

## Scaling Perspective

- **Vertical**: WAL throughput scales with disk write throughput. NVMe drives can sustain hundreds of MB/s of sequential WAL writes.
- **Horizontal reads**: WAL streamed to replicas; replicas catch up.
- **Horizontal writes**: each shard has its own WAL. Cross-shard transactions need 2PC or similar. (See [sharding-and-partitioning-strategies.md](../scalability/sharding-and-partitioning-strategies.md).)
- **Cloud storage**: distributed storage layers (Aurora, AlloyDB) decouple WAL from compute. Replication is a property of storage, not the database engine.
- **Geographic**: WAL shipping across regions is the foundation for disaster recovery.

---

## Cross-Domain Connections

- **MVCC**: each row version is created by a WAL-logged transaction. Vacuum reclaims old versions; the WAL records vacuum's operations too. (See [mvcc-and-isolation-levels.md](./mvcc-and-isolation-levels.md).)
- **Indexing**: index updates are WAL-logged just like row updates. Recovery rebuilds indexes from WAL. (See [indexing-and-storage-engines.md](./indexing-and-storage-engines.md).)
- **CAP/replication**: WAL streaming is the substrate of database replication. Synchronous vs async replication is a WAL durability choice. (See [cap-consistency-and-replication.md](../distributed-systems/cap-consistency-and-replication.md).)
- **Event sourcing**: the WAL *is* an event log. Some systems blur the line — using the database WAL as the application's event source. (See [cqrs-and-event-sourcing.md](../architecture-patterns/cqrs-and-event-sourcing.md).)
- **Filesystems**: journaling filesystems (ext4 journal, XFS, ZFS) use the same idea. The OS's filesystem journal protects metadata; the database's WAL protects data.
- **Distributed consensus**: Raft's log is a WAL replicated across nodes — recovery via replay is identical. (See [leader-election-and-consensus.md](../distributed-systems/leader-election-and-consensus.md).)

The unifying observation: **the write-ahead log is the universal answer to "how do I make state changes durable in the presence of failure?"** It recurs at every layer — filesystem, database, distributed system, application — for the same reason: append-only durable history is the cheapest robust primitive.

---

## Real Production Scenarios

- **Postgres fsyncgate (2018)**: PostgreSQL discovered that fsync error semantics on Linux had been subtly wrong for ~20 years. Resulted in a major design change: PANIC on fsync error.
- **AWS Aurora's storage architecture**: separates compute from a distributed storage layer that owns the WAL. Replication and durability become properties of the storage service.
- **Kafka's adoption as "the universal WAL"**: many companies now run an internal "log of all things" as Kafka, blurring the line between database WAL and application event log.
- **Postgres's `pg_basebackup` + WAL archiving**: standard PITR architecture across the industry. Restore from base backup, replay WAL to a target time.
- **MySQL's InnoDB redo log**: same architecture; tuning the redo log size is a real DBA discipline.
- **The 2017 GitLab incident**: a chain of operational mistakes — including misconfigured backups and WAL handling — led to ~6 hours of data loss. Required reading for anyone operating databases.

---

## What Junior Engineers Usually Miss

- That **commit means the WAL is fsynced**, not that data files are written.
- That **fsync is the durability boundary** — without it, "committed" is a lie.
- That **recovery is replay**, conceptually simple but operationally complex.
- That **checkpoints are I/O work** that must be scheduled carefully.
- That **long-running transactions pin WAL** and can fill the disk.
- That **torn pages exist** and require special handling.
- That **the WAL is a streaming primitive** — used for replication and CDC.
- That **untested recovery is broken** until proven otherwise.

---

## What Senior Engineers Instinctively Notice

- They **monitor WAL volume** and oldest active transaction.
- They **verify fsync semantics** of hardware/filesystems.
- They **tune checkpoint behavior** for their workload.
- They **plan recovery time** and capacity-plan accordingly.
- They **test PITR** regularly.
- They **replicate WAL off-host** for disaster recovery.
- They **understand the WAL as a streaming primitive** for CDC and replication.
- They **know the fsync history** and trust it appropriately.

---

## Interview Perspective

What gets tested:

1. **"How does a database guarantee durability?"** Senior answer: WAL + fsync at commit + recovery replay.
2. **"What's a write-ahead log?"** Append-only log of changes, written before data files.
3. **"Why fsync?"** Tests OS literacy. Right answer: explicit syscall to push through buffer caches to stable storage.
4. **"What's a checkpoint?"** Bounded recovery time; consistent point in data files.
5. **"What's group commit?"** Amortize fsync cost; many transactions per fsync.
6. **"How does recovery work?"** Find checkpoint; redo committed; undo uncommitted.
7. **"Why don't we just write directly to the data files?"** Random I/O, ordering, partial writes, performance — the WAL solves all of them.

Common traps:
- Confusing "write to disk" with "fsync."
- Believing data files contain the latest committed state at all times.
- Not knowing about the WAL's role in replication.

---

## Worked Example — Anatomy of a Commit

A user submits a payment. Walk through what actually happens at the WAL level.

### State before commit

```
Application: BEGIN; UPDATE accounts SET balance = balance - 100 WHERE id = 'A';
             UPDATE accounts SET balance = balance + 100 WHERE id = 'B';
             COMMIT;
```

In the database (Postgres flavor):

```
1. UPDATE 1 (debit account A):
   - Find account A's row in heap; current balance 500.
   - Generate new tuple version: balance=400; xmin=current_txid.
   - Generate WAL record: {LSN: 1234, type: HEAP_UPDATE, page: 47, before: ..., after: ...}
   - Append WAL record to in-memory WAL buffer (NOT disk yet).
   - Update in-memory page; page is now "dirty".
   - Update relevant indexes; each generates its own WAL record.

2. UPDATE 2 (credit account B):
   - Same pattern. WAL records: {LSN: 1235, ...}, {LSN: 1236, ...} for indexes.

3. COMMIT:
   - Generate WAL record: {LSN: 1237, type: TRANSACTION_COMMIT, txid: ...}
   - fsync the WAL file up through LSN 1237.
   - Return success to client.
```

The fsync is the durability boundary. Power failure between step 1 and step 3: the WAL records are not on disk; recovery rolls back. Power failure after step 3: WAL records on disk; recovery replays them.

### The data files haven't been written yet

Critical: the actual heap pages and index pages are still in memory (the buffer pool). They will be flushed:
- When the page is evicted from buffer pool (someone needs the slot).
- When a checkpoint runs.
- When the database shuts down cleanly.

This is *fine* because the WAL has the truth. The data files are a cache of the WAL's effects.

### Crash and recovery

Suppose the server crashes after the commit. On restart:

```
Recovery process:
1. Read pg_control to find the last checkpoint LSN: 800.
2. Open the WAL starting at LSN 800.
3. Replay each record:
   - LSN 800-1233: changes from before our transaction; apply each.
   - LSN 1234: HEAP_UPDATE on page 47. Read page 47 (current LSN on page is 1100; this record's LSN is 1234; apply).
   - LSN 1235-1236: index updates. Apply.
   - LSN 1237: COMMIT. Mark transaction as committed.
   - Continue with subsequent records.
4. After replay, identify in-flight transactions (no COMMIT record) — roll them back.
5. Mark the database open.
```

Result: the data files are now consistent with what the WAL says. The user's payment, which was acknowledged before the crash, survives.

### Group commit in action

In high-throughput scenarios, many transactions commit at the same time:

```
T1 commit: WAL record at LSN 1237; calls fsync.
T2 commit: WAL record at LSN 1238; calls fsync.
T3 commit: WAL record at LSN 1239; calls fsync.

Naive: 3 fsyncs (each takes ~1ms on SSD); 3000 commits/sec ceiling per thread.

Group commit:
T1 calls fsync; this fsync includes any WAL written so far.
T2 and T3, arriving between T1's fsync request and its completion,
   piggyback. All three return success after one fsync completes.
Effective throughput: thousands of commits per fsync.
```

Postgres does this automatically with `commit_delay` and `commit_siblings`. Most modern databases do similar.

### Reference architecture — Postgres write path

```
[Client]
   │ COMMIT
   ▼
[Postgres backend process]
   │
   ▼
┌──────────────────────────────────────────────────────┐
│  Buffer pool (in memory)                              │
│  - Updated heap pages (dirty)                          │
│  - Updated index pages (dirty)                         │
└──────────────────────────────────────────────────────┘
   │
   │  WAL records
   ▼
┌──────────────────────────────────────────────────────┐
│  WAL buffer (in memory)                               │
└────────────┬──────────────────────────────────────────┘
             │ fsync at commit
             ▼
┌──────────────────────────────────────────────────────┐
│  pg_wal/  (on stable storage)                          │
│  - 16MB segment files                                  │
│  - The source of truth                                 │
└────────────┬──────────────────────────────────────────┘
             │ asynchronous, batched
             ▼
┌──────────────────────────────────────────────────────┐
│  Background writer / checkpointer                      │
│  Flush dirty pages to data files                       │
└────────────┬──────────────────────────────────────────┘
             ▼
┌──────────────────────────────────────────────────────┐
│  Data files (heap, indexes)                            │
│  - Eventually consistent with WAL                      │
│  - On crash: rebuilt from WAL                          │
└──────────────────────────────────────────────────────┘
             │
             │ WAL streaming
             ▼
┌──────────────────────────────────────────────────────┐
│  Replicas / standbys                                   │
└──────────────────────────────────────────────────────┘
```

Every commit's durability hangs on the fsync of the WAL. Everything else is asynchronous bookkeeping.

---

## Recent Production References (2023-2024)

- **Postgres 16's logical replication from standbys (2023)**: removes the previous limitation that logical replication had to source from primary. Better load distribution.
- **AWS Aurora's distributed storage**: continues to be a reference for compute/storage decoupling. Storage ships WAL across multiple AZs.
- **Neon's serverless Postgres (2023+)**: complete decoupling of compute from storage; storage is its own service that handles the WAL and replication.
- **The fsyncgate retrospectives (continuing)**: educational material on Linux fsync semantics; ongoing relevance.
- **Heap.io's writeup on long-running transactions**: documented the operational impact on vacuum and WAL.
- **Sentry's continued txid wraparound vigilance**: documented operational practices since the original incident.
- **MySQL InnoDB redo log improvements**: ongoing engineering work; recent versions improve redo log scalability.

---

## 20% Knowledge Giving 80% Understanding

1. **WAL = append-only log of changes**, written before data files.
2. **Commit = WAL record durably fsynced.** Data files updated lazily.
3. **fsync is the durability boundary.** Without it, "committed" is a lie.
4. **Recovery = replay log from checkpoint forward.**
5. **Group commit amortizes fsync cost.**
6. **Checkpoints bound recovery time** at the cost of background I/O.
7. **Long-running transactions pin WAL** — disk-full risk.
8. **Torn pages require special handling** (e.g., full_page_writes).
9. **The WAL is a streaming primitive** — CDC and replication build on it.
10. **Test recovery regularly.** Untested recovery is broken.

---

## Final Mental Model

> **A database is a physics-defying promise: 'committed means it's safe.' Underneath that promise is a write-ahead log, an fsync, and the discipline of writing intentions before changes. Get that stack right, and your durability holds. Get it wrong — by skipping fsync, by mis-tuning checkpoints, by trusting hardware that lies — and the promise quietly becomes a fiction.**

The senior database engineer's instinct, debugging a durability question, isn't "did the data file get updated?" — it's "did the WAL fsync return?" Everything else is downstream of that. The WAL is the truth; the data files are a cache; the tools and metrics that monitor the WAL are the early-warning system for the database's most important guarantee.

Crash recovery is the test of this discipline. Every database that has been around for a decade has stories about times the discipline failed — fsyncgate at Postgres, configuration errors at countless shops, hardware that lied about durability. The answer is not to be smarter than the system; the answer is to *trust the WAL, test recovery, monitor the indicators, and accept that durability is a property of an entire stack, not a checkbox.*

That's the WAL. That's crash recovery. That's how databases keep their promise.
