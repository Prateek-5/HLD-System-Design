# Audit — Meta & Navigation Layer

**One-line verdict:** A genuinely useful, link-clean navigation layer (zero broken `.md` links across ~1,000 internal links) let down by a stale self-description and a consistent blind spot: ~4-6 topic files are systematically missing from the coverage artifacts (STARTER-CARDS, DEPENDENCY-GRAPH, and the role/level paths).

Audited 2026-06-05 against the live corpus (66 topic files in 10 domains).

---

## Scores

| File | Overall | Accuracy | Usefulness | Verdict |
|---|---|---|---|---|
| INDEX.md | 3 | 3 | 4 | Useful front door, but the Stats/domain counts are wrong and it omits a sibling nav file. |
| GLOSSARY.md | 5 | 5 | 5 | Best-in-class. 248 links, accurate definitions, multi-link for cross-cutting terms. |
| FAQ.md | 5 | 5 | 5 | Real questions, sharp answers, correctly linked. Earns its place. |
| STARTER-CARDS.md | 3 | 4 | 3 | Well-built per card, but only 62 of 66 topics have a card; partly duplicates the topics' own "Final Mental Model" sections. |
| DEPENDENCY-GRAPH.md | 4 | 4 | 4 | The most original artifact (real prereq graph). Missing 4 topics; the ASCII "Visual Summary" is decorative, not load-bearing. |
| COMMON-MISTAKES.md | 5 | 5 | 5 | Concrete, opinionated, correct. Functions as a real code-review checklist. |
| LEARNING-PATHS.md | 4 | 4 | 4 | Genuinely helpful curation by level/role/challenge; some overlap with INDEX's own reading orders. |
| ACRONYMS-BY-DOMAIN.md | 4 | 5 | 4 | Accurate and well-scoped; overlaps GLOSSARY but the "which world does this belong to" framing justifies it. |
| WORKED-EXAMPLES.md | 5 | 5 | 5 | The strongest scaffolding file. Real wrong-way/right-way code; does NOT duplicate topic files — it applies them. |

**Average overall: ~4.2 / 5.**

---

## Concrete issues (quoted)

### INDEX.md — stale self-description
- Stats section claims **"60 artifacts spanning 10 domains, plus 8 navigation aids."** Actual corpus is **66 topic files**, and there are **9** navigation files on disk (the 8 listed plus `CROSS-REF-LEARNING-PATH.md`, created later and never linked from INDEX).
- Domain header **"### JavaScript Runtime (5)"** is wrong — the section lists **6** items (Event Loop, V8, Node.js/libuv, Streams, Web Workers, Garbage Collection) and 6 files exist on disk.
- Per-domain counts otherwise check out (DB 8, Distributed 5, Concurrency 10, Networking 5, Observability 5, Scalability 7, Failures 7, Architecture 12, Caching 1) — they sum to **66**, contradicting the "60" headline in the same file.
- The "~210,000 words" / "~10 cross-references per artifact" stats are unverifiable and will rot; they read as marketing in an otherwise factual index.

### Systematic coverage gap (affects STARTER-CARDS, DEPENDENCY-GRAPH, LEARNING-PATHS, FAQ, COMMON-MISTAKES)
The same handful of topics fall through the navigation layer everywhere except INDEX:

| Topic file | Starter Card | Dep-Graph node | Learning Path | FAQ | Common-Mistakes |
|---|---|---|---|---|---|
| `architecture-patterns/grpc-internals-and-streaming.md` | missing | missing | missing | missing | missing |
| `architecture-patterns/graphql-deep-dive.md` | missing | missing | missing | missing | missing |
| `scalability/gpu-and-accelerator-computing.md` | missing | missing | missing | missing | missing |
| `database-internals/postgres-internals-deep-dive.md` | missing | missing | missing | present | missing |

- **STARTER-CARDS.md** has **62 cards** (`### ` headers) for **66 topics**. Architecture Patterns is described in INDEX as 12 topics but Starter Cards lists only 10 — `gRPC Internals` and `GraphQL Deep Dive` have no card. `Postgres Internals` and `GPU & Accelerator Computing` also have no card. (The grep hits for "gpu"/"graphql" in the file are incidental — e.g. "GPU-bound" inside the LLM Serving card — not dedicated cards.)
- **DEPENDENCY-GRAPH.md** has no prereq/related/followup node for postgres-internals, grpc-internals, graphql-deep-dive, or gpu-and-accelerator. These four topics therefore have *no documented path in or out* — a reader walking the graph will never arrive at them. This is the most consequential gap because the graph's entire value proposition is "what to read before what."
- The effect compounds: a reader using STARTER-CARDS to "decide what to read next" (its stated purpose) and DEPENDENCY-GRAPH to find prerequisites will never discover four real artifacts.

