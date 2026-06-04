# 🔍 Audit — `concurrency/`

**Reviewed:** 10 files (~4,041 lines) · **Lens:** brutal-honest, held to the corpus's "senior/staff 3000+ word deep dive" claim · **Avg score: ~3.8/5**

---

## Verdict in one line
The **strongest directory in the corpus on technical accuracy** — the marquee gotchas (GIL releases on I/O, false sharing as cache-line bouncing, lock-free ≠ wait-free ≠ fast, Amdahl/Gustafson, async-Rust `Send`/`Pin`) are nearly all correct — but it's **diluted by relentless padding** (the five repeating summary sections add ~30–40% redundancy) and **a handful of fabricated round numbers and one anachronistic claim** that a fact-pass must scrub.

## Per-file scores (out of 5)

| File | Score | One-liner |
|---|---|---|
| `backpressure-and-queues.md` | **4.5** | Best in dir; Little's Law + utilization trap correct, layered worked example is genuinely staff-level |
| `locks-mutexes-and-lock-free.md` | **4.4** | Excellent; CAS/ABA/MESI/priority-inversion all right; one garbled "weaker stronger" line |
| `parallelism-vs-concurrency.md` | **4.3** | Clean conceptual spine; Amdahl AND Gustafson formulas correct; rare to see both |
| `async-rust-and-the-borrow-checker.md` | **4.2** | Accurate on the parts that bite (`Send`, `Pin`, cancellation leak, std-Mutex-across-await) |
| `actor-model-and-message-passing.md` | **4.0** | Solid; at-most-once default + supervision + virtual actors correct; "goroutines are actors" wobble |
| `coroutines-and-green-threads.md` | **3.9** | Good layered framing; function-coloring attribution correct; padding-heavy |
| `python-runtime-and-the-gil.md` | **3.6** | Core GIL model correct; invented "~50ns" and "3.16+" precision; thin at 2,243 words |
| `jvm-internals-and-virtual-threads.md` | **3.5** | Good Loom coverage; pinning mechanism imprecise; broad-and-shallow on GC |
| `go-runtime-and-goroutines.md` | **3.4** | GMP correct; **anachronistic "container-aware GOMAXPROCS (modern Go)"**; self-contradicting deadlock claim |
| `cpu-caches-and-false-sharing.md` | **3.2** | Correct but the thinnest file (2,108 words); reads like notes, not a deep dive |

## Concrete errors found (must-fix)

- 🚩 **Anachronism / misleading (`go-runtime-and-goroutines.md`):** Scaling section claims "**Cloud: container-aware GOMAXPROCS (modern Go)**" and "GC sub-ms pauses; production at huge scale" presents container-awareness as a standard runtime feature. Until **Go 1.25 (Aug 2025)** `GOMAXPROCS` defaulted to the *host* CPU count and ignored cgroup CPU limits — the long-standing fix was the third-party `uber-go/automaxprocs`. Worse, this directly contradicts the file's own **Scenario 4 ("The CPU pegging via GOMAXPROCS… Go thinks it has 32… Fix: set GOMAXPROCS to actual CPU")**. Pick one and date it.
- 🚩 **Self-contradiction (`go-runtime-and-goroutines.md`):** "The channel deadlock… **Detected by Go's runtime; panic**" (Scenario 3 and Production section). Go's deadlock detector only fires for **whole-program** deadlock ("all goroutines are asleep"). A two-goroutine deadlock while other goroutines run is **not** detected. The file says this correctly once ("deadlock detector (only for whole-program deadlocks)") then overstates it twice — reconcile.
- 🚩 **Fabricated precision (`python-runtime-and-the-gil.md`):** "**Default GIL removal in 3.16+ tentatively**." PEP 703 deliberately does **not** name a default-on version; it specifies a 3-phase experimental→supported→default plan with no committed release. The "3.16+" is invented. Same file: "**GIL acquisition: ~50ns**" — an unsourced made-up number.
- 🚩 **Garbled definition (`locks-mutexes-and-lock-free.md`):** wait-free described as "**A weaker stronger guarantee**" — incoherent. Wait-free is strictly **stronger** than lock-free (per-thread bounded progress vs. system-wide progress). Delete "weaker."
- 🚩 **Imprecise mechanism (`jvm-internals-and-virtual-threads.md`):** "A virtual thread inside a `synchronized` block can't unmount. **JVM creates an extra carrier thread**." Pinning means the carrier is *blocked* (pinned); the scheduler may add *compensating* carriers up to a cap when a pinned vthread blocks, but the flat "creates an extra carrier thread" mis-states it as automatic relief. Also worth noting: **JDK 24 / JEP 491 removed `synchronized` pinning** — the file hedges "see Java 24+" but should state the fix landed.
- 🚩 **Overstated equivalence (`actor-model-and-message-passing.md`):** opener lists "**Go's goroutines + channels are actors with different vocabulary**." They are CSP, not actors (no per-entity mailbox/address; channels are first-class). The file *corrects itself* later ("Not strictly actors… channels are first-class, not actor inboxes") — soften the headline claim to match.
- 🚩 **Loose attribution (`locks-mutexes-and-lock-free.md`):** "Java's `volatile` and **Go's atomic operations default to sequential consistency**." Java `volatile` is SC-for-data-race-free under the JMM (defensible shorthand). Go's `sync/atomic` is sequentially consistent *as documented since Go 1.19's memory model* — fine, but pre-1.19 the guarantee was unspecified; a one-line date would prevent a subtle wrong impression.
- 🚩 **Unsourced round numbers throughout (pattern):** "Channel ops: 50–200ns", "GIL acquisition ~50ns", "multiprocessing IPC: milliseconds", goroutine "switch: nanoseconds", actor dispatch "microseconds". Most are plausible order-of-magnitude, but they are presented as measured fact with no hardware/benchmark context. Hedge or cite.

