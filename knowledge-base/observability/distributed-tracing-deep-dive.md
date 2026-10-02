# Distributed Tracing — A Deep Dive

> *"Logs tell you what one service did. Metrics tell you what all services did, in aggregate. Traces tell you what happened together — the causal chain through a system that no single component could have shown you. In a microservices world, traces are not nice to have. They're how you debug at all."*

---

## Topic Overview

Distributed tracing answers a question that nothing else in your observability stack can: *for this specific request, what happened across every service it touched, in what order, and how long did each step take?* Without it, debugging "why was that request slow?" in a microservices architecture is archaeology — piecing together logs from 12 services, hoping the timestamps line up, hoping you can identify the customer's request in each.

The conceptual model — a tree of *spans* representing units of work, linked by trace and parent IDs — is simple. The engineering work is everything around it: context propagation across boundaries, sampling at scale, span aggregation, storage, query, integration with logs and metrics. A poorly-instrumented system produces traces that are full of holes, exactly where you need them most. A well-instrumented system produces traces that show you the bug before you finish reading the alert.

This is the topic where instrumentation becomes architecture. Distributed tracing is not a vendor product — it's a *design property* of a system, baked in via libraries, conventions, and discipline. Like APIs, like idempotency, like timeouts, it's part of the foundation that makes everything else operable.

---

## Intuition Before Definitions

Imagine following a single package through a global shipping network.

It's picked up from a customer's house, taken to a sorting facility, loaded onto a truck, driven to an airport, flown to another country, sorted again, transferred to a regional facility, loaded onto a delivery truck, and finally dropped at the recipient's door.

Each step is logged separately by the people involved. The driver knows when they picked it up. The sorting facility knows when it arrived and left. The airport knows the flight. But no single one of them can tell you "your package is 3 days late because the flight from Frankfurt to Dubai was delayed 4 hours, which caused it to miss the connecting flight to Singapore."

To answer that, someone needs to *aggregate the logs*, joined by the package's tracking number, ordered by timestamp. That's a trace. The tracking number is the *trace ID*. Each individual log is a *span*. The hierarchy (sorting facility → flight → connecting flight) is the parent-child relationship of spans. The visualization that shows you the full journey, with delays highlighted, is what trace UIs do.

Distributed tracing is exactly this for software requests. Each service is a "facility" handling part of the journey. The trace ID travels with the request through every service. Each service emits spans for its work. The trace UI joins them all, shows the timeline, highlights bottlenecks. *That* is how you debug "why was this request slow."

---

## Historical Evolution

**Era 1 — Logs and grep.**
Engineers tailed logs across servers. "Did request X reach service Y?" Search the logs. Slow, error-prone, didn't scale past a few services.

**Era 2 — Google Dapper.**
Google's internal tracing system, described in the 2010 paper "Dapper, a Large-Scale Distributed Systems Tracing Infrastructure." First major public articulation of distributed tracing at scale. Sampling, span aggregation, low-overhead instrumentation. The blueprint for everything that followed.

**Era 3 — Zipkin and Jaeger.**
Twitter open-sources Zipkin (2012). Uber open-sources Jaeger (2015). The first widely-deployed open-source tracing systems. UI patterns (waterfall views), span APIs, storage backends standardized.

**Era 4 — OpenTracing and OpenCensus.**
Two competing standards (2016, 2017). Both attempts to provide vendor-neutral instrumentation. Caused fragmentation; libraries had to support both.

**Era 5 — OpenTelemetry.**
The merger (2019). OpenTracing + OpenCensus → OpenTelemetry. Single standard for traces, metrics, and logs. Vendor-neutral SDKs, semantic conventions, language coverage. Industry adoption rapid; almost every major observability vendor speaks OTel today.

**Era 6 — Tail sampling and high-cardinality storage.**
Modern systems support tail-based sampling (decide what to keep after the request finishes), which preserves slow and erroring requests at high fidelity. Storage backends (ClickHouse, Tempo, Honeycomb) optimize for high-cardinality span querying. The era of "1% sampled, hope you got the bug" gives way to intelligent sampling.

