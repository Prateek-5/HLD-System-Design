# Starter Cards

> One-screen TL;DR for every artifact in the knowledge base. Use as quick reference, interview prep, or to decide what to read next. Each card: 5 mental models + the final mental model + the one-sentence reason this topic matters.

---

## Database Internals

### MVCC & Isolation Levels
**Mental models:**
1. Time, not state — transactions read snapshots.
2. Versions are append-only; deletes are tombstones.
3. Visibility is computed from (version timestamps, snapshot, in-flight txids).
4. Isolation levels are contracts about anomalies, not magic.
5. Writers still need conflict resolution.

**Final:** *The database isn't a state — it's a log of versions, and a transaction is a viewing angle into that log.*

**Why it matters:** Foundation of modern OLTP concurrency. Explains why your reads don't block, why vacuum exists, why "Repeatable Read" means different things in different databases.

---

### Indexing & Storage Engines
**Mental models:**
1. Storage engine answers two questions: where is row X, what's near it.
2. Every index is a tax on writes.
3. Random vs sequential I/O is the hidden ruler.
4. Reads and writes are zero-sum at some layer.
5. The plan is a treasure map; the storage layout is the terrain.

**Final:** *An index is a deal: pay extra on writes, pay less on reads. The art is making that deal exactly where it pays off.*

**Why it matters:** Why B-tree vs LSM matters; why dropping unused indexes is high-leverage; why composite index column order is critical.

---

### WAL & Crash Recovery
**Mental models:**
1. Write-ahead means write *before*.
2. Commit is the moment the log entry is durable.
3. Recovery is replay.
4. Durability is fsync.
5. Group commit amortizes the cost.

**Final:** *A database is a physics-defying promise: 'committed means safe.' Underneath is a write-ahead log, an fsync, and discipline.*

**Why it matters:** Foundation of database durability; explains replication, CDC, recovery operations.

---

### Query Optimization & Execution Plans
**Mental models:**
1. Plan is a tree of physical operators.
2. The planner's job is to estimate cost.
3. Statistics are the planner's lens on reality.
4. Right operator depends on data shape.
5. Plan stability is desirable; optimality is not always.

**Final:** *A SQL query is a goal; the execution plan is the strategy. Most query performance problems are statistics problems wearing a costume.*

**Why it matters:** EXPLAIN-driven debugging; understanding plan flips; recognizing N+1 antipatterns.

---

### Replication Strategies
**Mental models:**
1. Sync vs async is the most important dimension.
2. Read replicas don't scale writes; they scale reads.
3. Lag is a first-class concern.
4. Failover is separate from replication.
5. Replication strategy determines consistency model.

**Final:** *Replication is the bridge between durability (one machine) and availability (many machines).*

**Why it matters:** HA design; failover planning; the data-loss window question.

---

### OLTP vs OLAP & Columnar Storage
**Mental models:**
1. Row-oriented = fast row access; columnar = fast column access.
2. OLTP = high-frequency small ops; OLAP = low-frequency large ops.
3. Disk pattern follows: random for OLTP, sequential for OLAP.
4. Compression is a columnar superpower.
5. Vectorization beats row-at-a-time.

**Final:** *Workload shape drives database design. Mismatching workload to system is one of the most expensive engineering mistakes.*

**Why it matters:** Why Snowflake exists alongside Postgres; why analytics on production OLTP is dangerous.

---

### Time-Series Databases
**Mental models:**
1. Time is the primary index.
2. Append-only writes.
3. Compression is dramatic (10-100×).
4. Aggregation matters; downsampling speeds queries.
5. Cardinality is the killer.

**Final:** *Time-series databases take the data's shape seriously. Storage 10-100× more efficient and queries 10-100× faster than generic alternatives.*

**Why it matters:** Monitoring infrastructure; IoT; observability backends.

---

## Distributed Systems

### CAP, Consistency Models & Replication
**Mental models:**
1. CAP applies during partitions; PACELC adds steady-state.
2. Consistency is a continuum, not binary.
3. Replication is copy; consensus is agreement.
4. Latency is the tax on consistency.
5. The clock problem is at the heart of everything.

