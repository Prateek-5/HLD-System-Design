# Metrics, Logs & Traces — The Three Pillars of Observability

> *"You cannot fix what you cannot see. The depressing follow-up is: most production systems are designed to be fixed, not seen."*

---

## Topic Overview

Observability is the practice of asking arbitrary questions about your system's behavior *without* deploying new code. Monitoring is what you set up before the incident. Observability is what saves you during it. The difference is everything.

The three "pillars" — metrics, logs, and traces — aren't a complete framework. They're the three primary data shapes engineers have converged on for understanding running systems, each optimized for different questions. Metrics answer "what's the trend?" Logs answer "what happened?" Traces answer "what happened *together*?" A team without all three is debugging by candlelight.

This is the topic where most engineering teams underinvest until their first major outage, then overcorrect with a sprawling toolchain that nobody owns. The right framing isn't "what tools do we use?" — it's "what questions do we need to answer in 30 seconds at 3am?" The tooling falls out of that.

---

## Intuition Before Definitions

Imagine running an airline.

Your **metrics** are the dashboard in the operations center: number of flights in the air, average delay, fuel consumption per fleet, on-time percentage. Glance at it and you know whether the airline is healthy. You don't know *why* a particular flight is delayed.

Your **logs** are every individual record the system produces: takeoff confirmation for flight 247, fueling complete for flight 189, bag scanned at gate B12. Search them and you can reconstruct exactly what happened to a specific flight. But trying to spot a trend across millions of these is impossible — you'd be reading forever.

Your **traces** are the *journey* of a single passenger from check-in to baggage claim. Every step they took, every system that touched their booking, with timestamps. The trace tells you "Mrs. Patel's flight was delayed because she was a connection from a flight that landed late, which itself was delayed because gate availability was reshuffled by a thunderstorm in Chicago." You see the *causal chain*.

Each pillar answers a different shape of question:
- **Metrics**: "Is something off?" (high signal, low cardinality)
- **Logs**: "What exactly happened in that case?" (high detail, hard to aggregate)
- **Traces**: "Why was *this specific request* slow?" (causality across services)

The mature operator uses all three together. Metrics tell you something is wrong. Traces tell you which call path. Logs tell you the exception message. Without any one of them, debugging is much harder.

---

## Historical Evolution

**Era 1 — Print statements and tail -f.**
Logs were files on disk. Operators SSHed in and read them. Worked at one-server scale; collapsed at ten.

**Era 2 — Centralized logging.**
syslog, then log shippers (Logstash, Fluentd), then central stores (Elasticsearch, Splunk). The "ELK stack" (Elasticsearch + Logstash + Kibana) became canonical. Logs went from local files to searchable corpora.

**Era 3 — Time-series metrics.**
Nagios for alerting, Munin/Cacti for dashboards. Then Graphite (2008), then Prometheus (2012). The shift: metrics as a first-class data type, with a query language (PromQL) and a pull-based collection model. Suddenly you could ask "show me request rate per endpoint, broken down by HTTP status, over the last hour" and get an instant answer.

**Era 4 — Distributed tracing.**
Google's Dapper paper (2010) described their internal tracing system. Open-source followed: Zipkin (Twitter), Jaeger (Uber). The realization: in microservices, *no single log* tells the story; you need the request's journey across services, with parent/child spans linking them.

**Era 5 — OpenTelemetry.**
Multiple competing standards (OpenTracing, OpenCensus) merged into OpenTelemetry (2019), an industry-wide standard for instrumentation. Vendor-neutral SDKs, common semantic conventions. The data plane standardizes; the storage and analysis stay competitive.

**Era 6 — High-cardinality observability.**
Honeycomb's argument: pre-aggregated metrics lose the information you need at debug time. Instead, store *wide events* (every request, every relevant attribute) and let engineers slice arbitrarily at query time. The "three pillars" model is criticized as siloed; the alternative is "events as the unit, derive everything else."

The pattern across eras: each generation of tooling answered a question the previous generation couldn't. The current frontier is unifying the three pillars into a single coherent model, often with traces as the connective tissue.

---

## Core Mental Models

**1. Observability is a property of the system, not the tools.**
A system is observable if you can answer arbitrary questions about its behavior from its outputs. This is a *design property* — emitted by instrumentation choices, not bought from a vendor.

**2. The three pillars have different cost models.**
Metrics are cheap (pre-aggregated, bounded cardinality). Logs are expensive (variable, high volume, full-text indexed). Traces are *very* expensive at full fidelity (every span of every request). Sampling is non-negotiable for the latter two at scale.

