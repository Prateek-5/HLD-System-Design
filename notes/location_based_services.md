# Location-Based Services (Geo Indexing)

### 🔹 1. What This Topic Actually Is
Storing and querying geographic data: "find X within Y km of (lat,lon)", driver dispatch, delivery matching, proximity search.

### 🔹 2. Why It Exists
- Generic B-tree DB can't efficiently do "within 1 km of (12.97, 77.59)".
- Spatial indexes let you group by space and prune candidate set to O(log N).

### 🔹 3. Core Concepts (High Signal)
- **Geohash**: interleave lat/lon bits → base32 string. Longer prefix = smaller cell. Nearby points share prefixes.
- **Quadtree / R-tree**: recursive spatial partitioning (quadrants or bounding boxes).
- **H3 (Uber)**: hexagonal global grid. Better distance isotropy than geohash rectangles.
- **S2 (Google)**: spherical geometry + Hilbert curve → 1D index on 2D sphere; used in Maps.
- **Edge problem**: two nearby points can be in different cells. Always query **current cell + neighbors**.
- **kNN** (k-nearest neighbors): not a pure cell lookup; usually cell scan + exact distance filter.

### 🔹 4. Internal Working (Uber-like dispatch)
1. Each driver sends GPS update (every 3–5s) → in-memory index (Redis GEO / H3 bucket).
2. Rider request → compute rider's H3 cell.
3. Query current cell + 6 neighbors → candidate driver set.
4. Filter by vehicle type, availability; rank by ETA (routing service).
5. Offer to top driver; on reject, offer next.

**Failure points:** stale driver location; hot cell (downtown at rush hour); cell boundary misses nearest driver.

### 🔹 5. Key Tradeoffs
- Geohash: easy to store as string, DB-friendly; rectangular distortion at poles.
- H3: even hex cells, neighbor logic cleaner; needs H3 library.
- S2: strong spherical correctness; more complex.
- Redis GEO: fast, in-memory, great for real-time dispatch.
- PostGIS: heavy spatial queries, not real-time.

### 🔹 6. Interview Questions
**Beginner**
1. Why not just SQL for "nearby" query?
2. What does geohash do?

**Intermediate**
1. Why query neighboring cells too?
2. Geohash vs H3 tradeoffs.

**Advanced**
1. Design driver dispatch for 1M active drivers at 300k updates/s.
2. Handle surge pricing zones using spatial aggregation.

### 🔹 7. Real System Mapping
- **Uber**: H3 hex grid; Marketplace dispatch.
- **Lyft**: H3 + ML matching.
- **Google Maps**: S2 cells.
- **DoorDash**: location-based routing for delivery orchestration.
- **Yelp, Zomato**: proximity search + filters.

### 🔹 8. What Most People Miss
- **Cell size choice**: too big = too many candidates; too small = miss nearby. Tune per-workload; H3 has resolution 0–15.
- **Driver state lifecycle**: online/offline/busy — location alone isn't enough; combine with state in Redis.
- **Supply/demand per cell** is how surge is computed — aggregate cell counts continuously.
- **ETA ≠ distance**: real roads, traffic; separate routing service.
- **Privacy**: location data is sensitive; bucket before storing long-term.

### 🔹 9. 30-Second Revision
Geohash / H3 / S2 partition the map into cells. Query cell + neighbors. Store hot locations in Redis; use routing service for real ETA. H3 = hex, Uber's standard. S2 = Google's spherical. Always think "supply & demand per cell" for matching systems.

---

## 🔗 Cross-Topic Connections
- **Databases**: spatial indexes (PostGIS B-tree on geohash, Cassandra clustering on cell).
- **Caching**: Redis GEO sets for hot location lookups.
- **Load Balancing**: dispatch logic often sits behind regional LBs.
- **Messaging**: location updates flow through Kafka for analytics.

---

### Confidence Check
- [ ] Can I sketch a real-time dispatch system?
- [ ] Can I choose geohash vs H3 per scenario?

### Gaps
- S2 cell ID math.
- Routing algorithms (A*, Dijkstra on road graph).
