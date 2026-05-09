# Engineering Knowledge Base — Index

> A unified curriculum for senior/staff-level engineering intuition, spanning database internals, distributed systems, runtime engineering, scalability, observability, system reliability, and modern architecture. Each artifact is a mentor-style deep dive (~3000+ words) with intuition, history, deep technical detail, real production scenarios, failure modes, cross-domain connections, and interview perspective.

---

## Navigation Aids

- **[GLOSSARY.md](GLOSSARY.md)** — alphabetical reference of every term used across the corpus, with links to source artifacts.
- **[ACRONYMS-BY-DOMAIN.md](ACRONYMS-BY-DOMAIN.md)** — acronyms grouped by where they show up; quick context disambiguation.
- **[STARTER-CARDS.md](STARTER-CARDS.md)** — one-screen TL;DR for every artifact: 5 mental models, the final mental model, and why it matters.
- **[LEARNING-PATHS.md](LEARNING-PATHS.md)** — curated reading orders by experience level, role, and challenge.
- **[DEPENDENCY-GRAPH.md](DEPENDENCY-GRAPH.md)** — what to read before what; which artifacts compose which others.
- **[FAQ.md](FAQ.md)** — recurring questions with short answers and pointers to deeper coverage.
- **[COMMON-MISTAKES.md](COMMON-MISTAKES.md)** — production-engineer's checklist of mistakes that recur across teams and decades.
- **[WORKED-EXAMPLES.md](WORKED-EXAMPLES.md)** — concrete end-to-end scenarios that walk through patterns with code.

---

## How to Use This Index

The corpus is structured as 10 domains. Each artifact stands alone but cross-references others heavily. Reading a single piece will pull you across the corpus through the *Cross-Domain Connections* section.

Three reading paths:

**Foundations path** — for engineers building intuition from the bottom up:
1. [TCP & Network Fundamentals](networking/tcp-and-network-fundamentals.md)
2. [The Event Loop & Async Runtime](js-runtime/event-loop-and-async-runtime.md)
3. [V8 Internals & Hidden Classes](js-runtime/v8-internals-and-hidden-classes.md)
4. [WAL & Crash Recovery](database-internals/wal-and-crash-recovery.md)
5. [MVCC & Isolation Levels](database-internals/mvcc-and-isolation-levels.md)

**Scaling path** — for engineers operating at growing scale:
1. [Indexing & Storage Engines](database-internals/indexing-and-storage-engines.md)
2. [Sharding & Partitioning Strategies](scalability/sharding-and-partitioning-strategies.md)
3. [CAP, Consistency & Replication](distributed-systems/cap-consistency-and-replication.md)
4. [Backpressure & Queues](concurrency/backpressure-and-queues.md)
5. [Cascading Failures & Circuit Breakers](system-failures/cascading-failures-and-circuit-breakers.md)

**Distributed-systems path** — for engineers building service architectures:
1. [Microservices vs Monolith](architecture-patterns/microservices-vs-monolith.md)
2. [Sagas & Distributed Transactions](architecture-patterns/saga-pattern-and-distributed-transactions.md)
3. [Leader Election & Consensus](distributed-systems/leader-election-and-consensus.md)
4. [Timeouts, Retries & Idempotency](system-failures/timeouts-retries-and-idempotency.md)
5. [Distributed Tracing — A Deep Dive](observability/distributed-tracing-deep-dive.md)

---

## Domains

### Database Internals (8)
The storage and query layers under every transactional and analytical system.

- [MVCC & Isolation Levels](database-internals/mvcc-and-isolation-levels.md) — versions instead of locks; the foundation of modern concurrency control.
- [Indexing & Storage Engines](database-internals/indexing-and-storage-engines.md) — B-trees, LSM trees, the disk patterns that shape databases.
- [WAL & Crash Recovery](database-internals/wal-and-crash-recovery.md) — write-ahead logging and the durability stack.
- [Query Optimization & Execution Plans](database-internals/query-optimization-and-execution-plans.md) — the small compiler inside every database.
- [Replication Strategies](database-internals/replication-strategies.md) — sync, async, multi-leader, leaderless.
- [OLTP vs OLAP & Columnar Storage](database-internals/oltp-vs-olap-and-columnar-storage.md) — workload shape drives database design.
- [Time-Series Databases](database-internals/time-series-databases.md) — the storage shape under modern monitoring.
- [Postgres Internals — A Deep Dive](database-internals/postgres-internals-deep-dive.md) — the workhorse open-source RDBMS.

