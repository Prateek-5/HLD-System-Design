# The Strangler Fig & Legacy Migration

> *"Every large engineering organization has a legacy system that's too important to lose, too painful to keep, and too risky to rewrite. Most attempts to fix this problem produce a worse problem. The strangler fig is the pattern that has actually worked, repeatedly, when nothing else has."*

---

## Topic Overview

The "Big Rewrite" is the classic engineering disaster. A team decides the legacy system is unfixable; they'll write a clean replacement; in 18 months, they'll switch over. Two years later, the rewrite is 60% done, the legacy system has continued evolving with new features the rewrite doesn't have, and the team is exhausted. This story has played out at thousands of companies — Netscape, Microsoft, countless less-famous teams — almost always with the same ending.

The strangler fig pattern (named by Martin Fowler in 2004) is the alternative. Instead of rewriting, you *gradually replace* the legacy system, route by route, function by function, until eventually the legacy system has nothing left to do and you can delete it. The new system grows around the old one, slowly *strangling* it (the metaphor is the strangler fig tree, which grows around a host tree until the host dies).

This is the topic where engineering humility meets organizational strategy. Most large refactors and migrations fail because they're treated as engineering problems, not migration problems. The strangler fig — and its cousins, branch-by-abstraction and parallel run — are the patterns that survive contact with production.

---

## Intuition Before Definitions

Imagine you must replace the engine of a moving car.

The big-rewrite approach: build a new car parallel to the old one. Drive both for a while. One day, switch passengers to the new car. The old car is decommissioned.

Problems: the new car must replicate every feature of the old car, including features added during construction. It's a moving target. The old car keeps evolving. You're never quite done. By the time you're "ready," the requirements have shifted and the new car doesn't quite match.

The strangler approach: replace one part of the old car at a time. Replace the engine. Test thoroughly with the rest of the car. Replace the transmission. Test. Replace the brakes. Each part is a small, safe migration. After many such replacements, the entire car is new — but you never had to replace it all at once.

That's the strangler fig pattern. Each migration is small and reversible. The legacy system still works the whole time. Risk is bounded. Progress is incremental. You can stop at any point with a working system. Most importantly: there's no "big switchover day" to fear.

---

## Historical Evolution

**Era 1 — Big rewrites and their failures.**
1990s, 2000s. Famous failures: Netscape's Mozilla rewrite (Joel Spolsky's "Things You Should Never Do" essay, 2000); Microsoft's countless code-base rewrites; thousands of un-named startup catastrophes. The pattern is well-documented; the failures keep recurring.

**Era 2 — The strangler fig naming.**
2004. Martin Fowler describes the pattern, naming it after the strangler fig tree in his observations of Australian rainforest. Articulates a method that had been done ad-hoc but not systematized.

**Era 3 — Microservices migrations.**
2012-2018. The microservices wave brought countless monolith migrations. Many used variants of strangler. Some failed spectacularly (rewrite-renamed-as-microservices). Lessons compounded.

**Era 4 — Branch by abstraction.**
~2014. Jez Humble and Dave Farley codify "branch by abstraction" as a complementary pattern: introduce an abstraction over the part being migrated; switch implementations behind the abstraction; finally remove old implementation.

**Era 5 — Modern migration practice.**
2020+. Mature practice combines strangler fig + feature flags + observability + automated testing. Migrations are routine, not heroic. Tools (database CDC, dual-writes, traffic shadowing) make them safer.

The pattern: each generation produced more sophisticated migration techniques, often by failing the previous way and learning. The accumulated wisdom is now substantial — though new teams keep relearning it.

---

## Core Mental Models

**1. The legacy system is alive; treat it that way.**
You cannot freeze the old system while you build the new one. Users keep using it; bugs keep getting fixed; features keep getting added. The migration must coexist with ongoing development.

**2. Migrations are routes, not blocks.**
Replace one route, function, or capability at a time. Each migration is small enough to ship and rollback in a day, not a year.

**3. There is no "switchover day."**
The cutover is gradual. Users move to the new system imperceptibly, by URL, by feature flag, by traffic split. There's no single moment of risk; there are many small moments of small risk.

**4. The old system survives until it's empty.**
Don't aim for a deletion date. Aim for "the old system has nothing left that anyone uses." Then delete it. Often the last 10% takes longer than the first 90% — that's normal.

**5. Migration is a project of decommissioning, not building.**
The win condition isn't "new system has all features." It's "old system can be turned off." Frame the work that way.

---

## Deep Technical Explanation

### The strangler fig pattern

The basic structure:

