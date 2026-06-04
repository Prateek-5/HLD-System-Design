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

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🐒 Gap 1 — Chaos Engineering
- 🔹 **What it is**: Deliberately injecting failures into production-like systems (kill a node, sever a region, add latency) to prove recovery works *before* a real outage tests it for you.
- 🔹 **Why it matters**: Section F says most DR tests fail because runbooks are "unpracticed." Chaos engineering is the discipline that forces that practice continuously, turning DR from hope into a measured number.
- 🔹 **Connection**: This file's "game days" and "monthly DR drill" (sections C, I) are exactly this idea — chaos engineering systematizes them so failover is exercised on a schedule, not discovered during a crisis.
- 🔹 **When needed**: 🟢 **Foundational** — the mindset ("test the failure path") helps any engineer reason about reliability, even before touching tooling.
- 🔹 **Intuition**: Fire drills. You don't wait for a real fire to find out the exit is locked — you walk the route while it's safe, so the muscle memory is there when smoke fills the room.
- 🔹 **If you go deeper**: Read Netflix's Chaos Monkey / Simian Army origin story and the principles at principlesofchaos.org; try the open-source `chaos-mesh` or AWS Fault Injection Service to kill a pod and watch recovery.
- 🔹 **Interview hook**: *"How do you gain confidence your DR plan actually works?"* → run game days that inject real failures (node/region kills) on a schedule and measure observed RTO/RPO against the target.

---

#### 🌍 Gap 2 — Multi-Region Data Consistency
- 🔹 **What it is**: Keeping data copies across geographically distant regions agreeing despite network lag — choosing between strong consistency (slow, coordinated writes) and eventual consistency (fast, may temporarily diverge) and reconciling conflicts.
- 🔹 **Why it matters**: Section H's advanced question asks you to design multi-region *active-active for a writes-heavy service*. The hard part isn't compute — it's that two regions can both accept a write to the same row, and you must decide who wins.
- 🔹 **Connection**: The Hot/Hot tier in section B promises "RTO seconds, RPO ~0," but that promise only holds if writes in both regions stay reconcilable. This gap is the fine print behind the easiest-sounding row of your strategy table.
- 🔹 **When needed**: 🟡 **Mid-level** to discuss the strong-vs-eventual tradeoff; 🔴 **Senior** to actually design conflict resolution for active-active writes.
- 🔹 **Intuition**: Two bank tellers in different cities updating the same account offline. If you sync only at night, both could approve a withdrawal of the last $100. You either lock the account globally (slow) or let both proceed and settle the dispute later (eventual).
- 🔹 **If you go deeper**: Study the CAP/PACELC tradeoffs, then read how DynamoDB Global Tables and Google Spanner take opposite approaches — last-writer-wins vs. TrueTime-coordinated global consistency.
- 🔹 **Interview hook**: *"Two regions both accept a write to the same record — what happens?"* → with eventual consistency you get a conflict you must resolve (last-writer-wins, CRDTs, or app logic); strong consistency avoids it by coordinating the write but pays latency on every request.

---

#### 🔁 Gap 3 — CDC (Change Data Capture) for Replication
- 🔹 **What it is**: Streaming every row-level change (insert/update/delete) out of the primary database's transaction log so the DR region — or any downstream store — stays current in near real time.
- 🔹 **Why it matters**: It's the concrete mechanism behind "async replication keeps the DR region current" (sections C, I). Knowing CDC turns a hand-wave into a real pipeline you can name and reason about.
- 🔹 **Connection**: Your warm-standby and pilot-light tiers depend on continuous data replication; CDC is one of the standard engines that powers that "RPO ~ seconds" replication lag.
- 🔹 **When needed**: 🟡 **Mid-level** — common once you've handled basic replication and need cross-system or cross-region sync.
- 🔹 **Intuition**: A court stenographer who records every word spoken. Instead of re-photographing the whole room each minute, you just replay the transcript of *what changed* to reconstruct the scene anywhere.
- 🔹 **If you go deeper**: Run Debezium on Postgres' logical replication slot (`wal_level=logical`) and watch an `UPDATE` land as an event on a Kafka topic — see the "How to close" exercise above for the failover half.
- 🔹 **Interview hook**: *"How do you keep a DR region's data fresh without re-copying the whole DB?"* → tap the write-ahead log via CDC (e.g. Debezium) and stream only deltas, giving low replication lag and a small RPO.

---

#### 🕸️ Gap 4 — DNS Failover & TTL (Time To Live)
- 🔹 **What it is**: Rerouting users to the DR region by swapping a health-checked DNS A-record — but cached TTLs on resolvers and clients delay when that swap actually takes effect.
- 🔹 **Why it matters**: Section C lists DNS failover as "slow, TTL-bound," and section D's "flip DNS" step is the part learners underestimate. The TTL is a hard floor on how fast your cutover can possibly be, no matter how fast you promote the database.
- 🔹 **Connection**: Your mini design (section I) relies on "Global DNS health-checked (Route 53)" — this gap explains why even a perfect Route 53 setup can leave some users hitting the dead region for minutes after failover.
- 🔹 **When needed**: 🟢 **Foundational** — understanding TTL caching clears up a near-universal "why is failover still slow?" confusion.
- 🔹 **Intuition**: A printed phone directory. You can change a business's number at headquarters instantly, but everyone holding last year's printed book keeps dialing the old number until they get a fresh copy.
- 🔹 **If you go deeper**: Read AWS Route 53 health checks + failover routing docs; compare DNS-based failover against anycast/BGP and global load balancers (e.g. AWS Global Accelerator) that reroute without waiting on DNS caches.
- 🔹 **Interview hook**: *"You promoted the standby in 30 seconds but users still hit the old region for 5 minutes — why?"* → DNS TTL: resolvers and clients keep the cached old IP until it expires, so set low TTLs in advance or use anycast/global LB to bypass DNS caching.

---

### 🏆 Start here if you have limited time
1. **DNS failover & TTL** — clears up the most common "why is failover still slow?" misconception and directly explains your own mini-design's cutover step.
2. **Chaos Engineering** — the single mindset shift that explains *why* DR tests fail and how real companies stay confident; foundational and broadly applicable.

---

### 🧭 Suggested Deep Dive Order
1. **DNS failover & TTL** (~30 min; foundational, demystifies the cutover bottleneck).
2. **Chaos Engineering** (~1h; foundational mindset plus a hands-on Chaos Monkey / FIS experiment).
3. **CDC for replication** (~1h; mid-level, gives you a concrete replication pipeline to name in interviews).
4. **Multi-region data consistency** (~2h; senior-level payoff — unlocks the active-active design question).
