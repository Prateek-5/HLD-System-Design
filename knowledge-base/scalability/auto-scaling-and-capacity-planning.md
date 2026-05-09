# Auto-Scaling & Capacity Planning

> *"Auto-scaling is the marketing answer to 'how do we handle traffic spikes?' Capacity planning is the engineering answer. The first works in the slides; the second works at 3am during a launch."*

---

## Topic Overview

Capacity planning is the engineering discipline of figuring out how much hardware (CPU, memory, network, storage, IOPS, database connections) your system needs to handle expected workloads — under normal load, under peak, under failure conditions. Auto-scaling is the operational mechanism for adjusting capacity dynamically as load changes.

The mistake teams make is treating these as the same thing. Auto-scaling is *not* capacity planning. Auto-scaling is *fine-grained adjustment around a baseline you established with capacity planning*. A team that "doesn't need capacity planning because we have auto-scaling" discovers, painfully and predictably, that auto-scaling has limits — minutes-long warm-up times, ceiling on instance count, bottlenecks that don't scale with replicas, and costs that explode when scaling reactively.

This is the topic where the "cloud is infinitely elastic" marketing meets the operational reality of "actually, the database connection pool is the bottleneck and you can't auto-scale around it." Every successful at-scale system has both: thoughtful capacity planning *plus* auto-scaling for the noise around the baseline.

---

## Intuition Before Definitions

Imagine running a delivery service.

**Pure auto-scaling.** You hire drivers as orders come in. An order arrives → you call a driver. Three orders arrive → call three drivers. The drivers have to come from somewhere — they live across town, take 20 minutes to arrive. You can hire as many as you want, but they're not instantly available.

**Pure capacity planning.** You hire a fixed fleet of 50 drivers. They cost money even when they're idle. On slow days they're underutilized; on busy days they're insufficient. But they're *there* — instant capacity for whatever load arrives.

**The real answer.** You hire 30 baseline drivers (covers 90% of typical load). You have a roster of 40 on-call drivers who can be activated within 20 minutes. For the absolute extreme (Black Friday), you've pre-staged extra drivers in the area for 2 weeks, paying their idle time as insurance.

That's how production systems actually run. Auto-scaling for the noise. Static capacity for the baseline. Pre-staged extra capacity for known events. *Capacity planning is the discipline of deciding the baseline*. Auto-scaling is the implementation of the noise-handling. Pre-staging is the response to known events that exceed even auto-scaling's limits.

---

## Historical Evolution

**Era 1 — Manual provisioning.**
1990s, 2000s. Servers ordered weeks in advance. Capacity planned for peak — months of estimates and procurement. Underutilized most of the time; overwhelmed during unexpected spikes.

**Era 2 — Virtualization.**
~2003 onward. VMware, Xen. Decouples logical servers from physical hardware. Capacity becomes more elastic; provisioning still mostly manual.

**Era 3 — Cloud and elasticity.**
~2007 onward (AWS launched 2006). Provision instances in minutes, pay per hour. Capacity planning shifts from "buy hardware" to "configure cloud." Auto-scaling groups appear.

**Era 4 — Container orchestration.**
~2014 onward. Kubernetes, ECS. Containers scale in seconds vs minutes for VMs. Horizontal Pod Autoscaler standardized.

**Era 5 — Serverless.**
~2014 onward. AWS Lambda, Cloud Functions. Scale to zero; scale up to thousands in seconds. Capacity planning seemingly disappears (still exists; just at the platform level).

**Era 6 — Predictive and ML-driven scaling.**
Modern systems use ML to predict load (daily patterns, weekly cycles, holiday spikes). Pre-provision capacity ahead of predicted demand. Combine with reactive scaling for noise.

The pattern: scaling has gotten faster (weeks → minutes → seconds), more granular (servers → VMs → containers → functions), and more predictive (reactive → predictive). Each generation reduced the gap between demand and supply.

---

## Core Mental Models

**1. Auto-scaling is reactive; capacity planning is proactive.**
Auto-scaling responds to *current* load. Capacity planning prepares for *expected* load. Together they handle both predictable and unpredictable demand.

**2. Scaling has limits. Some are technical; some are time.**
A new instance takes 30 seconds to 5 minutes to come online. Your traffic spike is 10 seconds. Auto-scaling alone cannot help with sudden spikes; pre-warm or use load shedding.

