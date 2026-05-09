# Locks, Mutexes & Lock-Free Programming

> *"A lock is not a tool for making code correct. It's a tool for making the consequences of incorrectness less obvious."*

---

## Topic Overview

Concurrency is the art of getting multiple things to happen at once without them tripping over each other. Locks are the oldest, simplest, most-used answer — and the source of more production-level horror stories than perhaps any other primitive in computing. Deadlocks, priority inversion, lock convoy, ABA bugs, livelock, false sharing — entire vocabularies exist to name the ways locks fail when programmers don't think carefully.

The alternative — *lock-free* and *wait-free* programming — promises better performance and absence of certain failure modes, at the cost of being much harder to reason about. Compare-and-swap loops, memory ordering semantics, hazard pointers, RCU. The territory of "I'll just add a `lock()` here" doesn't extend into this region.

This is the topic where hardware, language semantics, and operational reality crash into each other. The same phrase ("thread-safe") means different things to different programmers, and the differences are often the bug. Understanding when to lock, what to lock, how granular to lock, and when *not* to lock at all is the difference between concurrent code that works and concurrent code that *appears* to work.

---

## Intuition Before Definitions

Picture a single bathroom in a small office.

When someone needs to use it, they lock the door. Anyone else has to wait. The lock guarantees that only one person uses the bathroom at a time — *mutual exclusion*. Simple. Obvious.

Now scale up. Two bathrooms. Now three. People start optimizing — checking which one is free before queueing. Sometimes they pick the wrong one and queue behind a slow user while the other becomes free. Sometimes two people see "free" simultaneously and race for the door. Sometimes Alice locks bathroom 1 and waits for bathroom 2 (she needs supplies from there); Bob locks bathroom 2 and waits for bathroom 1. Neither moves. *Deadlock.*

Now imagine the bathroom *is* the file you're writing to, and "person" is a thread. Real systems have thousands of bathrooms (data structures), millions of people (operations), and stricter requirements ("the office must keep working"). The simple lock-the-door model becomes much harder. People sometimes hold a lock for too long, blocking everyone behind them. Sometimes a high-priority person yields to a low-priority one because of the lock structure. Sometimes — under specific patterns — the entire office grinds to a halt and nobody can figure out why.

Lock-free programming is the equivalent of "let me just leave a note saying I was here, and check before I leave whether someone else also left a note, and if so we'll figure it out." Faster in many cases. Almost impossible to get right without specialized tools.

---

## Historical Evolution

**Era 1 — Cooperative multitasking and explicit yields.**
Early multitasking systems (early Mac OS, Windows 3.1) had no preemption. A thread held the CPU until it yielded. Concurrency bugs were limited to the points where you yielded. Simple, fragile.

**Era 2 — Preemptive threads and the lock revolution.**
Posix threads, Windows threads. The OS could interrupt any thread at any instruction. Suddenly *anything* could happen between any two operations. Locks became the universal answer. The 1990s and early 2000s were the era of "synchronize everything" — entire frameworks (early Java) made every method synchronized by default, with predictable performance disasters.

**Era 3 — The multicore awakening (2005).**
CPU clock speeds plateau; chips grow cores instead. Suddenly every program is multi-threaded whether the developer wants it or not. Locks built for single-CPU machines reveal scalability ceilings. Cache coherence becomes a programmer's concern. Lock-free data structures move from research curiosities to standard libraries (Java's `java.util.concurrent`, C++'s `<atomic>`).

**Era 4 — Memory model formalization.**
Java Memory Model (2005), C++11 memory model (2011). For the first time, the *exact* semantics of "thread-safe" became language-level specifications. Programmers learned about acquire/release semantics, sequential consistency, relaxed ordering. The territory was real.

**Era 5 — Software transactional memory and alternatives.**
STM (research peak in 2000s, surviving in Haskell and Clojure). The actor model (Erlang, Akka). Channels (Go, Rust). Each tries to *eliminate the lock as the unit of synchronization*. Mixed adoption; locks remain dominant for low-level work.

