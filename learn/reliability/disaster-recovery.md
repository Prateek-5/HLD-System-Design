# Disaster Recovery — When a Region Dies

## A. Intuition First
DR = plan for catastrophic failure (AZ outage, region outage, data loss event). Two numbers matter:
- **RTO (Recovery Time Objective)** — how fast back up.
- **RPO (Recovery Point Objective)** — how much data can you afford to lose.

## B. Mental Model
DR strategies by cost/time:
- **Backup & Restore**: nightly backups. RTO hours, RPO hours. Cheap.
- **Pilot Light**: replicate data continuously; start up compute only on disaster. RTO minutes, RPO seconds.
- **Warm Standby**: smaller copy always running. RTO minutes, RPO ~0.
- **Hot/Hot (Multi-region active-active)**: full production in multiple regions. RTO seconds, RPO ~0.

## C. Internal Working
- Backups: automated, tested restores (untested backup = no backup).
- Multi-region replication: async logical/physical replication; DR region can assume traffic.
- DNS failover: health-check + automatic A-record swap (slow, TTL-bound).
- Runbooks + game days: tested, not hoped for.

## D. Visual Representation
```
Normal:    users → [Region A primary]
Disaster:  users → [Region B warm]  (promote DB, flip DNS)
```

## E. Tradeoffs
Cost rises sharply with each tier. Pick per business criticality.

## F. Interview Lens
- "RTO vs RPO?"
- "How do you do multi-region for Postgres?"
- "Why do most companies fail DR tests?" — unpracticed runbooks.
- Pitfalls: assuming backups work without restoring them.

## G. Real-World Mapping
AWS regions: us-east-1 (primary) + us-west-2 (DR) is a classic pair. Critical systems run active-active across regions (Netflix). Post-mortems of major region outages (Cloudflare, AWS) drive industry best practices.

## H. Questions
**Beginner**: RTO and RPO?
**Intermediate**: Compare 4 DR strategies.
**Advanced**: Design multi-region active-active for a writes-heavy service.

## I. Mini Design
Multi-region setup:
- Region A: primary.
- Region B: warm standby, async replicated.
- Global DNS health-checked (Route 53).
- Runbooks for promotion + DNS cutover + data reconciliation.
- Monthly DR drill.

## J. Cross-Topic Connections
- [Availability](../foundations/scaling/availability.md), [Replication](../data/database-replication.md), [SLA/SLO/SLI](sla-slo-sli.md).

## K. Confidence Checklist
- [ ] Can pick DR tier based on RTO/RPO needs.
- [ ] Knows practiced runbooks matter.

## L. Potential Gaps & Improvements
- **Chaos Engineering** — deliberately injecting failures (kill a node, drop a region) to prove recovery works before a real outage does; turns DR from hope into measured confidence.
- **Multi-region data consistency** — keeping copies across regions agreeing despite network lag; you must choose between strong (slow, coordinated) and eventual (fast, may diverge) and reconcile conflicts.
- **CDC (Change Data Capture)** — tools like Debezium stream every row change out of the primary database so the DR region stays current; key for "keep two stores consistent" replication.
- **RTO (Recovery Time Objective) / RPO (Recovery Point Objective)** — the two numbers that price every DR tier; restate them as concrete minutes/seconds for each strategy (→ see Interview Lens).
- **DNS failover & TTL (Time To Live)** — health-checked A-record swaps reroute users to the DR region, but cached TTLs delay cutover; learners care because it caps how fast "flip DNS" actually works.

**🔧 How to close:** Spin up two Postgres containers with `docker-compose`, set the second as a streaming replica, then `docker stop` the primary and run `pg_promote()` (or `SELECT pg_promote();`) on the standby — time how long until it accepts writes to feel RTO firsthand.
