# 🛠️ Knowledge-Base Remediation Plan

**Goal:** act on every shortcoming the audit found **and** make the corpus intuitive for a beginner — **without compromising the senior/staff depth that is its whole point.**

**The core idea:** we do **not** dumb anything down. Beginner-accessibility is added as a *layer on top* of the existing depth (an intuition on-ramp + prerequisite links + difficulty tiering + glossed jargon), exactly the pattern that worked for `learn/`. Quality is simultaneously *raised* by fixing the factual errors, cutting the padding, and filling the hard-topic gaps. Depth and approachability are not in tension here — the padding and the errors are what hurt *both*.

**Status:** awaiting review. Nothing edited until approved. All work on branch `audit/knowledge-base` (or a child branch).

---

## 0. Guiding principles
1. **No depth lost.** Every senior-level explanation, internal, and failure mode stays. We add on-ramps and fix errors; we don't delete substance.
2. **Accuracy is non-negotiable.** A "deep dive" with hallucinated facts is worse than useless — it teaches wrong things confidently. Accuracy is Phase 1.
3. **De-padding *is* a quality win, not a trim.** Cutting the 25–45% repetition makes the real content easier to find for everyone — beginner and senior alike.
4. **Beginner-accessible ≠ beginner-only.** The on-ramp lets a newcomer *enter* and know when to stop; the depth below still serves staff readers.
5. **One spec, applied corpus-wide**, so the 66 files stop varying in quality and shape.

---

## 1. The KB file standard (Definition of Done)

Every topic file should have, in order:

1. **🎯 Start Here — Intuition** *(new, ~5 lines)* — a plain-English analogy + one-sentence "what problem this solves," and a **prerequisite link** to the matching `learn/` topic via [`CROSS-REF-LEARNING-PATH.md`](../CROSS-REF-LEARNING-PATH.md) (*"New to this? Build the basics in `learn/...` first, then come back."*).
2. **Difficulty gate before deep internals** — a tag like *"⚠️ The sections below assume X. Tagged 🟢 foundational / 🟡 mid-level / 🔴 senior."* (the same honest tiering used in `learn/`).
3. **The existing deep content** — kept, with **every acronym glossed on first use** or linked to [`GLOSSARY.md`](../GLOSSARY.md).
4. **One consolidated "Key Takeaways"** — replacing the 4–5 repeating summary sections ("Junior Misses / Senior Notices / 20% Knowledge / Final Mental Model").
5. **Accurate, sourced references** — every "company X did Y" / number gets a real source or a hedge; no invented authority.

A template file `_KB_FILE_TEMPLATE.md` will encode this (Phase 0), mirroring `learn/_TEMPLATE_gaps_and_guided.md`.

---

## 2. Phased execution

> Phases are independently shippable and reviewable. Drafting via parallel agents; you review each phase's diff before the next.

### Phase 0 — Spec & template
Author `_KB_FILE_TEMPLATE.md` (the standard above), built from the corpus's best files (`mvcc-and-isolation-levels`, `cascading-failures-and-circuit-breakers`, `cqrs-and-event-sourcing`). Add a section contract to `INDEX.md`.

### Phase 1 — Accuracy pass (must-fix, highest priority)
Fix **every 🚩 flagged error** across all directories. These actively mislead. Worst offenders, fix first:
- Inverted/wrong definitions: `disaster-recovery-and-rto-rpo` (CDP/RPO inversion), `mvcc-and-isolation` (RR "lost updates" row), `caching-hierarchy` ("90% hit rate barely faster").
- Hallucinations: Figma/Linear "use CRDTs", Python "GIL removed in 3.16", fabricated `--trace-ic` output, garbled Node.js origin history, "GitHub MySQL→MariaDB", Roman-aqueduct story, "80/90/95 rule".
- Bad math: cardinality "$90M" (10× off), fsync "3000/sec" (self-contradicts), retry "27× vs 64×" (two files disagree), saga `compensate()` post-pivot refund bug.
- Wrong theorem/specifics: FLP→Two Generals, SWIM detection complexity, "CRDTs inherently idempotent", proto3 "optional by default", "never change proto types".
- Dated defaults: TCP `cwnd=1`→IW10, GOMAXPROCS, int8 quantization.

### Phase 2 — De-pad the corpus
Collapse the repeating summary sections into one **"Key Takeaways"** per file. ~25–45% length reduction, zero information loss. This is the single biggest readability win for beginners *and* the fastest way to make the files honestly match their word-count claim.

### Phase 3 — Beginner on-ramp layer *(the "make it intuitive" core)*
Add to every topic file: the **🎯 Start Here — Intuition** opener (analogy + problem statement + prerequisite link to `learn/`) and the **difficulty gate + 🟢/🟡/🔴 tiering**. Purely additive — no existing depth touched. This is what lets a beginner enter the KB without drowning, while the senior content underneath is untouched.

### Phase 4 — Jargon glossing + GLOSSARY wiring
Gloss every acronym on first use or link to `GLOSSARY.md`; extend `GLOSSARY.md` to cover any missing terms. Cross-link aggressively so a beginner is never stranded on an undefined term.

