# Async Rust & the Borrow Checker

> *"Async Rust is what happens when a language built around 'no garbage collector, no data races, no surprises' meets cooperative concurrency. The result is the most powerful async runtime any language has ever shipped — and the steepest learning curve. The borrow checker doesn't sleep when you start writing futures; if anything, it gets sharper."*

---

## Topic Overview

Async Rust is a different beast from async in other languages. Where JavaScript's `async/await` is a small layer over Promises, where Python's asyncio is a runtime with sometimes-surprising semantics, Rust's async is *deeply integrated with the language's ownership system*. The borrow checker, which already enforces memory safety in synchronous Rust, has to reason about futures that pause and resume, that hold references across `await` points, that may be polled from any thread.

The result: code that, when it compiles, has guarantees no other async system provides. No data races. No garbage collection. Bounded memory per task. Performance close to hand-written state machines. The cost: a learning curve that even experienced Rust developers describe as "the second compile-time war." And `Pin`, `Send`, `Sync`, `'static`, `&mut self` across `await` — vocabulary that takes weeks to internalize.

This is the topic where the academic ambition of Rust's safety guarantees meets the practical reality of writing high-performance services. Tokio (the dominant runtime) powers production systems at Discord, Cloudflare, AWS. Understanding async Rust is understanding what's possible when you refuse to compromise on memory safety, garbage collection, or performance — and accept the complexity that comes with it.

---

## Intuition Before Definitions

Imagine writing instructions for someone to do many tasks, where they can pause any task at any moment and resume later.

In JavaScript, this is fine: each task's local variables live in a closure; pausing just stores a reference. In Python, similarly: the interpreter manages state. Both languages have garbage collectors that ensure references stay valid.

In Rust, there's no garbage collector. Every reference must be valid. Every borrow must be tracked. When a task pauses (at `await`), and resumes later — possibly on a different thread — the compiler must prove that everything the task references is still valid, still safe to access, still not concurrently mutated.

This is hard. It's why async Rust looks weird. `Pin`, `Send`, `Sync` exist because the compiler can't prove your code is safe under arbitrary pause-and-resume without your help. The borrow checker is more demanding because the lifetimes are more intricate.

The good news: when you get it right, the result is beautifully predictable. No hidden mutexes. No GC pauses. No "wait, did this thread see the latest value?" Rust's async is concurrency without any of the surprises that plague other languages — at the cost of you spending more time talking to the compiler.

---

## Historical Evolution

**Era 1 — Pre-async Rust.**
Pre-2018. Rust had concurrency primitives (threads, channels) but no async. People used `mio` (low-level I/O) or just blocking with thread pools.

**Era 2 — Futures 0.1.**
~2017. First futures library; combinator-heavy; ergonomically painful.

**Era 3 — async/await stabilization (2019).**
Rust 1.39. The keywords stabilized. Tokio rewritten for new model. Cleaner code; still steep learning curve.

**Era 4 — Tokio dominance.**
2019-2022. Tokio becomes the de facto runtime. Built ecosystem (hyper, axum, tonic). Async ecosystem matures.

**Era 5 — Async traits.**
2023+. `async fn in trait` stabilized; `Pin` debugging eased; ecosystem ergonomics improving but still complex.

**Era 6 — Production maturity.**
2023+. Cloudflare, Discord, AWS Lambda use async Rust at scale. Performance and reliability proven.

The pattern: each generation reduced friction. The model is sound; the ergonomics keep improving.

---

## Core Mental Models

**1. A Future is a state machine the compiler builds.**
`async fn` becomes a state machine implementing the `Future` trait. Each `await` is a state transition. The compiler does this; you write the linear-looking code.

**2. Futures are lazy.**
Calling an `async fn` doesn't run anything. It returns a future. The future runs when *polled* — typically by a runtime.

**3. Polls happen on threads.**
A future may be polled from any thread the runtime chooses. Across an `await`, the future might move threads. Anything held across an `await` must be `Send` (sendable across threads).

**4. The borrow checker reaches into futures.**
References held across `await` must outlive the future. Mutable references across await are particularly tricky. `&mut self` async methods have special restrictions.

**5. `Pin` is about not moving futures.**
Once a future is being polled, it can't move in memory (because internal references would be invalidated). `Pin` is the type that enforces this.

---

## Deep Technical Explanation

### Futures as state machines

```rust
async fn fetch_user(id: u64) -> Result<User, Error> {
    let response = http_get(&format!("/users/{id}")).await?;
    let user = response.json::<User>().await?;
    Ok(user)
}
```

The compiler transforms this into roughly:

```rust
enum FetchUserState {
    Initial { id: u64 },
    AwaitingResponse { future: HttpGetFuture },
    AwaitingJson { future: JsonFuture },
    Done,
}
```

