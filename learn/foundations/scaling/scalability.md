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
- **Amdahl's Law** — a formula showing the serial (non-parallel) fraction of work caps your maximum speedup no matter how many machines you add; explains why scaling out eventually stops paying off.
- **USL (Universal Scalability Law)** — extends Amdahl by adding a "crosstalk/coordination" penalty, so throughput can actually *drop* past some node count; the math behind "why did adding servers make it slower?"
- **Stateful service scaling (DB, cache)** — techniques like replication, sharding, and consistent hashing for the tiers that hold data; this is the hard part of horizontal scaling and deserves a dedicated read (→ see Interview Lens).
- **Cost modeling ($/1000 QPS)** — putting a dollar figure on each tier per thousand Queries Per Second so you can compare scale-up vs scale-out economically; the question interviewers love but learners rarely practice.
- **Connection draining** — gracefully finishing in-flight requests before removing a node during scale-in, so users don't see dropped connections; key to safe autoscaling.
- **p99 latency** — the response time the slowest 1% of requests still beat; a far better autoscaling trigger than average latency because it catches tail-latency pain.

**🔧 How to close:** Spin up a tiny stateless web app and put a load test on it to *feel* the bottleneck. Run `docker run --rm -p 8080:80 nginxdemos/hello`, then in another terminal install hey (`go install github.com/rakyll/hey@latest` or `brew install hey`) and fire `hey -z 30s -c 200 http://localhost:8080/` — watch the p99 latency in the output, then run a second container on port 8081 and split traffic to see throughput rise roughly linearly until your laptop's CPU (the shared bottleneck) caps it.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 📈 Gap 1 — Amdahl's Law & the Universal Scalability Law (USL)
- 🔹 **What it is**: Two formulas that predict how much faster a system gets as you add machines — Amdahl caps speedup by the serial fraction; USL adds a coordination penalty so throughput can actually *drop* past some node count.
- 🔹 **Why it matters**: They explain *why* the "roughly linear" curve in this file's Tradeoffs table flattens and then bends down — adding servers is not free and not infinite.
- 🔹 **Connection**: This file says horizontal scale is "near-linear until the shared tier bottlenecks." Amdahl/USL put math on exactly that flattening, including the crosstalk cost between nodes.
- 🔹 **When needed**: 🟡 **Mid-level** — useful once you can reason about tiers and want to defend a number, not just a direction.
- 🔹 **Intuition**: A road crew of 10 fills potholes 10× faster, but if every worker must check with one foreman before each pothole, the foreman becomes a queue — eventually a 20th worker just adds chatter and slows everyone.
- 🔹 **If you go deeper**: Read Neil Gunther's *Guerrilla Capacity Planning* (the USL); pair it with the original Amdahl 1967 paper. Fit a USL curve to load-test data with the `usl` R package or Python `usl` library.
- 🔹 **Interview hook**: *"You added 50% more servers and got only 10% more throughput — why?"* → past the knee of the USL curve, coordination/contention overhead outweighs added parallelism.

---

#### 🗄️ Gap 2 — Scaling the Stateful Tier (replication, sharding, consistent hashing)
- 🔹 **What it is**: The techniques for scaling the tiers that hold data — read replicas, partitioning rows across shards, and consistent hashing to spread keys with minimal reshuffling when nodes change.
- 🔹 **Why it matters**: The stateless web tier is the easy 20%; the database is where "just add a box" stops working, and it's the bottleneck this whole file keeps pointing at.
- 🔹 **Connection**: The Internal Working section calls scaling the stateful tier "the real work," and the Mini Design shards metadata by `user_id` hash — this gap is that work spelled out.
- 🔹 **When needed**: 🟢 **Foundational** — every system-design interview touches database scaling; reachable as soon as the basics here are solid.
- 🔹 **Intuition**: A library that outgrows one building: first photocopy popular books to reading rooms (replicas), then split the collection A–M / N–Z across two buildings (sharding), then use a card system so adding a third building only moves a slice of books, not all of them (consistent hashing).
- 🔹 **If you go deeper**: Read the [Sharding](../../data/sharding.md) and [Consistent Hashing](../../data/consistent-hashing.md) notes, then the DynamoDB paper (2007) for consistent hashing in production. → see Cross-Topic Connections.
- 🔹 **Interview hook**: *"At what scale do read replicas stop helping, and what's next?"* → when writes (not reads) saturate the primary; next step is sharding to split the write load.

