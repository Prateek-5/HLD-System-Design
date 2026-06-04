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

### 🪜 Concretely — what's in the manifest (HLS `.m3u8`)

```
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
360p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2400000,RESOLUTION=1280x720
720p.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080
1080p.m3u8
```

Each sub-manifest (`720p.m3u8`) lists individual segments:
```
#EXTINF:6.0,
seg_001.ts
#EXTINF:6.0,
seg_002.ts
...
```

**Decision rule** (simplified): every N seconds, estimate throughput; if throughput × buffer > segment bitrate × N → upgrade. Else downgrade.

> **🧠 What if segments weren't independently cacheable?** A viral show would force every CDN PoP to re-fetch a single huge file. Segmentation is what makes video CDN economical.
>
> **🔎 Quick Check** — Your 720p stream briefly drops to 480p mid-episode. What likely just happened?
> **🎯 Recall** — Network throughput dropped; the ABR algorithm picked a lower bitrate for the next segment to avoid buffering.

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
- **DRM (Digital Rights Management)** — encryption plus license servers that stop a downloaded stream from being copied or replayed; studios won't license content without it.
- **Content protection (watermarking / forensic marking)** — invisible per-user marks embedded in the video so a leaked copy can be traced back to the account; matters for piracy questions.
- **Offline playback (pre-downloaded titles)** — files cached and license-bound on the device so they play with no network; raises sync, expiry, and storage-eviction design problems.
- **A/B testing framework** — infrastructure that splits users into buckets and measures which variant (artwork, ABR algorithm, recommendation) wins on real metrics; how Netflix ships product changes safely.
- **ABR (Adaptive Bitrate Streaming)** — the player measures bandwidth and swaps to a higher- or lower-quality chunk on the fly so video keeps playing without buffering (→ see Interview Lens).

**🔧 How to close:** Run `ffprobe -v quiet -print_format json -show_format -show_streams <video.mp4>` on any sample video to inspect its codec, bitrate, and resolution, then use `ffmpeg -i input.mp4 -b:v 800k out_800k.mp4` and again at `2500k` to produce two bitrate renditions — this is exactly the multi-rendition input that an ABR/DRM packager consumes.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 📡 Gap 1 — ABR Algorithm Design (Throughput vs Buffer-Based)
- 🔹 **What it is**: The actual logic a player uses to pick the next segment's quality — pure bandwidth estimation, buffer-occupancy rules, or a hybrid that blends both.
- 🔹 **Why it matters**: This is the difference between "video keeps playing smoothly" and "constant rebuffering"; it is the single most-asked follow-up on any streaming design.
- 🔹 **Connection**: This file gives a simplified decision rule (`throughput × buffer > segment bitrate × N`) in the manifest section — real ABR is far richer, weighing buffer fill level so a brief bandwidth dip doesn't trigger an unnecessary quality drop.
- 🔹 **When needed**: 🟢 **Foundational** — anyone designing a streaming or download system benefits, and it directly extends what this file already taught.
- 🔹 **Intuition**: Driving with a near-empty fuel tank (buffer) — even if the road looks clear (bandwidth high), you slow down and play it safe until the tank refills.
- 🔹 **If you go deeper**: Read the BOLA paper (buffer-occupancy ABR) and Netflix's own work on "MPC-based" adaptive streaming; both are implemented in the open-source dash.js reference player.
- 🔹 **Interview hook**: *"Why not just always pick the quality your current bandwidth supports?"* → bandwidth is noisy and bursty; a buffer-aware policy smooths over short dips and avoids oscillating quality (the "ABR flapping" problem).

---

#### 🔐 Gap 2 — DRM and Per-User Content Protection
- 🔹 **What it is**: Encrypting segments and gating playback behind a license server (Widevine / FairPlay / PlayReady), plus forensic watermarking that embeds an invisible per-account mark to trace leaks.
- 🔹 **Why it matters**: Studios will not license premium content without it; it is the legal precondition for the whole business, and a frequent "how do you stop piracy?" interview prompt.
- 🔹 **Connection**: This file's encoding pipeline produces 1200+ variants — in reality a *packager* also encrypts each variant and the player must fetch a license key before it can decrypt and play a segment.
- 🔹 **When needed**: 🟡 **Mid-level** — most candidates can name DRM exists; explaining the license-key handshake and watermarking signals depth.
- 🔹 **Intuition**: A hotel keycard — the room (segment) is locked, the front desk (license server) issues a card scoped to your stay, and the card silently logs which guest opened the door.
- 🔹 **If you go deeper**: Study the Widevine modular DRM flow and the CENC (Common Encryption) standard, which lets one encrypted file serve multiple DRM systems.
- 🔹 **Interview hook**: *"A 4K rip of a new release leaks online — how do you find the source?"* → forensic watermarking ties a unique invisible pattern to each session/account, letting you trace the leaked copy back.

---

