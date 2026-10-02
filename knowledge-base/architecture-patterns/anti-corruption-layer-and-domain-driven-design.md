# Anti-Corruption Layer & Domain-Driven Design

> *"Most software complexity isn't technical; it's that two parts of the system mean different things by the same words. The order in your shopping cart isn't the order in fulfillment isn't the order in billing. They're three different concepts the business uses interchangeably and the code conflates. Domain-Driven Design is the discipline of taking these distinctions seriously."*

---

## Topic Overview

Domain-Driven Design (DDD), Eric Evans's 2003 book, is one of the most influential — and most uneven-adopted — works in software architecture. Its insight: software complexity is dominated by *domain complexity*, not technical complexity. The job of a software architect is to model the domain accurately, with rigorous vocabulary that matches how the business actually thinks.

The patterns: **Bounded Contexts** (different parts of the system have different vocabulary, deliberately), **Aggregates** (groups of objects treated as a unit), **Domain Events** (significant happenings in the domain), **Anti-Corruption Layer (ACL)** (a translation layer between bounded contexts that prevents one's vocabulary from polluting another's).

The anti-corruption layer in particular is the practical workhorse. When you integrate with a legacy system, an external API, or a different team's service, an ACL stops their model from invading yours. Your code stays clean; their oddities are isolated.

This is the topic where software architecture becomes about *language* and *concept boundaries*, not just modules and classes. DDD is widely cited and inconsistently practiced. The teams that internalize it produce systems that age gracefully; the teams that don't produce code that conflates concepts and accumulates complexity.

---

## Intuition Before Definitions

Imagine a hospital with three departments: emergency, surgery, billing.

In the **emergency department**, "patient" means "someone who walked in with a problem." Their data: vitals, complaints, triage level. Their lifecycle: arrive, get treated, discharge or admit.

In **surgery**, "patient" means "someone scheduled for a procedure." Their data: pre-op tests, surgeon, anesthesiologist, OR booking. Their lifecycle: scheduled, prepped, operated, recovery, discharge.

In **billing**, "patient" means "an account paying for services." Their data: insurance, charges, payment plan. Their lifecycle: balance, payments, collections.

Same person; three different conceptions. Same word ("patient"); three different *models*.

A naive system tries to be a single "Patient" object with all the fields from all departments. It becomes huge, messy, hard to change. A surgery enhancement breaks billing logic. An ER form change cascades to billing.

A DDD-shaped system has three bounded contexts: ER's Patient, Surgery's Patient, Billing's Patient. They share an ID; they're translated as patients move between contexts. Each is small, focused, evolvable independently.

That's bounded contexts. That's the insight DDD makes formal: don't merge concepts that the business treats differently. The boundary is the architecture.

---

## Historical Evolution

**Era 1 — Eric Evans's book (2003).**
"Domain-Driven Design: Tackling Complexity in the Heart of Software." Defines the vocabulary, the patterns, the philosophy. Influential but adoption uneven.

**Era 2 — Slow uptake.**
2003-2010. DDD was talked about more than practiced. Many teams adopted vocabulary without practice.

**Era 3 — Microservices alignment.**
~2014. Microservices = bounded contexts at the service level. DDD's relevance surged.

**Era 4 — Event-driven and CQRS.**
~2015. Domain events; CQRS; event sourcing. DDD informed these patterns and was informed by them.

