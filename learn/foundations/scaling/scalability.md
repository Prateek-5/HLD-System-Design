# Scalability — Vertical vs Horizontal, and When Each Breaks

## A. Intuition First
Scalability = "how well does this system respond when we need to handle 10× or 100× more load?" You want load to rise; you want cost and complexity to rise less than linearly.

**Why it matters**: if your system can only scale by rewriting itself, you've already lost.

## B. Mental Model
Two levers:
- **Vertical (scale up)** — bigger box: more CPU, RAM, disk.
- **Horizontal (scale out)** — more boxes.

Both have ceilings and costs. Real systems do both.

## C. Internal Working

### Vertical scaling
- Shut down, upgrade the machine, restart. (Or hot-upgrade, rarely smooth.)
- Works until you hit hardware limits or the $ curve goes vertical (2× RAM often 4× price).
- One machine = one failure domain = SPOF until paired with HA.

### Horizontal scaling
- Add machines, distribute work.
- Requires the app to be **stateless** or for state to be externalized (DB, cache, session store).
- Scaling the stateless tier is easy; scaling stateful tier (DB) is the real work: replication, sharding, consistent hashing.

### Autoscaling
- Trigger on metrics (CPU > 70%, request queue > N, p99 latency).
- Cooldown windows to prevent flapping.
- Scale-out is fast (minutes); scale-in is conservative (drain connections, wait).

## D. Visual Representation
```
Vertical:      Horizontal:
[  HUGE  ]    [S][S][S][S][S]
  ↑ limit      ↑ near-linear until
                 the shared tier (DB) bottlenecks
```

## E. Tradeoffs
| Axis | Vertical | Horizontal |
|---|---|---|
| Simplicity | Easy (same app) | Harder (must be stateless) |
| Cost curve | Exponential | Roughly linear |
| Ceiling | Hardware limit | Theoretically unlimited (in practice, shared-tier bottleneck) |
| Fault tolerance | SPOF | Natural redundancy |
| Data consistency | Trivial | Hard (see CAP) |

## F. Interview Lens
- "How do you scale from 1k to 1M users?" — work through each tier (web → app → DB → cache → async).
- "Why is stateless important?" — so you can scale horizontally.
- "What's the bottleneck when scaling horizontally?" — usually the shared DB tier.
- Pitfalls: treating scaling as a knob rather than understanding *which tier* is actually bottlenecked.

## G. Real-World Mapping
- **Web/app tier**: horizontal, trivial once stateless.
- **Relational DB**: vertical first, then replication, then shard.
- **NoSQL**: designed for horizontal (Cassandra, DynamoDB).
- **Object storage (S3)**: effectively infinite horizontal scale.

## H. Questions
**Beginner**: Vertical vs horizontal? Stateless vs stateful?
**Intermediate**:
1. How do you make a web tier horizontally scalable?
2. Why is a SQL DB harder to scale out than a stateless web server?
**Advanced**:
1. Scale a single-box monolith to 1M QPS. What steps?
2. At what scale do read replicas stop helping? What's next?

## I. Mini Design — "Scale a photo upload service"
- Stateless upload handler: horizontal.
- Storage: S3 / object storage (infinite horizontal).
- Metadata DB: start vertical (RDS), then read replicas, then shard by user_id hash at scale.
- Image processing: async queue + worker fleet, horizontal.
- CDN for delivery: horizontal by design.

## J. Cross-Topic Connections
- [Sharding](../../data/sharding.md) — horizontal scale for DBs.
- [Consistent Hashing](../../data/consistent-hashing.md) — distribute work.
- [Load Balancing](load-balancing.md) — horizontal scale's entry point.
- [Caching](caching.md) — cheap way to scale reads without adding servers.

## K. Confidence Checklist
- [ ] I can explain when vertical is the right choice.
- [ ] I can identify the stateful vs stateless tiers in a stack.
- [ ] I know autoscaling triggers and cooldowns.
- [ ] I can identify the bottleneck tier.

### Red flags
- ❌ "Just scale horizontally" — ignores that state is hard.
- ❌ Treating scaling as one decision instead of per-tier.

## L. Potential Gaps & Improvements
- Amdahl's law for scalability limits (serial portion caps parallelism).
- Stateful services (DB, cache) scaling techniques deserve a dedicated read.
- Cost modeling: "how many $ per 1000 QPS?" — not covered.
