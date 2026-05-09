# Glossary

> Alphabetical reference of vocabulary used across the knowledge base. Each entry has a brief definition and a link to the most relevant artifact for deeper coverage. Terms that recur across many artifacts have multiple links.

---

## A

**ACID** — Atomicity, Consistency, Isolation, Durability. Properties of database transactions. → [MVCC](database-internals/mvcc-and-isolation-levels.md), [WAL](database-internals/wal-and-crash-recovery.md)

**ACL (Anti-Corruption Layer)** — Translation layer between bounded contexts; prevents one model from polluting another. → [DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md)

**Aggregate (DDD)** — A cluster of related domain objects treated as a unit for data changes. → [DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md)

**AIMD** — Additive Increase Multiplicative Decrease. TCP's congestion control pattern. → [TCP](networking/tcp-and-network-fundamentals.md)

**ALPN** — Application-Layer Protocol Negotiation. TLS extension used to negotiate HTTP/2 vs HTTP/1.1. → [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md)

**Anycast** — Network routing where the same IP is advertised from many locations; routers send packets to the nearest. → [DNS](networking/dns-deep-dive.md), [Edge](scalability/edge-computing-and-cdns.md)

**API Gateway** — Edge HTTP service that routes, authenticates, rate-limits requests to backends. → [API Design](architecture-patterns/api-design-rest-vs-grpc.md)

**Append-only log** — Storage where data is only added, never modified. Foundation of WAL, Kafka, event sourcing. → [WAL](database-internals/wal-and-crash-recovery.md), [Kafka](architecture-patterns/kafka-internals-and-stream-processing.md)

**Async/await** — Language syntax for cooperative concurrency; compiles to state machines. → [Coroutines](concurrency/coroutines-and-green-threads.md), [Async Rust](concurrency/async-rust-and-the-borrow-checker.md)

**At-least-once delivery** — Message-delivery guarantee allowing duplicates but not loss. Combined with idempotent receivers = effectively-once. → [Idempotency](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)

**Atomics** — CPU instructions or language primitives providing race-free read/modify/write. → [Locks](concurrency/locks-mutexes-and-lock-free.md), [Web Workers](js-runtime/web-workers-and-shared-memory.md)

## B

**Backpressure** — Mechanism by which a slow consumer signals an upstream producer to slow down. → [Backpressure & Queues](concurrency/backpressure-and-queues.md), [Streams in Node](js-runtime/streams-and-backpressure-in-node.md)

**BBR** — Bottleneck Bandwidth and RTT. Modern TCP congestion-control algorithm; better on lossy links. → [TCP](networking/tcp-and-network-fundamentals.md)

**B+ tree** — Balanced search tree used as the default database index structure. → [Indexing](database-internals/indexing-and-storage-engines.md)

**Blast radius** — The set of users/services affected when something fails. Bounding it is core resilience work. → [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md), [Multi-tenancy](scalability/multi-tenancy-strategies.md)

**Bloom filter** — Probabilistic set-membership data structure; "definitely not" or "maybe yes." → [Indexing](database-internals/indexing-and-storage-engines.md)

**Blue-green deployment** — Two identical production environments; switch traffic between them. → [Feature Flags](system-failures/feature-flags-and-progressive-delivery.md)

**Bounded context (DDD)** — A part of the system with its own model and vocabulary. → [DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md)

**Burn rate** — How fast you're consuming an SLO error budget. → [SLOs](observability/slos-error-budgets-and-alerting.md)

## C

**Cache coherence** — Hardware protocol ensuring CPU caches don't disagree when one core writes shared memory. → [CPU Caches](concurrency/cpu-caches-and-false-sharing.md)

**Cache line** — Unit of CPU cache transfer; typically 64 bytes. → [CPU Caches](concurrency/cpu-caches-and-false-sharing.md)

**Canary release** — Deploy new version to a small subset; observe; expand if healthy. → [Feature Flags](system-failures/feature-flags-and-progressive-delivery.md)

**CAP theorem** — During network partitions, you must choose between Consistency and Availability. → [CAP](distributed-systems/cap-consistency-and-replication.md)

