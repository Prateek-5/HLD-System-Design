# SLOs, Error Budgets & Alerting

> *"Reliability is not free. It costs feature velocity, infrastructure spend, and engineering attention. The teams that work this out explicitly — through SLOs and error budgets — make rational tradeoffs. The teams that don't oscillate between 'reliability is everything' and 'ship at any cost,' producing systems that are both unreliable and slow to evolve."*

---

## Topic Overview

Service Level Objectives (SLOs) are the formal contract about how reliable a service must be. Service Level Indicators (SLIs) are the metrics that measure that. Error budgets are the *operational consequence* — the difference between perfect and required, measured in how many failures you can afford before you must stop shipping new features and focus on reliability.

This is Google's SRE framework, popularized through the SRE book (2016). It's now industry standard practice — though widely talked about and inconsistently practiced. The framework is not just measurement; it's a *decision-making tool* that aligns reliability and feature velocity in a way that prevents the eternal "is this important enough to fix?" debate.

Alerting is the operational arm of all this: tying paging to SLO violations, not arbitrary metrics. The mature practice is "page on user-facing impact, ticket on internal symptoms" — a discipline that prevents alert fatigue and ensures incidents get the right urgency.

This is the topic where reliability becomes math. "We have good monitoring" becomes "we have a 99.9% availability SLO with a 28-day rolling window, currently at 99.92% with 30% of error budget remaining." The conversation shifts from feelings to measurements. The teams that adopt this find it transformative; the teams that don't keep arguing about whether the system is "reliable enough."

---

## Intuition Before Definitions

Imagine you run a chain of coffee shops.

Without SLOs, every customer complaint becomes a debate. "Is this slow service unacceptable?" Some managers say yes; some say no. Engineers fix some problems and ignore others. There's no shared definition of "good enough."

With SLOs, you decide explicitly: "95% of orders served within 5 minutes." That's the contract. Anyone can measure it. If you're hitting 96%, you're meeting the contract — invest in new features, expansion, anything. If you're hitting 92%, you're failing — stop expansion, focus on speeding service.

The error budget makes this even more powerful. You're allowed 5% slow orders. If you've used 4% in the first half of the month, you're "burning fast" — be cautious. If you've used 0.5%, you're fine; experiment, ship new things, accept some risk.

This turns the eternal "is reliability or velocity more important?" debate into a single number: how much error budget is left? When it's plentiful, ship. When it's depleted, reliability work.

That's SLOs. That's error budgets. The math turns vague debate into concrete decisions.

---

## Historical Evolution

**Era 1 — SLAs as marketing.**
1990s, 2000s. Service Level Agreements existed as customer-facing contracts ("99.9% uptime"), often without serious internal measurement. Often missed; rarely enforced.

**Era 2 — Internal availability metrics.**
2000s. Companies started measuring uptime internally. Mostly used for executive reports; not connected to engineering decisions.

**Era 3 — Google's SRE codification.**
~2003 onward, internally; public from 2016 with the SRE book. Google formalized SLOs, SLIs, error budgets, and the connection to engineering velocity. The framework's power: it makes reliability and feature velocity *trade off explicitly*.

**Era 4 — Industry adoption.**
Late 2010s. SRE practices spread. SLO tooling (Nobl9, Chronosphere, plain Prometheus) emerges. Cloud providers offer SLO-aware managed services.

**Era 5 — Burn-rate alerting.**
~2018. The realization that "alert when SLO is violated" is too late; better to alert on *burn rate* — how fast you're consuming error budget. Multi-window multi-burn-rate alerts become standard.

**Era 6 — Mature SLO culture.**
2020+. Best practices: tiered SLOs, user-journey SLOs (not just per-service), SLO-driven prioritization, error-budget-based release control. Still inconsistently adopted but increasingly the gold standard.

The pattern: reliability moved from vibes to measurements to operational decisions. Each generation made the framework sharper and more practical.

---

## Core Mental Models

**1. SLO = the contract; SLI = the measurement.**
The SLO is the goal; the SLI is what you measure to know if you're hitting it. Each SLO needs a clear, measurable, agreed-upon SLI.

**2. The error budget makes reliability tradeable.**
1 - SLO = error budget. With a 99.9% SLO, you have 0.1% to spend. This budget is what lets you ship — risky deploys, experiments, edge-case features. Without the framework, every change requires a debate; with it, the budget governs.

