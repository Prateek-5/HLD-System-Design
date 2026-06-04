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
