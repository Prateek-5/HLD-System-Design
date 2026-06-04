# JVM Internals & Virtual Threads

> *"The Java Virtual Machine has been the most-deployed managed runtime in production for thirty years. Its internals — the bytecode interpreter, the JIT compilers, the half-dozen garbage collectors, the threading model — are an entire engineering discipline. Project Loom's virtual threads, shipped in 2023, are the JVM's response to the C10K problem two decades after the rest of the industry went async. They preserve Java's blocking-thread idiom while quietly multiplexing millions of threads onto a few OS threads."*

---

## Topic Overview

The JVM (Java Virtual Machine) runs Java, Kotlin, Scala, Clojure, and other languages. Its internals — class loading, bytecode interpretation, JIT compilation, garbage collection, thread management — are mature and battle-tested. Production JVMs (HotSpot, OpenJ9, GraalVM) handle everything from low-latency trading to massive-scale Hadoop clusters.

The recent landmark: **Project Loom** (Java 21, 2023) introduces *virtual threads*. The JVM that for decades treated threads as expensive OS resources now provides cheap user-space threads multiplexed onto a small pool of OS threads. The programming model is unchanged — code uses `Thread` as before — but scaling to a million concurrent operations no longer requires async/reactive frameworks.

This is the topic where the JVM's design choices (managed memory, JIT, dynamic dispatch) meet modern concurrency demands. Understanding the runtime — bytecode, GC, virtual threads — is what separates "I write Java" from "I operate JVM services at scale."

---

## Intuition Before Definitions

Imagine a translator who interprets a foreign language live, but with a special trick: the more they see common phrases, the faster they translate them. After hearing "good morning" enough times, they have a memorized response that fires instantly.

That's the JIT. The interpreter starts slow (translating bytecode line by line). Hot code is compiled to native machine code. Frequently-used paths run at near-native speeds.

Now imagine the translator can hire assistants. Traditionally, each assistant was expensive (full salary, office, benefits). With Project Loom, assistants are cheap — they share offices, equipment, and only get paid when actually working. The translator can have thousands of assistants for the cost of a few.

That's virtual threads. The semantics of "I have many threads, each doing one thing" is preserved; the cost is dramatically reduced.

---

## Historical Evolution

**Era 1 — JVM 1.0 (1995).**
Bytecode interpreter only. Slow.

**Era 2 — JIT compilation (HotSpot, 1999).**
Sun's HotSpot JVM. Adaptive optimization; tiered compilation. Java becomes performance-competitive.

**Era 3 — Garbage collector evolution.**
Serial → Parallel → CMS → G1 → ZGC/Shenandoah. Each generation reduces pauses or improves throughput.

**Era 4 — Native libraries (NIO, 2002).**
Async I/O for the JVM. Foundation for Netty, etc.

**Era 5 — Reactive movement.**
2010s. RxJava, Project Reactor, async/await alternatives. Workarounds for JVM's expensive threads.

**Era 6 — Project Loom (2023).**
Virtual threads ship in JDK 21. Restores blocking-thread programming with async-runtime efficiency.

The pattern: the JVM evolved from interpreter to one of the most sophisticated runtimes in production. Loom is its latest big bet.

---

## Deep Technical Explanation

### Class loading

When you run a Java program, the JVM loads classes on demand:
- **Bootstrap classloader**: core classes.
- **Platform classloader**: platform extensions.
- **Application classloader**: your code.
- **Custom classloaders**: app servers, OSGi, hot-reloading frameworks.

Each class is loaded as bytecode (.class file), verified, prepared (statics initialized), resolved (symbolic references linked).

Class loading complexity is a recurring source of bugs (NoClassDefFoundError, version conflicts, classloader leaks).

### Bytecode

Java compiles to platform-independent bytecode. Operations like:
- `aload_0`: push local variable 0 onto stack.
- `invokevirtual`: virtual method call.
- `iadd`: integer add.

Bytecode is *stack-based*: operations push and pop from an operand stack. Nice for portability; less efficient than register-based.

The JIT transforms bytecode to register-based native code.

### Tiered compilation

Modern HotSpot:
- **Tier 0**: interpreter.
- **Tier 3**: C1 compiler with profiling. Quick to compile; moderate speed.
- **Tier 4**: C2 compiler. Slow to compile; aggressive optimization. Fast code.

A method starts interpreted; if hot, compiled by C1; if very hot, recompiled by C2.

Optimization techniques in C2:
- Inlining.
- Escape analysis.
- Loop unrolling.
- Vectorization.
- Speculative optimizations (deopt if assumption breaks).

A long-running JVM has its hot code in C2; it runs at near-native speeds.

### Deoptimization

C2 makes assumptions ("this method is only called with type X"). If broken, the code must deopt — fall back to C1 or interpreter.

Causes:
- Unexpected types.
- Class loading invalidates inline cache.
- Speculative branch broke.

Deopt is expensive. Frequent deopts kill performance.

### Garbage collectors (deep)

(See [garbage-collection-and-memory-management.md](../js-runtime/garbage-collection-and-memory-management.md) for general concepts.)

JVM-specific:

