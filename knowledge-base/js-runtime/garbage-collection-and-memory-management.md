# Garbage Collection & Memory Management

> *"Garbage collection is what happens when computer scientists tell programmers 'we'll handle memory for you, you focus on the business logic.' The contract is generous in development. In production, GC pauses become tail-latency villains, allocation rates become throughput bottlenecks, and 'why is my service stuttering' often has its answer in the runtime's hidden bookkeeping."*

---

## 🎯 Start Here — Intuition

> **In one line:** your program keeps creating data it eventually stops using — garbage collection is the runtime quietly finding and throwing away that unused data so you never have to free memory by hand.
>
> **Analogy:** a hotel housekeeping crew. Guests (your code) check into rooms (memory) and leave junk behind. Housekeeping periodically walks the floors, figures out which rooms are still occupied vs. abandoned, and clears the abandoned ones for reuse. Clean continuously and guests barely notice; do one big sweep and the whole floor freezes while it happens — that freeze is a "GC pause."
>
> **Assumes you already know:** what the [throughput-vs-latency trade-off](../../learn/foundations/scaling/scalability.md) means (this topic lives entirely in that trade-off space), plus basic memory concepts (stack, heap, pointers/references). This is a senior/staff runtime-engineering topic with **no beginner learning-path counterpart** — that's expected, not a gap in your knowledge.
>
> **Level:** this file is 🔴 overall. The intuition and history sections are approachable; the algorithm internals and per-runtime tuning are deep. If a section's tag feels above you, that's the signal to slow down — **you are not behind.**

---

## Topic Overview 🟢

Garbage collection (GC) is the runtime mechanism that automatically reclaims memory when objects are no longer reachable. Different languages take different approaches: V8 (JavaScript) uses generational GC; the JVM (Java Virtual Machine) has dozens of GC algorithms; Go uses a concurrent mark-sweep; Python uses reference counting plus cycle detection.

The fundamental trade-offs are universal: **throughput** (how much GC work per unit of compute) vs **latency** (how long pauses are) vs **memory overhead** (how much extra space the GC needs). Different applications optimize different axes. A batch ETL (Extract, Transform, Load) job tolerates long pauses; a low-latency trading system can't.

This is the topic where language internals meet production reality. Most engineers treat GC as a black box until p99 latency spikes correlate with full GCs. Then GC tuning becomes a real discipline. Understanding the algorithms — generational, concurrent, regional, copying — is what separates "set the heap size and hope" from "I know exactly why my service has a 200ms pause every 30 seconds."

---

## Intuition Before Definitions 🟢

Imagine a janitorial team for an office building.

**Reference counting (Python).** Every object has a counter: how many things reference it? When the counter hits zero, the object is immediately discarded. Simple; can't handle cycles (two objects referencing each other but nothing else).

**Mark-and-sweep (most VMs).** Periodically, walk the room. Mark every object reachable from the entrance. Sweep up the unmarked. Simple; takes time proportional to the room's contents.

**Generational (V8, JVM).** Most objects die young. Allocate everything in a small "young" room. When that room fills, quickly clean it; promote survivors to a larger "old" room. Old room is collected rarely.

**Concurrent collection (Go, modern JVM).** Janitors work alongside office workers, in small bursts, instead of stopping work for cleaning.

The trade-offs map: simpler GC = better predictability but worse throughput; more sophisticated = better throughput but more complex pauses. The right choice depends on the application's latency tolerance and allocation pattern.

---

## Historical Evolution 🟢

**Era 1 — Manual memory management.**
C, C++. Programmer manages malloc/free. Maximum control; common bugs (leaks, use-after-free).

**Era 2 — Reference counting.**
Smalltalk, Python's primary mechanism. Simple; cycle detection added later.

**Era 3 — Mark-and-sweep.**
Lisp 1959. Periodic full traversal. Stop-the-world pauses.

**Era 4 — Generational GC.**
Lieberman & Hewitt 1983. Young/old separation. Massive throughput improvements.

**Era 5 — Concurrent and incremental GC.**
1990s onward. JVM CMS (Concurrent Mark-Sweep, deprecated), G1 (Garbage First), Shenandoah, ZGC (Z Garbage Collector). Reduce pauses by overlapping GC with application work.

**Era 6 — Modern low-latency GCs.**
ZGC, Shenandoah, OpenJDK's recent additions. Sub-millisecond pauses on multi-terabyte heaps.