1. **Identify a piece of functionality** in the legacy system.
2. **Build a façade** in front of the legacy that can route to either old or new implementation.
3. **Implement the new version** in the new system.
4. **Route some traffic** to the new version (canary).
5. **Validate** correctness and performance.
6. **Ramp traffic** to 100%.
7. **Delete** the old implementation.
8. **Repeat** with the next piece.

The façade is critical. Without it, you have two systems and no clean way to switch users between them.

```
Old: Client → Legacy
New: Client → Façade → {Legacy, New}
End: Client → Façade → New
```

The façade is often:
- An API gateway with routing rules.
- A reverse proxy with path-based routing.
- A feature-flagged code path inside the application.
- A service mesh with traffic-shaping rules.

### Branch by abstraction

A complementary pattern when the migration is *inside* a single application:

1. Identify the code being migrated (e.g., a database access layer).
2. Introduce an abstraction (interface) covering the existing usage.
3. Implement old behavior behind the abstraction.
4. Refactor callers to use the abstraction.
5. Implement new behavior behind the same abstraction.
6. Switch the abstraction's default implementation.
7. Remove the old implementation.

This works for in-process migrations (changing libraries, frameworks, internal patterns). The strangler fig is for service-level migrations.

### Parallel run / shadow traffic

A safety technique often combined with strangler:

- Both old and new implementations process every request.
- Only the old implementation's response is returned to the user.
- Both responses are compared; differences logged.
- Once differences are zero (or acceptably small), switch to new.

