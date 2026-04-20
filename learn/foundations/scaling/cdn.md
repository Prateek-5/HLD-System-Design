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
- Edge compute (Cloudflare Workers, Lambda@Edge) — the frontier, not covered.
- Bitrate-adaptive video (HLS/DASH) caching quirks — missing.
- Signed URLs for access control — missing.