The pattern: each generation reduced GC pauses, increased throughput, or both — at the cost of complexity.

---

## Deep Technical Explanation 🔴

> ⚠️ The rest assumes the basics above are solid.

### Reference counting

Each object has a counter. Increment on new reference; decrement on dereference. At zero, free.

Pros: deterministic; immediate reclamation.
Cons:
- Per-mutation overhead (every reference change touches a counter). In CPython these increments/decrements are *non-atomic* — they're protected by the GIL (Global Interpreter Lock), which is precisely why removing the GIL is so hard. Swift's ARC (Automatic Reference Counting) and free-threaded ("no-GIL") Python use *atomic* refcounts, which are correct under concurrency but measurably more expensive.
- Doesn't handle cycles (Python uses cycle detector for these).
- Cache-unfriendly (counter updates touch every referenced object).

Python's primary mechanism. Swift uses ARC (Automatic Reference Counting) — same idea, compile-time inserted.

### Mark-and-sweep

Two phases:
1. **Mark**: traverse from roots (stack, registers, globals); mark all reachable.
2. **Sweep**: walk all objects; free unmarked.

Pros: handles cycles; simple.
Cons: pauses scale with heap size; fragmentation.

### Mark-compact

Mark phase same. Compact phase: move live objects together; eliminate fragmentation.

Pros: no fragmentation.
Cons: more work; pointers must be updated.

### Copying GC

Allocate in "from-space"; when full, copy live to "to-space"; swap.

Pros: very fast allocation (bump pointer); compaction included.
Cons: requires 2× heap.

### Generational GC

Young generation collected frequently with copying GC; old generation collected rarely with mark-compact or similar.

Why it works: most objects die young. Copying just the survivors is much cheaper than walking the whole heap.

V8: young generation ("new space"), old generation ("old space"). Major collectors handle old; scavenger handles young.

JVM: young (Eden + 2 survivor spaces), old, sometimes permanent. Minor GC for young; major GC for old.

### Tri-color marking

Concurrent marking algorithm:
- White: not yet visited; potentially garbage.
- Gray: visited but children not yet visited.
- Black: visited and all children visited.

Marker walks gray nodes; mutator (application) creates new objects black or modifies pointers carefully (write barrier).

Goal: at end of mark, all white objects are garbage.

### Write barriers

When the application modifies a pointer during concurrent marking, the GC must know — otherwise it might miss reachable objects.

A *write barrier* is code inserted at every pointer write. It records the change for the GC.

Cost: small per-write overhead. Necessary for concurrent / incremental GC.

### Concurrent GC

Mark phase runs concurrently with application. Application "helps" by maintaining write barriers.

Stop-the-world only for very short phases (initial mark, final remark).

Examples: G1 (JVM), Shenandoah (JVM), ZGC (JVM), Go's GC.

### Region-based GC

Heap divided into regions. Each region collected somewhat independently.

G1 (Garbage First): identifies regions with most garbage; collects those preferentially.

Allows parallelism, partial collection, predictable pause times.

### V8's GC specifically

(See [v8-internals-and-hidden-classes.md](./v8-internals-and-hidden-classes.md) for V8 GC details.)

Generational:
- **Young (new space)**: small (1-8 MB); collected frequently with Scavenge.
- **Old (old space)**: gigabytes; collected with Mark-Sweep or Mark-Compact.

Modern V8 (Orinoco):
- Concurrent marking.
- Parallel collection.
- Incremental collection.
- Stop-the-world only for very short phases.

Typical pause: ~10-50ms; can spike to hundreds of ms in pathological cases.

### JVM GC algorithms

**Serial GC**: single-threaded; for small heaps.
**Parallel GC**: multi-threaded; throughput-oriented; long pauses.
**CMS (deprecated)**: concurrent mark-sweep; reduced pauses.
**G1**: regional; predictable pause times. Default since Java 9.
**ZGC**: sub-millisecond pauses on multi-TB (terabyte) heaps. JEP (JDK Enhancement Proposal) 333.
**Shenandoah**: similar goals to ZGC; Red Hat's implementation.

Each has knobs. Tuning matters for production.

### Go's GC

Concurrent mark-sweep. Designed for low-latency:
- Goroutines run alongside GC.
- Write barriers maintained.
- Stop-the-world phases are short (sub-millisecond).
- Trade-off: more CPU for GC; less for application.