**3. Page on user-facing impact; ticket on internal symptoms.**
A high CPU alert is not a page. A spike in customer-facing 500s is. Tie pages to SLO violations. Everything else is a ticket.

**4. Alerting on burn rate beats alerting on threshold.**
"Error rate > 1%" is a poor alert. "We'll burn the entire 28-day error budget in 6 hours at this rate" is meaningful. Burn-rate alerts integrate over time, fire at appropriate urgencies, and avoid both noise and missed incidents.

**5. SLOs evolve. They're not gospel.**
Set them; review them; adjust them as the business changes. Too tight? Too loose? Both are signals. The right SLO is one that's *useful* — one that produces meaningful conversations and decisions.

---

## Deep Technical Explanation

### SLI selection

The first design decision: what to measure. Common patterns:

**Availability SLI:**
`(successful requests) / (total requests)` over a window. "Successful" is precisely defined: 2xx and certain 4xx (auth failures aren't *the service's* fault).

**Latency SLI:**
`(requests served under threshold) / (total requests)` — e.g., 99% of requests under 200ms.

**Error rate SLI:**
`(failed requests) / (total requests)` — inverse of availability.

**Quality SLI:**
For services that succeed in degraded modes: `(requests served at full quality) / (total successful requests)`.

**Throughput SLI:**
For batch services: `(jobs completed within deadline) / (total jobs)`.

The discipline: pick SLIs that *reflect customer experience*. Internal metrics like CPU don't qualify. Latency from the user's perspective (including network), error counts the user actually sees, success of user-meaningful operations.

### SLO definition

`SLO = SLI must be ≥ X% over window Y`.

Example: "99.9% of GET /api/orders requests complete with 2xx in <500ms over a rolling 28-day window."

Components:
- **Specific SLI**: well-defined, measurable.
- **Target**: the percentage.
- **Window**: rolling time period (28 days is common; sometimes calendar months).

Targets:
- **99%** — relatively loose. ~7 hours of unavailability per month.
- **99.9%** — moderate. ~43 minutes per month.
- **99.95%** — tight. ~22 minutes per month.
- **99.99%** — very tight. ~4 minutes per month.
- **99.999%** — extreme. ~26 seconds per month.

