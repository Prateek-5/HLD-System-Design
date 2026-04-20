# Load Balancing — Horizontal Scaling's Entry Point

> **Prereq**: [IP](../networking/ip.md), [TCP/UDP](../networking/tcp-udp.md), [OSI](../networking/osi.md), [Proxy](../networking/proxy.md)
> **What you will understand by the end**: why load balancers exist, L4 vs L7, routing algorithms and where each breaks, and why the LB itself must not be a single point of failure.

---

## A. Intuition First

### The analogy
You run a busy restaurant. You have one door and 20 tables. If customers walk in randomly and sit wherever, you'll get empty tables next to overflowing ones, waiters will be uneven, customers will complain. So you hire a **host** at the door whose only job is: "see which tables are free, seat the next party at the one with the least load".

The **load balancer is the host**. It sees many backend servers and routes each incoming request to one.

### Why it *had* to exist
The moment you add a second server, you need to answer: "how do clients know which server to hit?"

Bad answer: "the client picks randomly". Clients are dumb; one server gets hammered.
Worse answer: "we put both IPs in DNS and do round-robin". DNS is cached aggressively; you can't do real-time health checks.
Right answer: **put a load balancer in front**, give the world one IP, let the LB decide per-request where to route.

---

## B. Mental Model

A load balancer has three jobs:
1. **Distribute** traffic across backends.
2. **Health-check** backends so dead ones are removed from rotation within seconds.
3. **Terminate** often-repeated work (TLS, compression) once at the edge.

### Two levels at which it can operate

| Layer | Routes on | Can do | Example |
|---|---|---|---|
| **L4** (transport) | IP + port | Round-robin TCP connections; no URL awareness | AWS NLB, HAProxy L4 mode |
| **L7** (application) | HTTP method, path, headers, cookies | Path routing (/api → service A, /img → service B), sticky sessions by cookie, WAF | AWS ALB, Nginx, Envoy |

L4 is blazing fast and protocol-agnostic. L7 is smarter but costs CPU (it must parse HTTP).

### 🧱 Concretely — what can you do at L7 that you can't do at L4?

| Capability | L4 | L7 |
|---|---|---|
| Route by source IP + port | ✅ | ✅ |
| Route by URL path (`/api/*` → service A) | ❌ | ✅ |
| Route by HTTP host header (multi-tenant) | ❌ | ✅ |
| Route by cookie (sticky session) | ❌ | ✅ |
| Terminate TLS | ⚠️ passthrough only | ✅ |
| Cache HTTP responses | ❌ | ✅ |
| Block WAF / SQLi patterns | ❌ | ✅ |
| Gzip / brotli responses | ❌ | ✅ |
| Rewrite request headers | ❌ | ✅ |
| Preserve client IP automatically | ❌ (use PROXY protocol) | ✅ (adds `X-Forwarded-For`) |

> **🧠 What if you only had L4?** You'd have to push all URL-based logic into app servers, can't centralize TLS, can't cache at the front door. You'd basically re-implement a bad L7 LB inside each service.
>
> **🔎 Quick Check** — You want `/api` to go to Service A and `/static` to go to Service B with the same public domain. Minimum layer needed?
> **🎯 Recall** — L7 (path-based routing).

---

## C. Internal Working

### How an L4 LB handles a new TCP connection
1. Client sends SYN to LB's public IP.
2. LB completes the TCP handshake (or in some modes forwards it to a backend directly — "direct server return" for performance).
3. LB picks a backend using its algorithm (round-robin, least-conn, hash).
4. Opens TCP to the backend, splices bytes in both directions until either side closes.
5. One logical connection, two TCP connections (client↔LB, LB↔backend).

Cost: minimal CPU per packet, no HTTP parsing. Cannot make decisions on URL/header.

### How an L7 LB handles a new request
1. Client completes TCP + TLS with LB.
2. LB reads the full HTTP request (method, path, headers, cookies).
3. Applies rules (e.g., path `/api` → upstream pool A, path `/static` → upstream pool B).
4. Picks a backend, maintains a pool of keep-alive connections to upstreams (for performance).
5. Forwards, reads response, forwards to client.
6. Can cache, compress, rewrite headers, add `X-Forwarded-For`.

Cost: HTTP parsing per request. Gain: rich routing logic.

### Algorithms — when each one wins

| Algorithm | Best for | Breaks when |
|---|---|---|
| **Round-robin** | Homogeneous backends, short requests | Heterogeneous capacity; long requests pile up on same server |
| **Weighted round-robin** | Heterogeneous servers (big + small) | Weights are static; doesn't adapt to runtime load |
| **Least connections** | Long-lived connections (DB, WebSocket) | Needs real-time conn counts — LB state per backend |
| **Least response time** | Mixed-latency workloads | LB must track RTT per backend |
| **IP hash / URL hash** | Cache locality, sticky sessions | One hot user → one hot server; rebalance pain when adding/removing backends |
| **Random (with two choices)** | Simple, surprisingly competitive ("power of two choices") | Needs statistical sample |

**Power of two choices** is a personal favorite interview topic: pick 2 backends at random, send to whichever has fewer connections. Theoretically much better than pure random, almost as good as least-conn, dirt simple to implement. [Used in Nginx, HAProxy, Envoy.]

### Health checks
- **Active**: LB pings `/healthz` every N seconds, counts consecutive failures before evicting.
- **Passive**: LB tracks failures on real traffic; if 3-in-a-row 5xx, evict for a cooldown.
- Both should be used; passive alone is too slow, active alone misses real-traffic failures.

---

## D. Visual Representation

```
                        ┌─[ API server 1 ]
                        │
  Clients ─→ [LB (health-check each) ]─→ [ API server 2 ]
                        │
                        └─[ API server 3 ]
                                │
                        [ LB standby (failover)]
```

