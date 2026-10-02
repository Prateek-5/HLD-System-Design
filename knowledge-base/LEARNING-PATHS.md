# Learning Paths

> Curated reading orders through the knowledge base. Pick the path that matches your role, level, or current challenge. Each path lists 8-12 artifacts in order, with a brief justification of *why* each piece comes when it does.

---

## How to Use These Paths

Read in order. Earlier pieces lay groundwork later pieces depend on. Each artifact takes ~20-30 minutes to read carefully; ~10 minutes if you're skimming. A typical path is one focused week of reading or three relaxed weeks.

After completing a path, follow the **Cross-Domain Connections** section in any artifact to branch laterally. The corpus is a graph; paths are linear samples of it.

---

## By Experience Level

### Junior Engineer (0-2 years)

The goal: build foundational mental models. Don't try to absorb everything. Read for *intuition*, not memorization.

1. **[The Event Loop & Async Runtime](js-runtime/event-loop-and-async-runtime.md)** — explains why async is everywhere; foundation for understanding modern runtimes.
2. **[V8 Internals & Hidden Classes](js-runtime/v8-internals-and-hidden-classes.md)** — the JIT compiler under your code; why object shape matters.
3. **[Indexing & Storage Engines](database-internals/indexing-and-storage-engines.md)** — what your queries actually do under the hood.
4. **[Caching Hierarchy](caching/caching-hierarchy.md)** — the universal pattern; once you see it, you see it everywhere.
5. **[TCP & Network Fundamentals](networking/tcp-and-network-fundamentals.md)** — the layer under every connection your code makes.
6. **[Backpressure & Queues](concurrency/backpressure-and-queues.md)** — the diagnostic frame for many performance problems.
7. **[Metrics, Logs & Traces](observability/metrics-logs-traces.md)** — how production systems are debugged.
8. **[Timeouts, Retries & Idempotency](system-failures/timeouts-retries-and-idempotency.md)** — the foundation contract for every distributed call.
9. **[API Design — REST vs gRPC vs GraphQL](architecture-patterns/api-design-rest-vs-grpc.md)** — protocols and their trade-offs.
10. **[MVCC & Isolation Levels](database-internals/mvcc-and-isolation-levels.md)** — modern database concurrency; foundational for understanding transactions.

After this path: you have the vocabulary and intuition for most senior engineering conversations. You'll recognize patterns; you'll know which questions to ask.

---

### Mid-Level Engineer (2-5 years)

The goal: deepen practical knowledge and start seeing systemic patterns.

1. **[Parallelism vs Concurrency](concurrency/parallelism-vs-concurrency.md)** — the foundational distinction; clarifies many design decisions.
2. **[Locks, Mutexes & Lock-Free](concurrency/locks-mutexes-and-lock-free.md)** — concurrency primitives and their pathologies.
3. **[CAP, Consistency & Replication](distributed-systems/cap-consistency-and-replication.md)** — the trilemma; consistency models.
4. **[Sharding & Partitioning](scalability/sharding-and-partitioning-strategies.md)** — what scaling actually looks like.
5. **[Cascading Failures & Circuit Breakers](system-failures/cascading-failures-and-circuit-breakers.md)** — production reliability fundamentals.
6. **[Distributed Tracing — A Deep Dive](observability/distributed-tracing-deep-dive.md)** — the only observability primitive that crosses services.
7. **[Sagas & Distributed Transactions](architecture-patterns/saga-pattern-and-distributed-transactions.md)** — modern alternative to 2PC.
8. **[WAL & Crash Recovery](database-internals/wal-and-crash-recovery.md)** — durability foundation.
9. **[Load Balancing Strategies](scalability/load-balancing-strategies.md)** — the visible face of distribution.
10. **[Profiling & Flame Graphs](observability/profiling-and-flame-graphs.md)** — performance debugging discipline.
11. **[Idempotency Receivers & "Exactly-Once" Semantics](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)** — when retries matter.
12. **[SLOs, Error Budgets & Alerting](observability/slos-error-budgets-and-alerting.md)** — operational maturity framework.

After this path: you can reason about systems holistically. You're equipped for senior IC work, design reviews, and production-incident leadership.

---

### Senior / Staff Engineer (5+ years)

The goal: complete coverage of the staff-level mental model. You've seen most of these patterns; this path connects them.

