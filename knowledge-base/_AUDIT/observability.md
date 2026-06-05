# 🔍 Audit — `observability/`

**Reviewed:** 5 files (~2,310 lines) · **Lens:** brutal-honest, held to the corpus's own "senior/staff 3000+ word deep dive" claim · **Avg score: ~4.0/5**

---

## Verdict in one line
The **strongest, most fact-clean directory** in the corpus so far — the marquee concepts (cardinality combinatorics, W3C trace context, multi-window multi-burn-rate, on/off-CPU profiling, tail sampling) are right where they usually go wrong — but it's **diluted by ~35–45% boilerplate padding** and a couple of unsourced "real numbers" that don't survive arithmetic.

## Per-file scores (out of 5)

| File | Score | One-liner |
|---|---|---|
| `slos-error-budgets-and-alerting.md` | **4.5** | Best file; burn-rate table + worked checkout SLO are genuinely staff-level and *correct* |
| `distributed-tracing-deep-dive.md` | **4.4** | Excellent waterfall worked example; W3C format right; only "128-bit UUID" slips |
| `metrics-logs-traces.md` | **4.0** | Clean three-pillars; correct RED/USE/golden-signals attribution; heavy summary padding |
| `profiling-and-flame-graphs.md` | **3.9** | On-CPU vs off-CPU nailed; correct width-not-height; thin on *how* sampling actually works |
| `cardinality-and-the-economics-of-monitoring.md` | **3.6** | Core combinatorics correct; the Splunk cost number is off ~10× and unsourced |

## Concrete errors found (must-fix)

