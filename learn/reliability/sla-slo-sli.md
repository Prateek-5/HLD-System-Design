# SLA, SLO, SLI — The Reliability Vocabulary

## A. Intuition First
- **SLI (Indicator)**: a metric. (e.g., p95 latency, success rate.)
- **SLO (Objective)**: the internal target. (e.g., 99.9% of requests < 300 ms.)
- **SLA (Agreement)**: contractual with customers. (e.g., "99.9% uptime or credit".)

SLIs are what you **measure**. SLOs are what you **promise internally**. SLAs are what your **legal team writes for customers**.

## B. Mental Model
- SLO is stricter than SLA (buffer for imperfection).
- Every SLO implies an **error budget** = 1 − SLO (e.g., 0.1% downtime is "allowed").
- When error budget is consumed, freeze risky changes until recovered.

## C. Internal Working
1. Pick 3–5 SLIs per service (availability, latency, throughput, correctness).
2. Set SLOs with evidence + stakeholder buy-in.
3. Instrument dashboards and alerts (alert on burn rate, not instant drops).
4. Budget drives product vs reliability work.

## D. Visual Representation
```
SLI (measured)  ──> compared to SLO (target)
If SLO missed for users  →  SLA credit to customer
```

## E. Tradeoffs
- High SLOs → less feature velocity (need more ops investment).
- Too-loose SLOs → customers churn.
- SLO per service, not per org; different endpoints have different criticality.

## F. Interview Lens
- "SLA vs SLO?"
- "What's an error budget?"
- "How do you react when you've burned your monthly budget?"
- Pitfalls: confusing availability with latency SLOs; alerting on symptoms not causes.

## G. Real-World Mapping
Google SRE book made this vocabulary standard. Most mature tech orgs use it.

## H. Questions
**Beginner**: Define SLA/SLO/SLI.
**Intermediate**: Error budget policy?
**Advanced**: Design SLOs for a payments service. Defend.

## I. Mini Design
Payments SLI: success rate and p99 latency. SLO: 99.95% success, p99 < 500 ms over 30 days. SLA to merchants: 99.9% or 5% monthly credit. If p99 trending bad for 1h → alert; if SLO burn > 2× expected → freeze risky deploys.

## J. Cross-Topic Connections
- [Availability](../foundations/scaling/availability.md), [Disaster Recovery](disaster-recovery.md).

## K. Confidence Checklist
- [ ] Can articulate difference between the three.
- [ ] Knows error budget policy.

## L. Potential Gaps & Improvements
- Burn-rate alerting math.
- Multi-window, multi-burn-rate alert configurations.
