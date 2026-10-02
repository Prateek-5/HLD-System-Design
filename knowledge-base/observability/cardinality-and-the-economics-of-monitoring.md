# Cardinality & the Economics of Monitoring

> *"The first observability dashboard you build is free. The hundredth costs more than your engineering team. Monitoring is one of those areas where the bill, not the technology, ends up driving design decisions — and where 'just add a label' is one of the most expensive sentences in engineering."*

---

## Topic Overview

Observability has a cost. Every metric, every log line, every span has storage, processing, and query cost. At scale, these costs are non-trivial — many companies spend more on observability than on their compute infrastructure. The drivers of that cost are surprisingly counter-intuitive: it's not request volume that breaks the budget; it's *cardinality*. The number of unique combinations of labels, attributes, and dimensions that the observability system must track.

A label like `endpoint` (10 values) is cheap. The same metric with `endpoint × user_id` (10 × 10M = 100M) is six orders of magnitude more expensive. The metric is the same. The cardinality changed everything. Most observability cost surprises trace back to cardinality decisions made without understanding the economics.

This is the topic where observability becomes a finance problem. The technical decisions (what to monitor, what to keep, how to sample) all have direct costs. The senior practice is treating observability as a budgeted resource — useful as much as you can afford, with conscious trade-offs about what's worth keeping.

---

## Intuition Before Definitions

Imagine running a research library.

Cataloging every book by title, author, and genre is cheap. Maybe 10 genres × 1000 authors × 100K titles. The catalog fits in a small database.

Now add: which page each visitor read, when, for how long. Every visitor × every book × every minute. Cardinality explodes. The "catalog" now needs petabytes.

Add: every word every visitor highlighted, with context. The catalog is now larger than the books themselves.

That's the cardinality problem. As you add dimensions, the data needed to record them grows multiplicatively. At some point, the metadata is more expensive than the underlying activity it describes. Observability runs into this constantly: "let's tag with user ID" turns a megabyte of metrics into a terabyte.

The library's solution: don't catalog everything. Sample. Pick what's worth keeping; discard the rest. Observability's solution is the same. The art is knowing what to keep.

---

## Historical Evolution

**Era 1 — Server logs.**
1990s, 2000s. Logs were files. You shipped them somewhere. Cost was disk space. Cardinality wasn't a concept; you grepped what you had.

**Era 2 — Centralized log aggregation.**
Late 2000s. Splunk, ELK. Centralized storage; full-text indexing. Cost scaled with log volume; index size dominated.

**Era 3 — Time-series metrics.**
~2010. Graphite, then Prometheus. Cardinality became visible as "number of time series." Per-time-series cost became the lever.

**Era 4 — High-cardinality observability.**
~2016. Honeycomb argues cardinality is the value, not the cost. Wide events. ClickHouse, Druid as backends.

**Era 5 — Cost awareness.**
2020+. Major postmortems and bills woke teams up. Observability cost becomes a major engineering line item. FinOps for observability.

**Era 6 — Tiering and intelligent retention.**
Modern: hot/warm/cold storage tiers. Different retention per data type. Sampling that preserves rare events. Cost optimization as a discipline.

The pattern: each generation made observability more powerful and more expensive. Cost discipline arrived late; many teams paid for the lesson.

---

## Core Mental Models

**1. Cardinality is the cost driver.**
Number of unique combinations of dimensions. A metric with N dimensions, each with M values: M^N possible series. Each series has storage cost. Cardinality compounds; one bad label breaks the budget.

**2. Cardinality is also the value driver.**
The questions you can ask depend on the dimensions you have. Ability to slice by user, region, version, feature requires the data to *have* those dimensions.

**3. Different signals have different cost models.**
Metrics: cardinality × resolution × retention. Logs: volume × indexing × retention. Traces: span volume × sampling × retention. Each is a different optimization problem.

**4. Pre-aggregation is the cheap solution; raw events are the powerful one.**
Aggregating losing dimensions; you can't slice later. Storing raw events lets you slice anything; cost is much higher. The trade-off is at the architecture level.

**5. Sampling is mandatory at scale.**
Keeping everything is fine until 10K RPS becomes 100K. Sampling — head-based or tail-based — is what makes observability affordable. Smart sampling preserves what matters.

---

## Deep Technical Explanation

### The cardinality formula

For a metric with dimensions d1, d2, ..., dN where each has c1, c2, ..., cN values:

`Cardinality = c1 × c2 × ... × cN`

Each unique combination is a *time series*: an independent sequence of (timestamp, value) pairs. Storage scales linearly with cardinality.

A simple example:

```
http_requests_total{method, endpoint, status}
  method: 5 values (GET, POST, PUT, DELETE, PATCH)
  endpoint: 50 values
  status: 10 values
```

