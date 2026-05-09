# Parallelism vs Concurrency

> *"Concurrency is about dealing with many things at once. Parallelism is about doing many things at once. They sound the same. They're not. The difference is whether your CPU has more than one core, and whether you've actually arranged your work to use them."*

---

## Topic Overview

Few distinctions in computer science are more constantly conflated — and more consequential — than concurrency vs parallelism. The terms are used interchangeably in casual conversation, in interview answers, in technical documentation. They're not the same thing. Concurrency is *structure*: writing programs as multiple cooperating activities. Parallelism is *execution*: running computations simultaneously on multiple hardware units.

A program can be concurrent without being parallel (cooperative multitasking on a single core). A program can be parallel without being especially concurrent (a numerical kernel split across CPU cores). The interesting designs are the ones that are *both* — concurrent in structure and parallel in execution. Most production-scale systems are this.

The distinction matters because the *bugs* differ, the *speedups* differ, and the *primitives* differ. Designing for concurrency without understanding when it gets you parallelism (and when it doesn't) is how you end up with a multi-threaded Python program that runs slower than the single-threaded version.

---

## Intuition Before Definitions

Imagine a coffee shop with one barista.

**Concurrency.** The barista takes order #1, starts the espresso machine running, takes order #2 while machine #1 is brewing, starts machine #2, returns to #1 when its drink is ready. The barista is *handling many drinks at once* — but at any instant, only one task is happening (taking an order, starting a machine, finishing a drink). The barista is *concurrent*. The throughput is high because the barista doesn't *wait* idly; they switch between tasks.

**Parallelism.** Now hire a second barista. They each take orders, run machines, finish drinks — at the same time, on different drinks. Two drinks are *literally* being made simultaneously. The shop is *parallel* because work is happening in two places at once.

A shop can be concurrent without being parallel (one fast barista juggling). It can be parallel without being especially concurrent (two baristas each making one drink start to finish, never multitasking). Real busy shops are both: multiple baristas, each multitasking.

The same is true of programs. Concurrency is a structure ("write this as cooperating tasks"). Parallelism is an execution property ("run these tasks simultaneously on different cores"). They compose; they're not synonymous.

---

## Historical Evolution

**Era 1 — Single-CPU concurrency.**
1960s-70s. Time-sharing operating systems (Multics, Unix). Multiple processes appear to run simultaneously by switching the CPU among them. Concurrent in structure; not parallel.

**Era 2 — SMP and parallel execution.**
1990s-2000s. Multi-CPU servers. Threads can truly run in parallel on separate CPUs. Lock-based synchronization becomes mainstream. Programs written for concurrency now run faster — when locks don't dominate.

**Era 3 — Multi-core era.**
~2005. Single-thread CPU performance plateaus; chips grow cores instead. Suddenly every desktop and phone has parallelism available. Languages and frameworks adapt: Java's `java.util.concurrent`, .NET's TPL, etc.

**Era 4 — Async runtimes.**
2010s. Node.js, asyncio, Tokio, Goroutines. Concurrency without parallelism (within a process) becomes the model for I/O-bound workloads. Single-threaded performance with massive concurrency.

**Era 5 — GPGPU and SIMD.**
GPUs as compute devices (CUDA, 2007). Vector instructions in CPUs (AVX). Massive data-parallelism for specific workloads. Different model than multi-core threading.

**Era 6 — Hybrid models.**
Modern systems mix: multi-process (parallelism), multi-threaded within each (more parallelism), async I/O within each thread (concurrency). Goroutines + work-stealing schedulers. Rust's tokio + threads. Each layer earns its place.

The pattern: hardware shaped the abstractions. As parallelism became free (multiple cores), languages and runtimes evolved to exploit it without forcing all programmers to write lock-heavy code.

---

## Core Mental Models

**1. Concurrency is structure; parallelism is execution.**
A program structured concurrently *can* be executed in parallel if hardware allows. But you can have one without the other.

**2. Concurrency helps with I/O-bound; parallelism helps with CPU-bound.**
If your program waits a lot (network, disk, user), concurrency lets you wait less by switching to other work. If your program computes a lot, parallelism lets you finish faster by computing on multiple cores.

**3. The GIL or single-threaded runtime is a parallelism limit, not a concurrency limit.**
Python (with GIL), Node.js (single event loop), Ruby (with GVL) all support concurrency but not (for pure Python/JS code) parallelism. CPU-bound work in these runtimes does not benefit from multiple cores within one process.

**4. Amdahl's Law caps parallel speedup.**
If 10% of your work is sequential, no amount of parallelism gets you past a 10× speedup. Real workloads have more sequential portions than people estimate. Pure-parallel speedups are rare in practice.

**5. Coordination is the cost of parallelism.**
Threads must synchronize to share data. Cores must coordinate caches. The more they coordinate, the less parallel speedup you get. The art is *minimizing* coordination — partitioning data, avoiding shared state, batching work.

---

## Deep Technical Explanation

### The taxonomy

| Property | Concurrency | Parallelism |
|---|---|---|
| **Definition** | Structure: multiple activities making progress | Execution: multiple computations running simultaneously |
| **Hardware required** | Single core sufficient | Multiple cores/devices required |
| **Primary benefit** | Hide latency (I/O) | Reduce time (compute) |
| **Failure mode** | Race conditions, deadlocks | Cache coherence, false sharing |
| **Typical primitive** | Threads, async tasks, actors | Thread pools, parallel loops, GPU kernels |

A program can have:
- **Neither**: a single-threaded sequential program.
- **Only concurrency**: an event loop or generator-based program on one core.
- **Only parallelism**: a numerical kernel that splits work but doesn't multitask.
- **Both**: multi-threaded server doing async I/O on each thread.

### Amdahl's Law

If a fraction `s` of the work must be sequential, and the rest `(1-s)` can be parallelized perfectly across `N` cores:

```
speedup(N) = 1 / (s + (1-s)/N)
```

As N → ∞, speedup → 1/s. With 10% sequential work, max speedup is 10×, no matter how many cores. With 1%, max is 100×.

Most real programs have more sequential work than people guess: serialization at the start, aggregation at the end, occasional locks, I/O. A "perfectly parallel" workload is rare.

### Gustafson's Law (the optimist's response)

Amdahl assumes fixed problem size. Gustafson observes that with more cores, problems also grow. Larger datasets, more iterations. Speedup scales with the problem size that fits into the available compute:

```
speedup(N) = N - s × (N - 1)
```

Linear in N when s is small. The two laws aren't contradictory; they answer different questions ("how fast on this fixed problem?" vs "how big a problem can I solve?").

### Concurrency primitives

**Threads:** OS-level. Preemptive. Heavy (~1MB stack each). Synchronize via locks/atomics.

**Lightweight threads / fibers / coroutines:** runtime-managed. Cooperative or pseudo-preemptive. Cheap (KB-scale). Examples: Go goroutines, Erlang processes, Java virtual threads (Project Loom).

**Async tasks:** state machines compiled from `async`/`await`. Cooperatively scheduled by an event loop. Ultra-lightweight. Examples: JavaScript promises, Rust futures, Python asyncio.

**Actors:** isolated processes with message-passing. Each actor is conceptually single-threaded; messages serialize via mailbox. (See [actor-model-and-message-passing.md](./actor-model-and-message-passing.md).)

**Channels (CSP):** typed pipes between concurrent activities. Communication, not sharing.

Each provides concurrency. *Whether they provide parallelism depends on the runtime.*

### Parallelism primitives

**Multi-process:** each process has its own memory. True parallelism. Coordination via IPC (pipes, shared memory, message passing). Used in Python (`multiprocessing`) and other GIL-limited languages.

**Multi-threaded:** threads share memory within a process. Parallelism on multi-core. Coordination via locks, atomics. The classic model.

**Thread pool / executor service:** pre-allocated threads servicing a work queue. Avoids per-task thread-creation cost. Java's `ExecutorService`, Python's `ThreadPoolExecutor`, Rust's `rayon`.

**Data parallelism (parallel loops):** automatically split a loop across cores. OpenMP `#pragma omp parallel for`, Rust's `rayon::par_iter`, Java's parallel streams. Best for embarrassingly parallel work.

**SIMD (Single Instruction, Multiple Data):** within one core, apply the same operation to multiple values simultaneously. AVX, NEON. Compilers auto-vectorize many loops.

**GPGPU:** thousands of lightweight threads on a GPU. Massive data-parallelism for specific patterns (graphics, ML, simulation).

**Distributed parallelism:** multiple machines. Map-reduce, Spark, distributed training. Highest scale; highest coordination cost.

### The GIL and its consequences

Python's Global Interpreter Lock prevents multiple threads from executing Python bytecode simultaneously. Implications:

- **CPU-bound Python**: threads don't help. `multiprocessing` does (separate processes, separate GILs).
- **I/O-bound Python**: threads do help (the GIL is released during I/O syscalls).
- **C extensions**: can release the GIL during compute (NumPy, scipy do this).

This is why Python's `concurrent.futures.ThreadPoolExecutor` is fine for downloading 100 URLs in parallel but won't speed up a Python-pure compute loop.

Similarly, Ruby's GVL and Node.js's single thread are parallelism limits within their runtimes. Multiple processes (each with its own runtime) restore parallelism.

### Work stealing

A classic scheduling pattern. Each thread has its own work queue. When a thread runs out, it *steals* from another thread's queue (typically from the back, opposite end from the owner's pop direction).