The pattern: each generation extended what could be observed and made it cheaper to observe at scale. Tracing went from "manual log correlation" to "automatic, sampled, queryable, integrated with logs and metrics."

---

## Core Mental Models

**1. A trace is a tree.**
The root span represents the top-level operation (an incoming HTTP request). Each child span is a sub-operation. The tree shows causality and timing. Reading a trace is reading a system's behavior for one request.

**2. Context propagation is the entire game.**
A missing trace context propagation breaks the tree. Half the request shows up; the other half is invisible. Universal propagation discipline — in HTTP, in Kafka, in gRPC, in async work — is what makes tracing useful.

**3. Sampling is a cost-vs-completeness tradeoff.**
At scale, capturing every span is too expensive. Sampling decides what to keep. Smart sampling (tail-based, error-biased) is dramatically more useful than naive head sampling.

**4. Traces, logs, and metrics are three views of the same events.**
The trace shows causality. The metric shows trend. The log shows detail. Stitching them together — by trace ID — turns three separate signals into one coherent debug session.

**5. The point of tracing is debugging.**
Don't optimize the tracing setup for things you can already do with metrics. Optimize for "I have a slow request; I need to find the bottleneck across services." That's the irreplaceable use case.

---

## Deep Technical Explanation

### Span anatomy

A span represents a unit of work:

```json
{
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "parent_span_id": "06b41fa3a3b51b59",
  "name": "GET /api/orders/{id}",
  "kind": "SERVER",
  "start_time": "2026-05-09T14:23:45.123Z",
  "end_time": "2026-05-09T14:23:45.382Z",
  "attributes": {
    "http.method": "GET",
    "http.status_code": 200,
    "user.id": "u-12345",
    "db.statement": "SELECT * FROM orders WHERE id = ?"
  },
  "events": [
    { "time": "...", "name": "cache_miss" },
    { "time": "...", "name": "db_query_start" }
  ],
  "status": { "code": "OK" }
}
```

Key fields:
- **trace_id**: shared across all spans in the request (128-bit UUID).
- **span_id**: unique to this span (64-bit).
- **parent_span_id**: forms the tree.
- **start_time, end_time**: timing.
- **attributes**: arbitrary key-value tags.
- **events**: log-like entries within the span.
- **kind**: SERVER, CLIENT, INTERNAL, PRODUCER, CONSUMER.
- **status**: OK, ERROR, UNSET.

### Context propagation — the W3C standard

The trace context flows in HTTP headers per the W3C Trace Context specification:

```
traceparent: 00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01
tracestate: key1=value1, key2=value2
```

Format of `traceparent`:
- `00`: version.
- `4bf92f3577b34da6a3ce929d0e0e4736`: trace ID.
- `00f067aa0ba902b7`: parent span ID.
- `01`: flags (sampled flag).

Every service receives `traceparent`, creates a child span, propagates a new `traceparent` (with its own span ID) to outbound calls. The chain is unbroken.

For non-HTTP transports:
- **gRPC**: standard metadata.
- **Kafka**: message headers.
- **AWS SDK**: context flows through SDK calls.
- **Async work**: context must be explicitly passed; this is where most propagation bugs live.

### Sampling strategies

**Head-based (decide at start):**
- **Probabilistic**: keep N% of traces uniformly. 1%, 0.1%, etc.
- **Rate-limited**: keep up to N traces per second per service.
- **Always-on for specific routes**: keep all health-checks dropped, all checkout flows kept.

Head sampling decisions propagate via the `sampled` flag in `traceparent` — once decided at the entry point, all downstream services honor the decision.

Pros: simple, low overhead.
Cons: misses interesting requests statistically (errors, slow requests are rare).

**Tail-based (decide after the request):**
- Collect *all* spans for *all* requests (briefly, in memory or buffered).
- After the request completes, decide whether to retain based on properties (errors, slow, important user, etc.).

Pros: keeps all interesting traces.
Cons: requires buffering all span data; more infrastructure; latency before final retention decision.