### Redundancy / earning-their-length
- **STARTER-CARDS.md (891 lines):** each card's **Final** line is largely lifted from the topic file's own "Final Mental Model" section, and the "5 mental models" mirror each topic's "Core Mental Models" heading. This is the file most at risk of being padding — it is a re-projection of content that already exists in a fixed slot in every artifact. It is still useful as a single-file skim/interview sheet, but it is the lowest-leverage scaffolding file and the hardest to keep in sync (62 hand-maintained mirrors).
- **WORKED-EXAMPLES.md (1040 lines):** by contrast, *earns* its length. It does not duplicate topic prose — it shows applied, runnable-shaped code (idempotent charge API, orchestrated saga with a named pivot transaction, cache-stampede single-flight + XFetch, burn-rate alert YAML, dual-write shard migration, Node stream backpressure, OTel tracing). The wrong-way/right-way framing is exactly what the topic files don't provide. Keep as-is.
- **INDEX vs LEARNING-PATHS overlap:** INDEX has its own "Reading Order Recommendations" by role (Backend early/senior, SRE, DB, Distributed, Frontend, AI infra) that partially duplicate LEARNING-PATHS' "By Role" section. Pick one home for role-based paths; have INDEX link to it rather than re-state a shorter, divergent version.
- **ACRONYMS vs GLOSSARY overlap:** real but defensible — ACRONYMS groups by domain ("which world does this belong to") and points to GLOSSARY for definitions; GLOSSARY is alphabetical. Different access patterns. No change needed.

### Minor
- `CROSS-REF-LEARNING-PATH.md` exists in the directory but is referenced by **no** navigation file (0 hits in INDEX). Either an unfinished/duplicate of LEARNING-PATHS or an orphan that should be linked or removed.
- DEPENDENCY-GRAPH's closing "Visual Summary" ASCII tree is decorative and already drifting (it lists ~25 of 66 topics); it adds little over the per-tier prose and is a maintenance liability.

---

## Strengths (what's working and should be preserved)

- **Link integrity is excellent.** Every `.md` link in all nine nav files resolves to a real file — checked exhaustively (INDEX 89, GLOSSARY 248, DEPENDENCY-GRAPH 305, LEARNING-PATHS 201, FAQ 65, COMMON-MISTAKES 69, WORKED-EXAMPLES 27 links; STARTER-CARDS and ACRONYMS are intentionally low-link). **Zero broken links.**
- **GLOSSARY, FAQ, COMMON-MISTAKES are genuinely useful, not padding.** They answer questions a reader actually arrives with, are technically accurate (CAP framing, exactly-once impossibility, even-cluster-size pitfall, MVCC bloat, RR-differs-by-DB, false sharing), and route correctly.
- **WORKED-EXAMPLES is the standout.** It bridges theory→practice in a way the topic files don't, with no duplication.
- **DEPENDENCY-GRAPH is the most original idea** — tiered prerequisites with prereq/related/followup is real scaffolding, not a re-list of the table of contents.
- **Consistent navigation footer** ("When in Doubt" in FAQ; cross-links between nav files) makes the layer feel like one connected system.

---

## Tailored improvement plan for the navigation layer

**Priority 1 — Close the coverage gap (correctness).**
1. Add STARTER-CARDS entries for `gRPC Internals & Streaming`, `GraphQL Deep Dive`, `GPU & Accelerator Computing`, `Postgres Internals`. (62 → 66, full parity.)
2. Add DEPENDENCY-GRAPH nodes for the same four, with prereq/related/followup. Suggested: gRPC under Tier 2 (prereq: API Design, HTTP/2-3, TLS); GraphQL under Tier 2 (prereq: API Design); GPU/Accelerator under Tier 3-4 (related: LLM Serving, Capacity Planning); Postgres Internals under Tier 2 (prereq: MVCC, WAL, Indexing, Query Optimization).
3. Slot the four into at least one LEARNING-PATH each (gRPC/GraphQL → Architect & Backend; GPU → AI Infra; Postgres → DB Engineer).

**Priority 2 — Make INDEX truthful and self-maintaining.**
4. Fix the headline Stats to "66 artifacts" and "9 navigation aids," or replace hard counts with a generated note.
5. Fix "JavaScript Runtime (5)" → "(6)".
6. Link or delete `CROSS-REF-LEARNING-PATH.md`; if it duplicates LEARNING-PATHS, remove it.
7. Add a CI/pre-commit check: assert every topic file appears in STARTER-CARDS and DEPENDENCY-GRAPH, and that domain counts in INDEX match `ls`. A 20-line script would have caught every issue in this audit.

**Priority 3 — Reduce duplication / drift surface.**
8. Pick a single home for role-based reading orders (LEARNING-PATHS); shrink INDEX's role section to a pointer.
9. Consider dropping or auto-generating DEPENDENCY-GRAPH's ASCII "Visual Summary" — it's the part most likely to silently go stale.
10. Optionally generate STARTER-CARDS' "Final" line directly from each topic's "Final Mental Model" section so the mirror can't drift.

**Do not touch:** GLOSSARY, FAQ, COMMON-MISTAKES, WORKED-EXAMPLES, ACRONYMS — these are pulling their weight.
