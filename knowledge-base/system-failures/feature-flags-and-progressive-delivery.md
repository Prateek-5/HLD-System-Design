# Feature Flags & Progressive Delivery

> *"Deploys used to be the unit of risk. A new release shipped to everyone, immediately, and either it worked or you rolled it back and apologized. Feature flags decoupled deploy from release. The new unit of risk is the cohort of users who see the new code first — and the discipline of growing that cohort as confidence grows."*

---

## Topic Overview

A feature flag (or feature toggle) is a runtime switch that controls whether a piece of code is active. Wrapping new functionality in a flag means you can deploy the code to production but keep it *off* — turning it on for some users, then more, then everyone. The deploy and the release are now two different events.

Progressive delivery is the broader practice this enables: gradual rollout to canaries, blast-radius-controlled feature releases, A/B experiments, kill switches, dark launches. The goal: ship code continuously to production while exposing customers to risk gradually and revocably.

Done well, feature flags transform engineering. Risk drops because rollback is a config change, not a deploy. Experiments become trivial. Failed features can be aborted in seconds. Done badly, feature flags become technical debt of staggering proportions — thousands of stale flags, branching logic nobody understands, "that flag was supposed to be removed last year" moments. The technique is powerful and demands discipline.

This is the topic where deployment practices become engineering tools. Mature teams treat feature flags as core infrastructure, with lifecycle policies, ownership, and observability. Teams without these end up with flag systems they fear to clean up.

---

## Intuition Before Definitions

Imagine renovating a hotel while guests are staying.

The old way: close the hotel, do the renovation, reopen. Guaranteed to be fully renovated when reopened. Also guaranteed: lost revenue, displaced guests, and if anything's wrong with the renovation, all guests experience it at once.

The new way: build new rooms behind a temporary wall. Open one renovated room first; one guest tries it; report back. Find a problem? Close it; fix it; open again. Working well? Open a few more. Eventually, all rooms are renovated, with the wall coming down progressively. Guests rarely notice; failures affect one room at a time.

That's progressive delivery. The hotel is your application. The renovated rooms are new features. The wall is the feature flag. The "one guest at a time" model is canary release. Failures are bounded; learning is incremental; the operation never closes.

The catch: you now have two versions of the hotel coexisting. Plumbing must work in both. Cleaning crews must navigate both. Light switches in renovated rooms work differently. Manage this complexity, and renovation is graceful. Lose track, and you have a maze.

---

## Historical Evolution

**Era 1 — Big-bang releases.**
1990s, early 2000s. Quarterly or yearly releases. Long QA cycles. Deploy = release. Failures meant full rollback. Teams shipped infrequently because shipping was scary.

**Era 2 — Continuous integration and frequent deploys.**
Late 2000s. Companies like Flickr (2009 famous "10+ deploys per day" talk) demonstrated continuous deployment. But each deploy still meant "this code is now live for everyone."

**Era 3 — Feature flag emergence.**
~2010-2014. Companies internally built flag systems. LaunchDarkly (founded 2014) productized them. The pattern spread.

**Era 4 — Progressive delivery vocabulary.**
~2018. James Governor (RedMonk) coined "progressive delivery." Frameworks (LaunchDarkly, Split.io, Optimizely) and practices (canary, blue-green, A/B) crystallized into a coherent discipline.

**Era 5 — Observability integration.**
2020+. Feature flags integrated with observability stacks: per-flag metrics, automatic anomaly detection, automatic rollback on SLO violation. The flag becomes a deployment unit with its own monitoring.

**Era 6 — Platform maturity.**
Modern platforms (LaunchDarkly, ConfigCat, Flipt, Unleash) handle large flag inventories, governance, audit logs, integration with CI/CD. Self-service for engineering teams; central oversight for ops.

The pattern: each generation reduced the unit of risk. From "the whole release" to "the whole deploy" to "this specific feature for this specific cohort." The technical capability and the cultural practice co-evolved.

---

## Core Mental Models

**1. Deploy ≠ release.**
A deploy puts code in production. A release exposes code to users. With flags, these are separable. Deploy continuously; release deliberately.

**2. The unit of risk is the user cohort.**
A new feature behind a flag exposes risk to whoever sees it. Limit the cohort initially; grow as confidence grows. 1% → 10% → 50% → 100% is a typical ramp.

**3. Flags have lifecycles.**
A flag is created for a purpose; serves it; should be removed. Stale flags are technical debt. The flag system needs lifecycle policies as much as the code does.

**4. Flags are configuration, not code.**
Changing a flag should not require a deploy. The flag system is part of runtime; misconfigured flags can take down the system as effectively as bad code.

**5. The goal is reducing blast radius, not avoiding bugs.**
Bugs will ship. Flags ensure bugs affect 1% of users for 5 minutes, not 100% for 5 hours. Mean-time-to-recover collapses from hours to minutes.