**Cardinality** — Number of unique combinations of dimensions in a metric or label set. Drives observability cost. → [Cardinality](observability/cardinality-and-the-economics-of-monitoring.md)

**CAS (Compare-and-Swap)** — Atomic instruction; foundation of lock-free programming. → [Locks](concurrency/locks-mutexes-and-lock-free.md)

**CDC (Change Data Capture)** — Stream of changes from a database to downstream consumers. → [WAL](database-internals/wal-and-crash-recovery.md), [Replication](database-internals/replication-strategies.md)

**CDN (Content Delivery Network)** — Distributed network of caching servers near users. → [Edge & CDNs](scalability/edge-computing-and-cdns.md)

**Cell-based architecture** — Independent service cells; each cell holds a subset of customers. → [Multi-tenancy](scalability/multi-tenancy-strategies.md), [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md)

**Choreography** — Event-driven flow without a central coordinator; each service reacts independently. → [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md)

**Circuit breaker** — Pattern that fails fast on a known-broken dependency to prevent cascades. → [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md)

**CNAME** — DNS record; aliases a name to another name. → [DNS](networking/dns-deep-dive.md)

**Cold start** — Latency added when starting a fresh runtime instance. → [Capacity Planning](scalability/auto-scaling-and-capacity-planning.md), [Edge](scalability/edge-computing-and-cdns.md)

**Compensation (sagas)** — Forward operation that semantically undoes a previous step. Not the same as rollback. → [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md)

**Conformist** — DDD context-mapping pattern; one context simply uses another's model. → [DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md)

**Consensus** — Distributed protocol for agreeing on a single value. Raft, Paxos. → [Consensus](distributed-systems/leader-election-and-consensus.md)

**Consistent hashing** — Distribution scheme where adding a node moves only ~1/N of keys. → [Sharding](scalability/sharding-and-partitioning-strategies.md), [Load Balancing](scalability/load-balancing-strategies.md)

**Continuous batching** — LLM-serving technique; new requests join the running batch each generation step. → [LLM Serving](architecture-patterns/llm-serving-and-vector-databases.md)

**Continuous query** — Pre-computed aggregation that updates as new data arrives. → [Time-series DBs](database-internals/time-series-databases.md)

**Coordinator (2PC)** — Single point that decides commit/abort across participants. Single point of failure. → [2PC/3PC](distributed-systems/distributed-transactions-2pc-3pc.md)

**Coroutine** — Function that can pause and resume. Foundation of async/await. → [Coroutines](concurrency/coroutines-and-green-threads.md)

**CQRS** — Command Query Responsibility Segregation. Separate read/write models. → [CQRS](architecture-patterns/cqrs-and-event-sourcing.md)

**CRDT** — Conflict-free Replicated Data Type. Inherently mergeable, idempotent. → [CAP](distributed-systems/cap-consistency-and-replication.md)

**CRD (Kubernetes)** — Custom Resource Definition. Extends Kubernetes with new resource types. → [Kubernetes](scalability/kubernetes-internals.md)

**CUBIC** — Default TCP congestion-control algorithm on Linux. → [TCP](networking/tcp-and-network-fundamentals.md)

## D

**Dark launch** — Deploy code but don't expose it to users; run in shadow mode for validation. → [Feature Flags](system-failures/feature-flags-and-progressive-delivery.md)

**Dead-letter queue (DLQ)** — Queue for messages that consistently fail processing. → [Event-driven](architecture-patterns/event-driven-architecture.md)

**Deadlock** — Two or more threads waiting on each other's locks; nobody progresses. → [Locks](concurrency/locks-mutexes-and-lock-free.md)

**Debezium** — Open-source CDC tool for streaming database changes. → [Replication](database-internals/replication-strategies.md)

**Declarative config (Kubernetes)** — Specify desired state; system converges. → [Kubernetes](scalability/kubernetes-internals.md)

**Deoptimization** — JIT compiler reverts to lower tier when assumptions break. → [V8](js-runtime/v8-internals-and-hidden-classes.md), [JVM](concurrency/jvm-internals-and-virtual-threads.md)

**DNSSEC** — DNS Security Extensions; cryptographic signing of DNS records. → [DNS](networking/dns-deep-dive.md)

