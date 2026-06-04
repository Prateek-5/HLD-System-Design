# Proxy — Forward vs Reverse, and Why the Reverse One is Everywhere

> **Prereq**: [IP](ip.md), [TCP/UDP](tcp-udp.md), [OSI](osi.md)
> **What you will understand by the end**: the difference between a forward and a reverse proxy, why your company has both, and why almost every production web system sits behind a reverse proxy even when the engineers don't realize it.

---

## A. Intuition First

### The analogy
Imagine you want to buy something without the seller knowing who you are. You hire an **agent**. You tell the agent what you want, the agent buys it, hands it to you. The seller only ever sees the agent.

A **forward proxy** is that agent — it sits in front of clients, hiding them from servers.

Now imagine the seller — a famous person whose fans mob them directly — wants their own buffer. They hire a **receptionist** who takes all requests and filters / routes them. Customers only ever talk to the receptionist.

A **reverse proxy** is that receptionist — it sits in front of servers, hiding them from clients.

### Why these had to exist
- **Forward proxy**: privacy (hide the client), policy enforcement (corporate firewall says "no Facebook"), caching (download common resources once for many users).
- **Reverse proxy**: protection (don't expose servers directly), scaling (one face, many servers behind), termination (SSL, compression, caching at one place).

Fundamentally both are just "a middlebox that forwards traffic" — but the direction of the hiding is opposite.

---

## B. Mental Model

**Forward proxy** (client-side):
```
[Client A]─┐
[Client B]─┼─→ [Forward Proxy] ─→ [Internet] ─→ [Server]
[Client C]─┘
```
The server sees "one client" — the proxy. Client identities are hidden.

**Reverse proxy** (server-side):
```
                                ┌─→ [Server 1]
[Client] ─→ [Reverse Proxy] ───┼─→ [Server 2]
                                └─→ [Server 3]
```
The client sees "one server" — the proxy. Server fleet is hidden.

**Key test to tell them apart**: *Whose identity is being hidden from the other side?*

### 🧱 What each side sees

| Role | Forward Proxy | Reverse Proxy |
|---|---|---|
| Client sees | "The target server" (may not know proxy exists if transparent) | "One server" at a stable IP/DNS name |
| Server sees | The proxy's IP (not the real client) | The proxy's IP; real client IP via `X-Forwarded-For` header |
| Proxy knows | Real client, real target | Real client, chosen backend |

> **🔎 Quick Check** — Which type of proxy is Cloudflare, when it sits between the public internet and your origin server?
> **🎯 Recall** — Reverse proxy. It hides your origin from clients.

---

## C. Internal Working

### Forward proxy flow
1. Client's application (browser, app) is configured to send all HTTP traffic to the proxy (via OS network settings or PAC file).
2. Browser opens TCP to the proxy (not to the target server).
3. Browser sends a slightly modified request: `GET http://example.com/page HTTP/1.1` — full URL in the request line (normal HTTP sends just `/page`).
4. Proxy opens its own TCP connection to `example.com`, forwards the request with its own source IP.
5. Proxy receives response, returns it to the client.
6. `example.com` logs see the proxy's IP, not the client's.

For HTTPS, the client uses the **CONNECT** method: it tells the proxy "please open a TCP tunnel to `example.com:443`" and then does TLS end-to-end with the server, so the proxy can't read the traffic (only the hostname via SNI).

### Reverse proxy flow
1. Client resolves `yourapp.com` to the reverse proxy's IP (not the backend).
2. Client opens TCP + TLS with the reverse proxy.
3. Proxy reads HTTP request, picks a backend (based on path, host header, healthy pool, load algorithm).
4. Proxy opens its own TCP connection to the chosen backend (often keep-alive pooled).
5. Proxy forwards the request.
6. Proxy receives backend response, returns it (possibly caching, compressing, modifying headers).
7. Client never learns which backend served it.

### What a reverse proxy commonly does (beyond forwarding)
- **TLS termination**: decrypt once at the edge; talk to backends over plain HTTP inside a trusted network.
- **Load balancing**: round-robin, least-connections, consistent-hash.
- **Caching**: cache 200 OK responses for static content, invalidate on write.
- **Compression**: gzip / brotli the response body.
- **Header rewriting**: add `X-Forwarded-For`, strip internal headers.
- **Authentication**: validate a JWT, inject user identity into an internal header.
- **Rate limiting**: see [Rate Limiting](../../reliability/rate-limiting.md).
- **WAF (Web Application Firewall)**: block SQL injection attempts, etc.
- **A/B routing**: 1% of traffic to canary build.

---

## D. Visual Representation

**Forward proxy** — corporate office:
```
Office LAN                           Internet
┌───────────────────────┐           ┌──────────────┐
│  Employee browsers ───┼─→ Proxy ──┼─→ Websites    │
│  (configured to       │           │              │
│   send via proxy)     │           │              │
└───────────────────────┘           └──────────────┘
                                    Websites see only
                                    proxy's IP
```

**Reverse proxy** — public web app:
```
Public Internet                     Private network
┌──────────────┐         ┌──────────────────────────┐
│  Clients ────┼─→ LB / ─┼─→ App server 1           │
│              │   Proxy │── App server 2            │
│              │         │── App server 3            │
└──────────────┘         └──────────────────────────┘
Clients see only           Actual servers are hidden
proxy's domain/IP
```

---

## E. Tradeoffs

### Forward proxy
- **Pros**: corporate control, caching (Squid), anonymity.
- **Cons**: becomes a bottleneck; must be trusted with traffic contents (unless only CONNECT); HTTPS makes caching moot.

### Reverse proxy
- **Pros**: single public entry point, TLS termination, load balancing, caching, request filtering.
- **Cons**: SPOF if not redundant; adds latency (~1 ms per hop); one more thing to monitor; if it dies, all traffic dies.

### "Transparent" proxy
A forward proxy that intercepts traffic without client configuration (e.g., carrier-grade NAT + HTTP interception). Legal/ethics baggage and mostly HTTP-only.

### Reverse proxy vs load balancer — are they the same?
**Mostly yes.** A load balancer *is* a kind of reverse proxy (it hides backends and spreads traffic). Engineers use the terms somewhat interchangeably. Subtle distinctions:
- "Load balancer" emphasizes traffic *distribution*.
- "Reverse proxy" emphasizes request *manipulation* (rewriting, auth, caching).

Nginx can be both. AWS ALB is both. In a real architecture, the same box usually plays both roles.

---

## F. Interview Lens

### Common questions
- "What's the difference between a forward and a reverse proxy?" — direction of hiding.
- "Is a load balancer a reverse proxy?" — mostly yes (see above).
- "What does TLS termination mean?" — decrypt at the proxy, plaintext inside the private network. Why: lets the proxy do L7 routing and caching.
- "What header does a reverse proxy add so backends know the real client IP?" — `X-Forwarded-For`, `X-Real-IP`.
- "What's the risk of trusting `X-Forwarded-For`?" — clients can forge it. Only trust it from your own trusted proxies; strip / overwrite from outside.

### Subtle interview gotchas
- **End-to-end TLS vs termination**: in a fully secure model, TLS is terminated at the backend itself (mTLS between proxy and backend). Most companies terminate at the proxy for simplicity.
- **Idempotency**: a proxy retrying a POST to another backend can double-apply a mutation. Real systems handle this via idempotency keys.
- **Sticky sessions** — a proxy can pin a user to a backend via cookie or IP. Sometimes necessary, often a smell (suggests the app isn't stateless).

### Depth by level
- **Junior**: knows forward vs reverse with examples.
- **Mid**: can describe TLS termination, `X-Forwarded-For`, caching.
- **Senior**: discusses stateless-vs-sticky tradeoffs, proxy as a SPOF, why HTTP/2 + HTTPS has changed forward proxies' usefulness.

---

## G. Real-World Mapping

**Reverse proxies you touch every day:**
- **Nginx, Apache, HAProxy, Envoy** — open-source.
- **AWS ALB / NLB / CloudFront** — managed.
- **Cloudflare** — reverse proxy for the planet (plus CDN + WAF + DDoS protection).
- **Istio / Linkerd sidecar (Envoy)** — service mesh. Every pod in k8s has a reverse proxy *inside it*.

**Forward proxies:**
- **Corporate egress proxies** (Blue Coat, Zscaler).
- **Squid** (classic open-source caching proxy).
- **SOCKS proxies** (often used for SSH tunneling / VPN-lite).

---

## H. Questions

### Beginner
1. What does a proxy do?
2. What's the difference between a forward and a reverse proxy?

### Intermediate
1. Why would a company use a forward proxy? A reverse proxy?
2. What is TLS termination and where does it happen?
3. What does `X-Forwarded-For` solve?

### Advanced (interview)
1. Design the front door of a web app serving 1M QPS. Start from DNS and walk inward.
2. In a service mesh, every service has a sidecar proxy. Why? What does this buy you?
3. A user reports "my requests reach your server but the server sees my IP as the LB, not mine." Debug and fix.
4. Forward proxy vs VPN — when would you choose one over the other?

---

## I. Mini Design Problem — "Place a reverse proxy"

For a 3-tier web app (browser → app servers → DB), the team proposes putting a reverse proxy in front of the app servers. List what they get by doing this.

**Expected answer:**
1. Single public endpoint — fewer DNS records, one TLS cert.
2. TLS termination — simpler app code (no TLS inside).
3. Load balancing across app servers.
4. Caching of static responses.
5. Compression / header rewriting.
6. Rate limiting at the edge.
7. WAF / request inspection before it hits the app.
8. Ability to deploy app servers with no public IPs (security).

This is why every serious prod system has a reverse proxy at the edge. Not optional.

---

## J. Cross-Topic Connections
- **[Load Balancing](../scaling/load-balancing.md)** — reverse proxy is often *also* the LB.
- **[API Gateway](../../architecture/api-gateway.md)** — a reverse proxy with app-awareness (auth, throttling, API versioning).
- **[CDN](../scaling/cdn.md)** — a planet-wide reverse-proxy caching layer.
- **[Rate Limiting](../../reliability/rate-limiting.md)** — commonly done at the proxy.
- **[SSL/TLS](../../reliability/ssl-tls-mtls.md)** — terminated at the proxy.

---

## K. Confidence Checklist
- [ ] I can state the one-sentence difference between forward and reverse.
- [ ] I can list 5 things a reverse proxy typically does besides forwarding.
- [ ] I know what `X-Forwarded-For` is and its security caveat.
- [ ] I can defend putting a reverse proxy in front of any public service.

### Red flags
- ❌ Confusing the directions.
- ❌ "TLS is always end-to-end" — not in most real deployments; it's terminated at the edge.
- ❌ Treating reverse proxy as "just a load balancer" with no awareness of the other concerns.

---

## L. Potential Gaps & Improvements
- **Sidecar proxy / service mesh** — a tiny reverse proxy (Envoy) deployed next to every service so mesh handles TLS, retries, and routing; deserves its own file because it powers modern microservice infra (→ see Real-World Mapping).
- **HTTP/2 multiplexing** — one connection carries many parallel request streams, so a proxy's old "one backend connection per client request" pooling model breaks down; learn it because it reshapes how you size backend connections.
- **Connection pooling math** — how many keep-alive backend connections each proxy instance should hold open (roughly concurrent in-flight requests ÷ instances); matters so you don't exhaust backend sockets under load.
- **PROXY Protocol v1/v2** — a small header an L4 (Layer 4 / TCP) load balancer prepends so the backend still learns the real client IP that TCP would otherwise hide; needed whenever you load-balance below HTTP and lose `X-Forwarded-For`.
- **xDS (the Envoy discovery APIs)** — the gRPC/REST APIs (LDS, CDS, EDS, RDS) a control plane uses to push live config to Envoy proxies; key to understanding how a service mesh updates routing without restarts.

**🔧 How to close:** Run a local reverse proxy and watch it hide the backend: `docker run -d -p 8080:80 --name web nginx`, then put a second nginx in front of it as a reverse proxy and curl through it with `curl -v http://localhost:8081/`. Inspect the `X-Forwarded-For` and `Server` headers the proxy adds, and use `ss -tan | grep :80` to see the separate front-side and back-side TCP connections the proxy maintains.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🕸️ Gap 1 — Sidecar Proxy & Service Mesh
- 🔹 **What it is**: A tiny reverse proxy (usually Envoy) deployed right next to every service instance, so a control plane can handle TLS, retries, and routing for the whole fleet.
- 🔹 **Why it matters**: It's how modern microservice infra (Istio, Linkerd) moves networking concerns out of app code — a very common "how does your service mesh work?" interview thread.
- 🔹 **Connection**: Section G already noted "every pod in k8s has a reverse proxy inside it." This is that proxy — the same TLS-termination and routing jobs from Section C, just replicated per-pod instead of one box at the edge.
- 🔹 **When needed**: 🔴 **Senior** — relevant for platform/infra and microservices-at-scale rounds.
- 🔹 **Intuition**: Instead of one receptionist at the building's front door, give *every office* its own personal assistant who logs visitors, checks IDs, and retries dropped calls — uniformly, without each office writing its own rules.
- 🔹 **If you go deeper**: Read the Istio architecture docs and Envoy's "service mesh" overview; deploy a two-service mesh locally with Linkerd's getting-started and watch mTLS turn on with zero app changes.
- 🔹 **Interview hook**: *"In a service mesh, every service has a sidecar proxy — why?"* → It pushes cross-cutting networking (mTLS, retries, observability, traffic-shifting) into a uniform data plane, so app teams stop reimplementing it and the platform controls it centrally.

---

#### 🔀 Gap 2 — HTTP/2 Multiplexing & Connection Pooling Math
- 🔹 **What it is**: HTTP/2 carries many parallel request streams over a single connection, which breaks the old "one backend connection per in-flight request" model and changes how many keep-alive connections a proxy should hold.
- 🔹 **Why it matters**: Mis-sizing the backend pool either exhausts backend sockets under load or under-utilizes connections — a concrete capacity-planning question that separates mid from senior.
- 🔹 **Connection**: Section C's reverse-proxy flow says the proxy "opens its own TCP connection to the chosen backend (often keep-alive pooled)." Multiplexing is what determines how big that pool needs to be.
- 🔹 **When needed**: 🟡 **Mid-level** — useful once you're reasoning about proxy capacity and tuning real deployments.
- 🔹 **Intuition**: HTTP/1.1 pooling is like needing one phone line per simultaneous call; HTTP/2 is a single line that carries many conversations at once — so you suddenly need far fewer lines, but each line is busier.
- 🔹 **If you go deeper**: Read RFC 7540 (HTTP/2) on streams and multiplexing, then tune Nginx `keepalive` / Envoy `max_requests_per_connection` and load-test to find the right pool size (roughly concurrent in-flight requests ÷ proxy instances).
- 🔹 **Interview hook**: *"How many backend connections should each proxy instance keep open?"* → Size it to peak concurrent in-flight requests divided by the number of proxy instances, then adjust for HTTP/2 multiplexing, which lets one connection serve many streams.

---

#### 🧾 Gap 3 — Preserving Client IP Below HTTP (PROXY Protocol & xDS)
- 🔹 **What it is**: When you load-balance at Layer 4 (raw TCP) you lose `X-Forwarded-For`, so the **PROXY Protocol** prepends a tiny header carrying the real client IP; separately, **xDS** is the set of gRPC/REST APIs (LDS, CDS, EDS, RDS) a control plane uses to push live config to Envoy proxies without restarts.
- 🔹 **Why it matters**: Both are the "how does this actually work in production" follow-ups to the file's client-IP and routing topics — and a forged-or-lost client IP is a real security and debugging hazard.
- 🔹 **Connection**: Section C and the Interview Lens lean on `X-Forwarded-For` to recover the real client IP, but that only exists at L7; PROXY Protocol solves the same problem at L4. xDS is what makes the per-pod sidecars from Gap 1 update routing dynamically.
- 🔹 **When needed**: 🔴 **Senior** — infra/networking depth; rarely needed until you operate L4 LBs or a mesh.
- 🔹 **Intuition**: A sealed envelope (TCP) hides the sender's return address; PROXY Protocol staples a sticky note with the original sender on the front before handing it over. xDS is the dispatcher radioing every courier new delivery routes mid-shift instead of recalling them to base.
- 🔹 **If you go deeper**: Read HAProxy's PROXY Protocol spec (v1/v2) and enable it between an L4 LB and Nginx; read the Envoy xDS API docs to see how LDS/CDS/EDS/RDS map to listeners, clusters, endpoints, and routes.
- 🔹 **Interview hook**: *"You load-balance at L4 and the backend only sees the LB's IP — how do you recover the real client IP?"* → Enable the PROXY Protocol so the LB prepends a header with the original client address, since `X-Forwarded-For` only exists once you parse HTTP at L7.

---

### 🏆 Start here if you have limited time
1. **HTTP/2 multiplexing & pooling math** — the most broadly applicable; it shows up the moment you tune or size a real proxy.
2. **Sidecar proxy / service mesh** — highest-leverage for microservices and platform interviews.

---

### 🧭 Suggested Deep Dive Order
1. **HTTP/2 multiplexing & connection pooling** (~45 min; immediately useful for capacity planning).
2. **Sidecar proxy / service mesh** (~1.5h; unlocks modern microservice infra).
3. **PROXY Protocol & xDS** (~1h; senior-infra signaling, builds on the mesh you just learned).