Properties:
- **No customer impact** during validation.
- **Catches subtle bugs** the new system might have.
- **Expensive**: doubled compute load.
- **Side-effect concerns**: must handle non-idempotent operations carefully (don't actually charge the card twice).

Used heavily in payment systems, financial calculations, anywhere correctness is critical.

### Database migrations

The hardest part of most migrations. Schemas change; data must move; consistency must hold.

**Expand-contract (parallel change) pattern:**

1. **Expand**: add new columns/tables alongside the old. Application writes to both.
2. **Migrate**: backfill new columns from old data.
3. **Switch reads**: application reads from new structure; falls back to old on miss.
4. **Stop writes to old**: only new structure is written.
5. **Contract**: remove old columns/tables.

Each step is independently deployable and reversible. No "big migration window."

**Dual writes:**

Application writes the same data to both old and new stores. Critical: dual writes are not transactional across stores; reconciliation jobs catch divergence.

**Change Data Capture (CDC):**

The new system subscribes to changes in the old system's data (via WAL streaming, Debezium, etc.). The new system stays in sync with the old without dual writes. Migration completes when the new system can serve reads correctly.

### The 80/90/95 rule

Migrations follow a predictable pattern:
- **First 80%**: rapidly handled. Common cases, well-understood code.
- **Next 10% (to 90%)**: harder. Edge cases, less-trafficked endpoints.
- **Next 5% (to 95%)**: very hard. Strange features, poorly-documented integrations.
- **Last 5%**: appears insurmountable. Often takes as long as the first 80%.

Two responses:
- **Push through**: dedicated effort to migrate the last 5%.
- **Long tail**: keep the legacy system running for the unmigrated parts indefinitely. Most companies end up here. The cost is real — you maintain two systems forever.

The senior decision: explicitly choose between these. Don't drift into long-tail by accident.

### Testing during migration

Critical: regressions in the new system are migration-killers. Confidence requires:

- **Comprehensive test suites** covering both old and new behavior.
- **Contract tests** ensuring the API surface matches.
- **Shadow traffic / parallel run** in production.
- **Canary releases** with explicit monitoring.
- **Quick rollback paths** for every migration step.

A migration without these is a migration that will produce production incidents at every step.

### Observability for migration

Per-route, per-cohort metrics:
- Request rate to old vs new.
- Error rate per implementation.
- Latency comparison.
- Business metrics (conversion, completion) per cohort.

A migration where you can't compare old vs new in production data is a migration on faith. Observability investment is part of the migration cost.

### Common anti-patterns

**The big rewrite.** All-or-nothing replacement. Almost always fails.

**The 90% migration that lasts forever.** New system never quite reaches 100%; old system never decommissioned. Two systems forever.

**The "we'll fix it later" abstraction.** Façade introduced; never gets cleaned up after migration. New system inherits the old system's awkward shape via the façade.

**The migration without metrics.** "We migrated; everything's fine." No comparison data. Bugs surface weeks later.

**The migration that started without buy-in.** Engineering team migrating; product team continues adding features to the old system. Migration target moves; never catches up.

### The decision to migrate

When *should* you migrate?
- Legacy system is genuinely impeding new development (not just ugly).
- Operational cost is unsustainable.
- Skills/knowledge are vanishing.
- Strategic technology shift (e.g., language change forced by ecosystem).

When *shouldn't* you migrate?
- "It's old" isn't a reason. Old code that works is precious.
- "We don't like the language/framework" rarely justifies the cost.
- New team wanting to demonstrate skill is a terrible reason.
- The legacy system is shrinking on its own (use less; eventually retire).

Many proposed migrations don't survive cost-benefit analysis. Saying no is sometimes the senior engineering move.

---

## Real Engineering Analogies

**The hospital renovation.**
A hospital can't close for a year while it renovates. Instead, they renovate one wing while patients use other wings. Slowly the new wings replace old ones. Patients are gradually moved. Eventually, the original building is demolished — but only after every function has been moved.

That's strangler. The hospital remains functional throughout. Risk per step is small. The transformation is gradual but complete.

**The roman aqueduct replacement.**
Roman aqueducts supplied water for centuries. When they were replaced, engineers built new pipes alongside, valve-by-valve switching the water source. The old aqueducts weren't demolished until the new system was proven. Some Roman aqueducts still exist because they were never decommissioned — the new system was built around them.

This is the long-tail outcome: the new system handles current load; the old system persists for legacy reasons; over decades, the old becomes a museum.

---

## Production Engineering Perspective

What goes wrong:

- **The big rewrite that took 4 years.** Started as 18-month project. Old system kept evolving; new system always 6 months behind on features. Eventually scrapped. Years of work lost.
- **The long-tail trap.** New system handles 95% of traffic. Last 5% is too painful. Both systems run for 5 more years. Maintenance cost doubles indefinitely.
- **The data migration disaster.** Data backfill from old to new took 3 days; during which business decisions were made on incomplete data. Reports were wrong; financial implications.
- **The façade that became permanent.** Façade introduced as temporary; nobody ever removed it. New system lives "behind" a translation layer that imposes the legacy system's awkward shape on it.
- **The buy-in failure.** Engineering "migrated"; product team added new features to the old system in parallel. Migration never catches up. Eventually abandoned.
- **The shadow-traffic side-effect bug.** Parallel run sent same payment to old and new systems; old charged the card; new tried to charge again; idempotency saved most cases but not all. Customer refunds.
- **The "we'll add tests later" disaster.** Migration shipped without comprehensive tests. Subtle regressions in edge cases. Customer complaints accumulate.

The senior architect's habits:
- **Explicitly choose strangler over big rewrite**, every time.
- **Invest in observability** before the migration starts.
- **Define "done"** as old system decommissioned, not new system shipped.
- **Plan the long-tail** explicitly.
- **Avoid permanent façades.**
- **Get cross-functional buy-in** before starting.
- **Test exhaustively** in parallel run before cutover.

---

## Failure Scenarios

**Scenario 1 — The two-year migration that never finished.**
Started as "rewrite in microservices." Two years in: 60% migrated. New features go to old system because that's faster. Migration never catches up. Eventually project is killed; some pieces stay migrated, most don't. Mixed-architecture mess.

**Scenario 2 — The data divergence.**
Dual-writing during migration. A bug in the new system causes some writes to silently fail. For three weeks, new and old data diverge. Discovery: spot-check finds mismatches. Reconciliation takes weeks.

**Scenario 3 — The shadow-traffic compute cost.**
Parallel run sends every request to two systems. Compute cost doubles. Bill shock. Team accelerates the migration to reduce cost; quality slips; rollback rate spikes.

**Scenario 4 — The forgotten endpoint.**
Migration covered "all endpoints" — except an old admin endpoint nobody remembered. Used by a single internal team weekly. Migration declares completion; old system is deprecated; the internal team breaks. Recovery: emergency reactivation of the legacy endpoint.

**Scenario 5 — The "feature parity" debate.**
New system migrated 95% of features. Last 5% is "we don't think anyone uses these." Customer reports problems. Investigation: customers absolutely used those features. New system didn't replicate them. Recovery: re-implement; delays migration completion.

---

## Performance Perspective

- **Migration cost**: significant engineering investment over months/years.
- **Parallel run cost**: doubled compute during validation phases.
- **Façade overhead**: small per-request latency cost.
- **Database migration**: I/O cost for backfill; performance impact during dual writes.

---

## Scaling Perspective

- **Small monoliths**: strangler is straightforward; one team can manage.
- **Large monoliths**: multi-team coordination; long timelines (years).
- **Microservices migrations**: per-service strangler; complexity in cross-service contracts.
- **Cross-org migrations**: alignment is the hardest part; technical work is often easier.

---

## Cross-Domain Connections

- **Microservices vs monolith**: extracting services from a monolith is the canonical strangler use case. (See [microservices-vs-monolith.md](./microservices-vs-monolith.md).)
- **Feature flags**: strangler routes are typically flag-controlled. (See [feature-flags-and-progressive-delivery.md](../system-failures/feature-flags-and-progressive-delivery.md).)
- **API design**: the façade is an API; designing it well matters. (See [api-design-rest-vs-grpc.md](./api-design-rest-vs-grpc.md).)
- **Database internals**: schema migrations during strangler use expand-contract. (See [wal-and-crash-recovery.md](../database-internals/wal-and-crash-recovery.md).)
- **Observability**: comparing old vs new requires excellent metrics. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)
- **CQRS**: sometimes the migration target uses CQRS where the legacy didn't. (See [cqrs-and-event-sourcing.md](./cqrs-and-event-sourcing.md).)