**Era 6 — Async runtimes and lock contention as the new bottleneck.**
With async/await making single-threaded concurrency easy, multi-threaded use cases shrink — but where they remain (parallel computation, shared caches, in-memory databases), lock contention is increasingly the bottleneck. Modern designs increasingly partition data per-thread (sharded locks, work-stealing) to avoid contention rather than optimize it.

The pattern: each generation either *added a synchronization primitive* or *eliminated the need for one*. The arc of concurrency is toward less explicit synchronization, more structured concurrency, and partitioning over locking where possible.

---

## Core Mental Models

**1. A lock protects an *invariant*, not a variable.**
The mistake most beginners make: locking a single variable. The right model: identify the invariant ("the linked list's pointers are consistent"), determine what must be atomic to preserve it, and lock the entire critical section. Locking less is unsafe; locking more is slow.

**2. Lock granularity is a fundamental tradeoff.**
Coarse locks (one lock for everything) are simple but contended. Fine-grained locks (one per object) are scalable but error-prone (deadlock risk, more complex). The right granularity depends on the workload's contention pattern, not on intuition.

**3. The hardware is doing things you don't see.**
Caches, write buffers, instruction reordering — modern CPUs aggressively reorder memory operations. Without explicit memory barriers (or language-level acquire/release semantics), you cannot assume your writes are visible to other threads in the order they appear in your code.

**4. Lock-free ≠ wait-free ≠ fast.**
Lock-free guarantees the system makes progress; some thread always advances. Wait-free guarantees *every* thread makes progress in bounded steps. Both are weaker than "absence of locks" suggests; both can be slower than locks for low-contention workloads. Algorithm complexity often outweighs primitive efficiency.

**5. Contention is the cost.**
A lock with no contention is essentially free (microseconds). A lock with heavy contention serializes throughput to one thread's worth of work. The work isn't "wait" — it's *coherence traffic between CPU caches*, which is slow, invisible, and underappreciated.

---

## Deep Technical Explanation

### Mutex — the fundamental primitive

A mutex (mutual exclusion lock) provides:
- `lock()` — block until exclusive ownership is acquired.
- `unlock()` — release ownership.

Implemented at multiple levels:
- **Spinlock**: busy-wait in a tight loop checking an atomic flag. Cheap when contention is brief; murderous when it isn't.
- **OS mutex**: blocking via syscall. Thread is descheduled until the lock is available. Cheap to wait; expensive to acquire (context switch).
- **Adaptive mutex**: spin briefly, then block. Modern OS mutexes often work this way.

The lock acquisition itself uses atomic operations:
```
while (atomic_compare_exchange(lock_flag, expected=0, desired=1) == false) {
    // contended path
}
```

CAS (compare-and-swap) is the bedrock instruction. Most concurrent primitives are built on it.

### Reader-writer locks

```
read_lock(): allow multiple concurrent readers, no writer.
write_lock(): exclusive; no other reader or writer.
```

Useful when reads vastly outnumber writes. Two failure modes:
- **Writer starvation**: continuous readers prevent writers from ever acquiring. Mitigation: writer-preference variants.
- **Reader starvation**: writer-preference can starve readers under heavy writes.

Modern alternative: RCU (Read-Copy-Update), where readers don't block at all.

### Spinlocks vs blocking — when each wins

Spinlock wins when:
- The critical section is *very short* (nanoseconds).
- Contention is rare.
- The OS context-switch cost would exceed the wait time.
- Used in kernels, low-level real-time systems.

Blocking lock wins when:
- The critical section is non-trivial (microseconds+).
- Contention is significant.
- You don't want to burn CPU cycles spinning.
- Used in almost all application code.

Adaptive mutexes do both — spin briefly, fall back to blocking if the wait extends.

### Deadlock

The classic four conditions (Coffman, 1971):
1. **Mutual exclusion**: at least one resource held exclusively.
2. **Hold and wait**: a thread holds a resource and waits for another.
3. **No preemption**: resources can't be forcibly taken.
4. **Circular wait**: a cycle in the wait-for graph.