Each state is a snapshot of the function's progress. `poll()` advances the state machine. When the inner future is `Pending`, this future returns `Pending` too. When the inner is `Ready`, advance to the next state.

This is what `async/await` means in Rust. Not magic — explicit, compile-time-generated state machines.

### The Future trait

```rust
trait Future {
    type Output;
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output>;
}
```

`Poll<T>` is `Pending | Ready(T)`. The future is asked to make progress; it either completes or returns Pending and arranges to be re-polled when ready.

`Context` carries a `Waker` — a handle the future uses to signal "wake me up when there's progress" (e.g., when the underlying socket becomes readable).

### Tokio runtime

A runtime executes futures:
- Maintains a pool of worker threads.
- Schedules tasks (top-level futures).
- Integrates with epoll/kqueue/IOCP for I/O readiness.
- Provides timers, channels, mutexes that integrate with the async model.

```rust
#[tokio::main]
async fn main() {
    let result = fetch_user(42).await.unwrap();
    println!("{:?}", result);
}
```

The `#[tokio::main]` macro spins up a runtime; `main` becomes a top-level task; futures inside it run on the runtime's threads.

Tokio defaults to multi-threaded; current_thread runtime is also available for single-threaded scenarios.

### Send and Sync

To run a future on a multi-threaded runtime, the future must be `Send` (sendable across threads).

`Send` is automatic for types built from `Send` parts. `Rc` is not `Send`; `Arc` is. `RefCell` is not `Sync`; `Mutex` is.

A future that holds an `Rc` across an `await` is *not* `Send`, and can't run on tokio's multi-threaded runtime. The error message is famous for being incomprehensible at first; with practice, recognizable.

```rust
async fn bad() {
    let rc = Rc::new(42);
    other_async_fn().await;  // Rc held across await
    println!("{}", rc);
}
// Error: future is not `Send`
```

The fix: don't hold non-Send types across awaits. Use `Arc` if shared ownership needed; clone before await; or restructure to drop the borrow before awaiting.

### The borrow checker across await

```rust
async fn process(data: &Vec<u8>) {
    something().await;
    println!("{:?}", data);  // borrow held across await
}
```

The reference `data` must outlive the future. The compiler enforces this; if the caller drops the data while the future is suspended, that's a use-after-free — Rust catches it.

This is fine for shared references that outlive the function. It's painful for `&mut`:

```rust
async fn process(data: &mut Vec<u8>) {
    data.push(1);
    something().await;  // mutable borrow held across await
    data.push(2);
}
```

Subtle issues:
- The `&mut` borrow lasts for the whole function.
- During await, no one else can read or modify `data`.
- This is correct (Rust prevents data races) but limits patterns.

Workarounds: scope the borrow narrower; clone; use interior mutability with `Mutex`.

### `Pin` and `Unpin`

A future may have *self-referential* fields — internal pointers that point at other parts of itself. Once polled (and possibly moved internal pointers established), the future cannot move in memory; doing so would invalidate the pointers.

`Pin<&mut T>` is a wrapper that prevents moving the underlying value. `poll` takes `Pin<&mut Self>`.

Most futures are `Unpin` (safe to move). The auto-generated state machines from `async fn` are sometimes `!Unpin` because they may have self-references.

In day-to-day code, `Pin` mostly stays out of your way. When you write your own `Future` impl, `Pin` becomes essential vocabulary.

### Async traits

Pre-2023, async functions in traits required workarounds (`async-trait` crate). Stabilized in 2023:

```rust
trait UserStore {
    async fn get_user(&self, id: u64) -> Result<User, Error>;
}
```

Limitations remain (return-position async, dyn compatibility); ecosystem is catching up.

### Tokio primitives

- **`tokio::spawn`**: spawn a task on the runtime.
- **`tokio::select!`**: race multiple futures.
- **`tokio::join!`**: await multiple futures concurrently.
- **`tokio::sync::Mutex`**: async-aware mutex (yields instead of blocks).
- **`tokio::sync::mpsc`, `oneshot`, `broadcast`**: channels.
- **`tokio::time::sleep`**: async timer.
- **`tokio::fs`, `tokio::net`**: async file and network I/O.

Each integrates with the runtime's scheduler. Using std's blocking variants in async code blocks the runtime — a common bug.

### The "function color" problem in Rust

Like other async languages, Rust has function coloring:
- `async fn` and regular `fn` don't compose freely.
- An `async fn` can call a regular `fn`.
- A regular `fn` can call `async fn` only by spawning it on a runtime or blocking.

This propagates through call chains. Once a function is async, callers tend to become async too.

