# Chaos Engineering & Game Days

> *"You cannot build a reliable system. You can only test one. Reliability is not a property of code; it's a property of code that has been actively, deliberately, and repeatedly broken — and then fixed before customers noticed."*

---

## Topic Overview

Chaos engineering is the practice of *deliberately* breaking parts of your production (or production-like) system to discover how it fails before customers do. It sounds reckless. It's actually the opposite — it's the discipline of accepting that failures are inevitable and choosing to encounter them on your terms, in business hours, with the on-call engineer warmed up, rather than at 3am during a customer launch.

Game days are the structured version: scheduled exercises where teams inject failures and observe how the system (and the team) responds. Both practices share the same core insight: *the only resilience features that work are the ones that have been tested with real failures*. Untested failover is broken failover. Untested retries amplify. Untested circuit breakers don't trip. Untested runbooks don't help.

This is the topic where reliability engineering moves from theory to practice. Every other defensive pattern in the knowledge base — circuit breakers, retries, timeouts, sagas, replication, supervision — assumes the failure paths actually work. Chaos engineering is the discipline of *proving* that assumption, regularly, on purpose.

---

## Intuition Before Definitions

Imagine you're hired to ensure a building never burns down.

You install fire suppression systems, smoke detectors, sprinklers, fire-rated walls, evacuation routes. You write evacuation procedures. You hire fire wardens. You're confident. You sleep at night.

Then one day a small kitchen fire starts. The sprinklers turn out to be on a different water main that was shut off for plumbing work. The smoke detectors trigger but their batteries are dead. The fire wardens are trained but never practiced. The evacuation route map is in a closed cabinet. The actual evacuation is chaos.

The mistake wasn't the design. The design was reasonable. The mistake was *never testing the system in failure mode*. Every individual feature worked in isolation, in pristine conditions. None of them had been exercised together, in realistic conditions, by people who would actually be present during the fire.

Chaos engineering is the fire drill — but for software. You don't wait for the kitchen fire. You light a small, controlled fire (in a safe place, with safety nets) and watch what happens. Sprinklers don't engage? Discover that on Tuesday at 10am with the plumber on standby, not at 3am with a real fire.

Game days are the *coordinated* fire drill: the whole team is there, the failure is announced, the response is observed and critiqued. Not "did the system survive?" alone — "did *we* respond well? was the runbook helpful? did the alerts fire? did anyone find the dashboard fast enough?"

---

## Historical Evolution

**Era 1 — Ad-hoc disaster recovery testing.**
Decades of "let's bring down the database in dev and see what happens." Done occasionally, often not in production-equivalent environments, often by individual engineers without organizational support. Findings were rarely systematized.

**Era 2 — Netflix and Chaos Monkey.**
Netflix migrates to AWS (~2010-2011). Realizes their cloud architecture must tolerate instance failures because AWS instances *will* fail. Builds Chaos Monkey: a tool that randomly terminates production instances during business hours. Forces every service to be resilient by design, because the failure injection is constant.

**Era 3 — The Simian Army.**
Netflix expands to Chaos Gorilla (kills entire availability zones), Chaos Kong (entire regions), Latency Monkey (injects latency), Janitor Monkey (cleans unused resources). The principle: simulate every failure mode that could happen. Open-source the tools.

**Era 4 — Chaos engineering as a discipline.**
"Principles of Chaos Engineering" published (2015). Frames the practice as scientific: hypothesize about steady state, vary real-world events, observe deviations. The Chaos Engineering book (Rosenthal et al., 2017). Industry interest grows.

**Era 5 — Game days at Amazon, Google, Microsoft.**
Cloud providers adopt structured failure exercises. AWS publishes resilience patterns. Google's SRE book devotes chapters to disaster role playing (DiRT). Microsoft formalizes "fire drills" in Azure.

**Era 6 — Tooling and managed services.**
Gremlin (2016) productizes chaos engineering. AWS Fault Injection Simulator (2020). LitmusChaos (2018) for Kubernetes. Chaos engineering moves from "Netflix's cool thing" to mainstream cloud infrastructure tooling.

The pattern: each generation expanded the scope of what was deliberately tested, and made the tooling more accessible. The discipline went from "weird Netflix idea" to industry-standard reliability practice.

---

## Core Mental Models

**1. Failures are not exceptional; they're routine.**
At scale, *something* is always failing. A network blip, a slow disk, a process crash, a degraded dependency. The question isn't "will failures happen?" — it's "do we know how the system responds when they do?"

