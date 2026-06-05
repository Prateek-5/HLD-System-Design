# CPU Caches & False Sharing

> *"The CPU you're running on is not one chip; it's a hierarchy of caches with a small slow chip at the bottom. The hierarchy is invisible to your code — until you wonder why your perfectly-correct multi-threaded program scales sublinearly. Then you discover false sharing, cache coherence protocols, and the silicon-level reality that 'memory access' is not what you thought."*

---

## 🎯 Start Here — Intuition

> **In one line:** your CPU doesn't read memory one byte at a time — it copies fixed-size chunks into fast on-chip caches, and when two threads keep touching the same chunk, the chunk ping-pongs between cores and your "parallel" code crawls.
>
> **Analogy:** four cooks share one pantry. Nobody grabs a single egg; each grabs a whole tray of nearby items (a cache line) and works at their own station. The catch: if two cooks need *different* things off the *same* tray, every time one changes something the other's tray is declared stale and has to be fetched fresh. They're doing unrelated work, yet they keep waiting on each other — because they share a tray, not the food. That wasted shuttling is false sharing.
>
> **Assumes you already know:** what a thread is, that multiple CPU cores run in parallel, and roughly how a struct lays out its fields in memory. *(These are runtime/systems fundamentals; the `learn/` track is interview-focused and has no concurrency counterpart, so there's no prerequisite link to follow — start here.)*
>
> **Level:** this file is 🔴 overall — it's a senior/staff runtime-engineering topic, well below the system-design interview line. The intuition and the false-sharing example are very approachable; the MESI states, NUMA, and data-oriented internals are deep. If those tags make you slow down, that's expected — **you are not behind.**

---

## Topic Overview 🟢

Modern CPUs have multiple levels of cache between the cores and main memory: L1 (32-64 KB per core; 1ns); L2 (256KB-1MB per core; 3ns); L3 (megabytes shared across cores; 10ns); main memory (gigabytes; 100ns). The 100× speed gap between L1 and main memory means cache behavior dominates real-world performance.

Multi-core CPUs face a coherence problem: when one core writes a value, other cores' caches must reflect the change. This is solved by hardware protocols (MESI and variants) — but the protocols have costs. **False sharing** is the canonical pathology: two threads modify *unrelated* variables that happen to share a cache line, triggering coherence traffic that destroys performance.

This is the topic where the abstraction "memory is one big array" finally leaks. Understanding cache behavior — line size, coherence costs, prefetching, NUMA effects — is what separates "I can write multi-threaded code" from "I can write multi-threaded code that scales."

---

## Intuition Before Definitions 🟢

Imagine four chefs sharing one pantry.

The pantry is the only place ingredients are stored. Walking to the pantry takes time. Each chef has a small bench (cache) where they keep what they're using.

When a chef needs an ingredient, they walk to the pantry. They take a small basket of related items (a cache line) — not just one ingredient.

Now: two chefs both need ingredients from the same shelf. Different items, same shelf. Each chef takes the whole basket of items (cache line). They're each working on different items but holding the same shelf's basket.

When chef A modifies their item, the *shelf* (cache line) is marked changed. Chef B's basket is now stale — they must walk back to the pantry, return their basket, take a fresh one. They were working on a different item; doesn't matter; the cache line is shared.

That's false sharing. The threads aren't really sharing data; the *cache line* is shared. Performance collapses for what looks like independent work.

---

## Historical Evolution 🟡

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
GPUs, TPUs (Tensor Processing Units) have their own memory hierarchies; same principles, different specifics.

The pattern: cache hierarchy has been a constant; programmer awareness has grown.

---

## Deep Technical Explanation 🔴

⚠️ The rest assumes the basics above are solid.

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

Typical line size: **64 bytes** on x86-64 (Intel, AMD) and on most ARM cores including Apple Silicon's data cache. Some architectures differ — POWER and certain ARM designs use 128 bytes — and Apple Silicon notably uses a 128-byte *effective* coherence/prefetch granularity on some paths, which is why portable code that pads "to a cache line" often pads to 128 bytes to be safe (Rust's `crossbeam` `CachePadded`, for example, uses 128 bytes on aarch64).

Because the line is 64 bytes, the low 6 bits of an address are the *offset within the line*; the rest selects the line. When you read one byte, the entire 64-byte line is loaded — so a 64-byte struct touches one line, a 65-byte struct can straddle two. Sequential access (good cache behavior) is much faster than random access.

Spatial locality: nearby data tends to be accessed together; cache lines exploit this.

Temporal locality: recently-accessed data tends to be re-accessed; caches retain it.

### MESI protocol 🔴

Coherence is maintained by a hardware protocol that tags **every cache line, in every core's cache, with one of four states**. The classic protocol is MESI (extensions add **O**wned → MOESI on AMD, and **F**orward → MESIF on Intel, which optimize cache-to-cache transfers, but the four MESI states are the conceptual core):

