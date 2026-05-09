# Multi-Tenancy Strategies

> *"Every SaaS company is a multi-tenancy company, whether they planned it or not. The architectural decisions about how tenants share resources — or don't — are made early, often without realizing how consequential they are. Three years later, those decisions determine whether onboarding a big customer is a one-day project or a six-month re-architecture."*

---

## Topic Overview

Multi-tenancy is the practice of serving multiple customers (tenants) from shared infrastructure. The "tenant" is a business unit (a company subscribing to a SaaS); each tenant has its own users, data, and configurations. The fundamental question: *how much do tenants share?*

The spectrum:
- **Pool model**: all tenants share one database, one application instance. Cheapest; weakest isolation.
- **Silo model**: each tenant has dedicated infrastructure. Strongest isolation; most expensive.
- **Bridge model**: shared application; per-tenant database (or per-tenant schema).
- **Cell-based**: groups of tenants in independent "cells"; bound blast radius.

Each is a different point in the cost-isolation-complexity space. The wrong choice produces operational pain that compounds. The right choice depends on customer size, compliance requirements, performance variance, and operational maturity.

This is the topic where SaaS architecture meets sharding meets compliance. Multi-tenancy is the architecture under every B2B SaaS, every cloud provider, every shared service. Getting it right is one of the most consequential early decisions.

---

## Intuition Before Definitions

Imagine running an apartment building.

**Pool (single big room).** All residents share one large open space. Cheap to build; one kitchen serves all. Disaster: one resident makes noise; everyone hears. One resident gets sick; everyone catches it. Privacy nonexistent. Operationally simple but customer satisfaction is awful.

**Silo (separate houses).** Each resident gets their own house on their own land. Maximum privacy and quiet. Expensive: separate plumbing, kitchens, utilities. Operationally heavy: each house must be maintained.

**Bridge (apartment building).** Shared building (walls, plumbing); separate units (bedrooms, kitchens). Reasonable privacy; reasonable cost. Most modern multi-tenant apps work this way.

**Cell (apartment complex with multiple buildings).** Independent buildings each housing many residents. A fire in Building A doesn't affect Building B. Used at scale: tenants distributed across cells.

The choice depends on tenant needs (privacy, performance, compliance) and operational capacity. Same trade-off as software multi-tenancy.

---

## Historical Evolution

**Era 1 — Single-tenant (the original SaaS).**
1990s-2000s. Each customer ran their own instance. Operationally heavy.

**Era 2 — Shared databases.**
~2005. SaaS adoption demanded efficiency. Shared schema with `tenant_id` column. Cheaper but isolation concerns.

**Era 3 — Per-tenant schemas.**
~2010. PostgreSQL schemas per tenant. Stronger isolation; manageable at moderate scale.

**Era 4 — Cell-based architectures.**
~2015. AWS, Stripe document cellular designs. Distribute tenants across cells; bound blast radius.

**Era 5 — Modern hybrid models.**
2020+. Most SaaS combines: pool for small tenants, silo for enterprise. Per-tenant capacity tuning.

**Era 6 — Compliance-driven isolation.**
GDPR, SOC2, HIPAA drive isolation requirements. Some workloads must be silo for compliance reasons.

The pattern: each generation refined the cost-isolation tradeoff. Modern SaaS uses hybrid models matching tenant size and requirements.

---

## Core Mental Models

**1. Multi-tenancy is a continuum.**
From pure pool (everything shared) to pure silo (everything dedicated). Most production systems sit somewhere in between, often differently for different tenant types.

**2. The blast radius is the unit of isolation.**
A bug, a noisy neighbor, a security breach — what's the largest set of tenants affected? Designs with bounded blast radius survive bad days.

**3. Isolation has costs.**
Stronger isolation = more infrastructure, more operational overhead, more cost. The right level matches business needs.

**4. Tenant identity propagates everywhere.**
Every database query, every cache key, every log line, every metric — tenant context must be present. Forgetting it leads to data leaks.

**5. Tenants vary wildly.**
Small tenants: most of your count. Large tenants: most of your load. Treating them identically in pool model leads to small tenants suffering from large tenants. Enterprise patterns differ.

---

## Deep Technical Explanation

### The pool model

All tenants share one application and one database. Tables have a `tenant_id` column.

```sql
SELECT * FROM orders WHERE tenant_id = $1 AND id = $2;
```

