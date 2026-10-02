# Case Study — Design Uber

## A. Intuition First
Real-time matching of riders and drivers, both moving. The interesting parts: geo-indexing, matching, pricing, and ETA.

## B. Requirements
**Functional**
- Rider requests ride; system matches with nearby driver.
- Live location tracking.
- Pricing (including surge).
- Trip history, payments.

**Non-functional**
- Dispatch < 2 s.
- Scale: 15M+ rides/day.
- Geo-correctness near 100% (don't send a rider across town).
- Handle spikes (rainy evenings).

## C. Estimation
- 15M rides/day ≈ 170/s avg; peaks 1k/s.
- Active drivers: 1M+ at peak, sending location updates every 3–5 s → ~300k loc updates/s peak.
- Storage of rider/driver locations: hot in Redis/Cassandra.

## D. High-Level Architecture
```
Rider/Driver app ─→ API Gateway ─→ Location svc (geo-index)
                                 ─→ Dispatch svc (matching)
                                 ─→ Pricing svc (surge)
                                 ─→ Trip svc (state machine)
                                 ─→ Payment svc
                                 ─→ Maps/ETA service (map data)
```

## E. Deep Dives

### Location tracking
- Drivers send GPS updates every few seconds over WebSocket or long-polling.
- Stored in an in-memory geo-index (Redis GEO, or Uber's own H3 hex-grid).
- Indexed by geohash / H3 cell.

### Dispatch / matching
- Rider request → compute rider's cell.
- Query nearby cells (current + adjacent 6 hex neighbors).
- Filter by driver availability + vehicle type.
- Rank by ETA (not just distance — real-road routing matters).
- Offer ride to top driver; on accept, commit; on reject, offer next.
- Timeouts on acceptance.

### Pricing / surge
- Geo cells continuously computing supply/demand ratio.
- Surge = multiplier based on ratio.
- Rider sees upfront fare computed from route, traffic, surge.

### 🪜 Surge math (concrete)

For each H3 cell every ~30s:
- `supply` = active drivers in cell.
- `demand` = pending rider requests in cell over the last 5 min.
- `ratio = demand / max(supply, 1)`.
- `surge = clamp(1.0, 3.5, f(ratio))` — e.g., step function: >1.5 → 1.2×, >3 → 2.0×.

Hot-cell problem during rush hour in a dense zone:
- 10,000 concurrent rider requests → hot cell hammered.
- Mitigation: **replicate cell state across 3 shards** and fan-out reads; writes still one authoritative shard but consistency is eventual (good enough for surge).

> **🧠 What if surge was computed globally instead of per-cell?**
> Oversupply in downtown wouldn't suppress surge in airport zone with undersupply. Per-cell granularity is what lets surge match actual local imbalance.
>
> **🔎 Quick Check** — Concert ends at Wembley, 50k riders request at once. What's the system's first visible reaction?
> **🎯 Recall** — Wembley's H3 cells see demand spike, surge multiplier jumps, riders see higher fares, marginal drivers get nudged toward the cell.

### Trip state machine
States: Requested → Accepted → EnRoute → Arrived → InTrip → Completed / Cancelled.
Each transition emits an event (Kafka) consumed by billing, analytics, notifications.

### Payments
- Saga: authorize card at trip start, capture at end; handle failures with retries and customer contact.

## F. Tradeoffs
- Cassandra for trip history (high write volume).
- Redis for hot location index (must be sub-ms).
- H3 hex cells over geohash rectangles: less distortion at different latitudes; better for neighbor queries.
- Sagas over 2PC: payment + trip + notifications must all eventually succeed or compensate.

## G. Interview Lens
- "How do you match driver + rider fast?" — geo-index + nearest-cell query.
- "How does surge work?" — cell-level supply/demand metric.
- "What happens during a network partition between regions?" — per-region dispatch; regional autonomy.
- "How do you handle driver dropping?" — heartbeat timeout → evict from index; trip state machine can reassign.

## H. Questions
**Beginner**: Why geohash/H3?
**Intermediate**:
1. How to not double-book a driver.
2. ETA computation at scale.
**Advanced**:
1. Design surge pricing algorithm.
2. Multi-region active-active for a global service.

## I. Cross-Topic Connections
- [Geohashing/Quadtrees](../reliability/geohashing-quadtrees.md), [WebSockets](../architecture/long-polling-websockets-sse.md), [Message Brokers](../architecture/message-brokers.md), [Distributed Transactions](../data/distributed-transactions.md), [Sharding](../data/sharding.md), [Consistent Hashing](../data/consistent-hashing.md).

## J. Confidence Checklist
- [ ] Full dispatch flow with geo-index.
- [ ] State machine for trips.
- [ ] Payments via saga.

## K. Potential Gaps & Improvements
- Carpool / Uber Pool matching (harder optimization).
- Fraud detection (fake trips).
- Driver incentives modeling.
