# Garbage Collection & Memory Management

> *"Garbage collection is what happens when computer scientists tell programmers 'we'll handle memory for you, you focus on the business logic.' The contract is generous in development. In production, GC pauses become tail-latency villains, allocation rates become throughput bottlenecks, and 'why is my service stuttering' often has its answer in the runtime's hidden bookkeeping."*

---

## Topic Overview

Garbage collection (GC) is the runtime mechanism that automatically reclaims memory when objects are no longer reachable. Different languages take different approaches: V8 (JavaScript) uses generational GC; the JVM has dozens of GC algorithms; Go uses a concurrent mark-sweep; Python uses reference counting plus cycle detection.

The fundamental trade-offs are universal: **throughput** (how much GC work per unit of compute) vs **latency** (how long pauses are) vs **memory overhead** (how much extra space the GC needs). Different applications optimize different axes. A batch ETL job tolerates long pauses; a low-latency trading system can't.

This is the topic where language internals meet production reality. Most engineers treat GC as a black box until p99 latency spikes correlate with full GCs. Then GC tuning becomes a real discipline. Understanding the algorithms — generational, concurrent, regional, copying — is what separates "set the heap size and hope" from "I know exactly why my service has a 200ms pause every 30 seconds."

---

## Intuition Before Definitions

Imagine a janitorial team for an office building.

**Reference counting (Python).** Every object has a counter: how many things reference it? When the counter hits zero, the object is immediately discarded. Simple; can't handle cycles (two objects referencing each other but nothing else).

**Mark-and-sweep (most VMs).** Periodically, walk the room. Mark every object reachable from the entrance. Sweep up the unmarked. Simple; takes time proportional to the room's contents.

**Generational (V8, JVM).** Most objects die young. Allocate everything in a small "young" room. When that room fills, quickly clean it; promote survivors to a larger "old" room. Old room is collected rarely.

**Concurrent collection (Go, modern JVM).** Janitors work alongside office workers, in small bursts, instead of stopping work for cleaning.

The trade-offs map: simpler GC = better predictability but worse throughput; more sophisticated = better throughput but more complex pauses. The right choice depends on the application's latency tolerance and allocation pattern.

---

## Historical Evolution

**Era 1 — Manual memory management.**
C, C++. Programmer manages malloc/free. Maximum control; common bugs (leaks, use-after-free).

**Era 2 — Reference counting.**
Smalltalk, Python's primary mechanism. Simple; cycle detection added later.

**Era 3 — Mark-and-sweep.**
Lisp 1959. Periodic full traversal. Stop-the-world pauses.

**Era 4 — Generational GC.**
Lieberman & Hewitt 1983. Young/old separation. Massive throughput improvements.

**Era 5 — Concurrent and incremental GC.**
1990s onward. JVM CMS (deprecated), G1, Shenandoah, ZGC. Reduce pauses by overlapping GC with application work.

**Era 6 — Modern low-latency GCs.**
ZGC, Shenandoah, OpenJDK's recent additions. Sub-millisecond pauses on multi-terabyte heaps.

The pattern: each generation reduced GC pauses, increased throughput, or both — at the cost of complexity.

---

## Core Mental Models

**1. The weak generational hypothesis.**
Most objects die young. Generational GC exploits this by collecting young space frequently and cheaply.

**2. Pause time vs throughput is the central trade-off.**
Stop-the-world is fast (less coordination overhead) but pauses kill latency. Concurrent collectors keep pauses short but use more CPU.

**3. Allocation rate matters as much as live size.**
A program allocating 1GB/sec creates GC pressure even if its live set is small. Reducing allocations is often the highest-leverage optimization.

**4. GC tuning is application-specific.**
The right GC algorithm and parameters depend on heap size, allocation rate, latency requirements, throughput goals.

**5. GC is not a black box.**
Modern runtimes provide extensive instrumentation. Reading GC logs, understanding generational counts, recognizing common patterns — all are operational skills.

---

## Deep Technical Explanation

### Reference counting

Each object has a counter. Increment on new reference; decrement on dereference. At zero, free.

Pros: deterministic; immediate reclamation.
Cons:
- Per-mutation overhead (atomic increments).
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
**ZGC**: sub-millisecond pauses on multi-TB heaps. JEP 333.
**Shenandoah**: similar goals to ZGC; Red Hat's implementation.

Each has knobs. Tuning matters for production.

### Go's GC

Concurrent mark-sweep. Designed for low-latency:
- Goroutines run alongside GC.
- Write barriers maintained.
- Stop-the-world phases are short (sub-millisecond).
- Trade-off: more CPU for GC; less for application.

Tunable via `GOGC` (target heap growth before GC; default 100%).

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

## Real Engineering Analogies

**The office janitorial crew.**
Cleans throughout the day (concurrent GC) vs cleans only at night (stop-the-world). Different trade-offs in disturbance vs efficiency.

**The library deaccession process.**
Periodically removes books no one's checking out. Some libraries do continuously; some rarely with a big project. Same trade-off as GC: ongoing small effort vs occasional big effort.

