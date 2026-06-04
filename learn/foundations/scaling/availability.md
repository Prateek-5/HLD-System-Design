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

### 🪜 Worked example — why a junior architecture is worse than advertised
You promise "3 nines (99.9%)" to customers. Your stack:
Client → LB (99.9%) → App (99.9%) → DB (99.9%).
- All in series → total = 0.999 × 0.999 × 0.999 = **99.7%**. You missed your SLA by a full nine.

Fix: add redundancy.
- 2 LBs parallel → 1 − (0.001)² = 99.9999%
- 3 App instances parallel → ~100%
- Primary + sync replica DB → 99.9999%
- Series of those three: still ~99.9999% (the weakest link determines the floor).

> **🧠 What-if** — adding a 4th redundant component in series (say, a new auth service at 99.9%) drags you **back down**. You need it redundant too or it becomes the new weakest link.
>
> **🔎 Quick Check** — If I have 5 services each at 99.99%, all in series, what's the total?
> **🎯 Recall** — 0.9999⁵ ≈ 99.95%. You drop from 4 nines to ~3.5 nines just by chaining them.

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
- **MTTR (Mean Time To Recovery)** — average time to restore a service after it breaks; lowering it raises availability faster than chasing fewer failures.
- **MTBF (Mean Time Between Failures)** — average uptime between two outages; pairs with MTTR to model how reliable a component really is.
- **Regional vs Global SLOs (Service Level Objectives)** — a target met per-region can still miss globally; learners need to know which scope they are promising.
- **Error Budgets (Google SRE style)** — the small slice of allowed downtime left over from your SLO; spend it on shipping features, run out and you freeze releases.

**🔧 How to close:** Compute your own error budget by hand: for a 99.9% monthly SLO, run `python3 -c "print(30*24*60*(1-0.999), 'minutes/month allowed downtime')"` — then redo it for 99.99% to feel how each extra nine shrinks the budget tenfold.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### ⏱️ Gap 1 — MTTR & MTBF: the Two Levers Behind a Nine
- 🔹 **What it is**: MTBF (Mean Time Between Failures) is how long a component runs before it breaks; MTTR (Mean Time To Recovery) is how long it takes to get back up. Availability ≈ MTBF / (MTBF + MTTR).
- 🔹 **Why it matters**: It reframes availability from "don't break" to "recover fast." Halving your MTTR buys you the same nine as doubling how rarely you fail — and recovery is usually the cheaper lever.
- 🔹 **Connection**: This file gives availability as Uptime / (Uptime + Downtime). MTTR and MTBF are simply *how you predict that ratio before launch*, and they explain why the worked example's redundancy helps: redundancy slashes the MTTR seen by users (failover in seconds instead of a human paging in).
- 🔹 **When needed**: 🟢 **Foundational** — every on-call engineer and most mid-level interviews touch this.
- 🔹 **Intuition**: A car that breaks down once a year but takes a week in the shop is *less* available to you than one that stalls monthly but restarts in 30 seconds. Frequency isn't the whole story — recovery speed is.
- 🔹 **If you go deeper**: Read the MTTR/MTBF chapter of the Google SRE Book, and instrument a real incident timeline (detect → diagnose → mitigate → resolve) to see where your minutes actually go.
- 🔹 **Interview hook**: *"Your service fails as often as a competitor's but customers say you're more reliable — why?"* → Lower MTTR: you fail just as often but recover so fast users barely notice, so measured availability is higher.

---

#### 📊 Gap 2 — Error Budgets & SLOs: Spending Your Allowed Downtime
- 🔹 **What it is**: An SLO (Service Level Objective) is the availability target you commit to; the error budget is the leftover downtime that target *permits* (a 99.9% SLO budgets ~43 min/month). You're allowed to spend it on shipping features and taking risks.
- 🔹 **Why it matters**: It turns availability from a vague "be reliable" into a number teams can trade against velocity. Budget left → ship faster; budget burned → freeze releases and harden. It's how Google SRE settles the dev-vs-ops fight.
- 🔹 **Connection**: The file's "🔧 How to close" already computes this budget by hand. This gap is the *policy* wrapped around that number — and it directly uses the "each nine = 10× cost" tradeoff from section E to decide whether one more nine is worth the spend.
- 🔹 **When needed**: 🟡 **Mid-level** — expected once you own a service; common in SRE and senior design rounds.
- 🔹 **Intuition**: A monthly entertainment budget. Underspend and you can splurge on a risky night out (a big risky deploy); blow through it and you're eating instant noodles (release freeze) until next month.
- 🔹 **If you go deeper**: Read the "Embracing Risk" and "Service Level Objectives" chapters of the Google SRE Book; then set up a burn-rate alert in Prometheus/Grafana that fires when you're spending budget too fast.
- 🔹 **Interview hook**: *"Engineering wants to ship daily, ops wants stability — how do you resolve it without picking a side?"* → Define an SLO, derive its error budget, and let the remaining budget decide: spend it on launches, freeze when it's gone.

---

#### 🌍 Gap 3 — Scope of an SLO: Regional vs Global vs Per-User
- 🔹 **What it is**: The *boundary* you measure availability over. "99.99% globally" can hide a region that was fully down for an hour, because healthy regions average it out. Per-user or per-region SLOs catch the pain that global aggregates mask.
- 🔹 **Why it matters**: A user in one failed region experiences 0% availability while your dashboard proudly shows 99.99%. Picking the wrong scope means you promise a number that no single customer actually feels.
- 🔹 **Connection**: Section F warns about confusing "my server has uptime" with "users see it as up." Scope is the same trap one level higher: a *globally* available system can still be *regionally* unavailable to everyone in that region.
- 🔹 **When needed**: 🔴 **Senior** — matters for multi-region/global platforms and SLA negotiations; less so for a single-region app.
- 🔹 **Intuition**: A restaurant chain advertising "99% of tables served on time" — true company-wide, but useless if *your* branch is the one that's always slammed. The average doesn't sit at your table.
- 🔹 **If you go deeper**: Study how AWS publishes per-region status and per-service SLAs separately, and read the SRE Workbook chapter on SLO scoping and the "good events / valid events" ratio.
- 🔹 **Interview hook**: *"Your global availability is 99.99% but customers are furious — how?"* → A single region (or a single big tenant) was fully down; global averaging hid it. Measure and alert per-region/per-user, not just globally.

---

### 🏆 Start here if you have limited time
1. **MTTR & MTBF** — it reframes the whole file: availability is as much about fast recovery as about not failing, and it's the most universally useful lever on-call.
2. **Error Budgets & SLOs** — the single most common availability concept in mid-level and SRE interviews, and it builds directly on the math you already did here.

---

### 🧭 Suggested Deep Dive Order
1. **MTTR & MTBF** (~30 min; reframes availability and applies to every system you'll run).
2. **Error Budgets & SLOs** (~1h; high interview payoff, turns the number into a policy).
3. **SLO scope (regional vs global)** (~45 min; senior signaling, pays off once you're multi-region).
