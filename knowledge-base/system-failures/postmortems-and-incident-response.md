# Postmortems & Incident Response

> *"Every outage is a teacher. The team that responds well during the incident, then learns from it after, builds better systems over time. The team that scrambles, blames individuals, and skips the postmortem learns nothing — and re-encounters the same failures, by different names, forever."*

---

## 🎯 Start Here — Intuition

> **In one line:** how a team should act *while* something is on fire (stop the damage fast, with clear roles) and *afterward* (calmly figure out why, fix the real cause, and not blame anyone).
>
> **Analogy:** a house fire with a fire drill and a follow-up. During the fire, one person calls 911, one uses the extinguisher, one gets the kids out — nobody screams because everyone knows their job. A week later you sit down calmly: why was the stove unattended? Why was the smoke detector dead? You fix the *system* (new timers, battery checks) instead of arguing about whose fault it was.
>
> **Assumes you already know:** what "availability" / uptime means (see [`learn/foundations/scaling/availability.md`](../../learn/foundations/scaling/availability.md)), and SLAs/SLOs/SLIs (see [`learn/reliability/sla-slo-sli.md`](../../learn/reliability/sla-slo-sli.md)). Disaster recovery is a useful neighbor (see [`learn/reliability/disaster-recovery.md`](../../learn/reliability/disaster-recovery.md)).
>
> **Level:** this file is 🟡 overall — it is process/culture, not deep code, so most of it is reachable. Sections below are tagged. If the basics feel shaky, that tag is your signal to slow down — **you are not behind.**

---

## Topic Overview 🟢

Incident response and postmortems are the operational disciplines that turn outages from disasters into education. The first half — incident response — is the structured, time-pressured work of mitigating customer impact when something is broken. The second half — postmortems — is the reflective, time-deferred work of understanding *why* it broke and what should change.

Most engineering organizations do both badly. Incident response is ad-hoc — whoever's awake handles it, with no roles, no comms structure, no clear command. Postmortems are blame-fests, missing critical detail, or skipped entirely because "we already know what happened." The mature practices are well-documented (Google SRE (Site Reliability Engineering), AWS (Amazon Web Services), Facebook's PEACE framework) but require organizational commitment that not every company makes.

This is the topic where reliability transitions from a technical concern to an organizational one. You can't engineer your way to reliability without the disciplines that handle the unreliability when it inevitably appears. And the postmortem culture — blameless, thorough, follow-up-driven — is what determines whether your system gets more reliable over time or repeats the same incidents in slightly different costumes.

---

## Intuition Before Definitions 🟢

Imagine your kitchen catches fire.

**Bad incident response.** Three people in the house run around screaming. One grabs water. Another grabs a fire extinguisher but doesn't know how to use it. Someone calls 911 but can't articulate the address. The fire spreads. By the time it's put out, the kitchen is gone.

**Good incident response.** One person calls 911 with the address ready. One person grabs the extinguisher and uses it correctly. One person evacuates the kids and pets. There's no screaming because everyone knows their role. The fire is contained quickly.

**Bad postmortem.** "I told you not to leave the stove on!" "Well, you should have noticed sooner!" Family argues. No fire safety changes. Same fire happens six months later when someone leaves the toaster on.

**Good postmortem.** Sit down a week later. Look at the timeline. Why was the stove on unattended? Because the dog needed urgent attention. Why was the smoke detector silent? Battery was dead. Action items: install GFI (Ground Fault Interrupter)-cutoff stove timers, check all smoke detector batteries quarterly, train kids on extinguisher use. No blame; structural improvements.

That's the entire framework. Speed and clarity during the incident; calm and structure afterward. The teams that do both right have fewer fires, smaller fires, and faster response when fires do happen.

---

## Historical Evolution 🟡

**Era 1 — The hero culture.**
Pre-2000s. "We had an outage; Bob was up all night fixing it; everyone celebrate Bob." Incidents are individual, dramatic events. Lessons rarely captured. The same problems recur.

**Era 2 — The "war room."**
Late 1990s, 2000s. Operations teams formalize "incident calls" — bridge calls with multiple participants. Better than chaos; lacks structure. Often dominated by senior engineers shouting; junior engineers contribute little.