**Domain event** — A significant business happening, expressed as an event. → [DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md), [Event-driven](architecture-patterns/event-driven-architecture.md)

**Dynamic batching** — Group concurrent requests into a single GPU pass. → [LLM Serving](architecture-patterns/llm-serving-and-vector-databases.md)

## E

**ECN** — Explicit Congestion Notification. TCP signal for congestion without packet loss. → [TCP](networking/tcp-and-network-fundamentals.md)

**Edge computing** — Running application logic close to users at PoPs. → [Edge & CDNs](scalability/edge-computing-and-cdns.md)

**Effectively-once** — At-least-once delivery + idempotent processing. The achievable target. → [Idempotency](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)

**Embedding** — Vector representation of meaning, used for semantic similarity. → [LLM Serving](architecture-patterns/llm-serving-and-vector-databases.md)

**EMA / EWMA** — (Exponentially-)Weighted Moving Average. Used in adaptive load balancing. → [Load Balancing](scalability/load-balancing-strategies.md)

**Epoch** — Bookkeeping for memory reclamation in lock-free programming. → [Locks](concurrency/locks-mutexes-and-lock-free.md)

**epoll** — Linux mechanism for scalable async I/O notification. → [TCP](networking/tcp-and-network-fundamentals.md), [Event Loop](js-runtime/event-loop-and-async-runtime.md)

**Error budget** — `1 - SLO`; the failure rate you can afford. → [SLOs](observability/slos-error-budgets-and-alerting.md)

**etcd** — Consensus-backed key-value store; Kubernetes's source of truth. → [Kubernetes](scalability/kubernetes-internals.md), [Consensus](distributed-systems/leader-election-and-consensus.md)

**Eventual consistency** — Replicas converge eventually if writes stop. → [CAP](distributed-systems/cap-consistency-and-replication.md)

**Event sourcing** — State derived by folding over an immutable log of events. → [CQRS / Event Sourcing](architecture-patterns/cqrs-and-event-sourcing.md)

## F

**Fail-fast** — Reject quickly when overloaded rather than queuing. → [Backpressure](concurrency/backpressure-and-queues.md)

**False sharing** — Two threads modify different vars in the same cache line, causing coherence traffic. → [CPU Caches](concurrency/cpu-caches-and-false-sharing.md)

**Feature flag** — Runtime switch controlling whether a piece of functionality is active. → [Feature Flags](system-failures/feature-flags-and-progressive-delivery.md)

**FLP impossibility** — Fischer-Lynch-Paterson result: no deterministic consensus protocol guarantees both safety and liveness in fully asynchronous systems with one faulty process. → [Consensus](distributed-systems/leader-election-and-consensus.md)

**Flow control** — Mechanism preventing a fast sender from overwhelming a slow receiver. TCP's window. → [TCP](networking/tcp-and-network-fundamentals.md)

**Forward secrecy** — Past sessions remain secure even if long-term key is later compromised. → [TLS](networking/tls-and-mtls.md)

**fsync** — Syscall forcing data from buffers to stable storage. The durability boundary. → [WAL](database-internals/wal-and-crash-recovery.md)

**Future** — Object representing an asynchronous result. → [Async Rust](concurrency/async-rust-and-the-borrow-checker.md)

## G

**Garbage collection (GC)** — Automatic memory reclamation. → [GC](js-runtime/garbage-collection-and-memory-management.md)

**Generational GC** — Separate young/old heaps; collects young frequently. → [GC](js-runtime/garbage-collection-and-memory-management.md)

**GIL** — Global Interpreter Lock. Python's serialization of bytecode execution. → [Python GIL](concurrency/python-runtime-and-the-gil.md)

**Goroutine** — Go's lightweight thread; multiplexed onto OS threads. → [Go Runtime](concurrency/go-runtime-and-goroutines.md)

**Gossip protocol** — Decentralized state propagation by random peer exchange. → [Gossip](distributed-systems/gossip-protocols-and-membership.md)

**GraalVM** — JVM with AOT compilation and polyglot support. → [JVM](concurrency/jvm-internals-and-virtual-threads.md)