Pros:
- Cheap (one database, one app fleet).
- Easy operations (single deployment, single backup).
- Simple architecture.

Cons:
- **Noisy neighbor**: one tenant's heavy query slows all.
- **No data isolation**: a missing `WHERE tenant_id = ...` exposes other tenants' data. Catastrophic.
- **No per-tenant capacity**: small tenant suffers from large tenant's load.
- **Compliance challenges**: some standards require physical isolation.

The pool model is fine for small SaaS with similar-sized tenants. Falls apart at scale or with enterprise customers.

### The silo model

Each tenant gets dedicated infrastructure: own database, possibly own application instance.

Pros:
- **Strong isolation**: customer-specific failures.
- **Compliance**: easy to demonstrate.
- **Per-tenant scaling**: independent.

Cons:
- **Expensive**: scales linearly with tenant count.
- **Operationally heavy**: per-tenant migrations, backups, monitoring.
- **Cold-start cost**: provisioning a new tenant takes time.

Silo is right for enterprise contracts, regulated industries, very large tenants.

### The bridge model

Shared application; per-tenant data isolation:

**Per-tenant schema.**
PostgreSQL schemas; one per tenant. Same database; isolated tables. `SET search_path TO tenant_42`.

```sql
CREATE SCHEMA tenant_42;
CREATE TABLE tenant_42.orders (...);
```

Pros: data isolation; shared application.
Cons: per-tenant migrations (run schema changes per schema); doesn't scale to millions of schemas.

**Per-tenant database.**
Each tenant has a separate database. Connection pool routes by tenant.

Pros: stronger isolation.
Cons: connection-pool complexity; per-tenant backup.

**Shared schema with row-level security.**
Same tables; PostgreSQL RLS policies enforce `WHERE tenant_id = current_tenant()`.

Pros: data leak prevention enforced by database; shared schema.
Cons: query optimization can be tricky.

### Cell-based architecture

Groups of tenants in independent "cells." Each cell is a complete stack (app, database, etc.). Tenants assigned to cells.

Properties:
- **Bounded blast radius**: a cell failure affects only its tenants.
- **Independent scaling**: each cell sized to its tenants.
- **Independent deployments** (in some designs): canary one cell first.
- **Operational overhead**: many cells to manage.

Used by: AWS internally, Stripe, Slack, many large SaaS. Documented patterns.

The number of cells is a design choice: 10 cells = each is 10% of customers; 100 cells = 1% per cell. Trade-off: blast radius vs operational cost.

### Tenant routing

How does a request reach the right tenant's data?

- **Subdomain**: `tenant1.example.com`, `tenant2.example.com`. DNS or LB routing.
- **Path-based**: `/tenants/42/...`. App layer routes.
- **Header-based**: `X-Tenant-ID: 42`. App layer routes.
- **Token-based**: JWT contains tenant ID. App extracts.

Routing infrastructure: API gateway maps tenant → cell; LB routes; app reads context.

### Tenant context propagation

Once routed, tenant context must propagate through every layer:
- Database connection (SET tenant context for RLS).
- Cache key (prefix with tenant ID).
- Log line (include tenant ID).
- Metrics tags (tenant dimension; with cardinality concerns).
- Outbound calls (forward tenant ID to downstream services).

Forgetting any layer: data leak (cache cross-tenant), missing observability, etc.

### Per-tenant rate limiting

Without per-tenant limits, one tenant can consume all capacity (noisy neighbor).

Implementation:
- Token bucket per tenant.
- Distributed (Redis) for multi-instance services.
- Tiered: free tier 10 RPS, paid 100 RPS, enterprise 10K RPS.

Critical for fair multi-tenant operation. The "noisy neighbor" problem is solved at this layer.

### Per-tenant metrics

Metrics tagged with tenant_id (carefully—high cardinality):
- Errors per tenant.
- Latency per tenant.
- Resource consumption per tenant.

Must balance cardinality cost. Often: aggregate metrics with tenant tags only for top-N tenants; everything else aggregated.

### Tenant migration

Moving tenants between cells (for rebalancing, upgrades):
- Copy data to new cell.
- Switch routing.
- Verify no traffic to old cell.
- Decommission old data.

Online migration (no downtime) is complex; many systems have downtime windows for migration.

### Compliance and isolation

GDPR: data residency. EU tenants' data must stay in EU.
HIPAA: PHI requires careful handling.
SOC2: documented controls.
PCI: credit card data tightly isolated.