**Final:** *Distributed systems are about applications making promises about state in a world where messages get lost. The promise is the consistency model.*

**Why it matters:** Foundation of all distributed-systems trade-offs.

---

### Leader Election & Consensus
**Mental models:**
1. Consensus is majority agreement.
2. Leader is a performance optimization.
3. Safety vs liveness.
4. The log is the consensus.
5. Membership changes need joint consensus.

**Final:** *Consensus is what computers do when humans aren't around to break ties. Every binding decision in a distributed system is either backed by consensus or quietly broken.*

**Why it matters:** etcd, ZooKeeper, distributed databases; understanding why odd cluster sizes matter.

---

### Clocks, Time & Ordering
**Mental models:**
1. There is no global time.
2. Causal ordering matters, not wall-clock.
3. Clocks have skew and can jump.
4. Different problems need different clocks.
5. Time is a coordination cost.

**Final:** *Time in a distributed system is a coordination protocol multiple machines run, with various levels of fidelity to physical reality.*

**Why it matters:** LWW conflict resolution; distributed snapshots; understanding HLC vs TrueTime vs Lamport.

---

### Gossip Protocols & Cluster Membership
**Mental models:**
1. Information spreads probabilistically.
2. Constant-time per node; log-time convergence.
3. Failure detection integrated.
4. Eventual consistency at cluster level.
5. Robust to failures.

**Final:** *Gossip is how information spreads when no one is in charge. The math scales decentrally; the practice runs Cassandra and Consul.*

**Why it matters:** Cluster membership at scale; understanding Cassandra, Consul.

---

### Distributed Transactions — 2PC, 3PC
**Mental models:**
1. 2PC has two phases: prepare and commit.
2. Coordinator is single point of failure (and blocking).
3. 3PC tries to fix blocking; introduces other issues.
4. Real-world 2PC is rare across services.
5. Alternatives are sagas and eventual consistency.

**Final:** *2PC is correct theory; problematic in practice. Modern systems use it carefully (Spanner) or replace it entirely (sagas).*

**Why it matters:** Why XA is an anti-pattern; why sagas exist; what Spanner does differently.

---

## Concurrency

### Locks, Mutexes & Lock-Free
**Mental models:**
1. A lock protects an invariant.
2. Lock granularity is a fundamental tradeoff.
3. Hardware reorders memory invisibly.
4. Lock-free ≠ wait-free ≠ fast.
5. Contention is the cost.

**Final:** *A lock is a confession that you're sharing mutable state. Every other technique is a way to confess less.*

**Why it matters:** Concurrency bug triage; understanding why "thread-safe" isn't the whole story.

---

### Backpressure & Queues
**Mental models:**
1. Every queue is a buffer between two rates.
2. Latency = service time + queueing time.
3. Backpressure is the inverse of buffering.
4. Failure must propagate upstream.
5. Queues hide problems until they don't.

**Final:** *Queues are time machines for work. Backpressure is the rule that says you cannot send infinite work into the future.*

**Why it matters:** The diagnostic frame for half of all production performance issues.

---

### The Actor Model & Message Passing
**Mental models:**
1. Each actor is single-threaded.
2. Communication is message passing.
3. State is encapsulated.
4. Failure is local, supervised, recoverable.
5. Location transparency.

**Final:** *Actors trade shared state for explicit messages. The bug categories shift; new code is usually easier to reason about.*

**Why it matters:** Erlang's nine-nines; why Discord's voice chat works.

---

### Parallelism vs Concurrency
**Mental models:**
1. Concurrency is structure; parallelism is execution.
2. Concurrency helps with I/O; parallelism with CPU.
3. GIL/event-loop is parallelism limit, not concurrency limit.
4. Amdahl's Law caps parallel speedup.
5. Coordination is the cost of parallelism.

**Final:** *Concurrency is how you structure code; parallelism is how it runs. Match the structure to the hardware.*