Pre-requisite: you're already comfortable with the mid-level path. This is *complementary*, not replacement.

1. **[Leader Election & Consensus](distributed-systems/leader-election-and-consensus.md)** — the mechanism under every binding distributed decision.
2. **[Clocks, Time & Ordering](distributed-systems/clocks-time-and-ordering.md)** — the hidden coordination primitive.
3. **[Replication Strategies](database-internals/replication-strategies.md)** — sync vs async; the real engineering.
4. **[Microservices vs Monolith](architecture-patterns/microservices-vs-monolith.md)** — the architectural meta-decision.
5. **[Anti-Corruption Layer & DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md)** — language as architecture.
6. **[Strangler Fig & Legacy Migration](architecture-patterns/strangler-fig-and-legacy-migration.md)** — how systems actually evolve.
7. **[Event-Driven Architecture](architecture-patterns/event-driven-architecture.md)** — the substrate of reactive systems.
8. **[Chaos Engineering & Game Days](system-failures/chaos-engineering-and-game-days.md)** — proving resilience.
9. **[Postmortems & Incident Response](system-failures/postmortems-and-incident-response.md)** — turning incidents into learning.
10. **[Auto-Scaling & Capacity Planning](scalability/auto-scaling-and-capacity-planning.md)** — proactive vs reactive.
11. **[Disaster Recovery, RTO & RPO](system-failures/disaster-recovery-and-rto-rpo.md)** — catastrophic-failure planning.
12. **[Cardinality & the Economics of Monitoring](observability/cardinality-and-the-economics-of-monitoring.md)** — observability cost discipline.

After this path: you can lead architecture, drive operational maturity, and mentor effectively. You see the meta-patterns across all of distributed systems.

---

## By Role

### Backend Engineer

Path: build production-grade backend services.

1. [Event Loop](js-runtime/event-loop-and-async-runtime.md) or [Go Runtime](concurrency/go-runtime-and-goroutines.md) or [JVM](concurrency/jvm-internals-and-virtual-threads.md) — pick your runtime.
2. [V8 Internals](js-runtime/v8-internals-and-hidden-classes.md) (or runtime equivalent) — performance fundamentals.
3. [MVCC & Isolation](database-internals/mvcc-and-isolation-levels.md) — your database's concurrency.
4. [Indexing](database-internals/indexing-and-storage-engines.md) — query performance.
5. [Query Optimization](database-internals/query-optimization-and-execution-plans.md) — debug slow queries.
6. [API Design](architecture-patterns/api-design-rest-vs-grpc.md) — your service's contract.
7. [Timeouts, Retries, Idempotency](system-failures/timeouts-retries-and-idempotency.md) — distributed-call basics.
8. [Backpressure & Queues](concurrency/backpressure-and-queues.md) — flow control.
9. [Caching Hierarchy](caching/caching-hierarchy.md) — performance patterns.
10. [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md) — defensive design.

---

### Frontend / Full-Stack Engineer

Path: understand the runtime and the network under your UI.

1. [Event Loop](js-runtime/event-loop-and-async-runtime.md)
2. [V8 Internals](js-runtime/v8-internals-and-hidden-classes.md)
3. [Garbage Collection](js-runtime/garbage-collection-and-memory-management.md)
4. [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md)
5. [TLS & mTLS](networking/tls-and-mtls.md)
6. [Caching Hierarchy](caching/caching-hierarchy.md)
7. [Edge Computing & CDNs](scalability/edge-computing-and-cdns.md)
8. [WebSockets & Real-Time](networking/websockets-and-realtime-protocols.md)
9. [Web Workers & Shared Memory](js-runtime/web-workers-and-shared-memory.md)
10. [Streams & Backpressure in Node](js-runtime/streams-and-backpressure-in-node.md)

---

### SRE / DevOps / Platform Engineer

Path: operate systems at scale.

