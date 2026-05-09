# CPU Caches & False Sharing

> *"The CPU you're running on is not one chip; it's a hierarchy of caches with a small slow chip at the bottom. The hierarchy is invisible to your code — until you wonder why your perfectly-correct multi-threaded program scales sublinearly. Then you discover false sharing, cache coherence protocols, and the silicon-level reality that 'memory access' is not what you thought."*

---

## Topic Overview

Modern CPUs have multiple levels of cache between the cores and main memory: L1 (32-64 KB per core; 1ns); L2 (256KB-1MB per core; 3ns); L3 (megabytes shared across cores; 10ns); main memory (gigabytes; 100ns). The 100× speed gap between L1 and main memory means cache behavior dominates real-world performance.

Multi-core CPUs face a coherence problem: when one core writes a value, other cores' caches must reflect the change. This is solved by hardware protocols (MESI and variants) — but the protocols have costs. **False sharing** is the canonical pathology: two threads modify *unrelated* variables that happen to share a cache line, triggering coherence traffic that destroys performance.

This is the topic where the abstraction "memory is one big array" finally leaks. Understanding cache behavior — line size, coherence costs, prefetching, NUMA effects — is what separates "I can write multi-threaded code" from "I can write multi-threaded code that scales."

---

## Intuition Before Definitions

Imagine four chefs sharing one pantry.

The pantry is the only place ingredients are stored. Walking to the pantry takes time. Each chef has a small bench (cache) where they keep what they're using.

When a chef needs an ingredient, they walk to the pantry. They take a small basket of related items (a cache line) — not just one ingredient.

Now: two chefs both need ingredients from the same shelf. Different items, same shelf. Each chef takes the whole basket of items (cache line). They're each working on different items but holding the same shelf's basket.

When chef A modifies their item, the *shelf* (cache line) is marked changed. Chef B's basket is now stale — they must walk back to the pantry, return their basket, take a fresh one. They were working on a different item; doesn't matter; the cache line is shared.

That's false sharing. The threads aren't really sharing data; the *cache line* is shared. Performance collapses for what looks like independent work.

---

## Historical Evolution

**Era 1 — Caches in the 1980s.**
Early multi-CPU systems. Coherence was a problem; hardware solutions emerged.

**Era 2 — MESI protocol.**
~1980s. Foundational cache coherence protocol. Modern variations everywhere.

**Era 3 — Multi-core mainstream (2005+).**
Single-CPU chips with multiple cores. Cache coherence becomes universal.

**Era 4 — NUMA architectures.**
Multi-socket systems with non-uniform memory access. Programmer concerns deepen.

**Era 5 — Cache-aware programming as discipline.**
Performance-conscious code routinely considers cache effects.

**Era 6 — Modern accelerators.**
GPUs, TPUs have their own memory hierarchies; same principles, different specifics.

The pattern: cache hierarchy has been a constant; programmer awareness has grown.

---

## Core Mental Models

**1. Memory access is not uniform.**
L1 cache: 1ns. Main memory: 100ns. The hierarchy matters profoundly.

**2. Cache lines are the unit of transfer.**
Typically 64 bytes. Reading 1 byte loads 64.

**3. Coherence has a cost.**
When one core writes a line, others' copies are invalidated. Subsequent reads on those cores stall.

**4. False sharing is silent.**
Threads with no logical sharing can suffer if their data colocates in cache lines.

**5. NUMA adds another dimension.**
Cross-socket memory access is much slower than local.

---

## Deep Technical Explanation

### Cache hierarchy

Typical modern CPU:

| Level | Size | Latency | Sharing |
|---|---|---|---|
| Registers | bytes | <1ns | per-core |
| L1 cache | 32-64 KB | 1ns | per-core |
| L2 cache | 256KB-1MB | 3ns | per-core or per-pair |
| L3 cache | 8-32 MB | 10ns | shared across cores |
| Main memory | GB | 100ns | shared |

The 100:1 latency ratio between L1 and main memory means a code path's memory pattern often dominates its performance.

### Cache lines

Typical line size: 64 bytes (Intel, AMD); 128 bytes (some POWER, Apple Silicon for some scenarios).

When you read one byte, the entire line is loaded. Sequential access (good cache behavior) is much faster than random access.

Spatial locality: nearby data tends to be accessed together; cache lines exploit this.

Temporal locality: recently-accessed data tends to be re-accessed; caches retain it.

### MESI protocol

Cache coherence states (per cache line, per core):
- **M (Modified)**: this core has the only modified copy.
- **E (Exclusive)**: this core has the only clean copy.
- **S (Shared)**: multiple cores have clean copies.
- **I (Invalid)**: this cache's copy is stale.