**GraphQL** — Query language; clients specify exactly the data shape they need. → [API Design](architecture-patterns/api-design-rest-vs-grpc.md)

**G1** — Garbage-First. Default JVM GC since Java 9. → [JVM](concurrency/jvm-internals-and-virtual-threads.md)

**gRPC** — RPC framework over HTTP/2 with protobuf serialization. → [API Design](architecture-patterns/api-design-rest-vs-grpc.md)

## H

**Happens-before** — Lamport's causal-ordering relation. → [Clocks](distributed-systems/clocks-time-and-ordering.md)

**Hash partitioning** — Sharding by hash of key. → [Sharding](scalability/sharding-and-partitioning-strategies.md)

**Hidden class (V8)** — Object shape used by V8 for fast property access. → [V8](js-runtime/v8-internals-and-hidden-classes.md)

**HLC** — Hybrid Logical Clock; physical time + logical counter. → [Clocks](distributed-systems/clocks-time-and-ordering.md)

**HNSW** — Hierarchical Navigable Small World. ANN graph algorithm. → [LLM Serving](architecture-patterns/llm-serving-and-vector-databases.md)

**Hotspot (JVM)** — Standard JVM with adaptive JIT compilation. → [JVM](concurrency/jvm-internals-and-virtual-threads.md)

**HPACK** — HTTP/2's header compression. → [HTTP/2](networking/http-2-and-http-3.md)

**HTTP/3** — HTTP over QUIC; eliminates TCP head-of-line blocking. → [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md)

## I

**Idempotency key** — Unique identifier per logical operation; lets receivers dedupe retries. → [Idempotency](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)

**IC (Inline Cache)** — V8's per-call-site type cache; mono/poly/megamorphic states. → [V8](js-runtime/v8-internals-and-hidden-classes.md)

**Index-only scan** — Query satisfied entirely from the index without touching the heap. → [Indexing](database-internals/indexing-and-storage-engines.md)

**Ingress (Kubernetes)** — L7 routing into the cluster. → [Kubernetes](scalability/kubernetes-internals.md)

**Inverted index** — Index mapping terms to documents containing them. → [Time-series DBs](database-internals/time-series-databases.md)

**ISR** — In-Sync Replica. Followers caught up to leader in Kafka. → [Kafka](architecture-patterns/kafka-internals-and-stream-processing.md)

## J

**JIT (Just-In-Time)** — Compile bytecode to native code at runtime. → [V8](js-runtime/v8-internals-and-hidden-classes.md), [JVM](concurrency/jvm-internals-and-virtual-threads.md)

**Joint consensus** — Raft mechanism for safe membership changes. → [Consensus](distributed-systems/leader-election-and-consensus.md)

## K

**KRaft** — Kafka's internal Raft replacing ZooKeeper. → [Kafka](architecture-patterns/kafka-internals-and-stream-processing.md)

**Kubelet** — Kubernetes node agent that runs pods. → [Kubernetes](scalability/kubernetes-internals.md)

**KV cache (LLM)** — Cached key/value tensors from previous tokens; avoids recomputation. → [LLM Serving](architecture-patterns/llm-serving-and-vector-databases.md)

## L

**Lamport clock** — Logical clock providing total order consistent with causality. → [Clocks](distributed-systems/clocks-time-and-ordering.md)

**Linearizability** — Strongest consistency: operations appear instantaneous in some global order respecting real time. → [CAP](distributed-systems/cap-consistency-and-replication.md)

**Liveness probe (Kubernetes)** — Health check; restart container if it fails. → [Kubernetes](scalability/kubernetes-internals.md)

**Load shedding** — Drop low-priority traffic to protect a saturated system. → [Backpressure](concurrency/backpressure-and-queues.md)

**Lock convoy** — Pathological serialization through a single hot mutex. → [Locks](concurrency/locks-mutexes-and-lock-free.md)

**Loom (Project)** — Java's virtual threads. → [JVM](concurrency/jvm-internals-and-virtual-threads.md)

**LSM tree** — Log-Structured Merge tree. Storage engine optimized for writes. → [Indexing](database-internals/indexing-and-storage-engines.md)

