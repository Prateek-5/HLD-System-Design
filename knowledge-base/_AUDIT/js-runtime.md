# 🔍 Audit — `js-runtime/`
**Reviewed:** 6 files (~2844 lines) · **Lens:** brutal-honest, held to the corpus's "senior/staff 3000+ word deep dive" claim · **Avg score: 4.0/5**

## Verdict in one line
The best-fact-checked directory in the corpus so far — the event-loop and V8 files are genuinely staff-grade and nail the exact things this domain usually gets wrong (libuv pool is 4 for fs/dns/crypto NOT network; GC is generational/scavenger NOT refcount; nextTick > microtasks; mono/poly/megamorphic ICs) — but the GC file is a thin survey that leans on the JVM/Go to pad its word count, and all six carry the corpus-wide ~25–30% padding tax of restating-the-same-list sections.

## Per-file scores (out of 5)

| File | Score | One-liner |
|---|---|---|
| `event-loop-and-async-runtime.md` | 4.4 | Excellent, accurate, well-structured; the worked worker-pool example earns the staff claim. |
| `v8-internals-and-hidden-classes.md` | 4.4 | Deepest file here; hidden classes / IC states / tiering all correct; one fabricated `--trace-ic` snippet. |
| `nodejs-architecture-and-libuv.md` | 4.2 | Tight, accurate libuv/V8 split; correctly separates kernel-async network I/O from the thread pool. |
| `streams-and-backpressure-in-node.md` | 4.0 | Solid, correct backpressure mechanics; heavy overlap with itself and the event-loop file. |
| `web-workers-and-shared-memory.md` | 3.8 | Accurate and complete but survey-flat; Atomics/SAB/COOP-COEP right, but little depth beyond an API tour. |
| `garbage-collection-and-memory-management.md` | 3.2 | Weakest: a generic GC survey padded with JVM/Go/ZGC; the bullet-fragment sections are filler, and refcount "atomic increments" is wrong for CPython. |

## Concrete errors found (must-fix)

🚩 **`garbage-collection-and-memory-management.md` — reference counting described as using atomic increments.** Quote: *"Per-mutation overhead (atomic increments)."* listed under reference counting's cons, immediately followed by "Python's primary mechanism." **Correction:** CPython's reference counts are **not** atomic — they are plain (non-atomic) increments/decrements protected by the GIL, which is precisely *why* removing the GIL is so hard. Atomic refcounting is what Swift's ARC and free-threaded/no-GIL Python do, and it's expensive *because* it's atomic. As written, the file implies standard Python refcounting pays the atomic cost; it does not.

🚩 **`v8-internals-and-hidden-classes.md` — fabricated/incoherent `--trace-ic` output.** Quote: the "V8 measurement" block claims a single IC site at `calc.js:25:20` saw these hidden classes:
```
- hidden class 0x123abc: {id, name, qty, unitPrice, tax}
- hidden class 0x456def: {id, name, qty, unitPrice, discount, subtotal}
- hidden class 0x789012: {id, name, qty, unitPrice, tax, subtotal}
```
**Correction:** This is invented output, not real `--trace-ic` formatting (real output looks like `[ic] ... (LoadIC) ... MONOMORPHIC -> POLYMORPHIC`, with map addresses, not pretty `{field}` sets). Worse, it's internally inconsistent: a single property-write IC at one line cannot simultaneously observe shapes that both *include* and *exclude* `subtotal` if `subtotal` is the property being written there. Flag it as illustrative pseudo-output or replace with a real trace; presenting it as literal measurement is a hallucination.

🚩 **`nodejs-architecture-and-libuv.md` — Node born from "CPython's libpython-style FFI."** Quote: *"Ryan Dahl combines V8 with libev (event loop) and CPython's libpython-style FFI."* **Correction:** This is garbled history. Original Node combined V8 + **libev** + **libeio** (the thread pool for async file I/O) + **c-ares** (DNS); there was no "CPython libpython FFI" involved. The libev→libuv evolution (correctly described two paragraphs later) is right, but the libeio piece — the actual ancestor of today's thread pool — is omitted and a CPython reference is invented in its place.

