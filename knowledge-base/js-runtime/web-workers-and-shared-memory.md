# Web Workers, Worker Threads & Shared Memory in JavaScript

> *"JavaScript was designed as a single-threaded language and stayed that way for two decades, by deliberate choice. Then the web tried to do video editing, ML inference, and 3D rendering in the browser, and the choice became untenable. Web Workers, Worker Threads, and SharedArrayBuffer are the carefully-bounded retreat from 'JavaScript is single-threaded' — preserving most of the simplicity while admitting parallelism where it's actually needed."*

---

## Topic Overview

JavaScript's single-threaded model is a feature, not a bug. The simplicity — no race conditions, no locks, no shared mutable state across threads — is what made it the most-deployed programming language in history. But "single-threaded" is increasingly a constraint, not a property. CPU-heavy work blocks the UI; ML inference can't run on the main thread; large data processing crawls.

The answer was Web Workers (browser, 2009) and Worker Threads (Node, 2018). Each is a separate JavaScript execution context — its own V8 isolate, its own event loop, its own memory. Communication is via message passing (`postMessage`). The single-threaded property is preserved *within each worker*; parallelism is across workers.

For genuinely shared state, SharedArrayBuffer (2017+, with security restrictions) provides shared memory between workers. With Atomics for safe synchronization, JavaScript can do what C does — but with sharply restricted scopes and explicit opt-in.

This is the topic where JavaScript reluctantly admits parallelism. The model is conservative by design: workers can't share regular objects; only structured-cloned messages and explicit shared memory. The complexity that locks and shared state bring to other languages is mostly avoided. Where it isn't avoided, it's confined to specific use cases.

---

## Intuition Before Definitions

Imagine your web app is a single chef in a kitchen, taking orders one at a time.

For most things, this is fine. Take order, prepare, serve, next. The customer gets fast service because the chef doesn't multitask poorly.

But: a customer orders something that requires 30 minutes of grinding (heavy CPU work). The chef can't take any other orders during the grind. Other customers wait. The kitchen is jammed.

**Web Workers solution.** Hire an assistant who works in a separate room. When a customer orders the grinding-heavy dish, the chef hands the request to the assistant via a window. The assistant grinds; the chef keeps taking orders; eventually the assistant slides the finished dish back through the window. The kitchen flows again.

The chef and assistant don't share countertops. They don't share knives. They communicate only by passing things through the window. This separation is fundamental — and is what makes the system work without locks or coordination headaches.

**SharedArrayBuffer solution.** For some tasks, copying data through the window is too slow. The chef and assistant agree to share a specific shelf. They use explicit handoff signals (Atomics) to coordinate access. More efficient; more dangerous. Used only where strictly needed.

That's Web Workers, Worker Threads, and shared memory. JavaScript's reluctant parallelism, with strong walls between threads to keep the model simple.

---

## Historical Evolution

**Era 1 — Single-threaded everything.**
1990s-2000s. JavaScript ran on one thread; long-running scripts froze the browser. Acceptable when JS was used lightly.

**Era 2 — Web Workers (2009).**
WHATWG specifies Web Workers. Browsers implement. Each worker is a separate execution context; communicates via postMessage. Slow adoption initially.

**Era 3 — Service Workers (2014).**
A specialized worker for offline-first PWAs. Different from regular workers but shares the model.

**Era 4 — SharedArrayBuffer (2017).**
Spectre attacks (2018) caused browsers to disable SharedArrayBuffer temporarily. Required cross-origin isolation headers (COOP, COEP) to re-enable. Practical use complicated by these requirements.

**Era 5 — Worker Threads in Node (2018).**
Node 10+ ships worker_threads. Same model as Web Workers but in Node. Server-side parallelism within a single Node process.

**Era 6 — Modern usage patterns.**
Today: workers for CPU-heavy work (image processing, parsing, ML inference). SharedArrayBuffer for high-bandwidth scenarios (WebAssembly + threading). Slowly mainstreaming.

