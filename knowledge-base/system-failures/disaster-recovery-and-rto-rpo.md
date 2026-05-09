# Disaster Recovery, RTO & RPO

> *"Every system that survives a major disaster does so because someone planned for it years earlier. Every system that doesn't is held together by hope and cron jobs that nobody has tested. Disaster recovery is the discipline of making 'the entire data center is gone' a survivable event — when, not if."*

---

## Topic Overview

Disaster Recovery (DR) is the practice of preparing for catastrophic failures: an entire data center going dark, a region losing connectivity, a database catastrophically corrupting, ransomware encrypting your production data. Not the small failures observability and chaos engineering catch — the big, rare, business-threatening events.

Two numbers anchor the conversation: **RTO (Recovery Time Objective)** — how long can you be down? **RPO (Recovery Point Objective)** — how much data can you afford to lose? These aren't aspirations; they're business decisions with engineering consequences. RTO of 5 minutes requires hot standby; RTO of 24 hours allows nightly backups. RPO of zero requires synchronous replication; RPO of 1 hour allows async with bounded lag.

This is the topic where backups, replication, multi-region architecture, and operational runbooks meet. It's also the topic most teams underinvest in, then desperately wish they had — because by the time you need DR, you can't build it. Mature organizations test DR routinely; immature ones discover, during their first real disaster, that their backups don't restore.

---

## Intuition Before Definitions

Imagine running a hospital.

Most days, things work. Patients are treated, records are kept, supplies arrive. The hospital prepares for catastrophic events too: fires, floods, mass casualty incidents, terrorist attacks. They have plans, drills, redundant systems.

The hospital that doesn't plan: when the fire happens, they discover the sprinklers are broken, the evacuation plan is in a binder no one's read, the backup generator hasn't been tested in 5 years. People die.

The hospital that does plan: they have an off-site backup of patient records. They have a redundant communication system. They've drilled fire response monthly. When the fire happens, they're prepared.

Software disasters work the same way. The hospital fire is the data center outage. The patient records are your data. The drills are DR exercises. The unprepared organization discovers, during the disaster, that their backups don't restore. The prepared one survives.

RTO and RPO are the targets. RTO: "how long can the hospital be effectively closed?" RPO: "how recent can our patient records be?" These targets drive everything else.

---

## Historical Evolution

**Era 1 — Tape backups.**
Decades-old practice. Nightly tape; off-site storage. Recovery time: hours to days. Acceptable when systems were small.

**Era 2 — Disk-based backups.**
2000s. Faster recovery; still slow by modern standards.

**Era 3 — Replication-based DR.**
Late 2000s. Continuous replication to a standby site. Failover in minutes (in theory).

**Era 4 — Multi-region cloud.**
2010s. Cloud regions enabled active-active or active-passive multi-region architectures. RTO measured in minutes.

**Era 5 — Continuous DR testing.**
~2015. Game days, region failovers as routine exercise. DR moves from "hope" to "verified."

**Era 6 — DR as a property of architecture.**
2020+. Cellular architectures, blast-radius limitation, automatic failover. DR is built in, not bolted on.

The pattern: each generation reduced RTO and RPO. Today's expectations (minutes RTO, near-zero RPO) would have been impossible 15 years ago. The cost has dropped commensurately.

---

## Core Mental Models

**1. RTO and RPO are business decisions.**
Engineering implements; the business sets the target. "How long can we be down?" "How much data can we lose?" These have costs (tighter targets cost more); the business decides what's affordable.

**2. Backups that aren't tested are not backups.**
Untested recovery is broken recovery. Many disasters reveal that backups exist but can't be restored. Test recovery regularly.

**3. DR is broader than backups.**
Backups are the data. DR is also: the standby infrastructure, the failover procedures, the runbooks, the team training, the network configurations, the third-party dependencies.

**4. The disaster you'll have is not the one you planned for.**
Plan for catastrophic data loss; the actual disaster might be ransomware. Plan for a fire; it might be a misbehaving deploy. The plans help anyway, but stay flexible.

**5. Cost scales with how strict your targets are.**
RTO of seconds requires hot standby (2× infrastructure). RTO of hours requires warm standby (1.5×). RTO of days requires cold backups (1.1×). The economics drive the architecture.

---

## Deep Technical Explanation

### RTO and RPO

**RTO (Recovery Time Objective):** the maximum acceptable downtime after a disaster.

Examples:
- 5 minutes: requires hot standby with automated failover.
- 1 hour: warm standby; automated or manual failover.
- 24 hours: cold backups; manual restore.
- 72 hours: tape backups from off-site.

**RPO (Recovery Point Objective):** the maximum acceptable data loss measured in time.

Examples:
- 0: synchronous replication; no data loss.
- 30 seconds: fast async replication.
- 1 hour: hourly snapshots.
- 24 hours: nightly backups.