### Phase 5 — Fill the hard-topic gaps in weak files
Raise the bottom of the corpus to standard by adding the specific senior topics each weak file dodges (see per-directory table below) — e.g. Kafka `min.insync.replicas`, k8s HPA formula, negative caching, real LLM latency taxonomy, SSI internals. This *raises* the standard; it does not lower it.

### Phase 6 — Meta/navigation fixes
- Make `INDEX.md` self-truthful (correct the "60 artifacts" stats → real 66 topic + nav files) and add a **CI parity check** so stats can't drift again.
- Add the missing `STARTER-CARDS` (gRPC, GraphQL, GPU, Postgres internals).
- Wire `CROSS-REF-LEARNING-PATH.md` into `INDEX.md` and `LEARNING-PATHS.md`.

### Phase 7 — Verification
Fact-check re-pass on edited files; link checker across `DEPENDENCY-GRAPH`/`LEARNING-PATHS`/cross-ref; INDEX-stats parity check; beginner-readability spot-check (can a newcomer follow the first screen of each file?).

---

## 3. Per-directory tailoring (each domain's specific fixes)

| Directory | Avg | Top fixes (beyond the corpus-wide phases) |
|---|---|---|
| `architecture-patterns` (3.5) | Fix the 13 errors (saga code bug, hallucinated refs, FLP, proto types, Kafka gaps); rebuild `kafka-internals` (add `min.insync.replicas`, ISR mechanics, compaction); deepen `graphql`/`llm-serving` |
| `caching` (3.8) | Fix "90% hit rate" claim + non-monotonic latency table; add **negative caching** + **Redis-vs-Memcached internals** |
| `concurrency` (3.8) | Remove invented numbers (GIL ~50ns, channel ns); fix Go GOMAXPROCS/deadlock + Python 3.16 GIL claim; thicken `cpu-caches` & `go-runtime` |
| `database-internals` (4.1) | Fix 64-bit XID + fsync math + RR lost-update row; add SSI internals, join-order search, value compression |
| `distributed-systems` (4.0) | Fix SWIM O(log N), Figma/Linear CRDT, Redis CRDT qualifier; de-pad ~35% |
| `js-runtime` (4.0) | Rewrite the GC file (refcount/Python error); delete fabricated `--trace-ic`; fix libuv/Node history; cut cross-file redundancy |
| `networking` (4.0) | Fix `cwnd=1`→IW10, HTTP/2 coalescing, SSE 6-connection limit; de-pad ~40% |
| `observability` (4.0) | Fix cardinality $ (10× off), trace_id "UUID", sampling-decision absolutism; cut boilerplate |
| `scalability` (4.0) | Add Little's Law, HPA formula, cooldown/stabilization; **rewrite the shallow `kubernetes-internals` file** |
| `system-failures` (4.0) | Fix CDP/RPO inversion + retry-math inconsistency; level up `security-incident-response` & `disaster-recovery` |
| meta/navigation (4.2) | INDEX stats + parity check; missing starter cards; coverage-gap note |

---

## 4. Impact by reader level (post-fix)

- **🟢 Beginner — the biggest change.** Today the KB is a wall of senior jargon with no entry point; a newcomer bounces. After Phase 3+4 they get an intuition analogy, a "go learn the basics here first" link into `learn/`, difficulty tiers telling them when to stop, and glossed terms — so the KB becomes *enterable* instead of intimidating. **They lose nothing; they gain a door.**
- **🟡 Intermediate.** De-padding + glossing + honest tiering turns the corpus into a clean level-up resource; the accurate references let them cite confidently.
- **🔴 Senior/staff.** Accuracy fixes + filled hard-topic gaps make the strong files genuinely *reference-grade* and stop the weak files from embarrassing them in an interview. This is where "quality/standard preserved" is most concretely delivered — the depth goes *up*, not down.
- **🧰 Maintainer.** Template + INDEX parity check + link checker prevent regression and stat-drift.

---

## 5. Scope & decisions for your review

**Scope:** 66 topic files + 9 nav files. Phases 1–2 touch all of them; Phase 5 touches the ~10 weak files; Phase 6 touches nav files.

Decisions (my recommendation in **bold**):
- **D1 — Coverage:** **All 66 files to the new standard** *(recommended, full consistency)* vs. fix only the sub-4.0 files first.
- **D2 — Positioning:** **Reposition as "layered: beginner on-ramp → senior depth"** *(recommended)* vs. keep the pure "senior/staff" framing and only fix errors/padding.
- **D3 — Accuracy-only fast track:** if you want value fastest, **do Phase 1 (accuracy) + Phase 2 (de-pad) corpus-wide first and ship that**, then decide on the beginner layer. *(Recommended sequencing.)*
- **D4 — Execution:** **parallel agents draft per phase, you review each phase's diff** *(recommended, as with the `learn/` work)*.

---

*Net promise: zero depth removed; accuracy fixed; padding cut; a beginner on-ramp added on top. The corpus gets both more trustworthy and more approachable at once.*