The pattern: each generation expanded JavaScript's parallelism options conservatively. The single-threaded-per-context model is preserved; parallelism is across contexts.

---

## Core Mental Models

**1. Each worker is a separate JavaScript execution context.**
Its own V8 isolate, its own event loop, its own memory. It can't access the parent's variables.

**2. Communication is by structured cloning.**
`postMessage` serializes the message; worker deserializes it. Functions, DOM nodes, and other non-cloneable types can't be sent.

**3. Transferable objects move ownership.**
Some types (ArrayBuffer, MessagePort) can be *transferred* — ownership moves to the receiver; sender no longer has access. Avoids copying.

**4. Workers add parallelism, not concurrency.**
Each worker still runs single-threaded internally. The cross-worker structure is the parallelism. Within a worker, the same async patterns apply.

**5. Shared memory is a sharp tool.**
SharedArrayBuffer + Atomics enables true shared state. Race conditions become possible. Used only where the alternative (copying) is too expensive.

---

## Deep Technical Explanation

### Web Workers

```js
// main.js
const worker = new Worker('worker.js');
worker.postMessage({ data: largeArray });
worker.onmessage = (e) => {
  console.log('Result:', e.data);
};

// worker.js
self.onmessage = (e) => {
  const result = heavyComputation(e.data);
  self.postMessage(result);
};
```

Properties:
- Worker file is a separate JS file (or Blob URL).
- No DOM access in the worker.
- Communication only via message passing.
- Worker can have its own subworkers.

### Worker Threads in Node

```js
// main.js
const { Worker } = require('worker_threads');
const worker = new Worker('./worker.js');
worker.postMessage({ data: largeArray });
worker.on('message', (msg) => {
  console.log('Result:', msg);
});

// worker.js
const { parentPort } = require('worker_threads');
parentPort.on('message', (msg) => {
  const result = heavyComputation(msg.data);
  parentPort.postMessage(result);
});
```

Same model as Web Workers. Differences:
- Workers can use Node's standard library (fs, net, etc.).
- Process-wide state is per-worker (each has its own require cache).
- Memory limits are per-worker.

### Structured cloning

`postMessage` uses the structured clone algorithm:
- Serializable types: numbers, strings, booleans, null, undefined, plain objects, arrays, Map, Set, Date, RegExp, ArrayBuffer, typed arrays.
- Not serializable: functions, DOM nodes (browser), classes with prototypes (only data is preserved).
- Throws on circular references? Actually, structured cloning handles circular references.

Cost: deep copy of the message. Large objects = expensive.

### Transferable objects

For large binary data, transfer instead of copy:

```js
const buffer = new ArrayBuffer(1024 * 1024);
worker.postMessage({ buffer }, [buffer]);
// buffer is now neutered in the main thread
```

The buffer's memory is "transferred" — the worker now owns it; the main thread can't access it. Zero-copy hand-off.

Transferable types: ArrayBuffer, MessagePort, ImageBitmap, OffscreenCanvas, ReadableStream, WritableStream.

### SharedArrayBuffer

For genuinely shared memory:

```js
const sab = new SharedArrayBuffer(1024 * 1024);
const view = new Int32Array(sab);
worker.postMessage({ sab });

// Both threads can now read/write `view`. Race conditions possible.
```

Both contexts have access to the same memory. *No serialization*. Read and write are direct.

Race conditions are real:
```js
view[0] = view[0] + 1;  // race
```

If two threads do this simultaneously, the result is unpredictable.

### Atomics

For safe shared-memory access:

```js
Atomics.add(view, 0, 1);   // atomic increment
Atomics.load(view, 0);      // atomic read
Atomics.store(view, 0, 42); // atomic write

Atomics.compareExchange(view, 0, expected, replacement);  // CAS

Atomics.wait(view, 0, value, timeout);   // futex-like wait
Atomics.notify(view, 0, count);          // wake up waiters
```

