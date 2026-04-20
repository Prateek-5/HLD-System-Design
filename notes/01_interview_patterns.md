# 🎯 01 · Interview Patterns

> The recurring patterns behind 80% of system design questions. Memorize these; everything else is a permutation.

---

## Pattern 1 — Scaling Reads

**Signal:** "100× more reads than writes." Feeds, catalogs, profiles, search.

**Playbook:**
1. **Cache** the hot reads (Redis/Memcached). Aim for 95%+ hit rate.
2. **Read replicas** for DB reads; direct writes to primary. Watch replication lag.
3. **CDN** for static/public content.
4. **Denormalize** / precompute to kill joins.
5. **CQRS** — separate read model optimized for the query.

**Watch out for:** cache stampede, read-after-write lag, fan-out spikes.

---

## Pattern 2 — Scaling Writes

**Signal:** write QPS approaches single-node DB ceiling (~10k–50k).

**Playbook:**
1. **Shard** by a high-cardinality low-skew key; use **consistent hashing**.
2. **Batch writes** — accumulate in app, write in chunks.
3. **Async via queue** — decouple producer from DB.
4. **LSM-based DB** (Cassandra, RocksDB) for write-optimized storage.
5. **Event sourcing / append-only log** for extreme write concurrency.

**Watch out for:** hot shards, cross-shard transactions, rebalancing pain.

---

## Pattern 3 — Handling Failures Gracefully

**Signal:** "what happens when X dies?", "how do you handle a slow downstream?"

**Playbook:**
1. **Timeout** on every cross-service call.
2. **Retry with exponential backoff + jitter** — never raw retry.
3. **Circuit breaker** — open on sustained failures.
4. **Bulkhead** — isolate resource pools so one sick dependency doesn't exhaust threads for others.
5. **Fallback / graceful degradation** — cached data, trending feed, default response.
6. **Idempotency keys** — retries safe.

**Watch out for:** retry storms (bad retries amplify load), no fallback = outage, `TIME_WAIT` exhaustion.

---

## Pattern 4 — Async Processing

**Signal:** long work, bursts, cross-service coordination, decoupling.

**Playbook:**
1. **Producer → Queue/Topic → Consumer pool**.
2. **Visibility timeout** or ack-before-delete for at-least-once.
3. **Consumers idempotent** (always).
4. **DLQ** for poison messages; alerts on depth.
5. **Autoscale workers** on queue depth.
6. **Outbox pattern** — write event atomically with DB change; ship via CDC to avoid dual-write inconsistency.

**Watch out for:** ordering (only within partition), exactly-once (requires dedup), queue as DB anti-pattern.

---

## Pattern 5 — Geo Distribution

**Signal:** global users, <200 ms expected, regional fault tolerance.

**Playbook:**
1. **CDN** at the edge for static content.
2. **GeoDNS / anycast** for regional routing.
3. **Read replicas per region**; writes centralized OR multi-master with CRDTs.
4. **Latency budget**: any cross-ocean hop costs 200 ms — design to avoid in hot path.
5. **Data sovereignty**: EU users' data stays in EU region (GDPR).

**Watch out for:** multi-master conflicts, replication lag, DNS cache TTLs slowing failover.

---

## Pattern 6 — Real-Time Push

**Signal:** chat, notifications, live feeds, collaborative editing.

**Playbook:**
1. **WebSocket** for bi-directional, **SSE** for server-push only, **long polling** as fallback.
2. **Sticky routing** to connection shard via consistent hashing.
3. **Presence** via Redis pub-sub + TTL.
4. **Offline delivery** via durable queue per user; flush on reconnect.
5. **Fan-out** via pub-sub; per-connection server does delivery.

**Watch out for:** connection storms on deploy, sticky-session issues, mobile flakiness → reconnect logic.

---

## Pattern 7 — Search & Analytics

**Signal:** full-text search, aggregations, ad-hoc querying.