### Distributed Systems (5)
The theory and machinery of multiple machines coordinating.

- [CAP, Consistency Models & Replication](distributed-systems/cap-consistency-and-replication.md) — the trilemma and the consistency spectrum.
- [Leader Election & Consensus](distributed-systems/leader-election-and-consensus.md) — Raft, Paxos, the foundation of binding decisions.
- [Clocks, Time & Ordering](distributed-systems/clocks-time-and-ordering.md) — Lamport clocks, vector clocks, HLCs, TrueTime.
- [Gossip Protocols & Cluster Membership](distributed-systems/gossip-protocols-and-membership.md) — decentralized state propagation at scale.
- [Distributed Transactions — 2PC, 3PC](distributed-systems/distributed-transactions-2pc-3pc.md) — what's broken about classical distributed atomicity.

### Concurrency (10)
The patterns and primitives of doing multiple things at once.

- [Locks, Mutexes & Lock-Free](concurrency/locks-mutexes-and-lock-free.md) — synchronization fundamentals.
- [Backpressure & Queues](concurrency/backpressure-and-queues.md) — the discipline of saying no in time.
- [The Actor Model & Message Passing](concurrency/actor-model-and-message-passing.md) — share nothing, communicate explicitly.
- [Parallelism vs Concurrency](concurrency/parallelism-vs-concurrency.md) — the foundational distinction.
- [Coroutines, Green Threads & Async Runtimes](concurrency/coroutines-and-green-threads.md) — the modern lightweight-concurrency stack.
- [Async Rust & the Borrow Checker](concurrency/async-rust-and-the-borrow-checker.md) — concurrency with safety guarantees.
- [Go Runtime & Goroutines](concurrency/go-runtime-and-goroutines.md) — the most-deployed work-stealing scheduler.
- [JVM Internals & Virtual Threads](concurrency/jvm-internals-and-virtual-threads.md) — the JVM under thirty years of enterprise software.
- [Python Runtime & the GIL](concurrency/python-runtime-and-the-gil.md) — Python's defining concurrency constraint.
- [CPU Caches & False Sharing](concurrency/cpu-caches-and-false-sharing.md) — the silicon-level reality under multi-threaded code.

### JavaScript Runtime (5)
The internals of V8, Node.js, and the JavaScript execution model.

- [The Event Loop & Async Runtime](js-runtime/event-loop-and-async-runtime.md) — single-threaded async fundamentals.
- [V8 Internals & Hidden Classes](js-runtime/v8-internals-and-hidden-classes.md) — the JIT under every browser tab and every Node service.
- [Node.js Architecture & libuv](js-runtime/nodejs-architecture-and-libuv.md) — the V8 + libuv glue that makes Node work.
- [Streams & Backpressure in Node](js-runtime/streams-and-backpressure-in-node.md) — the standard library's most powerful primitive.
- [Web Workers, Worker Threads & Shared Memory](js-runtime/web-workers-and-shared-memory.md) — JavaScript's controlled retreat from single-threaded.
- [Garbage Collection & Memory Management](js-runtime/garbage-collection-and-memory-management.md) — the runtime contract under every managed language.

### Networking (5)
The protocols that carry every distributed system.

- [TCP & Network Fundamentals](networking/tcp-and-network-fundamentals.md) — reliable streams over unreliable packets.
- [HTTP/2, HTTP/3 & QUIC](networking/http-2-and-http-3.md) — the web protocol's evolution.
- [DNS Deep Dive](networking/dns-deep-dive.md) — the layer everything depends on.
- [WebSockets & Real-Time Protocols](networking/websockets-and-realtime-protocols.md) — bidirectional persistent channels.
- [TLS & Mutual TLS](networking/tls-and-mtls.md) — the cryptographic foundation.

