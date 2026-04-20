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
- CDC tooling (Debezium) for sync.
- Read model rebuilds.
