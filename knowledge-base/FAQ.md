# FAQ — Recurring Questions

> Questions that come up across the corpus, with short answers and pointers to the artifact that goes deeper. Use as a quick lookup when you have a specific question; use the linked artifacts for full understanding.

---

## Database & Storage

### Why does my SELECT not block when someone is updating the same row?

MVCC. The database keeps multiple versions; readers see a snapshot taken at transaction start. Writers create new versions. No read locks. → [MVCC & Isolation Levels](database-internals/mvcc-and-isolation-levels.md)

### Why does my Postgres database keep growing even though I delete data?

MVCC creates dead tuples (deleted/superseded versions). Vacuum reclaims them. If vacuum can't run (long-running transactions, autovacuum disabled), bloat accumulates. → [MVCC & Isolation Levels](database-internals/mvcc-and-isolation-levels.md)

### Why doesn't my index help my query?

Common causes: function on the column (`WHERE upper(email) = ...` defeats index unless functional index exists); leading column not in WHERE for composite index; selectivity too low (planner picks seq scan); stale statistics; query plan cached for different parameter. → [Query Optimization & Plans](database-internals/query-optimization-and-execution-plans.md)

### When should I use a B-tree vs LSM tree?

B-tree: read-heavy, point lookups, range queries, low write rate. LSM: write-heavy, append-mostly, can tolerate higher read amplification. Postgres/MySQL/InnoDB are B-tree; Cassandra/RocksDB/Scylla are LSM. → [Indexing & Storage Engines](database-internals/indexing-and-storage-engines.md)

### What's the difference between Repeatable Read in Postgres vs MySQL?

Postgres RR uses true snapshot isolation (one snapshot per transaction). MySQL InnoDB RR uses snapshot-style for SELECT but current reads with locking for `SELECT ... FOR UPDATE` and DML, leading to subtly different semantics. → [MVCC & Isolation Levels](database-internals/mvcc-and-isolation-levels.md)

### How do I shard a database?

Choose a partition key that's in your hot queries (avoids scatter-gather), distributes load evenly (avoids hot keys), and that you won't need to change. Default: hash by tenant/user ID for SaaS; range by date for time-series. → [Sharding & Partitioning](scalability/sharding-and-partitioning-strategies.md)

### Why do my reads from a replica show old data?

Async replication has lag — typically milliseconds, sometimes seconds. Reading from a replica means seeing data as of the replica's current position, which trails the primary. → [Replication Strategies](database-internals/replication-strategies.md)

### Should I use Postgres for analytics?

For small-to-medium analytics on operational data, yes. For aggregations over millions of rows or batch reporting, no — replicate to a columnar warehouse (Snowflake, ClickHouse, BigQuery). Running heavy analytics on production OLTP locks tables and ruins user-facing performance. → [OLTP vs OLAP & Columnar Storage](database-internals/oltp-vs-olap-and-columnar-storage.md)

### What's the right way to do schema migrations?

Expand-contract: add new columns alongside old; backfill; dual-write; switch reads; remove old. Each step is independently deployable and reversible. Avoid "big migration windows." → [Strangler Fig & Legacy Migration](architecture-patterns/strangler-fig-and-legacy-migration.md)

---

## Distributed Systems

### Should I use 2PC across services?

No. 2PC blocks indefinitely on coordinator failure; it has been the cause of countless production outages. Use sagas with compensation instead. 2PC is acceptable inside a single database that uses consensus-backed coordination (Spanner, CockroachDB). → [Distributed Transactions 2PC/3PC](distributed-systems/distributed-transactions-2pc-3pc.md)

### What's the right cluster size for etcd / Raft / consensus?

Odd: 3, 5, or 7. Even sizes (4) tolerate the same number of failures as the smaller odd size (3) but with more failure surface. Most production clusters use 3 or 5. → [Leader Election & Consensus](distributed-systems/leader-election-and-consensus.md)

### Can I use timestamps to order events across services?

Not reliably. Clocks across machines disagree by milliseconds (NTP) and can jump backward (clock corrections, VM migrations). Use logical clocks (Lamport, vector, HLC) for causal ordering. Use TrueTime if you need real-time-respecting ordering and have the hardware. → [Clocks, Time & Ordering](distributed-systems/clocks-time-and-ordering.md)

### Is exactly-once delivery possible?

No. The network cannot tell you whether a message was received when no ack arrives. You can have at-least-once delivery + idempotent processing = effectively-once outcome. Treat any "exactly-once delivery" claim with skepticism. → [Idempotency & Exactly-Once](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)

### What does CAP actually mean?

During network partitions, a distributed system must choose: respond to all requests with possibly-stale data (Available, not Consistent) or refuse to respond until consistent (Consistent, not Available). It does NOT mean "pick 2 of 3 in steady state." → [CAP, Consistency & Replication](distributed-systems/cap-consistency-and-replication.md)

