# Availability — What "Five Nines" Actually Means

> **Prereq**: none conceptually, but all prior topics inform this.

## A. Intuition First
Availability = the fraction of time your system is up and serving users correctly.

**Why it matters**: it's what users actually feel. A "fast but down 5 min/day" service looks worse than a "slow but always up" one.

## B. Mental Model
$$ \text{Availability} = \frac{\text{Uptime}}{\text{Uptime + Downtime}} $$

### The "nines" table
| Nines | % | Yearly downtime |
|---|---|---|
| 2 (99%) | — | 3.65 days |
| 3 (99.9%) | — | 8.77 hours |
| 4 (99.99%) | — | 52.6 minutes |
| 5 (99.999%) | — | 5.25 minutes |

Every extra "nine" costs roughly 10× the engineering effort. Most consumer apps target 3 nines; critical infra (payments, telephony) targets 4–5.

## C. Internal Working

### Availability of components in series vs parallel
- **Series** (any one failure kills the system): `A_total = A1 * A2 * A3...`
  - Example: web server (99.9%) + DB (99.9%) in series = 99.8%. You *lost* a nine.
- **Parallel** (redundancy — any one alive keeps it up): `A_total = 1 - (1-A1)*(1-A2)...`
  - Example: two DBs each at 99.9% → 1 - 0.001² = 99.9999%. You *gained* three nines.

**Punchline**: dependencies in series degrade availability; redundancy in parallel multiplies it. This is why systems are built with redundancy at every layer.

## D. Visual Representation
```
Series (any failure = outage):     A──B──C  → multiply availabilities
Parallel (need all to fail):       ┌─A─┐
                                   │   │   → 1 - product of (1-Ai)
                                   └─B─┘
```

## E. Tradeoffs
- **Availability vs Reliability**: reliable = correct when up; available = up. An available system can be unreliable (serving wrong answers). Really both matter.
- **HA vs Fault Tolerance**: HA minimizes downtime (seconds to minutes). FT aims for zero perceived downtime (requires full redundancy, expensive; used for life-critical systems).
- **More nines = more cost**: each nine typically requires 10× investment in redundancy, testing, automation, ops maturity.

## F. Interview Lens
- "Compute availability of this architecture." (apply the series/parallel formulas)
- "What SLA would you target and why?"
- "Difference between availability and reliability?"
- "How does introducing a cache affect availability?" (It *can* mask origin outages, but a cache miss during an origin outage fails.)
- Pitfalls: confusing "my server has uptime" with "users see it as up". The latter includes DNS, LB, ISP.

## G. Real-World Mapping
- AWS S3 SLA: 99.9% → ~43 min downtime/month of financial credit.
- AWS EC2 SLA: 99.99%.
- Critical telecom: 5–6 nines.
- PagerDuty incidents graph your real availability vs target — seniors look at that.

## H. Questions
**Beginner**: What's 4-nines availability? What's the difference from reliability?
**Intermediate**:
1. If all components are at 99%, and I chain 5 in series, what's the availability?
2. How does adding a second DC change it?
**Advanced**:
1. Design a 5-nines payments system. What redundancy at each layer?
2. How does a cache help or hurt availability?

## I. Mini Design — "Calculate availability"
Architecture: Client → LB → 3 app servers (parallel) → DB primary + replica. Each component 99.9%.
- LB → 99.9%
- App tier parallel (3 servers): 1 - 0.001³ ≈ 100%
- DB primary + replica: 1 - 0.001² ≈ 99.9999%
- All in series: 99.9% × 99.9999% × 99.9999% ≈ **99.9%** (LB is the weak link).
Conclusion: **redundant LB** is the next upgrade.

## J. Cross-Topic Connections
- [SLA/SLO/SLI](../../reliability/sla-slo-sli.md) — the formal measurement framework.
- [Disaster Recovery](../../reliability/disaster-recovery.md) — what happens when you fail the SLA.
- [Circuit Breaker](../../reliability/circuit-breaker.md) — maintaining availability during downstream failure.

## K. Confidence Checklist
- [ ] I can compute series and parallel availability.
- [ ] I know the "nines" → downtime mapping.
- [ ] I understand the cost curve (each nine is 10× effort).
- [ ] I can identify weakest-link components.

### Red flags
- ❌ Quoting "5 nines" without the math or operational maturity to back it.
- ❌ Treating availability as a single number rather than per-service, per-SLI.

## L. Potential Gaps & Improvements
- MTTR (Mean Time to Recovery) and MTBF (Mean Time Between Failures) — closely related but not covered.
- Regional vs global SLOs — deserve treatment.
- Error budgets (Google SRE style) — missing.