Compliance often dictates silo model for specific tenants or regions. Multi-tenancy strategy must accommodate.

### Onboarding and offboarding

**Onboarding**: provision tenant. Pool: just create rows. Silo: full infrastructure. Cell-based: assign to cell.

**Offboarding**: tenant leaves; data must be deleted (GDPR). Pool: DELETE WHERE tenant_id = ... Silo: tear down. Cell-based: depends.

Offboarding is harder than it looks. Cascading deletes; backups; analytics warehouses; logs; metrics. All must be cleaned.

### Performance isolation

Beyond rate limiting, deeper performance isolation:
- **Connection pool per tenant**: a tenant's connections are bounded.
- **Resource quotas**: CPU, memory caps.
- **Query timeouts**: prevent runaway queries.
- **Concurrency limits**: per-tenant in-flight request caps.

Critical for shared environments. Without these, one tenant can starve others.

---

## Real Engineering Analogies

**The university dorm vs apartment vs single-family home.**
- **Dorm (pool)**: cheap; shared everything; noise problems.
- **Apartment (bridge)**: own unit; shared building.
- **Single-family home (silo)**: most space; most cost.
- **Apartment complex (cell-based)**: many buildings, each with apartments.

Universities offer all four to match student needs and budgets. SaaS architectures do the same for tenants.

**The hotel vs resort.**
A hotel chain: shared property, shared staff, individual rooms. Customers within a hotel share noise, elevators, breakfast. A resort with private villas: more privacy, much more cost. Different customer segments fit different models.

---

## Production Engineering Perspective

What goes wrong:

- **The tenant data leak.** Forgotten WHERE tenant_id = ... in one query path. Tenant A's data shown to tenant B. Catastrophic; customer notification; potentially regulatory consequences. Mitigation: row-level security enforced at database layer.
- **The noisy neighbor.** One tenant generates 100× normal load (legitimate growth or bug). Other tenants suffer slow responses. Mitigation: per-tenant rate limiting; cell-based isolation.
- **The cell overflow.** Cells assigned by hash; one cell ends up with disproportionately heavy tenants. Mitigation: weighted assignment; rebalancing.
- **The per-tenant migration.** Schema change must run per-tenant in bridge model. 1000 tenants × 5 minutes = 80 hours. Operational pain. Mitigation: parallelize; automate.
- **The onboarding latency.** Silo model: provisioning a tenant takes 30 minutes. Sales sells; customer waits half an hour. Painful. Mitigation: pre-provision; faster automation.
- **The compliance failure.** EU tenant's data ended up in US datacenter (cell mis-assigned). GDPR violation. Mitigation: enforce region constraints in routing.
- **The offboarding miss.** Tenant deleted from primary database; analytics warehouse retains data; logs retain data. GDPR audit fails. Mitigation: comprehensive offboarding.

The senior architect's habits:
- **Choose multi-tenancy strategy** based on tenant size distribution.
- **Hybrid models** for varying tenant needs.
- **Per-tenant rate limiting** mandatory.
- **Tenant context propagation** in every layer.
- **Cell-based architecture** for blast-radius reduction at scale.
- **Comprehensive offboarding** including downstream systems.

---

## Failure Scenarios

**Scenario 1 — The cross-tenant cache leak.**
Cache key didn't include tenant_id. Tenant A's response cached. Tenant B's request hits the same key; gets A's data. Discovered: customer support call. Mitigation: tenant_id in every cache key; incident review.

**Scenario 2 — The noisy enterprise.**
Big new customer; 50× normal load. Pool model; database CPU spikes; other tenants suffer. Recovery: emergency capacity increase; eventually move enterprise to silo or dedicated cell.

**Scenario 3 — The schema migration.**
Bridge model; 5000 tenant schemas. Schema migration: 5000 ALTER TABLEs. Some fail; partial state. Recovery: per-tenant retry logic; eventually consistent migration.

**Scenario 4 — The cell-bound region.**
Tenant in EU cell tried to access feature only deployed in US cell. Errors. Recovery: feature deployed to all cells; or routing logic that fails gracefully.

**Scenario 5 — The offboarding miss.**
Customer departed; data deleted from primary; logs and analytics still contain. Audit reveals; remediation. Lesson: comprehensive offboarding from day one.

---

## Performance Perspective

