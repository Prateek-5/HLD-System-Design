# The Event Loop & Async Runtime

> *"JavaScript is not single-threaded because it's primitive. It's single-threaded because somebody, decades ago, decided that asking application developers to reason about locks was a worse mistake than the cost of one CPU core."*

---

## 🎯 Start Here — Intuition

> **In one line:** how a program juggles thousands of "waiting" jobs (network calls, disk reads, timers) on a single worker without hiring a thread for each one.
>
> **Analogy:** one barista at a busy coffee shop. They never stand still waiting for an espresso machine — they start your drink, take the next order, start that machine too, and circle back when each machine beeps. The barista is the single thread; the beeping machines are I/O finishing in the background.
>
> **Assumes you already know:** what it means for a server to handle many requests at once, and the single-machine vs. add-more-machines tradeoff — build that in [`learn/foundations/scaling/scalability.md`](../../learn/foundations/scaling/scalability.md). Threads-per-connection vs. one-process-many-connections is the contrast this whole topic lives in.
>
> **Level:** this file is 🔴 overall — it's Node/JS-specialist runtime depth, deliberately past what a system-design interview needs. The intuition and history below are approachable; the phases, libuv, and microtask internals are deep. If those feel shaky, that tag is your signal to slow down — **you are not behind.**

## Topic Overview 🟢

The event loop is the most misunderstood mechanism in modern programming, and the most powerful. It's why Node.js can handle 50,000 concurrent connections on a single thread. It's why a misplaced `JSON.parse` of a 200MB blob freezes your entire server. It's why `setTimeout(fn, 0)` doesn't actually run `fn` in zero milliseconds. It's why every senior backend engineer who came from Java has, at some point, said "wait, *what*?"

This isn't a JavaScript-only topic. The same fundamental architecture — single-threaded execution + async I/O + a queue of pending work — appears in Python's asyncio, Rust's tokio, Go's runtime (with extra goroutine machinery), nginx, Redis, and the entire family of "async frameworks." Understanding the event loop is understanding **the modern alternative to threads**, period.

The promise: handle many concurrent operations without the lock complexity, the per-thread memory overhead, or the context-switch cost of OS threads.

The cost: every unit of work *must* yield. A single tight CPU loop blocks everything.

---

## Intuition Before Definitions 🟢

Picture a coffee shop with one barista.

A bad barista takes one order, waits for the espresso machine to finish (30 seconds), hands the cup over, takes the next order. Throughput: 2 customers a minute. Customers leave.

A good barista takes an order, *starts* the espresso machine, takes the next order, starts another machine, comes back to the first cup when its machine beeps. The barista never *waits* — they're either taking orders, starting machines, or finishing drinks. Throughput: limited only by how many machines are running.

That barista is the event loop. The machines are I/O operations (network, disk, timers). The orders queue is the task queue. The barista's hands are the single thread of execution. The beeping machines are I/O completion events.

The catch: if a customer asks the barista to *manually grind beans for ten minutes*, every other customer waits. The event loop doesn't help with CPU work. It helps with *waiting*.

That's the entire model. Everything else is mechanics.

---

## Historical Evolution 🟢

**Era 1 — Threads everywhere.**
Apache, classic Java EE servers: one OS thread per connection. Beautiful programming model. Disastrous at scale. 10K connections = 10K threads = 80GB of stack memory + a context-switch storm. The "C10K problem" was named in 1999 and dominated server engineering for a decade.

**Era 2 — `select()` and `poll()`.**
The first wave of event-driven servers used POSIX (Portable Operating System Interface) `select` to wait on many file descriptors with one thread. Worked. Scaled to a few thousand connections, then quadratic costs in the syscall killed it.

**Era 3 — `epoll`, `kqueue`, IOCP (Input/Output Completion Ports).**
Linux's `epoll` (2002) and BSD (Berkeley Software Distribution)'s `kqueue` introduced O(1) event notification: register interest in fds (file descriptors) once, get back only the ones with activity. This is the kernel-level primitive that makes modern event loops viable. Without it, async would still be a niche pattern.

**Era 4 — Node.js (2009).**
Ryan Dahl's insight: JavaScript already has a single-threaded async model (the browser event loop), and the language's culture is callback-friendly. Pair it with V8 (a fast JS engine) and libuv (a cross-platform abstraction over epoll/kqueue/IOCP) — suddenly you have a runtime that handles tens of thousands of concurrent I/O-bound connections on a single thread.