## M

**Major GC** — Collects old generation; longer pauses. → [GC](js-runtime/garbage-collection-and-memory-management.md)

**Mark-and-sweep** — Classic GC: mark reachable objects, sweep unreachable. → [GC](js-runtime/garbage-collection-and-memory-management.md)

**Megamorphic IC** — V8's slowest call-site state; too many shapes seen. → [V8](js-runtime/v8-internals-and-hidden-classes.md)

**Memtable** — In-memory write buffer in LSM trees. → [Indexing](database-internals/indexing-and-storage-engines.md)

**MESI** — Cache coherence protocol states (Modified/Exclusive/Shared/Invalid). → [CPU Caches](concurrency/cpu-caches-and-false-sharing.md)

**Merge join** — Join algorithm over sorted inputs. → [Query Optimization](database-internals/query-optimization-and-execution-plans.md)

**Microservice** — Independently-deployable service owning a bounded context. → [Microservices](architecture-patterns/microservices-vs-monolith.md)

**Microtask** — Callback queued via Promise/queueMicrotask; drains before next macrotask. → [Event Loop](js-runtime/event-loop-and-async-runtime.md)

**Minor GC** — Collects young generation; quick. → [GC](js-runtime/garbage-collection-and-memory-management.md)

**Monomorphic IC** — V8's fastest call-site state; one shape seen. → [V8](js-runtime/v8-internals-and-hidden-classes.md)

**MPP** — Massively Parallel Processing. Distributed analytics architecture. → [OLTP vs OLAP](database-internals/oltp-vs-olap-and-columnar-storage.md)

**MTU** — Maximum Transmission Unit; largest packet a network can carry. → [TCP](networking/tcp-and-network-fundamentals.md)

**MTBF / MTTR / MTTD** — Mean Time Between Failures / To Recovery / To Detection. → [Postmortems](system-failures/postmortems-and-incident-response.md)

**MVCC** — Multi-Version Concurrency Control. Versions instead of read locks. → [MVCC](database-internals/mvcc-and-isolation-levels.md)

**mTLS** — Mutual TLS; both client and server present certificates. → [TLS](networking/tls-and-mtls.md)

## N

**Nagle's algorithm** — TCP buffering of small writes; can cause latency with delayed ACKs. → [TCP](networking/tcp-and-network-fundamentals.md)

**NUMA** — Non-Uniform Memory Access; multi-socket memory architecture. → [CPU Caches](concurrency/cpu-caches-and-false-sharing.md)

## O

**OLAP** — Online Analytical Processing. Aggregation-heavy workloads. → [OLTP vs OLAP](database-internals/oltp-vs-olap-and-columnar-storage.md)

**OLTP** — Online Transactional Processing. Many small transactions. → [OLTP vs OLAP](database-internals/oltp-vs-olap-and-columnar-storage.md)

**OpenTelemetry (OTel)** — Vendor-neutral instrumentation standard. → [Observability](observability/metrics-logs-traces.md), [Tracing](observability/distributed-tracing-deep-dive.md)

**Operator (Kubernetes)** — CRD + custom controller; encodes operational knowledge. → [Kubernetes](scalability/kubernetes-internals.md)

**Orchestration** — Saga driven by a central coordinator. → [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md)

**Outbox pattern** — Atomic database write + event-emit via an outbox table. → [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md), [Event-driven](architecture-patterns/event-driven-architecture.md)

## P

**P2C (Power of Two Choices)** — Pick two random servers; route to less loaded. Effective load-balancing strategy. → [Load Balancing](scalability/load-balancing-strategies.md)

**PACELC** — Refinement of CAP: under Partition pick A or C; Else pick Latency or Consistency. → [CAP](distributed-systems/cap-consistency-and-replication.md)

**Page cache** — OS-level cache of disk pages in RAM. → [Indexing](database-internals/indexing-and-storage-engines.md)

**Paxos** — Classical consensus algorithm. → [Consensus](distributed-systems/leader-election-and-consensus.md)

**Pin (Rust)** — Type ensuring a future cannot move in memory. → [Async Rust](concurrency/async-rust-and-the-borrow-checker.md)