Most production systems do a combination: probabilistic head sampling for steady-state, tail sampling for errors and slow requests.

**Adaptive sampling:**
- Sampling rate adjusts based on traffic volume.
- Reserves storage budget for high-value traces.

### The waterfall view

The canonical trace UI is a *waterfall* — spans drawn as horizontal bars, indented by tree level, with start time on the X-axis.

```
[==================== GET /api/orders =====================]    250ms
   [== auth.verify ==]                                         15ms
   [============ db.query orders ============]                 180ms
       [====== db.query users ======]                          95ms
   [== cache.set ==]                                           8ms
```

The visualization makes problems obvious:
- A long bar = slow operation.
- Sequential bars where they should be parallel = optimization opportunity.
- Gaps = unaccounted time (instrumentation gap).
- A child span longer than its parent = clock skew or instrumentation bug.

Reading waterfalls is a skill. The first slow trace you debug teaches you to read every shape of bottleneck.

### Trace-log correlation

Best practice: every log line includes the current trace and span ID:

```json
{
  "timestamp": "...",
  "level": "ERROR",
  "service": "orders-api",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "span_id": "00f067aa0ba902b7",
  "message": "Database query failed: connection refused"
}
```

Now you can:
- See an error in logs → click the trace ID → see the trace with full context.
- See a slow trace → click the span → fetch logs from that exact span time window.

Without this correlation, traces and logs are two disconnected worlds. With it, debugging is fluid.

### Trace-metric correlation

Modern systems generate metrics *from* span data:
- **Request rate** by service: count of SERVER spans.
- **Latency distribution** by service: distribution of SERVER span durations.
- **Error rate** by service: count of spans with ERROR status.

Single source of truth for "what happened"; multiple views derived. Honeycomb's "wide event" model is the cleanest expression of this idea.

### Span links

Some causal relationships aren't parent-child. Examples:
- A batch operation triggered by 100 separate inputs — the batch span has 100 *links* to its source spans.
- An async retry — the retry span links to the original.
- A queue consumer — links to the producer span.

Links are non-tree relationships preserved in the trace data. UIs visualize them as additional lines.

### Errors and the status field

Best practice:
- **Set span status to ERROR** when the operation failed.
- **Add an exception event** with the error type and message.
- **Add attributes** for the failure reason (`error.code`, `error.kind`).

This lets queries find traces with errors, count error rates per service, identify recurring failure modes. Just throwing exceptions and catching them isn't enough — explicit instrumentation is required.

### Async work

The hardest part of tracing. When work is enqueued for later processing:
- The producer creates a span ending at "enqueued."
- The consumer, when it processes, creates a child span — but parent is *temporally* in the past.
- The trace tree spans wall-clock seconds, hours, or days.

Many systems represent this with span links rather than parent-child to avoid weird visualizations. The tradeoff between fidelity (real parent-child) and ergonomics (links keeping wall-clock UI sane) is a design choice.

### Tracing in practice

Modern stacks:
- **Auto-instrumentation** via OpenTelemetry agents/SDKs hooks into HTTP, database, gRPC, queue libraries automatically.
- **Manual instrumentation** for business-specific spans (e.g., "validate cart contents," "compute shipping cost").
- **Semantic conventions** (OTel) standardize attribute names: `http.method`, `db.system`, `messaging.system`.

Coverage matters: if even one service in a request path is uninstrumented, the trace has a gap. Discipline of "every service emits and propagates" is mandatory.

---

## Real Engineering Analogies

**The hospital chart for one patient.**
A patient goes through admission, triage, doctor visit, lab tests, imaging, prescription, discharge. Each step is performed by a different department. Without a chart that follows the patient and accumulates findings, no one can answer "why has this patient been here for 6 hours?"

The patient's chart is a trace. Each department's notes are spans. The hospital's discipline of always-update-the-chart is the propagation rule. Hospital systems that get this wrong have patients lost in the system; same for software.