**Era 5 — Async/await everywhere.**
Promises (ES2015, ECMAScript 2015), async/await (ES2017) made async code look synchronous. Other languages followed: Python's asyncio, C# async/await, Rust's async/await with tokio, Java's Project Loom (a different but related answer). Async became mainstream syntax.

**Era 6 — The blowback.**
"Function coloring" (red functions can call blue, blue can't call red), the rise of *structured concurrency*, the realization that purely cooperative scheduling has ergonomic costs. Go's goroutines and Java's virtual threads represent a different bet — keep the threading mental model, but with cheap user-space threads multiplexed onto OS threads.

The event loop won the *infrastructure* war (it's everywhere). The threading model is making a comeback for *application code* (Loom, goroutines). Both can coexist, and increasingly do.

---

## Deep Technical Explanation 🔴

⚠️ The rest assumes the basics above are solid.

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
- Inside an I/O callback, `setImmediate` runs before `setTimeout(fn, 0)`. Outside (at the top of the main module) the order isn't guaranteed: it depends on whether the ~1ms timer threshold has already elapsed by the time the loop reaches the timers phase, which is sensitive to process-startup cost — not a true coin flip. This trips up everyone exactly once.

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
- DNS (Domain Name System) resolution via `getaddrinfo` (synchronous-looking C library).
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

This is a happy-path sketch only — it gets rejection semantics wrong. A real async function wraps its entire synchronous body so that a `throw` *before* the first `await` still returns a rejected promise; the naive `.then` desugaring above would instead throw synchronously at call time. (This is the same reason an `async` function always returns a promise, even on a synchronous error.)

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

Real production: a JSON parse of a megabyte payload is ~10ms of pure CPU. A markdown render is ~50ms. A regex on attacker-controlled input can be *milliseconds to minutes* (ReDoS, Regular expression Denial of Service). Each is a tiny event-loop freeze. At scale, these add up to elevated p99 latency that is invisible in CPU graphs but obvious to users.

The fix categories:
1. **Yield with `await new Promise(setImmediate)`** in long loops to let other work in.
2. **Use `worker_threads`** for CPU-heavy work.
3. **Move it to another service** (a Python worker, a Go binary, a Rust function).

---

## Real Engineering Analogies 🟢

**The single-lane bridge.**
The event loop is a single-lane bridge. Cars cross one at a time. The bridge keeper (scheduler) lets each car finish crossing, then waves on the next. Some cars are tiny (a microtask). Some are huge (a CPU loop). The bridge can't be widened. The job of every developer is to keep their cars small.

**The air traffic controller.**
ATC (Air Traffic Control) handles dozens of planes from one console. They never *fly* a plane — they coordinate. They authorize takeoffs, hand off to other controllers, manage the queue. If a single plane needs continuous attention (an emergency), every other plane waits. That's an event loop with a blocking task.

---

## Failure Scenarios 🟡

**Scenario 1 — The DNS thread pool starvation.**
A service makes outbound API calls to ~10 services per request. Each call does a DNS lookup. Under traffic, all 4 libuv threads are stuck on DNS. New requests pile up. CPU is idle. The team blames "the network" for an hour before someone reads the libuv docs.

**Scenario 2 — The microtask infinite loop.**
A library implements polling via recursive `Promise.resolve().then(...)`. It works fine in isolation. In production, it monopolizes the microtask queue, starving the macrotask queue. Timers fire seconds late. HTTP responses are delayed. The browser tab becomes unresponsive but doesn't show as "frozen."

**Scenario 3 — The synchronous JSON in the hot path.**
Service averages 5ms per request. A new feature parses a config blob (200KB) on every request. Median goes to 8ms. p99 goes from 30ms to 400ms — disproportionately bad because the synchronous parse blocks every concurrent request on the same loop iteration.

**Scenario 4 — The ReDoS DoS (Denial of Service).**
A health-check endpoint validates input via regex. Attacker sends a pathological payload. The regex engine backtracks for 30 seconds. Process appears hung. Load balancer marks it unhealthy. Auto-scaler spins up new instances. Attacker hits each one in turn. Service is down.

**Scenario 5 — The memory-leak-from-closure.**
A Promise-based queue keeps references to old completed jobs because of an unintentional closure capture in the resolution path. Memory grows by 50MB/hour. Service restarts every 12 hours from OOM (Out Of Memory). The "fix" is to deploy more frequently, until someone profiles the heap.

---

## Performance Perspective 🟡

- **Event loop lag is your latency budget.** Zero blocking work = zero added latency. Every blocking ms is added to *every concurrent request's* tail.
- **Microtasks are cheaper than macrotasks** (no phase transition cost), but they share the same blocking risk.
- **Buffer reuse matters.** Allocating new buffers on every request is GC (Garbage Collection) pressure. Reusing buffers via pools is a classic optimization.
- **Avoid sync I/O on the request path.** Without exception. The "fast path" of a sync call is *not* faster than async — it's faster *for that one request*, at the cost of every concurrent request.
- **`worker_threads` are real OS threads.** Use them for CPU work. The IPC (Inter-Process Communication) cost is real, so reserve them for tasks that take >10ms.

---

## Scaling Perspective 🟡

- **Vertical:** a Node process uses one CPU core. Add more concurrency to that core via async I/O, but if you saturate the core, you saturate the process.
- **Horizontal (clustered):** Run N processes on N cores using cluster, PM2 (Process Manager 2), or just multiple containers behind a load balancer. Almost always preferable to manual `worker_threads` orchestration for HTTP servers.
- **Memory:** A Node process with 100K open connections still costs orders of magnitude less RAM than a thread-per-connection server with 100K threads.
- **Where it fails to scale:** workloads dominated by CPU, not I/O. Image processing, ML (Machine Learning) inference, heavy serialization — these are not Node's natural habitat.

The scaling logic mirrors distributed systems: **the bottleneck is whichever resource you saturate first.** Node biases toward saturating CPU (because I/O is async); thread-per-connection biases toward saturating memory (per-thread stacks).

---

## Cross-Domain Connections 🟡

- **Database transactions:** the "task runs to completion" rule is the application-layer analog of *serializable execution* — if no other code can interleave, you have isolation by construction.
- **Message queues:** the event loop's task queue *is* a message queue, in miniature. Backpressure, prioritization, fairness — all the same problems.
- **Distributed systems:** the actor model (Erlang, Akka) is fundamentally an event loop per actor, with messages as the queue. Same model, different scale.
- **Operating systems:** the kernel scheduler with cooperative multitasking (early Mac OS, early Windows) was an event loop. They abandoned it because applications didn't yield. Browsers and Node enforce yields via the language model.
- **Networking:** epoll is the kernel-side event loop. Your application's event loop is a user-space mirror of the same idea.
- **Caching:** Redis is single-threaded for almost the same reasons as Node — the simplicity is worth more than the per-core throughput. (Redis 6+ adds I/O threads, but command execution is still single-threaded.)

The deep insight: **single-threaded async is a tradeoff replicated at every layer of the stack.** Each layer saves complexity by serializing work at the cost of single-thread throughput.

---

## Real Production Scenarios 🟡

- **Walmart's Node migration (2012):** moved their mobile backend from Java to Node and watched memory drop, throughput rise — until a CPU-intensive feature surfaced the blocking problem. Postmortems became required Node training material.
- **PayPal's Node migration:** double the requests/sec at half the response time vs. Java, on equivalent hardware. The win was almost entirely from event-driven I/O.
- **Slack's Electron memory issues:** event loops in Electron renderers, plus reference retention via closures, drove memory bloat that became a multi-year engineering effort.
- **The `lodash` template ReDoS (2019):** vulnerable regex in a popular library, deployed in millions of services. Patched, but the post-incident analysis is a textbook on event-loop DoS.
- **Discord's switch from Go to Rust for some services:** documented reasons include avoiding GC pauses (different problem from event loop blocking, but same family of symptoms — unpredictable single-threaded latency spikes).

---

## Worked Example — Diagnosing Event Loop Lag 🔴

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

Each request parses a 50KB XML (eXtensible Markup Language) invoice synchronously. ~80ms of pure CPU per parse.

### Step 3: The synchronous-blocks-everyone realization

When request A is parsing for 80ms, every other request waits. Request B that arrives during A's parse waits 80ms before it even starts. With 100 RPS (Requests Per Second), queue depth grows; tail latency explodes.

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

## Recent Production References (2023-2024) 🟡

- **Bun's runtime (2023+)**: alternative JS runtime; event loop comparison with Node has been actively benchmarked. Different tradeoffs.
- **Deno 2 (2024)**: continues to push runtime evolution; native TypeScript support changes how teams use the event loop.
- **Cloudflare Workers**: V8 isolates per request; sub-millisecond cold starts. Different deployment of the same engine.
- **The Node.js permission model (Node 20+)**: emerging operational interface affecting libuv's syscall pattern.
- **Vercel's serverless Node functions**: cold-start optimization and event-loop-lag monitoring documented publicly.
- **The "node:worker_threads" mainstream adoption**: 2023+ patterns documented; CPU-bound offloading is now standard.

---

## Key Takeaways

**The 20% that gives 80% of the understanding:**

- **One thread runs JS; everything else is async I/O via libuv/kernel.** "JavaScript is async" is wrong — JS is *synchronous*; the *runtime* provides async I/O and (via libuv) invisible parallelism. There is no preemption: a function runs to completion or until it `await`s. A `while(true)` loop freezes the whole process.
- **Microtasks drain completely between macrotasks.** This single rule explains most "why did it run in this order" questions. Microtasks (Promise callbacks, `queueMicrotask`) are cheaper than macrotasks but share the same blocking risk; `process.nextTick` runs *before* microtasks.
- **The event loop runs in phases (Node):** timers, pending callbacks, idle/prepare, poll (I/O), check (`setImmediate`), close. `setTimeout(fn, 0)` is not zero — it runs on the *next timer phase*. `setImmediate` runs in the *check* phase; inside an I/O callback it beats `setTimeout(fn, 0)`.
- **Anything CPU-bound blocks every other request on the same loop.** A synchronous `for` loop with millions of iterations, a `JSON.parse` of a large payload, a markdown render — each is an event-loop freeze that inflates every concurrent request's tail latency. Distinguish **CPU-bound** from **I/O-bound** workloads first.
- **The libuv thread pool is 4 threads by default** (tunable via `UV_THREADPOOL_SIZE`). DNS (`dns.lookup`), file I/O, and crypto (`bcrypt`/`pbkdf2`) share it; saturation looks like elevated p99 with idle CPU. `dns.resolve` goes async instead.
- **Async/await is sugar over promises; every `await` is a yield point** — and an opportunity for shared state to change underneath you. `async` functions always return a Promise, even on a synchronous `return` or `throw`.
- **`forEach` does not await async callbacks** (it returns immediately); `for...of` with `await` serializes iterations; `Promise.all(arr.map(asyncFn))` parallelizes them. `Promise.all` rejects on first failure; `Promise.allSettled` waits for all. Throwing inside a Promise without `.catch` swallows the error.
- **Unhandled promise rejections crash modern Node** (terminate by default since Node 15). Handle them or design for crash-and-restart; set up loud unhandled-rejection and uncaught-exception handlers rather than silent data loss.
- **Watch event loop lag as a first-class metric** (a leading indicator of latency problems; lag > 100ms means tail latency is suffering). Profile with flame graphs (`--prof`, `clinic.js`) before guessing — don't reach for `try/catch` around `await` without knowing what you'll do with the error.
- **Reach for `worker_threads` for CPU-heavy work** (real OS threads; reserve for >10ms tasks given IPC cost), or offload to an external service. Watch for memory leaks via long-lived closures capturing large objects, and the `process.nextTick`-recursion bug that starves I/O phases without crashing.
- **Cluster horizontally, not within the loop.** N processes on N cores (cluster/PM2/containers) beats `worker_threads` heroics for HTTP servers; CPU-dominated workloads (image processing, ML inference) are not Node's habitat.

> **The event loop is a deal: you give up preemption, you get cheap concurrency. Honor the deal by yielding often. Break it once, and the entire system stutters.** The senior engineer is the one who knows which workload class they're in *before* they pick the runtime.

## Interview angle

- **Microtask-vs-macrotask ordering.** Given a snippet of `setTimeout` + Promises + synchronous logs, predict the output order *and explain why* (microtasks drain between macrotasks).
- **"Why doesn't `forEach` + async work?"** Knowing `forEach` doesn't await is mid-level; suggesting `Promise.all(arr.map(asyncFn))` *and* mentioning concurrency limits is senior.
- **"How do you do CPU work in Node?"** Worker threads, child processes, or offload to another service. Bonus: knowing libuv's thread pool exists.
- **"What is event loop lag and how do you measure it?"** `process.hrtime`-based measurement or the `perf_hooks` monitor, with named metrics and alert thresholds.
- **"What happens if you throw inside an async function?"** It returns a rejected promise; if unhandled, modern Node crashes the process.
- **Common traps:** "JavaScript is single-threaded" without nuance (runtime parallelism via libuv); confusing `setImmediate` and `setTimeout(fn, 0)`; thinking `await` waits for *all* concurrent operations; not knowing `process.nextTick` priority.
