# Geohashing and Quadtrees — Indexing Geographic Data

## A. Intuition First
"Find all cafes within 1 km of me" is not something a B-tree answers well. You need a **spatial index** that groups nearby points together.

## B. Mental Model
- **Geohash**: encode (lat, lon) as a short string; nearby points share prefixes → prefix search = spatial search.
- **Quadtree**: recursively divide the map into 4 quadrants until each contains ≤ K points.

## C. Internal Working

### Geohash
- Split lat/lon bit-by-bit into binary intervals → interleave bits → base32 encode.
- Example: `9q8yy` = San Francisco area. Shorter prefix → bigger area.
- Nearby points share prefix → group cache / partitioning by prefix.

### Quadtree
- Each node has up to 4 children (NE, NW, SE, SW).
- Subdivide when a cell exceeds capacity.
- Point query walks from root to leaf in O(log N).

## D. Visual Representation
```
Geohash: "9q8y" (bigger cell)  →  "9q8yy" (smaller) → "9q8yyv"
Quadtree:
        ┌────┬────┐
        │ NW │ NE │        (subdivide NE → 4 children)
        ├────┼────┤
        │ SW │ SE │
        └────┴────┘
```

## E. Tradeoffs
- Geohash: easy to store in any DB (string prefix), but edge-of-cell proximity issues (two nearby points can have different prefixes).
- Quadtree: dynamic, balanced, supports k-nearest; in-memory structure preferred.
- R-tree (another option): balanced tree of bounding boxes.

## F. Interview Lens
- "Design Uber driver lookup" → geohash for coarse, then kNN within.
- "Find nearby friends" → same.
- Pitfalls: using geohash alone and missing cell-boundary neighbors (query adjacent cells too).

## G. Real-World Mapping
Uber, Lyft, Yelp, Google Maps use spatial indexing (Uber uses H3, a hex-based variant).

## H. Questions
**Beginner**: What's a spatial index for?
**Intermediate**: Geohash precision levels?
**Advanced**: Design "nearby drivers" at 1M rides/min.

## I. Mini Design
Store each driver location keyed by geohash-6 in Redis set. On rider request, compute rider's geohash-6 and its 8 neighbors; union members of those 9 sets; filter by exact distance.

## J. Cross-Topic Connections
- [Caching](../foundations/scaling/caching.md), [Sharding](../data/sharding.md) (can shard by geohash prefix).

## K. Confidence Checklist
- [ ] Can sketch geohash encoding.
- [ ] Knows edge-of-cell pitfall.

## L. Potential Gaps & Improvements
- **H3 (Hexagonal Hierarchical Geospatial Indexing)** — Uber's open-source library that tiles the world into hexagons instead of squares, so every neighbor cell is exactly the same distance away; avoids the uneven-neighbor and cell-boundary problems geohash has.
- **S2 Cells (Spherical Geometry library)** — Google's index that maps the round Earth onto a cube then a space-filling (Hilbert) curve, giving low distortion near the poles; useful when you need accurate areas/distances globally.
- **R-tree (Rectangle tree)** — a balanced tree of nested bounding boxes that indexes arbitrary shapes (not just points), so range and "what overlaps this box" queries stay fast; the spatial index built into PostGIS and many databases.
- **kNN (k-Nearest-Neighbors) query** — "give me the closest K drivers" search run after the coarse geohash/cell filter; the core operation behind every "find nearby" feature (→ see Interview Lens).
- **Space-filling curve (Hilbert / Z-order curve)** — a 1-D ordering that keeps points close on the map also close in the index, which is exactly how geohash and S2 turn 2-D location into a sortable key.

**🔧 How to close:** Install the geohash CLI and verify the prefix property yourself: `pip install python-geohash` then run a tiny script — `python -c "import geohash; print(geohash.encode(37.7749,-122.4194,6)); print(geohash.encode(37.7750,-122.4195,6))"` and confirm the two nearby San Francisco points share a leading prefix; then re-encode a point right on a cell edge and watch the prefix change to feel the boundary pitfall.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔺 Gap 1 — Hexagonal Indexing (H3) vs Geohash Squares
- 🔹 **What it is**: H3 (Hexagonal Hierarchical Geospatial Indexing) tiles the world into hexagons instead of squares, so every neighbor cell sits at the same center-to-center distance.
- 🔹 **Why it matters**: Square cells have two kinds of neighbors (edge-touching vs corner-touching) at different distances, which biases "nearby" results; hexagons remove that bias and make ring/k-step queries clean.
- 🔹 **Connection**: This file's Mini Design unions a cell plus its 8 neighbors to dodge the boundary pitfall — H3 reframes that exact trick as a uniform "k-ring" around one hex.
- 🔹 **When needed**: 🟢 **Foundational** if you touch ride-hailing/maps; 🟡 **Mid-level** elsewhere.
- 🔹 **Intuition**: A bathroom floor tiled in hexagons (like a beehive) — step to any adjacent tile and you've walked the same distance every time; square tiles make diagonal steps longer.
- 🔹 **If you go deeper**: Read Uber Engineering's H3 post and the `uber/h3` library; try `h3.latlng_to_cell(...)` and `h3.grid_disk(cell, 1)`.
- 🔹 **Interview hook**: *"Why did Uber move off plain geohash to hexagons?"* → uniform neighbor distance and clean k-ring expansion for surge/supply analysis.