**Why it matters:** Distinguishing the two prevents wasted threading effort.

---

### Coroutines, Green Threads & Async Runtimes
**Mental models:**
1. Concurrent unit cost decreases up the stack.
2. Cooperative vs preemptive scheduling.
3. M:N scheduling is modern default.
4. Function coloring is real trade-off.
5. Where compute happens matters.

**Final:** *Modern concurrency is layered: cheap units in user space, multiplexed onto OS threads, scheduled by the runtime.*

**Why it matters:** Goroutines, virtual threads, Tokio; understanding the design space.

---

### Async Rust & the Borrow Checker
**Mental models:**
1. Future is a state machine the compiler builds.
2. Futures are lazy.
3. Polls happen on threads.
4. Borrow checker reaches into futures.
5. Pin is about not moving futures.

**Final:** *Async Rust is the most powerful and most demanding async runtime. Borrow checker, types, runtime conspire to ensure correctness.*

**Why it matters:** Production Rust at Discord, Cloudflare; understanding the learning curve.

---

### Go Runtime & Goroutines
**Mental models:**
1. Goroutines are M:N multiplexed onto OS threads.
2. Channels coordinate by communication.
3. Blocking I/O looks blocking but doesn't block the thread.
4. Goroutines are cheap.
5. Scheduler uses work-stealing.

**Final:** *Go's runtime is what made cheap concurrent units production-ready at scale.*

**Why it matters:** Why Go works for concurrency; the GMP scheduler.

---

### JVM Internals & Virtual Threads
**Mental models:**
1. JVM = bytecode + interpreter + JIT + GC + threading.
2. JIT compilation tiers escalate.
3. Garbage collection is configurable.
4. Virtual threads change cost model of threads.
5. JVM is highly observable.

**Final:** *The JVM is one of the most sophisticated production runtimes ever built. Loom belatedly brings async-runtime efficiency to its blocking-thread programming model.*

**Why it matters:** Java's longevity; Project Loom; tuning at scale.

---

### Python Runtime & the GIL
**Mental models:**
1. GIL serializes Python bytecode.
2. C extensions can release the GIL.
3. I/O = threading helps; CPU = it doesn't.
4. Multi-process for true parallelism.
5. asyncio is single-threaded concurrency.

**Final:** *Python's GIL is a constraint that shaped the language's architecture. Library ecosystem and patterns developed around it.*

**Why it matters:** Why Python threading often disappoints; multiprocessing vs asyncio choices.

---

### CPU Caches & False Sharing
**Mental models:**
1. Memory access is not uniform.
2. Cache lines are the unit of transfer.
3. Coherence has a cost.
4. False sharing is silent.
5. NUMA adds another dimension.

**Final:** *The CPU's cache hierarchy is the silicon-level reality. False sharing, NUMA effects — these are the everyday performance reality at scale.*

**Why it matters:** Multi-core scaling; why padding sometimes 10×s performance.

---

## JS Runtime

### The Event Loop & Async Runtime
**Mental models:**
1. Event loop is a scheduler with single execution slot.
2. JS is single-threaded; runtime is not.
3. There is no preemption.
4. Microtasks ≠ macrotasks.
5. Phases (in Node).

**Final:** *The event loop is a deal: give up preemption, get cheap concurrency. Honor by yielding often.*

**Why it matters:** Foundation of Node.js scaling and quirks.

---

### V8 Internals & Hidden Classes
**Mental models:**
1. JS is dynamic at language level, monomorphic in practice.
2. Hidden classes make property access fast.
3. Inline caches make repeated operations fast.
4. Optimization is speculative; deoptimization is mandatory.
5. Memory is generational.

**Final:** *V8 is a contract: stable types and shapes for fast code; chaos for slow.*

**Why it matters:** Performance tuning; why object shape matters; deopt diagnosis.

---

### Node.js Architecture & libuv
**Mental models:**
1. JS runs on one thread; libuv runs many.
2. The event loop is libuv's, not V8's.
3. Phases matter.
4. Thread pool is small by default.
5. CPU-bound work blocks the loop.