**2. The bug is not in the code; it's in the assumption.**
Every chaos finding is a *surprise*. The team thought retries handled the failure; they don't. The team thought failover was automatic; it isn't. The team thought the alert would fire; it didn't. Chaos engineering is *assumption testing*.

**3. Test in production, with safety.**
Staging environments are too clean. Real traffic patterns, real concurrency, real edge cases — these only exist in production. Modern chaos engineering tests in production, with blast-radius controls (limited scope, ability to abort).

**4. Game days test the team, not just the system.**
Half of any incident is *human response* — does the on-call engineer find the right runbook? Do they escalate appropriately? Do communications channels work? Game days exercise the team's response, exposing process gaps that no system test would find.

**5. Hypothesis-driven, not random.**
"Let's break things" is not chaos engineering. *"We hypothesize that if we lose one database replica, the system maintains 99.9% availability with elevated latency for 30 seconds. Let's test."* That's chaos engineering. The hypothesis turns the experiment into a learning exercise, with a definite pass/fail.

---

## Deep Technical Explanation

### The chaos experiment lifecycle

A well-formed chaos experiment:

1. **Define steady state.** What does normal look like? Specific metrics: requests/sec, p99 latency, error rate.
2. **Hypothesize.** "If we kill a backend pod, the system continues at >99% success rate with no observable customer impact."
3. **Define blast radius.** What's the worst case if we're wrong? "We'll affect at most 5% of traffic; we can abort within 30 seconds."
4. **Inject the failure.** Use the chaos tool. Observe.
5. **Observe.** Did metrics deviate? Did alerts fire? Did the team notice and respond?
6. **Analyze.** Pass: hypothesis confirmed; document and move to next experiment. Fail: write up the finding; ticket the fix; repeat the experiment after the fix.

This is *experiment* in the scientific sense. Each one teaches something — either confirming resilience or revealing a gap.

### Common failure injections

**Network failures:**
- Latency injection (add 100ms, 1s, 10s to specific calls).
- Packet loss (drop N% of packets).
- Network partition (block traffic between services).
- DNS failures.
- TLS handshake failures.

**Compute failures:**
- Process crash (kill a service instance).
- Pod failure (Kubernetes-level).
- Node failure (whole VM goes away).
- AZ failure (entire data center).
- Region failure (entire geography).

**Resource exhaustion:**
- CPU pressure (consume CPU).
- Memory pressure (allocate memory until near OOM).
- Disk pressure (fill disk).
- IOPS throttling.

**Application failures:**
- Service returns errors (5xx, 4xx).
- Service returns slow responses.
- Service returns malformed responses.
- Service returns success after the request is canceled.

**Infrastructure failures:**
- Database failover.
- Cache cluster failure.
- Message queue failure.
- DNS resolver failure.

Each failure type tests different defensive code paths. A mature program runs all of them, periodically.

### The blast radius principle

Chaos in production has a hard rule: *bound the blast radius*. Specific techniques:

- **Limit scope**: failure affects only one shard, one region, one customer cohort.
- **Ramp gradually**: start with 1% of traffic affected; if all is well, 10%, then 50%, then 100%.
- **Auto-abort on alarms**: monitoring triggers automatic experiment termination if metrics breach thresholds.
- **Time-boxed**: experiment runs for a fixed window (5-30 minutes typical).
- **Out-of-hours for big experiments**: full-region failures during low-traffic windows.

The discipline: *unbounded blast radius is not chaos engineering, it's negligence*. Even at Netflix, large failures (Chaos Kong, killing a region) are scheduled events with extensive preparation, not surprises.

### The chaos engineering principles (formal)

From "Principles of Chaos Engineering":

1. **Build a hypothesis around steady-state behavior.** Use system metrics to define normal.
2. **Vary real-world events.** Failures should mimic things that actually happen — slow disks, dropped packets, dead services.
3. **Run experiments in production.** Where possible, with safety. Staging cannot reproduce production's chaos.
4. **Automate experiments to run continuously.** A one-off chaos test is a snapshot; continuous chaos is a process.
5. **Minimize blast radius.** Bound the experiment's impact.

### Game days — the structured exercise

A game day is a scheduled, multi-hour exercise:

**Preparation:**
- Choose a scenario (e.g., "Region us-east-1 becomes unavailable").
- Identify participants (on-call engineers, SREs, observers).
- Set up a war room (physical or virtual).
- Have a "facilitator" who knows the failure but doesn't participate in response.
- Have observers who watch how the team responds, not just the system.