**3. Cardinality is the unit of cost and value.**
Cardinality = number of unique combinations of attribute values. A metric tagged by `endpoint` (10 endpoints) is cheap. The same metric tagged by `user_id` (1M users) is *six orders of magnitude* more expensive. High cardinality is what lets you slice; high cardinality is also what breaks budgets.

**4. SLOs are the contract; SLIs are the measurement.**
SLOs (Service Level Objectives): "99.9% of requests served under 200ms." SLIs (Service Level Indicators): the metric that proves it. Error budgets are the implication: 0.1% failure is allowed; failures beyond that cost feature-velocity until the budget refills. This framework comes from Google SRE and has become industry standard.

**5. Most production debugging is "what is this customer's request doing?"**
Optimize for that question. Customer ID searchable in logs. Trace ID propagated everywhere. Timeline view across services. If a senior engineer can answer "why was customer X's request slow at 3:47pm?" in under a minute, your observability is working. If not, it isn't — regardless of dashboard count.

---

## Deep Technical Explanation

### Metrics

A metric is a *time series* — a value (or set of values) measured over time, indexed by labels.

```
http_requests_total{method="GET", endpoint="/users", status="200"} = 12543
http_requests_total{method="GET", endpoint="/users", status="500"} = 27
```

Types (Prometheus convention):
- **Counter** — monotonically increasing. Total requests, errors, bytes sent.
- **Gauge** — current value, can go up or down. Memory usage, queue depth, active connections.
- **Histogram** — bucketed distribution. Latency percentiles, request size distribution.
- **Summary** — pre-computed quantiles. Useful but harder to aggregate across instances.

Cost model: storage is `cardinality × resolution × retention`. A 10-label metric where each label has 10 possible values has 10^10 = 10 billion potential time series. Don't do that. Real systems must be cardinality-disciplined.

The right things to measure:
- **RED** (Rate, Errors, Duration) for services.
- **USE** (Utilization, Saturation, Errors) for resources.
- **The four golden signals** (Latency, Traffic, Errors, Saturation) per Google SRE.

Latency must be measured as a *distribution*, not an average. Averages hide tails. p50/p95/p99 are the canonical reporting triple.

### Logs

A log entry is a structured (or unstructured) record of an event. Modern best practice: **always structured**, JSON or similar, with semantic fields:

```json
{
  "timestamp": "2026-05-09T14:23:45.123Z",
  "level": "ERROR",
  "service": "payments-api",
  "trace_id": "4bf92f3577b34da6a3ce929d0e0e4736",
  "user_id": "u-12345",
  "endpoint": "/charge",
  "error": "card_declined",
  "duration_ms": 234
}
```

Why structured: queryability. Want all `card_declined` errors for `user u-12345` between 2pm and 3pm? With structured logs, that's a single query. With free-text logs, it's a `grep` + manual filtering nightmare.

Log levels:
- **DEBUG** — verbose, off in production.
- **INFO** — normal operations, sampled or rate-limited at scale.
- **WARN** — something unexpected but not failing.
- **ERROR** — operation failed, *something is wrong*.
- **FATAL** — process is dying.

Most log volume is INFO. Most diagnostic value is in WARN and ERROR. Volume management:
- **Sampling**: log a fraction of successful requests; log all errors.
- **Rate limiting**: cap log volume per service per minute.
- **Structured truncation**: drop large payload fields rather than the whole entry.

The cost trap: log volume scales with traffic. Free-text logs at 100K req/s with 1KB per request = 100MB/s = 8.6TB/day. Indexing all of it is expensive. Sample, structure, retain selectively.

### Traces

A trace is a tree (or DAG) of *spans*, each representing a unit of work, with timing and metadata.

```
Trace: req-abc123 (total: 432ms)
├── span: HTTP GET /api/orders (432ms)
│   ├── span: auth.verify (12ms)
│   ├── span: db.query orders (180ms)
│   │   └── span: db.query users (95ms)
│   └── span: cache.set (8ms)
```

Each span has:
- A **trace ID** (shared across all spans in the request).
- A **span ID** (unique to this span).
- A **parent span ID** (forms the tree).
- **Start/end timestamps**, duration.
- **Attributes** (HTTP method, DB query, custom tags).
- **Events** (log-like entries within a span).

The trace's superpower: showing the **critical path**. The 432ms request had a 180ms DB query inside it. *That* is where to look. Without traces, you'd see "p99 is 500ms" with no indication of where the time went.

