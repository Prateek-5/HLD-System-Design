# 🔗 Cross-Reference — Learning Path ↔ Knowledge Base

> **What this file is.** The [`learn/00_learning_path.md`](../learn/00_learning_path.md) pipeline is the **beginner → intermediate** track: build correct intuition, layer by layer, until you can defend every box on a whiteboard. This `knowledge-base/` is the **senior/staff deep-dive** track: internals, failure modes, and the 20% that separates juniors from seniors.
>
> This file is the bridge. For each learning-path topic, it points to the knowledge-base artifact(s) that go deeper — and flags where one side has **no counterpart** on the other.

> **⚠️ Trust note.** The knowledge-base files vary in quality (they read as LLM-generated, vibe-reviewed but not uniformly fact-checked). Before trusting any specific number, theorem name, or "company X did Y" claim from a KB file, check its score and flagged errors in [`_AUDIT/`](_AUDIT/). The learning-path files were separately remediated and conform to a strict template.

**How to use it:** finish a learning-path topic first (intuition + interview lens), *then* jump to its KB deep-dive when you want senior-level depth. Don't start in the KB — several files skip the fundamentals the path teaches.

---

## Layer 1 — Foundations: Networking

| Learning-path topic | Knowledge-base deep-dive | What the KB adds |
|---|---|---|
| `foundations/networking/ip.md` | `networking/tcp-and-network-fundamentals.md` | Packet-level mechanics, congestion control |
| `foundations/networking/osi.md` | `networking/tcp-and-network-fundamentals.md` | Layer-by-layer framing in depth |
| `foundations/networking/tcp-udp.md` | `networking/tcp-and-network-fundamentals.md` | Handshake, slow-start, AIMD, BBR |
| `foundations/networking/dns.md` | `networking/dns-deep-dive.md` | Recursion, caching, record types in detail |
| `foundations/networking/proxy.md` | `scalability/load-balancing-strategies.md` *(partial)* | Reverse-proxy as L7 LB; no dedicated proxy file |
| *(path has no separate HTTP/2-3 topic)* | `networking/http-2-and-http-3.md` | Multiplexing, HPACK, QUIC — **KB-only** |

---

## Layer 2 — Foundations: Scaling & Availability

| Learning-path topic | Knowledge-base deep-dive | What the KB adds |
|---|---|---|
| `foundations/scaling/load-balancing.md` | `scalability/load-balancing-strategies.md` | L4/L7, algorithms, health checks |
| `foundations/scaling/clustering.md` | `distributed-systems/gossip-protocols-and-membership.md`; `scalability/kubernetes-internals.md` | Membership, failure detection, orchestration |
| `foundations/scaling/caching.md` | `caching/caching-hierarchy.md` | Eviction, stampede, write policies |
| `foundations/scaling/cdn.md` | `scalability/edge-computing-and-cdns.md` | Edge compute, cache hierarchy at the edge |
| `foundations/scaling/availability.md` | `system-failures/cascading-failures-and-circuit-breakers.md`; `observability/slos-error-budgets-and-alerting.md` | Failure propagation, error budgets |
| `foundations/scaling/scalability.md` | `scalability/auto-scaling-and-capacity-planning.md`; `scalability/sharding-and-partitioning-strategies.md` | Capacity planning, predictive scaling |
| `foundations/scaling/storage.md` | `database-internals/indexing-and-storage-engines.md` *(partial)* | Storage-engine internals |

---

## Layer 3 — The Data Layer