### Observability (5)
The discipline of making systems explain themselves.

- [Metrics, Logs & Traces](observability/metrics-logs-traces.md) — the three pillars of observability.
- [Distributed Tracing — A Deep Dive](observability/distributed-tracing-deep-dive.md) — the only signal that respects causality.
- [SLOs, Error Budgets & Alerting](observability/slos-error-budgets-and-alerting.md) — reliability as a budgeted resource.
- [Cardinality & the Economics of Monitoring](observability/cardinality-and-the-economics-of-monitoring.md) — observability's cost model.
- [Profiling & Flame Graphs](observability/profiling-and-flame-graphs.md) — finding bottlenecks with data, not intuition.

### Scalability (7)
The patterns of running at increasing scale.

- [Sharding & Partitioning Strategies](scalability/sharding-and-partitioning-strategies.md) — the most consequential schema decision.
- [Load Balancing Strategies](scalability/load-balancing-strategies.md) — the visible face of distribution.
- [Auto-Scaling & Capacity Planning](scalability/auto-scaling-and-capacity-planning.md) — proactive planning vs reactive scaling.
- [Edge Computing & CDNs](scalability/edge-computing-and-cdns.md) — geography weaponized for latency.
- [Multi-Tenancy Strategies](scalability/multi-tenancy-strategies.md) — the SaaS architectural foundation.
- [Kubernetes Internals](scalability/kubernetes-internals.md) — the OS of cloud-native infrastructure.
- [GPU & Accelerator Computing](scalability/gpu-and-accelerator-computing.md) — the substrate of modern AI.

### System Failures (7)
The disciplines of building systems that survive their own failures.

- [Cascading Failures & Circuit Breakers](system-failures/cascading-failures-and-circuit-breakers.md) — coupling is the fault line.
- [Timeouts, Retries & Idempotency](system-failures/timeouts-retries-and-idempotency.md) — the foundation contract for distributed calls.
- [Chaos Engineering & Game Days](system-failures/chaos-engineering-and-game-days.md) — proving resilience by breaking it.
- [Postmortems & Incident Response](system-failures/postmortems-and-incident-response.md) — turning outages into education.
- [Disaster Recovery, RTO & RPO](system-failures/disaster-recovery-and-rto-rpo.md) — preparing for catastrophic events.
- [Feature Flags & Progressive Delivery](system-failures/feature-flags-and-progressive-delivery.md) — decoupling deploy from release.
- [Security Incident Response](system-failures/security-incident-response.md) — incidents in a hostile environment.

### Architecture Patterns (12)
The building blocks of mature system designs.

- [Microservices vs Monolith](architecture-patterns/microservices-vs-monolith.md) — the most exhausting argument in software architecture.
- [Sagas & Distributed Transactions](architecture-patterns/saga-pattern-and-distributed-transactions.md) — the modern alternative to 2PC across services.
- [CQRS & Event Sourcing](architecture-patterns/cqrs-and-event-sourcing.md) — state as a story, not a snapshot.
- [API Design — REST vs gRPC vs GraphQL](architecture-patterns/api-design-rest-vs-grpc.md) — protocol choice as architecture.
- [Strangler Fig & Legacy Migration](architecture-patterns/strangler-fig-and-legacy-migration.md) — the only migration pattern that consistently works.
- [Event-Driven Architecture](architecture-patterns/event-driven-architecture.md) — loose coupling via durable facts.
- [Idempotency Receivers & "Exactly-Once" Semantics](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md) — turning at-least-once into effectively-once.
- [Anti-Corruption Layer & Domain-Driven Design](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md) — language as architecture.
- [LLM Serving & Vector Databases](architecture-patterns/llm-serving-and-vector-databases.md) — the AI era's new infrastructure layer.
- [Kafka Internals & Stream Processing](architecture-patterns/kafka-internals-and-stream-processing.md) — the distributed log as architectural primitive.
- [gRPC Internals & Streaming](architecture-patterns/grpc-internals-and-streaming.md) — opinionated infrastructure for service-to-service RPC.
- [GraphQL Deep Dive](architecture-patterns/graphql-deep-dive.md) — client-driven queries; server complexity.