- **M (Modified)**: this core holds the only copy, and it is *dirty* (differs from memory). Memory is stale; this cache is responsible for writing back.
- **E (Exclusive)**: this core holds the only copy, and it is *clean* (matches memory). No write-back needed; can transition to M silently (no bus traffic) on a write.
- **S (Shared)**: one or more cores hold clean copies. A write here requires permission first.
- **I (Invalid)**: this line is stale/empty; a read or write here is a miss.

**The two invariants** the protocol enforces: (1) at most one core may be in M or E for a given line (single writer), and (2) if any core is M, no other core may hold a valid copy.

**How a write invalidates other cores.** This is the mechanism interviewers probe. Cores snoop a shared bus / interconnect (or consult a directory in larger systems):

1. Core A wants to write a line currently in **S** (also cached by cores B, C). A write to a Shared line is *not* allowed directly — A must first gain exclusive ownership.
2. A issues a **Read-For-Ownership (RFO)** / "invalidate" request on the bus.
3. Cores B and C snoop it, transition their copies **S → I**, and acknowledge. (If a core had the line in **M**, it must write back / forward the dirty data first.)
4. Only once A has sole ownership does its line go **S → M** and the store completes.

So a single store to shared data is not a local operation — it is a bus transaction that round-trips to other cores, costing tens to hundreds of cycles. The next time B reads that address, B's copy is **I**, so B takes a coherence miss and must pull the line from A's cache (a *cache-to-cache transfer*, which MESIF/MOESI accelerate) or from memory, transitioning the line back to **S** on both. This invalidate-then-refetch cycle is exactly what makes false sharing expensive.

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

For HPC (High-Performance Computing), low-latency systems, NUMA is critical. For general-purpose servers, often less so.

### Cache-friendly data structures

- **Array of structures vs structure of arrays.** SoA (Structure of Arrays) often better for cache when iterating over one field.
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

### False-sharing mitigation across languages 🔴

Every fix is the same idea — force contended fields onto **separate cache lines** — but the idiom differs by language:

- **C/C++**: `alignas(64)` on the field (C++11), or `#pragma`/`__attribute__((aligned(64)))`. C++17 also exposes `std::hardware_destructive_interference_size` (the line size to pad *to*, to avoid false sharing) and `std::hardware_constructive_interference_size` (the size to pack *within*, to keep co-accessed data together).
- **Java**: `@jdk.internal.vm.annotation.Contended` (originally `sun.misc.Contended`, from **JEP 142**). The JVM inserts padding (default 128 bytes via `-XX:ContendedPaddingWidth`) around the annotated field/class. Requires `-XX:-RestrictContended` for application code. Used internally by `ConcurrentHashMap`'s per-bin counter cells (`@Contended static final class CounterCell`) and by `LongAdder`/`Striped64`.
- **Rust**: `crossbeam_utils::CachePadded<T>` (and `crossbeam::utils::CachePadded`) wraps a value with alignment to the platform's line size — 64 bytes on most targets, 128 on aarch64/powerpc64/x86-64-with-adjacent-line-prefetch — so each padded value sits alone in its line. The Tokio/`std` ecosystem uses it heavily in queues and counters.
- **Go**: no annotation; insert explicit padding fields, e.g. `_ [64]byte` (or `cpu.CacheLinePad` from `golang.org/x/sys/cpu`) between hot fields.
- **C#**: `[StructLayout(LayoutKind.Explicit)]` with `[FieldOffset(64)]`, or `PaddedHeadAndTail`-style structs as in `System.Threading.Channels`.

A subtlety: alignment alone is necessary but not sufficient — if a padded counter is only **4 bytes** in a 64-byte slot, two *adjacent* aligned counters won't false-share, but you must also pad the *trailing* space when objects can be allocated back-to-back. `@Contended` and `CachePadded` handle both leading and trailing padding for you.

---

## Real Engineering Analogies 🟢

**The communal kitchen with shared shelves.**
(Already used.) Multiple chefs sharing shelves; cache lines are shelves; modification invalidates everyone's view of the shelf.

**The library where everyone wants the same shelf.**
A library where readers must copy whole shelves of books to their tables. If two readers want different books on the same shelf, they keep invalidating each other's copies. The librarian (CPU coherence) reissues the shelf each time.

---

## Production Engineering Perspective 🟡

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

## Failure Scenarios 🔴

**Scenario 1 — The 16-thread counter.**
Concurrent counter array; performance scales to 4 threads then plateaus. Investigation: false sharing on cache lines. Pad each counter to 64 bytes; scaling restored.

**Scenario 2 — The lock-free queue regression.**
SPSC (Single Producer Single Consumer) queue (single producer single consumer); claimed fast. Actual performance: meh. Cause: producer's tail pointer same line as consumer's head. Padding fixes.

**Scenario 3 — The NUMA pin.**
Latency-critical service. Random NUMA placement causes cross-socket allocations. p99 variance. Fix: pin thread to NUMA node; allocate locally.

