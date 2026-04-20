# 🎯 Interview Mastery — Final Checklist

> Read this the night before a system design interview. It's the compressed version of everything in this repo.

---

## The 4-Stage Script (memorize this)

1. **Clarify** — scope, scale, consistency, latency. Write one sentence at the top of the whiteboard.
2. **Estimate** — DAU → QPS → storage → bandwidth. Out loud.
3. **High-level design** — client → edge → app → data. Justify each box.
4. **Deep dive** — on the component the interviewer picks (be ready for the one that dominates your scale).
5. **Non-functional wrap** — availability, consistency, monitoring, security, cost.

→ Full version: [`frameworks/thinking-framework.md`](frameworks/thinking-framework.md)

---

## The Concepts Check

For each, you should be able to define, draw, and defend in <2 min:

### Foundations
- [ ] IP, public vs private, NAT, IPv4 vs IPv6
- [ ] OSI model + "which layer is it?" debugging
- [ ] TCP handshake + UDP + when each wins
- [ ] DNS flow + caching + record types
- [ ] Forward vs reverse proxy

### Scaling
- [ ] Load balancer L4 vs L7 + algorithms + HA
- [ ] Cache (write-through/around/back), invalidation, stampede
- [ ] CDN, push vs pull, anycast
- [ ] Availability math (series vs parallel)
- [ ] Vertical vs horizontal scaling

### Data
- [ ] SQL vs NoSQL decision framework
- [ ] ACID + isolation levels
- [ ] Replication (primary-replica, lag, failover)
- [ ] Indexes (B-tree, left-most prefix, covering)
- [ ] CAP + PACELC classification
- [ ] Sharding strategies + consistent hashing
- [ ] Distributed transactions (2PC vs sagas)

### Architecture
- [ ] Monolith vs microservices tradeoffs
- [ ] Message queue vs pub-sub
- [ ] Event sourcing + CQRS
- [ ] API gateway's cross-cutting concerns
- [ ] REST vs GraphQL vs gRPC
- [ ] Long polling vs WebSocket vs SSE

### Reliability
- [ ] Rate limiting algorithms
- [ ] Circuit breaker state machine
- [ ] Service discovery
- [ ] SLA/SLO/SLI + error budget
- [ ] Disaster recovery (RTO, RPO)
- [ ] OAuth/OIDC + SSO + TLS/mTLS

---

## The Numbers to Know Cold

| Thing | Ballpark |
|---|---|
| RAM access | 100 ns |
| SSD access | 100 μs |
| HDD access | 10 ms |
| Intra-DC RTT | 0.5 ms |
| Cross-country RTT | 50 ms |
| Cross-ocean RTT | 200 ms |
| 1 year | 31.5 M seconds |
| 1 day | 86,400 seconds |
| Single DB node ceiling | 10k–100k QPS |
| 1 M QPS for a global LB | achievable with anycast + HA |
| p99 latency user "feel" threshold | <200 ms for interactive |

---

## Common Traps

- **Using 2PC in microservices** — use sagas.
- **Strong consistency everywhere** — decide per data type.
- **Adding cache without invalidation story** — worse than no cache for some data.
- **Jumping to microservices for 3-engineer teams** — monolith first.
- **Ignoring failure modes** — every box should be questioned.
- **Sticky sessions as default** — externalize state instead.
- **DNS failover as primary HA** — it's slow; use anycast / LB failover.
- **Round-robin for long-lived connections** — least-connections instead.

---

## Signature Phrases of a Senior

- "I picked X over Y because ___. If the requirements were ___ I'd pick Y."
- "Here's how I'd fail gracefully: ___"
- "My biggest risk is ___; here's how I'd mitigate."
- "Consistency-wise, I'll treat ___ as strongly consistent and ___ as eventually consistent because ___"
- "I'd instrument this with ___ and alert on ___"
- "If traffic 10×, the bottleneck becomes ___"

---

## The 24-Hour-Before Routine

- Read [`frameworks/thinking-framework.md`](frameworks/thinking-framework.md) in full.
- Read [`frameworks/request-lifecycle.md`](frameworks/request-lifecycle.md) — say it out loud.
- Do **one** case study end to end (URL shortener is shortest).
- Stop cramming. Sleep.

---

## After the Interview — Learning Loop

Whatever stumped you, come back and read that file. Add your own **Potential Gaps** section at the bottom. This repo is meant to grow with you.

Good luck. You're ready.