The `block_on` escape hatch lets you call async from sync, but at the cost of blocking the current thread (defeating async's purpose unless you're at a top-level entry point).

### Common mistakes

- **Holding `MutexGuard` across await.** Standard mutex is sync; holding it across await blocks the thread. Use `tokio::sync::Mutex`.
- **Calling `std::thread::sleep`.** Blocks the thread. Use `tokio::time::sleep`.
- **Using `std::fs` for files.** Blocking I/O. Use `tokio::fs`.
- **Holding `Rc` across await.** Not `Send`. Use `Arc`.
- **Spawning tasks that capture mutable references.** Lifetime issues. Use `Arc<Mutex<T>>` for shared state or message passing.
- **Forgetting `#[tokio::main]`.** Code looks right but doesn't run.

### Performance

Async Rust is fast:
- Zero-cost abstractions: state machines are roughly as efficient as hand-written.
- No GC: predictable latency.
- M:N scheduling: multiple OS threads multiplexing many tasks.
- Cache-friendly: small, allocated tasks.

Cloudflare, Discord report production systems handling millions of concurrent connections per node. The performance argument for async Rust is real.

The cost: compile times (futures have complex types); learning curve; ecosystem requires async versions of everything.

---

## Real Engineering Analogies

**The Swiss watch with safety inspectors.**
A complex mechanical watch (your code) has many gears (tasks). Inspectors (the borrow checker) verify, before the watch runs, that no gear can ever be in a position that breaks another. Once it runs, you have certainty: no jamming, no crashes. The cost: many inspections; some require you to redesign gears the inspectors don't approve.

**The hospital surgery scheduler.**
An OR scheduler (runtime) assigns surgeries (tasks) to surgeons (threads). Surgeries can pause for tests (await); the surgeon can take another surgery during the pause. But the scheduler must verify: this surgery's instruments must be safely transferable across surgeons; the patient's records must remain accessible. Without this verification, chaos.

---

## Production Engineering Perspective

What goes wrong:

- **The blocking call in async code.** Engineer uses `std::sync::Mutex` instead of `tokio::sync::Mutex`. Holding it across await blocks the worker thread; other tasks queue. Performance plummets. Debugging requires understanding of "which mutex is which."
- **The non-Send error from hell.** Compiler error spans pages. Engineer can't tell which line is the problem. Investigation: an `Rc` was held across an `await` deep in some library code. Fix: replace with `Arc`.
- **The lifetime tangle.** Async function holds a borrowed reference; spawning it as a task fails because the borrow doesn't outlive the task. Mitigation: own the data; use `Arc`; restructure.
- **The runaway compile time.** A complex async function generates a 50KB type signature. Compile time degrades. Mitigation: erase types with `Box<dyn Future>`; restructure.
- **The runtime confusion.** Mixing tokio and async-std accidentally; subtle bugs. Mitigation: pick one runtime; stick.
- **The cancellation surprise.** Future dropped mid-execution; no cleanup. Resources leaked. Mitigation: explicit cleanup; structured concurrency patterns.

The senior async Rust engineer's habits:
- **Use tokio's primitives** (mutex, sleep, fs).
- **Avoid blocking calls** in async paths.
- **Prefer `Arc` over `Rc`** in async code.
- **Structure code** to minimize borrows across await.
- **Read compiler errors** carefully.
- **Profile** to verify async helps the bottleneck.

---

## Failure Scenarios

**Scenario 1 — The accidental blocker.**
Engineer adds a "quick" call to a sync DB driver in an async handler. Under load, the worker thread blocks; tokio's scheduler can't reuse it. Throughput collapses. Fix: async DB driver.

**Scenario 2 — The Send-error wall.**
Compiler error: 80 lines of trait bounds explaining "future is not Send." After hours of investigation, the cause is an `Rc<HashMap>` deep in a callback. Refactor: `Arc<HashMap>`.

**Scenario 3 — The runtime collision.**
Library uses `async-std`; another uses `tokio`. Both initialize their own runtimes. Conflicts; weird hangs. Fix: choose one ecosystem.

**Scenario 4 — The cancellation leak.**
Drop future mid-execution. The future was holding a database transaction. Transaction never committed or rolled back; sits open. Mitigation: explicit cleanup in Drop; structured concurrency.

**Scenario 5 — The compile-time disaster.**
Async function with generic types and many awaits compiles for 5 minutes. CI times out. Mitigation: type erasure (`Box<dyn Future>`); refactor.

---

## Performance Perspective

- **Per-future overhead**: hundreds of bytes; nanoseconds to poll.
- **Context switch**: microseconds (cooperative; just function returns).
- **Memory**: scales with concurrent tasks; small per task.
- **Throughput**: millions of concurrent tasks on commodity hardware.
- **Latency**: predictable; no GC pauses.

