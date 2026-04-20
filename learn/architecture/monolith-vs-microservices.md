# Monoliths vs Microservices

## A. Intuition First
- **Monolith**: one deployable, one codebase. Everything in one process.
- **Microservices**: many small services, each with its own deploy, data, and team.

Microservices are not "better". They trade simplicity for flexibility + team independence + fault isolation.

## B. Mental Model
- Start with a monolith. Split only when coupling or scaling forces it.
- Each microservice owns its data; services communicate over network (HTTP/gRPC/events).

## C. Internal Working
### Monolith
- Shared codebase, shared DB, in-process calls.
- Simple to reason about, deploy atomic.
- Scales by running more copies behind LB.

### Microservices
- Each service = its own repo or module, deployment pipeline, DB.
- Communicate via REST/gRPC for sync, queue/pub-sub for async.
- Requires: service discovery, distributed tracing, centralized logging, API gateway, observability from day 1.

## D. Visual Representation
```
Monolith:         [Web + Svc + DB-client]──→ [DB]
Micro:     [Web] → [Orders] → [Orders DB]
                → [Inventory] → [Inv DB]
                → [Payment] → [Pay DB]
```

## E. Tradeoffs
| | Monolith | Microservices |
|---|---|---|
| Complexity | Low (1 service) | High (N services) |
| Deploy | Atomic, sometimes risky | Independent |
| Team scaling | One team bottleneck | Parallel teams |
| Fault isolation | One bug breaks all | Isolated |
| Ops cost | Low | High |
| Data consistency | Trivial | Hard (distributed tx / sagas) |

## F. Interview Lens
- "When do you split?" — when team size + domain complexity outgrow one codebase.
- "Shared DB anti-pattern?" — yes, each service must own its data.
- "Distributed monolith?" — many services but tightly coupled deploys = worst of both worlds.
- Pitfalls: starting with microservices for a team of 3.

## G. Real-World Mapping
- Amazon, Netflix, Uber: heavy microservices.
- Basecamp, Stack Overflow, Shopify: monolith-majuscule for most of their life.

## H. Questions
**Beginner**: Monolith vs microservices pros/cons.
**Intermediate**: When to split?
**Advanced**:
1. Extract a service from a monolith with zero downtime.
2. Describe the distributed monolith anti-pattern.

## I. Mini Design
A 5-year-old monolith: extract the payments module into a service. Steps: isolate module, add API boundary, dual-write in both old and new for a week, shift reads, remove from monolith.

## J. Cross-Topic Connections
- [API Gateway](api-gateway.md), [Service Discovery](../reliability/service-discovery.md), [Distributed Transactions](../data/distributed-transactions.md), [Event-Driven Architecture](event-driven-architecture.md).

## K. Confidence Checklist
- [ ] Can defend when to NOT use microservices.
- [ ] Knows the operational prerequisites (observability, tracing, CI/CD).

## L. Potential Gaps & Improvements
- Modular monolith as a middle ground.
- Strangler fig pattern for migration.