1. [Metrics, Logs & Traces](observability/metrics-logs-traces.md)
2. [SLOs, Error Budgets & Alerting](observability/slos-error-budgets-and-alerting.md)
3. [Distributed Tracing](observability/distributed-tracing-deep-dive.md)
4. [Cardinality & Monitoring Economics](observability/cardinality-and-the-economics-of-monitoring.md)
5. [Profiling & Flame Graphs](observability/profiling-and-flame-graphs.md)
6. [Cascading Failures & Circuit Breakers](system-failures/cascading-failures-and-circuit-breakers.md)
7. [Postmortems & Incident Response](system-failures/postmortems-and-incident-response.md)
8. [Chaos Engineering & Game Days](system-failures/chaos-engineering-and-game-days.md)
9. [Auto-Scaling & Capacity Planning](scalability/auto-scaling-and-capacity-planning.md)
10. [Disaster Recovery](system-failures/disaster-recovery-and-rto-rpo.md)
11. [Kubernetes Internals](scalability/kubernetes-internals.md)
12. [Load Balancing](scalability/load-balancing-strategies.md)

---

### Database Engineer / DBA

Path: deep storage and replication mastery.

1. [WAL & Crash Recovery](database-internals/wal-and-crash-recovery.md)
2. [MVCC & Isolation Levels](database-internals/mvcc-and-isolation-levels.md)
3. [Indexing & Storage Engines](database-internals/indexing-and-storage-engines.md)
4. [Query Optimization & Plans](database-internals/query-optimization-and-execution-plans.md)
5. [Replication Strategies](database-internals/replication-strategies.md)
6. [OLTP vs OLAP & Columnar](database-internals/oltp-vs-olap-and-columnar-storage.md)
7. [Time-Series Databases](database-internals/time-series-databases.md)
8. [Sharding & Partitioning](scalability/sharding-and-partitioning-strategies.md)
9. [CAP, Consistency & Replication](distributed-systems/cap-consistency-and-replication.md)
10. [Leader Election & Consensus](distributed-systems/leader-election-and-consensus.md)
11. [Distributed Transactions 2PC/3PC](distributed-systems/distributed-transactions-2pc-3pc.md)
12. [Disaster Recovery](system-failures/disaster-recovery-and-rto-rpo.md)

---

### Distributed Systems Engineer

Path: complete distributed-systems vocabulary.

1. [CAP, Consistency & Replication](distributed-systems/cap-consistency-and-replication.md)
2. [Leader Election & Consensus](distributed-systems/leader-election-and-consensus.md)
3. [Clocks, Time & Ordering](distributed-systems/clocks-time-and-ordering.md)
4. [Distributed Transactions 2PC/3PC](distributed-systems/distributed-transactions-2pc-3pc.md)
5. [Gossip Protocols](distributed-systems/gossip-protocols-and-membership.md)
6. [Sagas & Distributed Transactions](architecture-patterns/saga-pattern-and-distributed-transactions.md)
7. [Idempotency & Exactly-Once](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)
8. [Replication Strategies](database-internals/replication-strategies.md)
9. [Sharding & Partitioning](scalability/sharding-and-partitioning-strategies.md)
10. [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md)
11. [Distributed Tracing](observability/distributed-tracing-deep-dive.md)
12. [Kafka Internals](architecture-patterns/kafka-internals-and-stream-processing.md)

---

### Software Architect

Path: architecture-pattern mastery.

1. [Microservices vs Monolith](architecture-patterns/microservices-vs-monolith.md)
2. [Anti-Corruption Layer & DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md)
3. [API Design](architecture-patterns/api-design-rest-vs-grpc.md)
4. [Sagas & Distributed Transactions](architecture-patterns/saga-pattern-and-distributed-transactions.md)
5. [CQRS & Event Sourcing](architecture-patterns/cqrs-and-event-sourcing.md)
6. [Event-Driven Architecture](architecture-patterns/event-driven-architecture.md)
7. [Strangler Fig & Legacy Migration](architecture-patterns/strangler-fig-and-legacy-migration.md)
8. [Idempotency & Exactly-Once](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)
9. [Multi-Tenancy Strategies](scalability/multi-tenancy-strategies.md)
10. [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md)
11. [SLOs, Error Budgets](observability/slos-error-budgets-and-alerting.md)
12. [Kafka Internals](architecture-patterns/kafka-internals-and-stream-processing.md)

---

### Performance Engineer

Path: chase performance everywhere.