Tunable via `GOGC` (Go Garbage Collector percentage; target heap growth before GC; default 100%).

### Allocation patterns

**Bump allocation**: new objects added at the end of free space. Very fast.

**Free list**: maintain list of free chunks; allocate from list. Slower but reuses space.

**Thread-local allocation buffers (TLAB)**: each thread has its own bump-allocate region. Avoids contention.

Modern runtimes (V8, JVM, Go) all use TLABs.

### Memory leaks in GC'd languages

GC reclaims unreachable objects. *Reachable* objects that are no longer needed are leaks.

Common patterns:
- Caches that grow without bound.
- Long-lived collections holding references to short-lived data.
- Listeners/callbacks not unregistered.
- Closures capturing more than they need.

Tools: heap snapshots; retainer paths; allocation profiling.

### GC tuning

**Heap size**: too small = frequent GCs; too big = long pauses.

**Young generation size**: too small = early promotion to old; too big = long young collections.

**Concurrent vs stop-the-world ratio**: more concurrent = more CPU; fewer pauses.

**Allocation rate**: reduce by pooling; reusing buffers.

Heuristic: profile first; tune based on data.

---

## Real Engineering Analogies 🟢

**The office janitorial crew.**
Cleans throughout the day (concurrent GC) vs cleans only at night (stop-the-world). Different trade-offs in disturbance vs efficiency.

**The library deaccession process.**
Periodically removes books no one's checking out. Some libraries do continuously; some rarely with a big project. Same trade-off as GC: ongoing small effort vs occasional big effort.

---

## Production Engineering Perspective 🟡

What goes wrong:

- **The GC pause that ruined p99.** Service averages 5ms; p99 is 800ms. Investigation: full GC every 30s pauses for 600ms. Tune to G1 or ZGC; pauses drop to 30ms.
- **The allocation-rate disaster.** Service allocates 1GB/sec; GC pressure dominates CPU. Refactor: object pooling; pre-allocated buffers. Allocation drops 90%; throughput doubles.
- **The OOM (Out Of Memory) that wasn't a leak.** Memory grew; OOMed. Investigation: legitimate workload; heap was sized too small. Fix: bigger heap.
- **The leak from closures.** Long-lived task holds closure capturing request body. Memory grows. Fix: don't capture large objects in long-lived closures.
- **The concurrent GC's CPU cost.** Switched to Shenandoah for latency. Throughput dropped 15%. Trade-off: pauses better, CPU worse. Sometimes acceptable.
- **The undersized young gen.** Allocations promoted to old too quickly. Old fills; major GCs frequent. Fix: bigger young generation.

The senior engineer's habits:
- **Profile** to identify GC-related issues.
- **Read GC logs**.
- **Tune** based on workload.
- **Reduce allocations** in hot paths.
- **Choose GC algorithm** appropriate to latency goals.

---

## Failure Scenarios 🟡

**Scenario 1 — The full GC cliff.**
Service has 20GB heap. Major GC runs every 5 minutes; pauses for 2 seconds. p99 ruined. Fix: G1 GC with paused-time goal.

**Scenario 2 — The allocation flood.**
Code path allocates 100MB intermediate strings per request. Under load: GC pressure dominates. Fix: streaming; reuse buffers.

**Scenario 3 — The "leak" that's a cache.**
Cache grew; no eviction. Heap full. Fix: bounded cache.

**Scenario 4 — The promotion storm.**
Young gen too small. Survivors promoted aggressively. Old gen fills; major GC. Tuning: bigger young gen.

**Scenario 5 — The Go GC tuning.**
Service spends 30% of CPU on GC. Investigation: high allocation rate. Reduced via pooling; CPU recovered.

---

## Performance Perspective 🔴

- **Allocation cost**: nanoseconds per object (TLAB).
- **Young GC**: milliseconds typical; scales with surviving objects.
- **Major GC**: longer; scales with old-gen size.
- **Concurrent GC overhead**: 10-30% CPU typically.
- **Pause time**: depends on algorithm; modern can be sub-ms.

---

## Scaling Perspective 🟡

- **Heap size**: bigger heaps = longer GC; modern algorithms (ZGC) handle multi-TB.
- **Allocation rate**: scales with workload; can become bottleneck.
- **Multi-process** can avoid single-heap limits.
- **At hyperscale**: custom allocators; pre-allocated pools; sometimes manual memory management for hot paths.

---