Atomics provide synchronization primitives equivalent to those in C/Rust:
- Atomic read/write.
- Compare-and-swap.
- Wait/notify (futex semantics).

This is enough to build mutexes, condvars, lock-free queues, etc. — at the cost of doing it correctly, which is non-trivial.

### The Spectre / cross-origin isolation issue

SharedArrayBuffer + high-resolution timers can be used to construct timing side-channel attacks (Spectre). Browsers disabled it; later re-enabled with restrictions.

To use SharedArrayBuffer in browsers, the page must:
- Set `Cross-Origin-Opener-Policy: same-origin`.
- Set `Cross-Origin-Embedder-Policy: require-corp`.

This isolates the page from cross-origin resources. Many sites haven't adopted these headers; SharedArrayBuffer is unavailable.

In Node, no such restriction; SharedArrayBuffer always available.

### Use cases

**Image / video processing.**
Large pixel manipulation in workers; main thread keeps UI responsive. Photoshop-on-the-web, Figma, and similar products use this heavily.

**ML inference.**
TensorFlow.js can run models in workers (or with WebAssembly + workers + SharedArrayBuffer for parallelism within the model).

**Cryptography / hashing.**
Heavy crypto work shouldn't block UI; offload to worker.

**Large data parsing.**
Parsing huge JSON, CSV, XML files. Worker parses; main thread receives parsed results.

**Streaming / pipelines.**
Worker handles a stage of processing; pipeline of workers via MessageChannels.

**Parallel computation.**
N workers compute partitions of a problem; main thread aggregates. Embarrassingly parallel work.

### What workers can't do

- **Direct DOM access** (browser): the worker has no document.
- **Shared regular objects**: only via postMessage or SharedArrayBuffer.
- **Synchronous communication with main**: `postMessage` is async.
- **Loop the main thread**: the parent decides when to react to worker messages.

### Worker pools

For variable parallelism, maintain a pool of workers; assign tasks as workers become free.

```js
class WorkerPool {
    constructor(size) {
        this.workers = Array.from({length: size}, () => new Worker('./worker.js'));
        this.queue = [];
        this.idle = [...this.workers];
    }
    
    async run(task) {
        return new Promise((resolve) => {
            const job = { task, resolve };
            if (this.idle.length > 0) {
                this.assign(this.idle.pop(), job);
            } else {
                this.queue.push(job);
            }
        });
    }
    
    assign(worker, job) {
        worker.onmessage = (e) => {
            job.resolve(e.data);
            const next = this.queue.shift();
            if (next) this.assign(worker, next);
            else this.idle.push(worker);
        };
        worker.postMessage(job.task);
    }
}
```

Production patterns are more elaborate (error handling, worker termination, etc.). The pool ensures bounded resource usage.

### WebAssembly + workers + SharedArrayBuffer

The combination enabling near-native parallel computation in the browser:

- WASM module compiled with threading support.
- Multiple workers each running the same module.
- Workers share memory via SharedArrayBuffer.
- Atomics provide synchronization.

Used by: Adobe Photoshop on the web; Figma; several ML frameworks.

The tooling is complex (wasm-pack, Emscripten threading); the result is performance comparable to native applications.

### Service Workers (separate concept)

A specialized worker that intercepts network requests for offline-first PWAs. Not used for CPU parallelism. Different lifecycle (registered with the browser; survives across page loads). Uses similar message-passing model.

---

## Real Engineering Analogies

**The kitchen with prep cooks.**
The head chef (main thread) plates and serves. Prep cooks (workers) chop, blend, prepare in the back. They communicate via order tickets and a pickup window. The chef stays focused on customer-facing work; the cooks handle long tasks.

**The newsroom with photo editors.**
The reporter (main thread) writes the story; the photo editor (worker) processes images in a separate room. They exchange messages: "here's a photo, please retouch"; the editor returns a finished version. The reporter doesn't wait; they keep writing.

---

## Production Engineering Perspective

