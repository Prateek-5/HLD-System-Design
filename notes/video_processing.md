# Video Processing (Transcoding, Streaming, Live)

> **📎 Prereqs** — If rusty:
> - [`cdn.md`](cdn.md) — delivery pipeline.
> - [`distributed_file_system.md`](distributed_file_system.md) — segment storage.
> - Bitrate / codec basic vocabulary.

### 🔹 1. What This Topic Actually Is
Ingesting, encoding, storing, and delivering video at scale. The pipeline behind Netflix, YouTube, Twitch, ESPN.

### 🔹 2. Why It Exists
- Raw video is huge (1 GB+ per hour). Must encode for bitrate ladders and device compatibility.
- Delivery is bandwidth-dominant; CDN + segmentation essential.
- Live vs on-demand have very different latency budgets.

### 🔹 3. Core Concepts (High Signal)
- **Codecs**: H.264 (ubiquitous), H.265/HEVC (better compression, royalties), AV1 (open, newest).
- **Bitrate ladder**: same video at multiple qualities (240p/480p/720p/1080p/4K).
- **Chunking / segmentation**: split into 2–10s segments (HLS/DASH) → independently cacheable → adaptive.
- **Adaptive bitrate (ABR)**: player probes bandwidth, picks best quality per segment.
- **HLS (Apple)** vs **DASH (MPEG)**: competing formats; most systems support both.
- **Shot-based encoding (Netflix)**: encode each shot with its own optimal params → 20%+ savings.
- **Live latency tiers**:
  - Standard HLS: 15–30 s.
  - Low-Latency HLS / CMAF: 2–5 s.
  - WebRTC: <1 s (conferencing, auctions).

### 🔹 4. Internal Working (pipeline)
1. **Ingest**: upload or live stream via RTMP/SRT.
2. **Transcode**: fan-out job per bitrate; parallelized per segment on worker fleet (Netflix does shot-based).
3. **Package**: produce HLS + DASH manifests + segment files.
4. **Store**: object storage (S3).
5. **Distribute**: push/replicate to CDN / edge nodes.
6. **Play**: client reads manifest → pulls segments adaptively.

**Failure points:** transcoding cost (CPU/GPU-heavy), origin read spikes for long-tail content, live ingest failover, stream corruption mid-segment, DRM key leaks.

### 🔹 5. Key Tradeoffs
- On-demand: latency tolerant, optimize for cost (shot-based, better codecs).
- Live: latency critical, may sacrifice compression.
- CDN own vs rent: Netflix scale → own; smaller scale → Cloudflare/Akamai.
- UDP (WebRTC) for sub-second live; TCP (HTTPS) for everything else.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. Why transcode into multiple bitrates?
2. What's adaptive bitrate?

**Intermediate 🟡**
1. HLS vs DASH?
2. How does segmentation improve caching?

**Advanced 🔴**
1. Design live streaming for 10M concurrent viewers at <5 s latency.
2. Why does Netflix use shot-based encoding? Cost/benefit.
3. Why does Netflix run Open Connect rather than using Cloudflare?

### 🔹 7. Real System Mapping
- **Netflix**: Open Connect CDN, shot-based encoding, EVE encoder.
- **YouTube**: custom transcoding fleet (VP9/AV1).
- **Twitch**: low-latency HLS, game streaming.
- **ESPN live**: managed CDN + low-latency HLS.
- **Facebook Live**: broadcast infra paper.
- **Egnyte**: transcoding-at-scale blog.

### 🔹 8. What Most People Miss
- **Most cost is egress bandwidth**, not encoding — that's why Open Connect pays off at scale.
- **Pre-positioning content** (push CDN) is standard for big launches.
- **Perceptual quality metrics** (VMAF, PSNR) matter more than bitrate — better codecs give more quality at same bitrate.
- **Live ingest redundancy**: parallel streams, switch on failure (no viewer sees the drop).
- **DRM overhead** (Widevine, FairPlay, PlayReady) — multi-DRM pipeline per title is a real engineering chunk.

### 🔹 9. 30-Second Revision
Transcode into bitrate ladder; segment into 2–10 s chunks for ABR. HLS / DASH / CMAF. Deliver via CDN. On-demand optimizes cost (shot-based); live optimizes latency (low-latency HLS or WebRTC). Netflix runs own CDN because they are 15%+ of internet traffic.

---

## 🔗 Cross-Topic Connections
- **CDN**: delivery infra.
- **Batch processing**: transcoding jobs at scale (per segment).
- **Object storage**: stores segments.
- **Caching**: manifest + segment caching.

---

### Confidence Check
- [ ] Can I sketch transcoding pipeline end-to-end?
- [ ] Can I pick latency tier + tech for a given use case?

### Gaps
- Exact encoder tuning (CRF, two-pass, etc).
- Multi-DRM pipeline details.
- Per-title encoding specifics.
