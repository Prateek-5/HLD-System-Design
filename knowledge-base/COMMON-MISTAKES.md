# Common Mistakes — A Production Engineer's Checklist

> Mistakes that recur across teams, products, and decades. Each entry: the mistake, why it's wrong, the fix, and a pointer to the artifact for context. Use as a code-review checklist or a personal memory aid.

---

## Database & Storage

### ❌ Running analytical queries on production OLTP

A 30-minute aggregation locks tables and ruins user-facing latency. The "quick report" becomes a production incident.
- **Fix**: Replicate to a read replica or warehouse for analytics. Use CDC for near-real-time.
- → [OLTP vs OLAP](database-internals/oltp-vs-olap-and-columnar-storage.md)

### ❌ `SELECT *` in production hot paths

Forces all columns to disk; defeats covering indexes; transmits unnecessary bytes; couples the API to schema changes.
- **Fix**: List explicit columns. Use the smallest set you need.
- → [Indexing & Storage Engines](database-internals/indexing-and-storage-engines.md)

### ❌ Adding indexes without measuring

Every index taxes writes. Many indexes that "might be useful" sit unused. Drop unused indexes; add only when measured improvement justifies.
- **Fix**: Audit `pg_stat_user_indexes` (or equivalent) for `idx_scan = 0`; drop those.
- → [Indexing & Storage Engines](database-internals/indexing-and-storage-engines.md)

### ❌ Forgetting `ANALYZE` after bulk loads

Stale statistics cause planner to choose disastrous plans (nested loop on what should be hash join). Performance regression with no code change.
- **Fix**: Always `ANALYZE` after data loads / migrations. Configure autovacuum properly.
- → [Query Optimization & Plans](database-internals/query-optimization-and-execution-plans.md)

### ❌ Long-running transactions

Pin WAL on the primary, prevent vacuum, accumulate lock waiters, and turn into outages 12 hours later when someone forgot a `BEGIN`.
- **Fix**: Monitor `pg_stat_activity` for oldest transaction; alert on transactions older than ~5 minutes.
- → [MVCC & Isolation Levels](database-internals/mvcc-and-isolation-levels.md)

### ❌ Random UUIDs as primary keys

UUIDv4 is unsorted; inserts go to random positions in the B-tree, causing page splits across the entire index. Insert performance collapses.
- **Fix**: Use UUIDv7 or ULID (sortable by time); or autoincrement integers when ordering doesn't matter.
- → [Indexing & Storage Engines](database-internals/indexing-and-storage-engines.md)

### ❌ Believing "Repeatable Read" means the same in every database

Postgres RR is true snapshot isolation; MySQL InnoDB RR uses snapshot for SELECT but locking semantics for `SELECT FOR UPDATE`; Oracle's "Serializable" is actually snapshot isolation. Same word, different guarantees.
- **Fix**: Read your specific database's documentation; never assume.
- → [MVCC & Isolation Levels](database-internals/mvcc-and-isolation-levels.md)

### ❌ Cross-aggregate transactions in DDD

Trying to atomically update across aggregate boundaries; works locally but fights against the architecture and creates deadlocks at scale.
- **Fix**: Aggregates are consistency boundaries. Cross-aggregate updates are eventual via domain events.
- → [Anti-Corruption Layer & DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md)

---

## Distributed Systems

### ❌ Even-sized consensus clusters (4 nodes)

Tolerates the same number of failures as a 3-node cluster (1) but with more failure surface. Lose 2 nodes and you've lost quorum.
- **Fix**: 3, 5, or 7. Never 4.
- → [Leader Election & Consensus](distributed-systems/leader-election-and-consensus.md)

### ❌ Using wall-clock timestamps for distributed ordering