| Learning-path topic | Knowledge-base deep-dive | What the KB adds |
|---|---|---|
| `data/db-and-dbms.md` | `database-internals/postgres-internals-deep-dive.md` | Real engine internals |
| `data/sql-databases.md` | `database-internals/postgres-internals-deep-dive.md`; `query-optimization-and-execution-plans.md` | Planner, EXPLAIN, cost model |
| `data/nosql-databases.md` | `database-internals/indexing-and-storage-engines.md` *(LSM)*; `oltp-vs-olap-and-columnar-storage.md` | LSM-tree, columnar |
| `data/sql-vs-nosql.md` | `database-internals/oltp-vs-olap-and-columnar-storage.md` | Workload-driven choice |
| `data/database-replication.md` | `database-internals/replication-strategies.md`; `distributed-systems/cap-consistency-and-replication.md` | Sync/async, logical/physical, consistency |
| `data/indexes.md` | `database-internals/indexing-and-storage-engines.md`; `query-optimization-and-execution-plans.md` | B-tree vs LSM, index-only scans |
| `data/normalization-denormalization.md` | `database-internals/oltp-vs-olap-and-columnar-storage.md` *(partial)* | Star/snowflake, OLAP modeling |
| `data/acid-base.md` | `database-internals/mvcc-and-isolation-levels.md`; `wal-and-crash-recovery.md` | MVCC, isolation anomalies, ARIES |
| `data/cap-theorem.md` | `distributed-systems/cap-consistency-and-replication.md` | Consistency models, PACELC |
| `data/pacelc-theorem.md` | `distributed-systems/cap-consistency-and-replication.md`; `clocks-time-and-ordering.md` | Latency/consistency tradeoff, TrueTime |
| `data/transactions.md` | `database-internals/mvcc-and-isolation-levels.md`; `wal-and-crash-recovery.md` | Isolation levels, durability |
| `data/distributed-transactions.md` | `distributed-systems/distributed-transactions-2pc-3pc.md`; `architecture-patterns/saga-pattern-and-distributed-transactions.md` | 2PC/3PC, sagas, pivots |
| `data/sharding.md` | `scalability/sharding-and-partitioning-strategies.md` | Hash/range, hot shards, resharding |
| `data/consistent-hashing.md` | `scalability/sharding-and-partitioning-strategies.md`; `load-balancing-strategies.md` | Ring details, bounded-load |
| `data/database-federation.md` | `database-internals/oltp-vs-olap-and-columnar-storage.md` *(partial)* | Warehouse/lakehouse — **weak coverage** |

---

## Layer 4 — Architecture

| Learning-path topic | Knowledge-base deep-dive | What the KB adds |
|---|---|---|
| `architecture/n-tier-architecture.md` | `architecture-patterns/microservices-vs-monolith.md` | Decision framework, distributed monolith |
| `architecture/message-brokers.md` | `architecture-patterns/kafka-internals-and-stream-processing.md`; `event-driven-architecture.md` | Partitions, offsets, ISR *(see audit — gaps)* |
| `architecture/message-queues.md` | `architecture-patterns/event-driven-architecture.md`; `concurrency/backpressure-and-queues.md` | Delivery semantics, backpressure |
| `architecture/pub-sub.md` | `architecture-patterns/event-driven-architecture.md`; `kafka-internals-and-stream-processing.md` | Fan-out, ordering |
| `architecture/enterprise-service-bus.md` | `architecture-patterns/event-driven-architecture.md` *(partial)* | Modern EDA vs ESB |
| `architecture/monolith-vs-microservices.md` | `architecture-patterns/microservices-vs-monolith.md`; `anti-corruption-layer-and-domain-driven-design.md`; `strangler-fig-and-legacy-migration.md` | DDD boundaries, migration |
| `architecture/event-driven-architecture.md` | `architecture-patterns/event-driven-architecture.md` | Choreography vs orchestration, outbox |
| `architecture/event-sourcing.md` | `architecture-patterns/cqrs-and-event-sourcing.md` ⭐ | Fold, snapshots, schema evolution *(best KB file)* |
| `architecture/cqrs.md` | `architecture-patterns/cqrs-and-event-sourcing.md` ⭐ | Read/write split, projections |
| `architecture/api-gateway.md` | `architecture-patterns/api-design-rest-vs-grpc.md` *(partial)* | Gateway vs mesh |
| `architecture/rest-graphql-grpc.md` | `architecture-patterns/api-design-rest-vs-grpc.md`; `grpc-internals-and-streaming.md`; `graphql-deep-dive.md` | Protocol internals, pagination |
| `architecture/long-polling-websockets-sse.md` | `networking/websockets-and-realtime-protocols.md` | Framing, realtime protocol choice |

---

## Layer 5 — Advanced Reliability & Security

