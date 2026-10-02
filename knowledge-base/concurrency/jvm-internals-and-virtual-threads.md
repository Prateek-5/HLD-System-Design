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

## Core Mental Models

**1. JVM = bytecode + interpreter + JIT + GC + threading.**
Each piece is its own engineering effort. Tuning one affects the others.

**2. JIT compilation tiers escalate.**
Interpret → C1 (quick compile) → C2 (aggressive optimize). Hot code reaches the top tier.

**3. Garbage collection is configurable.**
Multiple algorithms; choose for your latency/throughput needs.

**4. Virtual threads change the cost model of threads.**
Pre-Loom: thread = expensive OS resource. Post-Loom: virtual thread = cheap user-space context.

**5. The JVM is highly observable.**
JFR, JMC, async-profiler, GC logs. Excellent tooling for production.

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

**Pinned threads.** A virtual thread inside a `synchronized` block can't unmount. JVM creates an extra carrier thread; degrades scaling. Mitigation: `ReentrantLock` instead of `synchronized` (Java 21 has improvements; see Java 24+ for further fixes).

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

## Production Engineering Perspective

What goes wrong:

- **The GC pause cliff.** Heap too big; major GCs pause for seconds. Switch to ZGC; pauses drop.
- **The classloader leak.** App server reloading creates classloaders that aren't collected. Memory grows. Famous source of bugs.
- **The deopt storm.** Hot code's assumption breaks (new type seen); C2 deopts; performance drops. Fix: type stability.
- **The thread pool starvation.** Pre-Loom: thread pool size too small; requests queue; slow. Post-Loom: virtual threads avoid this.
- **The pinned virtual thread.** `synchronized` blocks during I/O pin virtual threads to carriers. Loom doesn't help. Fix: ReentrantLock.
- **The JFR overhead.** Always-on profiling; small but real cost. Tune sampling rate.
- **The OOM from giant arrays.** Single allocation > heap. Know your data sizes.

The senior JVM engineer's habits:
- **Use ZGC or G1** for production.
- **Heap sizing** with `-Xms == -Xmx`.
- **JFR always on** for production diagnostics.
- **Virtual threads** for blocking-style services.
- **Profile** with async-profiler.
- **Watch GC logs**.

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

## What Junior Engineers Usually Miss

- That **virtual threads ≠ all problems solved**.
- That **classloader leaks** exist.
- That **GC choice matters**.
- That **JIT deopt** is a real cost.
- That **JFR** is excellent and free.
- That **off-heap memory** sometimes matters.

---

## What Senior Engineers Instinctively Notice

- They **use ZGC for low-latency**.
- They **tune heap size deliberately**.
- They **use JFR continuously**.
- They **adopt virtual threads where appropriate**.
- They **understand pinning**.
- They **read GC logs**.

---

## Interview Perspective

What gets tested:

1. **"How does JIT work?"** Tiered compilation; profiling; deopt.
2. **"GC algorithms?"** G1, ZGC, Shenandoah trade-offs.
3. **"What are virtual threads?"** Loom; cheap multiplexed threads.
4. **"What's pinning?"** Virtual thread can't unmount during synchronized.
5. **"How do you tune the JVM?"** Heap, GC, profiling.

Common traps:
- Believing virtual threads automatically scale everything.

---

## 20% Knowledge Giving 80% Understanding

1. **JVM = bytecode + JIT + GC + threading**.
2. **Tiered compilation**: interp → C1 → C2.
3. **G1, ZGC, Shenandoah** are the modern GCs.
4. **Virtual threads** make blocking idiomatic again.
5. **Pinning** during `synchronized`.
6. **JFR** for production profiling.
7. **`-Xms == -Xmx`** for predictability.
8. **Container-aware** tuning matters.
9. **Deopt** kills performance.
10. **GraalVM** for AOT and polyglot.

---

## Final Mental Model

> **The JVM is what production-grade managed runtimes look like. Decades of engineering produce a runtime that JIT-compiles to near-native speed, garbage-collects with sub-millisecond pauses, and (with Loom) handles millions of threads. Java's longevity isn't accident — it's the runtime working harder than any other.**

The senior JVM engineer reaches for virtual threads where they fit. They tune GC for the workload. They use JFR continuously. The JVM rewards discipline; production systems run on it for good reasons.

That's JVM internals. That's virtual threads. That's the runtime under thirty years of enterprise software — and the foundation under modern services that handle a million concurrent users.