## Cross-Domain Connections 🟡

- **V8 internals**: V8's GC details. (See [v8-internals-and-hidden-classes.md](./v8-internals-and-hidden-classes.md).)
- **Profiling**: GC pauses show in profiles. (See [profiling-and-flame-graphs.md](../observability/profiling-and-flame-graphs.md).)
- **SLOs (Service Level Objectives)**: GC pauses affect tail latency / SLO compliance. (See [slos-error-budgets-and-alerting.md](../observability/slos-error-budgets-and-alerting.md).)
- **Capacity planning**: heap size is a planning input. (See [auto-scaling-and-capacity-planning.md](../scalability/auto-scaling-and-capacity-planning.md).)
- **Async Rust**: no GC; deterministic memory. (See [async-rust-and-the-borrow-checker.md](../concurrency/async-rust-and-the-borrow-checker.md).)

The unifying observation: **GC trades programmer-time for runtime-time. The runtime's complexity is the cost of programmer simplicity. Modern GCs are excellent; understanding them remains operationally essential.**

---

## Real Production Scenarios 🟡

- **Discord's Go-to-Rust migration**: partly motivated by Go GC pauses.
- **LinkedIn's JVM tuning**: extensive public engineering.
- **Netflix's Cassandra GC tuning**: G1 with custom parameters.
- **The "we switched to ZGC" stories**: latency improvements documented.

---

## V8 Generational GC In Depth 🔴

The earlier "V8's GC specifically" section names the pieces; this one explains the mechanisms an interviewer probes.

### Young generation — the Scavenger (Cheney's semi-space copying)

New space is split into two equal halves: **to-space** and **from-space**. Allocation is a bump pointer in to-space — increment a pointer, no free-list search — which is why young-object allocation is effectively a single add instruction. When to-space fills, a **Scavenge** runs:

1. The roles flip: the active half becomes **from-space**.
2. Starting from the roots (stack, registers, handles), every *live* object is **copied** into the new to-space.
3. Pointers to copied objects are rewritten to their new address; a forwarding pointer left in the old slot ensures an object reached by two paths is copied once, not twice.

This is **Cheney's algorithm**: it uses the to-space itself as the work queue (a `scan` pointer chases an `alloc` pointer), so the traversal is iterative with no separate marking stack. Cost is proportional to the **surviving** set, not the allocated set — dead objects are never touched, so a Scavenge that allocated 8 MB but kept 200 KB does ~200 KB of work. Modern V8 runs the Scavenger **in parallel** across helper threads. After two Scavenge survivals an object is **promoted** to old space. The 2× space cost is the well-known downside of any copying collector, but new space is small (a few MB per isolate), so it's cheap in absolute terms.

### Old generation — Orinoco (mark-sweep / mark-compact)

Promoted objects live in **old space**, collected by the **major GC** (codename **Orinoco**). It cannot copy semi-space style — old space is gigabytes — so it uses **tri-color marking** followed by either **sweep** (rebuild free lists in place; fast, leaves fragmentation) or **compact** (relocate live objects to defragment; slower, used on fragmented pages). Orinoco makes the pauses tolerable through three techniques:

- **Incremental marking**: marking work is sliced into small steps interleaved with JS execution, so a multi-second mark becomes many sub-millisecond slices.
- **Concurrent marking**: most marking runs on background threads *while* JS keeps executing.
- **Parallel** sweeping/compaction across helper threads.

Only short **stop-the-world** phases remain (atomic pause: finalize marking, then start sweeping).

### Write barriers — tracking old→young references

Concurrent/incremental marking and generational collection share one hazard: the mutator can install a pointer the collector won't otherwise see. The fix is a **write barrier** — code V8 emits on every object-pointer store.

It solves two distinct problems:

- **Generational (inter-generational pointers).** A Scavenge treats old space as roots but must *not* trace all of old space (that would defeat the point of a minor GC). So when old-space object `A` is made to point at young-space object `B` (`A.field = B`), the barrier records `A`'s page in a **remembered set** (V8 stores these slots per-page). The Scavenger scans only the remembered set as extra roots, keeping `B` alive without walking the whole old generation. Without this, surviving young objects reachable only from old space would be wrongly reclaimed.
- **Concurrent marking (the lost-object problem).** If the mutator points an already-marked **black** object at a **white** object and deletes the only other path to that white object, the white object would be swept while still live. V8 uses a **Dijkstra-style insertion barrier**: writing a pointer to a white object re-colors it **gray** (re-enqueues it), preserving the tri-color invariant that no black object points directly to a white one.