---

#### 🎚️ Gap 3 — p99 Latency & Connection Draining for Safe Autoscaling
- 🔹 **What it is**: Two operational details — using p99 (the time the slowest 1% of requests still beat) as the scaling trigger instead of average, and connection draining (letting in-flight requests finish before a node is removed during scale-in).
- 🔹 **Why it matters**: Averages hide tail-latency pain that real users feel, and yanking a node mid-request drops connections — both turn "autoscaling works" into "autoscaling caused an outage."
- 🔹 **Connection**: The Autoscaling section lists `p99 latency` as a trigger and says scale-in must "drain connections, wait" — this gap explains why both choices matter.
- 🔹 **When needed**: 🟢 **Foundational** — anyone running a service behind a load balancer hits this early.
- 🔹 **Intuition**: A restaurant judged by its *slowest* tables, not the average table — and you never flip the chairs up while a party is still eating (drain first, then close the section).
- 🔹 **If you go deeper**: Read Google's "The Tail at Scale" (Dean & Barroso, 2013); configure `deregistration_delay` on an AWS ALB target group, or `terminationGracePeriodSeconds` + a `preStop` hook in Kubernetes.
- 🔹 **Interview hook**: *"Why trigger autoscaling on p99 instead of average latency?"* → average masks the long tail; p99 catches the pain a small fraction of users actually experience.

---

#### 💲 Gap 4 — Cost Modeling ($ per 1000 QPS)
- 🔹 **What it is**: Attaching a dollar figure to each tier per thousand Queries Per Second (QPS), so scale-up vs scale-out becomes an economic comparison, not just a technical one.
- 🔹 **Why it matters**: The vertical cost curve is exponential and horizontal is roughly linear — but the crossover point is a number, and interviewers love asking you to estimate it.
- 🔹 **Connection**: The Tradeoffs table claims vertical cost is "exponential" and horizontal is "roughly linear" — cost modeling is how you turn that hand-wave into a defensible decision.
- 🔹 **When needed**: 🟡 **Mid-level** — expected once you're proposing architectures someone has to pay for.
- 🔹 **Intuition**: Renting one giant truck vs a fleet of vans — the truck is cheaper until you outgrow it, then each capacity bump costs disproportionately more than adding another van.
- 🔹 **If you go deeper**: Build a back-of-envelope sheet from AWS/GCP on-demand instance pricing; read the AWS Well-Architected "Cost Optimization" pillar and practice estimating instance count from QPS × cost-per-request.
- 🔹 **Interview hook**: *"Scale-up or scale-out for this workload?"* → quote the crossover: vertical wins until the $ curve goes exponential, then horizontal's linear cost and built-in redundancy win.

---

### 🏆 Start here if you have limited time
1. **Scaling the stateful tier** — the database is the bottleneck this entire file circles back to, and it's the highest-frequency interview area.
2. **p99 & connection draining** — cheap to learn, immediately changes how you set up any autoscaled service.

---

### 🧭 Suggested Deep Dive Order
1. **Scaling the stateful tier** (~2h; replication → sharding → consistent hashing is the backbone of DB scaling questions).
2. **p99 latency & connection draining** (~45 min; small concepts, big operational payoff).
3. **Amdahl's Law & USL** (~1h; gives you the math to defend *why* a curve flattens).
4. **Cost modeling per 1000 QPS** (~45 min; turns scale-up/out into a number an interviewer can poke at).