What goes wrong:

- **The over-eager worker.** Engineer creates a worker for every task, even trivial ones. Worker startup cost dominates. Performance worse than single-threaded. Mitigation: worker pools.
- **The forgotten worker.** Worker created; never terminated; resources leak. Mitigation: explicit `terminate()`; track lifetimes.
- **The serialization cost.** Large message between main and worker; postMessage's structured clone copies the data. Slower than expected. Mitigation: transferable objects; SharedArrayBuffer.
- **The shared-memory race.** Multiple workers update SharedArrayBuffer without synchronization. Bizarre bugs. Mitigation: Atomics; lock-free design; or simple worker pools without SharedArrayBuffer.
- **The cross-origin isolation surprise.** Code uses SharedArrayBuffer; deployed; headers not set; SharedArrayBuffer is undefined; broken in production. Mitigation: deploy COOP/COEP headers; test in production-like environment.
- **The blocking message handler.** Worker takes a long time per message; messages queue. If main thread expects timely response, it appears hung. Mitigation: bounded message processing time.

The senior engineer's habits:
- **Worker pools** for repeated work.
- **Transferable objects** for large binary data.
- **SharedArrayBuffer + Atomics** only when copying is too slow.
- **Explicit termination** of workers.
- **Profile** to ensure workers help.
- **Test with COOP/COEP** for browser deployment.

---

## Failure Scenarios

**Scenario 1 — The serialization cost.**
Engineer offloads JSON parsing to a worker. JSON is 50MB; postMessage takes 200ms to clone before the worker even starts. Net result: worker is slower than main-thread parsing. Mitigation: transferable ArrayBuffer; or stream parsing with workers receiving chunks.

**Scenario 2 — The worker leak.**
Each user action spawns a new worker. Workers never terminated. Browser grows by 50MB per worker. After hours, tab is unusable. Mitigation: pool with max size; terminate when idle.

**Scenario 3 — The shared-memory bug.**
Two workers increment a shared counter via SharedArrayBuffer without atomics. Increments are lost. Counter is wrong. Mitigation: Atomics.add.

**Scenario 4 — The COEP-broken deploy.**
Site uses SharedArrayBuffer; deploys; COEP not configured; SharedArrayBuffer is now undefined; site breaks. Mitigation: header management in deploy pipeline; canary testing.

**Scenario 5 — The CPU-heavy main thread.**
Engineer thinks "we have a worker"; uses it for one task; main thread still has heavy regex on UI events. UI still freezes. Mitigation: identify *all* CPU-heavy paths; offload each.

---

## Performance Perspective

- **Worker startup**: ~5-50ms in browsers; ~10-50ms in Node.
- **postMessage with structured clone**: scales with data size; memory copy.
- **Transferable**: zero-copy; fast.
- **SharedArrayBuffer**: direct memory access; fastest.
- **Atomics overhead**: ~10-50ns per operation; comparable to native.

---

## Scaling Perspective

- **Browser**: typically 4-16 workers practical; one per CPU core.
- **Node**: similar; tune to CPU count.
- **At scale**: workers + clustering (Node) or workers + multiple tabs (browser, rare).

---

## Cross-Domain Connections

- **Event loop**: each worker has its own. (See [event-loop-and-async-runtime.md](./event-loop-and-async-runtime.md).)
- **V8 internals**: each worker is a separate isolate. (See [v8-internals-and-hidden-classes.md](./v8-internals-and-hidden-classes.md).)
- **Node.js architecture**: worker_threads are integrated into Node. (See [nodejs-architecture-and-libuv.md](./nodejs-architecture-and-libuv.md).)
- **Locks**: Atomics provide low-level synchronization for SharedArrayBuffer. (See [locks-mutexes-and-lock-free.md](../concurrency/locks-mutexes-and-lock-free.md).)
- **Parallelism vs concurrency**: workers add parallelism. (See [parallelism-vs-concurrency.md](../concurrency/parallelism-vs-concurrency.md).)

