# Database Federation — Split by Function

## A. Intuition First
Sharding splits *rows* of one big table across machines. **Federation** splits *whole tables / domains* across machines by function. Users DB on one node; products DB on another; analytics DB on a third.

## B. Mental Model
- Good for separating concerns (and scaling them independently).
- Natural step when you move toward microservices — each service owns its DB.

## C. Internal Working
- One writer per function; each DB has its own schema and backups.
- Joins across functional DBs must happen in the application layer (or via CDC into a data warehouse).

## D. Visual Representation
```
[Users service] → [Users DB]
[Products service] → [Products DB]
[Orders service] → [Orders DB]
```

## E. Tradeoffs
### Pros
- Scale each DB independently.
- Isolated failure domains.
- Smaller per-DB working set (better cache hit ratio).

### Cons
- No cross-functional joins in SQL.
- Need orchestration for cross-functional transactions (see [Distributed Transactions](distributed-transactions.md)).
- More ops overhead.

## F. Interview Lens
- "Federation vs sharding?" — federation = by function, sharding = by key within a table.
- "How do you report across federated DBs?" — ETL/CDC into a warehouse (BigQuery, Snowflake, Redshift).
- Pitfalls: starting microservices too early; needing joins you now can't do.

## G. Real-World Mapping
Every microservice architecture. Amazon's earliest rearchitecture (circa 2001) was essentially federation.

## H. Questions
**Beginner**: What's DB federation?
**Intermediate**: When do you pick federation over one big DB?
**Advanced**: How do you do cross-service transactional workflows after federating?

## I. Mini Design
An e-commerce app with users, catalog, orders, analytics. Federate into 4 DBs; use a message bus for cross-domain events; ETL all to BigQuery for reporting.

## J. Cross-Topic Connections
- [Sharding](sharding.md), [Microservices](../architecture/monolith-vs-microservices.md), [Event-Driven Architecture](../architecture/event-driven-architecture.md).

## K. Confidence Checklist
- [ ] Can contrast with sharding.
- [ ] Knows cross-functional joins require analytics warehouse or aggregation service.

## L. Potential Gaps & Improvements
- CDC tools (Debezium, Kafka Connect) deserve coverage.
- Data warehouse / lakehouse architectures.