---

## Deep Technical Explanation

### Types of feature flags

**Release flags.** Wrap new functionality during rollout. Removed once feature is fully deployed.

**Experiment flags.** A/B test variants. Same code path, different behavior per cohort.

**Operational flags.** Performance toggles (e.g., "enable expensive logging"), kill switches for problematic features. Typically permanent.

**Permission flags.** Entitlement-based ("premium features for paid users"). Permanent.

**Canary flags.** Gradual rollout based on user identity, region, or random hash. Removed once rollout is complete.

The lifecycle model differs by type. Release flags are short-lived (days to weeks). Experiment flags last for the experiment duration. Operational and permission flags are intentionally permanent.

### Flag implementation

Basic shape:

```python
if flag_service.is_on("new-checkout-flow", user_id):
    new_checkout_flow(...)
else:
    old_checkout_flow(...)
```

The flag service determines whether the flag is "on" for a given context. Common targeting:

- **Boolean flag**: globally on or off.
- **User-list targeting**: specific users see the new flow.
- **Percentage rollout**: hash(user_id) modulo bucket; 10% of users in the new flow.
- **Attribute-based**: users in region X, on plan Y, etc.
- **Multi-variant**: A/B/C testing with multiple branches.

The flag service is queried per-request (or cached locally with periodic refresh). Cache invalidation matters: a flag flip should propagate within seconds, not minutes.

### Targeting consistency

Critical: a user should see the same flag value across requests within a session. Otherwise UI breaks ("first request: new flow; second: old flow"). Achieved by hashing on a stable user ID, not random.

```
flag_value = hash(user_id + flag_key) % 100 < rollout_percentage
```

Hashing the user ID + flag key produces a stable result per (user, flag) pair. Rollout percentages can grow without changing previously-included users.

### Flag service architectures

**Library-based, push.**
Service polls a central config store; receives flag updates via push (long-poll, websocket). Decision is local; no per-request network call.

**Library-based, pull.**
Service queries flag service per request (or batch). Network cost; freshest data; central decision-making possible.

**Centralized API.**
Application calls flag service for every decision. Highest network cost; centralized logic; single point of failure.

Most modern systems are push-based: SDK in the application caches flag rules and updates them in real time via streaming.

### Canary releases

A specific progressive-delivery pattern:

1. Deploy new version to a small subset of instances (the "canary").
2. Send a small fraction of traffic to the canary.
3. Compare canary metrics (errors, latency, business metrics) against control.
4. If healthy: ramp traffic up.
5. If unhealthy: roll back; 0% traffic to bad version.

Different from feature flags, but complementary. Canary tests the *deploy* (entire codebase change). Feature flags test individual *features*.

Tools: Argo Rollouts, Flagger, AWS App Mesh canary deployments.

### Blue-green deployments

Two identical production environments. New version goes to "green"; production traffic stays on "blue." Switch traffic to green; if problems, switch back to blue.

Properties:
- **Instant rollback**: just route traffic.
- **Resource cost**: 2× capacity during transition.
- **Long-running connections**: tricky during cutover.
- **Database schema migrations**: must work on both versions.

Less common than canary at large scale (cost), more common than canary for stateful services.

### A/B testing

Statistical comparison of variants:
- Half users see A; half see B.
- Measure outcome metrics (conversion, latency, etc.).
- Determine if difference is statistically significant.
- Choose winner.

Critical considerations:
- **Sample size**: need enough users for statistical power.
- **Duration**: must run long enough to capture variance.
- **Segmentation**: results may differ across user types.
- **Novelty effects**: short-term reaction differs from steady-state.
- **Multiple comparisons**: testing many variants increases false-positive risk.

Mature A/B testing requires data science discipline. Naive testing produces "winning" results that don't replicate.

### Kill switches

Operational flags for emergency:
- "Disable analytics writes" if database is overloaded.
- "Disable feature X" if it's causing customer complaints.
- "Throttle to 50%" if load spikes.

These flags are *permanent infrastructure*. They live forever. They're part of the operational toolkit. Naming, ownership, and runbook documentation matter.

### Dark launches

Deploy new functionality but don't expose it to users — yet. Run it in shadow:
- New API code runs alongside old; results compared but not returned.
- Validates correctness and performance before customer exposure.
- Useful for risky migrations (database, large refactors).

### Flag debt

Every flag has a cost:
- Code paths to maintain.
- Cognitive load for engineers reading the code.
- Test combinations (with flag on, with flag off, with mixed flags).
- Risk of using a stale flag accidentally.

The discipline:
- **Set TTL on release flags** at creation: "this flag will be removed by date X."
- **Track active flags**: dashboard of all flags, age, last-toggled, owner.
- **Periodic audits**: review for stale flags; assign cleanup.
- **Cleanup as you go**: when a feature is fully rolled out, remove the flag and the dead branch.

