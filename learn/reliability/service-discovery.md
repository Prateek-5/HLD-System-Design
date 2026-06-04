# Service Discovery — How Services Find Each Other

## A. Intuition First
In a dynamic microservices environment, pod IPs change constantly. Hardcoding IPs fails. Service discovery maps a logical name (e.g., `payments`) to a list of live instance endpoints.

## B. Mental Model
- **Service Registry** — central store of registered services + their endpoints.
- **Client-side discovery** — client queries registry, picks instance, calls directly.
- **Server-side discovery** — client calls a fixed address (LB), which looks up and forwards.

## C. Internal Working
Registration: on startup, instance registers (name, IP, port, health). Periodic heartbeats keep it alive.
Deregistration: on shutdown or missed heartbeats → remove.
Lookup: by name → list of healthy instances.

## D. Visual Representation
```
[Service A] → [Registry (Consul/etcd)] ← register/heartbeat ← [Service B instances]
     │
     └── list of B endpoints → pick one → call
```

## E. Tradeoffs
- Client-side: less infra, but every client must integrate.
- Server-side: opaque to clients (use LB), but LB is SPOF without HA.
- DNS-based discovery (Kubernetes) is simple but cached; real-time health requires more.

## F. Interview Lens
- "How do services find each other?" — registry + health checks.
- "DNS-based vs registry-based?" — DNS cached (seconds), registry near-real-time.
- Pitfalls: no TTL on entries; stale endpoints.

## G. Real-World Mapping
Kubernetes (CoreDNS + Endpoints API), Consul, etcd, Eureka (Netflix), Zookeeper.

## H. Questions
**Beginner**: Why do we need SD?
**Intermediate**: Client-side vs server-side?
**Advanced**: Design SD for 10k services, 100k instances.

## I. Mini Design
k8s: services register via kube-apiserver; CoreDNS returns endpoint list; kube-proxy uses iptables/IPVS for per-pod routing.

## J. Cross-Topic Connections
- [DNS](../foundations/networking/dns.md), [Load Balancing](../foundations/scaling/load-balancing.md), [Clustering](../foundations/scaling/clustering.md), [API Gateway](../architecture/api-gateway.md).

## K. Confidence Checklist
- [ ] Can name 3 discovery systems.
- [ ] Knows client-side vs server-side.

## L. Potential Gaps & Improvements
- **Service mesh (Istio, Linkerd)** — an infrastructure layer that runs a proxy "sidecar" next to each service; it handles SD (Service Discovery), routing, and retries so app code stays clean — increasingly the default answer to "how do services find each other."
- **Sidecar pattern** — a helper proxy container deployed alongside your app container that intercepts all network traffic; learn it because it's how the mesh adds discovery and security without touching your code.
- **xDS protocol (Envoy)** — the family of "discovery service" APIs (Endpoint, Cluster, Route, Listener Discovery Service) that the Envoy proxy uses to fetch live config and endpoint lists from a control plane; worth knowing as the standard way meshes push routing updates dynamically.
- **Client-side vs server-side discovery** — client-side has the caller query a registry and pick an instance itself, while server-side hides that behind a load balancer; learners should be able to weigh the two in a design interview.

**🔧 How to close:** Run a local registry to watch discovery happen live: `docker run -d -p 8500:8500 consul agent -dev -client=0.0.0.0`, then register a fake service with `curl --request PUT --data '{"Name":"web","Port":80}' http://localhost:8500/v1/agent/service/register` and confirm it appears via `dig @localhost -p 8600 web.service.consul` — you'll see Consul answer DNS for the service you just registered.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🕸️ Gap 1 — Service Mesh & the Sidecar Pattern
- 🔹 **What it is**: A dedicated infrastructure layer that runs a small proxy ("sidecar") next to every service instance, taking over discovery, routing, retries, and mTLS so your application code stays free of that plumbing.
- 🔹 **Why it matters**: It's increasingly the default modern answer to "how do services find and talk to each other safely?" — interviewers expect you to know the mesh exists and what work it offloads.
- 🔹 **Connection**: This file's client-side discovery requires every client to integrate a registry SDK. A mesh moves that integration into the sidecar, so the app just calls `localhost` and the proxy handles the registry lookup, instance pick, and health-aware routing from §C.
- 🔹 **When needed**: 🟡 **Mid-level** to name it and explain the offload; 🔴 **Senior** to reason about its latency/operational cost.
- 🔹 **Intuition**: A personal translator who walks beside you everywhere. You speak your own language to them; they handle finding the right person, dialing, and re-dialing on a dropped call — you never learn the phone system.
- 🔹 **If you go deeper**: Read the Istio architecture docs and Linkerd's design; build a 2-service demo on Istio and watch the Envoy sidecar inject. Compare with the newer Istio "ambient mesh" (no per-pod sidecar).
- 🔹 **Interview hook**: *"Why use a service mesh instead of a discovery library?"* → it decouples cross-cutting concerns (discovery, retries, mTLS, observability) from app code so polyglot services get them uniformly without per-language SDKs.

---