These are typically negotiated with business stakeholders. Different systems may have different targets — payment systems often have RTO/RPO of minutes; analytics warehouses can tolerate hours.

### DR strategies, by sophistication

**Backup and restore.**
- Periodic backup; restore on disaster.
- RTO: hours to days.
- RPO: backup frequency.
- Cost: ~10% additional.
- Best for: non-critical systems; long-archive needs.

**Pilot light.**
- Minimal infrastructure in DR site (databases warm; servers cold).
- Spin up application servers on disaster.
- RTO: hours.
- RPO: replication lag (minutes).
- Cost: ~20-30% additional.

**Warm standby.**
- Full infrastructure running but at reduced capacity.
- Scale up on disaster.
- RTO: 30-60 minutes.
- RPO: replication lag.
- Cost: ~50% additional.

**Hot standby (active-passive).**
- Full infrastructure running, ready to take traffic.
- DNS or routing change to fail over.
- RTO: 5-15 minutes.
- RPO: replication lag (seconds).
- Cost: ~100% additional.

**Active-active multi-region.**
- All regions serving traffic; lose one without disruption.
- RTO: seconds (automatic).
- RPO: depends on replication.
- Cost: 100%+; complexity high.

The choice depends on RTO/RPO targets and budget.

### Backup strategies

**Full backup.** Complete copy. Slow to create; fast to restore.

**Incremental.** Changes since last backup. Fast to create; slow restore (apply chain).

**Differential.** Changes since last full. Compromise.

**Continuous (CDP).** Every change captured. Highest RPO; expensive.

In practice: weekly full + daily incremental is common. Or: continuous replication for hot data; periodic snapshots for archive.

### The 3-2-1 rule

Classic backup wisdom:
- **3** copies of data.
- **2** different storage media.
- **1** off-site.

Modern variant: 3-2-1-1-0 — 3 copies, 2 media, 1 off-site, 1 immutable (ransomware-resistant), 0 errors after verification.

### Replication for DR

For low RTO/RPO, replication to the DR site:
- **Synchronous**: zero RPO; latency cost; if DR site unreachable, primary may halt.
- **Asynchronous**: small RPO (seconds to minutes); no latency impact.
- **Snapshot-based**: periodic atomic snapshots replicated; RPO = snapshot interval.
- **CDC (Change Data Capture)**: stream of database changes; near-zero RPO; requires CDC tooling.

Most production systems use async replication for DR with monitored lag.

### Failover mechanisms

**DNS-based.** Update DNS to point to DR site. Slow (TTL, client caches); minutes.

**Anycast.** Withdraw routes from failed region; traffic flows to alive regions. Seconds.

**Load balancer-based.** Routing rule change. Fast within a single LB.

**Application-level.** Application detects failure; rebuilds connections to DR. Fastest but most complex.

The choice depends on infrastructure. Cloud providers offer managed DR routing.

### Database DR specifically

Database failover is operationally complex:
- Detect failure (avoid false positives).
- Promote replica.
- Reconfigure clients.
- Handle data divergence (split-brain).

Tools: Patroni (Postgres), Orchestrator (MySQL), managed services (Aurora, Cloud SQL).

The "did we lose data?" question is hardest. Async replication may have lost some commits. Auditing post-recovery is part of DR.

### Backup verification

A backup not verified is not a backup. Verification techniques:
- **Restore test**: periodically restore to a separate environment; verify data integrity.
- **Checksum validation**: ensure backup file integrity.
- **Application-level test**: run a query; verify expected result.
- **Full DR drill**: actually fail over to DR site.

Frequency: monthly minimum for critical systems; quarterly for others.

The "we have backups" claim is meaningless without "we tested restore last quarter."

### DR runbooks

Step-by-step procedures for DR scenarios:
- "Region us-east-1 is down. Steps to fail over to us-west-2."
- "Database primary is unrecoverable. Steps to promote replica."
- "Ransomware detected. Steps to isolate and restore."

Properties:
- **Specific**: not "fail over"; "run script X on host Y."
- **Tested**: each step exercised in drills.
- **Updated**: drift kills runbooks; review quarterly.
- **Discoverable**: stored where on-call can find them, *not* on the system that's failing.

### The ransomware scenario

A modern DR concern: ransomware encrypts production data. Backups too if not isolated.

Defenses:
- **Immutable backups**: write-once, read-many storage that can't be deleted by attackers.
- **Air-gapped backups**: physically or network-isolated copies.
- **Versioning**: keep multiple historical versions; ransomware can't poison all.
- **Offline tape archives**: ultimate last resort.

The ransomware threat shaped 21st-century DR practice. Backup strategies that protected against fires didn't protect against attackers. New patterns emerged.

### Testing DR

