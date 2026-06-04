# 🔍 Knowledge-Base Audit — Master Scorecard

**Reviewed:** all 75 `.md` files (66 topic files across 10 directories + 9 navigation files) · **Lens:** brutal-honest, held to the corpus's own *"senior/staff-level mentor deep dive (~3000+ words)"* claim.

Each directory has its own detailed audit + tailored improvement plan (linked below). This file is the consolidated verdict.

---

## Corpus verdict in one line
**A genuinely useful, mostly-accurate intermediate→senior study corpus that consistently oversells itself** — the *concepts* are reliable, but ~25–45% of every file is repetitive padding, and each directory carries a handful of confident-but-wrong factual details (hallucinated specifics, invented numbers, dated defaults). Trust the principles; verify the particulars.

## Master scorecard

| Directory | Avg | Files | Strongest | Weakest | Improvement theme |
|---|---|---|---|---|---|
| [`database-internals`](database-internals.md) | **4.1** | 8 | mvcc-and-isolation (4.6, best in corpus) | postgres / time-series (3.7) | 80% to reference-grade; fix 2 slips, add the hard topics |
| [`distributed-systems`](distributed-systems.md) | **4.0** | 5 | leader-election (4.5) | gossip-protocols (3.4) | Factually best dir; fix 3 errors, cut ~35% padding |
| [`js-runtime`](js-runtime.md) | **4.0** | 6 | event-loop / v8 (4.4) | garbage-collection (3.2) | Fix the GC file + fabricated traces; cut redundancy |
| [`networking`](networking.md) | **4.0** | 5 | http-2-and-http-3 (4.3) | websockets (3.6) | Facts are right; ~40% padding + dated defaults |
| [`observability`](observability.md) | **4.0** | 5 | slos-error-budgets (4.5) | cardinality (3.6) | Cut boilerplate, fix the figures |
| [`scalability`](scalability.md) | **4.0** | 7 | load-balancing (4.4) | kubernetes-internals (3.3) | Fix depth asymmetry + missing formulas; rewrite k8s |
| [`system-failures`](system-failures.md) | **4.0** | 7 | cascading-failures (4.7, top score) | security-incident (3.2) | Fix RPO/CDP inversion + retry-math; level up thin files |
| [`caching`](caching.md) | **3.8** | 1 | — | caching-hierarchy (3.8) | One wrong claim + 2 missing topics from a 4.5 |
| [`concurrency`](concurrency.md) | **3.8** | 10 | backpressure-and-queues (4.5) | cpu-caches (3.2) | Accurate; enemies are padding + invented numbers |
| [`architecture-patterns`](architecture-patterns.md) | **3.5** | 12 | cqrs-and-event-sourcing (4.8) | kafka-internals (2.6) | Fix 13 factual errors; de-pad; go deep where it bails |
| [`meta-and-navigation`](meta-and-navigation.md) | **4.2** | 9 | GLOSSARY / FAQ / WORKED-EXAMPLES / COMMON-MISTAKES (5) | INDEX / STARTER-CARDS (3) | Close coverage gaps; make INDEX self-truthful |

**Content-file mean ≈ 3.9/5.** Best directory: `database-internals` (4.1). Weakest: `architecture-patterns` (3.5).

## Hall of fame (refer freely)
- `database-internals/mvcc-and-isolation-levels.md` (4.6) — called the best file in the corpus
- `system-failures/cascading-failures-and-circuit-breakers.md` (4.7)
- `system-failures/timeouts-retries-and-idempotency.md` (4.6)
- `architecture-patterns/cqrs-and-event-sourcing.md` (4.8)
- `distributed-systems/leader-election-and-consensus.md` (4.5)
- `concurrency/backpressure-and-queues.md` (4.5)
- `database-internals/wal-and-crash-recovery.md` (4.5)
- `observability/slos-error-budgets-and-alerting.md` (4.5)

## Supplement heavily before relying (weakest)
`architecture-patterns/kafka-internals` (2.6), `graphql-deep-dive` (2.8), `llm-serving-and-vector-databases` (2.8); `concurrency/cpu-caches-and-false-sharing` (3.2); `js-runtime/garbage-collection` (3.2); `system-failures/security-incident-response` (3.2); `scalability/kubernetes-internals` (3.3).

---

## Corpus-wide recurring defects

1. **Systematic padding (25–45% of every file).** The repeating "What Junior Engineers Miss / What Senior Engineers Notice / 20% Knowledge / Final Mental Model" sections restate the same points 4–5×. This is what inflates files to "3000+ words" — length from repetition, not depth.
2. **Invented / unsourced numbers presented as fact.** GIL "~50ns", cardinality cost "$90M/yr" (off by ~10×), fsync "3000 commits/sec" (arithmetic self-contradicts), retry "27× vs 64×" (two files disagree), channel ops "50–200ns".
3. **Confident hallucinations (a few per dir).** Figma/Linear "use CRDTs" (Figma explicitly says they didn't); Python "GIL removed by default in 3.16" (PEP 703 commits to no such version); fabricated `--trace-ic` output; garbled Node.js origin history; "GitHub MySQL→MariaDB migration"; a Roman-aqueduct strangler story.
4. **Dated defaults.** TCP slow-start "cwnd=1" (modern IW10); int8 "most production" quantization; container-aware GOMAXPROCS as "modern Go" (only true since Go 1.25).
5. **Weak files dodge the genuinely hard parts** (k8s HPA formula, SSI internals, join-order search, real LLM latency taxonomy).
6. **The INDEX lies about its own stats** ("60 artifacts" vs actual 66 topic + 9 nav; per-domain counts disagree with disk).

## Corpus-wide strengths (genuine)
- **Correct on the commonly-botched marquee concepts** across nearly every dir: write-skew/SSI, ARIES, FLP/Raft, Little's Law + utilization trap, CAS/ABA/MESI, exactly-once *effect* vs *delivery*, circuit-breaker states.
- **Real, high-signal production failure modes**: K8s gRPC load-balancing trap, double-delete cache race, std-Mutex-across-await, fsyncgate, cascading-retry amplification.
- **The navigation layer is solid** — GLOSSARY, FAQ, COMMON-MISTAKES, and WORKED-EXAMPLES genuinely earn their place; links largely resolve.

## Is it good to refer to? — consolidated answer
- **Understanding concepts / building intuition:** **Yes.** It's accurate on the shape of every topic and won't mislead you on fundamentals.
- **Mid-level interview prep:** **Yes, with the per-dir error lists open beside you.**
- **Senior/staff interview prep:** **Selectively.** The hall-of-fame files are interview-grade; the weak files stop exactly where a strong interviewer digs in, and the invented numbers/hallucinations are the kind of thing that gets you challenged and caught.
- **Universal rule:** trust the *principles*; independently verify every specific number, theorem name, version claim, and "company X did Y" before repeating it. See each directory's audit for the exact list.

---

## Companion artifacts
- [`../CROSS-REF-LEARNING-PATH.md`](../CROSS-REF-LEARNING-PATH.md) — maps every `learn/00_learning_path.md` topic to its KB deep-dive, plus KB-only extras and KB coverage gaps.
- Per-directory audits: linked in the scorecard table above.