**Execution:**
- Inject the failure (or simulate it without actually injecting, depending on confidence).
- Team responds as if it's a real incident — checks dashboards, opens runbooks, escalates, mitigates.
- Communication channels active: Slack, video, etc.
- Facilitator may inject complications ("now your primary on-call has a meeting").

**Debrief:**
- What worked?
- What didn't?
- Was the runbook accurate?
- Did monitoring give the right signal?
- Did anyone make a wrong decision?
- What should change?

**Action items:**
- Bug fixes for system gaps.
- Runbook updates.
- Alerting changes.
- Training.
- *Schedule the next game day*.

### What makes game days different

Game days test the *human-system loop*, not just the system:

- Does the alert reach the right person?
- Does the on-call engineer have access to what they need?
- Does the runbook say where to look?
- Are escalation paths clear?
- Does communication flow well under stress?
- Are roles clear (incident commander, scribe, comms lead)?

Many game day findings are *not* code bugs. They're broken access, missing documentation, misaligned mental models. These don't show up in any other test.

### Tooling

**Open source:**
- **Chaos Monkey**: Netflix's original tool; instance termination.
- **Chaos Mesh**: Kubernetes-native; supports many failure types.
- **LitmusChaos**: also Kubernetes-native; rich experiment library.
- **Pumba**: Docker-targeted chaos.
- **Toxiproxy**: TCP-level network chaos for testing.

**Commercial / Managed:**
- **Gremlin**: comprehensive platform.
- **AWS FIS (Fault Injection Simulator)**: native AWS chaos service.
- **Azure Chaos Studio**: Azure equivalent.

**Custom:**
- Many companies build their own tooling. The complexity is more in the *workflow* (scheduling, blast-radius control, observation) than in the failure injection itself.

### Production safety

Modern chaos in production requires:

- **Authorization**: not anyone can inject failures.
- **Observability**: metrics and alarms must be real-time.
- **Auto-rollback**: failure injection terminates if SLOs breach.
- **Audit trail**: every experiment is logged.
- **Approval workflows**: large experiments require sign-off.
- **Communication**: announce experiments in chat channels so unrelated alerts aren't confused.

Without these, "chaos engineering" becomes "production incidents we caused on purpose." Tooling exists specifically to provide these guardrails.

### Continuous chaos

The mature practice runs chaos continuously, not one-off:

- Random pod terminations on a schedule.
- Latency injection in non-critical paths during testing windows.
- Periodic AZ-failure simulations.
- Regular dependency-failure exercises.

Continuous chaos has a special property: it forces *every change* to maintain resilience. Code reviews include "would this survive Chaos Monkey?" The discipline becomes cultural.

---

## Real Engineering Analogies

**The fire drill.**
Schools and offices conduct fire drills regularly. Why? The fire is rare. The drill is frequent. The drill exercises:
- Whether alarms can be heard everywhere.
- Whether evacuation routes are clear.
- Whether teachers/managers know their roles.
- Whether the fire department's response time is realistic.

A school that has never drilled may have a beautifully-designed fire safety system that fails on first contact with reality. A school that drills monthly knows every gap and has fixed most of them.

**Aircraft pilot simulators.**
Commercial pilots spend significant time in simulators practicing emergency scenarios — engine failure, decompression, weather emergencies. They don't practice these in real flights for obvious reasons. But the simulator gives them muscle memory; in a real emergency, they execute procedures they've performed dozens of times.

The argument for chaos engineering is the same. Production is the airplane in flight. Game days are the simulator. Without the simulator, the first time you encounter a serious failure, you're improvising — and improvising at scale tends to go badly.

---

## Production Engineering Perspective

What chaos engineering reveals (real findings, generalized):

- **The retry storm we didn't know about.** Killing a single instance triggers cascading retries; effective load 4× normal. Discovered in chaos exercise; fixed before real outage.
- **The runbook with stale URLs.** Failover instructions reference an admin tool that was migrated. On-call engineer can't access it during simulated failure. Fix: live-link runbooks to current tooling.
- **The alert that doesn't page.** Monitoring shows the issue but the alert is misconfigured. Game day reveals this. Fix: alert tested with synthetic failure.
- **The dependency you forgot about.** Killing service A reveals that service B *also* depends on A's health endpoint for its own availability. Hidden coupling. Fix: refactor or document the coupling.
- **The "automatic" failover that needs a human.** Documented as automatic; in practice, requires manual approval. Discovered during outage rehearsal.
- **The kill switch that doesn't.** Feature flags supposed to disable a problematic feature have a 5-minute propagation delay. Game day reveals this. Critical for fast incident mitigation.
- **The authentication tied to the failed service.** Killing the auth service means the on-call engineer can't log in to investigate. Recursive failure. Fix: out-of-band access for incidents.
- **The cascading dependency on logging.** Logging service degraded. Application threads block on log writes. Application appears down. Fix: async, bounded log buffers; backpressure to prevent log calls from blocking.

