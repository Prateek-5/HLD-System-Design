# CDN

### 🔹 1. What This Topic Actually Is
Geographically distributed cache of origin content (images, video segments, JS, HTML) served from **edge PoPs** closest to users.

### 🔹 2. Why It Exists
- Speed of light. A cross-ocean RTT is 200+ ms. CDN brings bytes within 10 ms of the user.
- Offloads origin: fewer requests traverse to origin → cheaper + more resilient.
- DDoS absorbing (huge aggregate capacity).

### 🔹 3. Core Concepts (High Signal)
- **Push vs Pull**:
  - Pull: edge fetches on demand. Default.
  - Push: you upload to CDN explicitly. Tight control.
- **Cache keys**: URL + selected headers (`Vary`).
- **TTL**: per response; best practice = **immutable URLs** (`file.v42.jpg`) + long TTL to sidestep purge lag.
- **Purge**: slow (seconds to minutes globally). Design around immutable URLs when possible.
- **Origin shield**: regional mid-tier that absorbs edge misses before hitting origin.
- **Anycast routing**: one IP announced from many PoPs; BGP routes user to nearest.
- **Signed URLs**: time-limited URLs for private content.

### 🔹 4. Internal Working
1. Client resolves `cdn.yourapp.com` → nearest PoP via anycast/geo-DNS.
2. Edge cache hit → immediate response.
3. Miss → edge fetches from origin shield → origin; populates cache.
4. Subsequent hits served from edge.

**Failure points:** origin outage cascades when cache cold; purge lag breaks user-visible consistency; signed-URL expiry mistakes; misconfigured `Vary` explodes cache key space.

### 🔹 5. Key Tradeoffs
- Great for static + semi-static content; hard for personalized (per-user) responses — use edge compute (Cloudflare Workers / Lambda@Edge).
- Cost: egress bandwidth still non-zero; saves origin egress + latency.
- Purge lag vs TTL — pick strategy once and stick.

### 🔹 6. Interview Questions
**Beginner**
1. Why do CDNs help latency?
2. Push vs pull?

**Intermediate**
1. How do you invalidate CDN content quickly?
2. What does `Vary` do and why does it matter?

**Advanced**
1. Design a CDN for 200 PB of video.
2. Why does Netflix run its own CDN (Open Connect) instead of renting?
3. Handle flash crowd (viral video) without melting origin. (origin shield + stale-while-revalidate + precompute segments)

### 🔹 7. Real System Mapping
- **Cloudflare, Akamai, Fastly, CloudFront** — the big commercial CDNs.
- **Netflix Open Connect** — own CDN with appliances inside ISPs.
- **YouTube peering/PoP infrastructure**.
- **Twitch** for low-latency live video.

### 🔹 8. What Most People Miss
- **Purges are slow** — always design with cache-busting URLs (file hash in name) when you need instant swap.
- **Dynamic content at edge** — modern CDNs run compute (Workers, Lambda@Edge) that can fetch + personalize at the edge, collapsing many origin hits.
- **Video is segmented**: HLS/DASH chunks are independently cacheable — this is why video CDNs work.
- **Hot shard at edge**: for viral content, one PoP hammered; neighbors can help via **consistent hashing of origin requests** within the PoP.
- **Cache key hygiene**: don't vary on per-user cookies — you get unique keys = 0% hit rate.

### 🔹 9. 30-Second Revision
CDN = geo-distributed cache. Pull + anycast default. Immutable URLs > purges. Origin shield absorbs miss spikes. HLS/DASH segmentation is why video CDNs work. Edge compute lets you personalize cheaply. Netflix built own CDN because they are 15%+ of internet.

---

## 🔗 Cross-Topic Connections
- **Caching**: CDN is just a geo-distributed cache.
- **DNS/anycast**: how users reach nearest PoP.
- **Load Balancing**: CDNs do per-PoP LB too.
- **Video processing**: segmentation + transcoding pipeline feeds CDN.

---

### Confidence Check
- [ ] Can I design a CDN-backed image/video service?
- [ ] Can I reason about hit ratio & purge tradeoffs?

### Gaps
- DRM for CDN-protected video.
- Exact anycast routing math.
