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
- Chaos engineering as DR confidence.
- Multi-region data consistency challenges.