**The detective's case file.**
Multiple officers investigate different aspects of a case — interviews, forensics, surveillance, records. The case file unifies their findings. Each is timestamped, identified by case number, organized chronologically. A skilled detective reads the file and constructs a timeline. The file is the trace; the case number is the trace ID; the officers' notes are the spans.

---

## Production Engineering Perspective

What goes wrong:

- **The trace gap.** Service B doesn't propagate `traceparent`. Service B's children appear as new traces unrelated to the parent. The waterfall shows the path before B; everything after is invisible. Fix: enforce propagation in shared HTTP libraries.
- **The orphaned span.** An async worker creates a span without parent context. It floats unconnected. Fix: explicit context handoff when enqueueing async work.
- **The cardinality explosion in attributes.** A team adds `user_id` as a span attribute. Trace storage costs blow up. Fix: cardinality-aware attribute selection; user IDs in logs/searchable attributes, not as primary span tags.
- **The unsampled debugging session.** Customer reports issue. The trace for their request was sampled out at 1% rate. No trace exists. Fix: tail sampling that preserves errors; user-ID-based sticky sampling for VIPs.
- **The sampling decision lost downstream.** Service A samples in. Service B doesn't honor the `sampled` flag, makes its own decision. Inconsistent traces. Fix: respect `traceparent` flag everywhere.
- **The clock skew anomaly.** Two services' clocks differ by 50ms. Span timing shows child ending before parent starts. Confusion. Fix: NTP synchronization; tracing tools that handle small skews gracefully.
- **The tracing infrastructure as a single point of failure.** Tracing backend goes down. Application becomes slow because it's blocking on flush calls. Fix: async, non-blocking trace export; circuit breakers around the tracing client.
- **The PII leak.** Span attributes include sensitive data (passwords in URLs, credit card numbers in payloads). Tracing storage is now PII-bearing. Fix: redaction at instrumentation time; treat trace storage as a regulated data source.

The senior engineer's habits:
- **Auto-instrument** for breadth; manually instrument business-critical paths for depth.
- **Propagate everywhere**: HTTP, gRPC, queues, async work.
- **Tail sample errors and slow requests**.
- **Correlate with logs** via trace ID in every log line.
- **Watch for trace gaps** as instrumentation bugs.
- **Redact sensitive attributes** at instrumentation time.
- **Treat tracing as a product** — onboarding new services to it is a checklist.

---

## Failure Scenarios

**Scenario 1 — The trace gap mystery.**
A user-reported slow request: 800ms. Trace shows 200ms in service A, then a gap of 600ms before service A returns. No spans in the gap. The team spends 2 hours guessing. Discovery: a third-party SDK was making outbound HTTP calls without OTel auto-instrumentation. Fix: explicit instrumentation of the SDK; trace shows the actual culprit (external API timeout).

**Scenario 2 — The 1% sampling bug.**
A subtle bug occurs in 0.1% of requests. With 1% sampling, the bug is in 0.001% of *traces*. The team gets one or two relevant traces per day; insufficient signal to debug. Fix: enable tail sampling; keep all error traces; bug surfaces immediately.

**Scenario 3 — The async tracing debacle.**
A queue-based architecture: producer service enqueues; consumer processes. No context propagation through the queue. Each consumer-side execution is a new trace, unconnected. Debugging "why did this user's order fail?" requires manual correlation of messages. Fix: trace context in message headers; consumer span linked to producer.

**Scenario 4 — The PII in spans.**
A team adds query parameters as a span attribute for debugging. URLs contain auth tokens. Tokens are now in the tracing system, exported to a third-party service. Security incident. Fix: explicit allowlist of attributes; redaction layer.

**Scenario 5 — The infinite trace.**
A bug causes a service to retry infinitely on a specific failure. Each retry creates a child span. The trace grows unbounded. Storage blows up. Trace UI hangs trying to render. Fix: span count limits per trace; circuit breakers preventing retry storms.

---

## Performance Perspective