**Serial GC**: small heaps, single-threaded.
**Parallel GC**: throughput-focused; multi-threaded.
**G1**: regional; predictable pauses; default since Java 9.
**ZGC**: sub-ms pauses; multi-TB heaps.
**Shenandoah**: similar to ZGC.
**Epsilon**: no-op GC (testing only).

Tuning: `-Xms`, `-Xmx` (heap size); `-XX:+UseG1GC`; many other flags.

Monitoring: GC logs (`-Xlog:gc*`); JFR; tools like Eclipse MAT for heap analysis.

### Threading (pre-Loom)

Java threads = OS threads (since JDK 1.2; abandoning green threads).

Each thread:
- ~1 MB stack.
- OS scheduling.
- Expensive to create/destroy.

Patterns:
- Thread pools (`ExecutorService`).
- `ForkJoinPool` for parallel algorithms (work-stealing).
- Reactive frameworks for async patterns.

The JVM scaled to a few thousand threads max. C10K-class workloads required async.

### Project Loom — virtual threads

Java 21 (2023) ships virtual threads.

```java
Thread.startVirtualThread(() -> {
    // runs on a virtual thread
});
```

Or via executor:
```java
try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
    executor.submit(task);
}
```

Properties:
- Cheap (~KB per thread).
- Multiplexed onto OS threads (carrier threads).
- API-compatible with platform threads — `Thread` interface is the same.
- Blocking I/O is non-blocking under the hood.

When a virtual thread blocks on I/O:
- The JVM detects the block.
- Unmounts the virtual thread from its carrier.
- Carrier picks up another virtual thread.
- When I/O completes, virtual thread is rescheduled.

This is invisible to application code. `Thread.sleep`, `Socket.read`, `BufferedReader.readLine` — all work; all yield correctly.

### Virtual thread limitations

**Pinned threads.** A virtual thread that blocks inside a `synchronized` block can't unmount — it stays pinned to its carrier OS thread, which is therefore tied up. The scheduler can add *compensating* carrier threads (up to a cap) so the rest of the pool keeps progressing, but a flood of pinned threads still degrades scaling. Mitigation (pre-JDK 24): use `ReentrantLock` instead of `synchronized`. JDK 24 / JEP 491 removed the `synchronized` pinning limitation, so virtual threads can now unmount while holding monitors.

**Native code blocking.** JNI calls don't yield. Carrier thread is blocked.

**Thread-local storage.** Per-thread state with millions of virtual threads becomes massive. Use `ScopedValue` (Java 21+) instead.

These are real but solvable. Most production code can adopt virtual threads with minor changes.

### Foreign Function & Memory API

Java 22 (2024) finalized FFM: alternative to JNI for calling native code, with explicit memory control.

Properties:
- Off-heap memory management.
- No JNI overhead.
- Memory safety via API design.

Replaces JNI for many use cases. Faster; safer.

### Java's concurrency model

Pre-Loom:
- Threads + locks (ReentrantLock, synchronized).
- ConcurrentHashMap, atomic classes.
- ExecutorService and Future.
- CompletableFuture for async chains.

Post-Loom:
- Virtual threads make blocking code idiomatic again.
- Structured concurrency (preview in Java 21).
- Async patterns less necessary for many workloads.

The reactive ecosystem (Reactor, RxJava) remains for backpressure-heavy and fully-async workloads.

### Production tuning

**Heap sizing.** `-Xms == -Xmx` for predictability.

**GC selection.** ZGC for low-latency; G1 for general; Parallel for batch.

**JIT tuning.** Most defaults are good; tier compilation rarely needs tweaking.

**Thread pool sizing.** Pre-Loom: CPU cores × small multiplier. Post-Loom: virtual threads, no pool needed.

**Profile.** JFR, async-profiler.

### JVM languages

The JVM hosts multiple languages:
- **Kotlin**: Android default; coroutines as native concurrency.
- **Scala**: functional + OO; complex.
- **Clojure**: Lisp dialect.
- **Groovy**: dynamic.

All compile to bytecode; interop is generally good.

### GraalVM

Alternative JVM with:
- **AOT compilation**: native images at build time.
- **Polyglot**: run JS, Python, Ruby on the JVM.
- **Faster startup**: native images start in milliseconds.

Used for serverless, CLI tools, microservices wanting fast startup.

---

## Real Engineering Analogies

**The translator with growing memory.**
A translator interpreting between languages starts slow (working from dictionaries). Over time, common phrases become memorized; they translate instantly. Adapts to the speaker's style. That's the JIT.

**The factory that streamlined.**
A factory with expensive workers (OS threads) produces inefficiently. New management hires temp workers (virtual threads) for routine tasks. The factory now scales to many concurrent jobs without each job consuming a full worker's salary.

---

## Failure Scenarios

**Scenario 1 — The full GC nightmare.**
Service has 32GB heap. Default G1; major GC every 5 minutes; pauses 1.5s. p99 latency wrecked. Switch to ZGC: pauses 1ms. Latency normal.

**Scenario 2 — The pinned virtual thread.**
Migrated to virtual threads; performance unchanged. Investigation: code uses `synchronized` extensively; virtual threads pin to carriers. Fix: replace with ReentrantLock; throughput jumps.

