# The Event Loop & Async Runtime

> *"JavaScript is not single-threaded because it's primitive. It's single-threaded because somebody, decades ago, decided that asking application developers to reason about locks was a worse mistake than the cost of one CPU core."*

---

## Topic Overview

The event loop is the most misunderstood mechanism in modern programming, and the most powerful. It's why Node.js can handle 50,000 concurrent connections on a single thread. It's why a misplaced `JSON.parse` of a 200MB blob freezes your entire server. It's why `setTimeout(fn, 0)` doesn't actually run `fn` in zero milliseconds. It's why every senior backend engineer who came from Java has, at some point, said "wait, *what*?"

This isn't a JavaScript-only topic. The same fundamental architecture — single-threaded execution + async I/O + a queue of pending work — appears in Python's asyncio, Rust's tokio, Go's runtime (with extra goroutine machinery), nginx, Redis, and the entire family of "async frameworks." Understanding the event loop is understanding **the modern alternative to threads**, period.

The promise: handle many concurrent operations without the lock complexity, the per-thread memory overhead, or the context-switch cost of OS threads.

The cost: every unit of work *must* yield. A single tight CPU loop blocks everything.

---

## Intuition Before Definitions

Picture a coffee shop with one barista.

A bad barista takes one order, waits for the espresso machine to finish (30 seconds), hands the cup over, takes the next order. Throughput: 2 customers a minute. Customers leave.

A good barista takes an order, *starts* the espresso machine, takes the next order, starts another machine, comes back to the first cup when its machine beeps. The barista never *waits* — they're either taking orders, starting machines, or finishing drinks. Throughput: limited only by how many machines are running.

That barista is the event loop. The machines are I/O operations (network, disk, timers). The orders queue is the task queue. The barista's hands are the single thread of execution. The beeping machines are I/O completion events.

The catch: if a customer asks the barista to *manually grind beans for ten minutes*, every other customer waits. The event loop doesn't help with CPU work. It helps with *waiting*.

That's the entire model. Everything else is mechanics.

---

## Historical Evolution

**Era 1 — Threads everywhere.**
Apache, classic Java EE servers: one OS thread per connection. Beautiful programming model. Disastrous at scale. 10K connections = 10K threads = 80GB of stack memory + a context-switch storm. The "C10K problem" was named in 1999 and dominated server engineering for a decade.

**Era 2 — `select()` and `poll()`.**
The first wave of event-driven servers used POSIX `select` to wait on many file descriptors with one thread. Worked. Scaled to a few thousand connections, then quadratic costs in the syscall killed it.

**Era 3 — `epoll`, `kqueue`, IOCP.**
Linux's `epoll` (2002) and BSD's `kqueue` introduced O(1) event notification: register interest in fds once, get back only the ones with activity. This is the kernel-level primitive that makes modern event loops viable. Without it, async would still be a niche pattern.

**Era 4 — Node.js (2009).**
Ryan Dahl's insight: JavaScript already has a single-threaded async model (the browser event loop), and the language's culture is callback-friendly. Pair it with V8 (a fast JS engine) and libuv (a cross-platform abstraction over epoll/kqueue/IOCP) — suddenly you have a runtime that handles tens of thousands of concurrent I/O-bound connections on a single thread.

**Era 5 — Async/await everywhere.**
Promises (ES2015), async/await (ES2017) made async code look synchronous. Other languages followed: Python's asyncio, C# async/await, Rust's async/await with tokio, Java's Project Loom (a different but related answer). Async became mainstream syntax.