State transitions: when one core writes, others' copies become Invalid. Reading an Invalid line requires fetching from another cache or memory.

The overhead: coherence traffic between cores. Visible in performance metrics; invisible in code.

### False sharing in detail

```c
struct Counters {
    int counter_a;  // used by thread A
    int counter_b;  // used by thread B
};
```

`counter_a` and `counter_b` are 4 bytes each; both fit in one 64-byte cache line. Both threads modify them.

What happens:
- Thread A modifies counter_a → its cache line is M; B's is I.
- Thread B reads counter_b → cache miss; fetch line; B's is now M; A's is I.
- Thread A reads counter_a → miss; fetch; A's is M; B's is I.
- Repeat.

The cache line bounces between cores. Performance is much worse than two independent counters in different lines.

Fix: align data to cache lines:
```c
struct Counters {
    alignas(64) int counter_a;
    alignas(64) int counter_b;
};
```

Each in its own 64-byte block; no false sharing.

### Detecting false sharing

Tools:
- `perf c2c` (Linux): cache-to-cache analysis.
- Intel VTune.
- Profilers showing high cache miss rates on hot data.

Symptoms:
- Multi-threaded performance worse than expected.
- Performance scales sublinearly with cores.
- High cache-miss rate on shared structures.

### Padding and alignment

Common patterns:

**Per-thread counters**: pad each to a cache line.

**Lock-free queues**: pad heads and tails so producer and consumer don't false-share.

**Per-core data structures**: explicit per-CPU layout; align everything.

Cost: memory overhead. Benefit: scalable performance.

### Cache prefetching

CPUs prefetch:
- Hardware: detects sequential access; loads ahead.
- Software: explicit prefetch instructions (`__builtin_prefetch`).

Prefetching hides memory latency for predictable patterns. Random access patterns can't be prefetched.

### NUMA

Multi-socket systems: each socket has its own memory channels. Local memory is fast (~80ns); remote (cross-socket) is slow (~200ns).

Implications:
- Threads accessing memory on the wrong socket are slow.
- Allocation strategy matters (pin threads + memory to same socket).

NUMA-aware programming:
- `numactl` to control thread/memory placement.
- Per-socket data structures.
- Reduce cross-socket coordination.

For HPC, low-latency systems, NUMA is critical. For general-purpose servers, often less so.

### Cache-friendly data structures

- **Array of structures vs structure of arrays.** SoA often better for cache when iterating over one field.
- **Linked lists**: bad cache behavior (pointers point everywhere).
- **Hash tables with open addressing**: better cache than chained.
- **Packed bitfields**: more data per cache line.

Modern data-oriented design (used in game engines, high-performance code) is largely cache optimization.

### Memory ordering and atomic operations

Beyond caches: write buffers, store-load reordering, instruction reordering.

(See [locks-mutexes-and-lock-free.md](./locks-mutexes-and-lock-free.md) for memory ordering specifics.)

Atomic operations cost more than non-atomic — they may flush write buffers, prevent reordering, trigger coherence.

### Specific microbenchmarks

A famous false-sharing demo: increment 16 separate counters in 16 threads.
- Without padding: scales sublinearly (or not at all).
- With cache-line padding: scales near-linearly.

The same code; the layout matters.

### Cache effects in higher-level languages

Java, Go, C# have padding annotations:
- Java's `@Contended` (JEP 142).
- Go's struct field padding manually.
- C# `[StructLayout(LayoutKind.Explicit)]` and padding.

Common in concurrent data structures (ConcurrentHashMap internals, sync primitives).

---

## Real Engineering Analogies

**The communal kitchen with shared shelves.**
(Already used.) Multiple chefs sharing shelves; cache lines are shelves; modification invalidates everyone's view of the shelf.

**The library where everyone wants the same shelf.**
A library where readers must copy whole shelves of books to their tables. If two readers want different books on the same shelf, they keep invalidating each other's copies. The librarian (CPU coherence) reissues the shelf each time.

---

## Production Engineering Perspective

What goes wrong:

- **The performance regression.** Two unrelated counters in same struct; under load, multi-threaded code slow. Pad fields.
- **The lock-free queue cliff.** Hand-rolled lock-free queue; performance terrible. Producer's index in same line as consumer's. Pad them.
- **The NUMA mystery.** Latency-sensitive service deployed on multi-socket machine; performance varies by deploy. Pin threads/memory.
- **The Java contention.** Hot data structure has hidden false sharing. Add `@Contended`.
- **The benchmark surprise.** Microbenchmark fast; production slow. Cache effects different at scale.

