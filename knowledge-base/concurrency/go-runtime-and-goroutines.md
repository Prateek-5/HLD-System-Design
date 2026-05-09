# Go Runtime & Goroutines

> *"Go's bet on goroutines was 'we'll make threads cheap, give you channels for communication, and let you write blocking code that scales.' The bet won. Goroutines are now the reference design for cheap concurrent units, and the Go scheduler is the most-deployed work-stealing runtime in production. Understanding it is understanding why Go's concurrency story works in ways other languages can't easily replicate."*

---

## Topic Overview

The Go runtime is what makes goroutines work. A goroutine is a lightweight execution context — much cheaper than an OS thread, but with similar programming semantics. The Go scheduler multiplexes millions of goroutines onto a small number of OS threads, with work-stealing for load balance and integrated I/O for non-blocking semantics that look blocking.

Channels are the coordination primitive. Built into the language; integrated with the scheduler; "share by communicating" is the slogan. Combined with goroutines, they form a programming model that handles many concurrency patterns elegantly.

This is the topic that explains why "rewriting in Go" has been a recurring engineering pattern. The language's concurrency model is ergonomically superior to threads-with-locks for many workloads. Understanding the runtime — the scheduler, the GC, the channels, the system call handling — is what separates "I write Go" from "I understand why Go is fast at concurrency."

---

## Intuition Before Definitions

Imagine a kitchen with three chefs and unlimited orders.

The chefs handle orders one at a time, but multiple orders can be in progress (one in the oven, one resting, one being chopped). The kitchen has a manager who decides which chef should focus on what next.

The chefs are OS threads. The orders are goroutines. The manager is the Go scheduler.

When an order is "blocked" (something baking), the chef doesn't wait — they take another order. The scheduler tracks who's blocked on what. When the bake finishes, the scheduler picks a free chef to plate the dish.

Channels are the kitchen's communication system: "Order #5 needs the sauce from station 2." Pass the message; whoever's free responds. No yelling across the kitchen; no stepping on each other; clear handoffs.

That's Go's runtime. Many concurrent activities; few execution threads; a smart scheduler; explicit communication. The result: code that *looks* like simple sequential code per goroutine, but runs concurrently with thousands of others.

---

## Historical Evolution

**Era 1 — Go's design (2009).**
Pike, Griesemer, Thompson at Google. Goroutines and channels as first-class. Inspired by CSP (Tony Hoare).

**Era 2 — Early scheduler.**
~2009-2014. M:N scheduler; work-stealing. Reasonable but had limitations.

**Era 3 — Preemption (1.14, 2020).**
Pre-1.14: cooperative scheduling could be hijacked by long-running goroutines. 1.14 added asynchronous preemption.

**Era 4 — Scalability improvements.**
Each release: scheduler tuning, better lock contention handling, network poller optimizations.

**Era 5 — Modern Go.**
2024+. Goroutines scale to millions per process; GC pauses sub-millisecond; production at huge scale (Cloudflare, Discord, Uber).

The pattern: Go's runtime has steadily evolved. The fundamental design stays; the implementation has matured.

---

## Core Mental Models

**1. Goroutines are M:N multiplexed onto OS threads.**
Many goroutines (M) share a fewer OS threads (N). Scheduler handles assignment.

**2. Channels coordinate by communication.**
Don't share memory; pass data via channels. Channels integrate with the scheduler.

**3. Blocking I/O looks blocking but doesn't block the thread.**
Goroutine blocks; OS thread takes another goroutine; underlying I/O is non-blocking.

**4. Goroutines are cheap.**
~2KB initial stack (grows as needed); microsecond-scale switches.

**5. The scheduler uses work-stealing.**
Each P (processor context) has a local queue. Idle Ps steal from busy ones.

---

## Deep Technical Explanation

### G, M, P — the Go scheduler