**Era 3 — Blameless postmortems.**
2010s. Etsy's John Allspaw popularizes "Blameless PostMortems and a Just Culture" (2012). The realization: blame produces silence and lies; blamelessness produces honest analysis and durable improvements.

**Era 4 — Incident command structures.**
~2015 onward. Models from emergency response (FEMA's (Federal Emergency Management Agency) Incident Command System) imported to software. Explicit roles: Incident Commander, Comms Lead, Operations Lead. Becomes standard at large tech orgs.

**Era 5 — The Google SRE codification.**
SRE Book (2016) and SRE Workbook (2018). Google's practices documented in detail: error budgets, postmortem templates, role definitions, action item tracking. Wide industry adoption.

**Era 6 — Tooling and integration.**
Modern systems integrate incident response into the engineering stack: PagerDuty, Incident.io, FireHydrant, Rootly. Automated runbooks, status pages, post-incident reviews. Practice professionalizes.

The pattern: incident response evolved from heroic to structured to tool-supported. Postmortems evolved from blame to learning. The progress is real but uneven across the industry.

---

## Deep Technical Explanation 🔴

⚠️ The rest assumes the basics above are solid.

### Incident severity levels

Most organizations classify incidents:

- **Sev-1 (Severity 1) / P0 (Priority 0)**: critical customer impact; major feature down; revenue impacting. All hands.
- **Sev-2 / P1**: significant customer impact; some users affected; degraded experience. Active response.
- **Sev-3 / P2**: minor impact; workaround exists; not customer-visible at scale. Scheduled response.
- **Sev-4 / P3**: internal-only; minor issue; can wait. Track but no urgency.

Levels drive response: who's paged, what comms goes out, whether all hands stop work. Calibration matters: Sev-1 should be rare and undeniable.

### The Incident Command System (ICS)

Borrowed from emergency response. Roles during an active incident:

- **Incident Commander (IC)**: owns the response. Makes decisions. Doesn't fix the problem personally — that's the Ops Lead's job. Coordinates the team.
- **Operations Lead (Ops)**: actually does the technical mitigation work.
- **Communications Lead (Comms)**: updates internal channels, customer status pages, executives. Frees the Ops Lead to focus.
- **Scribe**: records timeline. Critical for postmortem; otherwise everything is reconstructed from memory.
- **Subject Matter Experts (SMEs)**: pulled in as needed for specific systems.

The IC is *not necessarily* the most senior engineer. Often a more junior engineer who's been trained for the role — they're not solving the problem, they're coordinating those who do.

Critical principle: **the IC's job is to say "what's our next move?"** not "what's the answer?" Different skill set. Removes a single point of failure (the most-knowledgeable engineer being also the coordinator).

### Communication during incidents

Comms structure:

- **Internal channel**: dedicated Slack/Teams channel for the incident. All updates flow here.
- **Status page**: customer-facing. Acknowledge the incident; update at intervals; resolve when done.
- **Executive updates**: someone (Comms Lead, IC) keeps leadership informed. Don't let executives interrupt the response.
- **Postmortem promise**: "we'll publish a postmortem within X days."

The cadence: every 15-30 minutes during active response. Shorter intervals when things are changing; longer when stable.

The discipline: **structured updates**. "Status: investigating. Last known: payment service degraded since 14:23 UTC (Coordinated Universal Time). Working theory: database overload. Next step: scaling DB. ETA on resolution: 30 min." Bad updates are vague ("we're looking into it"); good updates are concrete.

### Mitigation before understanding

Classic mistake: spending an hour debugging while customers suffer. The right sequence:

1. **Detect**: alerts fire; on-call paged.
2. **Mitigate**: stop the bleeding. Roll back the deploy. Disable the feature flag. Drain the bad node. Restart the process.
3. **Understand**: now investigate root cause.
4. **Resolve**: implement the fix.
5. **Confirm**: verify mitigation; remove temporary measures.

Rolling back is almost always the right immediate move when the deploy correlation is clear. "Was a deploy made in the last hour? Roll it back." Instinct, not investigation.

### The 5 Whys

A simple but powerful technique:

> **Symptom**: customers couldn't check out for 12 minutes.
> Why? Payment service returning 500 (HTTP Internal Server Error).
> Why? Database connection pool exhausted.
> Why? A new query took 30s instead of 30ms.
> Why? Missing index on a new table.
> Why? Schema migration didn't run the index creation step.
> Why? Migration was split into two PRs (Pull Requests); the second was deployed first.

Six "whys" deep, the root cause is a deployment process gap, not "a missing index." Action items target the process, not just the symptom.

The discipline: **don't stop at the first "why."** The first answer is always proximate. The deeper answers are where systemic improvements live.

### Blameless postmortem template

A complete postmortem typically has:

1. **Summary**: 2-3 sentences. What happened, when, customer impact.
2. **Timeline**: minute-by-minute reconstruction. Who did what when.
3. **Impact**: customers affected, revenue lost, SLA implications.
4. **Detection**: how was it noticed? Was it as fast as possible?
5. **Response**: what was done? Was it the right move? Was the team prepared?
6. **Root causes**: 5 Whys output. Often multiple intersecting causes.
7. **Action items**: specific, owned, dated. What will change?
8. **Lessons**: takeaways for the broader org.

Length: typically 5-15 pages for significant incidents. Shorter for minor ones. Templated so postmortems are comparable.

### Action items

The most important — and most often-fumbled — part:

- **Specific**: "Improve monitoring" is not an action item. "Add alert for connection pool > 80% utilization" is.
- **Owned**: a single person responsible.
- **Dated**: when will it be done?
- **Tracked**: in a system (JIRA (issue-tracking tool by Atlassian), Linear, etc.) with the postmortem as parent.
- **Reviewed**: monthly check on completion.

Postmortems with un-completed action items 6 months later are common — and a sign of organizational dysfunction. The action items must matter, must be tractable, must be followed up.

### Blame culture vs learning culture

In a blame culture:
- Engineers hide details that might implicate them.
- Postmortems are politically negotiated.
- The same mistakes recur because their causes are obscured.
- Senior engineers avoid risky work.

In a learning culture:
- Engineers volunteer "I made the change that broke this."
- Postmortems include uncomfortable truths.
- Improvements are shipped because causes are visible.
- Risk-taking is calibrated, not avoided.

The transition takes years. It requires explicit leadership commitment ("we will not punish individuals for honest mistakes in this postmortem"). Backsliding is easy; one punitive response can poison the culture.

### MTTR, MTBF, and the metrics

- **MTTR (Mean Time To Recovery)**: average time from detection to mitigation. Lower is better.
- **MTBF (Mean Time Between Failures)**: average time between incidents. Higher is better.
- **MTTD (Mean Time To Detection)**: how fast did we notice?
- **Toil**: amount of manual operational work; should decrease as automation improves.

Each is imperfect. MTTR can be gamed by classifying things differently. MTBF depends on your definition of incident. Use them as trends, not absolutes.

The ratio MTTR / MTBF gives a rough availability number. 1 hour MTTR with 1 month MTBF is ~99.86% availability. To reach ~99.99% you need to cut downtime by ~10×: e.g., hold MTTR at 1 hour but push MTBF to ~1 year, or keep the 1-month MTBF but drop MTTR to ~5 minutes. Either lever works only when you state the other.

---

## Real Engineering Analogies 🟢

**The hospital ER.**
A patient arrives critical. The ER team has a structured response: triage assesses severity; resuscitation team stabilizes; specialists called as needed; one attending is in command. After: morbidity and mortality conferences (M&M) review what went wrong, blame-free, with action items for the hospital's protocols.

This is exactly incident command + postmortem. The ER didn't invent these practices for software; software borrowed them from medicine, which had borrowed them from emergency response, which had borrowed them from the military. The pattern is older than computing.

**The aviation safety system.**
Every aircraft accident is investigated. Pilots, mechanics, controllers — all interviewed. The result is a public NTSB (National Transportation Safety Board) report with system recommendations. Pilots are *protected* from blame for honest reports of near-misses; the data feeds back into safer operations.

The aviation industry's safety record (now astonishing) is a result of decades of this discipline. Software's reliability culture aspires to it. The principles transfer directly.

---

## Production Engineering Perspective 🔴

What goes wrong:

- **The incident with no IC.** Five engineers all trying to fix the problem. None coordinating. Actions step on each other. Nobody updating customers. Mitigation takes 4× longer than it should.
- **The "fix-forward" instead of rollback.** A deploy correlated with the outage. Engineer believes the bug is identified and ships a fix. Fix has its own bug. Now two changes to debug. Lesson: roll back first; fix later.
- **The skipped postmortem.** "We know what happened; let's move on." Six months later, similar incident. Same root cause. No durable learning happened.
- **The blame retrospective.** Postmortem becomes a meeting where the team blames the engineer who pushed the change. Engineer leaves the company. Nothing structural changes. Same incident in 8 months.
- **The action items rotting.** Postmortem produces 12 action items. After 6 months, 1 is done. Same kinds of incidents recur. Tracked but not enforced.
- **The over-paging.** Every minor anomaly pages someone. Pager fatigue. Real incidents missed because oncall is desensitized. Mitigation: tier alerts; only page on user-facing impact.
- **The runbook that doesn't exist.** During incident: "where's the failover procedure?" Nobody knows. Twenty minutes of finding the right wiki page. Lesson: runbooks live next to alerts; tested regularly.
- **The 4am panic.** No clear roles. Senior engineer woken up. Tries to do everything. Burns out. Three months later, the senior engineer leaves. Cause: missing IC role to coordinate.

The senior SRE/operator's habits:
- **Clear roles** in every incident.
- **Mitigation before investigation.**
- **Templated postmortems** for consistency.
- **Action items tracked** to completion.
- **Pager budget** monitored.
- **Runbooks tested** during game days.
- **Blameless culture** enforced from leadership.

---

## Failure Scenarios 🟡

**Scenario 1 — The unstructured response.**
Major outage. 8 engineers in a Slack channel. Some are trying to roll back; others are debugging the new code; others are restarting services. Conflicting actions. Customer impact extends an extra 45 minutes due to coordination chaos. Lesson: ICS structure with one IC.

**Scenario 2 — The political postmortem.**
Outage caused by a change owned by Team A but triggered by traffic from Team B. Postmortem becomes a negotiation: who gets blamed? Action items are watered down. Same incident pattern recurs in 4 months when neither team improves their interface contract. Lesson: blameless analysis; both teams own structural improvements.

**Scenario 3 — The action item graveyard.**
30 postmortems over a year, each with 5-10 action items. Tracking shows 20% completion rate. The high-impact action items remain undone. Outages of identified types continue. Recovery: dedicated capacity for "operational debt" each sprint; aging action items escalated.

**Scenario 4 — The pager fatigue.**
Team's on-call rotation pages 20 times per night on average. Most are non-issues. Real incident occurs at 3am; oncall snoozes the alarm out of habit. Customer impact extends 2 hours. Recovery: alert audit; cull non-actionable; tier severity.

**Scenario 5 — The hero engineer who left.**
One senior engineer is the de facto incident commander for every Sev-1. They burn out and resign. The next major incident has no IC; response is chaotic. Lesson: distribute IC training; rotate the role; document context.

---

## Performance Perspective 🟡

- **MTTD optimization**: invest in monitoring and alerting. Faster detection compounds.
- **MTTR optimization**: practiced runbooks; automated recovery; clear roles.
- **Postmortem quality**: a 2-page postmortem may capture less than a 10-page one. But a 10-page postmortem with no follow-through is worse than a 2-page one with completed action items.
- **Process overhead**: incident response structure has cost (training, on-call rotation). Worth it past a certain scale; overkill for tiny teams.

---

## Scaling Perspective 🟡

- **Small teams (<20 engineers)**: lightweight process. One on-call rotation. Templated postmortems. Quarterly review.
- **Medium teams (20-200 engineers)**: dedicated IC training. Multiple on-call rotations. Centralized postmortem repository. Regular reviews.
- **Large orgs (200+ engineers)**: dedicated SRE/reliability team. Incident management tooling. Cross-team postmortems. Weekly action-item reviews.
- **Hyperscale**: continuous incident command training. Postmortem library serves as institutional memory. Reliability metrics tied to engineering velocity.

---

## Cross-Domain Connections 🔴

- **Cascading failures**: incidents are often cascades; understanding the cascade is the postmortem's analysis. (See [cascading-failures-and-circuit-breakers.md](./cascading-failures-and-circuit-breakers.md).)
- **Chaos engineering**: prevents the incidents you'd otherwise have postmortems about. The two are complementary disciplines. (See [chaos-engineering-and-game-days.md](./chaos-engineering-and-game-days.md).)
- **Observability**: detection speed is downstream of monitoring quality. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)
- **SLOs**: incident severity is calibrated against SLOs. (See [slos-error-budgets-and-alerting.md](../observability/slos-error-budgets-and-alerting.md).)
- **Distributed tracing**: critical for incident investigation. (See [distributed-tracing-deep-dive.md](../observability/distributed-tracing-deep-dive.md).)
- **Microservices**: more services = more failure modes = more postmortems. (See [microservices-vs-monolith.md](../architecture-patterns/microservices-vs-monolith.md).)
- **Timeouts/retries/idempotency**: configuration of these is often the cause OR the fix in postmortems. (See [timeouts-retries-and-idempotency.md](./timeouts-retries-and-idempotency.md).)