The barrier is a few instructions on every reference store — a real but small steady-state cost, and the price of admission for non-blocking collection.

### Why tracing, not reference counting 🔴

V8 is a **tracing** collector (reachability from roots), not a reference-counting one, and the choice is deliberate:

- **Cycles.** Reference counting cannot reclaim a cycle: two detached objects referencing each other each keep the other's count at 1, so neither ever hits zero. JS makes cycles trivial (`a.b = b; b.a = a`, a DOM node holding a closure that captures the node). A refcounting JS engine would need a separate cycle-collector anyway — which is just tracing bolted on. Tracing handles cycles for free: an unreachable cycle is simply never marked.
- **Per-mutation overhead.** Reference counting taxes *every* pointer write with a counter update (and under concurrency, an *atomic* one — see the Reference counting section). JS executes enormous numbers of pointer writes; tracing moves the cost off the mutation hot path and amortizes it into periodic collection that scales with the *live* set, not the *mutation* count.
- **Locality.** Refcount updates dirty cache lines across the whole object graph on every assignment; the Scavenger touches only live objects in a tight copy loop.

The trade-off tracing accepts is *non-determinism of reclamation* (an object isn't freed the instant it dies, but at the next collection) — acceptable in a managed runtime, and the reason finalization (`FinalizationRegistry`, `WeakRef`) is explicitly non-deterministic in JS.

---

## Key Takeaways

- **GC reclaims unreachable memory** automatically — but reachable-but-unused objects are leaks the GC will never collect (unbounded caches, long-lived collections, unregistered listeners, over-capturing closures).
- **The weak generational hypothesis**: most objects die young. Generational GC exploits this by collecting young space frequently and cheaply, promoting survivors to a rarely-collected old space.
- **Pause time vs throughput is the central trade-off.** Stop-the-world is fast (less coordination overhead) but pauses kill tail latency; concurrent collectors keep pauses short but cost more CPU (typically 10-30%).
- **Allocation rate matters as much as live size.** A program allocating 1GB/sec creates GC pressure even with a small live set. Reducing allocations (pooling, buffer reuse) in hot paths is often the highest-leverage optimization.
- **GC pauses dominate tail latency** — a senior reading "high p99" investigates full GCs early.
- **GC tuning is application-specific.** The right algorithm and parameters depend on heap size, allocation rate, latency requirements, and throughput goals. Heap size cuts both ways: too small means frequent GCs, too big means long pauses. Profile first, tune on data.
- **GC algorithms differ dramatically** — and modern ones (ZGC, Shenandoah) achieve sub-millisecond pauses on multi-TB heaps.
- **GC is not a black box.** Reading GC logs, monitoring pause times, understanding generational counts, and distinguishing leaks from sizing issues are routine operational skills.
- **V8 splits the work by generation.** The young-gen **Scavenger** does Cheney semi-space copying — cost scales with *survivors*, not allocations; the old-gen **Orinoco** does tri-color mark-sweep/compact with incremental + concurrent + parallel phases so only short stop-the-world windows remain.
- **Tracing beats reference counting for JS** because refcounting cannot collect cycles (trivial to create in JS) and taxes every pointer write; **write barriers** are the glue — a remembered set tracks old→young pointers so minor GCs needn't scan old space, and an insertion barrier preserves the tri-color invariant during concurrent marking.

> **Mental model:** Garbage collection is the runtime contract that frees programmers from memory management — but the contract has fine print: pauses, allocation pressure, throughput cost. Production engineers read the fine print; novices treat GC as magic. Modern GCs are excellent — when configured for the workload. GC trades programmer-time for runtime-time, handling billions of allocations per second invisibly, until it doesn't and you have to understand how it actually works.

---

## Interview angle 🟡

- **"How does GC work?"** Mark-and-sweep, generational, concurrent.
- **"What's the weak generational hypothesis?"** Most objects die young.
- **"Stop-the-world vs concurrent?"** Trade-offs (pause time vs CPU cost).
- **"Why is allocation rate important?"** It drives GC frequency.
- **"How do you debug GC pauses?"** Profile, read logs, tune.
- **"G1 vs ZGC?"** Region-based vs concurrent low-latency.
- Common traps: believing GC is "free"; not knowing about generational GC.