Clocks across machines disagree (NTP keeps them within ~10ms; can be much worse). Last-write-wins by wall-clock makes the machine with the fast clock always "win." Silent data corruption.
- **Fix**: Use logical clocks (Lamport, vector, HLC) for ordering. Wall-clock for human-readable timestamps only.
- → [Clocks, Time & Ordering](distributed-systems/clocks-time-and-ordering.md)

### ❌ Using XA / 2PC across services

Coordinator failure leaves participants in "prepared" state with locks held; production stalls; manual recovery required.
- **Fix**: Sagas with compensation. 2PC only inside a single database that uses consensus-backed coordination.
- → [Distributed Transactions 2PC/3PC](distributed-systems/distributed-transactions-2pc-3pc.md)

### ❌ Promising "exactly-once delivery"

Mathematically impossible across an unreliable network. Marketing aside, you can't deliver this.
- **Fix**: At-least-once delivery + idempotent receivers = effectively-once outcome. Document semantics honestly.
- → [Idempotency & Exactly-Once](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)

### ❌ Manual etcd / consensus cluster surgery without joint consensus

Naive add/remove of cluster members can produce two majorities (and two leaders) during the transition. Catastrophic.
- **Fix**: Use library-implemented joint consensus. Don't roll your own membership changes.
- → [Leader Election & Consensus](distributed-systems/leader-election-and-consensus.md)

### ❌ Believing "the network is reliable"

The first of Peter Deutsch's 1994 fallacies. Every retry-without-idempotency, every infinite-timeout, every assume-it-arrived design is downstream of this assumption.
- **Fix**: Every external call has three outcomes (success, fail, *unknown*). Design for the third.
- → [Timeouts, Retries & Idempotency](system-failures/timeouts-retries-and-idempotency.md)

---

## Concurrency

### ❌ `count++` for shared state (in most languages)

Compiles to load-modify-store. Two threads can interleave; updates lost. The cardinal sin of multi-threaded counters.
- **Fix**: Atomic increment (`AtomicInteger`, `atomic.fetch_add`, `++` is atomic in Go for `sync/atomic` types only).
- → [Locks, Mutexes & Lock-Free](concurrency/locks-mutexes-and-lock-free.md)

### ❌ Holding a lock while doing I/O

The lock holder blocks; everyone waiting on that lock blocks transitively; throughput collapses.
- **Fix**: Acquire lock, copy/check state, release lock, then do I/O on the copy.
- → [Locks, Mutexes & Lock-Free](concurrency/locks-mutexes-and-lock-free.md)

### ❌ Using `std::sync::Mutex` (or equivalent blocking lock) inside async code

Holds the OS thread; the async runtime can't reuse it for other tasks. Throughput collapses.
- **Fix**: Use the runtime's async-aware mutex (`tokio::sync::Mutex`, `parking_lot` won't help here).
- → [Async Rust](concurrency/async-rust-and-the-borrow-checker.md)

### ❌ Threads for CPU-bound Python work

GIL serializes Python bytecode. CPU-heavy threads don't run in parallel; they take turns.
- **Fix**: `multiprocessing` for CPU-bound; `asyncio`/threads for I/O-bound; NumPy for numerics (releases GIL during compute).
- → [Python Runtime & the GIL](concurrency/python-runtime-and-the-gil.md)

### ❌ Forgetting to handle the race between `check` and `act`

`if (cache.has(k)) { return cache.get(k); } else { v = compute(); cache.set(k, v); }` — multiple threads compute the same value.
- **Fix**: Single-flight pattern (coalesce concurrent fillers); or atomic compute-if-absent.
- → [Caching Hierarchy](caching/caching-hierarchy.md)

### ❌ Per-thread counters without cache-line padding

False sharing destroys scaling. 16 counters in 16 threads, sub-linear performance because the cache line bounces.
- **Fix**: Pad each counter to its own cache line (typically 64 bytes).
- → [CPU Caches & False Sharing](concurrency/cpu-caches-and-false-sharing.md)

### ❌ Spawning unbounded goroutines / async tasks