**Pivot transaction (saga)** — The point of no return; subsequent steps must succeed. → [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md)

**Pod (Kubernetes)** — Smallest deployable unit; one or more containers. → [Kubernetes](scalability/kubernetes-internals.md)

**Polymorphic IC** — V8 IC with a small set of shapes; slower than monomorphic. → [V8](js-runtime/v8-internals-and-hidden-classes.md)

**Postmortem** — Blameless analysis of an incident with action items. → [Postmortems](system-failures/postmortems-and-incident-response.md)

**Probabilistic early refresh** — Cache strategy preventing stampedes. → [Caching](caching/caching-hierarchy.md)

**Prometheus** — Pull-based time-series database for metrics. → [Time-series DBs](database-internals/time-series-databases.md), [Observability](observability/metrics-logs-traces.md)

**Protobuf** — Binary serialization with strong schema; gRPC's wire format. → [API Design](architecture-patterns/api-design-rest-vs-grpc.md)

**Pub/sub** — Decoupled communication via topics. → [Event-driven](architecture-patterns/event-driven-architecture.md)

## Q

**QPACK** — HTTP/3's header compression (QUIC-aware variant of HPACK). → [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md)

**QUIC** — UDP-based transport with TCP-like reliability + TLS 1.3 + per-stream loss handling. → [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md)

**Quorum** — Majority required for distributed agreement. → [CAP](distributed-systems/cap-consistency-and-replication.md), [Consensus](distributed-systems/leader-election-and-consensus.md)

## R

**Raft** — Understandable consensus algorithm. → [Consensus](distributed-systems/leader-election-and-consensus.md)

**RAG** — Retrieval-Augmented Generation. Retrieve context; LLM synthesizes answer. → [LLM Serving](architecture-patterns/llm-serving-and-vector-databases.md)

**Range partitioning** — Sharding by contiguous key ranges. → [Sharding](scalability/sharding-and-partitioning-strategies.md)

**RBAC** — Role-Based Access Control. → [Kubernetes](scalability/kubernetes-internals.md)

**Read replica** — Replica serving read traffic; usually async. → [Replication](database-internals/replication-strategies.md)

**Read-your-writes** — Consistency guarantee: a client sees its own writes. → [CAP](distributed-systems/cap-consistency-and-replication.md)

**Readiness probe (Kubernetes)** — Health check determining whether a pod can receive traffic. → [Kubernetes](scalability/kubernetes-internals.md)

**Reduction (Erlang)** — Unit of work used for fair scheduling. → [Actors](concurrency/actor-model-and-message-passing.md)

**RED method** — Rate, Errors, Duration. Per-service observability. → [Observability](observability/metrics-logs-traces.md)

**Redis** — In-memory data structure store; widely used as cache. → [Caching](caching/caching-hierarchy.md)

**Replication lag** — Time delay between primary and replica. → [Replication](database-internals/replication-strategies.md)

**REST** — HTTP-based API style around resources and verbs. → [API Design](architecture-patterns/api-design-rest-vs-grpc.md)

**Retry budget** — Cap on retries as fraction of base traffic; prevents amplification. → [Timeouts/Retries](system-failures/timeouts-retries-and-idempotency.md)

**RTO / RPO** — Recovery Time / Recovery Point Objective. DR targets. → [Disaster Recovery](system-failures/disaster-recovery-and-rto-rpo.md)

## S

**SACK** — Selective Acknowledgment. TCP option for finer-grained ack. → [TCP](networking/tcp-and-network-fundamentals.md)

**Saga** — Sequence of local transactions with compensations; alternative to 2PC across services. → [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md)

**SAN** — Subject Alternative Name. TLS certificate field for additional hostnames. → [TLS](networking/tls-and-mtls.md)

**Schema registry** — Manages event schemas; enforces compatibility. → [Event-driven](architecture-patterns/event-driven-architecture.md)

**Scrape (Prometheus)** — Pull-based metric collection. → [Observability](observability/metrics-logs-traces.md)

**Sequence number (TCP)** — Position in the byte stream; used for ordering and retransmission. → [TCP](networking/tcp-and-network-fundamentals.md)