The unifying observation: **postmortems are the feedback loop that improves all other engineering disciplines. Without them, you make the same mistakes forever; with them, the system gets better over time.**

---

## Real Production Scenarios 🟡

- **Google's SRE postmortem culture**: extensively documented in the SRE book. Templated, blameless, action-item-tracked. Reference for the industry.
- **AWS public postmortems**: the S3 (Simple Storage Service) outage of 2017, the DynamoDB outage of 2015, others. Public, detailed, instructional.
- **GitLab's "we lost data" postmortem (2017)**: an extraordinarily transparent public postmortem of a multi-hour data-loss incident. Required reading.
- **Etsy's "Just Culture" article (Allspaw)**: foundational text on blameless postmortems.
- **Cloudflare's transparent postmortems**: regular, detailed, customer-facing. Builds trust.
- **The "operational excellence" practices at Stripe and others**: published case studies on incident review processes.

---

## Key Takeaways

- **Incidents have phases — and roles change with phase**: Detection → Response → Mitigation → Recovery → Postmortem → Action items. Clear handoffs prevent one overloaded person doing all of it.
- **Mitigate first; understand second.** Stop the bleeding (roll back, disable flag, drain node, restart) before root-cause analysis. There isn't time for both during the outage.
- **Roll back deploy-correlated outages immediately** — fixing forward risks a second bug and two changes to debug.
- **Use the IC structure** for any non-trivial incident: IC coordinates ("what's our next move?"), Ops mitigates, Comms updates, Scribe records. The IC's job is coordination, not solving — and need not be the most senior engineer. **Train juniors as ICs and rotate the role** to remove the single-point-of-failure hero.
- **Maintain calm, structured comms**: concrete status updates every 15-30 min, not "we're looking into it."
- **Blameless ≠ accountability-free.** Don't assume an individual's intent or competence was the failure; the team still owns the system and follows through on changes. Postmortems are **systems analysis, not blame meetings** — blame produces silence and lies; blamelessness produces honest analysis. The cultural transition takes years and one punitive response can poison it.
- **Use the 5 Whys** — don't stop at the first (proximate) "why"; the deeper answers are where systemic fixes live (e.g., a "missing index" is really a deploy-process gap).
- **Action items are the only durable output.** Make them specific, owned, dated, tracked, and reviewed to completion. Un-completed action items 6 months later signal organizational dysfunction.
- **MTTR / MTBF / MTTD** are your operational metrics — use them as trends, not absolutes. MTTR/MTBF gives a rough availability figure.
- **Manage alert fatigue ruthlessly**: tier alerts; only page on user-facing impact, or oncall desensitizes and misses real incidents.
- **Runbooks live next to alerts** and are tested regularly (e.g., during game days), so failover procedures aren't hunted for mid-incident.

> **An outage is a teacher.** The team that listens — responding well, then learning calmly — gets more reliable over time; the team that doesn't has the same outage forever in different costumes. Reliable systems come not from smarter engineers but from teams who've internalized these unglamorous disciplines.

---

## Interview angle 🟡

Commonly tested questions:

1. **"How does your team handle incidents?"** — looks for experience with structured response.
2. **"Walk me through a postmortem you wrote."** — practical experience.
3. **"What's a blameless postmortem?"** — conceptual understanding.
4. **"What are the 5 whys?"** — technique knowledge.
5. **"What's MTTR and MTBF?"** — vocabulary.
6. **"How do you avoid alert fatigue?"** — operational maturity.
7. **"What's the IC's role?"** — coordination, not problem-solving.

Common traps: believing postmortems are about assigning blame; skipping the IC role; not tracking action items.
