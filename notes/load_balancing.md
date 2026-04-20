# Load Balancing

### 🔹 1. What This Topic Actually Is
A component that distributes incoming traffic across a pool of backends. Single front-door, many workers. Also does health-checking and TLS termination.

### 🔹 2. Why It Exists
- One server has a throughput & reliability ceiling — LB lets you scale horizontally and absorb failures.
- Without it: clients have no single target; dead servers still get traffic; no way to do gradual deploys or TLS termination.

### 🔹 3. Core Concepts (High Signal)
- **L4 vs L7**: L4 = TCP/UDP, fast, no URL awareness. L7 = HTTP, can route by path/header/cookie, cost: parse HTTP.
- **Algorithms**: Round-robin, weighted, least-connections, least-response-time, IP/URL hash, **power-of-two-choices** (pick 2, send to lighter — nearly as good as least-conn, dirt simple).
- **Health checks**: active (probe `/healthz`) + passive (observe real failures).
- **Sticky sessions**: bind user to one backend. Almost always a smell — externalize state instead.
- **Redundancy**: LB is a SPOF. Use active-passive VIP (VRRP/keepalived) or anycast.
- **Connection draining**: when removing a backend, stop new conns but let existing finish.
- **Subsetting** (Google's trick): each LB instance only knows a subset of backends, not the full fleet — cuts connection count at scale.

### 🔹 4. Internal Working
**L4 path:** client SYN → LB accepts → picks backend → proxies/splices bytes both ways.
**L7 path:** TLS terminated at LB → parse HTTP → route rule match (path/host) → pick from upstream pool → keep-alive connection to backend → stream response → optionally cache/compress.
**Failure points:** single LB dying, upstream pool all-down, slow backend causing queue buildup, TLS handshake storm on cold start.

### 🔹 5. Key Tradeoffs
- Works well: homogeneous stateless tier with fast requests.
- Breaks: long-lived connections (RR goes lopsided → use least-conn), heterogeneous backends (weighted), sticky workloads (consider moving state out).
- Alternatives: DNS round-robin (no health checks), client-side LB (gRPC, Finagle — less infra but couples clients), anycast (BGP-level).

### 🔹 6. Interview Questions
**Beginner**
1. Difference between L4 and L7 LB?
2. Why is a single LB a SPOF and how do you fix it?

**Intermediate**
1. For WebSocket service with long-lived connections, which algorithm?
2. How do health checks + connection draining cooperate during a deploy?

**Advanced**
1. At 1M backends, why does naive "all LBs know all backends" break? (connection count explodes → subsetting)
2. Compare power-of-two-choices vs least-connections in theory and practice.

### 🔹 7. Real System Mapping
- **AWS**: NLB (L4), ALB (L7), CloudFront LB (global anycast).
- **GCP**: Global HTTP(S) LB — single anycast IP, 300+ PoPs.
- **Netflix Zuul**: L7 app-aware gateway.
- **Cloudflare**: anycast planet-scale LB.
- **Nginx/HAProxy/Envoy**: open-source; Envoy powers Istio service mesh.

### 🔹 8. What Most People Miss
- **Connection churn**: reconnecting TCP on every request is expensive at scale. Netflix's Zuul 2 keeps long-lived connections from client to LB and from LB to upstreams.
- **Subsetting** matters hugely beyond ~1000 backends — without it you pay quadratic connection cost.
- **Draining time** should match the longest acceptable request (chat → 5 min; REST → 30s).
- **TLS termination location** is a big design decision — at LB is common; end-to-end (or mTLS to backends) is more secure but harder.

### 🔹 9. 30-Second Revision
L4 = transport, L7 = app. Round-robin is only OK for homogeneous + short. For long conns use least-conn. LB is a SPOF: fix with VRRP or anycast. Health check = active + passive. Sticky sessions are a smell. At scale, subsetting beats full-mesh.

---

## 🔗 Cross-Topic Connections
- **Caching**: L7 LBs often cache responses for static content.
- **Databases**: LB in front of read replicas for read scaling; proxy like pgbouncer for connection pooling.
- **Messaging**: queues decouple producers from consumers — LB does the same synchronously for HTTP.
- **DNS**: DNS LB is the first layer; real LB is second.
- **Consistent hashing**: used for sticky-ish routing without the rebalance pain.

---

### Confidence Check
- [ ] Can I explain L4 vs L7 in 30s?
- [ ] Can I apply: "design the front door of a 1M QPS service"?

### Gaps
- BGP / anycast deep internals.
- Global Server Load Balancing (GSLB) specifics.
- TCP keep-alive tuning numbers for 1M+ conns.
