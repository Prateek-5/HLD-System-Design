# Time-Series Databases

> *"Time-series data has a shape: many writes, append-only, queries that span time ranges and aggregate. Treating it like generic data — using a relational database — works at small scale and falls apart at larger ones. Time-series databases are what happens when you take that shape seriously and build storage and query engines optimized for it."*

---

## 🎯 Start Here — Intuition

> **In one line:** A database built for data that's constantly being recorded over time (sensor readings, server metrics, stock ticks) — so you can store huge volumes cheaply and answer "what happened between 2pm and 3pm?" fast.
>
> **Analogy:** A grocery store's security camera footage. New frames are added every second and never edited; old footage is compressed and eventually auto-deleted; and you almost never ask "show me frame #4,812,003" — you ask "show me the last 20 minutes." A time-series database stores data the same way the camera stores video: append-only, compressed, and organized by time.
>
> **Assumes you already know:** what a database is ([`learn/data/db-and-dbms.md`](../../learn/data/db-and-dbms.md)) and the basics of how data gets stored on disk ([`learn/foundations/scaling/storage.md`](../../learn/foundations/scaling/storage.md)). Familiarity with NoSQL ([`learn/data/nosql-databases.md`](../../learn/data/nosql-databases.md)) helps but isn't required.
>
> **Level:** this file is 🟡 overall, ramping to 🔴 in the internals. Sections below are tagged. If the basics feel shaky, that tag is your signal to slow down — **you are not behind.**

## 🟢 Topic Overview

