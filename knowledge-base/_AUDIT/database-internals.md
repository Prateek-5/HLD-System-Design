# 🔍 Audit — `database-internals/`

**Reviewed:** 8 files (~3,432 lines) · **Lens:** brutal-honest, held to the corpus's own "senior/staff 3000+ word deep dive" claim · **Avg score: ~4.1/5**

---

## Verdict in one line
The strongest directory in the corpus so far: **genuinely staff-level and unusually accurate** on the parts that bite (write skew, SSI, fsync semantics, ARIES, B-tree vs LSM amplification), dragged down only by a real txid-width error and by two files (`postgres-internals`, `time-series`) where the "deep dive" collapses into terse bullet-list padding.

## Per-file scores (out of 5)

| File | Score | One-liner |
|---|---|---|
| `mvcc-and-isolation-levels.md` | **4.6** | Best file in the corpus; write-skew + SSI + vendor reality all correct |
| `wal-and-crash-recovery.md` | **4.5** | ARIES, fsyncgate, torn pages, group commit — all right, well-told |
| `indexing-and-storage-engines.md` | **4.4** | Concrete index worked example; LSM amplification taxonomy correct |
| `query-optimization-and-execution-plans.md` | **4.3** | Cardinality-estimation framing is exactly the senior insight |
| `replication-strategies.md` | **3.9** | Accurate and complete; thinner originality, some padding |
| `oltp-vs-olap-and-columnar-storage.md` | **3.8** | Solid and correct; leans list-y; analogies recycled |
| `postgres-internals-deep-dive.md` | **3.7** | Good detail but a real txid error + padding sections go threadbare |
| `time-series-databases.md` | **3.7** | Gorilla cited correctly; back half is bullet-list filler |

## Concrete errors found (must-fix)

- 🚩 **`postgres-internals-deep-dive.md` (line 146): 64-bit XID claim is misleading-to-wrong.** Quote: *"Modern Postgres has 64-bit transaction IDs in some contexts; freezing is still a concern at very high write rates."* As of all released versions (through PG17), on-disk transaction IDs for user tuples remain **32-bit**, and wraparound/freezing is unequivocally still a thing. Postgres uses a 64-bit `FullTransactionId` internally for some bookkeeping, but the sentence reads as if wraparound is partially solved — it is not. Correct it to: "Postgres XIDs are still 32-bit on disk; 64-bit XIDs are a long-proposed feature that has *not* shipped, which is why freezing remains mandatory."
- 🚩 **`wal-and-crash-recovery.md` (line 401) — self-inconsistent fsync number.** Worked example says *"Naive: 3 fsyncs (each takes ~1ms on SSD); 3000 commits/sec ceiling per thread."* Three fsyncs at 1ms each is **~333 commits/sec per thread**, not 3000 (and the earlier Core Mental Models section at line 130 correctly says "~1ms fsync … caps throughput at ~1000 commits/second"). The numbers contradict each other across the same file. Pick one and make the arithmetic match.
- 🚩 **`mvcc-and-isolation-levels.md` (line 173) — Repeatable Read row is too generous to the SQL standard, slightly misleading for Postgres.** The table lists Repeatable Read / Snapshot Isolation as *"Allows: Write skew, lost updates,"* softened only by a footnote. In **Postgres specifically**, Repeatable Read *does* abort on lost updates (`ERROR: could not serialize access due to concurrent update`) and does *not* exhibit the standard's phantom behavior. The asterisked footnotes (lines 176–177) partially rescue this, but a reader skimming the table walks away believing PG RR allows lost updates, which is false. Minor, but it is the one isolation-table imprecision worth tightening.
- 🚩 **`oltp-vs-olap-and-columnar-storage.md` (line 208) — DuckDB/SQLite framing is loose.** Quote: *"Embedded analytics in app | DuckDB, SQLite (analytical mode)."* SQLite has no "analytical mode"; it is a row-store and is precisely the *wrong* embedded choice for OLAP (which is why DuckDB exists). The pairing implies a parity that does not exist.

Beyond these, I specifically fact-checked the items the brief flagged as commonly-wrong and the docs got them **right**: ARIES redo-then-undo + CLRs + steal/no-force (`wal`, lines 119–126); fsyncgate / PANIC-on-fsync-error (`wal`, 153–158, 236); `full_page_writes` for torn pages (`wal`, 208); SSI cycle detection and the doctors-on-call write-skew example (`mvcc`, 57–59, 314–336); Oracle "Serializable" is really snapshot isolation (`mvcc`, 183); MySQL InnoDB RR consistent-read vs current-read blend (`mvcc`, 182); LSM write/read/space amplification and bloom filters (`indexing`, 122–129); cost-based optimization tracing to System R 1979 (`query-opt`, 42–44); the planner's independence assumption on correlated columns (`query-opt`, 143–151); Gorilla's 1.37 bytes/point (`time-series`, 117); delta-of-delta encoding (`time-series`, 103–104); HOT updates + `fillfactor` (`postgres`, 156); TOAST >2KB out-of-line (`postgres`, 233). That is an unusually clean fact-check run for this corpus — credit where due.