The senior engineer's habits:
- **Schedule chaos regularly**, not just before launches.
- **Hypothesize before each experiment** — make it a test, not a stunt.
- **Run game days** at least quarterly for major systems.
- **Bound blast radius** rigorously.
- **Document findings** and verify fixes with re-runs.
- **Make resilience testing part of definition of done** for new services.

---

## Failure Scenarios

**Scenario 1 — The chaos experiment that became a real incident.**
A team injects 50% latency into a non-critical path. Hypothesis: traffic continues normally. Reality: a downstream system has tight timeouts that don't tolerate the latency. Cascading failure. Mitigation: experiment auto-aborts via SLO monitoring within 90 seconds. Lessons: blast radius worked; downstream timeout was a real bug; fix shipped.

**Scenario 2 — The game day that revealed bad runbooks.**
Simulated database primary failure. On-call engineer follows runbook for failover. Runbook has wrong server names (renamed in last migration). Engineer spends 25 minutes finding the right tooling. Lesson: runbooks rot; periodic walkthroughs catch this.

**Scenario 3 — The "we don't need chaos" team.**
A team avoids chaos engineering, citing "we already have good tests." A real region failure occurs unexpectedly. Failover doesn't trigger automatically; manual recovery takes 4 hours. Postmortem reveals the same gaps that a chaos exercise would have found in 30 minutes.

**Scenario 4 — The AZ kill that worked.**
Quarterly chaos exercise: fail an entire AZ for 1 hour. Outcome: 99.95% of traffic continues unaffected; 0.05% experiences brief errors; failover is automatic; team observes the response. Result: high confidence in regional resilience; one minor finding ticketed.

**Scenario 5 — The chaos tool that broke prod.**
A new chaos tool injects a "harmless" packet drop. Bug in the tool's targeting logic affects all instances, not the intended subset. Real outage. Mitigation: tool is removed; rollback to known-good version; future chaos requires approved tool versions only.

---

## Performance Perspective

- **Chaos experiments add load** during execution. Account for this in capacity planning.
- **Continuous chaos** has a steady-state cost; typically <1% of capacity but real.
- **Game day preparation** is significant engineering investment — typically several days of planning per major game day.
- **Tool overhead**: most chaos tools are lightweight; the overhead is usually in the failure being injected, not the tool itself.

---

## Scaling Perspective

- **Small teams**: start with manual exercises (kill a process, see what happens). Build muscle.
- **Medium teams**: add tooling; schedule experiments; run game days quarterly.
- **Large organizations**: continuous chaos in production; game days monthly across teams; dedicated SRE/resilience teams owning the program.
- **Hyperscale**: chaos as platform — Netflix, Google, AWS run chaos as core infrastructure.
- **Cross-team coordination** is the scaling challenge — chaos in one team's domain affects others; communication and approvals matter.

---

## Cross-Domain Connections

- **Cascading failures**: chaos engineering tests the cascade-prevention machinery. Without testing, defenses are theoretical. (See [cascading-failures-and-circuit-breakers.md](./cascading-failures-and-circuit-breakers.md).)
- **Timeouts, retries, idempotency**: chaos exposes whether these are correctly configured. Untested = unproven. (See [timeouts-retries-and-idempotency.md](./timeouts-retries-and-idempotency.md).)
- **Backpressure**: chaos reveals where backpressure is missing — failed dependencies expose unbounded queues. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Sagas**: chaos tests compensation paths — many sagas have buggy compensation only revealed under failure. (See [saga-pattern-and-distributed-transactions.md](../architecture-patterns/saga-pattern-and-distributed-transactions.md).)
- **Observability**: chaos exercises reveal observability gaps. Logs, metrics, traces all need to work during failures. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)
- **Consensus**: distributed databases need partition testing. Jepsen is chaos engineering for consensus systems. (See [leader-election-and-consensus.md](../distributed-systems/leader-election-and-consensus.md).)
- **Load balancing**: chaos reveals whether health checks correctly detect degradation, whether failover routing works. (See [load-balancing-strategies.md](../scalability/load-balancing-strategies.md).)