The unifying observation: **legacy migration is engineering's hardest problem, not because of the code but because of organizational dynamics. The strangler fig works because it aligns engineering pace with the reality that the legacy system isn't going to wait for you.**

---

## Real Production Scenarios

- **Shopify's monolith preservation**: extensive public engineering on extracting bounded contexts from a Rails monolith over a decade.
- **Stripe's API migrations**: documented patterns for evolving APIs with thousands of customers.
- **Netflix's monolith decomposition**: famous public talks on the multi-year journey.
- **GitHub's MySQL → MariaDB migration**: documented case study of database migration at scale.
- **Bank legacy modernizations**: many banks running 40-year-old COBOL systems alongside modern microservices, with strangler-fig migration strategies measured in decades.
- **The Joel Spolsky essay**: "Things You Should Never Do, Part I" remains required reading.

---

## What Junior Engineers Usually Miss

- That **big rewrites usually fail.**
- That **migrations are routes, not blocks.**
- That **the old system survives during migration.**
- That **observability investment is part of migration cost.**
- That **the long tail is real** and must be planned.
- That **shadow traffic catches bugs** parallel run wouldn't.
- That **expand-contract** for database migrations.
- That **buy-in across teams is mandatory.**

---

## What Senior Engineers Instinctively Notice

- They **prefer strangler over rewrite** by default.
- They **invest in observability** before starting.
- They **define done** as old system decommissioned.
- They **plan the long tail** explicitly.
- They **avoid permanent façades.**
- They **get cross-team alignment** before starting.
- They **test exhaustively** during parallel run.
- They **choose carefully which migrations to do**, often saying no.

---

## Interview Perspective

What gets tested:

1. **"How would you migrate a legacy system?"** Senior answer: strangler fig; not rewrite.
2. **"What's a strangler fig?"** Tests pattern literacy.
3. **"How do you handle database schema migration?"** Expand-contract.
4. **"What's parallel run / shadow traffic?"** Tests safety-technique awareness.
5. **"When wouldn't you migrate?"** Old code that works is often best left alone.
6. **"What's branch by abstraction?"** In-process variant of strangler.
7. **"How long should a migration take?"** Months to years; if estimating less, you're optimistic.

Common traps:
- Recommending big rewrites.
- Underestimating migration timelines.
- Not planning the long tail.

---

## 20% Knowledge Giving 80% Understanding

1. **Big rewrites usually fail.** Default to strangler.
2. **Façade routes traffic** between old and new.
3. **Each migration step is small and reversible.**
4. **Define done** as old system decommissioned.
5. **Expand-contract** for database schemas.
6. **Parallel run / shadow traffic** validates new system.
7. **Observability is mandatory** for migration.
8. **Long tail is real**; plan for it.
9. **Buy-in across teams** before starting.
10. **Saying no to migrations** is sometimes correct.

---

## Final Mental Model

> **Migration is the discipline of replacing a system that's still running. The strangler fig is the only pattern that consistently works at scale — because it accepts the legacy system as a peer that won't pause while you build, and grows the new system around it gradually until the old one withers.**

The senior architect doesn't propose rewrites. They propose strangler-fig migrations with explicit phases, observability, rollback plans, and decommissioning targets. They negotiate buy-in across product and engineering. They measure progress by what's *deleted*, not what's built.

Migrations that succeed are the ones treated as projects with discipline equal to feature work. Migrations that fail are the ones treated as engineering side-quests. The pattern works; the discipline is hard. The teams that internalize this can transform their systems gracefully; the teams that don't keep producing legacy that future engineers will need to migrate.

That's the strangler fig. That's legacy migration. That's the most under-appreciated pattern in software architecture — and the one that has saved more engineering organizations than any other.