Break any one to prevent deadlock. The most common technique: **lock ordering**. All threads must acquire locks in the same global order. Cycles cannot form because the order is total.

### Livelock

Two threads detect they're in conflict and politely back off — repeatedly, in lockstep. Neither makes progress. The classic example: two people in a hallway, each stepping aside in the same direction, repeatedly. Mitigation: randomized backoff.

### Lock convoy

A thread holds a lock briefly, releases it; another thread immediately acquires it; first thread tries to re-acquire and blocks. The lock has effectively become a serialization point. All threads run in lockstep, with throughput equal to one thread. Often invisible until profiling shows lock acquisition as a hotspot.

### Priority inversion

A low-priority thread holds a lock. A high-priority thread waits for it. A medium-priority thread (CPU-bound, doesn't need the lock) preempts the low-priority thread, preventing it from releasing. The high-priority thread is effectively blocked by the medium-priority one.

The classic case: NASA's Mars Pathfinder rover (1997). A low-priority thread held a lock while a medium-priority thread monopolized CPU. Mission-critical high-priority work was delayed, triggering watchdog resets. Diagnosed remotely; fixed by enabling priority inheritance.

### False sharing

Two threads modify *different* variables that happen to live in the *same CPU cache line* (typically 64 bytes). The cache coherence protocol invalidates the line on the other CPU's cache for every modification. Performance collapses. The threads aren't sharing data — but the hardware thinks they are.

Mitigation: align hot variables to cache-line boundaries; pad structures to ensure independence.

### Memory ordering

Modern CPUs reorder memory operations for performance. Without barriers:

```
// Thread A
x = 1;        // (1)
flag = true;  // (2)

// Thread B
if (flag) {       // (3)
    print(x);     // might print 0!
}
```

The CPU might reorder (1) and (2). Without an explicit barrier, Thread B can see `flag = true` while still seeing `x = 0`.

Memory orderings (C++ vocabulary):
- **Relaxed**: no ordering guarantees. Just atomicity.
- **Acquire**: subsequent reads/writes can't move before this.
- **Release**: prior reads/writes can't move after this.
- **Acquire-release**: both.
- **Sequentially consistent**: total global order. Strongest, slowest.

Java's `volatile` and Go's atomic operations default to sequential consistency. Lower-level languages let you weaken for performance — at significant complexity cost.

### Lock-free data structures

A lock-free queue (Michael & Scott, 1996):

```
push(value):
    node = new Node(value)
    while True:
        tail = atomic_load(tail_ptr)
        next = atomic_load(tail.next)
        if next is None:
            if compare_and_swap(tail.next, None, node):
                compare_and_swap(tail_ptr, tail, node)
                return
        else:
            compare_and_swap(tail_ptr, tail, next)  # help advance
```

The key idea: instead of locking, *retry on failure*. CAS detects conflicts; the loser tries again. No thread blocks; some thread always makes progress.

Costs:
- More complex code.
- Memory ordering subtleties.
- The **ABA problem**: a CAS sees the same value before and after, but the value was changed in between (and changed back). Mitigations: hazard pointers, version counters (CAS on a 128-bit value), epoch-based reclamation, RCU.

Memory reclamation is the hardest part: how do you free a node when other threads might still be reading it? "Just free it" is a use-after-free. Hazard pointers and epoch-based GC are the standard answers; both are non-trivial.

### Wait-free

A weaker stronger guarantee: every thread completes its operation in *bounded* steps. No starvation possible. Useful in real-time systems. Generally even harder to implement than lock-free; performance often worse for typical workloads.

### Channels and message passing

Go's channels, Erlang's mailboxes, Rust's `mpsc::channel`. Instead of sharing memory and synchronizing with locks, threads/tasks communicate by sending values. The underlying implementation uses locks (or lock-free queues), but the *programming model* eliminates explicit synchronization.

Go's mantra: "Don't communicate by sharing memory; share memory by communicating." The channel is the synchronization point; data ownership transfers atomically.

The tradeoff: channels add overhead vs lock-protected shared state for some workloads (e.g., a hot in-memory cache). They radically simplify reasoning for many others (event handling, pipeline processing).

---

## Real Engineering Analogies

**The library reading room.**
A reading room with rare books. Multiple readers can examine the same book (read lock). To make a correction, the librarian must take the book to a back room (write lock) — and no one else can see the book during that time. If readers refuse to leave, the correction never happens (writer starvation). If the librarian always wins, readers may wait indefinitely (reader starvation).

The reading room only works because *the social contract* is the lock — and like real locks, it's only as good as its weakest enforcer.

**The single restaurant kitchen.**
Multiple chefs (threads) preparing dishes (operations). Only one chef can use the oven (resource) at a time. Bad day: Chef A grabs the oven and waits for the prep counter (held by Chef B); Chef B is using the prep counter and waiting for the oven. Both are stuck. Deadlock. The fix: a strict rule — always grab the oven first, then the counter. Lock ordering, made physical.

---

## Production Engineering Perspective

What concurrency bugs look like in production:

- **The intermittent test failure.** A test passes 999 times, fails the 1000th. "Flaky test." It's almost always a race condition. The fix is hard; the temptation to mark it as flaky and move on is corrosive.
- **The deadlock that only happens in production.** Higher contention exposes a code path that's deadlock-prone. Local testing doesn't trigger it. Recovery: deadlock detection in production, lock-ordering audits, simplification.
- **The cache invalidation lock convoy.** A "global mutex" around a cache invalidation runs at every request. Throughput is capped at the lock's serialization rate. CPUs sit idle while the queue grows. Profiling shows nearly all time waiting on the lock.
- **The false-sharing surprise.** A counter array, one element per thread. Performance scales sub-linearly with cores. Investigation reveals counters share cache lines. Padding to 64-byte alignment unlocks scaling.
- **The atomic-but-not-atomic pattern.** A counter incremented "atomically" via `count++`. In some languages (Python, Ruby), this is *not* atomic — it compiles to load, modify, store. Concurrent increments lose updates. Fix: explicit atomic operation or lock.
- **The forgotten lock.** A code path adds a new field but forgets the lock. Other paths still lock; this one doesn't. Data corruption appears under specific timing. Diagnosed only by careful audit; modern languages with RAII (Rust, C++) make this less common.
- **The deadlock from logging.** A logger acquires a lock to write to a shared file. A failure handler logs from inside a critical section. The critical section's lock is held while waiting on the logger's lock. Another thread holds the logger's lock and is logging into a critical section. Mutual deadlock from infrastructure code.

The senior engineer's habits:
- **Document lock ordering** in every codebase that uses multiple locks.
- **Use higher-level primitives** where possible (channels, async tasks, immutable data).
- **Profile lock contention** as part of performance work.
- **Prefer partitioning over locking** — give each thread its own data when possible.
- **Don't hold locks while doing I/O.** Ever.
- **Don't hold locks while calling unknown code.** External callbacks may invoke arbitrary work.

---

## Failure Scenarios

**Scenario 1 — The classic deadlock.**
Method A acquires lock X, then tries to acquire lock Y. Method B acquires lock Y, then tries to acquire lock X. Under load, they collide. Service hangs. Restart "fixes" it — until next time. Permanent fix: enforce global lock ordering; refactor to acquire both locks atomically (typically via a higher-level lock).

**Scenario 2 — The lock convoy in a hot cache.**
A web server caches user profiles. Cache access goes through a single mutex. With 64 cores and high QPS, every request contends. CPU usage 30%, throughput half what it should be. Fix: shard the cache across N mutexes by hash; or use a lock-free concurrent map.

**Scenario 3 — Priority inversion in a real-time system.**
A safety-critical thread (high priority) waits on a lock held by a logging thread (low priority). A computation thread (medium priority) preempts the logging thread. Safety thread misses its deadline. Fix: priority inheritance — lock holders temporarily inherit the highest priority waiting on the lock.

**Scenario 4 — False sharing in a metrics system.**
Per-core metric counters laid out as `int counters[NUM_CORES]`. Each int is 4 bytes; cache line is 64 bytes. 16 counters share each cache line. Concurrent updates cause cache-line bouncing. Throughput is 10× lower than expected. Fix: pad each counter to its own cache line.

**Scenario 5 — The data race that "works."**
A reader thread reads a flag set by a writer thread. No memory barrier. Compiler caches the flag in a register. Reader spins forever even after writer sets the flag. The bug is invisible in debug builds (less optimization) and "intermittent" in release builds. Fix: declare the flag `volatile` (Java) / `atomic` (C++) / use proper memory ordering.

---

## Performance Perspective

- **Uncontended locks are nearly free** (~10–50ns). Don't over-optimize away.
- **Contended locks serialize throughput**. The theoretical maximum is one thread's worth of throughput on the critical section.
- **CAS is faster than locks** for simple operations (counters, flags) under contention.
- **Lock-free is not always faster.** Under low contention, locks often win because the CAS retry loop adds overhead.
- **Cache-line bouncing** is the hidden cost of any shared mutable state — locked or atomic.
- **Partitioning beats optimizing locks**: per-thread or per-shard data avoids the question entirely.

---

## Scaling Perspective

- **Scale up:** modern CPUs have dozens of cores. Lock contention scales superlinearly with cores under fixed workload.
- **Scale out:** distributed locks (Redis, ZooKeeper, etcd) carry network latency. Use sparingly; prefer partitioning.
- **Hot keys:** a single shared resource (a counter, a list, a singleton) is a scaling killer. Partition or eliminate.
- **The work-stealing pattern:** each thread has its own work queue; when empty, steal from another. Used in Go's runtime, Java's ForkJoinPool, Tokio's scheduler. Eliminates global contention.
- **At extreme scale:** lock-free + RCU + per-CPU data structures. Linux kernel pioneered these techniques for SMP scaling.

---

## Cross-Domain Connections

- **MVCC**: snapshot isolation lets readers proceed without locks. The same insight at the database layer. (See [mvcc-and-isolation-levels.md](../database-internals/mvcc-and-isolation-levels.md).)
- **Distributed consistency**: distributed locks (Redlock, ZooKeeper) are locking promoted to a network. Same failure modes, longer timescales. (See [cap-consistency-and-replication.md](../distributed-systems/cap-consistency-and-replication.md).)
- **Event loop**: single-threaded execution gives you free mutual exclusion within a process. The cost: no parallelism. (See [event-loop-and-async-runtime.md](../js-runtime/event-loop-and-async-runtime.md).)
- **Backpressure**: lock waits are queues; lock convoys are queue-amplifying behavior. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Caching**: cache coherence between CPUs is a hardware-level locking protocol (MESI). The same theory recurs at silicon. False sharing is cache coherence working against you.
- **OS schedulers**: priority inheritance, futex implementations, work-stealing — kernel-level concurrency primitives that user-space inherits.

The unifying insight: **synchronization is what happens when state is shared. The cheaper alternative is almost always to share less.**

---

## Real Production Scenarios

- **NASA's Mars Pathfinder priority inversion (1997)**: textbook case of low-priority thread holding a lock needed by a high-priority one, with a medium-priority thread monopolizing CPU. Fixed remotely by enabling priority inheritance.
- **Linux kernel's RCU adoption**: reader-side scalability achieved by allowing readers to proceed without locks, with deferred reclamation of obsolete data. Enabled the kernel to scale to hundreds of cores.
- **JDK's `ConcurrentHashMap` evolution**: from globally-locked Hashtable, to lock-striped (16 segments), to fully lock-free in Java 8+. Each generation a more sophisticated answer to the same problem.
- **Go's `sync.Map`**: introduced after years of community lock-contention pain on built-in `map` plus `sync.Mutex`. Targeted at append-mostly, read-heavy workloads.
- **Redis's choice of single-threaded execution**: avoids the entire question. Trades per-core throughput for radical simplicity. Has aged remarkably well.
- **PostgreSQL's heavyweight lock contention** at scale: well-documented in Postgres internals; mitigated through MVCC and finer-grained latch design.

---

## What Junior Engineers Usually Miss

- That **`x++` is not atomic** in most languages.
- That **the compiler can reorder** memory operations.
- That **thread-safe doesn't mean correct** in your specific use.
- That **adding a lock can cause deadlock** with existing locks.
- That **fine-grained locks aren't always faster** — overhead and complexity matter.
- That **holding a lock while doing I/O** is a recipe for outages.
- That **debug mode hides race conditions** that release mode exposes.
- That **lock-free is hard** and "we'll write our own" is rarely the answer.

---

## What Senior Engineers Instinctively Notice

- They **document lock ordering** explicitly.
- They **prefer immutable data** and channels to shared mutable state.
- They **partition data per-thread** when scalability matters.
- They **profile lock contention** as a regular discipline.
- They **never hold locks across I/O or callbacks**.
- They **use higher-level primitives** (atomics, channels, futures) by default.
- They **know about false sharing** and pad accordingly when it matters.
- They **respect the difference between "thread-safe" and "concurrent and correct."**

---

## Interview Perspective

What gets tested:

1. **"What's a deadlock?"** Tests basics. Bonus for naming the four Coffman conditions and lock ordering as the standard prevention.
2. **"What's a lock convoy?"** Mid-level. Senior candidates explain it as serialization through a single mutex.
3. **"Explain the ABA problem."** Tests lock-free awareness. The right answer involves CAS seeing the same value despite intermediate changes.
4. **"What's false sharing?"** Tests hardware awareness. Right answer: cache-line bouncing from independent variables.
5. **"How would you make a thread-safe counter?"** Junior: mutex around a variable. Senior: atomic increment. Staff: per-CPU counters with periodic aggregation, depending on workload.
6. **"What's the difference between lock-free and wait-free?"** Lock-free: system makes progress. Wait-free: every thread bounded.
7. **"When wouldn't you use locks?"** Senior answer: when you can partition, when you can use immutable data, when channels work, when atomics are sufficient.

Common traps:
- Using `volatile` thinking it's a lock.
- Believing `synchronized` makes everything thread-safe.
- Confusing atomic operations with locks.
- Not knowing about memory ordering.

---

## 20% Knowledge Giving 80% Understanding

1. **A lock protects an invariant**, not a single variable.
2. **Lock ordering** prevents deadlock. Document it.
3. **Don't hold locks across I/O** or unknown code.
4. **CAS** is the foundation of lock-free programming.
5. **Memory ordering matters**: writes can be reordered without barriers.
6. **False sharing** kills performance silently.
7. **Partitioning > optimizing locks** for scalability.
8. **Lock-free is not always faster** under low contention.
9. **Higher-level primitives** (channels, immutable data, async) avoid most lock pitfalls.
10. **Reader-writer locks** for read-heavy workloads; RCU/MVCC for extreme cases.

---

## Final Mental Model

> **A lock is a confession that you're sharing mutable state. Every other technique — partitioning, immutability, channels, MVCC — is a way to confess less.**

The senior engineer's instinct, looking at concurrent code, isn't to add another lock. It's to ask: *do these threads need to share this state?* Often, the answer is no — and the "fix" is partitioning, copying, or restructuring rather than locking. When sharing is genuinely required, locks are a tool, but never the only tool. Atomics, channels, message passing, immutable snapshots, and lock-free structures all have their place.

Concurrency bugs are the bugs that survive code review, pass tests, and ship to production — and surface only under load that nobody could reproduce locally. The defensive discipline is to *minimize the surface area* on which they can occur. Less shared mutable state. Fewer locks. Clearer ownership. Higher-level abstractions.

That's locks. That's lock-free. That's the discipline of making concurrent code as boring as you can — because boring code is the only code that survives the chaos of production.
