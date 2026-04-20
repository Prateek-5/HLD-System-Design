# Case Study — Design Netflix

## A. Intuition First
Netflix is a **video streaming** platform. The interesting parts: content ingestion + encoding, globally-distributed delivery (CDN), adaptive bitrate streaming, and recommendation.

## B. Requirements
**Functional**
- Browse catalog + search.
- Stream video to any device, any connection speed.
- Resume playback across devices.
- Recommendations.

**Non-functional**
- Global scale (250M+ subscribers).
- Video start latency < 2s.
- High availability, regional fault tolerance.

## C. Estimation
- ~200 PB of content.
- Peak traffic: 15%+ of all internet traffic at evening peaks.
- Billions of streams/day.

## D. High-Level Architecture
```
[User] → [CDN (Open Connect)] → Video segments served at edge
       → [API Gateway] → [Catalog svc] [User svc] [Playback svc] [Recs svc]
                           │
                           └─ S3-like blob for originals
                           └─ Elasticsearch for search
                           └─ Cassandra for user state / viewing history
                           └─ Kafka for events
```

## E. Deep Dives

### Content ingestion + encoding
- Originals uploaded to blob storage.
- Transcoded into 1200+ variants (codec × bitrate × resolution).
- Broken into segments (2–10 s each) for adaptive streaming (HLS/DASH).
- Segments pushed to Open Connect (Netflix's own CDN).

### Adaptive bitrate streaming
- Player downloads a manifest listing segments at different qualities.
- Based on network throughput, player picks the best quality per segment.
- Bad network → drop to lower bitrate instead of buffering.

### CDN — Open Connect
- Netflix built its own CDN.
- ISPs host Open Connect Appliances (OCAs) inside their networks; content pre-positioned at night.
- Peak-hour evening traffic served locally → massive ISP cost savings + lower latency.
- DNS + BGP route users to nearest OCA.

### Playback service
- Holds session state: what you're watching, progress, device info.
- Stores progress events in Cassandra (user_id, video_id, timestamp).
- On resume, fetches last position.

### Recommendations
- Batch: offline Spark jobs training models on viewing history → served via a feature store.
- Online: serve pre-computed candidate sets, then re-rank with a lightweight online model.

### Metadata
- Catalog in a read-optimized store + heavy caching.
- Search in Elasticsearch.

## F. Tradeoffs
- Cassandra for user viewing state: write-heavy, AP, fits perfectly.
- Own CDN: capex enormous, but essential at their scale; would not make sense for a small service.
- Microservices: ~1000+ services at Netflix; operational maturity required (chaos engineering, distributed tracing).

## G. Interview Lens
- "How does Netflix start a video in < 2s?" — nearest OCA + adaptive bitrate.
- "How is recommendation served?" — offline training + online serving.
- "What happens when one region dies?" — active-active multi-region (Netflix does this famously).
- "Why Cassandra for viewing history?" — write-heavy, partitioned by user, tunable consistency.

## H. Questions
**Beginner**: Why a CDN?
**Intermediate**: Adaptive bitrate?
**Advanced**:
1. Active-active multi-region.
2. Chaos engineering (Simian Army).
3. Pre-positioning content at edges.

## I. Cross-Topic Connections
- [CDN](../foundations/scaling/cdn.md), [Caching](../foundations/scaling/caching.md), [NoSQL](../data/nosql-databases.md), [Microservices](../architecture/monolith-vs-microservices.md), [Circuit Breaker](../reliability/circuit-breaker.md).

## J. Confidence Checklist
- [ ] Can describe video flow end-to-end.
- [ ] Knows Open Connect's value.
- [ ] Knows adaptive bitrate.

## K. Potential Gaps & Improvements
- DRM and content protection.
- Offline playback (pre-downloaded).
- A/B testing framework.