The senior performance engineer's habits:
- **Align hot data** to cache lines.
- **Pad thread-local counters**.
- **Profile with cache-aware tools** (perf c2c).
- **NUMA-aware** for multi-socket production.
- **Measure, don't guess** at memory layout.

---

## Failure Scenarios

**Scenario 1 — The 16-thread counter.**
Concurrent counter array; performance scales to 4 threads then plateaus. Investigation: false sharing on cache lines. Pad each counter to 64 bytes; scaling restored.

**Scenario 2 — The lock-free queue regression.**
SPSC queue (single producer single consumer); claimed fast. Actual performance: meh. Cause: producer's tail pointer same line as consumer's head. Padding fixes.

**Scenario 3 — The NUMA pin.**
Latency-critical service. Random NUMA placement causes cross-socket allocations. p99 variance. Fix: pin thread to NUMA node; allocate locally.

**Scenario 4 — The hashmap hot bucket.**
Concurrent hashmap; one bucket vastly more accessed. Cache contention on that bucket. Mitigation: per-thread sharding.

**Scenario 5 — The cache-line stride.**
Loop accessing array with stride that hits cache line conflicts; slower than expected. Adjust stride; performance recovers.

---

## Performance Perspective

- **L1 hit**: ~1ns.
- **L3 hit**: ~10ns.
- **Main memory**: ~100ns.
- **NUMA remote**: ~200ns.
- **Cache line bounce**: 100s of ns per bounce.

---

## Scaling Perspective

- **Single core**: cache hierarchy dominates.
- **Multi-core**: false sharing matters.
- **Multi-socket**: NUMA matters.
- **At hyperscale**: hand-tuned per-CPU data structures.

---

## Cross-Domain Connections

- **Locks**: contention often manifests as cache effects. (See [locks-mutexes-and-lock-free.md](./locks-mutexes-and-lock-free.md).)
- **Parallelism**: cache effects limit scaling. (See [parallelism-vs-concurrency.md](./parallelism-vs-concurrency.md).)
- **Profiling**: cache profilers reveal these issues. (See [profiling-and-flame-graphs.md](../observability/profiling-and-flame-graphs.md).)
- **Sharding**: per-CPU sharding avoids contention.

The unifying observation: **the abstraction 'memory is uniform' is a useful lie. Production performance lives in the hierarchy below — cache lines, coherence protocols, NUMA distances. Engineers who see the hardware write code that scales.**

---

## Real Production Scenarios

- **Java ConcurrentHashMap**: extensive cache-line padding internally.
- **Linux kernel**: per-CPU variables; explicit cache discipline.
- **High-frequency trading systems**: cache awareness as core skill.
- **Game engines**: data-oriented design is cache optimization.

---

## What Junior Engineers Usually Miss

- That **memory access is not uniform**.
- That **cache lines are 64 bytes**.
- That **false sharing exists**.
- That **NUMA matters** on big servers.
- That **alignment can dramatically affect performance**.

---

## What Senior Engineers Instinctively Notice

- They **align hot data**.
- They **pad thread-local data**.
- They **use cache-aware tools** (perf c2c).
- They **NUMA-pin** when needed.

---

## Interview Perspective

What gets tested:

1. **"What's a cache line?"** 64-byte block.
2. **"What's false sharing?"** Different vars same line.
3. **"MESI?"** Coherence protocol states.
4. **"NUMA?"** Non-uniform memory access.
5. **"How to fix false sharing?"** Padding/alignment.

Common traps:
- Not knowing about cache lines.
- Treating multi-core as automatically scalable.

---

## 20% Knowledge Giving 80% Understanding

1. **Cache hierarchy**: registers → L1 → L2 → L3 → memory.
2. **64-byte cache lines** are the unit.
3. **False sharing** = different vars same line.
4. **MESI** maintains coherence.
5. **Pad hot data** to cache lines.
6. **NUMA** matters on multi-socket.
7. **Spatial locality** matters.
8. **Linked lists are cache-hostile**.
9. **Per-core data** for scaling.
10. **Profile with cache-aware tools**.

---

## Final Mental Model

> **The CPU's cache hierarchy is the silicon-level reality your multi-threaded code runs on. False sharing, NUMA effects, cache contention — these aren't edge cases; they're the everyday performance reality at scale. Engineers who understand the hardware write code that scales; those who don't keep wondering why more cores don't help.**

The senior performance engineer thinks about layout. They pad. They align. They profile cache effects. The result: code that scales to many cores instead of plateauing.

That's CPU caches. That's false sharing. That's the layer below the language — the layer that determines whether your concurrent code actually runs in parallel.