---

## Production Engineering Perspective

What goes wrong:

- **The GC pause that ruined p99.** Service averages 5ms; p99 is 800ms. Investigation: full GC every 30s pauses for 600ms. Tune to G1 or ZGC; pauses drop to 30ms.
- **The allocation-rate disaster.** Service allocates 1GB/sec; GC pressure dominates CPU. Refactor: object pooling; pre-allocated buffers. Allocation drops 90%; throughput doubles.
- **The OOM that wasn't a leak.** Memory grew; OOMed. Investigation: legitimate workload; heap was sized too small. Fix: bigger heap.
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

## Failure Scenarios

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

## Performance Perspective

- **Allocation cost**: nanoseconds per object (TLAB).
- **Young GC**: milliseconds typical; scales with surviving objects.
- **Major GC**: longer; scales with old-gen size.
- **Concurrent GC overhead**: 10-30% CPU typically.
- **Pause time**: depends on algorithm; modern can be sub-ms.

---

## Scaling Perspective

- **Heap size**: bigger heaps = longer GC; modern algorithms (ZGC) handle multi-TB.
- **Allocation rate**: scales with workload; can become bottleneck.
- **Multi-process** can avoid single-heap limits.
- **At hyperscale**: custom allocators; pre-allocated pools; sometimes manual memory management for hot paths.

---

## Cross-Domain Connections

- **V8 internals**: V8's GC details. (See [v8-internals-and-hidden-classes.md](./v8-internals-and-hidden-classes.md).)
- **Profiling**: GC pauses show in profiles. (See [profiling-and-flame-graphs.md](../observability/profiling-and-flame-graphs.md).)
- **SLOs**: GC pauses affect tail latency / SLO compliance. (See [slos-error-budgets-and-alerting.md](../observability/slos-error-budgets-and-alerting.md).)
- **Capacity planning**: heap size is a planning input. (See [auto-scaling-and-capacity-planning.md](../scalability/auto-scaling-and-capacity-planning.md).)
- **Async Rust**: no GC; deterministic memory. (See [async-rust-and-the-borrow-checker.md](../concurrency/async-rust-and-the-borrow-checker.md).)

The unifying observation: **GC trades programmer-time for runtime-time. The runtime's complexity is the cost of programmer simplicity. Modern GCs are excellent; understanding them remains operationally essential.**

---

## Real Production Scenarios

- **Discord's Go-to-Rust migration**: partly motivated by Go GC pauses.
- **LinkedIn's JVM tuning**: extensive public engineering.
- **Netflix's Cassandra GC tuning**: G1 with custom parameters.
- **The "we switched to ZGC" stories**: latency improvements documented.

---

## What Junior Engineers Usually Miss

- That **GC pauses dominate tail latency**.
- That **allocation rate matters**.
- That **heap size has trade-offs**.
- That **GC algorithms differ** dramatically.
- That **leaks happen in GC'd languages** too.
- That **reading GC logs** is a skill.

---

## What Senior Engineers Instinctively Notice

- They **monitor GC pause times**.
- They **read GC logs** as routine practice.
- They **reduce allocations** in hot paths.
- They **tune** for application's latency goals.
- They **distinguish leaks from sizing issues**.

---

## Interview Perspective

What gets tested:

1. **"How does GC work?"** Mark-and-sweep, generational, concurrent.
2. **"What's the weak generational hypothesis?"** Most objects die young.
3. **"Stop-the-world vs concurrent?"** Trade-offs.
4. **"Why is allocation rate important?"** Drives GC frequency.
5. **"How do you debug GC pauses?"** Profile, read logs, tune.
6. **"G1 vs ZGC?"** Region-based vs concurrent.

Common traps:
- Believing GC is "free."
- Not knowing about generational GC.

---

## 20% Knowledge Giving 80% Understanding

1. **GC reclaims unreachable** memory.
2. **Reference counting** vs **mark-sweep**.
3. **Generational**: young dies young.
4. **Concurrent GC** reduces pauses.
5. **Allocation rate** is a key driver.
6. **Pauses kill tail latency**.
7. **Tune** based on workload.
8. **Leaks happen** with reachable-but-unused.
9. **Modern GCs** can be sub-millisecond pause.
10. **Read GC logs** as a practice.

---

## Final Mental Model

> **Garbage collection is the runtime contract that frees programmers from memory management. The contract has fine print: pauses, allocation pressure, throughput cost. Production engineers read the fine print; novices treat GC as magic. Modern GCs are excellent — when configured for the workload.**

The senior engineer reading "high p99 latency" investigates GC pauses early. They reduce allocations in hot paths. They size heaps appropriately. They choose GC algorithms based on requirements. The discipline pays off; the alternative is mysterious latency spikes nobody explains.

That's GC. That's memory management at the runtime level. That's the layer that handles billions of allocations per second invisibly — until it doesn't, and you have to understand how it actually works.