**Context propagation** is the protocol that makes traces work across services. The trace ID is passed in HTTP headers (`traceparent` per W3C Trace Context), in Kafka message headers, in gRPC metadata. Every service receives the parent trace ID, creates child spans, and forwards the context onward. A single missing propagation breaks the trace tree.

Sampling is mandatory at scale. Common strategies:
- **Head sampling**: decide at request start (e.g., 1% of requests). Cheap; misses interesting cases (errors, slow requests) statistically.
- **Tail sampling**: collect all spans, decide after the request completes (keep all errors, all slow requests, sample the rest). More valuable; more infrastructure.

### The fourth pillar — events

A growing argument: metrics, logs, and traces all derive from a common substrate — the *wide event*. A single record per request, with every relevant attribute. Slice it for metrics, search it for logs, link it for traces. Honeycomb's model.

The tradeoff: storage and query cost vs. flexibility. Pre-aggregated metrics are cheap but rigid; wide events are expensive but answer questions you didn't anticipate. Modern systems often use both — wide events for *recent* data, aggregated metrics for *historical* trends.

### SLOs and error budgets

Define:
- **SLI (Indicator)**: a metric. "Fraction of requests returning 2xx within 200ms."
- **SLO (Objective)**: a target. "99.9% of requests over a 28-day window."
- **Error budget**: 1 - SLO. "0.1% of requests can fail." 28 days × 0.1% = ~40 minutes of budget per month.

When the error budget is full, ship features. When it's depleted, freeze releases until it refills. This single mechanism aligns reliability and feature velocity in a measurable way.

### The "USE" and "RED" methods

**USE (Brendan Gregg, for resources)**:
- **Utilization** — % time the resource is busy.
- **Saturation** — backlog (queue depth) for the resource.
- **Errors** — failure count.

Apply to CPU, memory, disk, network. Three numbers per resource.

**RED (Tom Wilkie, for services)**:
- **Rate** — requests per second.
- **Errors** — error rate or count.
- **Duration** — latency distribution.

Three numbers per endpoint or service. If you have these for every service and every dependency, you can answer most "what's wrong?" questions in seconds.

### Alerting

Alerts must be:
- **Actionable** — alerted human can do something.
- **Symptom-based** — "users are seeing errors" not "CPU is at 80%."
- **Tied to SLOs** — alert when error budget burn rate is fast.

Alert fatigue is a primary source of incident response failure. Teams that page on every CPU spike eventually ignore pages. Teams that page only on user-facing impact maintain alert respect.

---

## Real Engineering Analogies

**The hospital analogy.**
- **Vitals monitor (metrics)** — heart rate, blood pressure, oxygen saturation, updated continuously. You glance, you know if the patient is in trouble.
- **Patient chart (logs)** — every nurse note, every medication administered, every observation. Detailed, queryable, but you need a query (chart number, time range) to find what you want.
- **Surgical timeline (traces)** — for a specific procedure, the order of every step, who did what, how long it took. Tells you "the anesthesia took 5 minutes longer than usual; that's why the procedure ran late."

A doctor working a code blue uses all three: vitals to see the trend, chart to see history, surgical timeline to understand causality. Production engineers do the same.

**The nautical chart and ship's log analogy.**
- Charts (metrics) — current position, speed, heading.
- Ship's log (logs) — recorded events, mile by mile.
- Voyage replay (traces) — the journey of one specific cargo from origin to destination.

You can't navigate without the charts. You can't audit without the log. You can't debug without the journey.

---

## Production Engineering Perspective

What goes wrong in real observability:

- **Cardinality explosion.** A label like `user_id` on a metric. 10M users. 10M time series. Prometheus dies. Bill explodes. Mitigation: never put unbounded-cardinality fields on metrics; reserve them for logs/traces.
- **The dashboard graveyard.** Hundreds of dashboards, none of which the on-call engineer trusts. Created during onboarding, never maintained. The first task during incidents is "find the right dashboard." Better: a small set of golden dashboards owned by the team, plus query-driven exploration.
- **Trace gaps.** Context propagation missing in one service. The trace tree breaks. The debug session loses minutes. Fix: enforce trace propagation in shared libraries, audit periodically.
- **Logs without trace IDs.** Logs and traces are separate worlds. To debug, you query logs by user ID, then traces by request ID, manually correlating. Adding trace IDs to log lines (as a field) connects the worlds.
- **Alert fatigue.** Hundreds of alerts per day. On-call ignores most. The one that matters gets missed. Mitigation: cull aggressively, make alerts actionable, tie to SLOs.
- **Sampling that hides the problem.** 1% sampling on traces. The slow-request path was 0.5% of traffic. You see no traces for it. Fix: tail sampling that keeps slow and erroring requests.
- **Metrics that don't predict failure.** CPU at 60%, memory fine, and the service is failing. Why? Because the *real* saturation was a connection pool, a queue depth, an external dependency — not the obvious resource. Always measure saturation at the level your application's actual bottleneck lives.
- **Logs as the only signal.** A team with rich logs but no metrics tries to answer "what's our request rate?" by counting log lines. Slow, expensive, fragile. Metrics exist for this.
- **Tracing in dev, missing in prod.** A common deployment hazard — instrumentation that works locally but isn't sampled to the storage backend in production.