**Era 6 — The blowback.**
"Function coloring" (red functions can call blue, blue can't call red), the rise of *structured concurrency*, the realization that purely cooperative scheduling has ergonomic costs. Go's goroutines and Java's virtual threads represent a different bet — keep the threading mental model, but with cheap user-space threads multiplexed onto OS threads.

The event loop won the *infrastructure* war (it's everywhere). The threading model is making a comeback for *application code* (Loom, goroutines). Both can coexist, and increasingly do.

---

## Core Mental Models

**1. The event loop is a scheduler with a single execution slot.**
At any moment, exactly one piece of JS is running. The event loop's job is to decide *what runs next* when that piece finishes.

**2. JS is single-threaded; the runtime around it is not.**
V8 runs your code on one thread. libuv has a thread pool for blocking syscalls (file I/O, DNS, crypto). Network I/O uses kernel async (epoll). The thread pool is invisible to your code, but it's there, and it's why `crypto.pbkdf2` doesn't block the event loop.

**3. There is no preemption.**
A function runs from start to finish (or until it `await`s). The runtime cannot interrupt your code. If you write a `while(true)` loop, the entire process is frozen — no requests served, no timers fired, nothing. This is the central tradeoff.

**4. Microtasks ≠ macrotasks.**
The queue you think is "the queue" is actually two queues with very different scheduling rules. Microtasks (Promise callbacks, `queueMicrotask`) drain *completely* between every macrotask. This single rule causes 80% of "why did my code run in this order" confusion.

**5. The event loop has phases (in Node).**
Timers, pending callbacks, idle/prepare, poll (I/O), check (`setImmediate`), close. Each phase processes its queue, then yields to the next. Knowing the phases is what separates "I use Node" from "I understand Node."

---

## Deep Technical Explanation

### The browser event loop (simplified)

```
┌─────────────────────────────────────────────────┐
│  while (true) {                                  │
│    task = pickOneFromTaskQueue();                │
│    run(task);                                    │
│    drainMicrotaskQueue();                        │
│    if (renderingDue()) render();                 │
│  }                                                │
└─────────────────────────────────────────────────┘
```

- One macrotask runs. (This is your `setTimeout` callback, your event handler, your `fetch` resolution, etc.)
- After it finishes, *all* queued microtasks run. New microtasks queued during this draining also run, in order, until the queue is empty.
- Then the browser may render (if 16ms have elapsed and rendering is needed).
- Then back to the next macrotask.

**Implication:** if you keep queueing microtasks from microtasks (`Promise.resolve().then(loop)`), you can starve rendering. The browser will literally never paint.

### The Node event loop (more involved)

Node's loop runs in **phases**, each with its own callback queue:

| Phase | What runs |
|---|---|
| **Timers** | `setTimeout`, `setInterval` callbacks whose threshold elapsed |
| **Pending callbacks** | Some I/O callbacks deferred from the previous loop |
| **Idle, prepare** | Internal |
| **Poll** | New I/O events; blocks here if no other work is pending |
| **Check** | `setImmediate` callbacks |
| **Close callbacks** | `socket.on('close', …)` |

After each individual callback, microtasks drain and `process.nextTick` callbacks drain. `nextTick` runs *before* microtasks. (Yes, Node has its own queue *above* microtasks. This is a historical accident worth knowing about.)

Practical consequences:
- `setTimeout(fn, 0)` runs in the *next* timer phase, not "next tick."
- `setImmediate(fn)` runs in the *check* phase of the current loop iteration.
- Inside an I/O callback, `setImmediate` runs before `setTimeout(fn, 0)`. Outside, the order is non-deterministic. This trips up everyone exactly once.

### Microtasks: the rule that explains everything

```js
console.log('A');
setTimeout(() => console.log('B'), 0);
Promise.resolve().then(() => console.log('C'));
console.log('D');
```

Output: `A, D, C, B`.

Why: A and D are synchronous. C is a microtask, queued during the current task. B is a macrotask. After the current task (the script) finishes, *all* microtasks drain (C). Then the next macrotask runs (B).

This is not a JavaScript quirk. It is *the* mechanism by which Promises chain without yielding execution to other tasks. Every `.then` you write depends on this rule.

### libuv and the thread pool

libuv handles the bits the kernel can't do async natively:
- File I/O (because `read`/`write` on files don't have a clean async syscall on Linux that works for *all* filesystems).
- DNS resolution via `getaddrinfo` (synchronous-looking C library).
- CPU-heavy crypto operations.
- User-defined `worker_threads`.

Default thread pool size: 4. (Yes, four.) If you do four concurrent `fs.readFile`s on huge files, the fifth blocks. `UV_THREADPOOL_SIZE=128` exists; many production Node deployments set it.

This is the *invisible parallelism* that makes Node fast. The user code is single-threaded; libuv is not.

### Async/await mechanics

```js
async function f() {
  const a = await getA();
  const b = await getB(a);
  return b;
}
```

Compiles to (roughly):

```js
function f() {
  return getA().then(a => getB(a)).then(b => b);
}
```

Each `await` is a yield point. The function's state is captured, control returns to the event loop, and when the awaited promise resolves, a microtask is queued to resume the function.

Implication: there are *more yield points* in async code than in sync code. Each yield is an opportunity for other tasks to run. This is where async code's concurrency comes from — but it's also where its *bugs* come from. Anything reading shared state across an `await` may find that state changed.

### The blocking trap

```js
app.get('/heavy', (req, res) => {
  let sum = 0;
  for (let i = 0; i < 1e10; i++) sum += i;
  res.send({ sum });
});
```

This server can serve *one* request at a time. The CPU loop blocks the event loop entirely. Every other client waits, including the load balancer's health check.

Real production: a JSON parse of a megabyte payload is ~10ms of pure CPU. A markdown render is ~50ms. A regex on attacker-controlled input can be *milliseconds to minutes* (ReDoS). Each is a tiny event-loop freeze. At scale, these add up to elevated p99 latency that is invisible in CPU graphs but obvious to users.

The fix categories:
1. **Yield with `await new Promise(setImmediate)`** in long loops to let other work in.
2. **Use `worker_threads`** for CPU-heavy work.
3. **Move it to another service** (a Python worker, a Go binary, a Rust function).

---

## Real Engineering Analogies

**The single-lane bridge.**
The event loop is a single-lane bridge. Cars cross one at a time. The bridge keeper (scheduler) lets each car finish crossing, then waves on the next. Some cars are tiny (a microtask). Some are huge (a CPU loop). The bridge can't be widened. The job of every developer is to keep their cars small.

**The air traffic controller.**
ATC handles dozens of planes from one console. They never *fly* a plane — they coordinate. They authorize takeoffs, hand off to other controllers, manage the queue. If a single plane needs continuous attention (an emergency), every other plane waits. That's an event loop with a blocking task.

---

## Production Engineering Perspective

What breaks at 3am because of the event loop:

- **`JSON.parse` of large payloads.** Synchronous. Blocks the loop. A 10MB JSON parse at p99 looks like a mysterious latency spike.
- **Regex backtracking (ReDoS).** Attacker sends `aaaaaaaaaaaaaaaaaaaaaaa!` against a vulnerable regex. The loop freezes for seconds. Service appears down.
- **DNS resolution.** Default `dns.lookup` uses libuv's thread pool. Under load, the 4-thread default saturates. Symptom: requests pile up, CPU is idle, and nobody can figure out why. Fix: increase `UV_THREADPOOL_SIZE` or use `dns.resolve` (which goes async).
- **Crypto operations on the request path.** `bcrypt`, `pbkdf2`, large RSA operations. Each one blocks a libuv thread. Pool saturation looks like elevated p99s with idle CPU.
- **Synchronous filesystem calls.** `fs.readFileSync` in a route handler is grounds for code review rejection. Yet it appears in production code constantly.
- **Promise rejection handling.** Unhandled rejections used to crash the process; now they emit warnings and (since Node 15) terminate by default. Misconfigured handlers turn this into silent data loss.
- **Memory leaks via closures.** Long-lived event handlers capturing large objects. The GC can't collect what's referenced; memory grows monotonically.
- **The `process.nextTick` recursion bug.** A library that schedules a `nextTick` from inside a `nextTick` callback can starve the I/O phases entirely. The server stops accepting connections without crashing. Hard to diagnose without flame graphs.

The senior engineer's habits:
- Watch the **event loop lag** as a first-class metric. If lag > 100ms, your tail latency is suffering.
- Profile with `--prof` or `clinic.js` when latency spikes appear.
- Keep CPU-heavy work in worker threads or external services.
- Set up *unhandled rejection* and *uncaught exception* handlers that crash loudly rather than silently.

---

## Failure Scenarios

**Scenario 1 — The DNS thread pool starvation.**
A service makes outbound API calls to ~10 services per request. Each call does a DNS lookup. Under traffic, all 4 libuv threads are stuck on DNS. New requests pile up. CPU is idle. The team blames "the network" for an hour before someone reads the libuv docs.

**Scenario 2 — The microtask infinite loop.**
A library implements polling via recursive `Promise.resolve().then(...)`. It works fine in isolation. In production, it monopolizes the microtask queue, starving the macrotask queue. Timers fire seconds late. HTTP responses are delayed. The browser tab becomes unresponsive but doesn't show as "frozen."

**Scenario 3 — The synchronous JSON in the hot path.**
Service averages 5ms per request. A new feature parses a config blob (200KB) on every request. Median goes to 8ms. p99 goes from 30ms to 400ms — disproportionately bad because the synchronous parse blocks every concurrent request on the same loop iteration.

**Scenario 4 — The ReDoS DoS.**
A health-check endpoint validates input via regex. Attacker sends a pathological payload. The regex engine backtracks for 30 seconds. Process appears hung. Load balancer marks it unhealthy. Auto-scaler spins up new instances. Attacker hits each one in turn. Service is down.

**Scenario 5 — The memory-leak-from-closure.**
A Promise-based queue keeps references to old completed jobs because of an unintentional closure capture in the resolution path. Memory grows by 50MB/hour. Service restarts every 12 hours from OOM. The "fix" is to deploy more frequently, until someone profiles the heap.

---

## Performance Perspective

- **Event loop lag is your latency budget.** Zero blocking work = zero added latency. Every blocking ms is added to *every concurrent request's* tail.
- **Microtasks are cheaper than macrotasks** (no phase transition cost), but they share the same blocking risk.
- **Buffer reuse matters.** Allocating new buffers on every request is GC pressure. Reusing buffers via pools is a classic optimization.
- **Avoid sync I/O on the request path.** Without exception. The "fast path" of a sync call is *not* faster than async — it's faster *for that one request*, at the cost of every concurrent request.
- **`worker_threads` are real OS threads.** Use them for CPU work. The IPC cost is real, so reserve them for tasks that take >10ms.

---

## Scaling Perspective

- **Vertical:** a Node process uses one CPU core. Add more concurrency to that core via async I/O, but if you saturate the core, you saturate the process.
- **Horizontal (clustered):** Run N processes on N cores using cluster, PM2, or just multiple containers behind a load balancer. Almost always preferable to manual `worker_threads` orchestration for HTTP servers.
- **Memory:** A Node process with 100K open connections still costs orders of magnitude less RAM than a thread-per-connection server with 100K threads.
- **Where it fails to scale:** workloads dominated by CPU, not I/O. Image processing, ML inference, heavy serialization — these are not Node's natural habitat.

The scaling logic mirrors distributed systems: **the bottleneck is whichever resource you saturate first.** Node biases toward saturating CPU (because I/O is async); thread-per-connection biases toward saturating memory (per-thread stacks).

---

## Cross-Domain Connections

- **Database transactions:** the "task runs to completion" rule is the application-layer analog of *serializable execution* — if no other code can interleave, you have isolation by construction.
- **Message queues:** the event loop's task queue *is* a message queue, in miniature. Backpressure, prioritization, fairness — all the same problems.
- **Distributed systems:** the actor model (Erlang, Akka) is fundamentally an event loop per actor, with messages as the queue. Same model, different scale.
- **Operating systems:** the kernel scheduler with cooperative multitasking (early Mac OS, early Windows) was an event loop. They abandoned it because applications didn't yield. Browsers and Node enforce yields via the language model.
- **Networking:** epoll is the kernel-side event loop. Your application's event loop is a user-space mirror of the same idea.
- **Caching:** Redis is single-threaded for almost the same reasons as Node — the simplicity is worth more than the per-core throughput. (Redis 6+ adds I/O threads, but command execution is still single-threaded.)

The deep insight: **single-threaded async is a tradeoff replicated at every layer of the stack.** Each layer saves complexity by serializing work at the cost of single-thread throughput.

---

## Real Production Scenarios

- **Walmart's Node migration (2012):** moved their mobile backend from Java to Node and watched memory drop, throughput rise — until a CPU-intensive feature surfaced the blocking problem. Postmortems became required Node training material.
- **PayPal's Node migration:** double the requests/sec at half the response time vs. Java, on equivalent hardware. The win was almost entirely from event-driven I/O.
- **Slack's Electron memory issues:** event loops in Electron renderers, plus reference retention via closures, drove memory bloat that became a multi-year engineering effort.
- **The `lodash` template ReDoS (2019):** vulnerable regex in a popular library, deployed in millions of services. Patched, but the post-incident analysis is a textbook on event-loop DoS.
- **Discord's switch from Go to Rust for some services:** documented reasons include avoiding GC pauses (different problem from event loop blocking, but same family of symptoms — unpredictable single-threaded latency spikes).

---

## What Junior Engineers Usually Miss

- That "JavaScript is async" is **wrong** — JS is *synchronous*; the *runtime* provides async I/O.
- That `setTimeout(fn, 0)` is not "run immediately" — it's "run on the next timer phase."
- That `forEach` does not await async callbacks. It returns immediately. (`for...of` with `await` does what you want.)
- That throwing inside a Promise without `.catch` swallows the error.
- That `async` functions always return a Promise, even if you `return` a plain value.
- That `await` inside a loop serializes the iterations; `Promise.all(map)` parallelizes them.
- That `Promise.all` rejects on the first failure; `Promise.allSettled` waits for all.
- That a synchronous `for` loop with millions of iterations blocks every other client.

---

## What Senior Engineers Instinctively Notice

- They watch **event loop lag** in production dashboards.
- They reach for `worker_threads` reflexively when they see CPU work in a request handler.
- They know the **default libuv thread pool size is 4** and tune it for their workload.
- They distinguish **CPU-bound** from **I/O-bound** workloads in the first sentence of a design discussion.
- They don't write `try/catch` around `await` reflexively — they think about *what they're going to do with the error* first.
- They treat **unhandled promise rejections** as production-blocking bugs.
- They profile with flame graphs before guessing.
- They understand that **scaling a Node service horizontally is almost always preferable to optimizing for more concurrency on one core**.

---

## Interview Perspective

What gets tested:

1. **The microtask-vs-macrotask order question.** A code snippet with `setTimeout`, Promises, and synchronous logs, asking for the output order. The candidate who explains *why* (microtasks drain between macrotasks) is showing real understanding.
2. **"Why doesn't this work?" with `forEach` + async.** The candidate who knows `forEach` doesn't await is mid-level. The one who suggests `Promise.all(arr.map(asyncFn))` *and* mentions concurrency limits is senior.
3. **"How do you do CPU work in Node?"** Worker threads, child processes, offload to another service. Bonus for knowing libuv's thread pool exists.
4. **"What is event loop lag and how do you measure it?"** Look for `process.hrtime` based measurements or the `perf_hooks` monitor. Senior candidates name specific metrics and alert thresholds.
5. **"What happens if you throw inside an async function?"** The function returns a rejected promise. If unhandled, it (in modern Node) crashes the process.

Common traps:
- "JavaScript is single-threaded" without nuance — the *runtime* provides parallelism via libuv.
- Confusing `setImmediate` and `setTimeout(fn, 0)`.
- Thinking `await` waits for *all* concurrent operations.
- Not knowing about `process.nextTick` priority.

---

## Worked Example — Diagnosing Event Loop Lag

Production Node service averages 30ms latency. p99 is 800ms. CPU usage is 45%. The mismatch is the giveaway: low average + high tail = event loop lag.

### Step 1: Confirm event loop lag

Add a metric to the service:

```javascript
const { monitorEventLoopDelay } = require('perf_hooks');
const histogram = monitorEventLoopDelay({ resolution: 10 });
histogram.enable();

setInterval(() => {
  const lag = histogram.percentile(99) / 1e6; // convert ns to ms
  metrics.gauge('event_loop_lag_p99_ms', lag);
  histogram.reset();
}, 1000);
```

Production data shows: `event_loop_lag_p99_ms` regularly hits 200-700ms. Confirmed: lag is the issue.

### Step 2: Find the culprit

CPU profile (with `--prof` or clinic.js) reveals the hot path:

```
[==========================] handle_request
   [================] parse_invoice_xml         (60% of CPU)
       [============] xpath_evaluate
       [=========] string_normalize
   [====] business_logic
   [==] db_query
```

Each request parses a 50KB XML invoice synchronously. ~80ms of pure CPU per parse.

### Step 3: The synchronous-blocks-everyone realization

When request A is parsing for 80ms, every other request waits. Request B that arrives during A's parse waits 80ms before it even starts. With 100 RPS, queue depth grows; tail latency explodes.

This is *not* a CPU-utilization problem (CPU is 45%, not 100%). It's a *single-threaded blocking* problem. The event loop has only one execution slot; 80ms of blocking work blocks everything else.

### Step 4: The fix — move work off the event loop

```javascript
const { Worker, isMainThread, parentPort } = require('worker_threads');

// In a separate file: worker.js
parentPort.on('message', (xml) => {
  const parsed = parseInvoiceXml(xml);  // CPU-heavy, but on worker thread
  parentPort.postMessage(parsed);
});

// In main.js
class WorkerPool {
  constructor(size) {
    this.workers = Array.from({ length: size }, () => new Worker('./worker.js'));
    this.idle = [...this.workers];
    this.queue = [];
  }
  
  async parse(xml) {
    return new Promise((resolve, reject) => {
      const job = { xml, resolve, reject };
      if (this.idle.length > 0) this.assign(this.idle.pop(), job);
      else this.queue.push(job);
    });
  }
  
  assign(worker, job) {
    worker.once('message', (result) => {
      job.resolve(result);
      const next = this.queue.shift();
      if (next) this.assign(worker, next);
      else this.idle.push(worker);
    });
    worker.postMessage(job.xml);
  }
}

const pool = new WorkerPool(4);

app.post('/invoices', async (req, res) => {
  const parsed = await pool.parse(req.body);  // blocking work on worker thread
  // event loop is free during this await
  res.json(parsed);
});
```

After deploy:
- p99 drops from 800ms to 80ms.
- `event_loop_lag_p99_ms` drops to <10ms.
- CPU usage rises to 70% (workers actively running).
- Throughput doubles.

The operation isn't *faster* — each parse still takes 80ms — but other requests no longer wait behind it.

### Reference architecture — Node.js with worker pool

```
┌──────────────────────────────────────────────────────────┐
│                   Node.js Process                          │
│                                                            │
│   ┌────────────────────────┐                              │
│   │   Main Event Loop       │                              │
│   │   (V8, single-threaded) │                              │
│   │                          │                              │
│   │  - HTTP server           │                              │
│   │  - Routing               │                              │
│   │  - Database calls        │                              │
│   │  - Awaits                │                              │
│   └─────────┬──────────────┘                              │
│             │ postMessage                                   │
│             ▼                                               │
│   ┌────────────────────────────────────┐                  │
│   │  Worker Thread Pool                 │                  │
│   │                                      │                  │
│   │  ┌──────┐  ┌──────┐  ┌──────┐      │                  │
│   │  │ W1   │  │ W2   │  │ W3   │ ...  │                  │
│   │  │ Own  │  │ Own  │  │ Own  │      │                  │
│   │  │ V8   │  │ V8   │  │ V8   │      │                  │
│   │  │ loop │  │ loop │  │ loop │      │                  │
│   │  └──────┘  └──────┘  └──────┘      │                  │
│   └────────────────────────────────────┘                  │
│                                                            │
└──────────────────────────────────────────────────────────┘
```

Main loop handles I/O orchestration; workers handle CPU-bound tasks.

---

## Recent Production References (2023-2024)

- **Bun's runtime (2023+)**: alternative JS runtime; event loop comparison with Node has been actively benchmarked. Different tradeoffs.
- **Deno 2 (2024)**: continues to push runtime evolution; native TypeScript support changes how teams use the event loop.
- **Cloudflare Workers**: V8 isolates per request; sub-millisecond cold starts. Different deployment of the same engine.
- **The Node.js permission model (Node 20+)**: emerging operational interface affecting libuv's syscall pattern.
- **Vercel's serverless Node functions**: cold-start optimization and event-loop-lag monitoring documented publicly.
- **The "node:worker_threads" mainstream adoption**: 2023+ patterns documented; CPU-bound offloading is now standard.

---

## 20% Knowledge Giving 80% Understanding

1. **One thread runs JS. Everything else is async I/O via libuv/kernel.**
2. **Microtasks drain completely between macrotasks.** This single rule explains most ordering questions.
3. **Anything CPU-bound blocks every other request on the same loop.**
4. **`setTimeout(fn, 0)` is not zero — it's "next timer phase."**
5. **The libuv thread pool is 4 threads by default.** DNS, file I/O, crypto share it.
6. **Async/await is sugar over promises; every `await` is a yield point.**
7. **Unhandled promise rejections crash modern Node.** Handle them or design for crash-and-restart.
8. **Cluster horizontally, not within the loop.** N processes on N cores beats heroics in one loop.
9. **Event loop lag is a leading indicator** of latency problems. Monitor it.
10. **`forEach` doesn't await; `for...of` does; `Promise.all(map)` parallelizes.**

---

## Final Mental Model

> **The event loop is a deal: you give up preemption, you get cheap concurrency. Honor the deal by yielding often. Break it once, and the entire system stutters.**

Threads handle blocking work by burning memory and context-switch CPU. Event loops handle it by *outsourcing waiting* to the kernel and accepting that all in-process work is sequential. Each model is right for a class of workload — and the senior engineer is the one who knows which class they're in *before* they pick the runtime.

The barista metaphor isn't cute — it's literal. Your job, writing async code, is to be the good barista. Take the order, start the machine, take the next order, never freeze on a single drink. When you do that, one core handles thousands of customers. When you don't, the line goes out the door.