Each request spawns a task that never terminates; memory grows; OOM eventually.
- **Fix**: Bounded worker pools; structured concurrency; explicit lifetimes.
- → [Coroutines & Green Threads](concurrency/coroutines-and-green-threads.md)

---

## JS Runtime

### ❌ `JSON.parse` of large payloads in a hot path

Synchronous; blocks the event loop. A 10MB JSON parse pauses every other request for tens of milliseconds.
- **Fix**: Stream parsing for large payloads; move to worker threads; or shrink the payload.
- → [Event Loop](js-runtime/event-loop-and-async-runtime.md)

### ❌ Inconsistent object shape in V8 hot paths

Conditional property addition creates many hidden classes; inline cache becomes megamorphic; performance drops 10-50×.
- **Fix**: Initialize all properties uniformly (use null/undefined for absent values); avoid `delete`; use classes.
- → [V8 Internals & Hidden Classes](js-runtime/v8-internals-and-hidden-classes.md)

### ❌ `delete obj.password` to scrub before returning

`delete` triggers transition to dictionary mode; the object's hot-path performance plummets.
- **Fix**: Set to `null`; or construct a new object with the safe fields.
- → [V8 Internals & Hidden Classes](js-runtime/v8-internals-and-hidden-classes.md)

### ❌ `forEach` with async callback

`forEach` doesn't await the callback. Loop completes before async work finishes.
- **Fix**: `for...of` with `await`; or `Promise.all(arr.map(...))` for parallel.
- → [Event Loop](js-runtime/event-loop-and-async-runtime.md)

### ❌ Default `UV_THREADPOOL_SIZE` (4) for I/O-heavy services

DNS lookups, file I/O, crypto, zlib all share 4 libuv threads. Saturates under load; CPU sits idle while requests queue.
- **Fix**: `UV_THREADPOOL_SIZE=128` (or as appropriate); use `dns.resolve` instead of `dns.lookup` for high-volume DNS.
- → [Node.js Architecture & libuv](js-runtime/nodejs-architecture-and-libuv.md)

### ❌ Ignoring `writable.write()` return value when piping streams manually

Writes pile up in the buffer; memory grows unbounded; eventual OOM.
- **Fix**: Use `pipeline()` (handles backpressure correctly); or check return value and wait for `'drain'`.
- → [Streams & Backpressure in Node](js-runtime/streams-and-backpressure-in-node.md)

### ❌ Unhandled promise rejections in production

Modern Node terminates the process by default. Code without explicit `.catch` is a latent crash.
- **Fix**: `.catch` every promise chain; or use top-level `unhandledRejection` handler that logs and exits cleanly.
- → [Event Loop](js-runtime/event-loop-and-async-runtime.md)

---

## Networking

### ❌ Default infinite timeouts on HTTP clients

A slow downstream hangs your service forever. The default in many libraries is *no timeout*.
- **Fix**: Explicit timeout on every external call. Decreasing timeouts from outer to inner. Use deadlines if your runtime supports them.
- → [TCP](networking/tcp-and-network-fundamentals.md), [Timeouts/Retries](system-failures/timeouts-retries-and-idempotency.md)

### ❌ Three layers of retries (client + gateway + service mesh)

Single failure becomes 27× amplification. Cascading failure when downstream is slow.
- **Fix**: Retry at one layer only (typically the outermost). Use retry budgets in service mesh.
- → [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md)

### ❌ Forgetting `TCP_NODELAY` for latency-sensitive workloads

Nagle's algorithm + delayed ACK → 200ms latency on small writes. The infamous "why is my RPC slow" bug.
- **Fix**: `TCP_NODELAY` socket option for latency-sensitive paths.
- → [TCP](networking/tcp-and-network-fundamentals.md)

### ❌ Cache key without `Vary` header

`Accept-Language: fr` user requests a page; cache stores German version under same key; subsequent users get wrong language. Or worse: PII leaks between users.
- **Fix**: `Vary` header on responses; thoughtful cache key design.
- → [Caching Hierarchy](caching/caching-hierarchy.md)