**Scenario 4 — The hashmap hot bucket.**
Concurrent hashmap; one bucket vastly more accessed. Cache contention on that bucket. Mitigation: per-thread sharding.

**Scenario 5 — The cache-line stride.**
Loop accessing array with stride that hits cache line conflicts; slower than expected. Adjust stride; performance recovers.

---

## Performance Perspective 🟡

Realistic figures for a modern ~3 GHz x86-64 core (1 cycle ≈ 0.3 ns). Latency is what hurts a dependent access; throughput can be higher because loads pipeline. Numbers are order-of-magnitude — they vary by microarchitecture — but the *ratios* are the durable insight.

| Access | Latency (cycles) | Latency (ns) |
|---|---|---|
| Register | 0 (in pipeline) | <0.5 |
| L1 data cache hit | ~4-5 | ~1 |
| L2 cache hit | ~12-14 | ~3-4 |
| L3 cache hit (shared) | ~30-45 | ~10-15 |
| Main memory (DRAM, local) | ~200-300 | ~60-100 |
| NUMA remote (cross-socket) | ~400-600 | ~150-200 |
| Coherence miss / cache-line bounce | ~100s | ~100-300 |

Reading these as ratios: an L1 hit is the "free" baseline, L2 ~3×, L3 ~10×, DRAM ~70-100×, and a remote-NUMA or cache-line-bounce access can be 200×+. A false-sharing bounce costs roughly a cross-core round trip *on every contended write* — which is why a loop that "just increments a counter" can collapse to a fraction of single-threaded speed when the counter false-shares.

---

## Scaling Perspective 🟡

- **Single core**: cache hierarchy dominates.
- **Multi-core**: false sharing matters.
- **Multi-socket**: NUMA matters.
- **At hyperscale**: hand-tuned per-CPU data structures.

---

## Cross-Domain Connections 🔴

- **Locks**: contention often manifests as cache effects. (See [locks-mutexes-and-lock-free.md](./locks-mutexes-and-lock-free.md).)
- **Parallelism**: cache effects limit scaling. (See [parallelism-vs-concurrency.md](./parallelism-vs-concurrency.md).)
- **Profiling**: cache profilers reveal these issues. (See [profiling-and-flame-graphs.md](../observability/profiling-and-flame-graphs.md).)
- **Sharding**: per-CPU sharding avoids contention.

The unifying observation: **the abstraction 'memory is uniform' is a useful lie. Production performance lives in the hierarchy below — cache lines, coherence protocols, NUMA distances. Engineers who see the hardware write code that scales.**

---

## Real Production Scenarios 🟡

- **Java ConcurrentHashMap**: extensive cache-line padding internally.
- **Linux kernel**: per-CPU variables; explicit cache discipline.
- **High-frequency trading systems**: cache awareness as core skill.
- **Game engines**: data-oriented design is cache optimization.

---

## Key Takeaways 🟢

- **Memory access is not uniform.** The hierarchy is registers → L1 (~1ns) → L2 (~3ns) → L3 (~10ns) → main memory (~100ns), with NUMA remote at ~200ns. The ~100:1 L1-to-memory gap means memory layout often dominates performance.
- **Cache lines (typically 64 bytes) are the unit of transfer.** Reading one byte loads the whole line. Spatial locality is what makes sequential access fast and linked lists cache-hostile.
- **Coherence (MESI: Modified/Exclusive/Shared/Invalid) has a cost.** A write to a Shared line first issues a Read-For-Ownership that invalidates (S→I) every other core's copy via the bus/directory before the store can complete (the line goes →M). The next read on those cores is a coherence miss — the line bounces between cores, costing a cross-core round trip per contended write.
- **False sharing is silent.** Different, logically-unrelated variables that land in the same 64-byte cache line force this coherence traffic even with no real sharing. Fix by padding/aligning hot data to cache-line boundaries: C/C++ `alignas(64)` (or `std::hardware_destructive_interference_size`), Java `@Contended`, Rust `CachePadded`, Go `_ [64]byte` padding — pad to 128 bytes for cross-platform safety (aarch64/Apple Silicon).
- **NUMA matters on multi-socket machines.** Cross-socket access is far slower than local; pin threads and memory to the same node, use per-core/per-socket data structures.
- **Measure, don't guess.** Profile with cache-aware tools (`perf c2c`, Intel VTune); sublinear scaling on more cores is a classic false-sharing or NUMA symptom.

## Interview angle 🟢

- **"What's a cache line?"** A 64-byte block — the unit loaded on any memory access.
- **"What's false sharing?"** Different variables in the same cache line, causing coherence invalidations between cores that touch them.
- **"What is MESI?"** The cache-coherence protocol with Modified/Exclusive/Shared/Invalid line states.
- **"What is NUMA?"** Non-uniform memory access — memory latency depends on which socket owns the memory relative to the accessing core.
- **"How do you fix false sharing?"** Pad/align the contending data so each lands in its own cache line.
- **Common traps:** not knowing cache lines exist; assuming multi-core code automatically scales linearly.
