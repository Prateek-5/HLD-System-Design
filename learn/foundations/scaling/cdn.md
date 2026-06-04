# CDN — Cache at the Edge of the Planet

> **Prereq**: [Caching](caching.md), [DNS](../networking/dns.md), [IP](../networking/ip.md)

## A. Intuition First
A CDN is **caching + geography**. Put copies of static content (images, video segments, JS, CSS, HTML) in thousands of locations near users so a user in Mumbai gets a file from a Mumbai edge, not from a Virginia datacenter.

**Why it had to exist:** speed of light. Virginia → Mumbai round-trip ≈ 200 ms just for the network. No amount of server optimization beats physics; you have to move the bytes closer.

## B. Mental Model
- **Origin**: your "real" server; the source of truth.
- **Edge PoP (Point of Presence)**: one of hundreds of CDN locations globally.
- **DNS or Anycast routing**: directs a user to the nearest PoP.
- **Pull** vs **Push**: edge fetches on demand, or you upload to the CDN explicitly.

## C. Internal Working
1. User requests `cdn.yourapp.com/cat.jpg`.
2. DNS (or anycast) routes to the closest PoP (e.g., Mumbai).
3. Mumbai PoP checks local cache. Hit → return immediately.
4. Miss → Mumbai PoP fetches from a regional parent, then origin if needed, then caches.
5. Subsequent Mumbai requests → hit.

Cache keys typically include: URL + query string (or a subset) + relevant headers (`Vary` header tells the CDN which headers matter, e.g., `Accept-Encoding` for gzip vs br).

## D. Visual Representation
```
User (Mumbai) ──→ [Mumbai edge] ─miss─→ [Regional] ─miss─→ [Origin]
                      ↑                                       │
                      └─────────── cache populated ───────────┘
```

### 🧱 What a CDN edge knows (and doesn't)

| ✅ Knows | ❌ Doesn't know |
|---|---|
| Cached responses for its region | Your DB schema, app logic |
| Cache-Control + Vary headers | User sessions (unless edge compute runs) |
| How to reach origin shield on miss | Global invalidation truth — purge is eventual |
| Signed URL validity (if configured) | Anything about other PoPs except via the same origin |

> **🔎 Quick Check** — Why does purging a CDN URL take seconds to minutes?
> **🎯 Recall** — The purge has to propagate to every edge PoP globally. Each PoP is independent; no single broadcast channel.

## E. Tradeoffs
- **Extra cost** — CDN bandwidth billing (cheaper than egress from origin, but non-zero).
- **Purge lag** — invalidating cached content is slow (seconds to minutes to propagate globally); plan around it with cache-busting URLs (`cat.v42.jpg`).
- **Dynamic content** — CDNs are best at static. Personalized responses (your feed, your cart) are harder to cache without edge compute.
- **Geographic gaps** — if your audience is somewhere the CDN has no PoPs, performance can be worse than a well-placed origin.

## F. Interview Lens
- "How does a CDN know to route me to the nearest edge?" → Anycast, geo-DNS, or routing at the resolver level.
- "Push vs pull?" → Pull scales better and is the default; push is for tight control of what's at the edge.
- "How do you invalidate a CDN entry?" → purge APIs + cache-busting URLs. Prefer the latter (immutable URLs).
- "What's the `Vary` header and why does it matter?"
- "What's the difference between a CDN and a reverse proxy cache?" → CDN = geographically distributed; reverse proxy = a single site. Fundamentally same idea, different scale.

## G. Real-World Mapping
- **Cloudflare, Akamai, Fastly, CloudFront, Google CDN** — the big four.
- **Netflix Open Connect** — Netflix's own CDN with appliances inside ISPs (because 15%+ of internet traffic at peak is Netflix; it had to build its own).
- **Twitch, YouTube**: video CDN with specialized HLS/DASH segment caching.

## H. Questions