**3. The bottleneck moves.**
Scale CPUs, the database becomes the bottleneck. Scale the database, the connection pool becomes the bottleneck. Scale that, the cache becomes the bottleneck. Capacity planning is *whole-stack*.

**4. Saturation, not utilization, is the right signal.**
60% CPU is fine; queue length growing is not. Saturation indicators (queue depth, latency p99, request acceptance rate) predict failure better than utilization metrics (CPU %, memory %).

**5. Cost optimization is the dual of capacity planning.**
Plan for *just enough* capacity to meet SLOs. Over-provisioning is money burned. Under-provisioning is reliability burned. The economic sweet spot is service-specific.

---

## Deep Technical Explanation

### Capacity planning — the methodology

Steps:

1. **Identify the workload's primary metrics.** Requests per second, queries per second, messages per second, concurrent connections.
2. **Measure resource consumption per unit of workload.** "1 RPS = 0.05 CPU cores + 200 connection slots + 5 MB memory + 10 IOPS."
3. **Forecast workload.** Baseline + growth + seasonality + special events.
4. **Compute required capacity.** `Workload × per-unit cost × headroom factor`.
5. **Plan headroom for failures.** "We must survive a single AZ failure, so add 50%."
6. **Plan headroom for variability.** Real load is bursty; add 20-50% over the smooth average.
7. **Validate via load testing.** Don't trust calculations alone; measure under realistic load.

This is a *quarterly or yearly* exercise for stable services. A one-time "we provisioned for traffic" doesn't survive a year of growth.

### Workload characterization

Every system has a *bottleneck resource*. Common ones:

- **CPU**: typical for compute-bound services, image processing, ML inference.
- **Memory**: caches, in-memory databases, JVM heaps.
- **Network bandwidth**: video streaming, file transfers, replication.
- **Network connections**: per-instance limit on open sockets.
- **Disk IOPS**: databases, log writers, queue brokers.
- **Database connections**: a hard ceiling that auto-scaling instances cannot exceed.

Identify *yours*. Most services have one primary and one secondary. CPU and memory are easy to monitor; database connections often catch teams by surprise.

### Auto-scaling mechanisms

**Horizontal Pod Autoscaler (HPA)** — Kubernetes:
- Watches metrics (CPU, custom).
- Scales pod count up/down to maintain target.
- Default: target CPU utilization (e.g., 60%).
- Custom metrics: queue depth, RPS per pod, etc.