**Service mesh** — Sidecar proxies handling cross-cutting concerns (mTLS, routing, observability). → [Microservices](architecture-patterns/microservices-vs-monolith.md), [Load Balancing](scalability/load-balancing-strategies.md)

**Sharding** — Splitting data across multiple databases by some key. → [Sharding](scalability/sharding-and-partitioning-strategies.md)

**Single-flight** — Coalescing concurrent requests for the same key. → [Caching](caching/caching-hierarchy.md)

**SLA** — Service Level Agreement; customer-facing contract. → [SLOs](observability/slos-error-budgets-and-alerting.md)

**SLI** — Service Level Indicator; the measurement. → [SLOs](observability/slos-error-budgets-and-alerting.md)

**SLO** — Service Level Objective; reliability target. → [SLOs](observability/slos-error-budgets-and-alerting.md)

**Slow start (TCP)** — Exponential cwnd ramp-up at connection start. → [TCP](networking/tcp-and-network-fundamentals.md)

**Snapshot isolation** — MVCC-derived isolation level; per-transaction consistent view. → [MVCC](database-internals/mvcc-and-isolation-levels.md)

**Span (tracing)** — One unit of work in a distributed trace. → [Tracing](observability/distributed-tracing-deep-dive.md)

**Spinlock** — Lock implemented by busy-waiting. → [Locks](concurrency/locks-mutexes-and-lock-free.md)

**SSE** — Server-Sent Events. One-way HTTP stream. → [WebSockets](networking/websockets-and-realtime-protocols.md)

**Sticky session** — Route a client to the same server consistently. → [Load Balancing](scalability/load-balancing-strategies.md)

**Strangler fig** — Gradually replace a legacy system route by route. → [Strangler Fig](architecture-patterns/strangler-fig-and-legacy-migration.md)

**Stream (Node)** — Time-ordered data with built-in backpressure. → [Streams in Node](js-runtime/streams-and-backpressure-in-node.md)

**Structured concurrency** — Tasks have lifetimes bound to a scope. → [Coroutines](concurrency/coroutines-and-green-threads.md)

**SWIM** — Scalable Weakly-consistent Infection-style Membership. Gossip protocol. → [Gossip](distributed-systems/gossip-protocols-and-membership.md)

**Synchronous replication** — Primary waits for replica acks before commit. → [Replication](database-internals/replication-strategies.md)

## T

**Tail-based sampling** — Sampling decision made after a trace completes. → [Tracing](observability/distributed-tracing-deep-dive.md)

**Task (async)** — Top-level coroutine scheduled by a runtime. → [Coroutines](concurrency/coroutines-and-green-threads.md)

**Tail latency** — High-percentile latency (p95, p99). → [SLOs](observability/slos-error-budgets-and-alerting.md)

**TCP_NODELAY** — Socket option disabling Nagle's algorithm. → [TCP](networking/tcp-and-network-fundamentals.md)

**Time-to-first-token (TTFT)** — LLM serving latency to first generated token. → [LLM Serving](architecture-patterns/llm-serving-and-vector-databases.md)

**TIME_WAIT** — TCP state after active close; lasts 2 MSL. → [TCP](networking/tcp-and-network-fundamentals.md)

**TLB** — Translation Lookaside Buffer; CPU's virtual-to-physical address cache. → [CPU Caches](concurrency/cpu-caches-and-false-sharing.md)

**TLS** — Transport Layer Security. → [TLS](networking/tls-and-mtls.md)

**Tombstone** — Marker for deleted data, retained until safe to remove. → [MVCC](database-internals/mvcc-and-isolation-levels.md), [Gossip](distributed-systems/gossip-protocols-and-membership.md)

**TopicPartition (Kafka)** — A specific partition of a specific topic. → [Kafka](architecture-patterns/kafka-internals-and-stream-processing.md)

**Trace ID** — Unique identifier shared across all spans of a request. → [Tracing](observability/distributed-tracing-deep-dive.md)

**Transferable (Web Worker)** — Object whose ownership transfers to the worker (zero-copy). → [Web Workers](js-runtime/web-workers-and-shared-memory.md)