## Genuine strengths (keep)

- **The write-skew treatment in `mvcc` is genuinely staff-level.** It doesn't just name the anomaly — it explains *why* snapshot isolation misses it ("they target different rows … both snapshots agreed 'two are on call'"), then gives three real fixes (`SERIALIZABLE`, `SELECT … FOR UPDATE`, constraint-via-trigger) and correctly notes Postgres can't express the cross-row CHECK directly (line 357). This is the single best section in the entire knowledge base.
- **`wal`'s "commit = the fsync returned, not the data file" thread is the correct mental model**, hammered consistently and tied to real incidents (fsyncgate, GitLab 2017, Sentry wraparound). The Postgres write-path ASCII diagram (lines 414–457) is accurate and load-bearing.
- **`indexing`'s worked example** (lines 288–453) is the best practical content in the directory: real `pg_stat_statements`-style query mix, naive-vs-composite index strategy, partial index for `status='open'`, GIN for FTS/arrays, and an honest index-size budget. This is the rare "show, don't tell" section.
- **`query-opt` correctly centers cardinality estimation as the fragility** ("Most query performance problems are statistics problems wearing a costume," line 401) and the estimate-vs-actual EXPLAIN reading is the actual senior diagnostic move.
- **B-tree vs LSM is framed as "different bets about your workload," not "which is faster"** (`indexing`, lines 13, 29) — the correct framing, and the UUIDv4 page-split-storm callout (line 196–197) is a real interview discriminator.

## Redundancy / padding assessment

Every file carries the corpus's five-part tail: *What Junior Engineers Miss · What Senior Engineers Notice · Interview Perspective · 20% Knowledge · Final Mental Model*. Across this directory these restate the same handful of points **~25–35% redundancy** per file — and it is **worse in the two weakest files**: `postgres-internals` (lines 420–470) and `time-series` (lines 322–371) degrade into near-identical one-line bullets ("They **audit cardinality**." / "**Audit cardinality continuously**." / "**Cardinality drives cost**.") repeated three times in three sections. The four strong files earn their length with the Deep Technical Explanation + Worked Example carrying real signal; the weak two front-load decent material then coast on filler to hit word count. `oltp-vs-olap` and `time-series` also recycle the identical "library" / "flight recorder" analogies already used in `wal` and `indexing`, diluting originality.

## 🛠️ Improvement plan (tailored to this directory)

**Theme: this directory is 80% of the way to reference-grade — fix two factual slips, then cut padding and add the four hard topics it conspicuously dodges.**

1. **Fix the four flagged errors above first** — especially the `postgres-internals` 64-bit XID sentence and the `wal` 333-vs-3000 fsync arithmetic, since both undercut otherwise-authoritative files.
2. **`postgres-internals` and `time-series` need the padding amputated and replaced with depth.** Collapse the five tail sections into one "Interview + cheat-sheet" block (the strong files can keep more because their bodies justify it). Reinvest the words: `postgres-internals` should actually *show* a HOT-update before/after page diagram and an autovacuum-threshold worked calculation; `time-series` should show the Gorilla XOR-of-floats value compression (it names delta-of-delta for timestamps but never explains how *values* compress).
3. **Add the missing serializability depth `mvcc` gestures at but skips:** SSI's actual mechanism (rw-antidependency tracking, the "dangerous structure" of two rw-edges, `SIReadLock`/predicate locks). The file says "runtime detection of dangerous read-write dependency cycles" — a staff reader will want the pivot/dangerous-structure detail, not just the phrase.
4. **`query-opt` should add the join-order search-space problem concretely:** dynamic programming vs `geqo` (the genetic optimizer Postgres switches to past `geqo_threshold`), and *why* 12-way joins force heuristics. It mentions "factorial join orders" (line 247) but never names the actual algorithms a senior would cite.
5. **`replication-strategies` and `oltp-vs-olap` are correct but interchangeable-feeling — differentiate them with the hard quantitative tradeoffs.** Replication needs a concrete RPO/RTO worked number for async-vs-semisync-vs-sync (e.g., "10ms lag = up to 10ms of acknowledged writes lost on failover"). OLAP needs one real columnar-vs-row I/O calculation (scan 1 column of 50 vs reading full rows) instead of asserting "100× faster."
6. **De-duplicate analogies across the directory.** The library, flight recorder, and bank-ledger analogies appear in 3+ files each. Assign each analogy a home file and cross-link rather than re-paraphrase.