### Caching (1)
- [The Caching Hierarchy](caching/caching-hierarchy.md) — from CPU registers to global CDN.

---

## Cross-Cutting Themes

Several threads run through the corpus. Following them across artifacts yields connected understanding:

**The "history is data" thread.** WAL → MVCC → CQRS/Event Sourcing → Time-Series DBs. The recurring insight: append-only is faster, more reliable, and more expressive than mutate-in-place.

**The "consistency vs availability" thread.** CAP → Consensus → Sagas → Replication → Distributed Transactions → Multi-Tenancy. Every distributed-systems decision touches this trade-off.

**The "queues are everywhere" thread.** Backpressure → Streams in Node → Event Loop → Event-Driven Architecture → TCP. Once you see queues, you see them at every layer.

**The "observability is a property" thread.** Metrics/Logs/Traces → SLOs → Distributed Tracing → Profiling → Cardinality. Observability is built into systems, not bought.

**The "failure is normal" thread.** Cascading Failures → Chaos Engineering → Postmortems → DR → Security IR → Timeouts/Retries. Every reliable system encodes its failure response.

**The "language as architecture" thread.** DDD/ACL → API Design → Microservices → Bounded Contexts. Concepts and vocabulary shape the system more than tools do.

---

## Reading Order Recommendations

Different roles benefit from different starting points:

**Backend engineer (early career):**
- Event Loop → V8 Internals → MVCC → Indexing → API Design → Caching → Backpressure

**Backend engineer (senior):**
- Sagas → CQRS → Event-Driven → Microservices vs Monolith → Cascading Failures → SLOs → Distributed Tracing

**SRE / Operations:**
- Observability stack (Metrics/Logs/Traces, SLOs, Profiling, Cardinality) → System Failures (all) → Capacity Planning → Replication → Disaster Recovery

**Database engineer:**
- All of database-internals → Replication → Sharding → CAP → Consensus → Time-Series

**Distributed-systems engineer:**
- CAP → Consensus → Clocks → Gossip → Sagas → Distributed Transactions → Replication → Sharding

**Frontend / UI engineer learning systems:**
- Event Loop → V8 → Node.js Architecture → Streams → Web Workers → HTTP/2-3 → Caching

**AI infrastructure engineer:**
- LLM Serving → Caching → Edge Computing → API Design → Capacity Planning → Backpressure

---

## How These Were Written

Each artifact follows a consistent structure:

1. **Opening epigraph** — the topic in one sentence.
2. **Topic Overview** — what and why.
3. **Intuition Before Definitions** — the analogy.
4. **Historical Evolution** — how the field arrived here.
5. **Core Mental Models** — the 5 things that matter most.
6. **Deep Technical Explanation** — the substance.
7. **Real Engineering Analogies** — physical-world parallels.
8. **Production Engineering Perspective** — what 3am looks like.
9. **Failure Scenarios** — concrete bad days.
10. **Performance / Scaling Perspectives** — quantitative reality.
11. **Cross-Domain Connections** — links to related artifacts.
12. **Real Production Scenarios** — case studies and references.
13. **What Junior / Senior Engineers Notice** — the maturity gap.
14. **Interview Perspective** — what gets tested.
15. **20% / 80%** — the foundational takeaways.
16. **Final Mental Model** — the single transferable insight.

The format is consistent so that artifacts can be read individually or as a corpus, and so that the same kind of question always finds the same kind of answer.

---

## Stats

- **60 artifacts** spanning 10 domains, plus **8 navigation aids**.
- **~210,000 words** of curriculum + reference content.
- **~10 cross-references** per artifact, forming a dense web.
- **Mentor-style prose**, not textbook summary.
- **Production-oriented**, not academic.
- **No copyrighted reproductions**; original synthesis.

---

The corpus is meant to be lived in, not finished. Pick a topic; read the artifact; follow the cross-references when something connects. Over time, the whole graph becomes one mental model — and individual debugging sessions, design discussions, and architecture decisions become traversals through familiar territory.