- 🚩 **Bad arithmetic, stated as fact** (`cardinality...`, line 139): *"a service at 10K RPS with 2KB log per request = 20MB/s = ~1.7TB/day. At Splunk-like pricing of $1500/GB/yr indexed: $90M/yr."* 1.7 TB/day indexed for a year is ~635,000 GB; at $1500/GB/yr that is **~$950M/yr, not $90M** — off by an order of magnitude. The pricing model is also conflated (Splunk's historic per-GB list is roughly *per-GB/day ingested*, not per-GB-stored/yr). Either fix the math or drop the dollar figure; right now it teaches a wrong number with false precision.
- 🚩 **`trace_id` called a "128-bit UUID"** (`distributed-tracing...`, line 104): *"trace_id: shared across all spans in the request (128-bit UUID)."* A W3C trace-id is a 128-bit *random identifier*, **not a UUID** — it carries no UUID version/variant bits and is generated as raw randomness (the only constraint is "not all zeroes"). Minor, but a sharp interviewer will catch "UUID."
- 🚩 **Head-sampling decision described as universally entry-point-pinned** (`distributed-tracing...`, line 143): *"Head sampling decisions propagate via the `sampled` flag in `traceparent` — once decided at the entry point, all downstream services honor the decision."* This is the *intended* behavior of consistent/`ParentBased` sampling, but it is **not guaranteed** — the file's own failure scenario (line 269, "Service B doesn't honor the sampled flag, makes its own decision") contradicts the absolute "all downstream services honor" claim. State it as "if every service uses a ParentBased sampler" rather than as a property of the flag itself.
- 🚩 **Summary metric "harder to aggregate" undersold** (`metrics-logs-traces.md`, line 94): *"Summary — pre-computed quantiles. Useful but harder to aggregate across instances."* The correct, sharper statement is that **summary quantiles are mathematically non-aggregatable** — you cannot average two p99s to get a fleet p99. "Harder" implies it's merely inconvenient; it's actually invalid, which is *the* reason histograms won. Worth stating precisely in a file claiming staff depth.

Beyond these, I went looking hard for the usual landmines and the docs are clean: the cardinality formula (`c1×c2×…×cN`, "2,500 × 1,000,000 = 2.5 billion series … ~1 million× more storage") is **arithmetically correct**; the W3C `traceparent` field breakdown (`00`-traceid-parentid-`01`) is **correct**; RED→Tom Wilkie, USE→Brendan Gregg, four golden signals→Google SRE are **correctly attributed**; the burn-rate table (14.4×/1h/5m, 6×/6h/30m, 3×/24h/2h, 1×/72h/6h) **matches the SRE Workbook**; the availability ladder (99.9%≈43 min, 99.99%≈4 min, 99.999%≈26 s per month) is **right**; error-budget math (0.1%×40,320 min≈40 min) is **right**; head-vs-tail sampling and on-CPU-vs-off-CPU distinctions are **correctly characterized**. No hallucinated history, no invented "named rules," no fabricated company case studies presented as load-bearing fact. This is notably better than the architecture-patterns dir.

## Genuine strengths (keep)

- **The tracing worked example** (`distributed-tracing...` lines 393–514) is the best single artifact in the directory: a real waterfall (checkout → reserve_inventory → inventory-svc → `SELECT … FOR UPDATE`), a correct `db.lock_wait_ms` drill-down, a pivot to logs by `trace_id`, and finding the culprit `txid 9001` bulk import holding row locks. It teaches the *method*, not just the vocabulary. The `SELECT … FOR UPDATE SKIP LOCKED` remediation option is a genuine senior touch.
- **The checkout SLO worked example** (`slos...` lines 368–514): user-journey-first (not per-service), SLIs defined with explicit numerator/denominator and bot/health-check exclusion, real PromQL burn-rate alerts, and a tiered error-budget policy (<50% / 50–90% / 90–100% / >100%). The closing insight — *"The framework's value isn't the math. It's the aligned conversation"* — is exactly the staff-level point.
- **Cardinality as both cost AND value** is held in tension correctly (the "right home for each dimension" table on lines 114–122 is a high-signal cheat sheet), and the file resists the common trap of treating high cardinality as purely evil (Honeycomb counter-narrative).
- **`100% is the wrong target`** section (`slos...` 214–221) including the "customer's systems fail more than your budget anyway" argument — the real Google SRE reasoning, not a paraphrase.
- **Composite/dependent SLO math** (`X^N`, "three dependencies at 99.9% = 99.7%") framed as an *architectural* tool, not just arithmetic.
- **Off-CPU profiling** (`profiling...` 88–95) is correctly explained — most "deep dives" never mention it, and conflate "low CPU" with "fast." The differential flame graph for regression detection is a real, current practice.

## 🛠️ Improvement plan (tailored to this directory)

**Theme: this dir's problem is *padding + a few unsourced numbers*, not concepts. It's close to genuinely excellent — cut the fat and fix the figures.**

1. **De-pad aggressively (~35–45% reduction).** Every file ends with the same four-to-five restating blocks: *What Junior Engineers Miss / What Senior Engineers Notice / 20% Knowledge / Interview Perspective / Final Mental Model*. In `metrics-logs-traces.md` the "junior misses," "senior notices," and "20% knowledge" lists are near-verbatim restatements of the Core Mental Models (cardinality-is-cost, measure-distributions-not-averages, trace-IDs-in-logs appear 3–4 times each). Collapse into **one** "Key takeaways" block per file. This repetition is exactly what manufactures the "3000+ word" length.
2. **Fix the Splunk cost figure** (`cardinality...` line 139) — either correct it to ~$950M/yr with the right pricing basis, or replace with a hedged range and a real citation. A wrong number with three significant figures is worse than no number.
3. **Sharpen the four genuine technical imprecisions** above: summary quantiles are *non-aggregatable* (not "harder"); trace-id is a *128-bit random ID* (not a UUID); head-sampling consistency is a *property of ParentBased samplers*, not of the flag; and reconcile line 143 with the contradicting failure scenario on line 269.
4. **Go deeper where profiling currently bails.** The profiling file is the thinnest "deep dive": it asserts "sampling beats instrumentation" and "~1–3% overhead" but never explains *how* a sampling profiler actually interrupts (timer signals / `perf_event_open` / eBPF stack walking), why DWARF/frame-pointer unwinding matters (the classic "missing frames because `-fomit-frame-pointer`" gotcha), or why p99-latency profiling needs *off-CPU* flame graphs specifically. Add the unwinding-and-symbolication failure mode — it's the #1 real-world profiling pain.
5. **Add the cardinality-control mechanics, not just the warning.** The file repeats "audit cardinality / use URL patterns not raw URLs" but never names the actual levers a staff engineer reaches for: **recording rules / pre-aggregation, metric relabel/drop rules at scrape time, exemplars to bridge metric→trace, and limits like `sample_limit`**. Right now it's strong on *why* and thin on *how to actually cap it*.
6. **Promote the two worked examples** (`distributed-tracing` debugging session, `slos` checkout design) as the template the other three files should imitate — concrete, narrative, ends in a fix. The metrics/cardinality/profiling files would jump half a point each if they each carried one equally rigorous worked example instead of a fifth summary list.