### ❌ Long DNS TTLs without consideration for failover

Failover requires waiting for cached records to expire. With TTL=86400, recovery takes a day for some users.
- **Fix**: Lower TTLs (60-300s) for records that might fail over. Anycast for instant failover.
- → [DNS Deep Dive](networking/dns-deep-dive.md)

### ❌ Returning HTTP 200 with `{ "error": "..." }`

Defeats HTTP-level retry logic, caching, monitoring. Tooling expects status codes; you've broken the contract.
- **Fix**: Use proper status codes (4xx for client errors, 5xx for server). Errors in body are *additional* to status code.
- → [API Design](architecture-patterns/api-design-rest-vs-grpc.md)

---

## Caching

### ❌ Cache key including session-specific data

Each user has a unique key. Cache hit rate near zero. Origin load same as no-cache.
- **Fix**: Audit cache keys; ensure shared resources have shared keys; user-specific data goes elsewhere (per-user storage, not cache).
- → [Caching Hierarchy](caching/caching-hierarchy.md)

### ❌ DELETE-then-write race

Code: write DB, then `DELETE` cache key. Another request reads stale cache before delete and writes back. Stale data persists forever.
- **Fix**: Versioned keys (include version number; bump on writes); delete-and-set pattern; or read-through with proper invalidation.
- → [Caching Hierarchy](caching/caching-hierarchy.md)

### ❌ Cache stampede on hot keys

Popular key expires; thousand requests miss simultaneously; thousand identical queries hit the database.
- **Fix**: Single-flight (mutex per key); probabilistic early refresh; stale-while-revalidate.
- → [Caching Hierarchy](caching/caching-hierarchy.md)

### ❌ Treating Redis as primary storage

"It's just a cache" team accidentally relies on Redis for durability. Redis crashes. Data lost.
- **Fix**: Caches are caches. If you need durability, configure persistence and replication; but better, use a proper database for the source of truth.
- → [Caching Hierarchy](caching/caching-hierarchy.md)

---

## Observability

### ❌ Adding `user_id` as a label on metrics

10M users → 10M time series → TSDB melts → bill explodes.
- **Fix**: High-cardinality data goes in logs and traces, not metrics. Tag metrics by service, endpoint, status — low cardinality.
- → [Cardinality](observability/cardinality-and-the-economics-of-monitoring.md)

### ❌ Page on CPU > 80%

Symptoms, not causes. Wakes someone for a non-actionable signal. Alert fatigue.
- **Fix**: Page on user-facing impact (SLO violations). CPU is a dashboard metric, not a page.
- → [SLOs, Error Budgets](observability/slos-error-budgets-and-alerting.md)

### ❌ Average latency as the primary metric

Hides the tail. Mean of [10ms × 99 + 5000ms × 1] = ~60ms; the user experience is "1% of users wait 5 seconds."
- **Fix**: p50/p95/p99 always. Distribution, not average.
- → [Metrics, Logs & Traces](observability/metrics-logs-traces.md)

### ❌ Free-text logs at scale

Costly to index, slow to query, hard to aggregate. Every log line is a snowflake.
- **Fix**: Structured logs (JSON) with consistent fields. Index the fields you'll query.
- → [Metrics, Logs & Traces](observability/metrics-logs-traces.md)

### ❌ No trace IDs in log lines

Logs and traces are two disconnected worlds. Debugging a slow customer request means searching both manually.
- **Fix**: Every log line includes the trace ID. Pivot freely between trace and logs.
- → [Distributed Tracing](observability/distributed-tracing-deep-dive.md)

### ❌ 1% head sampling for traces

Bug occurs in 0.1% of requests; you sample 0.001%. Effectively no signal.
- **Fix**: Tail sampling preserving errors and slow requests; head sampling for steady state.
- → [Distributed Tracing](observability/distributed-tracing-deep-dive.md)

