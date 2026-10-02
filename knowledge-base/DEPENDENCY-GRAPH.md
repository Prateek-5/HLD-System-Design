# Topic Dependency Graph

> What to read before what. Each artifact has *prerequisite* concepts (you'll struggle without them) and *related* concepts (helpful but not required). This document maps those dependencies so you can find the right starting point or fill gaps.

---

## How to Read This

For each artifact:
- **Prerequisites**: what you should understand before reading.
- **Related**: artifacts that share concepts; useful but not strict prerequisites.
- **Followups**: what to read next if this artifact interested you.

If you're starting from scratch, walk the graph from the foundations up. If you have specific artifacts in mind, this map shows what to fill in.

---

## Foundations (no prerequisites)

These artifacts can be read first. They establish vocabulary the rest of the corpus uses.

```
┌──────────────────────────────────────────────────────────────────┐
│  TIER 0 — FOUNDATIONS                                              │
│  Start here regardless of path.                                    │
├──────────────────────────────────────────────────────────────────┤
│                                                                    │
│  • Event Loop & Async Runtime          (single-threaded async)     │
│  • V8 Internals & Hidden Classes       (JIT compilation)            │
│  • TCP & Network Fundamentals          (the network layer)          │
│  • Indexing & Storage Engines          (B-trees vs LSM)             │
│  • Caching Hierarchy                   (the universal pattern)      │
│  • Parallelism vs Concurrency          (foundational distinction)   │
│  • Metrics, Logs & Traces              (observability vocabulary)   │
│                                                                    │
└──────────────────────────────────────────────────────────────────┘
```

---

## Tier 1 — Built on Foundations

These artifacts depend on one or two Tier-0 concepts.

### MVCC & Isolation Levels
- **Prerequisites**: [Indexing](database-internals/indexing-and-storage-engines.md) (B-trees), basic transaction concept.
- **Related**: [WAL](database-internals/wal-and-crash-recovery.md), [CAP](distributed-systems/cap-consistency-and-replication.md).
- **Followups**: [Replication](database-internals/replication-strategies.md), [Query Optimization](database-internals/query-optimization-and-execution-plans.md).

### WAL & Crash Recovery
- **Prerequisites**: [Indexing](database-internals/indexing-and-storage-engines.md), [TCP](networking/tcp-and-network-fundamentals.md) (for replication context).
- **Related**: [MVCC](database-internals/mvcc-and-isolation-levels.md), [Replication](database-internals/replication-strategies.md).
- **Followups**: [Consensus](distributed-systems/leader-election-and-consensus.md) (Raft = replicated WAL).

### Locks, Mutexes & Lock-Free
- **Prerequisites**: [Parallelism vs Concurrency](concurrency/parallelism-vs-concurrency.md).
- **Related**: [CPU Caches](concurrency/cpu-caches-and-false-sharing.md), [Async Rust](concurrency/async-rust-and-the-borrow-checker.md).
- **Followups**: [Actor Model](concurrency/actor-model-and-message-passing.md) (avoiding locks via design).

### Backpressure & Queues
- **Prerequisites**: [Event Loop](js-runtime/event-loop-and-async-runtime.md) (or any concurrency model).
- **Related**: [TCP](networking/tcp-and-network-fundamentals.md) (TCP flow control), [Streams in Node](js-runtime/streams-and-backpressure-in-node.md).
- **Followups**: [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md), [Kafka](architecture-patterns/kafka-internals-and-stream-processing.md).

### Garbage Collection
- **Prerequisites**: basic memory model awareness.
- **Related**: [V8 Internals](js-runtime/v8-internals-and-hidden-classes.md), [JVM](concurrency/jvm-internals-and-virtual-threads.md), [MVCC](database-internals/mvcc-and-isolation-levels.md) (vacuum is GC).
- **Followups**: [Profiling](observability/profiling-and-flame-graphs.md).

### CPU Caches & False Sharing
- **Prerequisites**: [Parallelism vs Concurrency](concurrency/parallelism-vs-concurrency.md), [Locks](concurrency/locks-mutexes-and-lock-free.md).
- **Related**: [Locks](concurrency/locks-mutexes-and-lock-free.md), [Profiling](observability/profiling-and-flame-graphs.md).
- **Followups**: domain-specific performance work.

### Node.js Architecture & libuv
- **Prerequisites**: [Event Loop](js-runtime/event-loop-and-async-runtime.md), [V8 Internals](js-runtime/v8-internals-and-hidden-classes.md).
- **Related**: [TCP](networking/tcp-and-network-fundamentals.md), [Streams](js-runtime/streams-and-backpressure-in-node.md).
- **Followups**: [Web Workers](js-runtime/web-workers-and-shared-memory.md).

### Coroutines, Green Threads & Async Runtimes
- **Prerequisites**: [Parallelism vs Concurrency](concurrency/parallelism-vs-concurrency.md), [Event Loop](js-runtime/event-loop-and-async-runtime.md).
- **Related**: [Locks](concurrency/locks-mutexes-and-lock-free.md), [Backpressure](concurrency/backpressure-and-queues.md).
- **Followups**: [Async Rust](concurrency/async-rust-and-the-borrow-checker.md), [Go Runtime](concurrency/go-runtime-and-goroutines.md), [JVM](concurrency/jvm-internals-and-virtual-threads.md).

### HTTP/2, HTTP/3 & QUIC
- **Prerequisites**: [TCP](networking/tcp-and-network-fundamentals.md).
- **Related**: [TLS](networking/tls-and-mtls.md), [API Design](architecture-patterns/api-design-rest-vs-grpc.md).
- **Followups**: [Edge Computing](scalability/edge-computing-and-cdns.md), [WebSockets](networking/websockets-and-realtime-protocols.md).

### TLS & Mutual TLS
- **Prerequisites**: [TCP](networking/tcp-and-network-fundamentals.md).
- **Related**: [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md).
- **Followups**: [API Design](architecture-patterns/api-design-rest-vs-grpc.md), [Microservices](architecture-patterns/microservices-vs-monolith.md) (mTLS).

### DNS Deep Dive
- **Prerequisites**: [TCP](networking/tcp-and-network-fundamentals.md).
- **Related**: [Caching Hierarchy](caching/caching-hierarchy.md), [Edge Computing](scalability/edge-computing-and-cdns.md).
- **Followups**: [Load Balancing](scalability/load-balancing-strategies.md).

---

## Tier 2 — Composes Tier 1 Concepts

### Query Optimization & Execution Plans
- **Prerequisites**: [Indexing](database-internals/indexing-and-storage-engines.md), [MVCC](database-internals/mvcc-and-isolation-levels.md).
- **Related**: [OLTP vs OLAP](database-internals/oltp-vs-olap-and-columnar-storage.md).
- **Followups**: [Sharding](scalability/sharding-and-partitioning-strategies.md).

### Replication Strategies
- **Prerequisites**: [WAL](database-internals/wal-and-crash-recovery.md), [TCP](networking/tcp-and-network-fundamentals.md).
- **Related**: [CAP](distributed-systems/cap-consistency-and-replication.md), [Consensus](distributed-systems/leader-election-and-consensus.md).
- **Followups**: [Disaster Recovery](system-failures/disaster-recovery-and-rto-rpo.md).

### OLTP vs OLAP & Columnar Storage
- **Prerequisites**: [Indexing](database-internals/indexing-and-storage-engines.md), [MVCC](database-internals/mvcc-and-isolation-levels.md).
- **Related**: [Time-Series Databases](database-internals/time-series-databases.md), [Sharding](scalability/sharding-and-partitioning-strategies.md).
- **Followups**: [CQRS & Event Sourcing](architecture-patterns/cqrs-and-event-sourcing.md).

### Time-Series Databases
- **Prerequisites**: [OLTP vs OLAP](database-internals/oltp-vs-olap-and-columnar-storage.md), [Indexing](database-internals/indexing-and-storage-engines.md).
- **Related**: [Cardinality](observability/cardinality-and-the-economics-of-monitoring.md), [Metrics, Logs & Traces](observability/metrics-logs-traces.md).
- **Followups**: [SLOs](observability/slos-error-budgets-and-alerting.md).

### CAP, Consistency Models & Replication
- **Prerequisites**: [Replication](database-internals/replication-strategies.md), [TCP](networking/tcp-and-network-fundamentals.md).
- **Related**: [MVCC](database-internals/mvcc-and-isolation-levels.md), [Clocks](distributed-systems/clocks-time-and-ordering.md).
- **Followups**: [Consensus](distributed-systems/leader-election-and-consensus.md), [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md).

### Actor Model & Message Passing
- **Prerequisites**: [Event Loop](js-runtime/event-loop-and-async-runtime.md), [Locks](concurrency/locks-mutexes-and-lock-free.md).
- **Related**: [Backpressure](concurrency/backpressure-and-queues.md), [Coroutines](concurrency/coroutines-and-green-threads.md).
- **Followups**: [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md).

### Streams & Backpressure in Node
- **Prerequisites**: [Event Loop](js-runtime/event-loop-and-async-runtime.md), [Backpressure](concurrency/backpressure-and-queues.md), [Node.js Architecture](js-runtime/nodejs-architecture-and-libuv.md).
- **Related**: [TCP](networking/tcp-and-network-fundamentals.md).
- **Followups**: [Event-Driven Architecture](architecture-patterns/event-driven-architecture.md).

### Web Workers, Worker Threads & Shared Memory
- **Prerequisites**: [Event Loop](js-runtime/event-loop-and-async-runtime.md), [V8 Internals](js-runtime/v8-internals-and-hidden-classes.md), [Locks](concurrency/locks-mutexes-and-lock-free.md).
- **Related**: [Parallelism vs Concurrency](concurrency/parallelism-vs-concurrency.md).
- **Followups**: [Node.js Architecture](js-runtime/nodejs-architecture-and-libuv.md).

### Async Rust & the Borrow Checker
- **Prerequisites**: [Coroutines](concurrency/coroutines-and-green-threads.md), [Locks](concurrency/locks-mutexes-and-lock-free.md), [Parallelism vs Concurrency](concurrency/parallelism-vs-concurrency.md).
- **Related**: [Go Runtime](concurrency/go-runtime-and-goroutines.md), [Backpressure](concurrency/backpressure-and-queues.md).
- **Followups**: [TCP](networking/tcp-and-network-fundamentals.md) (real-world async I/O).

### Go Runtime & Goroutines
- **Prerequisites**: [Coroutines](concurrency/coroutines-and-green-threads.md), [Parallelism vs Concurrency](concurrency/parallelism-vs-concurrency.md).
- **Related**: [Actor Model](concurrency/actor-model-and-message-passing.md), [Locks](concurrency/locks-mutexes-and-lock-free.md), [GC](js-runtime/garbage-collection-and-memory-management.md).
- **Followups**: [Backpressure](concurrency/backpressure-and-queues.md), [Microservices](architecture-patterns/microservices-vs-monolith.md).

### JVM Internals & Virtual Threads
- **Prerequisites**: [Coroutines](concurrency/coroutines-and-green-threads.md), [GC](js-runtime/garbage-collection-and-memory-management.md), [Locks](concurrency/locks-mutexes-and-lock-free.md).
- **Related**: [Profiling](observability/profiling-and-flame-graphs.md).
- **Followups**: [Microservices](architecture-patterns/microservices-vs-monolith.md), [Kafka](architecture-patterns/kafka-internals-and-stream-processing.md) (Java/Scala).

### Python Runtime & the GIL
- **Prerequisites**: [Parallelism vs Concurrency](concurrency/parallelism-vs-concurrency.md), [Locks](concurrency/locks-mutexes-and-lock-free.md), [Event Loop](js-runtime/event-loop-and-async-runtime.md).
- **Related**: [Coroutines](concurrency/coroutines-and-green-threads.md).
- **Followups**: domain-specific Python deployments.

### WebSockets & Real-Time Protocols
- **Prerequisites**: [TCP](networking/tcp-and-network-fundamentals.md), [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md).
- **Related**: [Backpressure](concurrency/backpressure-and-queues.md), [Load Balancing](scalability/load-balancing-strategies.md).
- **Followups**: [Edge Computing](scalability/edge-computing-and-cdns.md).

### API Design — REST vs gRPC vs GraphQL
- **Prerequisites**: [TCP](networking/tcp-and-network-fundamentals.md), [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md), [TLS](networking/tls-and-mtls.md).
- **Related**: [Idempotency](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md), [Caching](caching/caching-hierarchy.md).
- **Followups**: [Microservices](architecture-patterns/microservices-vs-monolith.md), [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md).

### Distributed Tracing — A Deep Dive
- **Prerequisites**: [Metrics, Logs & Traces](observability/metrics-logs-traces.md), [API Design](architecture-patterns/api-design-rest-vs-grpc.md).
- **Related**: [Microservices](architecture-patterns/microservices-vs-monolith.md), [SLOs](observability/slos-error-budgets-and-alerting.md).
- **Followups**: [Profiling](observability/profiling-and-flame-graphs.md), [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md).

### Profiling & Flame Graphs
- **Prerequisites**: [Metrics, Logs & Traces](observability/metrics-logs-traces.md), [GC](js-runtime/garbage-collection-and-memory-management.md), [Locks](concurrency/locks-mutexes-and-lock-free.md).
- **Related**: [V8 Internals](js-runtime/v8-internals-and-hidden-classes.md), [JVM](concurrency/jvm-internals-and-virtual-threads.md).
- **Followups**: domain-specific perf work.

### Cardinality & Monitoring Economics
- **Prerequisites**: [Metrics, Logs & Traces](observability/metrics-logs-traces.md).
- **Related**: [Time-Series Databases](database-internals/time-series-databases.md), [SLOs](observability/slos-error-budgets-and-alerting.md), [Distributed Tracing](observability/distributed-tracing-deep-dive.md).
- **Followups**: cost discipline.

---

## Tier 3 — Combines Multiple Tier-2 Concepts

### Leader Election & Consensus
- **Prerequisites**: [CAP](distributed-systems/cap-consistency-and-replication.md), [WAL](database-internals/wal-and-crash-recovery.md), [Replication](database-internals/replication-strategies.md).
- **Related**: [Clocks](distributed-systems/clocks-time-and-ordering.md), [Sharding](scalability/sharding-and-partitioning-strategies.md).
- **Followups**: [Kubernetes Internals](scalability/kubernetes-internals.md) (etcd), [Kafka](architecture-patterns/kafka-internals-and-stream-processing.md) (KRaft).

### Clocks, Time & Ordering
- **Prerequisites**: [CAP](distributed-systems/cap-consistency-and-replication.md), [MVCC](database-internals/mvcc-and-isolation-levels.md).
- **Related**: [Consensus](distributed-systems/leader-election-and-consensus.md), [CQRS](architecture-patterns/cqrs-and-event-sourcing.md).
- **Followups**: [Distributed Transactions](distributed-systems/distributed-transactions-2pc-3pc.md), [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md).

### Gossip Protocols & Cluster Membership
- **Prerequisites**: [CAP](distributed-systems/cap-consistency-and-replication.md), [Consensus](distributed-systems/leader-election-and-consensus.md).
- **Related**: [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md).
- **Followups**: [Sharding](scalability/sharding-and-partitioning-strategies.md), [Kafka](architecture-patterns/kafka-internals-and-stream-processing.md).

### Distributed Transactions — 2PC, 3PC
- **Prerequisites**: [CAP](distributed-systems/cap-consistency-and-replication.md), [Consensus](distributed-systems/leader-election-and-consensus.md), [WAL](database-internals/wal-and-crash-recovery.md).
- **Related**: [Replication](database-internals/replication-strategies.md), [MVCC](database-internals/mvcc-and-isolation-levels.md).
- **Followups**: [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md).

### Sharding & Partitioning Strategies
- **Prerequisites**: [Indexing](database-internals/indexing-and-storage-engines.md), [CAP](distributed-systems/cap-consistency-and-replication.md), [Replication](database-internals/replication-strategies.md).
- **Related**: [Caching](caching/caching-hierarchy.md) (consistent hashing), [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md).
- **Followups**: [Multi-Tenancy](scalability/multi-tenancy-strategies.md), [Load Balancing](scalability/load-balancing-strategies.md).

### Load Balancing Strategies
- **Prerequisites**: [TCP](networking/tcp-and-network-fundamentals.md), [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md), [DNS](networking/dns-deep-dive.md).
- **Related**: [Sharding](scalability/sharding-and-partitioning-strategies.md), [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md).
- **Followups**: [Edge Computing](scalability/edge-computing-and-cdns.md), [Kubernetes](scalability/kubernetes-internals.md).

### Edge Computing & CDNs
- **Prerequisites**: [Caching](caching/caching-hierarchy.md), [TCP](networking/tcp-and-network-fundamentals.md), [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md), [DNS](networking/dns-deep-dive.md).
- **Related**: [Load Balancing](scalability/load-balancing-strategies.md), [V8 Internals](js-runtime/v8-internals-and-hidden-classes.md) (Workers).
- **Followups**: [LLM Serving](architecture-patterns/llm-serving-and-vector-databases.md).

### Cascading Failures & Circuit Breakers
- **Prerequisites**: [Backpressure](concurrency/backpressure-and-queues.md), [Replication](database-internals/replication-strategies.md), [Load Balancing](scalability/load-balancing-strategies.md).
- **Related**: [Microservices](architecture-patterns/microservices-vs-monolith.md), [Distributed Tracing](observability/distributed-tracing-deep-dive.md).
- **Followups**: [Timeouts/Retries](system-failures/timeouts-retries-and-idempotency.md), [Chaos Engineering](system-failures/chaos-engineering-and-game-days.md).

### Timeouts, Retries & Idempotency
- **Prerequisites**: [TCP](networking/tcp-and-network-fundamentals.md), [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md).
- **Related**: [API Design](architecture-patterns/api-design-rest-vs-grpc.md), [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md).
- **Followups**: [Idempotency](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md).

### SLOs, Error Budgets & Alerting
- **Prerequisites**: [Metrics, Logs & Traces](observability/metrics-logs-traces.md).
- **Related**: [Cardinality](observability/cardinality-and-the-economics-of-monitoring.md), [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md).
- **Followups**: [Postmortems](system-failures/postmortems-and-incident-response.md), [Capacity Planning](scalability/auto-scaling-and-capacity-planning.md).

### Auto-Scaling & Capacity Planning
- **Prerequisites**: [Load Balancing](scalability/load-balancing-strategies.md), [Sharding](scalability/sharding-and-partitioning-strategies.md), [SLOs](observability/slos-error-budgets-and-alerting.md).
- **Related**: [Backpressure](concurrency/backpressure-and-queues.md), [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md).
- **Followups**: [Disaster Recovery](system-failures/disaster-recovery-and-rto-rpo.md).

### Multi-Tenancy Strategies
- **Prerequisites**: [Sharding](scalability/sharding-and-partitioning-strategies.md), [Caching](caching/caching-hierarchy.md), [Backpressure](concurrency/backpressure-and-queues.md).
- **Related**: [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md), [Load Balancing](scalability/load-balancing-strategies.md).
- **Followups**: [Security IR](system-failures/security-incident-response.md).

### Postmortems & Incident Response
- **Prerequisites**: [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md), [SLOs](observability/slos-error-budgets-and-alerting.md), [Distributed Tracing](observability/distributed-tracing-deep-dive.md).
- **Related**: [Microservices](architecture-patterns/microservices-vs-monolith.md).
- **Followups**: [Chaos Engineering](system-failures/chaos-engineering-and-game-days.md), [Disaster Recovery](system-failures/disaster-recovery-and-rto-rpo.md), [Security IR](system-failures/security-incident-response.md).

### Chaos Engineering & Game Days
- **Prerequisites**: [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md), [SLOs](observability/slos-error-budgets-and-alerting.md), [Postmortems](system-failures/postmortems-and-incident-response.md).
- **Related**: [Timeouts/Retries](system-failures/timeouts-retries-and-idempotency.md).
- **Followups**: [Disaster Recovery](system-failures/disaster-recovery-and-rto-rpo.md).

### Disaster Recovery, RTO & RPO
- **Prerequisites**: [Replication](database-internals/replication-strategies.md), [WAL](database-internals/wal-and-crash-recovery.md), [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md), [Postmortems](system-failures/postmortems-and-incident-response.md).
- **Related**: [Capacity Planning](scalability/auto-scaling-and-capacity-planning.md).
- **Followups**: [Security IR](system-failures/security-incident-response.md).

### Feature Flags & Progressive Delivery
- **Prerequisites**: [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md), [SLOs](observability/slos-error-budgets-and-alerting.md).
- **Related**: [Postmortems](system-failures/postmortems-and-incident-response.md), [API Design](architecture-patterns/api-design-rest-vs-grpc.md).
- **Followups**: [Strangler Fig](architecture-patterns/strangler-fig-and-legacy-migration.md), [Chaos Engineering](system-failures/chaos-engineering-and-game-days.md).

### Security Incident Response
- **Prerequisites**: [Postmortems](system-failures/postmortems-and-incident-response.md), [Disaster Recovery](system-failures/disaster-recovery-and-rto-rpo.md).
- **Related**: [TLS](networking/tls-and-mtls.md), [Multi-Tenancy](scalability/multi-tenancy-strategies.md).
- **Followups**: domain-specific security work.

---

## Tier 4 — Top of the Graph

### Microservices vs Monolith
- **Prerequisites**: [API Design](architecture-patterns/api-design-rest-vs-grpc.md), [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md), [Distributed Tracing](observability/distributed-tracing-deep-dive.md), [SLOs](observability/slos-error-budgets-and-alerting.md).
- **Related**: [DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md).
- **Followups**: [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md), [Event-Driven](architecture-patterns/event-driven-architecture.md), [Strangler Fig](architecture-patterns/strangler-fig-and-legacy-migration.md).

### Sagas & Distributed Transactions
- **Prerequisites**: [Distributed Transactions 2PC/3PC](distributed-systems/distributed-transactions-2pc-3pc.md), [CAP](distributed-systems/cap-consistency-and-replication.md), [Timeouts/Retries](system-failures/timeouts-retries-and-idempotency.md).
- **Related**: [Idempotency](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md), [Event-Driven](architecture-patterns/event-driven-architecture.md).
- **Followups**: [CQRS](architecture-patterns/cqrs-and-event-sourcing.md).

### CQRS & Event Sourcing
- **Prerequisites**: [MVCC](database-internals/mvcc-and-isolation-levels.md), [Replication](database-internals/replication-strategies.md), [OLTP vs OLAP](database-internals/oltp-vs-olap-and-columnar-storage.md).
- **Related**: [Event-Driven](architecture-patterns/event-driven-architecture.md), [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md).
- **Followups**: [Anti-Corruption Layer & DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md).

### Event-Driven Architecture
- **Prerequisites**: [Backpressure](concurrency/backpressure-and-queues.md), [Idempotency](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md), [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md).
- **Related**: [Distributed Tracing](observability/distributed-tracing-deep-dive.md), [Microservices](architecture-patterns/microservices-vs-monolith.md).
- **Followups**: [Kafka Internals](architecture-patterns/kafka-internals-and-stream-processing.md), [CQRS](architecture-patterns/cqrs-and-event-sourcing.md).

### Idempotency Receivers & Exactly-Once
- **Prerequisites**: [Timeouts/Retries](system-failures/timeouts-retries-and-idempotency.md), [API Design](architecture-patterns/api-design-rest-vs-grpc.md).
- **Related**: [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md), [Event-Driven](architecture-patterns/event-driven-architecture.md).
- **Followups**: [Kafka](architecture-patterns/kafka-internals-and-stream-processing.md).

### Anti-Corruption Layer & DDD
- **Prerequisites**: [Microservices](architecture-patterns/microservices-vs-monolith.md), [API Design](architecture-patterns/api-design-rest-vs-grpc.md).
- **Related**: [Strangler Fig](architecture-patterns/strangler-fig-and-legacy-migration.md), [CQRS](architecture-patterns/cqrs-and-event-sourcing.md), [Event-Driven](architecture-patterns/event-driven-architecture.md).
- **Followups**: domain-specific architecture.

### Strangler Fig & Legacy Migration
- **Prerequisites**: [Microservices](architecture-patterns/microservices-vs-monolith.md), [DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md), [Feature Flags](system-failures/feature-flags-and-progressive-delivery.md).
- **Related**: [API Design](architecture-patterns/api-design-rest-vs-grpc.md), [SLOs](observability/slos-error-budgets-and-alerting.md).
- **Followups**: long-term migration practice.

### Kafka Internals & Stream Processing
- **Prerequisites**: [Replication](database-internals/replication-strategies.md), [Consensus](distributed-systems/leader-election-and-consensus.md), [Backpressure](concurrency/backpressure-and-queues.md), [Event-Driven](architecture-patterns/event-driven-architecture.md).
- **Related**: [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md), [CQRS](architecture-patterns/cqrs-and-event-sourcing.md), [WAL](database-internals/wal-and-crash-recovery.md).
- **Followups**: stream processing applications.

### Kubernetes Internals
- **Prerequisites**: [Consensus](distributed-systems/leader-election-and-consensus.md) (etcd), [Load Balancing](scalability/load-balancing-strategies.md), [Microservices](architecture-patterns/microservices-vs-monolith.md).
- **Related**: [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md), [Capacity Planning](scalability/auto-scaling-and-capacity-planning.md).
- **Followups**: domain-specific operational work.

### LLM Serving & Vector Databases
- **Prerequisites**: [API Design](architecture-patterns/api-design-rest-vs-grpc.md), [Caching](caching/caching-hierarchy.md), [Edge Computing](scalability/edge-computing-and-cdns.md), [Backpressure](concurrency/backpressure-and-queues.md).
- **Related**: [Capacity Planning](scalability/auto-scaling-and-capacity-planning.md), [SLOs](observability/slos-error-budgets-and-alerting.md).
- **Followups**: AI/ML infrastructure work.

---

## Visual Summary

```
                              Tier 4 (Top)
                              ─────────────
                         LLM Serving / Kafka
                       /   |          |    \
                      |  Microservices  Kubernetes
                       \   |   |   |    /
                    Sagas  CQRS  EDA  Idempotency
                            |    |    |
                            DDD  StranglerFig
                              \  /
                               Tier 3
                            ───────────
              Consensus / Clocks / Sharding / LoadBalancing
              CascadingFailures / SLOs / Postmortems / DR
                              |
                            Tier 2
                          ───────────
                        CAP / Replication
              QueryOpt / OLTP-OLAP / TimeSeries / DistTracing
              Coroutines / AsyncRust / Go / JVM / Python
              Streams / WebWorkers / API / WebSockets / Profiling
                              |
                            Tier 1
                          ───────────
                        MVCC / WAL / Locks
                      Backpressure / GC / CPU
                       NodeArch / HTTP / TLS / DNS
                              |
                          Tier 0 (Foundations)
                          ────────────────────
              EventLoop / V8 / TCP / Indexing / Caching
                  Parallelism vs Concurrency
                       Metrics-Logs-Traces
```

---

## How to Use This Graph

**To find a starting point**: scan the Tier 0 list. Pick what relates to a problem you're currently facing.

**To fill a knowledge gap**: find the artifact you want to read; check its prerequisites; ensure those are covered.

**To choose what to read next**: after finishing an artifact, check its Followups. They naturally extend its concepts.

**For comprehensive coverage**: walk the tiers from 0 to 4. This is the depth-first complete path.

**For role-specific paths**: see [LEARNING-PATHS.md](LEARNING-PATHS.md).

The graph isn't strict; many Tier-3 artifacts are accessible with partial Tier-2 knowledge. But understanding strengthens dramatically when prerequisites are solid.