The only valid DR is tested DR.

**Backup restore tests.** Monthly. Restore a backup to a non-prod environment; verify data.

**Database failover tests.** Quarterly. Promote replica; verify application connects; revert.

**Region failover drills.** Semi-annually. Actually fail traffic to DR region; observe; recover.

**Full DR exercise.** Annually. Simulate complete loss of primary; verify recovery to RTO.

Record results; track improvements. Each exercise reveals gaps; each gap is a fix.

---

## Real Engineering Analogies

**The fire drill at the office building.**
A skyscraper has fire suppression, evacuation routes, alarm systems. They drill regularly. When a real fire happens, people execute the rehearsed plan. The building survives. Compare: a building that's never drilled — chaos, injuries, possibly deaths. Same physical infrastructure; different practices; very different outcomes.

**The military's exercises and war games.**
Militaries don't wait for war to test their plans. They run exercises constantly. They identify gaps; they update doctrine; they train troops. When real conflict comes, they execute. DR is software's equivalent.

**The off-site safe deposit box.**
You keep important documents in an off-site safe deposit box, in case your house burns down. You never expect to use it, but the cost (a few dollars per year) is small relative to the value (irreplaceable documents). Backups are this for data.

---

## Production Engineering Perspective

What goes wrong:

- **The backup that didn't restore.** Backups taken nightly for 5 years; never restored. Disaster strikes; restore attempt fails (corrupted index, version mismatch, wrong configuration). 12+ hours of additional downtime. Lesson: test restores monthly.
- **The DR that "should work."** No actual drill in 3 years. Disaster: configurations drifted; runbooks stale; team panics. RTO of 4 hours becomes 48 hours.
- **The split-brain post-failover.** Failover triggered; old primary returned; both accept writes. Data divergence. Manual reconciliation. Days of work.
- **The cross-region cost surprise.** Active-active multi-region; bandwidth costs (egress) blow up. Bills double. Architecture changes to mitigate.
- **The runbook that referenced a decommissioned tool.** During DR, the runbook says "use X." X was decommissioned 6 months ago. Engineer scrambles. Lesson: living runbooks; review quarterly.
- **The backup encryption key loss.** Backups encrypted; key lost. Backups effectively unusable. Lesson: key management as critical as backup itself.
- **The ransomware that ate the backups.** Attacker gained access to backup system; encrypted them too. Air-gap or immutability needed; missing.

The senior SRE/DR engineer's habits:
- **Define RTO/RPO** explicitly per system.
- **Test backup restores** monthly.
- **Run DR drills** quarterly.
- **Update runbooks** continuously.
- **Audit DR coverage** annually.
- **Plan for ransomware** with immutable storage.
- **Treat DR as part of architecture**, not an afterthought.

---

## Failure Scenarios

**Scenario 1 — The unrestorable backup.**
5 years of nightly backups. Disaster: production database lost. Restore from latest backup. Restore fails — backup file structure changed years ago; modern tools don't recognize it. Recovery: reconstruct from older logs and human knowledge. 4 days down. Lesson: continuous restore testing.

**Scenario 2 — The "we have a DR plan."**
Plan written 2 years ago; never tested. Major outage. DR procedures fail at step 3 because the system referenced no longer exists. Recovery improvised; RTO of 4 hours becomes 36 hours. Lesson: living runbooks.

**Scenario 3 — The replication-lag data loss.**
Async replication; lag spike during heavy write load. Disaster strikes during the spike. Failover loses 30 seconds of writes (paid orders). Customer support nightmare; revenue loss. Lesson: monitor lag; consider sync for critical data.

**Scenario 4 — The ransomware lockout.**
Attacker encrypts production. Recovery from backups: backups in same network, also encrypted. No air-gap. Recovery from older off-site backups: 6 months old; significant data loss. Lesson: immutable, air-gapped backups.

**Scenario 5 — The cross-region failover drill that worked.**
Pre-drill: chaos exercise simulates region failure. RTO target: 15 minutes. Drill achieves 12 minutes. Two minor bugs found and fixed. Real disaster a year later: 14 minutes RTO. Lesson: drilled DR works.

---

## Performance Perspective

- **Backup creation**: scales with data size; dedupe and incremental help.
- **Backup storage**: cheap (object storage) for cold data.
- **Replication**: async has minimal performance impact; sync has latency cost.
- **Failover latency**: dominated by detection time and reconfiguration.
- **Restore time**: scales with data size and storage tier.

---

## Scaling Perspective

- **Small systems**: backup-and-restore is sufficient.
- **Medium systems**: warm standby in another region.
- **Large systems**: active-active multi-region.
- **Hyperscale**: cellular architectures with isolated cells; loss of one cell = small fraction of customers affected.

---

## Cross-Domain Connections