The runtime has three primary types:
- **G (Goroutine)**: a unit of work; user code.
- **M (Machine)**: an OS thread.
- **P (Processor)**: a logical processor; runs G's on M's.

Number of P's: `GOMAXPROCS` (default = number of CPUs).
Number of M's: dynamic; created as needed.

A G runs on an M, scheduled by a P. When a G blocks (system call), the M can detach from the P; another M picks up the P and continues running other G's.

This is the genius: blocking I/O doesn't block the thread; the thread switches to another goroutine.

### Goroutine stacks

Initial stack: ~2KB (was 8KB; reduced over versions).

The stack grows as needed:
- Function entry checks if there's room.
- If not: allocate a larger stack; copy contents; continue.

Shrinking also possible.

Compare to OS threads: 1-8 MB stacks. Goroutines are 1000-4000× cheaper memory-wise.

### Channels

Built-in primitive:
```go
ch := make(chan int, 10)  // buffered, capacity 10
ch <- 42                   // send
v := <-ch                  // receive
close(ch)                  // close
```

Implementation:
- A channel has a buffer (if buffered) and queues of waiting senders/receivers.
- Send when buffer has space: just enqueue.
- Send when full: block; wake when space available.
- Receive when buffer has data: dequeue.
- Receive when empty: block; wake when data available.

Channels integrate with the scheduler: blocked goroutines are descheduled; the M picks up another goroutine.

### Select statement

Wait on multiple channel operations:

```go
select {
case v := <-ch1:
    handle(v)
case ch2 <- value:
    sent()
case <-time.After(1 * time.Second):
    timeout()
}
```

The runtime picks one ready operation (random among ready). If none ready and no `default` clause, blocks until one is.

`select` with a `default` clause is non-blocking.

### System calls

When a goroutine makes a blocking system call:
1. The M holding it detaches from the P.
2. Another M picks up the P; continues running other G's.
3. The blocked M waits for the syscall.
4. After syscall returns, the M tries to re-attach to a P; if all P's are busy, the M parks.

This is how Go achieves "blocking-looking code with non-blocking efficiency."

### Network poller

Network I/O uses a separate mechanism:
- Goroutine calls `net.Conn.Read`.
- Go runtime registers interest with the network poller (epoll/kqueue/IOCP).
- Goroutine descheduled.
- When socket is ready, poller wakes the goroutine.
- M continues with other work in the meantime.

A single thread handles network polling for all goroutines.

### Preemption

Pre-1.14: cooperative. A goroutine running a tight loop could prevent others from running.

```go
for {} // pre-1.14: hangs everything
```

1.14+: asynchronous preemption. Runtime sends signal to long-running goroutines; preempts them at safe points.

Preemption works at function call boundaries (compiler inserts safe points). Tight loops without function calls were the issue; modern Go handles them.

### Work-stealing scheduler

Each P has a local run queue. When empty, it steals from another P's queue.

Steal rules:
- Steal from random P.
- Steal half of victim's queue.
- If can't steal: poll global queue; check network poller; park.

Work-stealing balances load without central coordination. Standard pattern across modern runtimes (also Tokio, ForkJoinPool).

### Garbage collection

Concurrent mark-sweep. (See [garbage-collection-and-memory-management.md](../js-runtime/garbage-collection-and-memory-management.md).)

Goals: low pauses; <1ms typical.

Trade-offs:
- Concurrent: GC runs alongside goroutines.
- Write barriers maintained.
- More CPU for GC; less for application.

`GOGC` controls heap growth target (default 100% — collect when heap doubles).

### Goroutine leaks

A leaked goroutine stays alive forever, holding memory. Common causes:
- Goroutine reading from a channel that's never closed.
- Goroutine waiting on a sync primitive that's never signaled.
- Goroutine holding a reference to a large structure.

Detection: pprof goroutine profile. Number of goroutines should be roughly stable; growing = leak.

### Goroutines and panics

Unrecovered panic in a goroutine crashes the whole program.