Companies routinely accumulate hundreds or thousands of flags. Cleanup discipline determines whether the codebase stays healthy or becomes a maze.

### Observability

Each flag should have associated metrics:
- **Exposure**: how many users see each variant.
- **Impact**: error rate, latency, business metric, per variant.
- **Anomaly detection**: automatic comparison; alert on regression.
- **Audit log**: who toggled, when, from where.

Modern flag platforms automate much of this. Custom systems must build it.

---

## Real Engineering Analogies

**The retail "soft launch."**
A retailer opens a new product line in one store first. If it sells, they expand to a region. If it does well, nationally. Bad reception in the test store? Pull the line; reformulate. Far cheaper than launching nationally and discovering the same thing.

That's a feature flag. The new product is the new code. The test store is the canary cohort. National rollout is 100%.

**The medical clinical trial.**
A new drug isn't released to everyone at once. Phase 1: small group. Phase 2: larger. Phase 3: large randomized trial. At each phase, side effects are monitored; the drug can be pulled if problems emerge.

Software's progressive delivery is the same risk-management strategy. The cost of "all customers immediately" is too high; the cost of "phased exposure" is some complexity in management.

---

## Production Engineering Perspective

What goes wrong:

- **The flag that became dead code.** Feature rolled out years ago. Flag is "always on." Branch for "off" still exists. New engineer reads the code and is confused. Multiply by 1000 flags. Codebase is incomprehensible.
- **The kill switch that didn't.** Engineer needs to disable a feature urgently. The flag system is misconfigured (or itself depending on the failing feature). Rollback takes 10 minutes instead of 10 seconds. Lesson: flag system must be more reliable than the features it gates.
- **The flag dependency disaster.** Flag A's value depends on Flag B's value. B is toggled; A's behavior changes unexpectedly. Cascading flag effects nobody expected.
- **The targeting inconsistency.** A user is bucketed into the new feature on web; the bucketed-out on mobile. Same user; different experience. Confusion. Lesson: hash on a *globally* stable ID, not session-specific.
- **The metric blindness.** New feature ships behind a flag. No metrics differentiated by variant. Team can't tell if it's hurting; rolls out fully; only then notices the regression. Lesson: per-variant metrics from day one.
- **The flag that controls infrastructure.** Flag set wrong; entire service broken. Lesson: critical flags need extra protections (multiple approvers, gradual rollout of flag changes).
- **The flag-as-code-comment.** Flag named "WIP_NEW_THING" with no description. Six months later, nobody knows what it does. Toggle? At your peril. Lesson: rich metadata; ownership; documentation.

The senior engineer's habits:
- **TTL every release flag** at creation.
- **Automated cleanup** of flags past TTL.
- **Per-variant metrics** by default.
- **Targeting consistency** (stable user ID hashing).
- **Flag dependencies tracked** explicitly.
- **Critical flags have safeguards** (slow rollout, approval).
- **Flag platform is uptime-critical** infrastructure.

---

## Failure Scenarios

**Scenario 1 — The flag-controlled outage.**
Engineer toggles flag "ENABLE_NEW_AUTH_FLOW" to 100%. New auth flow has bug; all login attempts fail. Toggle back: outage lasted 4 minutes. Without the flag, would have been a deploy + rollback: 30 minutes. The flag system worked as designed.

**Scenario 2 — The flag dependency tangle.**
Flag A controls a query format. Flag B controls a parsing layer. They were rolled out together. Six months later, someone toggles A independently. B's parser doesn't handle the old format anymore. Production errors. Investigation: undocumented flag dependency.

**Scenario 3 — The targeting bug.**
A flag uses session ID for hashing. User logs out and back in: new session ID; possibly new flag bucket. UI changes mid-flow; cart contents lost. Fix: hash on user ID, not session.

**Scenario 4 — The flag platform outage.**
Flag service goes down. Application's flag SDK times out on flag lookups. Default behavior was "treat unknown flags as off." Critical flags now off; service degraded. Lesson: default flag values; SDK fallbacks; graceful degradation when flag service is down.

**Scenario 5 — The accumulated flag debt.**
Codebase has 4000 flags. 80% are stale (rolled out years ago, never removed). New engineers struggle to read code. Bugs from outdated flag combinations. Cleanup project: 6 months of dedicated effort. Lesson: TTL discipline from day one.

---

## Performance Perspective

- **Flag evaluation**: typically microseconds with cached rules.
- **SDK overhead**: small per-request; rules cached locally.
- **Network calls**: avoided by SDK push model; batch where unavoidable.
- **Conditional code paths**: branch prediction may suffer; usually negligible.

---

## Scaling Perspective