**Beginner**: What's a CDN? Why faster?
**Intermediate**: Push vs pull? How do CDNs handle invalidation?
**Advanced**:
1. Design a CDN for 10 PB of video, 100M DAU.
2. How would you handle cache invalidation within 10 seconds globally?
3. Why does Netflix run its own CDN rather than using Cloudflare?

## I. Mini Design — "CDN for an image hosting service"
- URLs are immutable (`/img/abc123.jpg`) → no invalidation needed.
- On upload, push to origin (S3). Pull CDN fetches on first demand.
- TTL = 1 year (max).
- If image is deleted: rewrite rules on origin return 404; CDN re-fetches, caches 404 for short TTL.

## J. Cross-Topic Connections
- [Caching](caching.md) — CDN is a cache.
- [DNS](../networking/dns.md) — CDN routing.
- [IP](../networking/ip.md) — anycast routing makes CDNs possible.

## K. Confidence Checklist
- [ ] I know push vs pull.
- [ ] I can explain anycast-based routing to a PoP.
- [ ] I know how to handle stale content.
- [ ] I can design a CDN-backed image service.

### Red flags
- ❌ Thinking a CDN handles dynamic, personalized content out of the box.
- ❌ "I'll just purge it" — purges are slow; use immutable URLs.

## L. Potential Gaps & Improvements
- **Edge compute (Cloudflare Workers, AWS Lambda@Edge)** — run small bits of code on the CDN's edge servers near users instead of a distant origin; matters because it cuts latency and offloads logic like auth or A/B routing.
- **ABR (Adaptive Bitrate) streaming via HLS (HTTP Live Streaming) / DASH (Dynamic Adaptive Streaming over HTTP)** — video is sliced into many small quality variants the player switches between; learners care because caching thousands of tiny segments behaves very differently from caching one big file.
- **Signed URLs** — time-limited links carrying a cryptographic signature so only authorized users can fetch a cached object; key for serving paid or private content from a public CDN.

**🔧 How to close:** Sign up for a free Cloudflare account, deploy a hello-world Worker with `npm create cloudflare@latest`, then run `curl -sI https://<your-worker>.workers.dev` and inspect the `cf-ray` and `cf-cache-status` headers to see edge handling in action.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔐 Gap 1 — Signed URLs & Signed Cookies
- 🔹 **What it is**: Time-limited links carrying a cryptographic signature, so a public CDN only serves a cached object to someone holding a valid, unexpired token.
- 🔹 **Why it matters**: It's how you serve paid videos, private downloads, or per-user assets from an edge that has no idea who the user is — the single most common "how do I protect CDN content?" interview question.
- 🔹 **Connection**: The §D table says an edge "Doesn't know user sessions." Signed URLs are how you enforce access *without* the edge knowing your auth system — the signature itself is the proof.
- 🔹 **When needed**: 🟢 **Foundational** — almost any media/file product needs this; reachable as soon as caching clicks.
- 🔹 **Intuition**: A movie ticket with a showtime printed on it. The usher (edge) doesn't know you personally; they just check the ticket is genuine and not expired.
- 🔹 **If you go deeper**: Read CloudFront's "signed URLs vs signed cookies" docs and Cloudflare's `Signed URLs` / token authentication. Build one: HMAC the path + expiry with a shared secret, append as a query param, verify at the edge.
- 🔹 **Interview hook**: *"How do you serve a paid video from a CDN without leaking the URL?"* → Issue a short-lived signed URL (path + expiry signed with a secret); the edge validates the signature and rejects expired or tampered links.

---