- **Span creation** is microseconds at full fidelity.
- **Context propagation** is essentially free at runtime (header read/write).
- **Span export** has latency — typically batched and async to avoid request-path blocking.
- **Sampling** is the primary cost lever.
- **Trace storage** scales with span volume. Kept-trace volume × retention drives cost.

---

## Scaling Perspective

- **Vertical**: trace backends scale to thousands of services.
- **Horizontal**: distributed trace storage (Tempo, Jaeger w/ Cassandra). High-cardinality columnar stores increasingly preferred.
- **Geographic**: regional collectors with cross-region aggregation.
- **At hyperscale**: Google's Dapper, Facebook's Canopy, Twitter's Zipkin — all custom systems handling petabyte-scale span volumes.

---

## Cross-Domain Connections

- **Observability metrics, logs, traces**: tracing is one of three pillars; integration with the others is essential. (See [metrics-logs-traces.md](./metrics-logs-traces.md).)
- **API design**: trace context propagation is part of every API contract. (See [api-design-rest-vs-grpc.md](../architecture-patterns/api-design-rest-vs-grpc.md).)
- **Cascading failures**: traces are the diagnostic for "where in the service graph did this start?" (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)
- **Sagas**: the saga's execution is a trace; tooling like Temporal exposes saga histories that look exactly like distributed traces. (See [saga-pattern-and-distributed-transactions.md](../architecture-patterns/saga-pattern-and-distributed-transactions.md).)
- **Backpressure**: queue depths and consumer lag — tracing through async work makes this visible. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Distributed consistency**: traces visualize the actual ordering of events across services, useful for debugging consistency-model issues. (See [cap-consistency-and-replication.md](../distributed-systems/cap-consistency-and-replication.md).)

The unifying observation: **distributed tracing is the *only* observability tool that respects causality across service boundaries.** Logs and metrics are per-service; traces are per-request, end-to-end. Every other observability artifact is enhanced by trace context.

---

## Real Production Scenarios

- **Google's Dapper paper (2010)**: foundational reference. Sampling, span aggregation, low-overhead instrumentation.
- **Uber's Jaeger**: born from operational pain. Public engineering posts on instrumentation discipline at microservice scale.
- **Netflix's Edgar**: internal trace + log aggregator. Public talks describe the integration patterns.
- **Honeycomb's wide event model**: tracing as the *primary* observability primitive, with metrics and logs derived. Counter-narrative to three-pillar approach.
- **OpenTelemetry adoption**: industry standardization; almost every major observability vendor and SDK supports it.
- **Stripe's distributed tracing**: large-scale public engineering on context propagation, sampling decisions, and trace-driven debugging.

---

## What Junior Engineers Usually Miss

- That **a missing propagation breaks the trace** entirely.
- That **head sampling at 1% misses interesting traces**.
- That **trace IDs in log lines** is the highest-leverage instrumentation choice.
- That **async work needs explicit context handoff**.
- That **span attributes can become PII**.
- That **clock skew across services** can confuse traces.
- That **auto-instrumentation gives breadth; manual gives depth**.
- That **traces visualize causality** — a different signal than logs or metrics.

---

## What Senior Engineers Instinctively Notice

- They **demand context propagation** in shared libraries.
- They **prefer tail sampling for errors and slow requests**.
- They **correlate traces with logs** via trace IDs.
- They **manually instrument business-critical paths**.
- They **watch for trace gaps** as instrumentation bugs.
- They **size trace storage** based on retention and sample rate.
- They **redact sensitive data** at instrumentation time.
- They **read waterfalls fluently** — bottleneck detection is muscle memory.

---

## Interview Perspective

What gets tested:

1. **"What's a span?"** Tests basic literacy. Bonus for explaining the tree structure.
2. **"What's context propagation?"** Tests practical understanding. Headers; W3C Trace Context.
3. **"How would you sample traces?"** Senior answer: tail sampling for errors and slow requests; head sampling for steady state.
4. **"How do traces, logs, and metrics relate?"** Different views; correlation via trace ID.
5. **"How do you debug 'why is this request slow'?"** Trace; waterfall; identify the slow span; drill into logs from that span's time window.
6. **"What goes wrong with async tracing?"** Context propagation through queues; parent-child semantics with wall-clock gaps.
7. **"How do you design tracing for new services?"** OTel SDK + auto-instrumentation; semantic conventions; trace IDs in logs; manual spans for business logic.