Each "9" of reliability is roughly 10× more expensive than the previous. 99.9% is achievable for most teams; 99.99% requires significant investment; 99.999% requires extraordinary engineering and is rarely the right choice (the customer pain often isn't worth the cost).

### Error budget

`Error budget = (1 - SLO) × window`.

For 99.9% over 28 days:
- 28 × 24 × 60 = 40,320 minutes.
- Error budget = 0.001 × 40,320 = ~40 minutes.

You can be "down" (or violating SLO) for 40 minutes per 28 days while still meeting the SLO.

### Burn rate alerting

The classic alert "page when error rate > X%" has two failure modes:
- **False positives**: a brief spike triggers; everyone wakes up; the spike was already over.
- **False negatives**: a sustained low-grade degradation never triggers; you blow the SLO without ever paging.

Burn-rate alerts solve this. Compute: at the *current* error rate, how fast are we burning the SLO budget?

`Burn rate = (current error rate) / (1 - SLO)`.

A burn rate of 1.0 means "if this continues, we'll exhaust the budget in exactly the SLO window." Burn rate of 14.4 means "we'll exhaust the entire monthly budget in 1 day."

Multi-window multi-burn-rate (Google SRE recommendation):

| Severity | Burn rate | Long window | Short window |
|---|---|---|---|
| Page | 14.4× | 1 hour | 5 minutes |
| Page | 6× | 6 hours | 30 minutes |
| Ticket | 3× | 24 hours | 2 hours |
| Ticket | 1× | 72 hours | 6 hours |

Why two windows: the long window confirms sustained behavior; the short window confirms it's currently happening (not a stale statistic). Both must be in violation.

This is the gold-standard alerting pattern. It catches real incidents, avoids noise, and gives meaningful signals at the right urgency.

### The alert hierarchy

- **Page**: someone wakes up. Reserved for active customer impact threatening SLO.
- **Ticket**: created for engineer review during business hours. SLO-affecting trends, near misses.
- **Dashboard**: visible to anyone looking. Internal metrics, capacity warnings.
- **Audit log**: recorded for postmortems; not actively watched.

The discipline:
- Pages must be actionable. If the response is "I'll look at it tomorrow," it shouldn't be a page.
- Tickets must be reviewable. If they're created and ignored, the alerting is broken.
- Dashboards must be owned. Orphan dashboards mislead.

### User-journey SLOs

Per-service SLOs are necessary; not sufficient. A user's experience crosses many services. A user-journey SLO measures the *whole flow*:

- "95% of checkouts complete within 3 seconds."
- "99% of search queries return results."
- "99.9% of payment confirmations are delivered within 1 minute."

These are harder to measure (require tracing, often custom tooling) but more meaningful. A service can hit its SLO while the journey it's part of fails — user experience is at the journey level.

### Error budget policies

When the error budget is depleted, what happens?

**Soft policy:**
- Notify stakeholders.
- Pause non-critical changes voluntarily.
- Discussion-driven response.

**Hard policy:**
- Auto-block deploys (only fixes allowed).
- Senior leadership approval required for new features.
- All hands focused on reliability work until budget recovers.

Most teams start soft and harden as the practice matures. The hard policy is uncomfortable but produces cultural change: reliability becomes a real cost, not an aspiration.

### SLO review and evolution

Review SLOs:
- **Quarterly**: are they still right? Too tight? Too loose?
- **After major incidents**: did the SLO catch this? Should the threshold change?
- **After product changes**: a new feature may shift user expectations.

Tightening SLOs ("99.9% → 99.95%") is a feature-velocity cost. Loosening ("99.95% → 99.9%") accepts more user pain. Neither is automatically better. The right SLO is the one that matches user expectations and business priorities.

### Composite and dependent SLOs

If your service depends on Service B (99.9% SLO), your SLO is bounded by B's. You can't promise 99.99% if a dependency only promises 99.9%.

Composing:
- N independent dependencies, each at SLO X: combined availability ≈ X^N. Three dependencies at 99.9% = 99.7%.
- Strong implication: deep dependency stacks make tight SLOs impossible. Architectures must minimize critical-path dependencies.

This is also a tool: SLOs surface architectural problems. "We can't hit 99.95% because we depend on 5 services at 99.9%" is actionable architectural insight.

### The "100% is the wrong target" insight

Google SRE's central insight: aiming for 100% reliability is wrong. It's:
- Infinitely expensive.
- Impossible (real systems fail).
- Counterproductive (your customers' systems fail more often than your SLO budget; perfect availability beyond their tolerance gives no benefit).

The right SLO reflects what *users actually need*. Users probably don't need 99.999% from your CRUD app. They might need it from the 911 dispatch service. SLO selection is a business question, not a technical one.

---

## Real Engineering Analogies

**The hospital admission triage.**
Hospitals don't promise to see every patient instantly. They have triage levels with target wait times: critical = immediate; serious = within 15 minutes; minor = within 4 hours. If they're meeting these targets, things are fine. If wait times are exceeding targets, the hospital is in distress and triage decisions get made.

That's SLOs: explicit targets per category. The error budget is "how much overage is acceptable before the system needs intervention."

**The airline on-time performance.**
Airlines publish on-time performance targets. They define "on-time" precisely (within 15 minutes of scheduled). They measure relentlessly. They use the metric for operational decisions: if performance is dropping, why? What can be done?

The same metric drives external trust (passengers choose airlines partly on this) and internal decisions. SLOs work the same way for software.

---

## Production Engineering Perspective

What goes wrong:

- **The SLO chosen by feel.** "Let's just say 99.9%." No analysis of user expectations, dependency reality, or business need. Either too tight (constantly violated; alerts ignored) or too loose (real problems missed). Mitigation: derive SLOs from data and business need.
- **The SLI that doesn't reflect customer pain.** Measuring backend success rate while users see CDN errors. SLO is "green" while customers complain. Mitigation: measure as close to the user as possible.
- **The unactionable SLO.** "99.99% availability" but the team has no way to know what's degrading. Without good observability, the SLO is a number; no diagnostic insight.
- **The alert fatigue spiral.** SLO violations alert on every minor blip. Engineers ignore. Real incidents missed. Mitigation: burn-rate alerts; multi-window confirmation.
- **The SLO without an owner.** "We have an availability SLO" but no one has authority to make tradeoffs. When budget runs out, business pressures override; SLO becomes theater.
- **The error budget that's never depleted.** The SLO is too loose; the team always has budget. Reliability work isn't prioritized. Customers actually suffer but the metric doesn't show it. Mitigation: tighten SLO until it's challenging.
- **The error budget that's always depleted.** The SLO is unachievable. Team is in permanent emergency mode. Burnout. Mitigation: loosen SLO to a realistic level.

The senior SRE's habits:
- **Define SLIs from the user's perspective.**
- **Set SLOs based on data**: historical performance, user expectations, business need.
- **Use burn-rate alerting**.
- **Page only on customer-impacting incidents**.
- **Review SLOs quarterly**.
- **Track error-budget burn** as a primary dashboard.
- **Tie engineering decisions to budget state**.

---

## Failure Scenarios

**Scenario 1 — The 99.99% delusion.**
Team commits to 99.99% availability without analyzing dependencies. Three downstream services are 99.9%. Compound availability is 99.7% — already failing the SLO before the team's own reliability matters. Six months of "the SLO is wrong" before adjustment to 99.5% (more realistic).

**Scenario 2 — The alert fatigue.**
Team creates 200+ alerts based on metric thresholds. On-call gets paged 30 times per night. Real incident occurs; oncall snoozes the alarm out of habit. 90-minute customer impact. Postmortem: cull alerts; implement burn-rate alerting; reduce paging volume by 90%.

**Scenario 3 — The SLO without consequences.**
Team has SLOs but no error budget policy. SLO frequently violated; nobody cares. Reliability work is always second to features. Customers churn. Eventually, SLO meeting consensus: actual budget freeze when violated; measurable reliability improvement quarter-over-quarter.

**Scenario 4 — The wrong SLI.**
SLO measured at the load balancer (success rate); customers see errors at the CDN layer. SLO is green; customer complaints rise. Investigation: SLI didn't include CDN failures. Migration to user-experience-based SLI; suddenly the SLO is correctly red.

**Scenario 5 — The burn-rate cascade.**
Service is degraded; burn rate hits 14× (will burn budget in 1 day). Page fires. On-call investigates. Issue is upstream dependency. Long-window check confirms sustained issue; mitigation begins. Budget is burnt 30%; learn-and-adjust cycle.

---

## Performance Perspective

- **SLI computation cost**: per-request metric extraction is microseconds.
- **SLO calculation**: rolling-window aggregations; cheap if pre-aggregated.
- **Burn-rate calculation**: more complex (multi-window); standard in modern monitoring stacks.
- **Alerting overhead**: real-time evaluation; modest CPU/memory.

---

## Scaling Perspective

- **Per-service SLOs**: each service team owns theirs.
- **User-journey SLOs**: cross-team coordination required.
- **Composite SLOs**: explicit multiplication of dependency SLOs.
- **At hyperscale**: SLO management as a discipline; tooling for SLO-driven release control.

---

## Cross-Domain Connections

- **Observability**: SLIs are derived from metrics, logs, traces. (See [metrics-logs-traces.md](./metrics-logs-traces.md).)
- **Cascading failures**: SLO breaches often start as small failures cascading. (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)
- **Capacity planning**: SLO targets drive capacity needs (more headroom = higher SLO achievability). (See [auto-scaling-and-capacity-planning.md](../scalability/auto-scaling-and-capacity-planning.md).)
- **Postmortems**: SLO violations trigger postmortems; postmortem action items improve SLO compliance. (See [postmortems-and-incident-response.md](../system-failures/postmortems-and-incident-response.md).)
- **Chaos engineering**: chaos exercises validate SLO compliance under failure. (See [chaos-engineering-and-game-days.md](../system-failures/chaos-engineering-and-game-days.md).)
- **Distributed tracing**: user-journey SLOs require traces. (See [distributed-tracing-deep-dive.md](./distributed-tracing-deep-dive.md).)

The unifying observation: **SLOs are the bridge between engineering metrics and business value. They turn reliability from an aspiration into a budgetable, tradeable engineering concern.**

---

## Real Production Scenarios

- **Google SRE's framework**: foundational. The SRE book and SRE workbook are the canonical references.
- **Netflix's SLOs and chaos**: combines SLOs with chaos engineering for reliability validation.
- **GitHub's public availability reports**: documented SLO performance over time; transparency-driven.
- **Cloudflare's SLA + SLO public posts**: customer-facing SLA backed by stricter internal SLOs.
- **Stripe's reliability culture**: documented SLO-driven engineering. Public engineering posts.
- **The SRE book's practical examples**: detailed case studies of SLO selection, alerting design, and error budget policy.

---

## What Junior Engineers Usually Miss

- That **SLIs must reflect user experience**, not internal metrics.
- That **SLOs are business decisions** as much as technical ones.
- That **error budgets are a tradeoff mechanism**, not a "we're allowed to fail" license.
- That **alerts must be actionable**.
- That **burn-rate alerting** is better than threshold-based.
- That **100% availability is wrong** as a target.
- That **SLOs depend on dependency SLOs** (multiplicatively).
- That **SLOs should be reviewed and adjusted** periodically.

---

## What Senior Engineers Instinctively Notice

- They **define SLIs from the user's perspective**.
- They **set SLOs from data and business need**.
- They **use burn-rate alerts**.
- They **page only on customer impact**.
- They **track error-budget burn** continuously.
- They **tie release decisions to budget state**.
- They **review SLOs quarterly**.
- They **understand dependency-SLO composition**.

---

## Interview Perspective

What gets tested:

1. **"What's an SLO?"** Tests basic literacy.
2. **"What's an error budget and how do you use it?"** Tests practical understanding.
3. **"What's burn-rate alerting?"** Tests modern alerting awareness.
4. **"How do you choose an SLO target?"** Tests judgment: data + business need + dependencies.
5. **"What's the difference between page and ticket?"** Tests operational maturity.
6. **"Why is 100% the wrong target?"** Tests SRE-philosophy literacy.
7. **"How do you compose SLOs across dependencies?"** Tests math + architecture awareness.

Common traps:
- Setting SLOs by gut feel.
- Measuring the wrong SLI.
- Page on every metric.
- Believing tighter is always better.

---

## Worked Example — Designing SLOs for a Checkout Service

You own checkout for an e-commerce site. Need to define SLOs that drive engineering priorities.

### Step 1: Identify user journeys

Don't define SLOs per-microservice. Define them per *user journey*:

```
Critical journeys:
  - Place order: from /checkout/start to confirmation page.
  - View cart: from /cart to display.
  - Add to cart: from click to UI update.

Support journeys:
  - View order history: less critical.
  - Update profile: less critical.
```

Each journey has its own SLO.

### Step 2: Define SLIs

For "place order":

```
SLI 1 — Availability:
  (orders_succeeded) / (orders_attempted)
  
  - Numerator: count of orders that returned 2xx within 30s and reached confirmation.
  - Denominator: count of /checkout/submit requests (excluding bots, health checks, abandoned carts).

SLI 2 — Latency:
  (orders_completed_in_under_5s) / (orders_completed)
  
  - 5s threshold based on user research; abandonment rises sharply past this.
```

Two SLIs. Both must be hit; either failure is a problem.

### Step 3: Set SLO targets

Look at historical data:

```
Last 90 days:
  Availability: 99.96% average; min 99.92% (during a database incident).
  Latency: 99.4% under 5s; min 98.1% (during a slow-query incident).
```

Set SLOs slightly more ambitious than current performance, but achievable:

```
SLO 1: 99.9% availability over 28-day rolling window.
       Error budget: 0.1% × 28 × 24 × 60 = 40 minutes/month.

SLO 2: 99% of orders complete within 5s over 28-day window.
       Error budget: 1% of orders can be slow.
```

99.9% (3 nines) is meaningful for checkout: matches user expectation; achievable; allows necessary maintenance.

### Step 4: Set up burn-rate alerts

(Multi-window, multi-burn-rate as canonical pattern.)

```yaml
# CRITICAL — page on-call
- alert: CheckoutAvailabilitySLOBurnFast
  expr: |
    (
      sum(rate(checkout_orders_failed[1h])) / sum(rate(checkout_orders_attempted[1h])) > (14.4 * 0.001)
    ) and (
      sum(rate(checkout_orders_failed[5m])) / sum(rate(checkout_orders_attempted[5m])) > (14.4 * 0.001)
    )
  for: 2m
  labels:
    severity: page
  annotations:
    summary: "Checkout SLO burning fast — full month's budget in 2 days"

# WARNING — ticket  
- alert: CheckoutAvailabilitySLOBurnSlow
  expr: |
    sum(rate(checkout_orders_failed[6h])) / sum(rate(checkout_orders_attempted[6h])) > (3 * 0.001)
  for: 30m
  labels:
    severity: ticket
  annotations:
    summary: "Checkout SLO trending bad — engineering review needed"

# Same patterns for latency SLO
```

### Step 5: Error budget policy

Document what happens when budget runs out:

```
Error budget policy:

If 28-day error budget consumption is:
  
  < 50% (healthy):
    - Ship freely. Take risks. Experiment.

  50-90% (cautious):
    - Continue feature work.
    - Recent changes get extra review.
    - Reliability work prioritized in backlog.

  90-100% (critical):
    - Soft freeze on non-critical features.
    - All new code requires reliability sign-off.
    - Top engineering priority is recovering budget.

  >100% (exhausted):
    - HARD FREEZE. No new features.
    - All hands on reliability work.
    - Postmortems for every incident.
    - Consider tightening SLO if this happens repeatedly.
```

### Step 6: Make it visible

```
Dashboards (always-up):
  - SLO compliance per journey, current month.
  - Error budget remaining.
  - Burn rate (last 1h, 6h, 24h).
  - Top contributors to failures (which endpoint, which error).

Weekly review:
  - SLO performance trends.
  - Action items from burn events.
  - Adjust SLO if calibration is off (too tight or too loose).
```

### What this produces

After 6 months:
- 5 incidents that previously would have been "did anyone notice?" generated burn alerts within minutes.
- 2 release freezes triggered by error budget exhaustion → both cases led to architectural improvements.
- Engineering and product agree on reliability vs feature trade-offs based on data, not feel.
- On-call gets paged 1-2 times per week instead of daily — alert fatigue eliminated.

The framework's value isn't the math. It's the *aligned conversation* between engineering and product: when the budget is full, ship; when it's depleted, fix. No more arguing about whether reliability is "important enough."

### Reference architecture — SLO infrastructure

```
[Application]
    │
    │  metrics emission (request count, latency, errors)
    ▼
[Prometheus / metric backend]
    │
    │  SLI computation
    ▼
[SLO computation layer]
    │  (e.g., Sloth, Pyrra, custom)
    │  Computes:
    │    - SLO target vs actual
    │    - Error budget remaining
    │    - Burn rate (multi-window)
    │
    ├──► [Alertmanager / PagerDuty]  (burn rate alerts)
    │
    ├──► [Grafana dashboards]         (SLO visibility)
    │
    └──► [Release-control automation]  (freeze on budget exhaustion)
```

---

## Recent Production References (2023-2024)

- **Sloth and Pyrra**: open-source SLO-computation tooling. Production use documented.
- **Google's SRE Workbook (continuing reference)**: still the foundational text.
- **Datadog SLOs**: managed SLO computation; widely used.
- **New Relic's SLO product**: similar.
- **The "RED method" by Tom Wilkie**: continues to be the foundation.
- **Slack's SLO journey**: documented evolution from no-SLOs to mature SLO culture.
- **Honeycomb's BubbleUp**: anomaly detection on SLI dimensions; complements SLO alerts.

---

## 20% Knowledge Giving 80% Understanding

1. **SLO = goal; SLI = measurement.**
2. **Error budget = 1 - SLO**, the slack you can spend.
3. **Page on customer impact**; ticket otherwise.
4. **Burn-rate alerts** > threshold alerts.
5. **Multi-window multi-burn-rate** is the gold standard.
6. **100% is wrong**; target user-meaningful reliability.
7. **SLOs compose multiplicatively** across dependencies.
8. **Review SLOs quarterly.**
9. **Error-budget policies** create real tradeoffs.
10. **User-journey SLOs** > per-service SLOs for customer experience.

---

## Final Mental Model

> **SLOs turn reliability from a religion into engineering. The error budget is the unit of trade between reliability and velocity. The burn rate is the early-warning system. Combined, they let an organization make rational reliability decisions instead of arguing.**

The senior engineer adopting SLOs treats them as a *cultural* change, not just a metric. The framework only works if the organization commits to it: SLO violations have consequences (release freezes, attention shifts), SLO definitions are reviewed (not stale), alerts are calibrated (not noise). Without that commitment, SLOs become theater — numbers reported but not acted upon.

The teams that internalize this discipline ship faster *and* more reliably than teams that don't. Faster, because the error budget gives them permission to take risks. More reliably, because budget burn forces real reliability work when it matters. The two stop being in conflict; they become explicit tradeoffs with a measurable currency.

That's SLOs. That's error budgets. That's alerting tied to user-facing reality. That's the practice that turns "is this important?" debates into "here's the burn rate" decisions — and that, in the long run, is what produces engineering organizations that survive scale.
