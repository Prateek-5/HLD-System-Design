# Stream & Batch Processing

> **📎 Prereqs** — If rusty:
> - [`message_queues_and_pubsub.md`](message_queues_and_pubsub.md) — Kafka is the stream source.
> - [`databases.md`](databases.md) — output sinks.
> - Event-time vs processing-time mental model.

### 🔹 1. What This Topic Actually Is
Two ways to process large data:
- **Batch**: bounded dataset, run periodically (hourly/daily). Throughput over latency.
- **Stream**: unbounded dataset, processed continuously in real time. Latency matters.

### 🔹 2. Why It Exists
- Batch: reports, ETL, ML training on large historical data.
- Stream: fraud detection, live analytics, real-time personalization, metrics.
- Choice is workload-driven, not fashion.

### 🔹 3. Core Concepts (High Signal)
- **MapReduce (Google, 2004)**: Map shards → Reduce per key. Historical foundation; superseded in practice by Spark / Flink / Dataflow.
- **Spark**: batch + micro-batch streaming (structured streaming); resilient distributed datasets (RDDs).
- **Flink**: true event-at-a-time streaming with strong time semantics.
- **Kafka Streams / ksqlDB**: stream processing library; lower ops cost if you already run Kafka.
- **Lambda vs Kappa**:
  - *Lambda* — run batch + stream in parallel, unify results.
  - *Kappa* — one stream pipeline; batch by replaying the stream.
- **Time semantics**: event time (when it happened) vs processing time (when system saw it) vs ingestion time.
- **Windows**: tumbling (fixed), sliding (overlapping), session (activity-driven).
- **Watermarks**: how late-arriving events are tolerated before closing a window.
- **Exactly-once stream processing**: end-to-end needs transactional producers + idempotent sinks (Flink checkpoints, Kafka EOS).

### 🔹 4. Internal Working (Kafka + Flink stream)
1. Events land in Kafka topic, partitioned.
2. Flink job consumes in parallel (one slot per partition typically).
3. Each event → stateful operator updates RocksDB-backed state (key-local).
4. Periodic barrier checkpoints persist state + offsets atomically.
5. On failure: rewind to last checkpoint, reprocess from stored offsets.

**Failure points:** backpressure (sink slower than source → lag), skewed partitions (hot keys), state growing unbounded, watermark tuning.

### 🔹 5. Key Tradeoffs
- Batch: simpler; high throughput; latency hours.
- Stream: complex (state, time, fault-tolerance); latency seconds.
- Micro-batch (Spark Streaming) = compromise; seconds latency.
- Warehouse (Snowflake, BigQuery) = SQL on huge historical data, batch-ish.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. Batch vs stream?
2. What is MapReduce conceptually?

**Intermediate 🟡**
1. Event time vs processing time.
2. Windows + watermarks — why?

**Advanced 🔴**
1. Design real-time fraud detection at 100k events/s with <1s latency.
2. Lambda vs Kappa — when each?
3. Kafka EOS for a stream job writing to DB — what guarantees, what cost?

### 🔹 7. Real System Mapping
- **Google Dataflow / Beam**: unified batch+stream model.
- **Netflix Keystone** on Kafka+Flink for real-time processing.
- **LinkedIn Brooklin** for data streaming.
- **Netflix Psyberg** for incremental data engineering.
- **KSQLDB** for SQL-on-Kafka.
- **Spark** for big-batch ML + ETL at most companies.

### 🔹 8. What Most People Miss
- **Most companies overestimate real-time needs** — a 5-min batch is often fine.
- **State management is the hard part of streaming** — Flink's RocksDB state is real infra.
- **Backpressure**: slow sink propagates back to producer or builds up memory. Plan it.
- **Skewed keys** (celebrity user_id) break parallelism — need salt/split.
- **Exactly-once is "effectively once"** in practice — achieved via idempotency + dedup.

### 🔹 9. 30-Second Revision
Batch = periodic, high-throughput. Stream = continuous, low-latency. Flink for true streaming, Spark for batch/micro-batch, Kafka Streams for Kafka-native. Watermarks handle late data. Exactly-once = transactional source + idempotent sink. Most problems are fine with 5-min batch.

---

## 🔗 Cross-Topic Connections
- **Messaging (Kafka)**: the transport for streaming.
- **Databases**: sinks for processed output + warehouses for batch.
- **Caching**: stream jobs often feed caches (materialized views).
- **Microservices / EDA**: events flow through streaming infra.

---

### Confidence Check
- [ ] Can I design a real-time pipeline with exactly-once goals?
- [ ] Can I choose batch vs stream for a problem?

### Gaps
- Flink internals (checkpoint barriers).
- Beam portability.
- ClickHouse / Druid for real-time OLAP.
