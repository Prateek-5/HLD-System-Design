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
- **Burn-rate alerting math** — burn rate is how fast you are spending the error budget relative to "normal"; a 2× burn rate means you will exhaust the month's budget in half a month, so it tells you when to page versus ignore noise.
- **Multi-window, multi-burn-rate alerts** — pairing a fast/short window (catch sudden outages) with a slow/long window (catch slow leaks) and different burn-rate thresholds; reduces false pages while still catching real budget burns (Google SRE's recommended setup).
- **Error budget policy** — the agreed rule for what happens when the budget is spent (e.g., freeze risky deploys until recovered); turns SLOs from a number into an actionable engineering decision (→ see Interview Lens).

**🔧 How to close:** Compute a burn rate by hand. Take a 99.9% availability SLO over 30 days: the budget is `0.001 × 30 × 24 × 60 = 43.2` minutes/month. If a 1-hour window shows 6 minutes of errored requests, the burn rate is `(6/60) / 0.001 = 100×` — meaning you would blow the whole month in ~26 minutes. Repeat for a 5-minute and a 6-hour window to see why multi-window alerting needs different thresholds for each.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔥 Gap 1 — Burn-Rate Alerting Math
- 🔹 **What it is**: A way to alert on *how fast* you are spending the error budget relative to "normal," instead of paging on every momentary error spike.
- 🔹 **Why it matters**: Alerting on instant drops creates noise and pager fatigue; burn rate ties the alert directly to whether you will actually miss the SLO. This is the single most-asked SRE follow-up after "what is an error budget?"
- 🔹 **Connection**: This file says "alert on burn rate, not instant drops" (Internal Working step 3) and the How-to-close walks the 100× example — this gap formalizes that arithmetic.
- 🔹 **When needed**: 🟢 **Foundational** — any reader running a service with an SLO benefits, and the math is just division.
- 🔹 **Intuition**: A fuel gauge that warns based on *consumption rate*, not the current tank level. Burning fuel at 100× the normal rate means an empty tank in minutes, even if the tank looks half full right now.
- 🔹 **If you go deeper**: Read Chapter 5 ("Alerting on SLOs") of the Google *Site Reliability Workbook* (free online); reproduce the burn-rate formula `burn = (observed error rate) / (1 − SLO)`.
- 🔹 **Interview hook**: *"Your 30-day 99.9% SLO is fine, but the last hour saw a 5% error rate — should you page?"* → 5% / 0.1% = 50× burn; at 50× you exhaust the month in ~14 hours, so yes, page.

---

#### 🪟 Gap 2 — Multi-Window, Multi-Burn-Rate Alerts
- 🔹 **What it is**: Combining a short/fast window with a long/slow window, each with its own burn-rate threshold, so you catch both sudden outages and slow leaks without false alarms.
- 🔹 **Why it matters**: A single window is always wrong somewhere — short windows page on blips, long windows miss fast outages. The paired setup is Google SRE's recommended production pattern and shows up in senior reliability rounds.
- 🔹 **Connection**: The Gaps bullet names this directly; the How-to-close hints at it by asking you to recompute burn for 5-minute and 6-hour windows.
- 🔹 **When needed**: 🟡 **Mid-level** — useful once you can compute a single burn rate and are actually configuring alerts.
- 🔹 **Intuition**: A smoke detector (fast, catches the kitchen fire) plus a monthly utility-bill review (slow, catches the dripping faucet). Different time scales catch different failures.
- 🔹 **If you go deeper**: Implement the canonical pair — e.g. page if 1h burn > 14.4× **and** 5m burn > 14.4×; ticket if 6h burn > 6×. Try it with Prometheus `multiburnrate` recording rules or Sloth/OpenSLO generators.
- 🔹 **Interview hook**: *"Why two windows instead of one?"* → the long window confirms the burn is sustained (avoids blip pages); the short window ensures you stop alerting quickly once recovered.

---

#### 📜 Gap 3 — Error Budget Policy as an Engineering Contract
- 🔹 **What it is**: The pre-agreed, written rule for what concretely happens when the budget is spent — e.g. freeze risky deploys, redirect the team to reliability work — signed off by both product and engineering before an incident.
- 🔹 **Why it matters**: An SLO is just a number until there is a policy that turns "we're over budget" into a forced decision; without it, reliability always loses to feature pressure. → see Interview Lens.
- 🔹 **Connection**: The Mental Model says "when error budget is consumed, freeze risky changes," and the Mini Design ends with "freeze risky deploys" — this gap is the governance layer that makes those automatic instead of a fight.
- 🔹 **When needed**: 🟡 **Mid-level** — matters most once a team owns its own SLOs and release cadence.
- 🔹 **Intuition**: A household rule agreed in calm times — "if the credit card hits the limit, no new purchases until it's paid down." Deciding the rule *before* the emergency removes the argument *during* it.
- 🔹 **If you go deeper**: Read the "Error Budget Policy" chapter of the Google SRE Workbook and draft a one-page policy for a sample service: who can override a freeze, escalation path, and recovery exit criteria.
- 🔹 **Interview hook**: *"You've burned the month's budget on day 10 — what happens?"* → the policy auto-triggers: freeze feature deploys, prioritize reliability fixes, and require explicit leadership sign-off to override.

---

### 🏆 Start here if you have limited time
1. **Burn-rate alerting math** — foundational, just division, and the most common follow-up to error-budget questions.
2. **Error budget policy** — turns the SLO from trivia into an organizational decision interviewers love to probe.

---

### 🧭 Suggested Deep Dive Order
1. **Burn-rate alerting math** (~30 min; unlocks every other reliability-alerting topic).
2. **Multi-window, multi-burn-rate alerts** (~1h; the production-grade alerting pattern).
3. **Error budget policy** (~45 min; the governance/people side that senior rounds expect).