Pattern: `recover()` in deferred function within the goroutine.

```go
go func() {
    defer func() {
        if r := recover(); r != nil {
            log.Printf("goroutine panic: %v", r)
        }
    }()
    doWork()
}()
```

Without recover, one panic ends the process. Important for fault tolerance.

### Context

`context.Context` is Go's mechanism for cancellation, deadlines, and request-scoped data:

```go
ctx, cancel := context.WithTimeout(ctx, 5*time.Second)
defer cancel()
result, err := doSomething(ctx)
```

Functions accept a `Context`; check `ctx.Done()` for cancellation. Standard pattern; ubiquitous in Go ecosystem.

### Common patterns

**Worker pool:**
```go
work := make(chan Job, 100)
for i := 0; i < 10; i++ {
    go worker(work)
}
for _, job := range jobs {
    work <- job
}
close(work)
```

**Fan-out/fan-in:**
```go
results := make(chan Result, len(items))
for _, item := range items {
    go func(item Item) {
        results <- process(item)
    }(item)
}
for range items {
    handle(<-results)
}
```

**Pipeline:**
```go
out := stage3(stage2(stage1(input)))
```

Each stage is a goroutine reading from its input channel and writing to its output.

---

## Real Engineering Analogies

**The kitchen brigade.**
Head chef directs; line cooks specialize; runners deliver; communication via order tickets. Many concurrent activities; few people; clear roles. Goroutines and channels are the engineered version.

**The factory line with multi-skilled workers.**
Workers move between stations as demand varies. The supervisor (scheduler) reassigns based on what's busy. No worker idle while others are overloaded. That's work-stealing.

---

## Production Engineering Perspective

What goes wrong:

- **The goroutine leak.** Every request spawns a goroutine that never exits. Memory grows. Restart needed eventually. Fix: bounded lifetimes; context cancellation.
- **The channel deadlock.** Goroutine A waits to send; B never receives. Both stuck. Detection: deadlock detector (only for whole-program deadlocks).
- **The unbounded goroutine spawn.** Each request spawns new goroutine; no limit. Many requests = many goroutines = OOM. Mitigation: worker pools.
- **The blocking-call blocker.** Cgo or syscall doesn't release P efficiently. Throughput drops. Mitigation: avoid long syscalls; use Go-native equivalents.
- **The race condition.** Shared map without mutex. Race detector catches in tests. Fix: mutex or sync.Map or channel.
- **The GC pause.** Heavy allocation; GC pauses appear in latency. Reduce allocations.

The senior Go engineer's habits:
- **Run race detector** in CI.
- **Bound goroutine concurrency** (worker pools).
- **Pass `context.Context`** through async paths.
- **Use channels for coordination**; mutexes for shared state.
- **Profile** with pprof.
- **Watch goroutine count** as a metric.

---

## Failure Scenarios

**Scenario 1 — The goroutine leak.**
HTTP handler launches goroutine; never returns. After million requests: million goroutines. Memory exhausted. Fix: bounded lifetimes via context.

**Scenario 2 — The select-default trap.**
`select { case <-ch: ... default: ... }` — if `ch` not ready, default runs immediately. Code intended to block; instead burns CPU in a busy loop. Mitigation: remove default if blocking desired.

**Scenario 3 — The channel deadlock.**
Sender and receiver both waiting on each other. Whole program hangs. Detected by Go's runtime; panic. Fix: redesign coordination.

**Scenario 4 — The CPU pegging via GOMAXPROCS.**
Container with 1 CPU; Go thinks it has 32 (host CPUs). GOMAXPROCS=32. Excessive context switching. Fix: set GOMAXPROCS to actual CPU.

**Scenario 5 — The ringless GC.**
High allocation rate; GC overhead 30%. Reduced via pooling; CPU recovered.

---

## Performance Perspective

