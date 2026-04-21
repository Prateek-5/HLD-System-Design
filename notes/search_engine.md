# Search Engine (Elasticsearch / Text Search)

> **📎 Prereqs** — If rusty:
> - [`databases.md`](databases.md) — why B-trees aren't built for text.
> - Inverted index concept (term → list of doc IDs).
> - CDC basics (for keeping indexes fresh).

### 🔹 1. What This Topic Actually Is
Full-text search over large corpora with ranking. Lucene-based: **Elasticsearch**, **OpenSearch**, **Solr**. Plus aggregations for analytics.

### 🔹 2. Why It Exists
- B-tree SQL is wrong for text search (no relevance, no tokenization).
- Inverted indexes give millisecond matches over billions of docs.

### 🔹 3. Core Concepts (High Signal)
- **Inverted index**: token → posting list of doc IDs containing it.
- **Analyzer**: tokenizer + filters (lowercase, stemming, stopwords). Per-field.
- **Relevance**: BM25 default; tunable.
- **Sharding + replication**: index split into shards; each has replicas.
- **Time-based indexing (logs, events)**: create indexes per day / per hour; old indexes read-only, closable for space.
- **Aggregations**: real-time group-by/metric queries over the index.
- **Refresh interval**: how quickly new docs are visible (default 1s — not strongly consistent).

### 🔹 4. Internal Working
Write: doc → analyzer → terms → index segment (immutable, Lucene). Refresh merges segments into searchable form every refresh_interval.
Read: parse query → intersect posting lists → score → return top K.
Shards processed in parallel, results merged.

**Failure points:** mapping explosion (dynamic fields create giant mappings), hot shard, slow queries on wide aggregations, refresh-lag vs throughput.

### 🔹 5. Key Tradeoffs
- Great for: search + analytics + log storage.
- Not good for: transactional writes, strong consistency, joins.
- Elastic vs OpenSearch: same roots, licensing split in 2021. Solr less popular now but still used.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. Why not SQL for search?
2. What's an inverted index?

**Intermediate 🟡**
1. How does time-based indexing help log retention?
2. Why isn't Elasticsearch strongly consistent?

**Advanced 🔴**
1. Design search for 10B docs at 5k QPS + typo-tolerant.
2. Hybrid keyword + vector (semantic) search design.

### 🔹 7. Real System Mapping
- **GitHub search** (historically Elasticsearch; now custom).
- **Amazon product search**: specialized Lucene-based.
- **Elastic APM / log analytics**: log indexing at scale.
- **Facebook Unicorn**: graph search system (more than text).

### 🔹 8. What Most People Miss
- **Mapping discipline** is crucial — letting Elastic infer all field types leads to explosion.
- **Reindexing is expensive** — plan schemas carefully.
- **Use separate clusters for hot (recent) vs cold (archive)** data.
- **Query performance depends on cache warmth** — cold queries can be 100× slower.
- **Vector search (kNN)** is now native in ES/OpenSearch — relevant for semantic search.

### 🔹 9. 30-Second Revision
Inverted index per term. Analyzers handle tokenization + stemming. BM25 default scoring. Time-based indexes for log/event use. Refresh interval controls near-real-time visibility. Not strongly consistent. Watch mapping explosion.

---

## 🔗 Cross-Topic Connections
- **Databases**: often kept in sync via CDC (Debezium → ES).
- **Caching**: query result caches or filter caches built-in.
- **Stream processing**: feed search indexes.
- **Observability**: log storage often in ES/OpenSearch.

---

### Confidence Check
- [ ] Can I design search for a given corpus + QPS?
- [ ] Can I articulate ES's consistency model?

### Gaps
- Vector search (HNSW) internals.
- Lucene segment merge tuning.