1. [V8 Internals](js-runtime/v8-internals-and-hidden-classes.md) (or [JVM](concurrency/jvm-internals-and-virtual-threads.md))
2. [Garbage Collection](js-runtime/garbage-collection-and-memory-management.md)
3. [CPU Caches & False Sharing](concurrency/cpu-caches-and-false-sharing.md)
4. [Locks, Mutexes & Lock-Free](concurrency/locks-mutexes-and-lock-free.md)
5. [Parallelism vs Concurrency](concurrency/parallelism-vs-concurrency.md)
6. [Indexing](database-internals/indexing-and-storage-engines.md)
7. [Query Optimization](database-internals/query-optimization-and-execution-plans.md)
8. [TCP](networking/tcp-and-network-fundamentals.md)
9. [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md)
10. [Profiling & Flame Graphs](observability/profiling-and-flame-graphs.md)
11. [Caching Hierarchy](caching/caching-hierarchy.md)
12. [Auto-Scaling & Capacity Planning](scalability/auto-scaling-and-capacity-planning.md)

---

### Security Engineer

Path: from network up.

1. [TCP](networking/tcp-and-network-fundamentals.md)
2. [TLS & mTLS](networking/tls-and-mtls.md)
3. [DNS](networking/dns-deep-dive.md)
4. [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md)
5. [API Design](architecture-patterns/api-design-rest-vs-grpc.md)
6. [Multi-Tenancy](scalability/multi-tenancy-strategies.md)
7. [Security Incident Response](system-failures/security-incident-response.md)
8. [Postmortems](system-failures/postmortems-and-incident-response.md)
9. [Disaster Recovery](system-failures/disaster-recovery-and-rto-rpo.md)
10. [Kubernetes Internals](scalability/kubernetes-internals.md)
11. [Idempotency & Exactly-Once](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)
12. [Distributed Tracing](observability/distributed-tracing-deep-dive.md)

---

### AI Infrastructure Engineer

Path: AI-native infrastructure.

1. [LLM Serving & Vector Databases](architecture-patterns/llm-serving-and-vector-databases.md)
2. [Caching Hierarchy](caching/caching-hierarchy.md)
3. [Edge Computing & CDNs](scalability/edge-computing-and-cdns.md)
4. [API Design](architecture-patterns/api-design-rest-vs-grpc.md)
5. [Backpressure & Queues](concurrency/backpressure-and-queues.md)
6. [Capacity Planning](scalability/auto-scaling-and-capacity-planning.md)
7. [SLOs](observability/slos-error-budgets-and-alerting.md)
8. [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md)
9. [Distributed Tracing](observability/distributed-tracing-deep-dive.md)
10. [Time-Series Databases](database-internals/time-series-databases.md) (for ML metrics)
11. [WebSockets](networking/websockets-and-realtime-protocols.md) (for streaming responses)
12. [TLS](networking/tls-and-mtls.md)

---

## By Challenge

Sometimes you have a specific problem and need to read for it. These paths target common challenges.

### "Our service is slow under load"

1. [Profiling & Flame Graphs](observability/profiling-and-flame-graphs.md) — measure first.
2. [Backpressure & Queues](concurrency/backpressure-and-queues.md) — find the queue.
3. [Caching Hierarchy](caching/caching-hierarchy.md) — what to cache.
4. [Indexing](database-internals/indexing-and-storage-engines.md) — DB performance.
5. [Query Optimization](database-internals/query-optimization-and-execution-plans.md) — slow queries.
6. [V8 Internals](js-runtime/v8-internals-and-hidden-classes.md) (or runtime equivalent) — runtime perf.
7. [GC](js-runtime/garbage-collection-and-memory-management.md) — pause-driven latency.
8. [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md) — slow ≠ slow.

### "We need to scale beyond one machine"

1. [Sharding & Partitioning](scalability/sharding-and-partitioning-strategies.md)
2. [CAP, Consistency](distributed-systems/cap-consistency-and-replication.md)
3. [Replication Strategies](database-internals/replication-strategies.md)
4. [Load Balancing](scalability/load-balancing-strategies.md)
5. [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md)
6. [Idempotency](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)
7. [Distributed Tracing](observability/distributed-tracing-deep-dive.md)
8. [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md)

### "We had a major outage"