| Learning-path topic | Knowledge-base deep-dive | What the KB adds |
|---|---|---|
| `reliability/geohashing-quadtrees.md` | — | **No KB counterpart** |
| `reliability/circuit-breaker.md` | `system-failures/cascading-failures-and-circuit-breakers.md` | States, bulkheads, failure propagation |
| `reliability/rate-limiting.md` | `system-failures/timeouts-retries-and-idempotency.md` *(adjacent)* | No dedicated rate-limit file — **gap** |
| `reliability/service-discovery.md` | `distributed-systems/gossip-protocols-and-membership.md`; `scalability/kubernetes-internals.md` | Membership, k8s service routing |
| `reliability/sla-slo-sli.md` | `observability/slos-error-budgets-and-alerting.md` | Burn-rate alerting, error budgets |
| `reliability/disaster-recovery.md` | `system-failures/disaster-recovery-and-rto-rpo.md` | RTO/RPO tiers, strategies |
| `reliability/vms-and-containers.md` | `scalability/kubernetes-internals.md` | Scheduler, controllers, etcd |
| `reliability/oauth-oidc.md` | — | **No KB counterpart** (auth largely absent from KB) |
| `reliability/sso.md` | — | **No KB counterpart** |
| `reliability/ssl-tls-mtls.md` | `networking/tls-and-mtls.md` | Handshake, 0-RTT, mTLS internals |

---

## Layer 6 — Interview Systems & Frameworks

| Learning-path topic | Knowledge-base deep-dive | What the KB adds |
|---|---|---|
| `interview-systems/*` (url-shortener, whatsapp, twitter, netflix, uber) | `WORKED-EXAMPLES.md` | End-to-end worked scenarios with code |
| `frameworks/thinking-framework.md` | `INDEX.md`; `LEARNING-PATHS.md` | Reading orders by role/level |
| `frameworks/request-lifecycle.md` | `networking/*` + `WORKED-EXAMPLES.md` | The full request path across the stack |

---

## 🧭 Knowledge-base topics with NO learning-path counterpart

These are **senior/staff extras** the interview-focused path deliberately doesn't cover. Pursue them for depth, runtime-engineering roles, or staff interviews — **not** for a first pass:

- **`concurrency/`** (entire dir) — GIL, goroutine scheduler, JVM virtual threads, actor model, locks/lock-free, false sharing, async Rust, coroutines, parallelism vs concurrency. *Runtime-engineering, mostly beyond system-design interviews.*
- **`js-runtime/`** (entire dir) — event loop, V8 hidden classes, GC, libuv, Node streams, web workers. *Node/JS-specialist depth.*
- **`observability/`** — metrics/logs/traces, distributed tracing, cardinality economics, profiling/flame graphs (only SLOs maps to the path).
- **`database-internals/`** extras — `postgres-internals-deep-dive`, `time-series-databases`, `query-optimization-and-execution-plans`.
- **`distributed-systems/`** extras — `clocks-time-and-ordering`, `leader-election-and-consensus`.
- **`scalability/`** extras — `gpu-and-accelerator-computing`, `multi-tenancy-strategies`, `kubernetes-internals`.
- **`system-failures/`** ops extras — `chaos-engineering-and-game-days`, `postmortems-and-incident-response`, `feature-flags-and-progressive-delivery`, `security-incident-response`.
- **`architecture-patterns/`** extras — `llm-serving-and-vector-databases`, `idempotency-receivers-and-exactly-once-semantics`, `kafka-internals-and-stream-processing`, `grpc-internals-and-streaming`.

## 🕳️ Learning-path topics the knowledge base does NOT deepen (KB gaps)

If you want senior depth on these, the KB won't help — go to primary sources:
- **Auth/security:** `oauth-oidc`, `sso` — no KB file. (KB security is incident-response, not protocol.)
- **`rate-limiting`** — no dedicated KB file.
- **`geohashing-quadtrees`** — no KB file.
- **`database-federation`**, **`normalization-denormalization`** — only partial/adjacent KB coverage.
- **`proxy`** — folded into load-balancing; no dedicated treatment.

---

*See [`_AUDIT/README.md`](_AUDIT/README.md) for per-directory quality scores and the specific factual errors to avoid in each knowledge-base file.*