- **Pool**: best resource utilization.
- **Silo**: per-tenant overhead; lower utilization.
- **Bridge**: middle.
- **Per-tenant rate limiting**: small overhead per request.
- **Cell-based**: similar to pool within cell; cell-bounded scope.

---

## Scaling Perspective

- **Pool**: scales until single-database limits.
- **Silo**: scales linearly with tenants and cost.
- **Bridge**: scales until per-tenant management overhead.
- **Cell-based**: scales by adding cells.
- **At hyperscale**: cell-based mandatory.

---

## Cross-Domain Connections

- **Sharding**: cells are a form of sharding. (See [sharding-and-partitioning-strategies.md](./sharding-and-partitioning-strategies.md).)
- **Cascading failures**: cell isolation prevents cross-tenant cascades. (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)
- **Backpressure**: per-tenant rate limiting. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Caching**: tenant ID in cache keys. (See [caching-hierarchy.md](../caching/caching-hierarchy.md).)
- **Load balancing**: cell routing. (See [load-balancing-strategies.md](./load-balancing-strategies.md).)
- **Observability**: per-tenant metrics; cardinality concerns. (See [cardinality-and-the-economics-of-monitoring.md](../observability/cardinality-and-the-economics-of-monitoring.md).)

The unifying observation: **multi-tenancy is the lens through which most distributed-systems concerns become customer-specific. Cells, sharding, isolation, blast radius — all become "for which tenants?" decisions.**

---

## Real Production Scenarios

- **Stripe's cell-based architecture**: documented public.
- **Slack's tenant model**: workspace-based.
- **Salesforce's multi-tenancy**: pioneering pool model at scale.
- **AWS internal multi-tenancy**: documented in re:Invent talks.
- **Atlassian's multi-tenant SaaS evolution**: published case studies.

---

## What Junior Engineers Usually Miss

- That **tenant context must propagate** everywhere.
- That **cache keys must include tenant_id**.
- That **noisy neighbor is real**.
- That **per-tenant rate limiting** is mandatory.
- That **compliance drives isolation**.
- That **offboarding is hard**.
- That **schema migrations multiply** in bridge model.

---

## What Senior Engineers Instinctively Notice

- They **choose multi-tenancy strategy** based on tenant distribution.
- They **enforce tenant isolation** in code review.
- They **use cell-based architecture** at scale.
- They **rate-limit per tenant**.
- They **propagate tenant context** rigorously.
- They **handle compliance constraints**.
- They **plan offboarding** from day one.

---

## Interview Perspective

What gets tested:

1. **"Multi-tenancy strategies?"** Pool, silo, bridge, cell.
2. **"How would you ensure tenant isolation?"** RLS; tenant_id everywhere.
3. **"What's the noisy neighbor problem?"** One tenant affecting others.
4. **"How do you rate-limit per tenant?"** Token bucket per tenant.
5. **"Cell-based architecture?"** Independent cells; bounded blast radius.
6. **"How do you handle compliance?"** Region/cell constraints.

Common traps:
- Recommending pure pool at scale.
- Forgetting tenant_id in caches.

---

## 20% Knowledge Giving 80% Understanding

1. **Multi-tenancy spectrum**: pool → silo.
2. **Pool**: cheap, shared, weak isolation.
3. **Silo**: expensive, isolated.
4. **Bridge**: shared app, per-tenant data.
5. **Cell-based**: bounded blast radius at scale.
6. **Per-tenant rate limiting** mandatory.
7. **Tenant context propagation** in every layer.
8. **Compliance** may dictate isolation.
9. **Offboarding** must be comprehensive.
10. **Hybrid models** for varying tenant needs.

---

## Final Mental Model

> **Multi-tenancy is the architecture under every SaaS. The strategy chosen determines how customers experience your service: shared infrastructure with potential noise, or isolated infrastructure with higher cost. The right answer is usually neither pure pool nor pure silo, but a hybrid that matches different tenant tiers to different isolation levels.**

The senior SaaS architect treats multi-tenancy as a design dimension that touches every component. Database schemas, caches, observability, deployment — all have tenant implications. The teams that get this right scale from one tenant to thousands without re-architecture; the teams that don't pay for the right answer in tears, three years in.

That's multi-tenancy. That's the structural decision under every B2B SaaS. That's the architecture that determines whether you can grow gracefully or whether each new customer is a one-off operational burden.