The unifying observation: **every defensive pattern in distributed systems is hypothetically resilient until proven via failure testing. Chaos engineering is the proof process.**

---

## Real Production Scenarios

- **Netflix's Chaos Monkey**: the canonical reference. Public engineering posts spanning 15+ years.
- **AWS GameDays**: regular internal exercises, productized as customer-facing chaos workshops.
- **Google's DiRT (Disaster Recovery Testing)**: annual large-scale exercises simulating major outages. Public talks describe the discipline.
- **Stripe's Game Days**: documented practice for financial-system resilience. Published case studies.
- **Slack's chaos engineering**: public posts on database failover testing, region failure exercises.
- **The Kyle Kingsbury (Aphyr) Jepsen reports**: independent chaos testing of distributed databases. Industry-shaping for adoption decisions.
- **The 2017 Cloudflare outage**: documented postmortem reveals patterns that chaos engineering would have caught.

---

## What Junior Engineers Usually Miss

- That **untested resilience is theoretical resilience**.
- That **production is the only realistic test environment** for distributed systems.
- That **game days test people**, not just systems.
- That **runbooks rot** and need exercise.
- That **blast radius bounds chaos** from being negligence.
- That **automatic failover often isn't** until tested.
- That **alerts don't always fire** the way you expect.
- That **the most valuable chaos findings are surprises**, not confirmations.

---

## What Senior Engineers Instinctively Notice

- They **schedule chaos regularly**, not as one-offs.
- They **hypothesize before each experiment**.
- They **rigorously bound blast radius**.
- They **run game days** for major systems.
- They **treat findings as bugs**, not academic exercises.
- They **integrate chaos into CI/CD** where appropriate.
- They **rotate game day participants** to spread knowledge.
- They **measure mean-time-to-detect and mean-time-to-mitigate** as resilience metrics.

---

## Interview Perspective

What gets tested:

1. **"What's chaos engineering?"** Tests basic literacy. Bonus for naming Netflix and the principles.
2. **"How would you start a chaos program?"** Senior answer: small experiments, hypothesis-driven, blast-radius bounded, growing in scope.
3. **"What's a game day?"** Tests practical understanding. Right answer: scheduled exercise testing system *and* team response.
4. **"How do you bound blast radius?"** Limit scope; ramp gradually; auto-abort on SLO breach; time-box.
5. **"What have you found through chaos engineering?"** Tests real experience. Look for specific findings — bad runbooks, retry storms, missing alerts.
6. **"Why test in production?"** Realism that staging can't reproduce. Real traffic patterns, real concurrency, real failure modes.
7. **"What's the difference between chaos engineering and fuzz testing?"** Fuzz tests inputs; chaos tests system failures.

Common traps:
- Treating chaos as "let's break things and see."
- Thinking staging tests are enough.
- Not bounding blast radius.
- Not using hypotheses.

---

## 20% Knowledge Giving 80% Understanding

1. **Chaos = hypothesis-driven failure injection.**
2. **Game days exercise the team**, not just the system.
3. **Bound the blast radius.** Always.
4. **Test in production with safety**: small scope, ramp gradually, auto-abort.
5. **Untested failover is broken failover.**
6. **Runbooks rot.** Exercise them regularly.
7. **Findings become bug tickets** and re-run experiments.
8. **Continuous chaos** > one-off exercises.
9. **The valuable findings are surprises**, not confirmations.
10. **Every resilience pattern needs chaos validation**.

---

## Final Mental Model

> **Reliability is not designed; it's discovered. Chaos engineering is the discipline of discovery — finding the failure modes before customers do, on your terms, with safety nets, in business hours. The team that does this routinely outperforms the team that designs reliability beautifully but never tests it.**

The senior engineer treats chaos engineering as part of the engineering loop, not a special activity. New service? Schedule a chaos exercise. New deployment? Verify resilience holds. New dependency? Test failure modes. The mindset shift is from "we designed for failure" to "we proved it; here are the receipts."

Every reliable system you've heard about — Netflix, Google, Amazon — invests heavily in this. The systems that aren't reliable aren't ones with worse engineers; they're ones that haven't built the discipline of routine failure testing. The first time a team runs chaos exercises, they always find things. The tenth time, they find subtler things. The fiftieth time, they find the bug that would have been the headline outage.

That's chaos engineering. That's game days. That's the practice that turns "we have good tests" into "we know how this fails because we've broken it ourselves." And in distributed systems, that distinction is the difference between sleeping at night and being paged at 3am for the failure mode you'd never imagined.