Time-series data is data indexed by time: server metrics, IoT sensor readings, financial ticks, user events, application logs (sometimes). The defining characteristics: high write rate (often millions of points/sec); append-only (data isn't updated, only added); queries are time-range based ("last hour," "last day"); aggregation is the dominant query pattern (averages, percentiles, downsampling).

**Time-series databases** (TSDBs) — InfluxDB, TimescaleDB, ClickHouse, Prometheus, Druid, M3 — are storage engines designed for this shape. They use techniques general-purpose databases can't easily replicate: aggressive compression, columnar layout, time-based partitioning, downsampling, retention policies.

This is the topic that explains why Prometheus exists alongside Postgres; why Datadog's storage isn't just MySQL; why financial systems use specialized stores. The data shape demands specialized engineering. Understanding the TSDB design space shapes choices for monitoring, IoT, observability, and analytics.

---

## 🟢 Intuition Before Definitions

Imagine a weather station recording temperature every minute, year-round.

**Generic database approach.** A row per reading: (timestamp, station_id, temperature). After a year: 525,600 rows per station. Across thousands of stations: billions. Queries like "average temperature in California last week" scan many rows.

**Time-series approach.** Group readings by station and time interval: each station's hourly chunk is one record. Compress aggressively (consecutive temperatures are similar; deltas compress to bits, not bytes). Partition by time so old data can be aged out. Aggregate-friendly storage.

Result: 100× more data in the same space; queries 100× faster.

That's a TSDB. Same data; storage shaped for the access pattern. The benefit compounds at scale.

---

## 🟢 Historical Evolution

**Era 1 — RRDtool.**
1999. Round-robin database for monitoring. Fixed-size circular buffers. Limited but efficient for the era.

**Era 2 — Generic databases.**
2000s. MySQL/Postgres for time-series. Worked at modest scale.

**Era 3 — Specialized TSDBs emerge.**
~2010. OpenTSDB (Yahoo, on HBase). Graphite. Specialized for monitoring.

**Era 4 — Modern TSDBs.**
2013+. InfluxDB (2013), Prometheus (2012), TimescaleDB (2017), ClickHouse for time-series (2016). Each with different design choices.

**Era 5 — Cloud TSDBs.**
2018+. Managed services: AWS Timestream, Azure Data Explorer, Google Cloud Monitoring backend.

**Era 6 — Convergence with OLAP.**
Today. ClickHouse and similar columnar OLAP databases serve time-series excellently. The line blurs.

The pattern: time-series became its own category, then converged with columnar OLAP. The fundamentals are stable.

---

## 🟡 Core Mental Models

**1. Time is the primary index.**
Most queries filter by time range. Storage is partitioned by time.

**2. Append-only writes.**
Time-series data isn't updated. This simplifies storage, replication, compression.

**3. Compression is dramatic.**
Consecutive timestamps and values are similar; delta encoding + bit packing achieves 10-100× compression.

**4. Aggregation matters.**
Most queries aggregate. Pre-computed aggregates ("downsampling") speed common queries.

**5. Cardinality is the killer.**
Time series with high-cardinality labels (user_id) explode. (See [cardinality-and-the-economics-of-monitoring.md](../observability/cardinality-and-the-economics-of-monitoring.md).)

---

## 🔴 Deep Technical Explanation

⚠️ The rest assumes the basics above are solid.

### Data model

A time series:
- **Metric name**: e.g., `http_requests_total`.
- **Labels** (key-value): e.g., `{method="GET", status="200"}`.
- **Timestamp + value** pairs: the actual data points.

Each unique combination of metric + labels = one *time series*. The set of time series defines cardinality.

### Time-based partitioning

Storage divided into chunks by time (hourly, daily, weekly).

Benefits:
- Old chunks can be deleted (retention).
- Queries skip irrelevant chunks (partition pruning).
- Each chunk can be optimized (compressed, indexed) independently.

Most TSDBs partition this way. The size of partitions matters: small = many chunks; large = bigger queries.

### Compression

Time-series compresses dramatically. Techniques:

**Delta encoding for timestamps.**
Rather than `[1000, 1010, 1020, 1030]`, store `[1000, +10, +10, +10]`. Delta is small; compresses better.

**Delta-of-delta.**
Rather than `[+10, +10, +10]`, store `[+10, +0, +0]`. Even smaller.

**Bit packing.**
Small integers packed into few bits. A delta of 10 fits in 4 bits.

**Run-length encoding.**
Consecutive identical values: `[10, 10, 10]` → `(10, 3)`.

**Dictionary encoding.**
For low-cardinality columns (like labels).

Combined: 1-3 bytes per data point typical. RDBMS with timestamp + value columns: 16+ bytes.

Facebook's Gorilla paper (2015): compressed time-series to 1.37 bytes per point on average.

### Cardinality challenges

Each unique label combination is a separate time series, with its own metadata, index entry, write path.

- 1M time series: typical scale; manageable.
- 10M: getting expensive.
- 100M: serious infrastructure.
- Billions: hyperscale.

High-cardinality labels (user_id, request_id, full URL) blow up cardinality. This is the #1 operational issue in TSDBs.

### Indexes

Inverted indexes on labels:
- `method=GET` → set of series IDs.
- `status=200` → set of series IDs.

Query "method=GET AND status=200": intersection of sets.

Postings lists; bitmap indexes; specialized data structures for fast set operations.

### Downsampling

Old data is queried less often and at lower resolution. Pre-aggregate:
- 5-second resolution for the last hour.
- 1-minute resolution for the last day.
- 1-hour resolution for the last month.
- 1-day for the last year.

Storage shrinks dramatically; queries on old data are fast.

Tools: Prometheus with Thanos/Mimir compactor; InfluxDB's Continuous Queries; Grafana Mimir.

### Retention policies

Old data is dropped. Specified per metric or globally.

Implementation: time-based partitions are deleted as they age out. Cheap; bounded by chunk granularity.

### Write path

Writes are typically:
- Append to a write-ahead log.
- Buffer in memory ("memtable" or similar).
- When buffer fills, flush as a chunk (sorted, compressed).
- Eventually merge chunks (compaction).

Sound familiar? It's LSM-tree-like, optimized for time-series. (See [indexing-and-storage-engines.md](./indexing-and-storage-engines.md).)

### Query path

Query: "average request rate, by method, over last hour."

1. Identify time range; find relevant chunks.
2. Identify matching time series (from labels).
3. Read data points from chunks.
4. Aggregate.
5. Return.

The path is optimized for time-range + labels + aggregation. Generic queries (find specific points) are less efficient.

### Specific TSDBs

**Prometheus.**
- Pull-based: scrapes targets.
- Local TSDB; push to long-term storage (Thanos, Cortex, Mimir).
- PromQL query language.
- 30 days retention typical.

**InfluxDB.**
- Push-based: clients send.
- Embedded TSDB.
- Flux query language (or InfluxQL).
- Cloud and OSS variants.

**TimescaleDB.**
- Postgres extension.
- Time-partitioned tables ("hypertables").
- Full SQL.
- Native to PostgreSQL ecosystem.

**ClickHouse.**
- Columnar OLAP; excellent for time-series.
- SQL.
- Used at Cloudflare, Yandex, Uber for time-series.

**Druid.**
- Distributed analytics; pre-aggregation focused.
- Used at Airbnb, Netflix.

Each has trade-offs. Choice depends on query patterns, ecosystem, scale.

### Continuous queries / materialized views

Pre-compute aggregates as data arrives:
- "Hourly average per service" — computed once; queried many times.

Reduces query cost; increases write cost (slightly).

Most TSDBs support this; the syntax varies.

### Chunking and compaction

Like LSM trees, TSDBs compact small chunks into bigger ones.

Compaction:
- Reduces file count.
- Improves compression (more data per chunk).
- Costs I/O.

Tuning compaction is real work in production TSDBs.

---

## 🟡 Real Engineering Analogies

**The flight data recorder.**
Captures every cockpit input every fraction of a second. Stores compactly because it's all similar data. Records overwrite when full (ring buffer). Query is "what happened in the last 30 minutes?" — exactly time-range.

**The seismograph.**
Records ground motion continuously. Aggregates for daily reports. Drills into specific events. Same shape as TSDB queries.

---

## 🔴 Production Engineering Perspective

What goes wrong:

- **The cardinality bomb.** Engineer adds `user_id` label. Cardinality grows from thousands to millions. TSDB OOMs. (See [cardinality-and-the-economics-of-monitoring.md](../observability/cardinality-and-the-economics-of-monitoring.md).)
- **The hot tag.** A "hot" label value (a popular customer) gets disproportionate writes; that shard is overwhelmed. Mitigation: bucket the hot tag.
- **The retention surprise.** Default retention 30 days; team needs 1 year for compliance. Storage explodes. Fix: tier; downsampling.
- **The write-path saturation.** Spike in metrics emission; ingestion can't keep up; data lost. Mitigation: capacity planning; scale ingest.
- **The query-path melt.** Big aggregation over months of data; query takes minutes; users wait. Mitigation: continuous queries; downsampling.
- **The clock-skew mess.** Clients with skewed clocks send "future" data; server rejects or stores in odd places. Mitigation: clock sync; or accept and tag.

The senior TSDB operator's habits:
- **Audit cardinality** continuously.
- **Plan retention** with downsampling.
- **Monitor write/query rates**.
- **Capacity-plan ingest**.
- **Use continuous queries** for common aggregations.

---

## 🔴 Failure Scenarios

**Scenario 1 — The cardinality explosion.**
Engineer adds `request_id` (unbounded) as label. TSDB OOMs. Recovery: revert; rebuild storage.

**Scenario 2 — The retention overflow.**
Team raises retention 30→365 days; storage 12× expected. Mitigation: aggressive downsampling for old data.

**Scenario 3 — The write storm.**
Massive deploy; metrics emission 10× normal. Ingestion saturates; data dropped. Mitigation: rate limit at the agent.

**Scenario 4 — The slow query.**
Annual report query: aggregate over 365 days; took 30 minutes. Mitigation: pre-compute; or use OLAP-grade infrastructure.

**Scenario 5 — The hot-label imbalance.**
Cardinality even except for one customer with 80% of metrics. That shard hot. Mitigation: shard rebalancing.

---

## 🟡 Performance Perspective

- **Write rate**: millions/sec on dedicated TSDBs.
- **Query rate**: thousands/sec; varies by complexity.
- **Compression ratio**: 10-100× typical.
- **Latency for recent data**: ms.
- **Latency for old data**: depends on tier.

---

## 🔴 Scaling Perspective

- **Vertical**: bigger nodes; tens of millions of series.
- **Horizontal**: shard by series or tenant.
- **Tiered**: hot/warm/cold storage.
- **At hyperscale**: federated; multi-region; specialized infrastructure (M3, Mimir).

---

## 🟡 Cross-Domain Connections

- **OLTP vs OLAP**: time-series is closer to OLAP. (See [oltp-vs-olap-and-columnar-storage.md](./oltp-vs-olap-and-columnar-storage.md).)
- **Cardinality**: the critical economics. (See [cardinality-and-the-economics-of-monitoring.md](../observability/cardinality-and-the-economics-of-monitoring.md).)
- **Indexing**: inverted indexes on labels. (See [indexing-and-storage-engines.md](./indexing-and-storage-engines.md).)
- **Sharding**: time-series sharded by series or tenant. (See [sharding-and-partitioning-strategies.md](../scalability/sharding-and-partitioning-strategies.md).)
- **Observability**: TSDBs underlie monitoring. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)