**Cluster Autoscaler** — Kubernetes:
- Adds/removes nodes from the underlying cluster.
- Watches pending pods (those that can't fit on existing nodes).
- Scales the *node pool*, not pod count.

**AWS Auto Scaling Group**:
- Dynamic policies (scale on metric thresholds).
- Scheduled scaling (scale up at 9am every weekday).
- Predictive scaling (ML-driven, AWS-managed).

**Serverless (Lambda, Cloud Run)**:
- No instances; concurrency-based scaling.
- Scale to zero.
- Cold-start latency for first request.

The mechanism choice is upstream of the operational behavior. Each has different latency, cost models, and failure modes.

### Scale-up vs scale-out

**Scale-up (vertical)**: bigger instance. More CPU, RAM. Limited by the largest available instance type.

**Scale-out (horizontal)**: more instances. Theoretically unlimited; practically limited by coordination overhead and bottlenecks (DB, network).

Most production scaling is scale-out. Scale-up is for:
- Memory-bound workloads (a single big-memory instance often beats many small ones).
- Workloads with large per-request memory (JVM heaps).
- Latency-sensitive workloads where in-process locality matters.

The hybrid: choose right-sized instances (not the smallest), then scale out.

### Cold start and warm-up

A new instance is *not immediately* fully operational:

- **Boot time**: VM startup, container pull, OS init. Seconds to minutes.
- **JIT warm-up**: JVM, V8 — first requests are slow until JIT kicks in.
- **Cache warm-up**: in-memory caches must populate. First requests have low cache hit rate.
- **Connection pool establishment**: DB connections must be created.

Total cold-start: tens of seconds for VMs; hundreds of milliseconds for serverless (best case); minutes for stateful systems.

Implications:
- **Auto-scaling lags load**. By the time the new instance is ready, the spike may be over.
- **Pre-warm for known events**. Black Friday: scale up at 6am, not when load spikes.
- **Buffer in scaling**. Scale at 50-60% utilization, not 90%.

### The runaway scaling failure

A pathological pattern:

1. Service is overloaded; latency spikes.
2. Auto-scaler adds instances.
3. New instances pile on the bottleneck (DB, cache).
4. Bottleneck saturates harder; latency worse.
5. Auto-scaler adds more instances.
6. Repeat until cost explodes.

This is what happens when the bottleneck *isn't* the scaled resource. Scaling app servers doesn't help if the DB is the bottleneck — the DB just gets more queries from more instances.

Mitigations:
- **Scale on saturation metrics**, not generic ones.
- **Cap auto-scaling**: max instance count limits.
- **Scale the bottleneck**, not just the front layer.
- **Load shed at the edge** when downstream is saturated.

### Capacity for failure

If you have N instances handling load X, what happens when one fails?

- **N=2**: each handles 50% of X. One fails → remaining must handle 100% of X. Each must be sized for double the steady-state load.
- **N=10**: each handles 10% of X. One fails → remaining must handle 11.1% each. Less surge per instance.
- **N=100**: one failure barely matters per-instance.

Implication: smaller-instance / larger-count fleets handle failures better. A few big instances are fragile; many small ones are resilient.

But: smaller instances have more per-instance overhead (each runs the OS, the runtime, the container). The economic sweet spot depends on the workload.

### Multi-AZ / multi-region

To survive AZ failures:
- Run in 3 AZs.
- Each must have ⅓ of capacity if any 2 must handle full load... wait, no. Each must have ½ of capacity if any 1 can fail (so 2 of 3 handle 100%). So total capacity is 1.5× the single-AZ-need: 50% headroom.
- Want to survive 2 AZ failures? 1 AZ must handle full load. Total capacity is 3× the single-AZ-need: 200% headroom.

Multi-region is similar but with cross-region latency and higher costs.

The math is uncomfortable. "We need 50% headroom for failure tolerance" sounds wasteful until you experience the failure.

### Forecasting

Sources of demand:
- **Historical patterns**: daily, weekly, seasonal cycles.
- **Growth**: compounding traffic year over year.
- **Marketing events**: launches, promotions, ads.
- **External events**: holidays, viral content.

Tools:
- Time-series forecasting (ARIMA, Prophet) for cyclical patterns.
- Manual planning for known events.
- Buffer for the unforecastable.

The discipline: review forecasts weekly; update capacity plans monthly; deep-dive quarterly.

### Cost considerations

The economic axis:

- **Reserved instances / committed use**: cheaper per hour; pay even if unused.
- **On-demand**: standard price; pay only when used.
- **Spot/preemptible**: cheap; can be terminated by the provider.

Pattern: baseline on reserved (predictable utilization), peak on on-demand, batch/non-critical on spot.

A team that's "always on demand" is paying 30-50% premium for flexibility they may not need.

---

## Real Engineering Analogies

**The restaurant on a Friday night.**
A restaurant doesn't hire chefs reactively as customers walk in. They forecast: Friday night, 200 diners expected, 1 chef per 30 diners, so 7 chefs. They hire 8 (buffer). They cross-train 2 servers as backup chefs (failure tolerance). A surprise reservation of 50? They fast-track a part-time chef on standby.

That's capacity planning. Auto-scaling is the part-time chef on standby. The 7 baseline chefs are static capacity. The cross-training is failure tolerance. Restaurants run this way because reactive hiring doesn't work — chefs aren't instantly available.

**The power grid.**
A grid operator forecasts demand by season, day, hour. They contract for *baseload* (cheap, always-on power: nuclear, coal). They have *intermediate* (gas turbines, ramping up over hours) and *peaking* plants (extreme spikes, expensive per MW). On a hot July afternoon, peaking plants light up.

Software systems should mirror this: baseline reserved capacity, mid-tier on-demand for daily peaks, spot/preemptible for batch, and pre-warmed scale-out for known events.

---

## Production Engineering Perspective

What goes wrong:

- **The "auto-scaling will handle it" assumption.** Marketing launches a campaign at 9am. Traffic spikes 10× in 30 seconds. Auto-scaling adds instances over 3 minutes. Site is degraded for 2-3 minutes. Mitigation: pre-warm; buffer baseline higher; load-shed gracefully.
- **The bottleneck behind the LB.** Scale app servers to 100 instances. DB has a 200-connection limit. App can only use 200 connections total — adding instances doesn't help. Discover this only at scale.
- **The cold-start tax.** Service rebooted; first 10 seconds of requests are slow because JIT, caches, and connection pools are cold. Latency p99 ruined for warm-up duration. Mitigation: warm-up phase before adding to load balancer.
- **The runaway cost.** Auto-scaling adds instances during a metric anomaly that's actually a metrics bug, not real load. Bill for the day spikes 10×. Mitigation: max instance caps; cost alerts.
- **The auto-scale-down race.** Scale-down too aggressive. A small dip in traffic terminates instances. Spike returns. Now we're undersized; auto-scale-up takes a minute. Mitigation: longer scale-down windows; conservative termination.
- **The "we'll just throw more instances at it" trap.** Performance problem at the application level. Team adds instances rather than fix. Cost explodes. The bug is still there. Mitigation: profiling, optimization, *then* capacity.
- **The forgotten reservation.** Team committed to 100 instances of a deprecated instance type. Bill for 6 months for unused reservations. Mitigation: track reservations; renew or cancel deliberately.

The senior operator's habits:
- **Identify the bottleneck** before scaling.
- **Pre-warm for known events.**
- **Cap auto-scaling** to prevent cost runaway.
- **Watch saturation metrics**, not just utilization.
- **Plan failure capacity** explicitly.
- **Forecast and review** monthly.
- **Optimize cost** with reservation strategy.

---

## Failure Scenarios

**Scenario 1 — The launch-day meltdown.**
Product launch at 10am. Traffic 50× normal. Auto-scaling can't keep up; cold-start adds 2-minute delay. Site is partially degraded for 30 minutes. Postmortem: pre-warm capacity ahead of known events; load shed at edge during launch.

**Scenario 2 — The database bottleneck reveal.**
Service auto-scales to 200 app instances during traffic spike. p99 latency still terrible. DB connections capped at 100 total (RDS instance limit). Each app instance gets 0.5 connections. Scale-out hurts more than helps. Fix: scale DB; or cap app pool size; or add connection pooler (PgBouncer).

**Scenario 3 — The cost catastrophe.**
A bug in metrics causes a flat false signal interpreted as "high load." Auto-scaler adds instances continuously. 24 hours later, cluster has scaled to 500 instances on a service that normally has 20. $50K bill. Recovery: max instance limit (now 50); alerts on instance count.

**Scenario 4 — The unplanned holiday traffic.**
Black Friday traffic is 8× normal. Capacity was planned at 4×. Service degrades; engineers manually add instances; takes 20 minutes. Revenue impact: estimated $500K. Fix: better capacity forecasting; pre-staged scaling for known events.

**Scenario 5 — The cascading capacity failure.**
A regional AZ failure removes ⅓ of capacity. Remaining 2 AZs are at 100% load each. Headroom was 50%, but they were already 80% utilized. Cascading slowness; some failover failures. Fix: increase per-AZ headroom; or accept partial failure during major events.

---

## Performance Perspective

- **Cold-start latency** matters for serverless and rapid-scale workloads.
- **Connection pool sizing** is often the underrated bottleneck.
- **Memory headroom** prevents OOM under spike.
- **Saturation metrics** beat utilization metrics for predicting failure.
- **Load testing** validates capacity numbers; theoretical calculations age badly.

---

## Scaling Perspective

- **Vertical**: limited by largest instance.
- **Horizontal**: limited by bottleneck resources downstream.
- **Geographic**: multi-region adds cost and complexity; required for very large scale.
- **Predictive vs reactive**: predictive scaling smooths daily patterns; reactive handles noise.
- **Cellular architectures**: independent capacity per cell; isolation prevents global cascades.

---

## Cross-Domain Connections

- **Sharding**: scaling limits manifest as need for sharding when single-instance ceilings are hit. (See [sharding-and-partitioning-strategies.md](./sharding-and-partitioning-strategies.md).)
- **Load balancing**: capacity is meaningless without effective distribution. (See [load-balancing-strategies.md](./load-balancing-strategies.md).)
- **Cascading failures**: undersized fleets cascade more easily; capacity is reliability. (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)
- **Backpressure**: the right response to over-capacity is shedding, not crashing. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Observability**: capacity decisions are downstream of metrics quality. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)
- **SLOs**: capacity must support SLO targets, including under failure. (See [slos-error-budgets-and-alerting.md](../observability/slos-error-budgets-and-alerting.md).)

