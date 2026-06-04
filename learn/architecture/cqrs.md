# CQRS — Separate Writes from Reads

## A. Intuition First
CQRS = Command Query Responsibility Segregation. **Commands** (writes) use one model; **queries** (reads) use another. Two models, optimized separately.

Why: reads and writes have wildly different patterns — denormalized read models, different storage tech, different scaling.

## B. Mental Model
- **Command side**: normalized, transactional (SQL, event store).
- **Query side**: denormalized, eventually-consistent read views (materialized views, search index, cache).
- **Sync** between them via events / CDC.

## C. Internal Working
1. Client submits a command → command handler validates + persists (maybe emits event).
2. Event is propagated → query-side projector updates read models.
3. Clients read from read models (possibly stale but fast).

## D. Visual Representation
```
[Client]──Cmd──▶ [Write model / DB] ──events──▶ [Projector] ──▶ [Read model]
[Client]─────── Query ─────────────────────────────────────────▶ [Read model]
```

## E. Tradeoffs
**Pros**: scale reads and writes independently, optimize schemas per side, natural fit with event sourcing.
**Cons**: complexity, eventual consistency on read side, more moving parts.

Use CQRS where reads dominate and require aggressive denormalization. Don't use it for a simple CRUD app.

## F. Interview Lens
- "When CQRS?" — heavy-read + complex-write systems with divergent requirements.
- "CQRS without event sourcing?" — yes, often done (just sync read model via CDC).
- Pitfalls: applying CQRS everywhere; stale reads breaking user expectations.

## G. Real-World Mapping
Amazon product catalog, Twitter feed, most large e-commerce platforms.

## H. Questions
**Beginner**: What is CQRS?
**Intermediate**: How is consistency maintained between sides?
**Advanced**: Design a CQRS system for a forum (posts, comments, feeds).

## I. Mini Design
Forum:
- Write side: Postgres (users, posts, comments with FKs).
- Events on every write.
- Read model: Elasticsearch for search + Redis for feeds.

## J. Cross-Topic Connections
- [Event Sourcing](event-sourcing.md), [EDA](event-driven-architecture.md), [Caching](../foundations/scaling/caching.md).

## K. Confidence Checklist
- [ ] Knows command vs query separation.
- [ ] Knows it's eventual on the read side.

## L. Potential Gaps & Improvements
- **CDC (Change Data Capture)** — tools like Debezium stream every row change out of the write database into the read side so the two models stay in sync; the standard answer to "how do you sync without dual-writes?"
- **Read model rebuilds** — replaying the full event/change log to regenerate a query view from scratch; lets you fix bugs, add new projections, or recover a corrupted read store without touching the write side.
- **Eventual consistency lag** — the delay between a write landing and the read model reflecting it; matters because users may not see their own change immediately (→ see Interview Lens).
- **Projection idempotency** — making the projector safe to re-run the same event twice without double-counting; essential because at-least-once delivery means events repeat.

**🔧 How to close:** Spin up the Debezium tutorial stack with `docker-compose -f debezium-mysql.yaml up`, insert a row into the source MySQL table, then `kafka-console-consumer --topic dbserver1.inventory.customers` and watch the change event appear — that captured event is exactly what a CQRS projector would consume to update a read model.