**Playbook:**
1. **Elasticsearch / OpenSearch** (Lucene-based) for search; B-tree SQL is wrong tool.
2. **CDC from OLTP → search index** via Kafka/Debezium.
3. **Time-series DB** (Prometheus, Druid, Influx) for metrics.
4. **OLAP warehouse** (BigQuery, Snowflake, Redshift) for slicing large data.
5. **Precompute** materialized views for common queries.

**Watch out for:** index consistency lag, re-index storms, cost (search and OLAP are expensive).

---

## Pattern 8 — Preventing Abuse / Protecting Backends

**Signal:** rate-limiting, DDoS, fair use, quota.

**Playbook:**
1. **Edge**: WAF, anycast DDoS absorption (Cloudflare).
2. **API gateway**: per-key token bucket in Redis.
3. **Per-user + per-IP + per-endpoint** layered limits.
4. **Fail-open** on limiter outage (with alert), never fail-closed.
5. **Authn before counting** where possible.

**Watch out for:** hash-based limits shared NAT users, distributed counter correctness, cold-start on pod restarts.

---

## Pattern 9 — Strong Consistency in a Distributed System

**Signal:** money, inventory, reservations, uniqueness.

**Playbook:**
1. **Single-node with replicas** for sync replication, if scale allows.
2. **Consensus (Raft/Paxos)** for replicated state machines (etcd, Zookeeper).
3. **2PC** only across DBs you control; avoid in microservices.
4. **Sagas** for multi-service flows + compensations.
5. **Idempotent + outbox** to avoid dual-write.
6. **Serializable isolation** when needed (cost: concurrency).

**Watch out for:** assuming "ACID" means cross-service; 2PC blocking; distributed locks (they're almost always wrong).

---

## Pattern 10 — Observability

**Signal:** "how do you monitor?", "how do you debug?"

**Playbook:**
1. **Metrics** (Prometheus): RED (Rate, Errors, Duration) per service.
2. **Logs** (Loki/Elastic): structured, correlated via trace ID.
3. **Traces** (Jaeger/Tempo): end-to-end per request.
4. **SLOs** with error budgets; alert on burn rate (fast/slow), not raw spikes.
5. **Runbooks** for every alert.

**Watch out for:** alert fatigue, over-aggregated metrics hiding per-tenant issues, logs without correlation.

---

## Meta-pattern — Component Justification

For every box you draw, be ready to answer:
- **Why is this here?** (what would fail without it)
- **Cost?** (latency, $, ops)
- **Failure mode?** (what happens when it dies)
- **How does it scale?** (10×, 100×)

If you can answer these four for every component, you sound senior.

---

## 20 FAQ design problems — pattern mapping

| Problem | Dominant patterns |
|---|---|
| URL shortener | Scaling reads + cache + shard by hash |
| WhatsApp | Real-time push + fan-out + offline queue |
| Twitter | Hybrid fan-out + cache + search |
| Instagram | Same as Twitter + media CDN |
| Netflix | CDN + video pipeline + adaptive bitrate |
| Uber | Geo index + saga for trip/payment + real-time |
| Google Docs | OT/CRDT + real-time push + versioned persistence |
| Google Drive / S3 | Object storage + chunking + dedupe |
| BookMyShow / IRCTC | Seat lock + strong consistency + queue for surge |
| Stripe | Idempotency + saga + ACID on payments |
| Gmail | Search + fan-out + distributed storage |
| Amazon (e-commerce) | Microservices + event-driven + search |
| PagerDuty / alerting | Anomaly detection + rate limit alerts + escalation |
| Analytics (GA) | Event firehose + OLAP + sampling |
| Live streaming (ESPN/Twitch) | Video pipeline + CDN + low-latency push |
| Chat (Slack/Discord) | Real-time push + channels/pub-sub |
| Cab aggregator | Geo index + dispatch + surge pricing |
| Food delivery | Geo index + routing + orchestration |
| Cloud provider (AWS) | Multi-tenancy + isolation + control plane |
| Chess/turn-based game | State machine + ELO matchmaking + persistent state |

---

## Final reminder

Patterns ≠ rigid recipes. They are starting points. The actual interview is about **defending your choices** from alternatives. Always say what you did NOT pick and why.