**Final:** *Node is the architectural decision to take a fast single-threaded language and pair it with a library that knows how to wait efficiently on every OS.*

**Why it matters:** UV_THREADPOOL_SIZE; DNS bottleneck; CPU-work-via-workers.

---

### Streams & Backpressure in Node
**Mental models:**
1. Streams are time-ordered data, not space-bounded.
2. Backpressure is automatic with proper APIs.
3. Four stream types: Readable/Writable/Duplex/Transform.
4. Modes matter.
5. Errors must be handled at every stage.

**Final:** *Streams are Node's answer to "data is bigger than memory." Backpressure is the discipline that makes streams safe.*

**Why it matters:** File processing, HTTP bodies, pipelines.

---

### Web Workers, Worker Threads & Shared Memory
**Mental models:**
1. Each worker is a separate execution context.
2. Communication is structured cloning.
3. Transferable objects move ownership.
4. Workers add parallelism, not concurrency.
5. Shared memory is a sharp tool.

**Final:** *JavaScript's controlled retreat from single-threaded simplicity. Most simplicity preserved; performance for the cases that need it.*

**Why it matters:** Browser CPU work; Node worker_threads for compute.

---

### Garbage Collection & Memory Management
**Mental models:**
1. Weak generational hypothesis.
2. Pause vs throughput is central tradeoff.
3. Allocation rate matters as much as live size.
4. GC tuning is application-specific.
5. GC is not a black box.

**Final:** *GC trades programmer-time for runtime-time. Modern GCs are excellent — when configured for the workload.*

**Why it matters:** Tail latency; reducing allocations; algorithm choice.

---

## Networking

### TCP & Network Fundamentals
**Mental models:**
1. TCP turns packets into streams.
2. Connection establishment costs RTT.
3. Congestion control is fairness.
4. Flow control is per-connection.
5. Connection state machines are subtle.

**Final:** *TCP is the most successful piece of distributed-systems engineering ever shipped.*

**Why it matters:** Connection-pool exhaustion; latency mysteries; tuning at scale.

---

### HTTP/2, HTTP/3 & QUIC
**Mental models:**
1. HTTP/1.1 is one-request-at-a-time per connection.
2. HTTP/2 multiplexes streams over one TCP.
3. HTTP/2 still has TCP head-of-line.
4. HTTP/3 = HTTP over QUIC.
5. Improvements compound.

**Final:** *HTTP's evolution is the web's optimization story: each version removed inefficiencies that mattered at scale.*

**Why it matters:** Modern web performance; QUIC adoption; mobile-network gains.

---

### DNS Deep Dive
**Mental models:**
1. DNS is a hierarchical tree.
2. Caching is everywhere.
3. Authority is delegated.
4. TTL trade-offs are operational.
5. Most DNS issues are caching issues.

**Final:** *DNS is the most foundational layer most engineers don't think about — and the layer that, when it fails, takes down everything.*

**Why it matters:** Failover speed; cache propagation; debugging "down for some users."

---

### WebSockets & Real-Time Protocols
**Mental models:**
1. WebSocket = persistent bidirectional channel.
2. SSE = server-to-client stream.
3. Connections cost memory.
4. Scaling persistent connections is different.
5. Reconnection is normal.

**Final:** *Real-time protocols turn the web's request-response into bidirectional flows. New operational concerns are real and different.*

**Why it matters:** Chat, live updates, multiplayer; scaling persistent connections.

---

### TLS & Mutual TLS
**Mental models:**
1. TLS does encryption + auth + integrity.
2. Handshake establishes shared secrets.
3. Certificates anchor identity.
4. mTLS authenticates both ends.
5. TLS 1.3 is the modern baseline.

**Final:** *TLS is the cryptographic plumbing every secure connection runs through. Operational discipline (cert management, version policy) is what separates secure deployments from waiting-for-expiry incidents.*

**Why it matters:** HTTPS; service mesh mTLS; cert lifecycle.

---

## Observability