#### 📡 Gap 2 — xDS / Envoy Control-Plane Protocol
- 🔹 **What it is**: The xDS family of "discovery service" APIs — EDS, CDS, RDS, LDS (Endpoint/Cluster/Route/Listener Discovery Service) — that an Envoy proxy uses to pull live endpoint lists and routing config from a control plane instead of restarting on every change.
- 🔹 **Why it matters**: It's the standard mechanism by which meshes *push* discovery and routing updates dynamically — knowing it shows you understand the wire-level "how," not just the buzzword "mesh."
- 🔹 **Connection**: §C describes lookup as "by name → list of healthy instances." xDS is the concrete protocol delivering that list to the data-plane proxy continuously, replacing the polling/DNS-cache staleness §E warns about.
- 🔹 **When needed**: 🔴 **Senior** — relevant for platform/infra and mesh-internals interviews.
- 🔹 **Intuition**: A live stock ticker feeding into a trader's screen. The trader (proxy) never refreshes a page; new prices (endpoints) stream in and the display updates in place.
- 🔹 **If you go deeper**: Read the Envoy xDS REST/gRPC protocol docs and the "Universal Data Plane API"; trace how Istio's `istiod` serves xDS. Run Envoy with a static config, then a dynamic ADS (Aggregated Discovery Service) stream.
- 🔹 **Interview hook**: *"How does the mesh propagate a new instance to all callers in real time?"* → the control plane streams an updated EDS response over xDS; proxies hot-reload endpoints with no restart.

---

#### 🤝 Gap 3 — Client-Side vs Server-Side Discovery (and the Health-Check Tradeoff)
- 🔹 **What it is**: The two structural choices for *who* does the lookup — the caller queries the registry and picks an instance (client-side), or a load balancer / mesh hides that behind a fixed address (server-side) — plus how stale entries are pruned via health checks and TTLs.
- 🔹 **Why it matters**: This is a direct, frequently-asked design-interview fork; you should be able to weigh infra cost vs client coupling vs SPOF in seconds.
- 🔹 **Connection**: Directly expands §B and §E. The file flags "no TTL on entries; stale endpoints" as a pitfall — that pitfall lives or dies on which side owns the health-check loop and how aggressively it deregisters.
- 🔹 **When needed**: 🟢 **Foundational** — most readers benefit now and it shows up in basic system-design rounds.
- 🔹 **Intuition**: Calling a company: client-side is you keeping every employee's direct number and redialing if one quit; server-side is dialing one switchboard that always knows who's currently at their desk.
- 🔹 **If you go deeper**: Compare Netflix Eureka (client-side, with Ribbon) against Kubernetes Services + kube-proxy (server-side). Implement both against your local Consul from the "How to close" exercise and kill an instance to watch deregistration timing.
- 🔹 **Interview hook**: *"Client-side or server-side discovery — which and why?"* → client-side avoids an LB hop and SPOF but couples every client to the registry; server-side keeps clients dumb but needs an HA load balancer.

---

#### 🗳️ Gap 4 — Registry Consistency: CP vs AP for Discovery Data
- 🔹 **What it is**: The choice of how the registry itself stays correct under failure — a strongly-consistent (CP) store like etcd/Consul using Raft, versus an availability-favoring (AP) store like Eureka that may serve slightly stale endpoint lists during partitions.
- 🔹 **Why it matters**: The "Design SD for 10k services, 100k instances" advanced question hinges on this; the answer reveals whether you understand CAP applied to the very data discovery depends on.
- 🔹 **Connection**: Directly the §H Advanced question and §G's mention of Consul/etcd/Eureka/Zookeeper. Whether a freshly-failed instance disappears immediately or lingers for seconds is exactly this CP/AP tradeoff acting on §C's heartbeat/deregistration loop.
- 🔹 **When needed**: 🔴 **Senior** — distributed-systems and scale-design rounds.
- 🔹 **Intuition**: A guest list at two venues. The strict venue (CP) refuses entry until the master list syncs, so it may briefly turn people away; the relaxed venue (AP) always lets the line move using its last-known list, occasionally admitting someone who already left.
- 🔹 **If you go deeper**: Read the Raft paper (Ongaro & Ousterhout) behind etcd/Consul, and Netflix's writeup on why Eureka chose AP. Note Zookeeper is CP (ZAB). Reason about how each behaves during a network partition for discovery specifically.
- 🔹 **Interview hook**: *"Should a service registry be CP or AP?"* → usually AP: in a partition you'd rather route to a possibly-stale instance (and fail/retry) than have discovery go fully unavailable; CP risks blocking lookups when you most need them.

---

### 🏆 Start here if you have limited time
1. **Client-side vs server-side discovery** — the most directly asked fork; foundational and reachable now.
2. **Service mesh & sidecar** — the modern default answer interviewers now expect alongside the classic registry story.

---

### 🧭 Suggested Deep Dive Order
1. **Client-side vs server-side + health checks** (~45 min; foundational, immediately interview-usable).
2. **Service mesh & sidecar pattern** (~1h; high-relevance modern context).
3. **Registry consistency CP vs AP** (~1h; senior scale-design signaling).
4. **xDS / Envoy control-plane protocol** (~1.5h; deepest, mesh-internals payoff).