**No hallucinated citations or fabricated history found** (a real improvement over `architecture-patterns/`). The named references that *are* checkable — Hewitt 1973, Erlang AXD301 nine-nines, WhatsApp "2M connections/server", Michael & Scott 1996, Coffman 1971 deadlock conditions, NASA Mars Pathfinder priority inversion (1997), Bob Nystrom's "What Color Is Your Function?" (2015), PEP 684/703 — are all real and correctly attributed.

## Genuine strengths (keep)

- **The commonly-botched concepts are correct.** GIL **releases on I/O and in GIL-releasing C extensions** (NumPy/BLAS) — stated clearly and repeatedly, the single most-mangled fact in the domain. False sharing is correctly framed as **cache-line bouncing of *logically independent* variables**, not real sharing. **Lock-free ≠ wait-free ≠ fast** is nailed, including "lock-free is not always faster under low contention." Async Rust correctly ties `Send` to "future may move threads," `Pin` to self-referential state machines, and flags **std-`Mutex`-held-across-`await`** and **cancellation-drops-an-open-transaction** — the exact things that bite.
- **`backpressure-and-queues.md` is genuinely staff-level.** Little's Law, the M/M/1 utilization trap ("at 90% util ≈10× service time"), "variance kills more than rate," the hidden-queue taxonomy (TCP rcv buffer, connection-pool waiters, `LinkedBlockingQueue` unbounded default), retry-storm amplification, and a **layered worked example with a side-by-side "with vs without backpressure" timeline** — this is the template the rest should imitate.
- **`parallelism-vs-concurrency.md`** includes **both Amdahl and Gustafson** with correct formulas and the right framing ("different questions, not contradictory") — uncommon and high-signal.
- **Honest failure-mode framing everywhere:** goroutine leaks, pinned virtual threads, lock convoys, priority inversion (with the real Pathfinder fix = priority inheritance), `select{}`-with-`default` busy-loop trap, fork-after-thread in Python. These are real war-stories, not filler.
- **Cross-domain links are accurate and useful** (actors→supervision→cascade containment; lock waits→queues→backpressure; MESI→false sharing).

## 🛠️ Improvement plan (tailored to this directory)

**Theme: this dir is *accurate and conceptually strong* — its enemies are *padding and a few invented numbers*, not wrong ideas.**

1. **Fix the 8 flagged errors first**, priority order: Go `GOMAXPROCS` anachronism (date it to 1.25 / mention `automaxprocs`) → Go whole-program-only deadlock detection → PEP 703 "3.16+" and "~50ns" inventions → wait-free "weaker stronger" → vthread pinning mechanism + JEP 491 → "goroutines are actors" headline.
2. **De-pad aggressively (~30–40% reduction).** Every file repeats *What Junior Engineers Miss / What Senior Engineers Notice / 20% Knowledge / Interview Perspective / Final Mental Model* — five sections restating the same 6–10 bullets. Collapse to **one "Key takeaways"** block per file. `actor-model`, `coroutines`, `parallelism`, and `go-runtime` are the worst offenders; the "Senior Notices" lists are near-verbatim inversions of the "Junior Misses" lists.
3. **Bring the two thin files up to the 3000-word bar with real depth, not more summary bullets.** `cpu-caches-and-false-sharing.md` (2,108 words) and `python-runtime-and-the-gil.md` (2,243) read like notes. Caches needs: actual MESI→MESIF/MOESI variants, store buffers vs. invalidation queues, why `volatile`/atomics interact with coherence, a concrete `perf c2c` reading. GIL needs: the eval-loop `_Py_CheckInterval`/`sys.setswitchinterval` mechanics, the convoy effect on multi-core (Beazley's classic finding that GIL can make multithreaded CPU code *slower* than single-threaded), and what biased reference counting / deferred reclamation actually change under nogil.
4. **Replace every bare latency number with a hedge or a source.** Add one sentence per "Performance Perspective" section: "order-of-magnitude on commodity x86; measure on your hardware." This kills the false authority of the fabricated `~50ns`-style figures.
5. **Add the missing free-threading nuance the hint calls for.** The GIL file should explicitly cover **3.13's `--disable-gil` build flag** and that free-threading is *opt-in at build time* (not a runtime toggle), plus the documented ~5–10% single-thread regression and ABI implications for C extensions — currently glossed.
6. **Promote `backpressure-and-queues.md` and `locks-mutexes-and-lock-free.md` as the directory's template** — they prove the corpus *can* be both accurate and deep; the weaker files (`cpu-caches`, `go-runtime`, `jvm`) should be rewritten to that standard rather than padded to length.
