# Testing Distributed Systems

> **📎 Prereqs** — If rusty:
> - [`distributed_consensus.md`](distributed_consensus.md) — what Jepsen tests.
> - [`database_replication.md`](database_replication.md) — failure modes to test for.
> - Unit vs integration test mental model.

### 🔹 1. What This Topic Actually Is
Beyond unit tests — how to verify concurrency, consistency, partition tolerance, and failure behavior of distributed systems.

### 🔹 2. Why It Exists
- Distributed systems fail in ways unit tests never cover.
- Famous real bugs in etcd, MongoDB, RabbitMQ, Kafka, Redis — all found via specialized testing.

### 🔹 3. Core Concepts (High Signal)
- **Deterministic simulation testing**: run the system with a controlled scheduler and fault injection; reproducible failures. FoundationDB, TigerBeetle.
- **Jepsen (Kyle Kingsbury / Aphyr)**: tool + methodology for testing distributed systems' real-world guarantees. Has found bugs in most popular DBs.
- **TLA+ (Leslie Lamport)**: formal specification language. Models behavior mathematically; checks invariants. Used at AWS, Microsoft for consensus protocols.
- **Chaos engineering (Netflix)**: Chaos Monkey, Simian Army — deliberately kill instances in prod to validate resilience.
- **Property-based testing**: generate random inputs + check invariants; QuickCheck lineage.
- **Fuzzing**: randomized input to find crashes/panics.
- **Load testing**: k6, Gatling, Locust — simulate real QPS.
- **Game days**: planned failure drills with on-call + engineering.

### 🔹 4. Internal Working (Jepsen-style run)
1. Bring up N nodes of the system under test.
2. Start client workload (generate ops with timestamps).
3. Induce partitions (iptables), clock skew, process kills.
4. Record all client observations.
5. After test, feed history into an **analyzer** (Knossos) that checks if the history is linearizable / eventually consistent / etc.
6. Report violations.

### 🔹 5. Key Tradeoffs
- Jepsen: catches real bugs, requires setup + manual analysis.
- TLA+: exhaustive proof but models, not actual code.
- Chaos engineering: tests prod but risks customer impact; use careful blast radius.
- Deterministic simulation: best for greenfield projects; hard to retrofit.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. What's chaos engineering?
2. Why aren't unit tests enough for distributed systems?

**Intermediate 🟡**
1. How does Jepsen verify linearizability?
2. What are game days?

**Advanced 🔴**
1. Design a chaos testing framework for a critical API platform.
2. Why does FoundationDB use deterministic simulation instead of Jepsen?

### 🔹 7. Real System Mapping
- **Netflix Chaos Monkey / ChAP / FIT**: production fault injection.
- **Jepsen reports** (jepsen.io) — required reading for serious distributed systems.
- **TLA+**: AWS uses for S3, DynamoDB, EBS; Microsoft for Cosmos; Oracle for distributed protocols.
- **FoundationDB / TigerBeetle**: deterministic simulation.
- **Gremlin**: commercial chaos platform.

### 🔹 8. What Most People Miss
- **Most "consistency" claims in vendor docs don't survive Jepsen**. Be skeptical.
- **Timing bugs require specific schedules** — deterministic simulation is the only way to reliably reproduce them.
- **Clock skew** is an underrated source of bugs (leap seconds, VM pauses).
- **Chaos monkey requires production maturity**: observability + automation first, or you just cause outages.
- **Formal specs prevent entire classes of design bugs** — the AWS S3 team reportedly finds 10+ latent issues during TLA+ specs.

### 🔹 9. 30-Second Revision
Unit tests insufficient. Jepsen injects partitions + checks history. TLA+ formalizes designs. Chaos Monkey validates prod. Deterministic simulation reproduces timing bugs. Invest once, pay dividends forever. Distributed systems without a testing strategy are time bombs.

---

## 🔗 Cross-Topic Connections
- **Consensus**: correctness is mathematical — TLA+ verifies, Jepsen tests.
- **Replication**: failover paths are where distributed bugs hide.
- **Observability**: required to even see what went wrong.
- **SRE**: game days drive maturity.

---

### Confidence Check
- [ ] Can I describe Jepsen's methodology?
- [ ] Can I articulate chaos engineering prerequisites?

### Gaps
- Hands-on TLA+ practice.
- Writing a deterministic simulator.