The unifying observation: **time-series databases are storage and query engines optimized for time-range, aggregate-heavy queries. Where general-purpose databases struggle (high write rates, time-range queries, retention), TSDBs shine.**

---

## 🔴 Real Production Scenarios

- **Cloudflare's ClickHouse usage**: petabyte-scale time-series.
- **Datadog's TSDB**: extensive public engineering.
- **Prometheus's design**: documented in papers and talks.
- **Facebook's Gorilla**: foundational paper.

---

## Key Takeaways

- **Time is the primary index.** Most queries filter by time range; storage is partitioned by time, enabling partition pruning and cheap retention drops.
- **Append-only writes.** Time-series isn't updated, only added — simplifying storage, replication, and compression.
- **Compression is dramatic.** Delta / delta-of-delta encoding, bit packing, RLE, and dictionary encoding give 10-100× compression (Gorilla: 1.37 bytes/point vs 16+ for RDBMS).
- **Cardinality drives cost and is the #1 operational issue.** Each unique label combination is a separate series; high-cardinality labels (user_id, request_id, full URL) blow it up and OOM the TSDB.
- **Downsampling is standard practice.** Pre-aggregate old data at coarser resolution; storage shrinks and old-data queries stay fast.
- **Retention policies** drop old data via aging-out partitions — cheap, bounded by chunk granularity.
- **Inverted indexes on labels** (postings/bitmap) resolve `label=value` lookups via set intersection.
- **Continuous queries / materialized views** pre-compute common aggregates — lower query cost for slightly higher write cost.
- **High write rates are normal** (millions/sec on dedicated TSDBs); query rates are thousands/sec depending on complexity.
- **OLAP convergence:** columnar OLAP engines like ClickHouse now serve time-series excellently; the category line blurs.
- **The senior reflexes:** audit cardinality continuously, choose the TSDB by workload/ecosystem, plan tiered retention with downsampling, and monitor ingest/query rates.
- **Net model:** TSDBs take the data's shape seriously, yielding storage 10-100× more efficient and queries 10-100× faster than generic alternatives. The cost is operational specialization; the benefit is monitoring/IoT/observability that scales with the business without bankrupting the team.

## Interview angle

- **"What's time-series data?"** Indexed by time; high writes; aggregation-dominant queries.
- **"Why a specialized DB?"** Compression, time-partitioning, and a query path tuned for time-range + labels + aggregation.
- **"What's downsampling?"** Pre-aggregating at coarser resolution for older data.
- **"What's cardinality?"** The number of unique metric+label combinations (each is one series).
- **"Prometheus vs InfluxDB?"** Pull vs push; PromQL vs Flux/InfluxQL; different ecosystems and trade-offs.
- **Common traps:** treating a TSDB as a generic database; ignoring cardinality.