**Transform stream (Node)** — Duplex stream that transforms incoming data to outgoing. → [Streams](js-runtime/streams-and-backpressure-in-node.md)

**Tri-color marking** — GC algorithm for concurrent marking. → [GC](js-runtime/garbage-collection-and-memory-management.md)

**TrueTime (Spanner)** — GPS+atomic clock interval providing bounded time uncertainty. → [Clocks](distributed-systems/clocks-time-and-ordering.md)

**TTL** — Time To Live. → [DNS](networking/dns-deep-dive.md), [Caching](caching/caching-hierarchy.md)

**Two-phase commit (2PC)** — Classical distributed transaction protocol. Prepare + commit. → [2PC/3PC](distributed-systems/distributed-transactions-2pc-3pc.md)

## U

**Ubiquitous language (DDD)** — Vocabulary shared between developers and domain experts. → [DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md)

**Unhandled rejection** — Promise that rejects without `.catch`; modern Node terminates. → [Event Loop](js-runtime/event-loop-and-async-runtime.md)

**USE method** — Utilization, Saturation, Errors. Resource observability. → [Observability](observability/metrics-logs-traces.md)

## V

**Vector clock** — Per-process counter array; captures concurrency vs causality. → [Clocks](distributed-systems/clocks-time-and-ordering.md)

**Vector database** — Stores embeddings; ANN search. → [LLM Serving](architecture-patterns/llm-serving-and-vector-databases.md)

**Vectorized execution** — Process batches of values at once; SIMD-friendly. → [OLTP vs OLAP](database-internals/oltp-vs-olap-and-columnar-storage.md)

**Virtual thread (JVM)** — Loom's lightweight thread; multiplexed onto OS threads. → [JVM](concurrency/jvm-internals-and-virtual-threads.md)

**Vnode (consistent hashing)** — Multiple ring positions per physical node. → [Sharding](scalability/sharding-and-partitioning-strategies.md)

**Volatile (Java)** — Variable read/written with sequential consistency. → [Locks](concurrency/locks-mutexes-and-lock-free.md)

## W

**WAL** — Write-Ahead Log. → [WAL](database-internals/wal-and-crash-recovery.md)

**Waterfall view (tracing)** — Standard trace UI showing spans on a time axis. → [Tracing](observability/distributed-tracing-deep-dive.md)

**WebSocket** — Persistent bidirectional channel over HTTP-upgraded connection. → [WebSockets](networking/websockets-and-realtime-protocols.md)

**WebTransport** — Modern alternative to WebSocket over QUIC. → [WebSockets](networking/websockets-and-realtime-protocols.md)

**Window scaling (TCP)** — TCP option enabling receive windows >64KB. → [TCP](networking/tcp-and-network-fundamentals.md)

**Work stealing** — Scheduler pattern: idle threads steal from busy ones' queues. → [Coroutines](concurrency/coroutines-and-green-threads.md), [Go](concurrency/go-runtime-and-goroutines.md)

**Write amplification** — Bytes written to disk per logical byte stored. → [Indexing](database-internals/indexing-and-storage-engines.md)

**Write barrier (GC)** — Code inserted at pointer writes to maintain GC invariants. → [GC](js-runtime/garbage-collection-and-memory-management.md)

## X-Z

**XA** — Standard for distributed transactions across resource managers. → [2PC/3PC](distributed-systems/distributed-transactions-2pc-3pc.md)

**ZGC** — Concurrent low-pause JVM GC. → [JVM](concurrency/jvm-internals-and-virtual-threads.md), [GC](js-runtime/garbage-collection-and-memory-management.md)

**Zero-copy** — I/O technique avoiding intermediate copies (e.g., `sendfile`). → [Kafka](architecture-patterns/kafka-internals-and-stream-processing.md)

**Zero-trust** — Network architecture trusting nothing based on location; identity-based. → [TLS](networking/tls-and-mtls.md)

**ZooKeeper** — Consensus-backed coordination service; classical (now superseded by KRaft for Kafka). → [Kafka](architecture-patterns/kafka-internals-and-stream-processing.md), [Consensus](distributed-systems/leader-election-and-consensus.md)