The unifying observation: **capacity planning is a forecast about the future; auto-scaling is an adjustment to present reality. Both need each other; neither replaces the other.**

---

## Real Production Scenarios

- **Netflix's predictive autoscaling**: documented machine-learning-driven approach to predicting evening traffic spikes.
- **AWS Black Friday playbooks**: extensive public guidance on pre-warming, scaling capacity, and handling launches.
- **Google's resource accounting**: internal systems for tracking capacity reservations and forecasts.
- **The Cloudflare 2019 outage**: regex backtracking caused CPU saturation; documented as a capacity / saturation failure.
- **Slack's capacity planning practices**: public engineering posts describe forecasting, headroom, and load testing.
- **The "we scaled to 0 then to too many" serverless stories**: well-documented pattern of cold-start cascades when scaling from idle.

---

## What Junior Engineers Usually Miss

- That **auto-scaling has time delays** (seconds to minutes).
- That **the bottleneck moves** as you scale.
- That **cold-start matters** for first requests.
- That **utilization metrics lag saturation**.
- That **DB connections are often the silent ceiling**.
- That **headroom for failure is mandatory**.
- That **load testing must include sustained overload**, not just peak.
- That **scale-up doesn't fix application bugs**.

---

## What Senior Engineers Instinctively Notice

- They **identify the bottleneck** before scaling.
- They **plan headroom for AZ/region failure**.
- They **pre-warm for known events**.
- They **cap auto-scaling** to prevent runaway cost.
- They **distinguish saturation from utilization**.
- They **forecast and review** capacity periodically.
- They **load-test under realistic patterns**.
- They **include cold-start in latency budgets**.