🚩 **`event-loop-and-async-runtime.md` — async/await desugaring drops error semantics.** Quote: the claim that `async function f(){ const a = await getA(); ... }` "Compiles to (roughly): `getA().then(a => getB(a)).then(b => b)`." **Correction:** Acceptable as a *happy-path* sketch but it's wrong about rejection propagation and the synchronous-throw boundary: a real async function wraps the synchronous body so that a throw *before* the first await still returns a rejected promise, whereas the `.then` desugaring would throw synchronously at call time. For a file that elsewhere stresses "throwing inside a Promise" semantics, this simplification undercuts its own point. Add a one-line caveat.

🚩 **`nodejs-architecture-and-libuv.md` — `--max-old-space-size` "Default: 2 GB on 64-bit."** Quote: *"Default: 2 GB on 64-bit (was 1.4 GB for years; raised)."* **Correction:** Imprecise. The old fixed default was ~1.5 GB (≈1400–1500 MB). Modern Node (since ~v12) does **not** use a fixed 2 GB default — it sizes the old-space heap based on available physical memory (`--max-old-space-size` is derived, roughly ~50% of RAM up to a cap, with newer versions raising it for large-memory machines). Stating a flat "2 GB default" is a common myth; the real answer is "memory-dependent." Same flat "2GB on 64-bit" claim is repeated in `v8-internals-and-hidden-classes.md` ("Default `--max-old-space-size` is 2GB on 64-bit").

🚩 **`event-loop-and-async-runtime.md` — `setImmediate` vs `setTimeout(0)` "non-deterministic" outside I/O is slightly overstated.** Quote: *"Outside, the order is non-deterministic."* **Correction:** Minor/defensible but worth tightening: the order at the top of the main module is *not truly random* — it depends on whether the 1 ms `setTimeout` timer has elapsed by the time the loop reaches the timers phase (which depends on process startup cost). Calling it "non-deterministic" is the common shorthand and the file uses it carefully, but a staff-level treatment would say "depends on whether the timer threshold has elapsed when the loop starts," not imply a coin flip.

Note on things that are **correct** and frequently gotten wrong elsewhere (credit where due): libuv pool default = 4 used for fs/dns(getaddrinfo)/crypto/zlib and **not** network I/O (kernel epoll/kqueue/IOCP) — stated correctly in two files; `process.nextTick` drains before the microtask/Promise queue — correct; GC is generational with Scavenge (young) + mark-sweep-compact (old) under Orinoco, explicitly **not** refcounting for V8 — correct; IC states mono→poly(≤4)→megamorphic — correct; Ignition→Sparkplug→Maglev→TurboFan tiering with Maglev (2023) — correct and current; streams `highWaterMark` 16 KB binary / 16 objects, `write()` returns false → wait for `drain` — correct; libuv max pool 1024 in modern libuv — correct; transferable vs structured-clone, SAB+Atomics futex semantics, COOP/COEP requirement — all correct.

## Genuine strengths (keep)