### When should I use leader-based vs leaderless replication?

Leader-based (Postgres streaming, Raft) for strong consistency and simpler reasoning. Leaderless (Cassandra, DynamoDB) for higher availability under partition and tunable consistency at the cost of conflict-resolution complexity. → [Replication Strategies](database-internals/replication-strategies.md)

### What's the difference between Raft and Paxos?

They solve the same problem (consensus). Raft was designed to be more understandable; it explicitly factors leader election from log replication. Paxos is mathematically elegant but notoriously hard to grok. Modern systems mostly use Raft. → [Leader Election & Consensus](distributed-systems/leader-election-and-consensus.md)

---

## Concurrency

### Why doesn't threading make my Python code faster?

The GIL serializes Python bytecode execution. CPU-bound code doesn't benefit from threads. For CPU work, use multiprocessing (separate Python processes). For I/O, threading or asyncio works (GIL released during I/O). For numerics, NumPy releases GIL during compute. → [Python Runtime & the GIL](concurrency/python-runtime-and-the-gil.md)

### Threads or async? Goroutines or threads-with-locks?

I/O-bound: prefer async (asyncio, tokio, Node, Go) — handles many concurrent operations cheaply. CPU-bound: prefer real threads or processes (parallelism, not just concurrency). Mixed: use a runtime that offers both (Go, modern Java with Loom). → [Parallelism vs Concurrency](concurrency/parallelism-vs-concurrency.md)

### What is false sharing and how do I fix it?

Two threads modify different variables that happen to share a CPU cache line (typically 64 bytes). Cache coherence invalidates the line on each write, even though the variables are unrelated. Fix: align/pad each hot variable to a cache line boundary. → [CPU Caches & False Sharing](concurrency/cpu-caches-and-false-sharing.md)

### Why is my multi-threaded code slower than single-threaded?