- **Flag count**: hundreds to thousands at large companies.
- **Evaluation rate**: scales with request rate; SDK caches handle it.
- **Configuration changes**: must propagate within seconds across fleet.
- **Audit volume**: every toggle logged; storage costs.
- **At hyperscale**: dedicated flag platform team; integration with CI/CD, observability, incident response.

---

## Cross-Domain Connections

- **Cascading failures**: flags are the kill switches that prevent cascades. (See [cascading-failures-and-circuit-breakers.md](./cascading-failures-and-circuit-breakers.md).)
- **Postmortems**: many incidents are mitigated by flag toggles; flag system effectiveness is itself a postmortem topic. (See [postmortems-and-incident-response.md](./postmortems-and-incident-response.md).)
- **Chaos engineering**: flags enable controlled failure injection. (See [chaos-engineering-and-game-days.md](./chaos-engineering-and-game-days.md).)
- **SLOs**: flag rollouts are guarded by SLO compliance; auto-revert on burn rate. (See [slos-error-budgets-and-alerting.md](../observability/slos-error-budgets-and-alerting.md).)
- **A/B testing**: a flag variant is the unit of experimentation.
- **Microservices**: each service has its own flags; cross-service flag coordination is a challenge.

The unifying observation: **feature flags decouple risk from deploy by making release a runtime decision. Every other reliability practice composes with this — chaos, SLOs, observability, postmortems all work better when flags exist.**

---

## Real Production Scenarios

- **Facebook's gatekeeper system**: pioneered large-scale feature gating. Internal system; no public open-source.
- **Google's experiment infrastructure**: extensive A/B testing; documented in research papers.
- **LaunchDarkly's customer base**: many public case studies.
- **Etsy's "Atlas" feature flags**: open-source; influential design.
- **Netflix's chaos engineering + flags**: combined for runtime control of failure injection.
- **GitHub's progressive rollout patterns**: documented public engineering posts.

---

## What Junior Engineers Usually Miss

- That **flags must be removed** after rollout.
- That **flag systems are critical infrastructure** themselves.
- That **targeting consistency** requires stable hashing.
- That **per-variant metrics** are mandatory.
- That **flag dependencies** must be tracked.
- That **kill switches** are permanent infrastructure.
- That **deploy ≠ release**.
- That **flag debt is real** and accumulates.

---

## What Senior Engineers Instinctively Notice

- They **set TTLs on release flags**.
- They **track flag age** and clean up.
- They **wire metrics per variant**.
- They **hash on stable identifiers**.
- They **document flag dependencies**.
- They **treat flag platform as uptime-critical**.
- They **integrate flags with SLO-based auto-revert**.
- They **distinguish flag types** and lifecycle them appropriately.

---

## Interview Perspective

What gets tested:

1. **"What's a feature flag?"** Tests basic literacy.
2. **"How do you implement consistent targeting?"** Stable user ID hashing.
3. **"How do you handle flag debt?"** TTL, dashboards, cleanup discipline.
4. **"Canary vs blue-green vs feature flags?"** Different scopes; complementary.
5. **"What's progressive delivery?"** Gradual rollout; risk reduction.
6. **"How do you measure a feature's impact?"** Per-variant metrics.
7. **"What's a kill switch?"** Operational toggle for emergency.

Common traps:
- Believing feature flags are temporary code only.
- Not setting TTLs.
- Hashing on session ID (inconsistent).

---

## 20% Knowledge Giving 80% Understanding

1. **Deploy ≠ release** with feature flags.
2. **Flags have lifecycles**; remove release flags promptly.
3. **Stable hashing** for consistent targeting.
4. **Per-variant metrics** mandatory.
5. **Kill switches are permanent infrastructure.**
6. **Flag platform must be highly reliable.**
7. **Progressive rollout**: 1% → 10% → 50% → 100%.
8. **Auto-revert on SLO breach**.
9. **TTL release flags** at creation.
10. **Flag debt accumulates**; manage actively.

---

## Final Mental Model

> **Feature flags turn deployment from a binary risk into a controlled experiment. The deploy puts code in production; the flag controls who sees it; the metrics tell you whether to ramp up or roll back. Mean-time-to-recover collapses from hours to seconds. The cost: discipline. Without it, you trade deploy risk for flag debt.**

The senior engineer using flags treats them as a tool with a contract: every flag has an owner, a TTL, a metrics setup, a removal plan. The flag system itself is critical infrastructure. The combination — disciplined flags + observability + SLO-driven auto-revert — is what allows mature teams to deploy hundreds of times a day with low risk.

Teams that don't internalize this end up with two failure modes: either they don't use flags (and have deploy fear) or they use flags without discipline (and have flag debt). The mature middle is *flags-as-code*: lifecycle managed, observability included, cleanup automatic, the platform itself uptime-critical.

That's feature flags. That's progressive delivery. That's the practice that turns "scary deploy night" into "Tuesday afternoon's continuous-delivery flow."