---

## Scalability

### ❌ Choosing a partition key without analyzing query patterns

The partition key is your queries' contract. Choose wrong, and you scatter-gather forever.
- **Fix**: Examine top queries first; choose key that's in their `WHERE` clause; verify load distribution; verify hot keys aren't a problem.
- → [Sharding & Partitioning](scalability/sharding-and-partitioning-strategies.md)

### ❌ Believing auto-scaling solves everything

Auto-scaling has minutes of latency (cold start). A 10× spike in 30 seconds is over before scaling reacts.
- **Fix**: Pre-warm capacity for known events; capacity baseline + auto-scaling for noise; load shed at the edge.
- → [Auto-Scaling & Capacity Planning](scalability/auto-scaling-and-capacity-planning.md)

### ❌ Scaling app servers when the bottleneck is the database

The database has fixed connection limit. Adding app servers means each gets fewer connections; doesn't help.
- **Fix**: Identify the bottleneck before scaling. Sometimes the answer is "don't scale; fix the bottleneck."
- → [Auto-Scaling & Capacity Planning](scalability/auto-scaling-and-capacity-planning.md)

### ❌ Sticky sessions everywhere

Every instance failure loses its sessions. Failover is painful.
- **Fix**: Externalize session state (Redis, DB). Stateless instances scale and fail over cleanly.
- → [Load Balancing](scalability/load-balancing-strategies.md)

### ❌ Health checks that probe shared dependencies

Health endpoint that calls the database. Database hiccups → all instances marked unhealthy → service down.
- **Fix**: Health checks reflect *this instance's* health, not its dependencies'.
- → [Load Balancing](scalability/load-balancing-strategies.md)

---

## Architecture

### ❌ "Microservices because Netflix"

Adopted without the operational maturity (observability, CI/CD, on-call rotations) it requires. Distributed monolith results.
- **Fix**: Start with monolith or modular monolith. Extract services only when pain demands it.
- → [Microservices vs Monolith](architecture-patterns/microservices-vs-monolith.md)

### ❌ Splitting services by tier (frontend/backend/database)

The wire crossings are denser than the cohesion. Distributed monolith with all the cost and none of the benefits.
- **Fix**: Split by bounded context (Orders, Payments, Inventory) — domain capabilities, not technology layers.
- → [Microservices vs Monolith](architecture-patterns/microservices-vs-monolith.md), [DDD](architecture-patterns/anti-corruption-layer-and-domain-driven-design.md)

### ❌ Big rewrite

"We'll build the new system in parallel; switchover in 18 months." It's now 36 months; the old system has new features the new doesn't; nothing ships.
- **Fix**: Strangler fig — replace one route at a time. Always have a working system.
- → [Strangler Fig](architecture-patterns/strangler-fig-and-legacy-migration.md)

### ❌ Event sourcing CRUD apps

Operational complexity (replay tooling, schema evolution, projections) without the benefits (audit, history).
- **Fix**: Use event sourcing where history is genuinely a feature (financial, audit-heavy domains). Skip otherwise.
- → [CQRS & Event Sourcing](architecture-patterns/cqrs-and-event-sourcing.md)

### ❌ Synchronous chains 5 services deep

A → B → C → D → E. E has 1% error rate. End-to-end success is 0.99⁵ ≈ 95%. Each layer's latency adds up. Cascading failures inevitable.
- **Fix**: Async events where possible; flatten chains; circuit-break aggressively.
- → [Microservices vs Monolith](architecture-patterns/microservices-vs-monolith.md), [Cascading Failures](system-failures/cascading-failures-and-circuit-breakers.md)

---

## System Failures

### ❌ Untested backups

The backup runs nightly. The restore was never tested. The disaster comes; the restore fails (corrupted, wrong format, missing data); recovery takes 10× longer than expected.
- **Fix**: Restore tests monthly. Quarterly DR drills. The only backup that works is a tested backup.
- → [Disaster Recovery](system-failures/disaster-recovery-and-rto-rpo.md)