#### 🎞️ Gap 2 — Adaptive Bitrate Streaming (HLS / DASH) at the Edge
- 🔹 **What it is**: Video sliced into thousands of small segments at multiple quality levels; the player switches bitrate on the fly, and the CDN caches each segment independently.
- 🔹 **Why it matters**: Caching ten-thousand tiny `.ts`/`.m4s` segments behaves nothing like caching one big file — it dominates the cost and cache-hit math for any video system.
- 🔹 **Connection**: §G mentions Netflix/Twitch/YouTube "specialized HLS/DASH segment caching." This gap unpacks *why* video is a different caching problem than the `cat.jpg` example.
- 🔹 **When needed**: 🟡 **Mid-level** — essential for any video/streaming design round; skippable for generic API work.
- 🔹 **Intuition**: A book sold as hundreds of single pages instead of one bound volume — readers grab pages as needed, and the library stocks the popular pages everywhere.
- 🔹 **If you go deeper**: Read the HLS RFC 8216 and the MPEG-DASH spec. Use `ffmpeg` to segment a video into an HLS playlist (`.m3u8` + segments) and serve it through a CDN, watching `cf-cache-status` per segment.
- 🔹 **Interview hook**: *"Why is caching video harder than caching images?"* → Each quality variant is split into many short segments, so cache keys explode and the long tail of rarely-watched segments hurts hit ratios.

---

#### ⚙️ Gap 3 — Edge Compute (Workers, Lambda@Edge)
- 🔹 **What it is**: Running small bits of your own code on the CDN's edge servers near users, instead of round-tripping to a distant origin.
- 🔹 **Why it matters**: It moves logic like auth checks, A/B routing, header rewriting, and personalization to within milliseconds of the user — the modern answer to "but CDNs can't do dynamic content."
- 🔹 **Connection**: §E lists "Dynamic content" as a CDN weakness ("harder to cache without edge compute"). This gap is the named escape hatch the tradeoff hints at.
- 🔹 **When needed**: 🟡 **Mid-level** generally; 🔴 **Senior** when designing globally-distributed request handling or edge state.
- 🔹 **Intuition**: A hotel front desk that can answer most questions itself instead of phoning head office for every guest.
- 🔹 **If you go deeper**: Deploy a Cloudflare Worker (V8 isolates) and AWS Lambda@Edge (per-PoP functions); compare their cold-start and execution-location models. Read about the isolate-vs-container startup difference.
- 🔹 **Interview hook**: *"How would you personalize a cached page without hitting the origin?"* → Cache a generic shell, then patch per-user bits at the edge with a Worker so most of the response stays cacheable.

---

#### 🛡️ Gap 4 — Cache Hierarchy & Origin Shield (Thundering Herd)
- 🔹 **What it is**: An extra mid-tier cache layer between edge PoPs and your origin, so that on a popular miss only *one* request reaches the origin instead of one per PoP.
- 🔹 **Why it matters**: Without it, a viral cache miss or a purge can stampede thousands of PoPs onto your origin at once and knock it over — a classic availability failure.
- 🔹 **Connection**: §C step 4 already shows the "Regional parent" hop on a miss. This gap names that pattern (origin shield) and explains the failure it prevents.
- 🔹 **When needed**: 🔴 **Senior** — shows up in high-scale and reliability rounds, not day-one usage.
- 🔹 **Intuition**: A regional warehouse between corner stores and the factory — stores restock from the warehouse, so the factory sees one bulk order, not a thousand frantic calls.
- 🔹 **If you go deeper**: Read Fastly/CloudFront "origin shield" docs and the general thundering-herd / request-coalescing pattern (single-flight). Note how shielding pairs with stale-while-revalidate.
- 🔹 **Interview hook**: *"A video goes viral and every PoP misses at once — how do you protect the origin?"* → Add an origin shield tier plus request coalescing so concurrent misses collapse into one origin fetch.

---

### 🏆 Start here if you have limited time
1. **Signed URLs** — foundational and almost universally needed; it's the default answer to "protect CDN content."
2. **Adaptive bitrate streaming** — unlocks every video-system question and reshapes how you reason about cache keys.

---

### 🧭 Suggested Deep Dive Order
1. **Signed URLs & signed cookies** (~45 min; broadly applicable access control).
2. **Edge compute** (~1h; the answer to the "CDNs can't do dynamic" tradeoff).
3. **Adaptive bitrate streaming** (~1.5h; essential for media designs, hands-on with `ffmpeg`).
4. **Cache hierarchy / origin shield** (~1h; senior reliability signaling).