---

## Scaling Perspective

- **Single process**: millions of tasks possible.
- **Multi-core**: tokio's multi-threaded runtime parallelizes.
- **Distributed**: each node is its own runtime; coordinate via network.

---

## Cross-Domain Connections

- **Coroutines / green threads**: async Rust is in this family. (See [coroutines-and-green-threads.md](./coroutines-and-green-threads.md).)
- **Locks**: async-aware mutexes differ from std mutex. (See [locks-mutexes-and-lock-free.md](./locks-mutexes-and-lock-free.md).)
- **Event loop**: tokio is a multi-threaded event loop. (See [event-loop-and-async-runtime.md](../js-runtime/event-loop-and-async-runtime.md).)
- **Backpressure**: tokio channels have bounded variants. (See [backpressure-and-queues.md](./backpressure-and-queues.md).)
- **Parallelism vs concurrency**: tokio provides both. (See [parallelism-vs-concurrency.md](./parallelism-vs-concurrency.md).)

The unifying observation: **async Rust pushes safety guarantees into concurrency. The compiler refuses to compile code with data races, dangling references, or thread-unsafe patterns. The cost is verbosity and learning curve; the benefit is bugs that other async runtimes ship to production.**

---

## Real Production Scenarios

- **Discord's Rust services**: documented migration from Go and Elixir for some services; tokio-based.
- **Cloudflare's pingora**: production Rust server platform.
- **AWS Firecracker**: VMM written in Rust with async I/O.
- **Linkerd 2.x proxy**: rewrote from Go to Rust for performance.
- **Tokio's own ecosystem**: hyper, axum, tonic — production HTTP/gRPC servers.

---

## What Junior Engineers Usually Miss

- That **async Rust requires Send/Sync awareness**.
- That **blocking calls poison async code**.
- That **`Pin` is about not moving futures**.
- That **async traits had restrictions** until recently.
- That **runtimes don't compose freely**.
- That **borrow checker reaches across awaits**.
- That **cancellation has subtle correctness implications**.

---

## What Senior Engineers Instinctively Notice

- They **use tokio primitives**, not std blocking.
- They **prefer `Arc` over `Rc`** in async paths.
- They **structure async code** to minimize cross-await borrows.
- They **handle cancellation** explicitly.
- They **read errors carefully** (the messages help once you understand).
- They **profile under realistic load**.
- They **understand the trade-offs** vs threads or other languages.

---

## Interview Perspective

What gets tested:

1. **"What's a Future?"** State machine implementing the trait.
2. **"What's `Send` and why does async Rust care?"** Tasks may move threads; non-Send types prevent that.
3. **"Why is `Pin` necessary?"** Self-referential futures can't move once polled.
4. **"async/await syntax — what does it compile to?"** State machines.
5. **"How does tokio scheduler work?"** M:N work-stealing.
6. **"Why can't I use std Mutex in async?"** Holds the thread; blocks scheduler.

Common traps:
- Believing async Rust is like JS async (it's harder).
- Mixing blocking and async code.

---

## 20% Knowledge Giving 80% Understanding

1. **Futures are lazy state machines** the compiler builds.
2. **`Send` required** for multi-threaded runtimes.
3. **Don't block** in async code.
4. **Use tokio primitives** (mutex, sleep, etc.).
5. **`Pin`** is about preventing moves.
6. **Borrow checker** spans awaits.
7. **`Arc` not `Rc`** in async.
8. **Cancellation** must be handled explicitly.
9. **Runtimes don't compose**; pick one.
10. **Performance is excellent** when you get it right.

---

## Final Mental Model

> **Async Rust is the most powerful and most demanding async runtime in any production language. The borrow checker, the type system, and the runtime conspire to ensure correctness; the cost is a learning curve that's measured in months, not days. The reward is concurrency without garbage collection, without data races, without surprises — performance close to C with safety better than Java.**

The senior async Rust engineer treats the compiler as a partner. Errors are information. `Send` and `Sync` requirements are the cost of multi-threading correctness. `Pin` is the cost of zero-cost futures. Each arcane concept exists for a reason; understanding the reason makes the concept easier.

The teams that ship production async Rust at scale (Discord, Cloudflare, AWS) are the teams that invested in the learning curve. The teams that bounce off async Rust often don't get past the first compile-error wall. The technology is real; the difficulty is real; the rewards are real for those who push through.

That's async Rust. That's the borrow checker meeting concurrency. That's what's possible when a language refuses to compromise on safety, garbage collection, or performance — and asks the developer to do the proof work to make it all consistent.