**Era 5 — Modern DDD practice.**
2018+. Better tooling, better books (Vaughn Vernon's "Implementing DDD"). Continuous discovery (Event Storming) as a workshop technique.

**Era 6 — Pragmatic DDD.**
Today. Most teams use bounded contexts and ACLs even without naming DDD. The pattern wins; the vocabulary is sometimes silent.

The pattern: DDD's insights are now widespread; the explicit practice remains specialized. Teams that don't know DDD often re-invent its patterns.

---

## Core Mental Models

**1. The same word can mean different things in different contexts.**
"Order" in cart, fulfillment, and billing are different things. Don't merge them.

**2. Bounded contexts have their own vocabulary.**
The "ubiquitous language" of one context is the dialect spoken there. Crossing contexts requires translation.

**3. Aggregates are consistency boundaries.**
A group of objects treated as one unit. Updates within an aggregate are atomic; across aggregates, eventually consistent.

**4. The anti-corruption layer is translation.**
When integrating contexts (or external systems), translate models. Don't let foreign vocabulary leak in.

**5. Domain events are first-class.**
Important things that happen in the domain ("OrderPlaced," "PaymentReceived") are events. Other parts of the system react to them.

---

## Deep Technical Explanation

### Bounded contexts

A bounded context is a part of the system with its own:
- **Vocabulary** (ubiquitous language).
- **Model** (classes, data structures).
- **Implementation** (code, database).

Different contexts can have:
- Different definitions of the same word.
- Different fields on the "same" entity.
- Different lifecycles.

Examples in an e-commerce system:
- **Catalog**: products with descriptions, images, search-relevant attributes.
- **Cart**: items being considered for purchase.
- **Order**: a confirmed purchase with line items, totals.
- **Fulfillment**: orders being prepared and shipped.
- **Returns**: orders coming back.

Each is a context. "Product" in catalog has marketing description; "Product" in fulfillment has weight, dimensions, warehouse location. Don't try to merge.

### Identifying bounded contexts

Heuristics:
- **Different teams**: each team's territory is a candidate context.
- **Different vocabularies**: where the same word means different things.
- **Different lifecycles**: where the entity's state evolves differently.
- **Different change rates**: things that change together belong together.

Workshops like **Event Storming** discover bounded contexts collaboratively.

### Aggregates

Within a bounded context, an aggregate is:
- A cluster of related objects (entities, value objects).
- Treated as a unit for data changes.
- Has a *root* — the entry point for external code.
- Internal consistency is enforced.

Example: an `Order` aggregate contains `OrderLine` items, an `Address`, a `PaymentMethod`. External code interacts with `Order`; doesn't directly manipulate `OrderLine`.

Aggregates are the unit of transaction:
- Updates within an aggregate are ACID.
- Updates across aggregates are eventual.

This shapes implementation: each aggregate maps to a transaction; cross-aggregate operations use sagas or domain events.

### Aggregate sizing

A common DDD mistake: too-large aggregates.
- One giant `Customer` containing all orders, all payments, all preferences.
- Updates contend; transactions long.

Or: too-small aggregates.
- An `OrderLine` separate from `Order`.
- Consistency between them not enforced.

The right size: the smallest aggregate that maintains the invariants you care about. "An order's lines must sum to its total" is an invariant; `OrderLine` belongs in `Order`. "An order references a customer" is just a reference; `Customer` is its own aggregate.

### Domain events

A domain event is something that happened in the domain that other parts of the system might care about.

Examples:
- `OrderPlaced`
- `PaymentCompleted`
- `ItemShipped`
- `CustomerAddressChanged`

Properties:
- **Past tense**: events describe what happened.
- **Immutable**: events don't change.
- **Have a timestamp** and a causal ID.
- **Carry minimal context**: just enough for consumers to act.

Events enable:
- Loose coupling between bounded contexts.
- Audit trail.
- Eventual consistency across aggregates.

### The anti-corruption layer (ACL)

When two bounded contexts integrate, the ACL is a translation layer.

```
[Context A] → [ACL] → [Context B]
```

The ACL:
- Speaks A's language to A.
- Speaks B's language to B.
- Translates between them.
- Hides B's quirks from A.

When integrating with a legacy system or external API: ACL.

Example: a modern catalog service must integrate with a legacy ERP. The ERP has weird field names, non-standard data formats, idiosyncratic business rules. The ACL:
- Receives clean catalog requests.
- Translates to ERP's format.
- Sends to ERP.
- Receives response.
- Translates back.

Your catalog code never sees ERP's vocabulary. ERP changes don't ripple through your code.

### When to use an ACL

- Integrating with **legacy systems**: their model shouldn't pollute new code.
- **Third-party APIs**: vendor-specific quirks isolated.
- **Cross-team services**: if their model differs from yours, translate.
- **Versioning**: when an upstream service changes, the ACL absorbs the change.

The ACL is the architectural equivalent of "good fences make good neighbors."

### Context mapping

Different relationships between bounded contexts:

**Shared kernel**: small overlap of model. Fragile; needs coordination.

**Customer-supplier**: one context provides services to another. Supplier accommodates customer's needs.

**Conformist**: one context simply uses another's model. No translation; coupling is high.

**Anti-corruption layer**: translate to protect.

**Open host service**: a context publishes a public API; many consumers.

**Published language**: a shared format (e.g., events) that contexts agree on.

These are vocabulary. The patterns recur across architectures.

### Strategic vs tactical DDD

**Strategic**: high-level. Bounded contexts, context maps, ubiquitous language.

**Tactical**: low-level. Aggregates, entities, value objects, repositories, factories.

Strategic DDD is more important and less practiced. Many teams adopt tactical patterns (entities, value objects) without the strategic insight (bounded contexts, ACLs). The result is "DDD-shaped code without DDD's benefits."

### Event Storming

A workshop technique for discovering bounded contexts:
- Stakeholders write events on sticky notes.
- Place on a timeline.
- Group; identify aggregates.
- Identify boundaries (where vocabulary changes).
- Output: bounded contexts, aggregates, key events.

Surprisingly effective. Many teams report breakthroughs from Event Storming after years of stuck architecture discussions.

### DDD and microservices

Bounded contexts ≈ microservice boundaries. Each microservice is one (or sometimes two) bounded contexts.

This alignment isn't accidental: microservices done well *follow* DDD. Microservices done poorly (split by tier or technology) violate it and pay the price.

The recommendation: identify bounded contexts first; create services around them.

### DDD and CQRS / Event Sourcing

Natural alignment:
- **CQRS**: separate read/write models, often per bounded context.
- **Event sourcing**: domain events as the source of truth.
- **Domain events**: integration mechanism.

Many DDD systems naturally evolve to use these patterns.

### When DDD doesn't fit

Not every system needs DDD:
- **Simple CRUD apps**: domain is shallow; DDD is overkill.
- **Pure technical infrastructure**: the "domain" is the technical concern.
- **Throwaway prototypes**: DDD's discipline costs time.

DDD shines for systems with rich, evolving business logic. Don't impose it everywhere.

---

## Real Engineering Analogies

**The legal system's specialized courts.**
Family court, criminal court, tax court, traffic court. Each has its own procedures, vocabulary, judges. They share a person ("the defendant") but treat them with different concerns. The court structure is a real-world bounded-context architecture.

**The hospital department analogy.**
(Already used.) Each department has its own model of "patient." Translation between departments is real work — discharge summary from ER becomes referral to surgery becomes transfer to billing.

---

## Production Engineering Perspective

What goes wrong:

- **The shared-everything model.** All systems use one giant `Customer` object. Changes anywhere break everywhere. Migration to bounded contexts takes years.
- **The legacy-vocabulary leak.** Integration with a legacy system; no ACL. Legacy field names spread through new code. Cleanup is painful.
- **The anemic aggregate.** Aggregate without behavior; just data. Business logic spread across "service" classes. DDD's organizational benefit lost.
- **The transaction-boundary mismatch.** Cross-aggregate transactions in code; fight against eventual consistency that DDD prescribes; bugs.
- **The DDD-ish project.** Team uses DDD vocabulary (entity, value object) without applying the strategic patterns (bounded contexts, context mapping). Code looks DDD; problems unsolved.

The senior architect's habits:
- **Identify bounded contexts** explicitly.
- **Define ubiquitous language** with stakeholders.
- **Use ACLs** at context boundaries.
- **Right-size aggregates** for invariants.
- **Domain events** for cross-context communication.

---

## Failure Scenarios

**Scenario 1 — The shared-customer disaster.**
One Customer class used across order, billing, support, marketing. Each team adds fields. After 5 years: 200-field class; tests slow; changes risky. Migration to bounded contexts: 18 months.

**Scenario 2 — The legacy leak.**
Integration with mainframe; no ACL. Mainframe field names (`CUST_NM_LST_FRST`) appear throughout new code. Clean up later: complete refactor.

**Scenario 3 — The cross-aggregate transaction.**
Code attempts atomic update across two aggregates. Database transaction works locally; sometimes deadlocks. Re-architecture: domain events; eventual consistency.

**Scenario 4 — The Event Storming success.**
Three years of architecture arguments. Day-long Event Storming workshop reveals five distinct bounded contexts that nobody had named. Architecture clarifies. Six months of implementation; delivery accelerates.

**Scenario 5 — The DDD-ish disappointment.**
Team adopts entities, value objects; doesn't define bounded contexts. Code is "DDD-shaped" but coupling problems persist. Realization: strategic DDD matters more than tactical.

---

## Performance Perspective

- **DDD has no inherent performance cost.**
- **Aggregates** as transaction boundaries align with database performance.
- **ACLs** add a translation hop; small cost.
- **Domain events** typically async; performance varies with infrastructure.

---

## Scaling Perspective

- **Bounded contexts → microservices**: natural alignment.
- **Aggregates → shard keys**: aggregates are natural units of partitioning.
- **Domain events → event-driven architecture**: natural integration.
- **At hyperscale**: each bounded context can be its own service with its own database, scaled independently.

---

## Cross-Domain Connections

- **Microservices vs monolith**: bounded contexts inform service boundaries. (See [microservices-vs-monolith.md](./microservices-vs-monolith.md).)
- **Event-driven architecture**: domain events fit naturally. (See [event-driven-architecture.md](./event-driven-architecture.md).)
- **CQRS / event sourcing**: complementary patterns. (See [cqrs-and-event-sourcing.md](./cqrs-and-event-sourcing.md).)
- **Sagas**: cross-aggregate consistency. (See [saga-pattern-and-distributed-transactions.md](./saga-pattern-and-distributed-transactions.md).)
- **Strangler fig**: ACLs are part of strangler-fig migrations. (See [strangler-fig-and-legacy-migration.md](./strangler-fig-and-legacy-migration.md).)

The unifying observation: **DDD is the discipline of taking domain vocabulary seriously. Bounded contexts, aggregates, anti-corruption layers — these are tools for managing the *cognitive* complexity of business systems, which usually dwarfs the technical complexity.**

---

## Real Production Scenarios

- **Eric Evans's book examples**: shipping, banking.
- **Vaughn Vernon's "Implementing DDD"**: practical case studies.
- **Microservices migrations** at large companies: typically informed by DDD, even when not labeled.
- **Event Storming workshops**: documented successes at many companies.

---

## What Junior Engineers Usually Miss

- That **bounded contexts are real**.
- That **ACLs prevent vocabulary contamination**.
- That **aggregates are transaction boundaries**.
- That **strategic DDD > tactical DDD**.
- That **domain events** are first-class.
- That **simple CRUD doesn't need DDD**.
- That **DDD is about language**, not classes.

---

## What Senior Engineers Instinctively Notice

- They **identify bounded contexts** in design discussions.
- They **introduce ACLs** at integration points.
- They **right-size aggregates**.
- They **respect ubiquitous language**.
- They **use domain events** for cross-context communication.
- They **align microservices with bounded contexts**.

---

## Interview Perspective

What gets tested:

1. **"What's a bounded context?"** Tests fundamental.
2. **"What's an anti-corruption layer?"** Translation between contexts.
3. **"What's an aggregate?"** Consistency boundary.
4. **"How does DDD relate to microservices?"** Bounded contexts ≈ services.
5. **"What's ubiquitous language?"** Shared vocabulary within context.
6. **"When wouldn't you use DDD?"** Simple CRUD; no rich domain.

Common traps:
- Believing DDD is just classes and patterns.
- Not knowing about strategic vs tactical.

---

## 20% Knowledge Giving 80% Understanding

1. **Bounded contexts** = different vocabularies for different parts.
2. **Ubiquitous language** within each context.
3. **Anti-corruption layer** for integration translation.
4. **Aggregates** are consistency boundaries.
5. **Domain events** for cross-context.
6. **Strategic DDD** matters more than tactical.
7. **Microservices align** with bounded contexts.
8. **Event Storming** discovers contexts.
9. **Right-size aggregates** for invariants.
10. **Skip DDD for simple CRUD**.

---

## Final Mental Model

> **Domain-Driven Design says the hard problem of software is not technology — it's modeling the business correctly. Bounded contexts honor that different parts of the business mean different things. Anti-corruption layers protect those distinctions when systems integrate. The discipline isn't trendy; the systems that have it scale gracefully through years of business evolution.**

The senior architect using DDD listens to the business carefully. They identify the words that mean different things in different rooms. They model accordingly. They put translation layers at boundaries. They keep aggregates focused. They use domain events for loose coupling.

The systems that age well are the ones whose architects took domain language seriously. The systems that calcify are the ones with one giant model trying to mean everything to everyone. DDD is the discipline that produces the former.

That's anti-corruption layers. That's domain-driven design. That's the architectural philosophy that puts language and concept boundaries at the center of design — and produces software that maps cleanly to the business it serves.