#### 🌍 Gap 3 — Active-Active Multi-Region Failover
- 🔹 **What it is**: Running full stacks in multiple AWS regions simultaneously, with traffic steering that can evacuate an entire failed region in minutes without users noticing.
- 🔹 **Why it matters**: At 250M+ subscribers a regional outage is a revenue and reputation event; "what happens when a region dies?" is explicitly in this file's Interview Lens.
- 🔹 **Connection**: The file mentions active-active multi-region in passing (Interview Lens + Advanced Questions) but never explains how state (viewing history in Cassandra) stays consistent across regions during a failover.
- 🔹 **When needed**: 🔴 **Senior** — this is genuine distributed-infra territory and signals senior-level operational maturity.
- 🔹 **Intuition**: Two identical fully-staffed kitchens in different cities — if one burns down, the host quietly seats everyone in the other and the menu is identical.
- 🔹 **If you go deeper**: Read Netflix's tech blog on "Active-Active for Multi-Regional Resiliency" and their Zuul/Eureka-based traffic shifting; pair it with Cassandra multi-region replication (NetworkTopologyStrategy + tunable consistency).
- 🔹 **Interview hook**: *"How do you fail over a region without losing a user's playback position?"* → Cassandra replicates viewing state cross-region asynchronously; on evacuation, DNS/traffic steering reroutes to the healthy region, which already holds a near-current copy.

---

#### 🧪 Gap 4 — Chaos Engineering and the A/B Testing Platform
- 🔹 **What it is**: Deliberately injecting failures in production (Chaos Monkey / Simian Army) to prove resilience, plus an experimentation platform that buckets users to measure which artwork, ABR tweak, or recommendation actually wins on real metrics.
- 🔹 **Why it matters**: It is *how* Netflix ships safely at ~1000 microservices; both chaos engineering and experimentation appear in this file's Tradeoffs and Gaps as the operational backbone.
- 🔹 **Connection**: The file notes microservices "require operational maturity (chaos engineering, distributed tracing)" and lists an A/B framework as a gap — this gap unpacks both into concrete mechanisms.
- 🔹 **When needed**: 🟡 **Mid-level** for the concept; 🔴 **Senior** when you must design the experiment-assignment and metrics pipeline yourself.
- 🔹 **Intuition**: A fire drill (chaos) plus a taste-test panel (A/B) — you randomly trigger alarms to check the exits work, and you serve two recipe variants to different tables to see which empties the plate.
- 🔹 **If you go deeper**: Read the Principles of Chaos Engineering, Netflix's Chaos Monkey repo, and their "Quasi Experimentation"/XP platform posts on consistent hashing for bucket assignment.
- 🔹 **Interview hook**: *"How do you roll out a new ABR algorithm to 250M users safely?"* → ship it behind an experiment flag to a small consistent-hash bucket, compare rebuffer/quality metrics against control, ramp gradually, and keep Chaos testing the fallback path.

---

#### 📥 Gap 5 — Offline Playback and Edge Pre-Positioning
- 🔹 **What it is**: Letting users pre-download license-bound titles for no-network playback, and the night-time process Netflix uses to push popular content onto ISP-hosted OCAs before peak demand.
- 🔹 **Why it matters**: Both are core to Netflix's cost and UX story; pre-positioning is *why* Open Connect is economical, and offline download raises tricky expiry/eviction design questions.
- 🔹 **Connection**: This file's CDN section says content is "pre-positioned at night" but never explains *how* Netflix predicts what to push where — and offline playback is listed as an open gap.
- 🔹 **When needed**: 🔴 **Senior** — predictive content placement and license-bound offline storage are deep, specialized problems.
- 🔹 **Intuition**: A corner store that restocks overnight based on tomorrow's weather forecast — by morning the popular items are already on the shelf nearest you.
- 🔹 **If you go deeper**: Read Netflix's Open Connect deployment guide and their blog on content-popularity prediction for cache fill; for offline, study how Widevine offline licenses encode expiry.
- 🔹 **Interview hook**: *"How does Netflix decide which titles to cache on which ISP appliance?"* → it predicts regional popularity from viewing data and pushes those titles during off-peak hours, so evening demand is served locally with no origin fetch.

---

### 🏆 Start here if you have limited time
1. **ABR algorithm design** — 🟢 foundational, directly extends the manifest section, and is the most common streaming follow-up.
2. **DRM and content protection** — 🟡 unlocks every "stop piracy / license content" question, which case-study interviews love.

---

### 🧭 Suggested Deep Dive Order
1. **ABR algorithm design** (~45 min; foundational, widely applicable beyond Netflix).
2. **DRM and per-user protection** (~1h; high interview payoff, concrete handshake to explain).
3. **Chaos engineering + A/B platform** (~1h; ties the microservices operational story together).
4. **Active-active multi-region failover** (~1.5h; senior-infra signaling, deep distributed-state reasoning).
5. **Offline playback + edge pre-positioning** (~1h; specialized, rounds out the Open Connect cost story).