The senior engineer's habits:
- **Define SLOs explicitly** for every user-facing service.
- **Watch error budget burn rate** as the primary alerting signal.
- **Trace IDs in every log line.**
- **A handful of high-quality dashboards**, owned by the team.
- **Drills**: practice answering "why is customer X seeing slow responses?" in under a minute.
- **Cardinality audits**: periodically check what's in the metrics store and why.

---

## Failure Scenarios

**Scenario 1 — The cardinality bomb.**
A new feature added `user_id` as a label on the request count metric. Within hours, Prometheus is OOM. The metric store has 50M time series. Recovery: identify the offending metric, remove the label, restart the metric backend, accept ~6 hours of historical data loss.

**Scenario 2 — The silent log loss.**
A log shipper had a buffer overflow. Logs were dropped silently for 12 hours during an incident. The team relied on logs for debug. Without them, the incident took 4 hours longer than it should have. Postmortem: monitor log shipper health like any other dependency.

**Scenario 3 — The sampled-out trace.**
A 0.01% slow path causes intermittent customer complaints. Traces are sampled at 1%. The slow path is rarely sampled. Each customer complaint reaches the team without correlated trace data. After three months of confusion, the team enables tail sampling for slow requests.

**Scenario 4 — The dashboard that lied.**
Latency dashboard shows p99 of 80ms. Customers report 5-second responses. Investigation: the dashboard was averaging across all instances, but a single bad instance had p99 of 8s. Fix: per-instance breakdown, or use max-of-percentiles aggregation.

**Scenario 5 — The alert that didn't fire.**
SLO-based alert was set on "error rate > 1% for 5 minutes." A subtle bug caused 0.9% errors continuously. Below threshold; no alert. Customer complaints accumulated for weeks. Fix: tier alerts — page at 1% for 5 min, ticket at 0.5% for 1 hour.

---

## Performance Perspective

- **Instrumentation has runtime cost.** Metrics: ~100ns per increment. Logs: a microsecond of work, more if synchronous I/O. Traces: span creation is expensive (tens of microseconds at full fidelity).
- **In-process buffering** is critical. Synchronous logging blocks the request path. Asynchronous logging with bounded buffers and overflow policies is the standard.
- **Sampling is a performance lever** as much as a cost lever — full-fidelity tracing of every request adds measurable latency.
- **High-cardinality storage** has high *query* cost too. A query across millions of time series is slow.

---

## Scaling Perspective

- **Vertical:** monitoring backends scale to thousands of services on dedicated hardware.
- **Horizontal:** Prometheus federates; Grafana Mimir, Cortex, Thanos shard for high-volume use cases.
- **Geographic:** regional metric backends with cross-region aggregation. Latency for cross-region queries is real.
- **The hardest scaling problem:** *high-cardinality storage at scale*. ClickHouse, Druid, and similar columnar stores are increasingly the backbone. Pre-aggregation strategies trade flexibility for cost.
- **Storage tiers**: hot (last hour), warm (last day), cold (last month), archived (year+). Different storage, different cost, different query speed.

---

## Cross-Domain Connections

- **Cascading failures**: observability is the diagnostic layer for failure. Without it, you can't tell *why* a cascade started. (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)
- **Backpressure**: queue depth is a saturation metric; consumer lag is the canonical event-driven SLI. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Distributed systems**: traces are the only practical way to debug distributed timing issues. They're the visualization of the consistency models in action.
- **Caching**: cache hit rate is a primary metric for any cache layer. Without instrumenting it, you don't know if your cache is helping.
- **MVCC**: vacuum lag and oldest-snapshot age are saturation metrics specific to MVCC databases. Critical to monitor.
- **Event loop**: event loop lag is a Node-specific SLI worth watching.
- **V8 internals**: GC pause time is an observability target — a service with regular long GC pauses needs metric-level visibility into them.

The unifying observation: **observability is the meta-discipline for everything else.** Every other topic in this knowledge base eventually says "monitor X." Observability is *how* you monitor.

