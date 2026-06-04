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
- **Carpool / Uber Pool matching** — grouping multiple riders whose routes overlap into one car; a much harder optimization problem (route detours, ETA tradeoffs) that tests how you model constraints under load.
- **Fraud detection (fake trips)** — spotting GPS spoofing or collusion where drivers/riders fake rides to farm incentives; matters because payments and trust depend on it.
- **Driver incentives modeling** — surge pricing and bonus schemes that nudge driver supply toward high-demand areas; key for any "balance supply and demand" question. (→ see Advanced Questions)
- **ETA prediction** — machine-learning model that estimates arrival time from live traffic and historical data; learners care because matching and pricing both depend on accurate ETAs.

**🔧 How to close:** Build a tiny in-memory geo-index demo: install the `geohash2` Python package (`pip install geohash2`), encode 20 random lat/long pairs to geohashes, then write a function that, given a rider's geohash prefix, returns all drivers sharing that prefix — this is exactly how proximity matching narrows the search space.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🗺️ Gap 1 — Geo-Index Internals: H3 vs Geohash vs Quadtree
- 🔹 **What it is**: The actual data structures that turn "find drivers near me" into a fast lookup — hex cells (H3), rectangular prefixes (geohash), or recursively-subdivided trees (quadtree).
- 🔹 **Why it matters**: Every map/proximity question (Uber, Yelp, Tinder, food delivery) hinges on this, and interviewers love probing *why* you picked one.
- 🔹 **Connection**: The Deep Dives use Redis GEO and H3 cells with "adjacent 6 hex neighbors"; this gap explains why 6 neighbors (hexagons have uniform adjacency) and why H3 beats geohash near the poles.
- 🔹 **When needed**: 🟢 **Foundational** — anyone doing location-based design needs the mental model.
- 🔹 **Intuition**: Hexagons are like a soccer-ball/honeycomb tiling — every neighbor is the same distance away. Geohash rectangles are like graph paper: two cells touching only at a corner are "neighbors" but feel far, and the squares stretch as you move toward the poles.
- 🔹 **If you go deeper**: Read Uber's open-source H3 docs (uber.github.io/h3), then compare with Redis `GEOSEARCH` (uses geohash + sorted sets) and Google S2 (used by many mapping systems).
- 🔹 **Interview hook**: *"Why H3 hexagons over geohash rectangles?"* → Uniform neighbor distance and no latitude distortion make ranking-by-proximity and neighbor scans cleaner.

---

#### 🛣️ Gap 2 — ETA Prediction at Scale
- 🔹 **What it is**: Estimating arrival time from live traffic, road graphs, and historical patterns — not just straight-line distance.
- 🔹 **Why it matters**: Both matching (rank by ETA) and pricing (upfront fare) depend on it; a bad ETA cascades into bad dispatch and angry users.
- 🔹 **Connection**: The Dispatch deep dive explicitly says "Rank by ETA (not just distance — real-road routing matters)" — this gap is *how* that ETA gets computed.
- 🔹 **When needed**: 🟡 **Mid-level** for the system-integration view; 🔴 **Senior** if they push into the ML modeling side.
- 🔹 **Intuition**: Like a GPS app that knows the highway is jammed and reroutes you through side streets — it's blending a road map with real-time traffic and "what usually happens at 6pm Friday."
- 🔹 **If you go deeper**: Read Uber's engineering posts on their ETA system (DeepETA / graph-based routing) and study contraction-hierarchies routing used by OSRM/Valhalla.
- 🔹 **Interview hook**: *"How do you compute ETA for millions of requests cheaply?"* → Precompute a routing graph with contraction hierarchies, cache segment travel-times, layer an ML correction on top.

---