Cardinality: 5 × 50 × 10 = 2,500 series. Cheap.

Add `user_id` (1M users):

Cardinality: 2,500 × 1,000,000 = 2.5 billion series.

The metric "didn't change" — same data being recorded — but the system now needs ~1 million× more storage. This is the *cardinality bomb*.

### Why high-cardinality fields hurt metrics

Time-series databases are designed for ~1M to 10M series. Past that:
- **Memory**: each series has metadata (labels, recent values). Per-series overhead is hundreds of bytes to KB.
- **Query**: aggregations over high-cardinality data are slow.
- **Ingestion**: hot path of "is this series new?" gets expensive.

Prometheus's docs explicitly warn against unbounded labels (user IDs, request IDs, full URLs). Other TSDBs have similar limits.

### The right home for each dimension

| Dimension | Cardinality | Best home |
|---|---|---|
| Service name | 10s | Metric label |
| Endpoint | 100s | Metric label |
| Status code | ~10 | Metric label |
| Region | <10 | Metric label |
| User ID | millions | Log/trace attribute |
| Request ID | unbounded | Log/trace attribute |
| Full URL | high | Log/trace attribute |

The rule: **low-cardinality dimensions on metrics; high-cardinality dimensions on logs and traces**. Logs and traces have different cost models that handle high cardinality.

### Logs cost model

Log cost drivers:
- **Volume**: bytes per second × retention.
- **Indexing**: full-text indexing is expensive; structured field indexing cheaper.
- **Query**: search across volume.

Optimization:
- **Structured logs**: index specific fields, not full text.
- **Sampling**: log all errors; sample successes.
- **Retention tiering**: hot (fast access) vs cold (cheap, slow).
- **Compression**: standard.

Real numbers: a service at 10K RPS with 2KB log per request = 20MB/s = ~1.7TB/day. At Splunk-like pricing of $1500/GB/yr indexed: $90M/yr. At more typical S3 + Athena: $5K/yr. The architecture matters enormously.

### Traces cost model

Span volume × sampling × retention:
- Each request can produce 5-50 spans.
- 10K RPS × 20 spans = 200K spans/sec.
- At 1KB per span: 200MB/s of trace data.

Sampling is mandatory:
- Head sampling at 1% reduces to 2MB/s.
- Tail sampling preserves errors and slow requests; cost varies.

Retention: usually shorter than logs (days to weeks); traces are debugging tools, not historical records.

### Sampling strategies in detail

**Probabilistic head sampling.**
At request entry, decide with probability P to capture the trace. Decision propagates to all spans.
- Simple, low overhead.
- Misses rare events (errors are usually <1%).

**Rate-limited sampling.**
Cap traces per second per service. Within the cap, all are kept.
- Predictable cost.
- Doesn't bias toward interesting events.

**Tail sampling.**
Buffer all spans; decide after request completes.
- Keep all errors, all slow requests.
- Sample successes at low rate (e.g., 0.1%).
- Requires infrastructure (collectors that buffer).

**Adaptive sampling.**
Sampling rate adjusts based on traffic volume or interest.
- Reserves storage for high-value events.
- Smart but operationally complex.