---

## Real Production Scenarios

- **Google SRE's error budget framework**: documented in the SRE book; widely adopted across industry.
- **Netflix's tracing infrastructure**: open-sourced parts of it, with publicly described patterns for sampling, retention, and integration with deploys.
- **Uber's Jaeger**: born from operational pain at Uber's microservice scale, now a CNCF project.
- **Honeycomb's wide-event model**: a counter-narrative to the three-pillar approach, with strong public advocacy and case studies.
- **Cloudflare's logging architecture**: multiple public posts about the petabyte-scale challenges of high-cardinality observability at edge scale.
- **The OpenTelemetry consolidation**: the industry-wide effort to standardize on a common instrumentation layer, decoupling SDK from backend.

---

## What Junior Engineers Usually Miss

- That **structured logs are non-negotiable** at production scale.
- That **averages hide tails** — measure percentiles.
- That **cardinality is cost** in metrics systems.
- That **a missing trace context propagation** breaks the entire trace.
- That **log levels matter** — DEBUG in production is a cost trap.
- That **alerts must be tied to user-facing impact**, not resource-level metrics.
- That **dashboards must be owned and maintained** or they become misleading.
- That **trace IDs in log lines** is the single highest-leverage instrumentation choice.

---

## What Senior Engineers Instinctively Notice

- They **define SLOs first**, then choose what to measure.
- They **read p99**, not means.
- They **hunt cardinality** as a regular discipline.
- They **see alert fatigue** as a debugging problem, not an alerting problem.
- They **demand trace propagation** in shared libraries.
- They **use error budgets** as a prioritization tool.
- They **know which one of the three pillars** answers each kind of question.
- They **distinguish the question they're asking** ("trend?" vs "cause?" vs "where?") and reach for the right pillar.

---

## Interview Perspective

What gets tested:

1. **"What's the difference between metrics, logs, and traces?"** Tests basic literacy. Bonus for explaining the cost/value tradeoffs.
2. **"How do you measure latency?"** Senior answer: distribution, p50/p95/p99, never just averages.
3. **"Explain SLOs and error budgets."** Senior candidates explain the prioritization framework, not just the math.
4. **"How do you debug 'this customer's request was slow'?"** Tests practical instrumentation. Right answer: trace ID propagation, then jump to the trace, then to logs at the slow span.
5. **"What's cardinality and why does it matter?"** Tests metrics literacy. Right answer: cost scales with cardinality; high-cardinality fields belong in logs/traces, not metrics.
6. **"How do you alert?"** Senior answer: SLO-based, symptom-based, actionable. Tied to user-facing impact.
7. **"How would you sample traces?"** Senior answer: tail sampling for errors and slow requests, head sampling for the rest.

Common traps:
- Treating monitoring and observability as synonyms.
- Recommending dashboards as the solution to debugging.
- Believing more alerts = better.
- Not knowing the cost model of metrics vs logs vs traces.

---

## 20% Knowledge Giving 80% Understanding

1. **Three pillars: metrics (what?), logs (when/exactly?), traces (why together?).**
2. **Cardinality is cost.** High-cardinality fields belong in logs/traces, not metrics.
3. **Measure distributions, not averages.** p50/p95/p99.
4. **SLOs define the contract; error budgets prioritize.**
5. **Structured logs only.** Free-text is a debugging trap at scale.
6. **Trace IDs in every log line.** Connects pillars.
7. **Sampling is mandatory** at scale. Tail-sample errors and slow requests.
8. **Alerts must be actionable, symptom-based, tied to SLOs.**
9. **The four golden signals**: latency, traffic, errors, saturation.
10. **Observability is a design property** of the system. Not bought; built.

---

## Final Mental Model

> **Observability is the discipline of making your system explain itself. The questions you didn't anticipate are the questions you'll need to answer at 3am — and the only way to answer them is to have instrumented for them in advance.**

The three pillars are tools. The real work is *deciding what's worth measuring*: which SLIs reflect customer experience, which dimensions reveal causality, which signals are leading vs lagging. A team with mediocre tools and excellent instrumentation choices outperforms a team with the best tools and poor choices, every time.

The senior operator's instinct, looking at any service: *if this fails right now, can I diagnose it without a deploy?* If the answer is no, the observability gap is the highest-priority engineering work — higher than the next feature, higher than the optimization. Because every minute of an incident with poor observability is a minute spent guessing.

That's metrics, logs, and traces. That's how production systems become legible. That's the difference between an outage that's resolved in 15 minutes and one that takes 4 hours.