- **Goroutine creation**: microseconds.
- **Goroutine switch**: nanoseconds (cooperative).
- **Channel ops**: 50-200ns typical.
- **GC pause**: <1ms typical.
- **Network I/O**: efficient via poller.

---

## Scaling Perspective

- **Single process**: millions of goroutines.
- **Multi-core**: GOMAXPROCS scales to CPUs.
- **Distributed**: each Go process is its own runtime.
- **Cloud**: container-aware GOMAXPROCS (modern Go).

---

## Cross-Domain Connections

- **Coroutines**: goroutines are coroutines. (See [coroutines-and-green-threads.md](./coroutines-and-green-threads.md).)
- **Backpressure**: bounded channels are backpressure. (See [backpressure-and-queues.md](./backpressure-and-queues.md).)
- **Locks**: Go's sync.Mutex; channels often preferred. (See [locks-mutexes-and-lock-free.md](./locks-mutexes-and-lock-free.md).)
- **Actor model**: goroutines + channels resemble actors. (See [actor-model-and-message-passing.md](./actor-model-and-message-passing.md).)
- **GC**: Go's concurrent mark-sweep. (See [garbage-collection-and-memory-management.md](../js-runtime/garbage-collection-and-memory-management.md).)

The unifying observation: **Go's runtime is what makes Go's concurrency story work. Cheap goroutines, integrated channels, M:N scheduling — these are the implementation that turns CSP-inspired ideas into production-scale engineering.**

---

## Real Production Scenarios

- **Discord's voice servers**: documented Go usage.
- **Cloudflare's Go services**: extensive public engineering.
- **Uber's Go adoption**: documented case studies.
- **Kubernetes**: largely written in Go; massive goroutine usage.

---

## What Junior Engineers Usually Miss

- That **goroutines need bounding** to avoid leaks.
- That **GOMAXPROCS** matters in containers.
- That **channels integrate with scheduler**.
- That **context propagation** is mandatory.
- That **race detector** is essential.
- That **panics in goroutines crash the process**.

---

## What Senior Engineers Instinctively Notice

- They **bound goroutine concurrency**.
- They **propagate context**.
- They **use channels for coordination**.
- They **run race detector** in CI.
- They **profile with pprof**.
- They **set GOMAXPROCS** for container awareness.

---

## Interview Perspective

What gets tested:

1. **"What's a goroutine?"** Lightweight execution unit.
2. **"Channels?"** Coordination via message passing.
3. **"GMP scheduler?"** G's run on M's via P's.
4. **"How does Go handle blocking I/O?"** Goroutine descheduled; thread takes another.
5. **"What's work-stealing?"** Idle P steals from busy.
6. **"How do you cancel work?"** context.Context.

Common traps:
- Believing goroutines are free.
- Not knowing about GOMAXPROCS in containers.

---

## 20% Knowledge Giving 80% Understanding

1. **Goroutines = M:N** multiplexed onto threads.
2. **GMP scheduler** with work-stealing.
3. **Channels coordinate** by communication.
4. **Blocking I/O via network poller**.
5. **Context propagation** for cancellation.
6. **Bound concurrency** to prevent leaks.
7. **Race detector** in CI.
8. **GC sub-ms** pauses.
9. **GOMAXPROCS** = CPU count.
10. **Recover panics** in goroutines.

---

## Final Mental Model

> **Go's runtime is what made "cheap concurrent units" production-ready at scale. The combination of goroutines, channels, M:N scheduling, and integrated I/O is engineered for the workloads where threads-and-locks fail. The systems that adopted Go found patterns of concurrency that were awkward elsewhere natural in Go.**

The senior Go engineer leans on the runtime. Goroutines for parallelism; channels for coordination; context for cancellation. They know the scheduler's quirks. They watch for leaks. They use the race detector. The runtime handles the complexity; they focus on the program.

That's Go's runtime. That's goroutines. That's the most-deployed work-stealing concurrent runtime in production — and the design that influenced async runtimes everywhere.