**Scenario 3 — The classloader leak in app server.**
Tomcat reloads app; old classloader retained by static field reference. Memory grows. Restart needed weekly. Fix: identify references; clean up.

**Scenario 4 — The deopt regression.**
New deploy: latency degrades. C2 is deopt-ing repeatedly. Cause: new code path with different types. Fix: type stability; explicit polymorphism handling.

**Scenario 5 — The Loom adoption.**
Service replaces async/reactive with virtual threads. Code becomes simpler; throughput similar. Maintenance easier. Win.

---

## Performance Perspective

- **Startup**: cold JVM is slow; AOT (GraalVM) much faster.
- **Steady-state**: C2-compiled code rivals C++.
- **GC**: tunable for either throughput or latency.
- **Throughput**: very high; rivals or beats most language runtimes.

---

## Scaling Perspective

- **Single JVM**: tens of GB heap; thousands to millions of threads (with Loom).
- **Cluster**: many JVMs; each is its own runtime.
- **Cloud**: container-aware tuning matters.

---

## Cross-Domain Connections

- **GC**: JVM's GCs. (See [garbage-collection-and-memory-management.md](../js-runtime/garbage-collection-and-memory-management.md).)
- **Coroutines / green threads**: virtual threads are this category. (See [coroutines-and-green-threads.md](./coroutines-and-green-threads.md).)
- **Locks**: JVM concurrency primitives. (See [locks-mutexes-and-lock-free.md](./locks-mutexes-and-lock-free.md).)
- **Profiling**: JFR is industry-leading. (See [profiling-and-flame-graphs.md](../observability/profiling-and-flame-graphs.md).)
- **Parallelism vs concurrency**: ForkJoinPool, virtual threads. (See [parallelism-vs-concurrency.md](./parallelism-vs-concurrency.md).)

The unifying observation: **the JVM is one of the most sophisticated production runtimes ever built. Virtual threads belatedly bring async-runtime efficiency to its blocking-thread programming model — preserving Java's idioms while solving its scaling limits.**

---

## Real Production Scenarios

- **Netflix's JVM tuning**: extensive public engineering on G1 and beyond.
- **LinkedIn's Java services**: large-scale deployment.
- **Banks' Java servers**: a vast amount of finance runs on JVM.
- **Apache Kafka**: written in Java/Scala; JVM-tuned for low latency.
- **Hadoop / Spark**: JVM-based.
- **The Loom adoption stories**: emerging in 2024.

---

## Key Takeaways

- **JVM = bytecode + interpreter + JIT + GC + threading.** Each piece is its own engineering effort; tuning one affects the others.
- **Tiered compilation escalates:** interpret → C1 (quick) → C2 (aggressive optimize). Hot code reaches the top tier and rivals near-native/C++ speed. **Deopt** (a C2 assumption breaking, e.g. an unexpected type) falls back to C1/interpreter and kills performance — type stability matters.
- **GC is configurable; choice matters.** G1 (default, general), ZGC/Shenandoah (sub-ms pauses, low-latency), Parallel (batch throughput), Serial (small heaps). Pick for your latency/throughput needs.
- **Virtual threads (Loom, JDK 21) change the cost model:** pre-Loom a thread was an expensive OS resource (~1 MB stack, a few thousand max); post-Loom a virtual thread is a cheap (~KB) user-space context multiplexed onto carrier threads, making blocking-style code idiomatic again. They are not a cure-all — they don't automatically scale everything.
- **Pinning:** a virtual thread blocking inside `synchronized` can't unmount and stays pinned to its carrier. Mitigate with `ReentrantLock` (JDK 24 / JEP 491 removed this limitation). Native/JNI calls also don't yield. With millions of threads, prefer `ScopedValue` over thread-locals.
- **The JVM is highly observable.** JFR, JMC, async-profiler, GC logs — excellent, mostly-free production tooling. Keep JFR on (tune the sampling rate; always-on profiling has a small but real cost).
- **`-Xms == -Xmx`** for predictability; container-aware tuning matters in the cloud.
- **Classloader leaks** (retained classloaders on app-server reload) are a famous, recurring source of growing memory.
- **OOM from giant arrays:** a single allocation larger than the heap fails — know your data sizes; off-heap memory (FFM API, Java 22) sometimes matters.
- **GraalVM** offers AOT native images (millisecond startup, good for serverless/CLI/microservices) and polyglot execution.
- **Big picture:** the JVM is one of the most sophisticated production runtimes ever built. Virtual threads belatedly bring async-runtime efficiency to its blocking-thread programming model — preserving Java's idioms while solving its scaling limits.

### Interview angle

- **"How does JIT work?"** Tiered compilation; profiling; deopt.
- **"GC algorithms?"** G1, ZGC, Shenandoah trade-offs.
- **"What are virtual threads?"** Loom; cheap multiplexed threads.
- **"What's pinning?"** A virtual thread can't unmount during `synchronized`.
- **"How do you tune the JVM?"** Heap, GC, profiling.
- **Common trap:** believing virtual threads automatically scale everything.