---

## Interview Perspective

What gets tested:

1. **"How would you size capacity for a service expecting X RPS?"** Tests methodology: per-request cost, headroom, failure tolerance.
2. **"Why isn't auto-scaling enough?"** Cold-start, bottleneck migration, time delays.
3. **"Where would you place a bottleneck?"** Tests workload characterization.
4. **"How do you handle a 10× spike in 30 seconds?"** Pre-warm, load shed, capacity buffer.
5. **"What's saturation vs utilization?"** Saturation predicts; utilization measures.
6. **"How does failure tolerance affect capacity?"** Headroom math.
7. **"How do you optimize cost?"** Reservation strategy + on-demand + spot mix.

Common traps:
- Believing auto-scaling is sufficient.
- Not knowing about connection-pool ceilings.
- Forgetting failure capacity.

---

## 20% Knowledge Giving 80% Understanding

1. **Capacity = baseline planning + auto-scaling for noise.**
2. **Identify the bottleneck**; scale that, not just the front.
3. **Cold-start adds delay** to scaling.
4. **Saturation metrics** > utilization metrics.
5. **Headroom for failure** is mandatory: 30-100%.
6. **Pre-warm for known events.**
7. **Cap auto-scaling** to prevent cost runaway.
8. **Connection pools** are common silent ceilings.
9. **Reservation + on-demand + spot** for cost optimization.
10. **Load test under realistic patterns**, including failures.

---

## Final Mental Model

> **Capacity planning is engineering for the load you expect. Auto-scaling is engineering for the load you didn't expect. Together they are how systems meet their SLOs while their bills stay sane.**

The senior engineer planning capacity treats it as a forecast, not a one-time calculation. Workloads grow; bottlenecks shift; failure scenarios evolve. Quarterly review keeps the plan current. Monthly metrics-watch catches drift. Pre-launch capacity reviews catch surprises before they're production incidents.

The systems that survive growth and unexpected events are the ones whose capacity is *planned*, not *reactive*. Auto-scaling is a powerful tool — within the limits of its assumptions. Outside those limits (cold-start delays, downstream bottlenecks, sudden 100× spikes), capacity planning is what saves you. The marketing slides will talk about elastic scaling. The engineering reality is more careful.

That's auto-scaling. That's capacity planning. That's the disciplined math behind "the system handles whatever traffic we throw at it" — when it's true.