#### 📍 Gap 3 — Surge / Driver-Incentive Feedback Loop
- 🔹 **What it is**: Surge isn't just a price tag — it's a control loop that nudges driver supply toward high-demand cells via bonuses and visible multipliers.
- 🔹 **Why it matters**: It's the heart of any "balance supply and demand" question, and shows you understand systems as feedback loops, not static functions.
- 🔹 **Connection**: Builds directly on the "🪜 Surge math" section (supply/demand ratio per H3 cell) — this gap closes the loop by asking what the multiplier *does* to behavior, and addresses the file's "Driver incentives modeling" gap bullet.
- 🔹 **When needed**: 🟡 **Mid-level** — common in product-leaning rounds; 🔴 **Senior** for the stability/oscillation concerns.
- 🔹 **Intuition**: Like a thermostat — high demand "heats up" a cell, surge raises the price, drivers flow in, demand cools, surge drops. Tune it wrong and it oscillates (drivers all rush one cell, then it crashes).
- 🔹 **If you go deeper**: Read Uber's "marketplace" engineering posts on dynamic pricing; study control-theory basics (damping, hysteresis) and why surge uses smoothing/clamping (the `clamp(1.0, 3.5, ...)` in this file).
- 🔹 **Interview hook**: *"How do you stop surge from oscillating wildly?"* → Smooth the ratio over a window, clamp the multiplier, and add hysteresis so it doesn't flip on every tick.

---

#### 🔐 Gap 4 — Trust & Safety: GPS Spoofing and Fake-Trip Fraud
- 🔹 **What it is**: Detecting fabricated rides — GPS spoofing, driver/rider collusion to farm incentives, or impossible-travel patterns.
- 🔹 **Why it matters**: Payments and the entire incentive system are only as trustworthy as your ability to spot fakes; it's a real money-loss vector.
- 🔹 **Connection**: The Payments saga and "Driver incentives" assume trips are real; this gap (the file's "Fraud detection" bullet) protects those assumptions.
- 🔹 **When needed**: 🔴 **Senior** — usually a follow-up, not a core requirement, but strong signal when raised proactively.
- 🔹 **Intuition**: Like a casino watching for card-counters — most players are honest, but you build detectors for the physically-impossible (a driver "teleporting" 50km in 10 seconds, or two phones reporting identical GPS).
- 🔹 **If you go deeper**: Study anomaly-detection pipelines (streaming features on Kafka → rules + ML scoring), and read about device-attestation and impossible-travel checks used in fraud/auth systems.
- 🔹 **Interview hook**: *"How would you catch a driver faking trips to earn bonuses?"* → Cross-check GPS trajectory plausibility, device fingerprints, and pickup/dropoff colocation against the trip's event stream.

---

#### 🚗 Gap 5 — Carpool / Pool Matching (Route-Overlap Optimization)
- 🔹 **What it is**: Grouping riders whose routes overlap into one vehicle while honoring detour and ETA limits — a hard combinatorial optimization on top of basic dispatch.
- 🔹 **Why it matters**: It tests whether you can model real constraints (max detour, capacity, time windows) under load, well beyond "find nearest driver."
- 🔹 **Connection**: Extends the single-rider Dispatch flow; the trip state machine must now juggle multiple riders' pickups/dropoffs in one trip.
- 🔹 **When needed**: 🔴 **Senior** — niche and genuinely hard; raise it to show depth, not as a default.
- 🔹 **Intuition**: Like a school bus route planner — you can pick up more kids, but only if each one's extra detour stays small enough that nobody revolts.
- 🔹 **If you go deeper**: Read about Uber Pool / Lyft Line matching and the Dynamic Ride-Sharing (DARP — Dial-A-Ride Problem) literature; study greedy insertion heuristics vs. batch optimization windows.
- 🔹 **Interview hook**: *"How do you decide whether to add a rider to an existing pool trip?"* → Insertion heuristic: accept only if the added detour keeps every existing rider within their ETA/detour budget.

---

### 🏆 Start here if you have limited time
1. **Geo-Index Internals (Gap 1)** — it underpins matching, surge cells, and every other location question; without it the rest doesn't click.
2. **Surge / Driver-Incentive Feedback Loop (Gap 3)** — the single most-asked Uber-specific concept, and it builds on the surge math already in this file.

---

### 🧭 Suggested Deep Dive Order
1. **Geo-Index Internals: H3 vs Geohash vs Quadtree** (~1h; foundational for all proximity matching).
2. **Surge / Driver-Incentive Feedback Loop** (~1h; highest-value Uber-specific topic).
3. **ETA Prediction at Scale** (~1.5h; connects matching and pricing, partly ML).
4. **Trust & Safety: GPS Spoofing / Fraud** (~1h; senior follow-up signal).
5. **Carpool / Pool Matching** (~2h; hardest, niche optimization depth).