The unifying observation: **Web Workers and Worker Threads are JavaScript's controlled retreat from single-threaded simplicity. The retreat is bounded: workers don't share regular state; communication is explicit; parallelism is opt-in. The result is most of the simplicity of single-threaded JS with most of the performance of multi-threaded native code, when used correctly.**

---

## Real Production Scenarios

- **Figma's collaborative editor**: extensive worker use for rendering, collaboration sync, etc. Public engineering posts.
- **Google Docs**: heavy use of workers for spreadsheet calculations.
- **TensorFlow.js**: WebGL backend + workers for ML inference.
- **Photoshop on the web (Adobe)**: heavy WebAssembly + workers + SharedArrayBuffer.
- **Node.js worker_threads in production**: ML inference, image processing, crypto offload.

---

## What Junior Engineers Usually Miss

- That **workers don't share regular objects**.
- That **postMessage copies** by default; transferable objects don't.
- That **SharedArrayBuffer requires COOP/COEP** in browsers.
- That **Atomics are needed** for safe shared-memory access.
- That **worker startup has cost**; pools are usually right.
- That **DOM access** is unavailable in workers.
- That **terminate workers** explicitly.

---

## What Senior Engineers Instinctively Notice

- They **use worker pools** for repeated work.
- They **prefer transferable** over copy for large data.
- They **reach for SharedArrayBuffer** only when needed.
- They **profile** to verify workers help.
- They **bound message size** to keep clone cost reasonable.
- They **handle errors** in workers.
- They **terminate idle workers**.

---

## Interview Perspective

What gets tested:

1. **"What's a Web Worker?"** Tests basic literacy.
2. **"How do main thread and worker communicate?"** postMessage; structured clone.
3. **"What's transferable vs cloned?"** Ownership move vs copy.
4. **"What's SharedArrayBuffer?"** Shared memory between contexts.
5. **"Why are atomics needed?"** Race conditions on shared memory.
6. **"When to use a worker?"** CPU-heavy work that would block the main thread.
7. **"What can't a worker do?"** No DOM access in browser; no synchronous main-thread call.

Common traps:
- Believing workers share regular objects.
- Forgetting postMessage's copy cost.
- Not knowing about COOP/COEP.

---

## 20% Knowledge Giving 80% Understanding

1. **Workers are separate execution contexts**, no shared regular state.
2. **Communication via postMessage** with structured clone or transfer.
3. **Transferable objects** zero-copy.
4. **SharedArrayBuffer** for shared memory; Atomics for synchronization.
5. **COOP/COEP headers** required in browsers for SharedArrayBuffer.
6. **Workers add parallelism**, not concurrency within.
7. **Pool workers** to amortize startup.
8. **Use for CPU-heavy work**; not necessary for I/O.
9. **Terminate workers** explicitly when done.
10. **DOM unavailable** in browser workers.

---

## Final Mental Model

> **Web Workers and Worker Threads are JavaScript's hedge against the limits of single-threaded execution. The model preserves most of the simplicity that made JS popular while adding parallelism for the cases that genuinely need it. Used right, you keep the UI responsive while crunching megabytes of data. Used wrong, you pay startup costs without speedup, or you introduce race conditions that JS programmers are not used to debugging.**

The senior JS engineer reaches for workers when CPU-heavy work threatens UI responsiveness or service throughput. They use pools. They prefer transferable objects. They reach for SharedArrayBuffer only when measured copies are too slow. They preserve the JavaScript simplicity within each worker while parallelizing across workers.

Most JS code doesn't need workers. The cases that do are increasingly important: image editing, ML, data analysis, collaborative editing. The model is well-designed; the discipline of using it correctly is the difference between scaling out smoothly and discovering new failure modes.

That's Web Workers. That's Worker Threads. That's how JavaScript handles parallelism without becoming a multi-threaded race-condition jungle — and the foundation under every browser-based application that does serious computation.
