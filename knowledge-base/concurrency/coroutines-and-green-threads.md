# Coroutines, Green Threads & Async Runtimes

> *"Threads are expensive because the OS owns them. Green threads are cheap because the runtime owns them. Coroutines are even cheaper because the compiler owns them. The story of concurrency in modern languages is the story of moving the cost of threading off the kernel and into user space — until it disappears almost entirely."*

---

## Topic Overview

For decades, "concurrency" meant OS threads — heavy, preemptive, with megabyte stacks, ~10μs context switches, and limits in the tens of thousands per process. Modern systems handle hundreds of thousands or millions of concurrent operations. Something had to give.

The answer was *moving the threading abstraction up the stack*. Green threads (Erlang's processes, Java's virtual threads), coroutines (Python's, Kotlin's, C++'s), and async/await runtimes (Rust's tokio, Node's event loop) all share a core insight: an OS thread is overkill for a unit of concurrent work that mostly waits. Build cheaper concurrent units in user space, multiplex them onto OS threads, and you can handle millions of concurrent operations on hardware that supports thousands of OS threads.

This is the topic where threading evolves into a layered system: at the bottom, OS threads (your CPU parallelism); in the middle, runtime schedulers (work-stealing, cooperative); on top, the developer-facing concurrency primitives (goroutines, async tasks, virtual threads). Understanding the stack — what each layer does, what it costs, and how they compose — is what separates "I write async code" from "I understand async."

---

## Intuition Before Definitions

Imagine a hospital's nursing system.

**OS threads.** Each nurse has their own room, their own equipment, their own break schedule. Hiring a nurse takes weeks; firing is awkward. Each nurse handles one patient at a time. To care for 1000 patients, you need 1000 nurses. Expensive.

**Green threads.** A small team of "core nurses" handles many "virtual nurses" — quick task contexts, each focused on one patient's care plan. The core nurses switch between virtual nurses based on what needs attention. 1000 patients can be cared for by 5-10 core nurses, each managing many concurrent contexts.

**Coroutines / async tasks.** Even cheaper. The hospital's electronic system tracks each patient's state. A core nurse looks up the next patient who needs something, does it, looks up the next. The "patient context" is just data; switching between them is microseconds. Tens of thousands of patients per nurse.

The progression is the same: each generation made the per-task overhead smaller. The number of concurrent tasks that can be handled grows by orders of magnitude. The question becomes "what's the right primitive for this kind of work?"

---

## Historical Evolution

**Era 1 — Forking processes.**
1970s. Each request handled by a forked process. Heavy. Apache prefork. Reliable but limited to thousands of concurrent operations.

**Era 2 — Threads.**
1990s. Cheaper than processes; share address space. Apache MPM worker. Tens of thousands of concurrent operations possible. Lock contention becomes a concern.

**Era 3 — Green threads (early).**
1990s. Java initially had green threads on top of one OS thread; abandoned for native threads in JDK 1.2. Erlang takes the opposite path: lightweight processes managed by the BEAM VM, never adopting OS-thread-per-process model.

**Era 4 — The async revolution.**
2009 onward. Node.js (event loop), Twisted (Python), Tornado, asyncio. Single-threaded async I/O. Concurrent operations limited only by memory; tens of thousands per process routine.

**Era 5 — Modern runtimes.**
~2016 onward. Go's goroutines (cheap, multiplexed onto OS threads, work-stealing scheduler). Rust's async with tokio. Kotlin coroutines. Python's asyncio matures.

**Era 6 — Virtual threads.**
2023+. Java's Project Loom delivers virtual threads — JVM-managed lightweight threads that look like OS threads but are cheap. The fragmentation between "thread world" and "async world" begins to heal.

The pattern: each generation made concurrent units cheaper. The newer abstractions (goroutines, virtual threads) try to bring back the simplicity of "just write blocking code" with the efficiency of async I/O.

---

## Core Mental Models

**1. Concurrent unit cost decreases up the stack.**
OS threads: ~1 MB stack, 10-100μs switches, limited to thousands.
Green threads / virtual threads: KB stacks, microsecond switches, millions per process.
Coroutines / async tasks: hundreds of bytes, nanosecond switches, even more.

**2. Cooperative vs preemptive scheduling.**
OS threads: preemptive (the kernel can interrupt anywhere). Coroutines/async tasks: cooperative (the task yields explicitly, often at `await` points). Cooperation requires care — a tight CPU loop blocks the runtime.

**3. M:N scheduling is the modern default.**
M user-space tasks multiplexed onto N OS threads. The runtime's scheduler decides which task runs on which thread. Work-stealing balances load.

**4. Function coloring is a real trade-off.**
"Async functions can call async functions; sync functions can't easily call async ones." This creates "red" (async) and "blue" (sync) functions. Some languages avoid this (Go, Erlang, Java with Loom); others embrace it (Rust, JS, Python).

**5. Where compute happens matters.**
Async/coroutines help with I/O-bound work. They don't add CPU parallelism within one process. A CPU-bound task in a coroutine still blocks all other coroutines on its thread. (See [parallelism-vs-concurrency.md](./parallelism-vs-concurrency.md).)

---

## Deep Technical Explanation

### OS threads in detail

The kernel's thread abstraction:
- Each thread has a stack (default 1-8 MB on Linux).
- Each thread is scheduled by the kernel.
- Context switches involve register save/restore, kernel TLB updates, ~1-10μs.
- Blocking syscall puts the thread in a wait queue; another thread runs.

Properties:
- **Preemptive**: kernel can interrupt anywhere. Fairness is automatic.
- **Heavy**: stack memory dominates. 10K threads = 10-80 GB just for stacks.
- **Slow context switch**: kernel transition is the cost.

For decades, thread-per-connection servers were viable — until C10K (the problem of 10,000 concurrent connections, 1999). Threads couldn't scale; the alternatives emerged.

### Green threads / virtual threads

User-space threading: the runtime (not the kernel) manages "threads."

**Erlang/OTP processes:**
- BEAM VM schedules millions of processes.
- Each process has ~300 bytes of overhead.
- Processes communicate only via message passing.
- Preemptive scheduling at *reduction* boundaries (a unit of work).
- Used for highly-concurrent telecom systems for decades.

**Go goroutines:**
- ~2KB initial stack (grows as needed).
- Multiplexed onto a pool of OS threads (default: GOMAXPROCS = number of CPUs).
- Work-stealing scheduler balances load.
- Cooperative-with-preemption: scheduler can preempt goroutines at safe points (modern Go).

**Java virtual threads (Loom):**
- ~1KB overhead per thread.
- Multiplexed onto OS threads (carrier threads).
- Looks identical to platform threads from API perspective.
- Aim: "make blocking code scalable without rewriting in async style."
- Released in Java 21 (2023).

The common theme: cheap concurrent units, M:N scheduling, work-stealing, cooperative with safety preemption.

### Coroutines and async/await

A coroutine is a function whose execution can pause and resume. Implementation: state machine. The compiler transforms the function into states; each `await` is a yield point.

**JavaScript:**
```js
async function fetchData() {
  const response = await fetch(url);   // yield point
  const data = await response.json();  // yield point
  return data;
}
```

The compiler converts this to roughly:
```js
function fetchData() {
  return fetch(url).then(response => response.json());
}
```

The state machine is implicit; the developer writes linear code; the runtime schedules.

**Rust async:**
```rust
async fn fetch_data() -> Result<Data, Error> {
    let response = http::get(url).await?;
    let data: Data = response.json().await?;
    Ok(data)
}
```

The compiler generates a state machine; tokio runs it. Zero-cost abstraction in principle — the generated code is similar to hand-written state machines.

**Python asyncio:**
```python
async def fetch_data():
    async with aiohttp.ClientSession() as session:
        async with session.get(url) as response:
            return await response.json()
```

Similar mechanic.

### Schedulers

**Cooperative.** Tasks yield explicitly (at await points). Simple. Vulnerable to one task hogging CPU. Used by Node, asyncio.

**Cooperative with preemption.** Like cooperative, but the runtime can preempt tasks at "safe points" (function calls, loop iterations). Goroutines work this way.

**Work-stealing.** Each scheduler thread has a local queue. When empty, steals from another. Excellent locality and load balance. Used by Go, tokio, Java's ForkJoinPool.

**Single-threaded.** One thread runs all tasks. Simple. Limited to one CPU's worth of work. Node.js, asyncio default.

**Multi-threaded.** Many threads each run tasks. Provides parallelism. Tokio's multi-thread runtime, Go's default.

### Function coloring

Bob Nystrom's "What Color Is Your Function?" (2015) named this:

In some languages, you can't call an `async` function from a regular function (without bridging). The "color" of a function is part of its type. Async libraries beget async libraries; sync libraries don't compose.

Languages that have this: JavaScript (mostly), Python (asyncio), Rust, C#.

Languages that don't: Go (goroutines), Erlang (processes), Java with virtual threads (any blocking call works).

The cost of function coloring: "I'd just like to add a bit of async here" is harder than it looks. Functions and their callers and their callers must all become async, recursively.

The benefit: explicit yield points enable certain optimizations and reasoning patterns. Rust's borrow checker, for example, depends on async being explicit.

### The runtime's role

A runtime (tokio, asyncio, Node's libuv, Go's runtime) handles:
- **Task scheduling**: which task runs next.
- **I/O multiplexing**: epoll/kqueue/IOCP integration.
- **Timer management**: setTimeout-equivalents.
- **Synchronization primitives**: async-aware mutexes, channels.
- **Thread pool**: for tasks that must block (file I/O, DNS, etc.).

The runtime is significant code. tokio is tens of thousands of LoC. Node's libuv similarly. Go's runtime is integral to the language.

### Channels and message passing

Common in green-thread / coroutine systems:

**Go:**
```go
ch := make(chan int)
go func() { ch <- 42 }()
value := <-ch
```

Channels couple naturally to goroutines: a goroutine's natural failure mode is "blocked on a channel," cleanly.

**Rust tokio:**
```rust
let (tx, mut rx) = tokio::sync::mpsc::channel(100);
tokio::spawn(async move { tx.send(42).await.unwrap(); });
let value = rx.recv().await.unwrap();
```

Same pattern; explicit awaits.

**Erlang:**
```erlang
Pid ! {message, 42}
receive
    {message, Value} -> ...
end
```

Channels are *the* coordination primitive in modern concurrent systems. Locks coordinate access to shared memory; channels coordinate by passing data.

### Structured concurrency

A modern movement (Kotlin, Swift, Python's TaskGroup, Rust's various proposals): concurrent tasks should have clear lifetime boundaries.

Anti-pattern: spawn task; forget about it; task crashes silently or leaks.

Pattern:
```python
async with TaskGroup() as tg:
    tg.create_task(work_a())
    tg.create_task(work_b())
# Both tasks complete (or all are cancelled if one fails)
```

Tasks created in the group are joined or cancelled when the block exits. Errors propagate. Lifetimes are explicit.

This is concurrency's structured-programming moment — equivalent to going from `goto` to scoped blocks. Adopted gradually across languages.

### Cancellation

Coroutines/tasks should be cancellable. Patterns:
- **Token-based**: tasks check a cancellation token periodically.
- **Exception-based**: cancellation throws a specific exception.
- **Drop-based**: in Rust, dropping a future cancels it.

Subtle correctness issues: cancellation in the middle of an operation may leave shared state inconsistent. Resource cleanup must handle cancellation. This is non-trivial.

---

## Real Engineering Analogies

**The restaurant kitchen with preset stations.**
A single chef (one OS thread) prepares dishes. Each dish has known steps; the chef interleaves them — start the soup boiling (await); chop salad while soup boils; check the soup; plate the salad. Many dishes "in flight" simultaneously, but only one chef.

That's a single-threaded async runtime. Many concurrent operations; one execution context. The chef yields between tasks; never two operations physically simultaneous.

A multi-chef kitchen (multi-threaded runtime) parallelizes the chef work. Tasks fluidly redistribute (work stealing). Some tasks take longer; the busy chef can hand off some to the idle one.

**The air traffic controller.**
One controller manages many flights. They're all active simultaneously (in the air, on the ground, taxiing). The controller switches attention rapidly: "United 247, climb to 5000." Task: handled. "Delta 612, hold short of runway 27." Task: handled. The controller is single-threaded; the flights are many.

That's a coroutine system. The flights are tasks; the controller is the scheduler; the radios are the I/O channels.

---

## Production Engineering Perspective

What goes wrong:

- **The blocking call in async code.** A synchronous HTTP library used inside an async function. The whole runtime stalls during that call. Discovered as "performance is terrible under load." Fix: async-native libraries.
- **The CPU-bound coroutine.** A heavy regex or computation in a coroutine. Other coroutines on the same thread starve. Move to worker thread or external service.
- **The unbounded task spawning.** Application spawns a goroutine/task per request without limit. Memory grows; eventually OOMs. Fix: bounded concurrency limits.
- **The leaked task.** A task is spawned but never joined or cancelled. Resources held forever. Subtle leak. Fix: structured concurrency.
- **The deadlock via channel.** Two goroutines each waiting on the other's channel. Both stuck. Mitigation: timeouts on channel sends/receives; structured patterns.
- **The function-coloring spread.** "We need to make this async." Three months later, half the codebase is `async` because changes propagated up the call stack.
- **The async-runtime in test environments.** Tests don't use the same runtime as production. Subtle behavior differences. Fix: same runtime in test and prod.

The senior engineer's habits:
- **Avoid blocking calls** in async contexts.
- **Bound concurrency** (semaphores, channels, queues).
- **Use structured concurrency** patterns.
- **Profile under load** to catch coroutine starvation.
- **Explicit cancellation** with cleanup.
- **Test with realistic concurrency**, not just unit tests.

---

## Failure Scenarios

**Scenario 1 — The blocking-call surprise.**
Service uses asyncio. New code includes synchronous DB call (forgot to use async driver). Under load, every request blocks on that DB call; other requests pile up. Performance equivalent to single-threaded. Fix: async-native DB driver.

**Scenario 2 — The goroutine leak.**
A goroutine waits on a channel that's never closed. Function returns; goroutine remains. Memory grows by one goroutine per request. After a million requests: 2 GB of goroutine stacks. OOM. Fix: structured concurrency; channel close on request completion.

**Scenario 3 — The CPU-bound starvation.**
A coroutine performs ML inference (CPU-heavy). All other coroutines on its thread wait. Latency p99 unacceptable. Fix: dedicated thread pool for CPU work; coroutines for I/O.

**Scenario 4 — The cooperative-scheduling deadlock.**
Two coroutines each await on a future the other will resolve. Neither yields. The runtime can't preempt cooperative tasks. Hung. Discoverable only at runtime; fix is design-level.

**Scenario 5 — The task that outlived its parent.**
Background task spawned for "fire-and-forget" reporting. Parent function returns; task continues; tries to access closed resources; crashes. Caller doesn't know because they're not awaiting. Fix: structured concurrency forces lifetime alignment.

---

## Performance Perspective

- **OS thread context switch**: ~1-10μs.
- **Coroutine context switch**: tens of nanoseconds.
- **Channel send/receive**: nanoseconds.
- **Async/await overhead**: typically zero-cost in Rust; small in JS/Python.
- **Per-task memory**: a few hundred bytes for coroutines; a few KB for goroutines/virtual threads; ~MB for OS threads.

---

## Scaling Perspective

- **Concurrent task count**: limited by memory. With coroutines, easily millions; with OS threads, low tens of thousands.
- **Multi-core**: depends on runtime. Single-threaded runtimes (Node, asyncio) scale via multiple processes.
- **Distributed**: green threads can transparently extend across nodes (Erlang); coroutines mostly don't.

---

## Cross-Domain Connections

- **Parallelism vs concurrency**: coroutines/green threads provide concurrency; parallelism depends on the runtime's threading. (See [parallelism-vs-concurrency.md](./parallelism-vs-concurrency.md).)
- **Event loop**: Node's event loop is the single-threaded coroutine runtime model. (See [event-loop-and-async-runtime.md](../js-runtime/event-loop-and-async-runtime.md).)
- **Actor model**: Erlang processes are green threads with mailboxes. (See [actor-model-and-message-passing.md](./actor-model-and-message-passing.md).)
- **Backpressure**: bounded channels are the natural backpressure primitive in coroutine systems. (See [backpressure-and-queues.md](./backpressure-and-queues.md).)
- **Locks**: async runtimes need async-aware locks; standard mutexes block threads, not coroutines. (See [locks-mutexes-and-lock-free.md](./locks-mutexes-and-lock-free.md).)

The unifying observation: **concurrent units have moved from kernel-managed (heavy, expensive) to user-space (lightweight, scalable). Each layer of abstraction is cheaper than the last; the trade-off is shifting some scheduling responsibility to the application.**

---

## Real Production Scenarios

- **Erlang at WhatsApp**: 2 million connections per server documented. Process-per-connection scale.
- **Go's adoption at Uber, Cloudflare, Discord**: case studies of replacing thread-per-connection with goroutines.
- **Java Project Loom**: documented benchmarks of virtual threads vs platform threads in real-world workloads.
- **Rust tokio at Discord, Cloudflare**: production deployments; performance analyses.
- **Python asyncio's mainstream adoption**: now standard for I/O-heavy Python services.
- **Microsoft's "what color is your function" influence**: the essay shaped language design discussions for years.

---

## What Junior Engineers Usually Miss

- That **OS threads are expensive** at scale.
- That **coroutines don't add parallelism** within a single thread.
- That **blocking calls in async code** ruin throughput.
- That **task spawning needs bounds**.
- That **structured concurrency** prevents lifetime bugs.
- That **function coloring** is a real cost.
- That **cancellation is subtle**.
- That **work-stealing** is the modern scheduler pattern.

---

## What Senior Engineers Instinctively Notice

- They **avoid blocking calls** in async contexts.
- They **bound concurrency** with channels/semaphores.
- They **prefer structured concurrency**.
- They **distinguish I/O-bound from CPU-bound work**.
- They **understand their runtime's scheduler**.
- They **handle cancellation** explicitly.
- They **measure under realistic load**.
- They **know when to use threads vs coroutines** for each task.

---

## Interview Perspective

What gets tested:

1. **"Coroutine vs OS thread?"** Tests fundamental literacy.
2. **"What's function coloring?"** Async/sync split; recursive propagation.
3. **"How does Go's scheduler work?"** Work-stealing M:N.
4. **"Virtual threads in Java?"** Cheap user-space threads multiplexed onto OS threads.
5. **"What's structured concurrency?"** Lifetime-bound task spawning.
6. **"Why is blocking in async bad?"** Stalls the runtime; other coroutines wait.
7. **"How do you handle cancellation?"** Tokens, exceptions, dropping futures.

Common traps:
- Believing async = parallelism.
- Spawning unbounded tasks.
- Mixing blocking and async without care.

---

## 20% Knowledge Giving 80% Understanding

1. **Coroutines/green threads are cheaper than OS threads.**
2. **M:N scheduling** multiplexes user tasks onto OS threads.
3. **Cooperative scheduling** requires yielding (await).
4. **Blocking calls in async code** stall the runtime.
5. **Function coloring** is a language design cost.
6. **Work-stealing** balances load across threads.
7. **Structured concurrency** for lifetime safety.
8. **Channels** for coordination by message passing.
9. **Cancellation** must be handled explicitly.
10. **CPU work belongs on dedicated threads**, not coroutines.

---

## Final Mental Model

> **Coroutines, green threads, and async runtimes are the response to a hardware reality (one OS thread is heavy) and an application reality (most concurrent work is waiting). Modern concurrency is layered: cheap units in user space, multiplexed onto OS threads, scheduled by the runtime. Master the layers, and you can express million-fold concurrency in code that looks linear.**

The senior engineer working in Go, Rust, Kotlin, modern Java, or asyncio Python carries a mental model of where their tasks run and what their cost is. They reach for goroutines/tasks for I/O-bound work, threads or workers for CPU-bound. They bound concurrency. They use structured patterns. They avoid the blocking-call-in-async footgun.

The systems that handle massive concurrency aren't necessarily the ones with the most cores. They're the ones whose abstractions match the work — cheap concurrent units for waiting, parallel threads for computing, channels for coordination. The cost is some new vocabulary; the benefit is software that can handle scales single-threaded blocking code never could.

That's coroutines. That's green threads. That's the modern concurrency stack — the layered system that turned C10K into a solved problem and made C10M routine.