1. [Postmortems & Incident Response](system-failures/postmortems-and-incident-response.md)
2. [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md)
3. [Timeouts, Retries, Idempotency](system-failures/timeouts-retries-and-idempotency.md)
4. [SLOs](observability/slos-error-budgets-and-alerting.md)
5. [Chaos Engineering](system-failures/chaos-engineering-and-game-days.md)
6. [Disaster Recovery](system-failures/disaster-recovery-and-rto-rpo.md)
7. [Distributed Tracing](observability/distributed-tracing-deep-dive.md)
8. [Backpressure](concurrency/backpressure-and-queues.md)

### "We need to migrate from a legacy system"

1. [Strangler Fig & Legacy Migration](architecture-patterns/strangler-fig-and-legacy-migration.md)
2. [Anti-Corruption Layer & DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md)
3. [API Design](architecture-patterns/api-design-rest-vs-grpc.md)
4. [Feature Flags](system-failures/feature-flags-and-progressive-delivery.md)
5. [WAL & Crash Recovery](database-internals/wal-and-crash-recovery.md) (CDC for migration)
6. [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md)
7. [Microservices vs Monolith](architecture-patterns/microservices-vs-monolith.md)
8. [SLOs](observability/slos-error-budgets-and-alerting.md)

### "We're building event-driven"

1. [Event-Driven Architecture](architecture-patterns/event-driven-architecture.md)
2. [Kafka Internals](architecture-patterns/kafka-internals-and-stream-processing.md)
3. [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md)
4. [Idempotency](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)
5. [CQRS & Event Sourcing](architecture-patterns/cqrs-and-event-sourcing.md)
6. [Backpressure & Queues](concurrency/backpressure-and-queues.md)
7. [Distributed Tracing](observability/distributed-tracing-deep-dive.md)
8. [Anti-Corruption Layer & DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md)

### "We're going from monolith to microservices"

1. [Microservices vs Monolith](architecture-patterns/microservices-vs-monolith.md) — read this first; sometimes the answer is "don't."
2. [Anti-Corruption Layer & DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md) — bounded contexts as service boundaries.
3. [Strangler Fig](architecture-patterns/strangler-fig-and-legacy-migration.md) — how to actually migrate.
4. [API Design](architecture-patterns/api-design-rest-vs-grpc.md) — service contracts.
5. [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md) — cross-service workflows.
6. [Distributed Tracing](observability/distributed-tracing-deep-dive.md) — debugging the new architecture.
7. [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md) — new failure modes.
8. [Kubernetes Internals](scalability/kubernetes-internals.md) — typical hosting.

### "Interview prep for senior systems-design"

1. [CAP, Consistency](distributed-systems/cap-consistency-and-replication.md)
2. [Sharding & Partitioning](scalability/sharding-and-partitioning-strategies.md)
3. [Caching Hierarchy](caching/caching-hierarchy.md)
4. [Load Balancing](scalability/load-balancing-strategies.md)
5. [API Design](architecture-patterns/api-design-rest-vs-grpc.md)
6. [Idempotency](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)
7. [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md)
8. [Microservices vs Monolith](architecture-patterns/microservices-vs-monolith.md)
9. [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md)
10. [SLOs, Error Budgets](observability/slos-error-budgets-and-alerting.md)
11. [Indexing](database-internals/indexing-and-storage-engines.md)
12. [MVCC](database-internals/mvcc-and-isolation-levels.md)

---

## How to Read These Artifacts Effectively

Each artifact is a complete mentor-style essay. Reading techniques:

**First read (~25 min)**: read the Intuition, Core Mental Models, and Final Mental Model sections fully. Skim the Deep Technical Explanation. You'll have the gestalt.

**Second read (~30 min)**: read the Deep Technical Explanation carefully. Read the Failure Scenarios and Production Engineering Perspective. Now you have technical depth.

**On reference**: Use the 20% / 80% section as the cheat sheet. Use the Glossary to look up specific terms.

**For interviews**: Read the Interview Perspective section. Practice articulating the Mental Models out loud.

---

## After You Finish a Path

Cross-reference. Each artifact has a Cross-Domain Connections section. Follow links to related artifacts; the corpus is a graph, not a list. Understanding deepens with revisits across different angles.

The corpus rewards re-reading. The same artifact reads differently after you've absorbed five related ones — concepts you previously absorbed at surface level click into place.

Pick a single section of the corpus per quarter. Live in it. Move on. Over a year you'll have internalized the staff-engineer mental model.