---

#### 🌐 Gap 2 — S2 Cells and Space-Filling Curves
- 🔹 **What it is**: S2 is Google's index that projects the round Earth onto a cube, then threads each face with a Hilbert space-filling curve to turn a 2-D location into a single sortable 64-bit key.
- 🔹 **Why it matters**: A Hilbert/Z-order curve keeps points that are close on the map close in the sorted key — that locality is *why* a 1-D database index (or geohash prefix) can answer 2-D proximity at all, and S2 does it with low distortion near the poles.
- 🔹 **Connection**: Geohash in this file already does this (interleave bits → sortable string); S2 is the same idea done more rigorously on a sphere instead of a flat lat/lon grid.
- 🔹 **When needed**: 🟡 **Mid-level**; 🔴 **Senior** if you design a global geo store.
- 🔹 **Intuition**: Folding a long ribbon back and forth to cover a whole table — points near each other on the table end up near each other along the ribbon, so a single tape measure (1-D index) finds neighbors.
- 🔹 **If you go deeper**: Read the S2 Geometry docs and the Hilbert-curve section; compare cell-area distortion of geohash vs S2 at high latitudes.
- 🔹 **Interview hook**: *"How do you turn a lat/lon into one indexable number without losing proximity?"* → interleave/space-filling curve so map-locality survives as key-locality.

---

#### 🗺️ Gap 3 — R-trees for Shapes and Range Queries
- 🔹 **What it is**: An R-tree (Rectangle tree) is a balanced tree of nested bounding boxes that indexes arbitrary shapes — not just points — so "what overlaps this box?" stays fast.
- 🔹 **Why it matters**: Geohash and quadtrees shine for point lookups, but real queries include polygons (delivery zones, geofences, "is this rider inside the airport boundary?") — R-trees handle those directly and back the spatial index in PostGIS.
- 🔹 **Connection**: This file's Tradeoffs section already lists R-tree as "a balanced tree of bounding boxes" — this gap explains when you'd reach for it over the quadtree/geohash it sits beside.
- 🔹 **When needed**: 🟡 **Mid-level**; common once you store regions, not just pins.
- 🔹 **Intuition**: Russian nesting dolls of cardboard boxes — to find what's in a region you only open the boxes whose outer box overlaps your area, skipping the rest.
- 🔹 **If you go deeper**: Build a PostGIS table, add a `GIST` index, and run `ST_Intersects` / `ST_DWithin`; read Guttman's 1984 R-tree paper.
- 🔹 **Interview hook**: *"How do you find every delivery zone a point falls inside?"* → R-tree bounding-box overlap, then exact polygon test.

---

#### 📍 Gap 4 — kNN After the Coarse Filter
- 🔹 **What it is**: k-Nearest-Neighbors (kNN) is the "give me the closest K drivers" step you run *after* a cell/prefix filter has narrowed the candidate set.
- 🔹 **Why it matters**: The spatial index only buckets candidates cheaply; the actual ranking by true distance (great-circle, not cell count) is a separate stage, and getting the two-phase split right is the heart of every "find nearby" answer.
- 🔹 **Connection**: This file's Interview Lens says "geohash for coarse, then kNN within" and the Mini Design ends with "filter by exact distance" — this gap names and sharpens that second phase (→ see Interview Lens).
- 🔹 **When needed**: 🟢 **Foundational** for any location feature.
- 🔹 **Intuition**: Finding a friend in a stadium — first you go to the right section (coarse cell), then you scan the seats nearby for the exact person (kNN), instead of searching the whole stadium.
- 🔹 **If you go deeper**: Try Redis `GEOSEARCH ... COUNT k ASC`, or compute Haversine distance over a geohash-filtered candidate set; widen the search ring if a cell yields fewer than K.
- 🔹 **Interview hook**: *"Your cell has only 3 drivers but you need 10 — now what?"* → expand to neighbor cells / coarser precision, then re-rank by exact distance.

---

### 🏆 Start here if you have limited time
1. **kNN after the coarse filter** — it's the actual answer to "find nearby X," and shows up in nearly every location-service interview.
2. **Hexagonal indexing (H3)** — the most-cited real upgrade over plain geohash, and easy to demo.

---

### 🧭 Suggested Deep Dive Order
1. **kNN after the coarse filter** (~30 min; cements the two-phase pattern you'll reuse everywhere).
2. **Hexagonal indexing (H3)** (~45 min; concrete, hands-on, interview-ready).
3. **R-trees for shapes** (~1h; unlocks polygon/geofence queries via PostGIS).
4. **S2 cells & space-filling curves** (~1h; deepest — the math behind why proximity survives as a 1-D key).
