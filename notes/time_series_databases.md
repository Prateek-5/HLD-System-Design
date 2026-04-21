# Time-Series Databases

> **📎 Prereqs** — If rusty:
> - [`databases.md`](databases.md) — general DB concepts.
> - [`nosql_internals.md`](nosql_internals.md) — LSM + compaction (TSDBs use similar ideas).
> - Percentile / aggregation intuition.

### 🔹 1. What This Topic Actually Is
Databases specialized for time-indexed, append-heavy data: metrics, IoT, monitoring, financial ticks, user events.

### 🔹 2. Why It Exists
- General-purpose DBs waste storage + compute on time-series:
  - Too many small rows.
  - Timestamps have high compressibility TSDBs exploit.
  - Queries are dominated by ranges + rollups, not point lookups.
- TSDBs crush storage cost 10–100× while delivering sub-second range queries.

### 🔹 3. Core Concepts (High Signal)
- **Append-only**, time-bucketed storage; often LSM-based.
- **Delta encoding** on timestamps (regular intervals compress to near-zero).
- **Gorilla compression** (Facebook, 2015): XOR consecutive float values; typical 1.37 bytes/value for metrics. Seminal paper.
- **Downsampling / retention policies**: raw for 1 day → 1-min rollups for 1 week → 1-hour for 1 year. Per-tier.
- **Tags / labels** vs fields — tags indexed, fields not; be careful (tag explosion is a common anti-pattern).
- **High-cardinality problem**: millions of unique tag combinations blow up indexes.

### 🔹 4. Internal Working (Influx-like)
- Writes batched, LSM'd to disk.
- Data organized into shards by time window (e.g., 1-hour shards).
- Queries: pick shards intersecting time range + tag-index lookup → scan + aggregate.

**Failure points:** high cardinality tags (cardinality explosion), ingestion backlog, retention policy mis-set (disk full), query spanning too many shards.

### 🔹 5. Key Tradeoffs
- TSDB for anything time-indexed and high-volume.
- Relational DB only at low scale (1k events/s).
- Column-store OLAP (ClickHouse, Druid) overlaps TSDB for real-time analytics.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. Why not use Postgres for metrics?
2. What's downsampling?

**Intermediate 🟡**
1. Explain Gorilla compression intuition.
2. What's the cardinality problem?

**Advanced 🔴**
1. Design metrics pipeline for 1B points/day.
2. Compare InfluxDB / Prometheus / ClickHouse / Druid for real-time analytics at scale.

### 🔹 7. Real System Mapping
- **Facebook Gorilla** (paper) → precursor to Prometheus TSDB.
- **Pinterest Goku** TSDB.
- **Uber AresDB**.
- **InfluxDB**, **Prometheus**, **TimescaleDB** (Postgres extension), **VictoriaMetrics**, **Druid**, **ClickHouse**.

### 🔹 8. What Most People Miss
- **Cardinality is the #1 killer**. A tag like `request_id` with millions of values → billions of unique series.
- **Prometheus is pull-based**, not push — scrapers poll targets. Works great for k8s, struggles with short-lived jobs (use Pushgateway).
- **Retention + downsampling tiers** save an order of magnitude of storage.
- **Timescale (SQL-based TSDB)** is underrated — all the SQL power plus time-series optimizations.
- **OLAP (Druid, ClickHouse)** is often a better fit than TSDB for event-level data with ad-hoc querying.

### 🔹 9. 30-Second Revision
Time-indexed data wants Gorilla compression + LSM + time-sharded storage. Downsample to save space. Watch cardinality — it's the biggest gotcha. Prometheus pull-based for k8s metrics. ClickHouse / Druid for ad-hoc analytics on events. Timescale if you want SQL.

---

## 🔗 Cross-Topic Connections
- **Databases**: TSDB is a specialized flavor.
- **Stream processing**: often feeds TSDB.
- **Caching**: recent metrics cached in memory.
- **Observability**: TSDB is the backbone.

---

### Confidence Check
- [ ] Can I explain delta+XOR compression?
- [ ] Can I avoid cardinality explosion in tag design?

### Gaps
- Prometheus federation + remote storage.
- Druid ingestion architecture.