**Priority/hint sampling.**
Application code marks specific traces as "must sample" (debugging a customer's issue, etc.).
- Useful for support workflows.
- Requires application instrumentation.

### Pre-aggregation vs raw events

**Pre-aggregated** (Prometheus model):
- Application increments counters with labels.
- TSDB stores aggregated time series.
- Queries compute on aggregates.
- Cheap; fixed cardinality envelope.

**Raw events** (Honeycomb/wide-event model):
- Application emits one rich event per operation.
- Storage layer indexes attributes.
- Queries can group by any attribute.
- Expensive; powerful.

Many systems combine: pre-aggregated metrics for dashboards and alerting; raw events for ad-hoc debugging. The dual model captures most value.

### Retention tiers

Hot: queryable in seconds; expensive. Last 24-48 hours.
Warm: queryable in seconds-to-minutes; cheaper. Last 1-4 weeks.
Cold: queryable in minutes-to-hours; very cheap. 1-12 months.
Archive: bulk storage; query is rare. Compliance/audit.

Each tier has different storage tech: Elasticsearch hot; ClickHouse warm; S3 cold; Glacier archive. Migration between tiers is automated.

The economics: 99% of queries hit hot. Hot can be small (last 24h). The rest is cheaply available if needed.

### Cost optimization patterns

**Drop logs in production.** DEBUG logs in production are pure cost. Filter at the source.

**Sample errors over successes.** Errors are 0.1% of traffic but 100% of value. Don't sample uniformly.

**Cardinality audits.** Periodically inspect what's in the metric store. Find the explosion.

**Drop unused metrics.** Many metrics are emitted but never queried. Auditing reveals 30-50% of metrics in many shops are dead.

**Compress before shipping.** Significant savings on egress costs.

**Local pre-aggregation.** Compute counts/rates in the agent before shipping. Reduce volume by orders of magnitude.

### Cardinality as a feature

Some systems lean into high cardinality:
- **Honeycomb**: query performance designed for hundreds of dimensions.
- **ClickHouse**: columnar storage handles wide events.
- **Druid**: pre-aggregation + raw event storage.

These systems push the cardinality boundary. The cost is real but provides flexibility for ad-hoc analysis. Not every observability backend supports this.

---

## Real Engineering Analogies

**The corporate accounting system.**
A company tracks income and expenses. By department: cheap. By project within department: more storage. By individual transaction: massive. The IRS only requires aggregated reporting; managers want detail; the trade-off is real.

Companies often store summary data online and detailed records archived. Same pattern as observability tiering.

**The retail receipt aggregation.**
A grocery store tracks "total revenue per day" cheaply. "Revenue per item per day" is bigger. "Revenue per customer per item per day" is massive. The trade-off: how granular does management need to slice?

Modern POS systems can capture all three. The CFO uses summary; the merchandiser uses item-level; the loyalty program uses customer-level. Each layer is filed separately and queried as needed.

---

## Production Engineering Perspective

What goes wrong:

- **The user_id label disaster.** A team adds `user_id` to a metric "for personalization debugging." 10M users; cardinality grows; storage bill triples. Rollback: remove the label; clear the cache; wait days for the legacy series to age out.
- **The unbounded URL label.** Capturing full URL as a label. Each unique URL is a series. Many APIs have query parameters; cardinality is unbounded. Fix: capture URL pattern (`/users/:id`), not full URL.
- **The unaudited metrics graveyard.** 50,000 metrics in the system. 80% are never queried. Cost is paid forever. Cleanup: usage analysis; drop the dead ones.
- **The per-request log volume.** Each request logs 10 lines × 2KB. At 10K RPS, that's 20MB/s. At Splunk-grade pricing, six figures per month. Reduction: sample successes; structured fields not full text.
- **The unindexed log query that scanned everything.** No indexes; "find errors mentioning customer X." Query scans 100GB. Costs more than $100. Mitigation: index error and customer fields.
- **The trace sampling that hid bugs.** 1% head sampling. Bug occurs in 0.1% of requests. Trace coverage of bug: 0.001%. Insufficient. Fix: tail sampling preserving errors.
- **The retention surprise.** Logs retained for 2 years "just in case." Storage scales linearly with time. Most queries hit last 7 days. Fix: tier; archive older data.

The senior engineer's habits:
- **Audit cardinality** quarterly.
- **Distinguish low-card from high-card** dimensions.
- **Tier retention** by query frequency.
- **Sample with bias** toward errors.
- **Drop unused metrics**.
- **Cost-monitor observability** spend.
- **Compress at edge**.

---

## Failure Scenarios

**Scenario 1 — The cardinality bomb.**
Engineer adds `customer_email` as a label. Cardinality grows from thousands to millions. TSDB OOMs. Outage on the metrics layer; alert system blind. Fix: revert; rebuild metric storage.

**Scenario 2 — The budget overrun.**
Team enabled DEBUG logging in production "temporarily." Forgot. Monthly bill arrives: 5× expected. Investigation: 100M log lines/day. Recovery: filter at source; restore budget.

**Scenario 3 — The query that timed out.**
Engineer searching logs for a specific incident. Query: scan 30 days of logs for a string. Took 90 minutes; user waited; missed lunch. Fix: structured fields; tighter time range; appropriate index.

**Scenario 4 — The unmonitored unused metric.**
Application emits 200 metrics. 195 are queried; 5 are not. The 5 cost $X/month indefinitely. Discovery during audit: drop them; save real money.

**Scenario 5 — The trace sample that missed the bug.**
1% sampling. Customer reports issue. No trace exists for their request. Engineering can't reproduce. Hours wasted before someone realizes the request would be in tail-sampling. Mitigation: enable tail sampling for errors and slow requests.

---

## Performance Perspective

- **Metric ingestion**: bounded by series count and write rate.
- **Log indexing**: typically the cost bottleneck.
- **Trace span volume**: scales with request rate × spans per request.
- **Query performance**: degrades with data volume; column-oriented stores help.
- **Compression**: 10-30% savings typical; CPU cost minor.

---

## Scaling Perspective

- **Vertical**: bigger storage backends; hits limits.
- **Horizontal**: shard observability backends. Most modern systems are distributed (Mimir, Cortex, Tempo, ClickHouse).
- **Geographic**: regional aggregation; cross-region for global view.
- **At hyperscale**: dedicated observability platform team; integration with cost monitoring.

---

## Cross-Domain Connections

- **Metrics, logs, traces**: cardinality matters differently for each. (See [metrics-logs-traces.md](./metrics-logs-traces.md).)
- **SLOs**: SLI computation depends on metrics; cardinality affects feasibility. (See [slos-error-budgets-and-alerting.md](./slos-error-budgets-and-alerting.md).)
- **Distributed tracing**: sampling strategy is a cardinality / cost trade-off. (See [distributed-tracing-deep-dive.md](./distributed-tracing-deep-dive.md).)
- **Capacity planning**: observability is itself a cost line item to plan. (See [auto-scaling-and-capacity-planning.md](../scalability/auto-scaling-and-capacity-planning.md).)
- **Microservices**: more services = more cardinality. (See [microservices-vs-monolith.md](../architecture-patterns/microservices-vs-monolith.md).)

The unifying observation: **observability is bounded not by what you'd like to monitor, but by what you can afford to. The discipline of cost-aware monitoring is what separates teams whose observability is sustainable from teams whose bills surprise them quarterly.**

---

## Real Production Scenarios

- **The "we spend more on Datadog than AWS" stories**: not uncommon at mid-sized companies.
- **Honeycomb's wide-event model**: published case studies of cost vs flexibility trade-offs.
- **Prometheus's Mimir / Cortex / Thanos**: scaled Prometheus deployments handling petabytes.
- **Splunk's pricing scrutiny**: many companies have moved off Splunk for cost reasons.
- **OpenTelemetry's vendor neutrality**: enables shopping for cheaper backends.

---

## What Junior Engineers Usually Miss

- That **cardinality is the dominant cost**.
- That **adding a label can multiply storage** by orders of magnitude.
- That **logs and traces have different cost models**.
- That **retention compounds** over time.
- That **sampling is mandatory at scale**.
- That **DEBUG in production is expensive**.
- That **dead metrics cost forever**.
- That **structured logs query better than free text**.

---

## What Senior Engineers Instinctively Notice

- They **audit cardinality** as a discipline.
- They **distinguish low-card from high-card** dimensions.
- They **tier retention** by query patterns.
- They **bias sampling toward errors**.
- They **monitor observability cost**.
- They **drop unused metrics**.
- They **compress at edge**.
- They **understand the right home** for each piece of data.

---

## Interview Perspective

What gets tested:

1. **"What's cardinality?"** Tests fundamental literacy.
2. **"Why is high-cardinality bad on metrics?"** Storage scales with series count.
3. **"What's tail sampling?"** Tests trace knowledge.
4. **"How do you control observability cost?"** Cardinality discipline; tiering; sampling.
5. **"Logs vs metrics vs traces — what's the right home for X?"** Tests judgment.
6. **"How would you handle a cost surprise?"** Audit; identify drivers; reduce or restructure.

Common traps:
- Believing more data is always better.
- Not knowing about cardinality.
- Treating cost as someone else's problem.

---

## 20% Knowledge Giving 80% Understanding

1. **Cardinality is cost.** High-cardinality fields belong in logs/traces, not metrics.
2. **Sampling is mandatory** at scale.
3. **Tail-sample errors and slow requests.**
4. **Tier retention** by query frequency.
5. **Audit unused metrics**; drop them.
6. **DEBUG in production is expensive.**
7. **Structured logs > free-text logs** for queryability and cost.
8. **Pre-aggregated metrics** are cheap; raw events are flexible.
9. **Compression at source** saves egress.
10. **Cost-monitor observability** as a line item.

---

## Final Mental Model

> **Observability is a budgeted resource. Every label, every log line, every span costs money. The art isn't capturing everything — it's capturing the *right* things, at the right tier, with the right sampling, for as long as it remains useful. Teams that internalize this have observability that scales with their business; teams that don't have observability that scales with their bill.**

The senior observability engineer reads dashboards while watching costs. They run cardinality audits. They sample with bias. They drop dead metrics. They tier old data. The result: monitoring that answers the questions you need, at a cost that doesn't surprise you.

The bills that arrived with three-digit increases month after month were the teaching moment for many companies. The discipline that emerged is now industry-standard for mature ops shops. Get it right early; pay attention to cardinality; treat observability as a feature with a budget. The alternative is a quarterly cost shock that drives reactive decisions you'd rather not make.

That's cardinality. That's the economics of monitoring. That's the financial reality behind every dashboard, every alert, every trace — the line item that determines whether your observability is sustainable or whether it eventually gets cut for cost.