Common traps:
- Believing 1% sampling is enough.
- Not propagating through async work.
- Adding high-cardinality data as attributes.
- Treating tracing as optional infrastructure.

---

## Worked Example — Debugging a Slow Customer Request

A customer reports: "Yesterday at 14:23 UTC, my checkout was slow." Walk through using traces to find the cause.

### Step 1: Find the trace

The application logs every request with the customer's user_id and the trace_id:

```json
{"timestamp": "2024-...T14:23:18Z", "level": "INFO", "user_id": "u-12345",
 "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736", "endpoint": "/checkout"}
```

Searching logs by user_id at 14:23 → trace_id obtained.

### Step 2: Open the trace in the UI (Jaeger / Honeycomb / Tempo)

The waterfall view shows:

```
[============================================ POST /checkout (4823ms) ====]
  [== validate_session (8ms) ==]
                                [== fetch_cart (15ms) ==]
                                                       [================== reserve_inventory (3812ms) =====]
                                                                                                            [===== charge_payment (350ms) ===]
                                                                                                                                              [== send_confirmation (640ms) ==]
```

The slow span is `reserve_inventory` at 3812ms.

### Step 3: Drill into the slow span

Click `reserve_inventory` to see its child spans:

```
reserve_inventory (3812ms)
  ├── http POST inventory-svc /reserve (3800ms)        ← slow!
  ├── audit_log_write (5ms)
  └── span_overhead (7ms)
```

The HTTP call to inventory-svc dominated. Drill in:

```
http POST inventory-svc /reserve (3800ms)
  - http.method: POST
  - http.url: https://inventory-svc/api/v1/reserve
  - http.status_code: 200
  - peer.service: inventory-svc
  - retry.count: 0
  - net.duration_ms: 3800
```

So the request reached inventory-svc and got 200, but took 3.8s. The trace continues into inventory-svc (because the trace context propagated):

```
inventory-svc: handle_reserve (3795ms)
  ├── auth_check (5ms)
  ├── db.SELECT items_lock (3700ms)              ← slow!
  ├── decrement_inventory (40ms)
  └── publish_event (50ms)
```

The slow span is the database query: `SELECT items_lock`. Drill in:

```
db.SELECT items_lock (3700ms)
  - db.system: postgresql
  - db.statement: SELECT * FROM inventory_items WHERE item_id IN (...) FOR UPDATE
  - db.peer: inventory-db-primary
  - db.lock_wait_ms: 3650
```

`db.lock_wait_ms` is annotated by the application instrumentation. We waited 3.65 seconds for a lock.

### Step 4: Pivot to logs

Click the trace_id; jump to logs from inventory-svc and the database during that 3.7-second window:

```
14:23:14 [inventory-svc] DEBUG attempting lock on items [42, 87, 103]
14:23:14 [postgres] LOG long-running query started: txid 9001 holding locks on inventory_items
14:23:18 [postgres] LOG txid 9001 committed; locks released
14:23:18 [inventory-svc] DEBUG lock acquired
```

A different transaction (txid 9001) was holding the locks for ~4 seconds. Why?

### Step 5: Find txid 9001

Search logs for `txid 9001`:

```
14:23:14 [inventory-svc-batch-import] INFO txid 9001 starting bulk import; 50000 rows
14:23:18 [inventory-svc-batch-import] INFO txid 9001 completed; 4012ms
```

The batch-import service was running a bulk operation that held locks. The customer's checkout waited for it.

### Step 6: The fix

Several options:
1. **Smaller batches**: import 1000 rows at a time, releasing locks between.
2. **Lock-free import**: write to a staging table; merge with row-level locks.
3. **Schedule batches off-peak**: avoid contention with checkout.
4. **Use SELECT ... FOR UPDATE SKIP LOCKED**: customer's request skips locked rows; eventual consistency where acceptable.

