# Streams & Backpressure in Node.js

> *"Node's streams are the most powerful, most underused primitive in the standard library. They handle backpressure automatically — if you use them right. They blow up memory, lose data, or create silent deadlocks if you don't. The difference between using streams correctly and almost-correctly is the difference between scaling and crashing."*

---

## 🎯 Start Here — Intuition

> **In one line:** how to move huge amounts of data through your program a little at a time, so a fast sender can't drown a slow receiver in data it hasn't finished processing.
>
> **Analogy:** pouring water from a big jug into a small cup. You don't dump the whole jug at once — it overflows. You pour, watch the cup fill, and stop pouring until it drains. "Backpressure" is just the cup telling the jug "hold on, I'm full" — and the jug actually waiting.
>
> **Assumes you already know:** what a buffer/queue is and why an unbounded one is dangerous, and the basics of producers and consumers — build that intuition first in [`learn/architecture/message-queues.md`](../../learn/architecture/message-queues.md) and [`learn/architecture/event-driven-architecture.md`](../../learn/architecture/event-driven-architecture.md), *then* come back for the Node-specific depth.
>
> **Level:** this file is 🟡 leaning 🔴 overall (it's Node/JS-specialist depth with no beginner learning-path counterpart). Sections below are tagged. If the basics feel shaky, that tag is your signal to slow down — **you are not behind.**

---

## Topic Overview 🟢

A stream is data over time. Reading a 10GB file shouldn't load 10GB into memory; you process it in chunks. A network upload arrives bit by bit, not all at once; you handle each chunk as it lands. A response sent to a slow client should pause when the network can't keep up. Streams are the abstraction for all of this.

Node.js's stream API is one of the oldest pieces of the standard library, and one of the most consistently misused. Engineers who don't understand streams write code that works in development and falls over in production. Engineers who do can serve thousands of concurrent file downloads with a tiny memory footprint, transform multi-gigabyte data sets without touching disk, and pipe network sources to network sinks with automatic flow control.

The killer feature is *backpressure*: when the consumer is slower than the producer, streams automatically slow the producer. Done right, this is invisible. Done wrong, you've recreated unbounded buffering with all its OOM (Out Of Memory) consequences.

This is the topic that turns "I work with files in Node" into "I architect data pipelines in Node." The skill is the same primitive used for HTTP, file I/O (Input/Output), sockets, transformations, parsers — the backbone of any non-trivial Node application.

---

## Intuition Before Definitions 🟢

Imagine moving water through pipes from a reservoir to a town.

The naive approach: a giant truck that hauls all the water at once. You need a truck the size of the reservoir. You can't deliver any water until the truck is full. The town is thirsty meanwhile.

The streaming approach: a continuous pipe with a controlled flow. Water flows from reservoir to town in real time. No giant truck needed; throughput is the diameter of the pipe.

But the pipe has a problem: if the reservoir flows faster than the town can use, the storage tank in town overflows. So you put a valve at the source: when the tank gets full, the valve closes. The reservoir's pump idles. When the tank drains, the valve reopens.

That's a Node stream with backpressure. The pipe is the stream. The reservoir is the producer. The town is the consumer. The tank is the internal buffer. The valve is the backpressure mechanism.

Without the valve — without backpressure — a fast producer overruns a slow consumer. You either lose data, OOM, or fall behind forever. The discipline of using streams *with* backpressure is the discipline of letting the slow side throttle the fast side automatically.

---

## Historical Evolution 🟡

**Era 1 — Streams1 (Node 0.x).**
Original API, callback-driven. Hard to compose; many edge cases. Source of bugs.

**Era 2 — Streams2 (Node 0.10).**
Major redesign. Two reading modes: paused (`stream.read()`) and flowing (`'data'` events). Object mode added. Backpressure formalized.

**Era 3 — Streams3 (Node 0.12+).**
Refinements; `pipeline()` API in Node 10 for proper error propagation.

**Era 4 — Async iteration.**
Node 10+. Streams became async-iterable: `for await (const chunk of stream)`. Combined with async/await, dramatically improved ergonomics.

**Era 5 — Web Streams.**
Node 16+. The Web Streams API (originally browser) is supported alongside Node streams. Cross-platform code possible.

**Era 6 — Modern usage.**
Today's idiomatic Node uses `pipeline`, async iteration, and Web Streams where appropriate. Old `pipe()` patterns persist in legacy code.

The pattern: each generation made streams safer (better error propagation), more ergonomic (async iteration), and more standard (Web Streams). The fundamentals — backpressure, modes, types — have stayed.

---

## Deep Technical Explanation 🔴

⚠️ The rest assumes the basics above are solid.

### The four stream types

**Readable.** Produces data.
```js
const fs = require('fs');
const readable = fs.createReadStream('big-file.csv');
```

Examples: file reads, HTTP requests (server-side body), responses (client-side body), child process stdout.

**Writable.** Consumes data.
```js
const writable = fs.createWriteStream('output.csv');
```

Examples: file writes, HTTP responses (server-side), requests (client-side body), child process stdin.

**Duplex.** Both readable and writable, separate channels (e.g., a TCP (Transmission Control Protocol) socket — you write to send, read to receive).

**Transform.** Duplex where reads are derived from writes (compression, encryption, parsing).

### Object mode vs binary mode

**Binary mode (default):** chunks are `Buffer` or `Uint8Array`.
**Object mode:** chunks are arbitrary JavaScript values.

Object-mode streams power message-passing pipelines. CSV (Comma-Separated Values) parsers in object mode emit row objects. Serializers consume row objects. Composability is the point.

### Reading: pause vs flow

**Paused mode (default):**
```js
readable.on('readable', () => {
  let chunk;
  while ((chunk = readable.read()) !== null) {
    // process chunk
  }
});
```
You explicitly pull data. Backpressure is implicit (you control the rate).

**Flowing mode:**
```js
readable.on('data', chunk => {
  // process chunk
});
```
Data is pushed at you. Easier to write; harder to apply backpressure (need `pause()` and `resume()`).

The old `data` event API is the source of countless backpressure bugs.

### Writing and the drain event

`writable.write(chunk)` returns:
- `true`: keep writing.
- `false`: backpressure! Stop writing until `'drain'` event.

```js
function writeWithBackpressure(writable, chunk, callback) {
  if (!writable.write(chunk)) {
    writable.once('drain', callback);
  } else {
    callback();
  }
}
```

This is the *exact* mechanism backpressure depends on. The writable's internal buffer has a `highWaterMark` (default 16KB binary, 16 objects in object mode). When buffer is at the watermark, `write()` returns `false`. Continuing to write past `false` adds to the in-memory buffer unboundedly.

### `pipe()` and `pipeline()`

**`pipe()`:**
```js
readable.pipe(writable);
```

Connects readable to writable; backpressure propagates automatically. Errors do *not* propagate cleanly; both source and destination need separate error handlers; cleanup is manual.

**`pipeline()`** (modern, recommended):
```js
const { pipeline } = require('stream');
pipeline(
  readable,
  transform,
  writable,
  (err) => { if (err) console.error('Pipeline failed', err); }
);
```

Or with promises:
```js
const { pipeline } = require('stream/promises');
await pipeline(readable, transform, writable);
```

`pipeline` handles errors properly, cleans up correctly, and is the right API for production code. `pipe()` is legacy.

### Async iteration

Modern, ergonomic:
```js
for await (const chunk of readable) {
  await processChunk(chunk);  // backpressure: this slows the iteration
}
```

The `await processChunk` slows the loop, which automatically slows the readable. Backpressure via execution rate. Beautiful for many use cases.

```js
async function* upperCaseLines(input) {
  for await (const chunk of input) {
    yield chunk.toString().toUpperCase();
  }
}

await pipeline(input, upperCaseLines, output);
```

Async generators as transform streams: clean, expressive, correct.

### Transform streams

```js
const { Transform } = require('stream');

const upper = new Transform({
  transform(chunk, encoding, callback) {
    callback(null, chunk.toString().toUpperCase());
  }
});

await pipeline(input, upper, output);
```

The `transform` function is called per chunk; `callback(err, transformed)` signals completion. Backpressure handled by the framework.

### Common stream patterns

**File-to-file with transformation:**
```js
await pipeline(
  fs.createReadStream('input.csv'),
  parser,
  transformer,
  fs.createWriteStream('output.csv')
);
```

**HTTP request body to file:**
```js
http.createServer(async (req, res) => {
  await pipeline(req, fs.createWriteStream('upload.bin'));
  res.end('uploaded');
});
```

**Compressed download:**
```js
const gzip = zlib.createGzip();
http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Encoding': 'gzip' });
  pipeline(fs.createReadStream('big.txt'), gzip, res, (err) => {
    if (err) console.error(err);
  });
});
```

Zero-buffering, end-to-end streaming.

### Backpressure in action

A common bug:
```js
// Wrong: ignores write() return value
async function copyFile(src, dst) {
  const readable = fs.createReadStream(src);
  const writable = fs.createWriteStream(dst);
  for await (const chunk of readable) {
    writable.write(chunk);  // BUG: doesn't check backpressure
  }
  writable.end();
}
```

If `writable` is slow, `readable` keeps pumping. Memory grows. OOM.

The fix:
```js
// Right: pipeline handles backpressure
async function copyFile(src, dst) {
  await pipeline(fs.createReadStream(src), fs.createWriteStream(dst));
}
```

Or, if you must write manually:
```js
for await (const chunk of readable) {
  if (!writable.write(chunk)) {
    await new Promise(resolve => writable.once('drain', resolve));
  }
}
```

### The unbounded-buffer trap

Forgetting backpressure is exactly creating an unbounded queue. The producer fills the buffer faster than the consumer drains it. Memory grows monotonically. Eventually crash.

This is the same pattern as event loop blocking but in the buffer dimension. The fix is the same as in distributed systems: backpressure or load shedding.

### Object-mode streams in practice

A CSV-processing pipeline:
```js
await pipeline(
  fs.createReadStream('input.csv'),
  csvParse({ columns: true }),  // object mode: emits rows
  Transform.from(async function*(rows) {
    for await (const row of rows) {
      if (row.amount > 0) yield row;  // filter
    }
  }),
  csvStringify({ header: true }),  // back to text
  fs.createWriteStream('output.csv')
);
```

Each stage processes one row at a time; memory stays bounded; the pipeline is composable.

### Error handling

Stream errors must be handled. `pipeline` handles automatically:
```js
try {
  await pipeline(readable, transform, writable);
} catch (err) {
  console.error('Pipeline failed:', err);
}
```

Without `pipeline`, you must handle each stream:
```js
readable.on('error', handleError);
transform.on('error', handleError);
writable.on('error', handleError);
```

Forgetting any of these can crash the process on stream error.

---

## Real Engineering Analogies 🟢

**The river dam with floodgates.**
A river feeds a reservoir. The reservoir has floodgates that open and close. When the reservoir is high, gates close (slowing the river upstream — backpressure). When the reservoir drains (downstream demand), gates reopen.

That's exactly Node's stream backpressure. The river is your data source. The reservoir is the internal buffer. The gates are the `write()` returning false / drain event.

**The conveyor belt with sensors.**
A factory conveyor belt. Workers along the belt take items off. Sensors detect "the next worker has 5 items waiting" — slow the belt upstream. The belt's speed dynamically matches the slowest worker's rate.

Node streams + backpressure: same model. The slow consumer paces the entire pipeline.

---

## Production Engineering Perspective 🔴

What goes wrong:

- **The "I'll just `data` event it" memory leak.** Old code uses `data` events without checking backpressure. Under load, internal buffers grow; OOM. Fix: use `pipe()` or `pipeline()`.
- **The unhandled stream error.** Stream errors event; nothing listening; process crashes (or worse, hangs). Fix: handle errors at every stage; or use `pipeline()`.
- **The forgotten `end()`.** Writable created; data written; `end()` not called; readers wait forever. Fix: `pipeline` calls `end()` automatically.
- **The mixed sync/async write.** Code does `writable.write(...)` without checking return value, then `writable.end()`. Data may be queued; `end` waits for queue to drain; works in tests, fails under load.
- **The closure-captured-stream leak.** Long-lived closure captures a stream that should have closed. Stream's buffer never frees. Fix: explicit cleanup.
- **The transform that buffered everything.** Transform stream that doesn't respect backpressure (calls `push` repeatedly without honoring return value). Memory grows.
- **The pause without resume.** Stream paused (e.g., during error handling); never resumed; data never flows. Fix: `pipeline` handles this.

The senior Node engineer's habits:
- **Always use `pipeline`** for production stream code.
- **Async iteration** for transformation pipelines.
- **`Transform.from(async function*)`** for clean transforms.
- **Error handling** at every stage.
- **Memory monitoring** to catch backpressure failures.

---

## Failure Scenarios 🔴

**Scenario 1 — The OOM file copy.**
Engineer copies a 100GB file. Doesn't use `pipeline`. Writes synchronously without checking backpressure. Memory grows; process killed. Fix: switch to `pipeline`.

**Scenario 2 — The crashing HTTP server.**
Server reads request body via `data` events; pipes to processing logic; doesn't handle `error` event on the request stream. Client disconnects mid-upload; error event fires; uncaught; server crashes. Fix: error handlers; or `pipeline`.

**Scenario 3 — The slow client cascade.**
Server streams a large file to clients. One slow client triggers backpressure on its stream, which is fine. But code stored references to all clients' streams; backpressured streams retain memory. Many slow clients: memory grows. Fix: explicit cleanup of disconnected clients.

**Scenario 4 — The transform that looped forever.**
Custom transform stream had a bug where `_transform` called `push` infinitely without honoring backpressure. Never advanced. Pipeline froze. Memory grew. Fix: respect `push` return value.

**Scenario 5 — The pipeline that didn't.**
Code used `pipe()` (not `pipeline`); error in middle stream; source kept reading; nothing consumed; OOM. Recovery: switch all to `pipeline`.

---

## Performance Perspective 🟡

- **Stream overhead**: small per-chunk; depends on chunk size.
- **highWaterMark tuning**: too small = excessive yield; too large = more memory. 16KB is fine for most.
- **Object-mode overhead**: each "chunk" is one object. Tens to hundreds of microseconds per chunk; design accordingly.
- **Backpressure cost**: zero (or saved memory) when working; problematic when broken.

---

## Scaling Perspective 🟡

- **Vertical**: a single Node process can handle many concurrent streams.
- **Memory bounded by highWaterMark × concurrent streams.** Predictable.
- **Network streaming**: HTTP/2 (Hypertext Transfer Protocol version 2) multiplexing complements; many concurrent streams over one connection.
- **At hyperscale**: streaming pipelines for ETL (Extract, Transform, Load), data processing.

---

## Cross-Domain Connections 🟡

- **Backpressure**: streams are the in-process backpressure primitive. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Event loop**: streams cooperate with the event loop; chunk processing yields. (See [event-loop-and-async-runtime.md](./event-loop-and-async-runtime.md).)
- **Node.js architecture**: libuv handles the underlying I/O. (See [nodejs-architecture-and-libuv.md](./nodejs-architecture-and-libuv.md).)
- **Coroutines**: async iteration over streams is coroutine-based. (See [coroutines-and-green-threads.md](../concurrency/coroutines-and-green-threads.md).)
- **API design**: HTTP request/response are streams; streaming APIs design around them. (See [api-design-rest-vs-grpc.md](../architecture-patterns/api-design-rest-vs-grpc.md).)

The unifying observation: **streams are how Node handles data that doesn't fit in memory. Mastering them — including backpressure — is the difference between Node code that scales and Node code that crashes under realistic load.**

---

## Real Production Scenarios 🟡

- **Node's HTTP server**: every request and response is a stream. Backpressure is built in if you use `pipeline`.
- **Cloud storage SDKs (Software Development Kits) (AWS S3 (Amazon Web Services Simple Storage Service), Google Cloud)**: stream-based upload/download.
- **Media servers (Plex, Jellyfin)**: stream transcoded video.
- **Build tools (Webpack, Rollup)**: process source files as streams.
- **CSV processing libraries (csv-parse)**: heavy stream usage; documented patterns.

---

## Key Takeaways

- **Streams are time-ordered data, not space-bounded buffers.** A stream is an interface through which data flows; total data may exceed memory while the in-flight buffer stays small.
- **Four stream types:** Readable (source), Writable (sink), Duplex (both, separate channels), Transform (Duplex where reads derive from writes).
- **Two reading modes:** paused (pull via `read()`) vs flowing (push via `'data'` events). Switching modes mid-stream causes weirdness; `data` events without `pause`/`resume` ignore backpressure and are the source of countless bugs.
- **Backpressure is the safety discipline.** `write()` returns a boolean: `false` means stop writing until the `'drain'` event. Ignoring it builds an unbounded in-memory buffer and eventually OOMs. `highWaterMark` controls buffer size (default 16KB binary / 16 objects) and is a tunable.
- **`pipeline` over `pipe`.** `pipeline` propagates errors, cleans up, and calls `end()` automatically; `pipe()` has bad error semantics and is legacy.
- **Async iteration (`for await...of`)** is the modern, ergonomic idiom; `await`-ing per chunk applies backpressure via execution rate. `Transform.from(async function*)` gives clean, composable transforms.
- **Object mode** lets chunks be arbitrary JS values, powering message-passing/row-based pipelines (e.g. CSV → filter → CSV).
- **Errors must be handled at every stage** — an unhandled stream `error` crashes the process. `pipeline` handles this; manual piping does not.
- **`end()` must be called** on writables to signal completion, or readers wait forever.
- Senior habits: reach for `pipeline` + async iteration + small focused Transforms, and monitor memory to catch backpressure failures early.

## Interview angle

- **"How does backpressure work in Node streams?"** `write()` returns `false` at the `highWaterMark`; you wait for `'drain'`. `pipeline`/`pipe` propagate this automatically.
- **"Pipe vs pipeline?"** `pipeline` handles errors and cleanup; `pipe` does not cleanly.
- **"What happens if you ignore `write()`'s return value?"** Buffer grows unbounded; eventually OOM.
- **"What's a Transform stream?"** A Duplex stream where output is derived from input.
- **"How do you handle errors in a stream chain?"** `pipeline` (single catch), or per-stream `error` handlers.
- **"Paused vs flowing mode?"** Pull (`read()`) vs push (`'data'`).
- **"How do you compose stream transformations?"** A `pipeline` of Transforms or async generators.
- Common traps: `data` events without backpressure handling, forgotten error handlers, missing `end()`.