### Metrics, Logs & Traces
**Mental models:**
1. Observability is a property of the system, not tools.
2. The three pillars have different cost models.
3. Cardinality is unit of cost and value.
4. SLOs are contract; SLIs are measurement.
5. Most production debugging is "what is this customer's request doing?"

**Final:** *Observability is the discipline of making your system explain itself.*

**Why it matters:** Foundation for all of operations.

---

### Distributed Tracing — A Deep Dive
**Mental models:**
1. A trace is a tree.
2. Context propagation is the entire game.
3. Sampling is cost-vs-completeness.
4. Traces, logs, metrics are three views.
5. The point is debugging.

**Final:** *A trace is a single request's story, told across every service it touched. Without it, microservices debugging is mythology.*

**Why it matters:** Cross-service debugging; why context propagation is mandatory.

---

### SLOs, Error Budgets & Alerting
**Mental models:**
1. SLO = contract; SLI = measurement.
2. Error budget makes reliability tradeable.
3. Page on user-facing impact; ticket on internal symptoms.
4. Alerting on burn rate beats alerting on threshold.
5. SLOs evolve.

**Final:** *SLOs turn reliability from a religion into engineering. The error budget is the unit of trade between reliability and velocity.*

**Why it matters:** Operational maturity; aligning velocity and reliability.

---

### Cardinality & the Economics of Monitoring
**Mental models:**
1. Cardinality is the cost driver.
2. Cardinality is also the value driver.
3. Different signals have different cost models.
4. Pre-aggregation cheap; raw events powerful.
5. Sampling is mandatory at scale.

**Final:** *Observability is a budgeted resource. Every label, every log line, every span costs money.*

**Why it matters:** Budget surprises; cardinality bombs.

---

### Profiling & Flame Graphs
**Mental models:**
1. Sampling beats instrumentation for production.
2. Time on CPU ≠ time on the wall.
3. Flame graphs are read width-first.
4. Aggregation matters.
5. Profile reflects the workload.

**Final:** *Profiling closes the gap between intuition and reality.*

**Why it matters:** Performance diagnosis; where time actually goes.

---

## Scalability

### Sharding & Partitioning Strategies
**Mental models:**
1. Partition key is contract with your queries.
2. Hot keys are the death of partitioning.
3. Rebalancing is the operation you didn't plan for.
4. Cross-shard queries are second-class.
5. Right partitioning makes system look like N independent.

**Final:** *Partitioning is what happens when your data outgrows your machine. The partition key is the most consequential decision.*

**Why it matters:** Schema design; scaling beyond single node.

---

### Load Balancing Strategies
**Mental models:**
1. Load balancing happens at multiple layers.
2. Right algorithm depends on workload.
3. Health checks determine availability.
4. Slow is worse than down.
5. Connection state shapes strategy.

**Final:** *A load balancer is a continuous decision-making process about where work should go.*

**Why it matters:** Smart routing; health-check design; sticky-session decisions.

---

### Auto-Scaling & Capacity Planning
**Mental models:**
1. Auto-scaling is reactive; capacity planning is proactive.
2. Scaling has limits.
3. The bottleneck moves.
4. Saturation, not utilization, is the right signal.
5. Cost optimization is the dual.

**Final:** *Capacity planning is engineering for the load you expect. Auto-scaling is engineering for the load you didn't expect.*

**Why it matters:** Avoiding launch-day disasters; cost control.

---

### Edge Computing & CDNs
**Mental models:**
1. Latency is bounded by light speed.
2. Edge is geographically distributed.
3. Edge runtimes are constrained.
4. Caching is the basic edge primitive.
5. State at the edge is hard.

**Final:** *Edge computing is geography weaponized for latency. The constraints are the price of being everywhere.*

**Why it matters:** Cloudflare Workers; CDN cache strategies; global latency.

---

### Multi-Tenancy Strategies
**Mental models:**
1. Multi-tenancy is a continuum.
2. Blast radius is unit of isolation.
3. Isolation has costs.
4. Tenant identity propagates everywhere.
5. Tenants vary wildly.