Common causes: lock contention (one mutex serializing all threads); false sharing (cache-line bouncing); insufficient parallelism (Amdahl's Law); thread-creation overhead; GIL (Python). Profile to find the cause. → [Locks, Mutexes & Lock-Free](concurrency/locks-mutexes-and-lock-free.md)

### When should I use channels vs locks?

Channels (Go, Erlang, Rust mpsc) for coordinating between concurrent units; the data ownership transfers with the message. Locks for protecting shared mutable state where transfer doesn't fit. Modern style prefers channels and immutability over locks. → [Locks](concurrency/locks-mutexes-and-lock-free.md), [Go Runtime](concurrency/go-runtime-and-goroutines.md)

### Why does my Node.js service stall under load?

Most likely: a CPU-heavy operation (JSON parse of large payload, regex backtracking, synchronous fs call) is blocking the event loop. Or libuv's thread pool (default 4) is saturated by file/DNS operations. Profile event-loop lag. → [Node.js Architecture](js-runtime/nodejs-architecture-and-libuv.md)

### What's the difference between concurrency and parallelism?

Concurrency is *structure* — writing programs as multiple cooperating activities. Parallelism is *execution* — actually running things simultaneously on multiple CPUs. You can have one without the other. → [Parallelism vs Concurrency](concurrency/parallelism-vs-concurrency.md)

---

## Networking

### Why is my new connection so slow?

Connection establishment costs round trips: TCP handshake (1 RTT) + TLS handshake (1-2 RTT). On a 100ms link, that's 200-300ms before the first byte. Connection pooling amortizes this; HTTP/2 multiplexing reduces it further. → [TCP](networking/tcp-and-network-fundamentals.md)

### What's TIME_WAIT and why does it matter?

A TCP connection state lasting 2× MSL (~60-120s) after active close. High-churn servers accumulate many TIME_WAIT entries; can exhaust ephemeral ports. Mitigations: connection reuse, port range tuning, `SO_REUSEADDR`. → [TCP](networking/tcp-and-network-fundamentals.md)

### Should I use HTTP/2 or HTTP/3?

HTTP/2 is well-supported; deploy it minimum. HTTP/3 (over QUIC) eliminates TCP head-of-line blocking — significantly faster on lossy networks (mobile). Deploy HTTP/3 at edge first; fall back to HTTP/2 where unavailable (corporate firewalls block UDP). → [HTTP/2 & HTTP/3](networking/http-2-and-http-3.md)

### Why do my DNS changes take so long to propagate?

TTL controls cache duration at every layer (browser, OS, ISP). A change with TTL=86400 (1 day) propagates only as fast as the slowest cache. Lower TTL ahead of changes. → [DNS](networking/dns-deep-dive.md)

### When should I use WebSockets vs SSE vs polling?

Polling: simple but wasteful; OK for low-frequency updates. SSE: server-to-client only; works through proxies; auto-reconnect built in. WebSocket: bidirectional persistent; for chat, collaborative editing, multiplayer. → [WebSockets & Real-Time](networking/websockets-and-realtime-protocols.md)

### Should I use TLS 1.2 or 1.3?

TLS 1.3. It's faster (1 RTT vs 2), simpler, more secure (mandatory forward secrecy, fewer cipher suites). Disable TLS 1.0/1.1 (insecure); deprecate 1.2 for new deployments. → [TLS](networking/tls-and-mtls.md)

### How do I do mTLS in production?

Service mesh (Istio, Linkerd, Consul Connect) automates mTLS between services with sidecar proxies. Each service identity is a certificate; rotation automated. Application code is unaware. → [TLS](networking/tls-and-mtls.md)

---

## Observability

### Should I add user_id as a label on my metric?

No — high-cardinality labels (user_id, request_id, full URL) explode time-series counts and storage. Put high-cardinality data in logs and traces; keep metrics low-cardinality. → [Cardinality](observability/cardinality-and-the-economics-of-monitoring.md)

### What's the difference between SLI, SLO, and SLA?

SLI is the measurement (e.g., "fraction of requests under 200ms"). SLO is the target (e.g., 99.9% over 28 days). SLA is the customer-facing contract (with consequences for breach). → [SLOs](observability/slos-error-budgets-and-alerting.md)

### How do I avoid alert fatigue?

Page only on user-facing impact tied to SLO violations. Use burn-rate alerts (multi-window, multi-burn-rate) instead of static thresholds. Cull alerts ruthlessly; if an alert is "informational," make it a ticket or dashboard, not a page. → [SLOs](observability/slos-error-budgets-and-alerting.md)

### Tail-based or head-based sampling for traces?

Head-based (decide at request start) is simpler but misses interesting events (errors are rare). Tail-based (decide after request completes) preserves errors and slow requests at high fidelity. Production grade: tail sampling with bias toward errors and slow paths. → [Distributed Tracing](observability/distributed-tracing-deep-dive.md)

### How do I find the bottleneck in a slow service?

Profile. Don't guess. CPU profile shows where compute time goes; off-CPU shows where threads wait; allocation profile shows GC pressure. Read flame graphs by *width* (time spent), not height (call depth). → [Profiling & Flame Graphs](observability/profiling-and-flame-graphs.md)

### Trace IDs in log lines — why?

So you can pivot between trace and logs for the same request. See an error in logs → click trace ID → see the trace context. Without this correlation, traces and logs are two disconnected worlds. → [Distributed Tracing](observability/distributed-tracing-deep-dive.md)

---

## Scalability & Architecture

### Should we move from monolith to microservices?

Probably not, unless you have specific pain that microservices solve and the operational maturity to take on the cost. Many teams that migrate to microservices later consolidate back. Default: modular monolith with strict boundaries. → [Microservices vs Monolith](architecture-patterns/microservices-vs-monolith.md)

### How do I migrate a legacy system?

Strangler fig: route by route, function by function. Build a façade that can route to either old or new. Replace one piece at a time; ramp traffic; verify; move on. Avoid "big rewrites" — they fail almost universally. → [Strangler Fig](architecture-patterns/strangler-fig-and-legacy-migration.md)

### When should I use sagas vs synchronous APIs?

Synchronous when the operation is truly atomic and the latency is acceptable. Sagas when the operation involves multiple services, when you can't hold locks across them, or when network partitions are realistic. Most modern cross-service workflows are sagas. → [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md)

### What's the difference between event-driven and message-queue architecture?

Message queues are point-to-point; events are pub/sub. Event-driven uses durable, replayable logs (Kafka). The message-queue pattern fits work distribution; the event-driven pattern fits decoupled reactions. → [Event-Driven Architecture](architecture-patterns/event-driven-architecture.md)

### When should I use CQRS / event sourcing?

CQRS: when read and write models are genuinely different (often true). Event sourcing: when history is a feature (audit-heavy, financial, collaborative). Don't event-source CRUD apps; the operational cost isn't worth it. → [CQRS & Event Sourcing](architecture-patterns/cqrs-and-event-sourcing.md)

### Sticky sessions — yes or no?

Avoid where possible. Externalize session state (Redis, DB) so any instance can serve any user. Sticky sessions multiply the impact of instance failures. → [Load Balancing](scalability/load-balancing-strategies.md)

### How do I size my service for capacity?

Start with the bottleneck resource (CPU? memory? database connections? IOPS?). Plan for steady-state baseline + variance + failure tolerance. Auto-scaling handles noise around the baseline; capacity planning sets the baseline. → [Auto-Scaling & Capacity Planning](scalability/auto-scaling-and-capacity-planning.md)

### Should I run my own Kubernetes or use a managed service?

Managed unless you have a specific reason not to. Operating Kubernetes well is non-trivial; managed services (EKS, GKE, AKS) handle the control-plane burden. → [Kubernetes Internals](scalability/kubernetes-internals.md)

---

## System Failures

### What's the difference between containment and eradication in a security incident?

Containment stops the immediate damage (block the attacker's IP, disable accounts). Eradication removes the threat entirely (patch the vulnerability, rotate credentials, audit for persistence). Skipping eradication means the attacker comes back. → [Security IR](system-failures/security-incident-response.md)

### How long should my RTO and RPO be?

Business decision, not engineering decision. Engineering implements; business sets target. Common: payment systems target minutes; analytics tolerates hours. Tighter targets cost exponentially more (hot standby vs nightly backups). → [Disaster Recovery](system-failures/disaster-recovery-and-rto-rpo.md)

### What's a blameless postmortem?

A postmortem that focuses on systems and processes, not individual blame. Blameless ≠ accountability-free; the team owns improvements. The discipline produces honest analysis; blame produces silence and lies. → [Postmortems](system-failures/postmortems-and-incident-response.md)

### Should I do chaos engineering in production?

Yes, with safety. Bound the blast radius (1% of traffic, one cell, one AZ). Have auto-abort on SLO breach. Hypothesize before you inject. Don't do it without these guardrails. → [Chaos Engineering](system-failures/chaos-engineering-and-game-days.md)

### What's a feature flag's TTL?

The maximum time the flag should exist. Release flags should be removed after rollout (days to weeks). Operational flags (kill switches) are permanent. Setting TTLs at flag creation prevents flag debt. → [Feature Flags](system-failures/feature-flags-and-progressive-delivery.md)

---

## API Design & Integration

### REST vs gRPC vs GraphQL — which?

REST for public APIs (discoverability, ubiquity). gRPC for internal service-to-service (efficiency, type safety, code generation). GraphQL for client-driven queries (mobile apps, aggregator backends). Modern systems use all three at different boundaries. → [API Design](architecture-patterns/api-design-rest-vs-grpc.md)

### Should I version my API in the URL or with headers?

URL versioning (`/v1/users`) is more discoverable; header versioning (`Accept: ...; version=2`) is cleaner. Either works. The bigger discipline: avoid breaking changes; deprecate clearly; remove only after migration. → [API Design](architecture-patterns/api-design-rest-vs-grpc.md)

### How do I make a POST endpoint safe to retry?

Idempotency keys. Client provides a unique ID per logical operation; server stores response keyed by that ID. Retries with the same key return the cached response without re-executing. → [Idempotency & Exactly-Once](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)

### What's the right pagination approach?

Cursor-based, not offset-based. Offsets shift when items are added/removed; cursors are stable. → [API Design](architecture-patterns/api-design-rest-vs-grpc.md)

---

## Performance

### Why is my GC pause so long?

Old-generation GC is the usual culprit. Mitigations: switch to a low-pause GC (ZGC, Shenandoah for JVM; reduce allocations); tune heap size; reduce allocation rate (object pooling). Always-on profiling helps. → [GC](js-runtime/garbage-collection-and-memory-management.md)

### Why is my V8/Node code slower than I expect?

Hidden classes and inline caches. If your hot code creates objects with different shapes, the IC degrades from monomorphic (fast) to megamorphic (slow). Initialize all object fields uniformly; avoid `delete`; use stable shapes. → [V8 Internals](js-runtime/v8-internals-and-hidden-classes.md)

### Why is my distributed cache hit rate low?

Cache key includes session-specific data (cookies, user IDs); each user gets a unique key. Or `Vary` headers split the cache too finely. Audit cache keys; ensure shared resources have shared keys. → [Caching Hierarchy](caching/caching-hierarchy.md)

### How do I prevent retry storms?

Exponential backoff with jitter, retry budgets (cap retries as fraction of base traffic), circuit breakers (don't retry into known-broken dependencies), and retry at one layer only (not at every level of the stack). → [Timeouts/Retries/Idempotency](system-failures/timeouts-retries-and-idempotency.md)

---

## When in Doubt

If you're not sure where to look:

- **A specific term**: [GLOSSARY.md](GLOSSARY.md).
- **An acronym**: [ACRONYMS-BY-DOMAIN.md](ACRONYMS-BY-DOMAIN.md).
- **A common pitfall**: [COMMON-MISTAKES.md](COMMON-MISTAKES.md).
- **A reading order**: [LEARNING-PATHS.md](LEARNING-PATHS.md).
- **What to read before this**: [DEPENDENCY-GRAPH.md](DEPENDENCY-GRAPH.md).
- **Quick refresher per topic**: [STARTER-CARDS.md](STARTER-CARDS.md).
- **Full topic list**: [INDEX.md](INDEX.md).