### ❌ Skipping the postmortem

"We know what happened; let's move on." Six months later, the same kind of incident recurs because nothing structural changed.
- **Fix**: Blameless postmortem within a week; tracked action items; verify completion.
- → [Postmortems](system-failures/postmortems-and-incident-response.md)

### ❌ Blame-driven retrospectives

Engineer who pushed the change is targeted. Honest reporting dies; future incidents are obscured.
- **Fix**: Blameless culture, enforced from leadership. Focus on systems, not individuals.
- → [Postmortems](system-failures/postmortems-and-incident-response.md)

### ❌ Feature flags without TTLs or owners

Hundreds of stale flags accumulate. Code is full of dead branches. New engineers can't read it.
- **Fix**: TTL every release flag at creation. Periodic flag audits. Cleanup as discipline.
- → [Feature Flags](system-failures/feature-flags-and-progressive-delivery.md)

### ❌ Health checks pass, but service is broken

The check is alive (process running) but not ready (DB connection failed; cache cold). Load balancer sends traffic; users see errors.
- **Fix**: Distinguish liveness from readiness. Readiness probe should reflect actual ability to serve.
- → [Kubernetes Internals](scalability/kubernetes-internals.md), [Load Balancing](scalability/load-balancing-strategies.md)

### ❌ Restoring service before preserving evidence (security incident)

Wipe and rebuild without forensics. Investigation handicapped; can't determine scope; can't comply with disclosure.
- **Fix**: Preserve evidence (memory dumps, disk images, logs) before remediation. Then rebuild.
- → [Security Incident Response](system-failures/security-incident-response.md)

---

## Cross-Cutting

### ❌ "We'll add observability later"

Observability is a *design property*. Retrofitting it onto a system that doesn't have it is much harder than building it in.
- **Fix**: Observability from day one. Trace IDs in logs. Metrics on every service. SLOs defined.
- → [Metrics, Logs & Traces](observability/metrics-logs-traces.md)

### ❌ Optimizing without profiling

The bottleneck is rarely where intuition says. A week spent optimizing the wrong path doesn't help.
- **Fix**: Profile first. Read the flame graph. Optimize the wide bars, not the tall ones.
- → [Profiling & Flame Graphs](observability/profiling-and-flame-graphs.md)

### ❌ Trusting "it works in dev"

Dev has clean state, single user, no cache cold-start, no concurrent traffic, no clock skew, no network jitter, no GC pause coincidence. Production is none of these.
- **Fix**: Test in production-like environments. Chaos exercises. Load tests with realistic patterns.
- → [Chaos Engineering & Game Days](system-failures/chaos-engineering-and-game-days.md)

### ❌ Building for hypothetical future requirements

Premature abstraction; design for scale you may never reach; code that's flexible everywhere is rigid nowhere.
- **Fix**: Build for the requirements you have. Refactor when the third similar case appears, not the second.

### ❌ Believing the marketing

"Exactly-once delivery." "100% uptime." "Infinite scalability." "Solves CAP."
- **Fix**: Read the documentation. Read the postmortems. Run Jepsen tests (or read them). Understand the actual guarantees.
- → [CAP](distributed-systems/cap-consistency-and-replication.md), [Idempotency](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)

---

## How to Use This Checklist

In code review: scan for the patterns. Many of these fit a one-liner: "Default infinite timeout?" "Cache key uniqueness?" "Vacuum-blocking transaction?"

In design review: walk through the relevant sections. Architecture choices have classic mistakes; calling them out early prevents production discovery.

In postmortems: ask "did we make any of these?" Often the root cause is a textbook mistake, not a novel insight.

In learning: each item points to the artifact that explains *why* it's a mistake. The mistake is the symptom; the artifact is the diagnosis.