**Final:** *Multi-tenancy is the architecture under every SaaS. The strategy determines how customers experience your service.*

**Why it matters:** SaaS architecture; tenant isolation; compliance.

---

### Kubernetes Internals
**Mental models:**
1. Declarative state, eventual consistency.
2. Control plane is etcd + API server + controllers.
3. Pods are the unit of scheduling.
4. Services abstract pods.
5. Everything is an API resource.

**Final:** *Kubernetes is what running containers at production scale looks like — declarative, eventual consistency, control loops.*

**Why it matters:** Cloud-native deployment; understanding K8s troubleshooting.

---

## System Failures

### Cascading Failures & Circuit Breakers
**Mental models:**
1. Coupling is the fault line cascades spread along.
2. Failure modes are not symmetric (slow > failed).
3. Retries amplify; backoff dampens.
4. Bulkheads contain damage.
5. Graceful degradation > heroic recovery.

**Final:** *Reliability isn't preventing failures. It's bounding their blast radius.*

**Why it matters:** Why services fall over together; circuit-breaker design.

---

### Timeouts, Retries & Idempotency
**Mental models:**
1. Every external call has three outcomes (success, fail, unknown).
2. Timeouts must decrease from outer to inner.
3. Retries amplify load.
4. Idempotency is precondition for retry.
5. End-to-end idempotency is hard.

**Final:** *The triple is the engineering vocabulary for handling network fact: you cannot tell success-with-lost-response from failure.*

**Why it matters:** Foundation contract for distributed calls.

---

### Chaos Engineering & Game Days
**Mental models:**
1. Failures are routine.
2. The bug is in the assumption.
3. Test in production with safety.
4. Game days test the team.
5. Hypothesis-driven, not random.

**Final:** *Reliability is not designed; it's discovered.*

**Why it matters:** Proving resilience; catching what tests miss.

---

### Postmortems & Incident Response
**Mental models:**
1. Incidents have phases; roles change.
2. First job is mitigation.
3. Blameless ≠ accountability-free.
4. Postmortem is about systems, not people.
5. Action items are the only durable output.

**Final:** *An outage is a teacher. The team that listens gets better; the team that doesn't has the same outage forever.*

**Why it matters:** Operational learning; turning incidents into improvements.

---

### Disaster Recovery, RTO & RPO
**Mental models:**
1. RTO/RPO are business decisions.
2. Untested backups don't work.
3. DR is broader than backups.
4. The disaster you'll have isn't the one you planned for.
5. Cost scales with target tightness.

**Final:** *DR is the discipline of being prepared for events you hope never happen.*

**Why it matters:** Catastrophic-failure planning; backup strategy.

---

### Feature Flags & Progressive Delivery
**Mental models:**
1. Deploy ≠ release.
2. Unit of risk is the user cohort.
3. Flags have lifecycles.
4. Flags are configuration, not code.
5. Goal is reducing blast radius.

**Final:** *Feature flags decouple risk from deploy. Mean-time-to-recover collapses from hours to seconds.*

**Why it matters:** Safe deploys; canary releases; emergency kill switches.

---

### Security Incident Response
**Mental models:**
1. Security IR has phases distinct from operational.
2. The attacker may be watching.
3. Evidence matters.
4. Containment ≠ eradication.
5. Disclosure has timelines.

**Final:** *Security incidents are operational incidents in a hostile environment.*

**Why it matters:** Breach response; regulatory compliance; ransomware.

---

## Architecture Patterns

### Microservices vs Monolith
**Mental models:**
1. Conway's Law is destiny.
2. Cost of microservices is mostly operational.
3. Service boundaries follow domain.
4. Small services don't always = simpler systems.
5. Right granularity isn't "as small as possible."

**Final:** *No architecture is better than another in a vacuum. Only architecture that fits.*

**Why it matters:** Architecture decisions; avoiding distributed monoliths.

---

### Sagas & Distributed Transactions
**Mental models:**
1. Atomicity bought with coordination.
2. Compensation is not rollback.
3. Idempotency is prerequisite.
4. Saga steps commit local state immediately.
5. Failure is normal.