Properties:
- **Locality**: each thread mostly works on its own queue (good cache behavior).
- **Load balancing**: idle threads find work without central coordination.
- **Scalability**: works well to dozens of cores.

Used in: Go's runtime, Java's ForkJoinPool, Rust's tokio, Cilk. Default scheduling for general-purpose parallel runtimes.

### False sharing

Two threads modify *different* variables that happen to live in the *same CPU cache line* (typically 64 bytes). Hardware cache coherence invalidates the line on the other core's cache for every modification. Performance collapses despite no actual data sharing.

This is a parallelism-specific bug. It doesn't appear in single-threaded or single-core code. Mitigations: padding, cache-line alignment.

### NUMA

Non-Uniform Memory Access. Multi-socket systems where each socket has local memory; access to other sockets' memory is slower. A thread pinned to socket A accessing memory allocated on socket B pays a latency penalty.

Production high-performance code is NUMA-aware: pin threads, allocate memory locally, minimize cross-socket coordination. Mostly a concern for HPC and low-latency systems; less for general-purpose servers.

---

## Real Engineering Analogies

**The kitchen with one chef vs many chefs.**
One chef multitasking is concurrency. Many chefs is parallelism. A kitchen with one fast chef juggling tasks can serve a lot of customers — until they hit a "parallel" workload (chopping 100 onions). Then no amount of multitasking helps; they need *another chef*.

