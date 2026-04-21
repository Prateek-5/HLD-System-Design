# 📚 Interview-Ready Notes — Master Index

> These notes compress the InterviewReady system-design-resources list into high-signal, interview-focused summaries. Each file ~100–200 lines.

## Read order (if you have 1 week)

### Day 0 — scaffolding
- [`00_quick_revision.md`](00_quick_revision.md) — the whole field in 2–3 pages
- [`01_interview_patterns.md`](01_interview_patterns.md) — the 10 patterns behind 80% of questions
- [`02_quiz.md`](02_quiz.md) — 60-question rapid-fire self-test (use after each day to verify)

### Day 1 — the big 3
- [`load_balancing.md`](load_balancing.md)
- [`caching.md`](caching.md)
- [`databases.md`](databases.md)

### Day 2 — database internals
- [`database_replication.md`](database_replication.md)
- [`nosql_internals.md`](nosql_internals.md) — LSM, SSTables, compaction
- [`time_series_databases.md`](time_series_databases.md)

### Day 3 — messaging & async
- [`message_queues_and_pubsub.md`](message_queues_and_pubsub.md)
- [`event_driven_architecture.md`](event_driven_architecture.md)
- [`stream_and_batch_processing.md`](stream_and_batch_processing.md)
- [`distributed_transactions.md`](distributed_transactions.md) — sagas, outbox, 2PC

### Day 4 — reliability
- [`rate_limiting.md`](rate_limiting.md)
- [`distributed_consensus.md`](distributed_consensus.md) — Paxos, Raft
- [`single_point_of_failure.md`](single_point_of_failure.md)
- [`observability_logging_alerts.md`](observability_logging_alerts.md)
- [`testing_distributed_systems.md`](testing_distributed_systems.md)

### Day 5 — architecture
- [`microservices.md`](microservices.md) — + hexagonal, clean, DDD
- [`service_mesh.md`](service_mesh.md)
- [`containers_docker.md`](containers_docker.md)
- [`cluster_and_workflow_management.md`](cluster_and_workflow_management.md)

### Day 6 — delivery + storage
- [`cdn.md`](cdn.md)
- [`distributed_file_system.md`](distributed_file_system.md)
- [`network_protocols.md`](network_protocols.md)
- [`api_design.md`](api_design.md)

### Day 7 — specialized + practice
- [`redis.md`](redis.md)
- [`location_based_services.md`](location_based_services.md)
- [`search_engine.md`](search_engine.md)
- [`video_processing.md`](video_processing.md)
- [`google_docs_collaboration.md`](google_docs_collaboration.md)
- [`authorization.md`](authorization.md)
- [`capacity_estimation.md`](capacity_estimation.md)

### Interview night
- Re-read [`00_quick_revision.md`](00_quick_revision.md).
- Re-read [`01_interview_patterns.md`](01_interview_patterns.md).
- Run `capacity_estimation.md` template out loud once.

---

## How these files are structured
Each topic file has:
1. What this topic actually is (2–3 lines)
2. Why it exists
3. Core concepts (bullets, high signal)
4. Internal working (condensed)
5. Tradeoffs
6. Interview questions (2 beginner, 2 intermediate, 2 advanced)
7. Real system mapping (Netflix, Uber, etc.)
8. What most people miss
9. 30-second revision block
10. Cross-topic connections
11. Confidence check + gaps

---

## Mapping back to the resource list

| Source topic (InterviewReady) | Notes file |
|---|---|
| Load Balancing | [load_balancing.md](load_balancing.md) |
| Caching | [caching.md](caching.md) |
| NoSQL Internals + Algorithms | [nosql_internals.md](nosql_internals.md) |
| Database Replication | [database_replication.md](database_replication.md) |
| Intra-Service Messaging + Pub-Sub + Antipatterns | [message_queues_and_pubsub.md](message_queues_and_pubsub.md) |
| Rate Limiting + Circuit Breaker | [rate_limiting.md](rate_limiting.md) |
| Distributed Consensus | [distributed_consensus.md](distributed_consensus.md) |
| Distributed Transactions Consistency | [distributed_transactions.md](distributed_transactions.md) |
| Capacity Estimation | [capacity_estimation.md](capacity_estimation.md) |
| Event Driven Architectures | [event_driven_architecture.md](event_driven_architecture.md) |
| Software Architectures + Microservices | [microservices.md](microservices.md) |
| Service Mesh | [service_mesh.md](service_mesh.md) |
| Content Delivery Network | [cdn.md](cdn.md) |
| Single Point of Failure | [single_point_of_failure.md](single_point_of_failure.md) |
| Location Based Services | [location_based_services.md](location_based_services.md) |
| Batch + Real Time Stream Processing | [stream_and_batch_processing.md](stream_and_batch_processing.md) |
| Time Series Databases | [time_series_databases.md](time_series_databases.md) |
| In Memory Database - Redis | [redis.md](redis.md) |
| Network Protocols | [network_protocols.md](network_protocols.md) |
| Video Processing | [video_processing.md](video_processing.md) |
| Google Docs | [google_docs_collaboration.md](google_docs_collaboration.md) |
| Alerts/Anomaly Detection + Distributed Logging + Metrics & Search | [observability_logging_alerts.md](observability_logging_alerts.md), [search_engine.md](search_engine.md) |
| Containers and Docker | [containers_docker.md](containers_docker.md) |
| Cluster and Workflow Management | [cluster_and_workflow_management.md](cluster_and_workflow_management.md) |
| Distributed File System | [distributed_file_system.md](distributed_file_system.md) |
| Authorization | [authorization.md](authorization.md) |
| API Design | [api_design.md](api_design.md) |
| Testing Distributed Systems | [testing_distributed_systems.md](testing_distributed_systems.md) |

### Omitted (low ROI for interviews)
- *Chess Engine Design* — domain-specific, rarely asked; principles covered under event sourcing + state machines.
- *Subscription Management* — specific product pattern; apply sagas + state machines.

---

## Cross-index with the `learn/` layered curriculum
If you also have the `learn/` system in this repo, these notes are the **compressed interview-prep layer** on top of the detailed topic files there. Use `notes/` for last-mile prep, `learn/` for deep study.