**Final:** *Sagas are the engineering work of telling the truth: "things happen in steps; sometimes steps fail; here's how we recover."*

**Why it matters:** Cross-service workflows; replacing 2PC.

---

### CQRS & Event Sourcing
**Mental models:**
1. State is a function of events.
2. Commands ≠ events.
3. Reads and writes have different shapes.
4. Eventual consistency between command and query.
5. Events are forever.

**Final:** *Event sourcing is what you do when you take seriously that state is a story, not a snapshot.*

**Why it matters:** Audit-heavy domains; financial systems; complex state evolution.

---

### API Design — REST vs gRPC vs GraphQL
**Mental models:**
1. APIs are contracts, not implementations.
2. Backward compatibility is most expensive feature.
3. Latency budgets shape protocol.
4. Discoverability vs efficiency is central tradeoff.
5. Protocol doesn't solve evolution; design does.

**Final:** *Pick the protocol for the boundary, not for the company. Public APIs need discoverability; internal services need efficiency.*

**Why it matters:** Protocol choice; versioning; idempotency.

---

### Strangler Fig & Legacy Migration
**Mental models:**
1. Legacy system is alive; treat it that way.
2. Migrations are routes, not blocks.
3. There is no "switchover day."
4. Old system survives until empty.
5. Migration is decommissioning, not building.

**Final:** *Migration is the discipline of replacing a system that's still running.*

**Why it matters:** Avoiding big-rewrite disasters.

---

### Event-Driven Architecture
**Mental models:**
1. Events are facts about the past.
2. Producers and consumers are decoupled.
3. Temporal decoupling.
4. Eventual consistency is default.
5. Order matters per partition; not globally.

**Final:** *Event-driven architecture is loose coupling realized through asynchronous facts.*

**Why it matters:** Modern reactive systems.

---

### Idempotency Receivers & "Exactly-Once" Semantics
**Mental models:**
1. At-least-once + idempotent = effectively-once.
2. Idempotency is end-to-end.
3. Exactly-once delivery is impossible.
4. Idempotency keys must be unique per logical op.
5. Dedup window matters.

**Final:** *The network gives you at-least-once. Your application, with discipline, gives you effectively-once.*

**Why it matters:** Payment systems; retry-safe APIs.

---

### Anti-Corruption Layer & Domain-Driven Design
**Mental models:**
1. Same word can mean different things in different contexts.
2. Bounded contexts have own vocabulary.
3. Aggregates are consistency boundaries.
4. ACL is translation.
5. Domain events are first-class.

**Final:** *DDD says the hard problem is not technology — it's modeling the business correctly.*

**Why it matters:** System architecture; integration; bounded contexts.

---

### LLM Serving & Vector Databases
**Mental models:**
1. LLM inference is GPU-bound, latency-variable, expensive.
2. Vector embeddings represent meaning numerically.
3. Token-by-token generation is dominant.
4. Context windows are limited.
5. Cost per query matters.

**Final:** *LLM serving and vector databases are the AI era's new infrastructure layer.*

**Why it matters:** RAG; modern AI applications; cost economics.

---

### Kafka Internals & Stream Processing
**Mental models:**
1. The log is primary abstraction.
2. Partitions enable parallelism.
3. Consumers track own offsets.
4. Replication for durability.
5. Retention is configurable.

**Final:** *Kafka is what happens when 'the log is the database' is taken as architectural truth.*

**Why it matters:** Event-driven substrate; CDC; stream processing.

---

## Caching

### The Caching Hierarchy
**Mental models:**
1. A cache is a deal: faster read, possibly stale.
2. Hit rate is everything.
3. Three meaningful patterns: cache-aside, read-through, write-through/behind.
4. Invalidation is a distributed-systems problem.
5. Cost of staleness varies wildly.

**Final:** *Caching is the answer when "how do I make this faster?" but always comes with a hidden invoice for staleness.*

**Why it matters:** Performance everywhere; cache invalidation pitfalls.