A kitchen with many chefs but no coordination produces chaos. The coordination cost (head chef directing, prep schedules) is the parallelism overhead. Beyond a certain number of chefs, adding more makes things worse.

**The construction crew.**
One worker can dig a hole. Two workers digging the same hole get in each other's way (limited parallelism — coordination overhead). Two workers digging *different* holes complete twice as fast — embarrassingly parallel.

The "hole" is your data structure or task. Some computations parallelize beautifully (independent holes); others fundamentally serialize (two people can't both have the only shovel at the same time).

---

## Production Engineering Perspective

What goes wrong:

- **The "I added threads and it's slower" surprise.** Threading a CPU-bound task in Python. GIL serializes execution. Per-task overhead added. Slower. Lesson: profile before parallelizing.
- **The cache-line ping-pong.** A counter array, one element per thread. Performance scales sub-linearly with cores. Investigation: false sharing on cache lines. Padding to 64-byte alignment unlocks scaling.
- **The Amdahl wall.** "We added 32 cores; speedup is only 4×." Investigation: 25% of the work is sequential (data loading, aggregation). Amdahl caps speedup at 4× regardless of core count.
- **The GIL discovery.** Python team migrates compute to threads expecting speedup. None materializes. Migration to `multiprocessing` introduces serialization overhead. Eventually rewrite the compute kernel in Cython or Rust to release the GIL.
- **The lock convoy at scale.** A "global mutex" in a hot path. CPU usage 30% on a 32-core machine. The mutex is the bottleneck. Refactor to per-shard locks; CPU jumps to 90%, throughput triples.
- **The over-parallelism overhead.** A workload split into 10K tiny tasks. Per-task overhead dominates. Coarser-grained partitioning (100 tasks of 100 items each) is faster despite "less parallelism."
- **The async-but-not-parallel mistake.** A Node.js service with CPU-heavy operations. async/await keeps the event loop responsive but each operation still runs single-threaded. Solution: worker threads or external service.

The senior engineer's habits:
- **Profile first.** Identify bottlenecks before parallelizing.
- **Distinguish I/O-bound from CPU-bound.** Different solutions.
- **Watch for false sharing** in hot loops with shared data.
- **Measure speedup**, don't assume.
- **Consider Amdahl's Law** before adding cores.
- **Minimize coordination** as the path to scaling.

---

## Failure Scenarios

**Scenario 1 — The single-core deployment.**
A team builds a multi-threaded service. Deploys to a 1-core container in production. Performance is identical to single-threaded. Threads add overhead without parallelism. Fix: appropriate container sizing.

**Scenario 2 — The cache-line catastrophe.**
A high-throughput counter array (one element per thread). Performance plateaus at 8 cores despite a 64-core machine. Cause: 64-byte cache lines hold 16 4-byte counters; 16 threads contend per line. Fix: pad each counter; throughput scales linearly to 64 cores.

**Scenario 3 — The Amdahl ambush.**
A team adds GPU acceleration expecting 10× speedup. Sees 1.8×. Investigation: data loading and result formatting take 50% of total time and run on CPU. The GPU work is now negligible; the CPU work dominates.

**Scenario 4 — The lock-contention regression.**
A monolithic service runs fine on 4 cores. Move to 64 cores. Throughput drops 30%. Cause: increased lock contention as more threads pile up at a shared mutex. The "more cores" made things worse. Fix: redesign the data structure (shared → per-thread, with periodic merge).

**Scenario 5 — The Python parallelization that wasn't.**
A team uses `concurrent.futures.ThreadPoolExecutor` for compute work. Sees no speedup. Migration to `ProcessPoolExecutor` introduces 100ms IPC overhead per task. Eventually rewrites compute in NumPy (which releases the GIL), gets 10× speedup with threads.

---

## Performance Perspective

- **Concurrency adds throughput** when waiting dominates (I/O).
- **Parallelism adds throughput** when compute dominates and work can be partitioned.
- **Coordination has a cost.** Locks, cache coherence, scheduler overhead. At some point, more cores hurt more than help.
- **Cache locality matters.** Threads running on different cores have different L1/L2 caches; passing data between them is slow.
- **Context switches** cost microseconds. Async tasks switch in nanoseconds.

---

## Scaling Perspective

- **Vertical (more cores per machine)**: works to dozens of cores; coordination eventually limits.
- **Vertical (more sockets, NUMA)**: requires NUMA-awareness for full benefit.
- **Horizontal (more machines)**: distributes work but adds network coordination cost.
- **GPU**: massive parallelism for specific patterns; most code doesn't fit.
- **At hyperscale**: combinations — multi-process per machine, multi-thread per process, async per thread, plus distributed coordination.

---

## Cross-Domain Connections

- **Locks**: parallelism's primary coordination mechanism; concurrency's bug source. (See [locks-mutexes-and-lock-free.md](./locks-mutexes-and-lock-free.md).)
- **Event loop**: pure concurrency, no parallelism within one loop. (See [event-loop-and-async-runtime.md](../js-runtime/event-loop-and-async-runtime.md).)
- **Actor model**: provides concurrency; parallelism via runtime placement. (See [actor-model-and-message-passing.md](./actor-model-and-message-passing.md).)
- **Backpressure**: concurrent systems with mismatched rates need backpressure. (See [backpressure-and-queues.md](./backpressure-and-queues.md).)
- **V8 internals**: single-threaded execution = single-threaded parallelism per V8 isolate. (See [v8-internals-and-hidden-classes.md](../js-runtime/v8-internals-and-hidden-classes.md).)
- **Sharding**: data parallelism at the system level. (See [sharding-and-partitioning-strategies.md](../scalability/sharding-and-partitioning-strategies.md).)

The unifying observation: **concurrency is a programming model; parallelism is a hardware property; getting them to compose well is the central engineering challenge of modern systems.**

---

## Real Production Scenarios

- **Node.js cluster mode**: multiple Node processes for parallelism, each running its own event loop for concurrency.
- **Python's NumPy/Pandas**: release the GIL during computation; threads provide real parallelism.
- **Go's goroutines**: cheap concurrency, multiplexed onto OS threads for parallelism. Scheduler handles both transparently.
- **Java's Project Loom (virtual threads)**: cheap concurrent threads, multiplexed onto OS threads for parallelism. New as of Java 21.
- **Rust's Tokio**: async concurrency with multi-threaded runtime for parallelism.
- **TensorFlow/PyTorch**: data parallelism across GPUs and machines for large model training.

---

## What Junior Engineers Usually Miss

- That **threading a Python compute task** doesn't help (GIL).
- That **async/await alone** gives concurrency, not parallelism.
- That **Amdahl's Law caps speedup** more than they expect.
- That **adding cores doesn't always help** — coordination costs matter.
- That **false sharing exists** and silently destroys parallelism.
- That **I/O-bound and CPU-bound have different solutions.**
- That **single-thread vs multi-thread containers** matters in deployment.
- That **profile-first beats assume-and-add-threads.**

---

## What Senior Engineers Instinctively Notice

- They **classify workloads as I/O-bound or CPU-bound** before designing.
- They **measure speedup**, not assume.
- They **minimize coordination** as the scaling strategy.
- They **know the GIL implications** of their language.
- They **watch for false sharing** in hot data structures.
- They **size deployments** for actual core counts.
- They **distinguish concurrency from parallelism** rigorously.
- They **understand work-stealing** as the modern scheduling pattern.

---

## Interview Perspective

What gets tested:

1. **"What's the difference between concurrency and parallelism?"** Tests fundamental literacy.
2. **"Why doesn't threading help in Python?"** GIL.
3. **"What's Amdahl's Law?"** Speedup is bounded by the sequential portion.
4. **"What's false sharing?"** Hardware cache coherence on shared cache lines.
5. **"How do you parallelize a CPU-bound task in Python?"** `multiprocessing`, native extensions, or moving the kernel out of Python.
6. **"What's work stealing?"** Scheduler pattern; idle threads steal from busy ones.
7. **"Why is my multi-threaded code slower?"** Common reasons: contention, false sharing, GIL, overhead exceeds parallelism gain.

Common traps:
- Conflating concurrency and parallelism.
- Believing more threads = more speedup.
- Not knowing about Amdahl's Law.

---

## 20% Knowledge Giving 80% Understanding

1. **Concurrency = structure**; **parallelism = execution**.
2. **I/O-bound → concurrency**; **CPU-bound → parallelism**.
3. **GIL/event-loop = parallelism limit** per process.
4. **Amdahl's Law caps speedup** at 1/sequential-fraction.
5. **Coordination is the cost** of parallelism.
6. **False sharing destroys** otherwise-clean parallelism.
7. **Work stealing** is the modern scheduler pattern.
8. **Threads are heavy**; lightweight threads / async are cheap.
9. **Profile first**; parallelize bottlenecks, not everything.
10. **Multi-process for GIL-bound parallelism.**

---

## Final Mental Model

> **Concurrency is how you structure code; parallelism is how it runs. The art is making the structure exploit the hardware — and recognizing when adding more hardware will just buy you more coordination overhead.**

The senior engineer designing a high-performance system doesn't reach for threads reflexively. They classify the workload (I/O? CPU? mixed?), profile to find the actual bottleneck, choose primitives that match (async for I/O, parallel pools for CPU, partitioned data for both), and *measure* the result. Many "parallelization" attempts produce no speedup or worse; the discipline is verifying.

The systems that scale to many cores are the ones designed with coordination as a first-class cost. Per-thread/per-shard data; minimal locks; cache-aware layout. The systems that hit ceilings are the ones that started single-threaded and tried to retrofit parallelism on top.

That's parallelism vs concurrency. That's the distinction that separates "we added threads" from "we made it actually faster." That's a foundation literacy that every modern engineer needs — because every modern computer has more cores than people know how to use, and the gap between hardware capability and software exploitation is where production performance is lost.