- **Replication**: DR depends on replication strategy. (See [replication-strategies.md](../database-internals/replication-strategies.md).)
- **WAL**: backups and replication build on WAL. (See [wal-and-crash-recovery.md](../database-internals/wal-and-crash-recovery.md).)
- **Cascading failures**: DR plans for the largest possible cascade. (See [cascading-failures-and-circuit-breakers.md](./cascading-failures-and-circuit-breakers.md).)
- **Postmortems**: real disasters become postmortems. (See [postmortems-and-incident-response.md](./postmortems-and-incident-response.md).)
- **Chaos engineering**: DR drills are the highest-stakes chaos exercises. (See [chaos-engineering-and-game-days.md](./chaos-engineering-and-game-days.md).)
- **SLOs**: DR's RTO/RPO are extreme-case SLOs. (See [slos-error-budgets-and-alerting.md](../observability/slos-error-budgets-and-alerting.md).)
- **Capacity planning**: DR capacity must be sized. (See [auto-scaling-and-capacity-planning.md](../scalability/auto-scaling-and-capacity-planning.md).)

The unifying observation: **disaster recovery is the cumulative sum of all your other reliability practices, tested under maximum-stress conditions. The systems that survive disasters are the ones whose other practices were already mature.**

---

## Real Production Scenarios

- **AWS Region outages**: documented examples; many companies' DR plans tested simultaneously.
- **GitLab's data loss incident (2017)**: backup verification gap led to ~6 hours of data loss. Public postmortem.
- **The 2021 Fastly outage**: ~1 hour global outage from a config bug. Documented response.
- **OVH data center fire (2021)**: physical destruction; many customers had no DR; lost data.
- **Ransomware attacks on Colonial Pipeline, others**: lessons in air-gapped backups.
- **Netflix's region evacuation drills**: routine; documented practices.

---

## What Junior Engineers Usually Miss

- That **untested backups don't work**.
- That **RTO/RPO are business decisions**.
- That **DR is broader than backups**.
- That **replication isn't backup** (deletes propagate; ransomware encrypts).
- That **runbooks rot**.
- That **air-gapped backups** matter for ransomware.
- That **the disaster you have isn't the one you planned for**.
- That **cost scales with target tightness**.

---

## What Senior Engineers Instinctively Notice

- They **define RTO/RPO** explicitly.
- They **test backups** monthly.
- They **drill DR** quarterly.
- They **update runbooks** continuously.
- They **plan for ransomware** with immutable storage.
- They **monitor replication lag** as a primary metric.
- They **audit DR coverage** annually.
- They **size DR infrastructure** appropriately.

---

## Interview Perspective

What gets tested:

1. **"What's RTO and RPO?"** Tests fundamentals.
2. **"How would you design DR for X?"** Tests applied judgment.
3. **"What's 3-2-1 backup?"** Tests classic discipline.
4. **"How do you test DR?"** Drills, restore tests.
5. **"What's the difference between backup and replication?"** Backup is a snapshot; replication is continuous.
6. **"How do you protect against ransomware?"** Immutable, air-gapped backups.
7. **"How would you fail over a database?"** Tests practical knowledge.

Common traps:
- Believing backups they haven't tested.
- Confusing replication with backup.
- Underestimating runbook drift.

---

## 20% Knowledge Giving 80% Understanding

1. **RTO = downtime**; **RPO = data loss tolerance**.
2. **Untested backups don't work.**
3. **DR strategies**: backup → pilot light → warm → hot standby → active-active.
4. **3-2-1 rule** (or modern variants).
5. **Replication is not backup** (deletes/corruption propagate).
6. **Air-gap or immutable** for ransomware.
7. **Runbooks must be tested**.
8. **DR drills** quarterly minimum.
9. **Cost scales with strictness**.
10. **The disaster you have ≠ the one you planned for** — but plans help anyway.

---

## Final Mental Model

> **Disaster recovery is the discipline of being prepared for events you hope never happen. The teams that take it seriously survive disasters; the teams that don't discover, in their first disaster, that they should have. The cost is real but small relative to the cost of being unprepared.**

The senior engineer designing for DR thinks about scenarios most teams ignore: the entire region is gone; the database is corrupted; ransomware has encrypted everything; the ops team has no laptops. They plan; they document; they drill. The plans have gaps that drills reveal; the gaps get fixed; the next drill goes better.

The systems that survive AWS region outages, ransomware attacks, and physical disasters are the ones whose teams invested in DR before they needed it. The systems that make the news for losing customer data are the ones that didn't. The cost of investment is small compared to the cost of disaster; the discipline of testing is the difference between "we have a DR plan" and "we have a DR capability."

That's disaster recovery. That's RTO and RPO. That's the operational practice for the days you hope never happen — and the foundation that makes "the system survived" the punchline of a story rather than its ending.