The team picks option 1: smaller batches. Deploys. Customer's checkout latency normal again.

### What this teaches

Without distributed tracing:
- Logs would have shown the slow query, but with no causal context.
- The team would have spent hours guessing.
- The cross-service nature (checkout-svc → inventory-svc → DB) would have been invisible.

With distributed tracing:
- 30 seconds to identify the slow span.
- 60 seconds to pivot to logs and find the culprit.
- Total diagnosis: ~5 minutes.

This is the killer feature. Tracing exists for exactly this debugging session.

### Reference architecture — production tracing pipeline

```
[Service A] ──────► [OTel SDK] ──┐
                                  │
[Service B] ──────► [OTel SDK] ──┤
                                  │
[Service C] ──────► [OTel SDK] ──┤
                                  │
[Database]  ──────► [OTel SDK] ──┘
                                   │
                                   ▼
                    ┌──────────────────────────┐
                    │   OTel Collector          │
                    │   - Batch                 │
                    │   - Tail-sampling         │
                    │   - Enrich                │
                    └─────────┬────────────────┘
                              │
                              ▼
                    ┌──────────────────────────┐
                    │   Trace storage           │
                    │   (Tempo / Jaeger / SaaS) │
                    │   Hot: 24h                │
                    │   Cold: 30d archived       │
                    └─────────┬────────────────┘
                              │
                              ▼
                    ┌──────────────────────────┐
                    │   UI (Grafana / Honeycomb)│
                    │   - Waterfall view        │
                    │   - Search by attributes  │
                    │   - Pivot to logs/metrics │
                    └──────────────────────────┘
```

---

## Recent Production References (2023-2024)

- **OpenTelemetry's continuing maturation (2023-2024)**: most major vendors have OTel-compatible ingest. Vendor lock-in reduced.
- **Tempo (Grafana)** for trace storage: documented scaling at petabyte-scale.
- **Honeycomb's wide-event query model**: continues to push the envelope on high-cardinality observability.
- **Datadog APM at scale**: documented case studies of production trace volumes.
- **eBPF-based tracing (Pixie, Parca)**: emerging zero-instrumentation observability.
- **AWS X-Ray's trace summarization**: AI-assisted root cause analysis.
- **Trace exemplars in metrics**: link from a metric anomaly to a representative trace.

---

## 20% Knowledge Giving 80% Understanding

1. **Trace = tree of spans** sharing a trace ID.
2. **Context propagation everywhere** — HTTP, gRPC, queues, async.
3. **W3C Trace Context** is the standard format.
4. **Tail sampling** for errors and slow requests; head sampling for steady state.
5. **Trace IDs in every log line.** Connects pillars.
6. **Span status field** marks errors explicitly.
7. **Waterfall view** is the diagnostic UI.
8. **Auto-instrumentation for breadth**; manual for depth.
9. **Async work** uses span links or careful parent-child.
10. **Redact sensitive attributes** at instrumentation.

---

## Final Mental Model

> **A trace is a single request's story, told across every service it touched. Without it, microservices debugging is mythology — guesswork dressed up as analysis. With it, the system explains itself, one span at a time.**

The senior engineer designing a new service makes tracing a checkbox of readiness — not metrics or logs alone. The instrumentation discipline (propagate everywhere, tag carefully, redact sensitively) is a cultural norm, not an individual choice. The result: when a 3am alert fires, a trace tells you which service was slow, which dependency was failing, which database query took longer than expected — in seconds, not hours.

Distributed tracing isn't infrastructure you add when you're "advanced." It's infrastructure you add *as soon as you have more than two services*. The cost compounds slowly; the benefit compounds quickly. Every team that has run microservices without tracing has stories. Every team that finally added it wonders how they lived without it.

That's distributed tracing. That's the request's journey, made legible. That's the one observability artifact whose absence is most visible — and most expensive — at exactly the moment you need it most.