- **The event-loop worked example is the gold standard for this corpus.** The "30ms avg / 800ms p99 / 45% CPU" diagnosis → `monitorEventLoopDelay` instrumentation → CPU profile → the explicit "this is NOT a CPU-utilization problem, it's single-threaded blocking" insight → a real `WorkerPool` implementation is exactly the senior/staff narrative the corpus *claims* to deliver. Most files only assert; this one demonstrates.
- **V8 file's "what V8 sees" decomposition** (2^N hidden classes from optional fields, then ×2 again when `subtotal` is added in the loop → 16+ shapes) is the single best concrete explanation of IC degradation I've seen in these docs, and the before/after benchmark with the capacity-math conclusion ("half a CPU's worth of capacity, recovered") is real engineering thinking.
- **`delete` → dictionary-mode transition** scenario (v8 file, Scenario 2) is a precise, true, frequently-missed footgun, with a correct rest-spread fix.
- **The libuv file's "how many threads does Node use?" framing as a trick question** ("JS: one. libuv pool: four. Network I/O: kernel async, no threads.") is exactly the right interview mental model and the rare place where "Node is single-threaded" is dismantled correctly rather than just repeated.
- **Streams file's correct insistence on `pipeline` over `pipe`** for error propagation/cleanup, plus the manual `write()`/`drain` backpressure loop and the `for await` rate-limiting-as-backpressure insight, is accurate and practically useful.
- **Strong cross-domain analogies that actually map** (event loop = single-lane bridge / ATC; IC mono/poly/mega = DB query planner replanning; TurboFan speculation = hardware branch prediction). These are signal, not filler.

## 🛠️ Improvement plan (tailored to this directory)

**Theme: This directory is 80% staff-grade already — fix the GC file, kill the fabricated traces, and cut the cross-file redundancy that's diluting genuinely good content.**

1. **Rewrite the GC file to be V8-first, not a JVM/Go survey.** Right now ~40% of it is JVM (Serial/Parallel/CMS/G1/ZGC/Shenandoah) and Go GOGC content that belongs in a JVM or Go doc, while the V8-specific section is a stub that punts to the v8-internals file. For a `js-runtime/` directory, invert it: lead with V8's Scavenge (Cheney semispace copying), the new-space-to-old-space promotion threshold (survives ~2 scavenges), Orinoco concurrent marking + write barriers, and the actual `--trace-gc` output a Node engineer reads. Keep JVM/Go to one comparison paragraph.

2. **Fix the refcount-atomicity error and the libeio history.** State plainly that CPython refcounts are non-atomic (GIL-protected) and that *that's the GIL's whole reason for being*; contrast with Swift ARC's atomic retain/release. In the libuv file, replace the "CPython libpython FFI" line with the real lineage: V8 + libev + **libeio** + c-ares → libuv unified all of this in 2011.

3. **Replace every fabricated tool-output block with either a real trace or an explicit "illustrative" label.** The `--trace-ic` block in the v8 file and the ASCII flame-graph in the event-loop file (`[==========] handle_request ... parse_invoice_xml (60%)`) read as literal captured output but are invented. Either paste a real (trimmed) trace or prefix with "schematic, not literal output." Staff readers will catch fabricated tooling output instantly and it poisons trust in the rest.

4. **Correct the `--max-old-space-size` default in both files.** Replace "2 GB default on 64-bit" with the accurate modern behavior: old default ~1.5 GB fixed; modern Node derives the limit from available physical memory. This is a textbook interview "gotcha" and the docs currently teach the myth.

5. **Add the one missing async-correctness caveat to the event-loop file.** The `.then` desugaring is fine as a sketch but add: "a real async function also converts a synchronous throw before the first `await` into a rejected promise" — this closes the loop with the file's own (correct) point that throwing in an async function returns a rejected promise.

6. **De-duplicate the cross-file boilerplate (~25–30% redundancy).** The "thread pool is 4 / DNS starvation / fs.readFileSync is banned / nextTick > microtasks / monitor event loop lag / CPU work blocks the loop" cluster appears nearly verbatim across the event-loop, libuv, and (partly) streams files, and every file ends with the same four ritual sections — "What Junior Engineers Miss," "What Senior Engineers Notice," "20% Knowledge," "Final Mental Model" — that restate the body. The GC file's versions of these are pure bullet fragments ("That **allocation rate matters**.", "**Read GC logs**."). Collapse to ONE of {Junior/Senior contrast, 20% summary} per file and let the DNS-starvation / nextTick-priority material live in exactly one file with cross-links from the others.