Two LBs for redundancy, usually active-passive with VRRP (virtual IP handoff) or DNS-based failover.

---

## E. Tradeoffs

### LB as SPOF
If your LB dies, everything behind it is unreachable. Mitigations:
- **Active-passive** with a floating VIP (keepalived/VRRP).
- **Active-active** with DNS multi-A or anycast.
- **Cloud managed** (AWS ALB, GCP LB) — the provider hides the HA.

### Sticky sessions — a smell
If you need "the user must go to the same backend every time" (sticky), your app is storing session in local memory. The real fix is externalize session (Redis, JWT). Stickiness works but:
- defeats even load distribution,
- one crashed backend → those users' sessions die.

### DNS load balancing limits
Round-robin DNS (multiple A records) "kind of" works but:
- Clients / resolvers cache answers for TTL; real balance only emerges at scale.
- No health awareness — DNS happily hands out IPs of dead servers.
- Use it for regional routing (geo-DNS to nearest PoP), not for real-time server-level balancing.

### TLS termination point
- **At the LB**: simple, central cert management, LB can do L7 routing.
- **Passthrough (TCP)**: LB just splices bytes; backends terminate TLS. Needed when you need end-to-end encryption (finance, health) or mTLS.

---

## F. Interview Lens

### The classic questions
- "L4 vs L7 LB — when do you use each?"
- "An LB itself is a SPOF. How do you avoid that?"
- "Walk me through a request from client to backend through the LB."
- "What's a sticky session and when would you use one?"
- "What are some load balancing algorithms? Which would you use for a WebSocket service?"
  (Hint: least-connections, because connections are long-lived; RR is bad here.)

### Red flags interviewers watch for
- Picking an LB before knowing the traffic shape.
- Saying "round-robin" without considering heterogeneous servers.
- Forgetting about health checks.
- Treating the LB as a magic box, not discussing TLS termination, keep-alives, and connection pools.

### Depth by level
- **Junior**: knows LB distributes requests; can name RR and least-conn.
- **Mid**: can compare L4 and L7; discuss sticky sessions; knows health checks.
- **Senior**: discusses LB-as-SPOF, anycast, power-of-two-choices, connection pool tuning, TLS termination models.

---

## G. Real-World Mapping

- **AWS**: NLB (L4), ALB (L7), CLB (classic, both).
- **GCP**: Google Cloud Load Balancing (anycast global L7).
- **Cloudflare**: anycast L7 LB across 300+ edge PoPs.
- **Nginx / HAProxy / Envoy**: self-hosted, used heavily inside k8s (Envoy powers Istio).
- **Netflix Zuul / Spring Cloud Gateway**: application-aware LBs used in microservice stacks.

---

## H. Questions

### Beginner
1. Why do we need a load balancer?
2. What's the difference between L4 and L7?
3. Name 3 load balancing algorithms.

### Intermediate
1. A LB is a SPOF. How do you eliminate that?
2. When is round-robin a bad choice?
3. What does "TLS termination at the LB" mean and what's the alternative?
4. What's a sticky session and why might you avoid it?

### Advanced (interview)
1. Design the front door of Amazon.com from DNS → LB → app tier. Walk through a request.
2. Why would you pick least-connections over round-robin for a WebSocket service?
3. Explain "power of two choices" and why it works so well.
4. Your LB has 4 backends. You add a 5th. With consistent hashing, what fraction of sessions get reassigned? With simple hash modulo? (Consistent: ~1/n; modulo: nearly all — this is the setup for [Consistent Hashing](../../data/consistent-hashing.md).)

---

## I. Mini Design Problem — "Load-balance a video streaming service"

Service: 100k concurrent viewers; each session is a long-lived HTTP/2 stream (15 min avg).

**Design choices**
- **Algorithm**: least-connections (sessions are long; RR gets lopsided fast).
- **Layer**: L7 — you want to route `/live/*` to live servers, `/vod/*` to VoD servers.
- **Termination**: TLS at LB; backends on trusted network.
- **Health checks**: active `/healthz` every 2s + passive on failures.
- **Redundancy**: active-active LB pair behind an anycast IP.
- **Connection draining**: on backend removal, stop new connections, let existing ones finish (15 min max) before full eviction.

This pattern (L7 + least-conn + connection draining) is used by Netflix and YouTube.

---

## J. Cross-Topic Connections
- **[Proxy](../networking/proxy.md)** — LB *is* a specialized reverse proxy.
- **[DNS](../networking/dns.md)** — DNS-level LB is the first layer.
- **[Caching](caching.md)** — L7 LBs often cache.
- **[Consistent Hashing](../../data/consistent-hashing.md)** — the right hash for sticky-ish routing without rebalancing pain.
- **[Circuit Breaker](../../reliability/circuit-breaker.md)** — often co-located with LB logic.

---

## K. Confidence Checklist
- [ ] I can draw an LB with 3 backends and health checks.
- [ ] I know when to pick L4 vs L7.
- [ ] I can list 4 algorithms and say where each breaks.
- [ ] I know how to make the LB itself HA.
- [ ] I can walk request → TLS → backend at the packet level.

### Red flags
- ❌ Using round-robin for long-lived connections.
- ❌ Forgetting health checks.
- ❌ Thinking DNS LB is a substitute for real LB.

---

## L. Potential Gaps & Improvements
- Global Server Load Balancing (GSLB) — the layer above regional LBs — deserves its own section.
- Backend connection pooling math (e.g., "for 10k client conns to LB, how many upstream conns do I need?") — missing.
- TCP keep-alive vs HTTP keep-alive tuning — missing.
- Deep discussion of "direct server return" (DSR) for L4 LBs — very performance-relevant, omitted.
- BGP-based anycast LBs deserve a deep-dive.
