# Service Mesh

### 🔹 1. What This Topic Actually Is
A layer that handles service-to-service network concerns (mTLS, retries, circuit breaking, routing, telemetry) via **sidecar proxies** (Envoy) injected next to each service — out of the app code.

### 🔹 2. Why It Exists
- In microservices, every service reimplementing retries / TLS / tracing is wasteful and error-prone.
- Mesh externalizes these into a uniform, language-agnostic layer.

### 🔹 3. Core Concepts (High Signal)
- **Data plane**: sidecar proxies (Envoy, Linkerd-proxy) handle traffic.
- **Control plane**: distributes config / policy / certs to sidecars (Istiod, Linkerd-controller).
- **mTLS** everywhere — automatic cert issuance + rotation.
- **Traffic policy**: retries, timeouts, circuit breakers, canary, traffic splitting.
- **Observability**: per-hop metrics, logs, traces — uniform.
- **xDS**: Envoy's discovery protocol (LDS, RDS, CDS, EDS) — control plane → data plane contract.

### 🔹 4. Internal Working
App A → localhost:port (its own sidecar) → Envoy intercepts → mTLS to remote service's sidecar → Envoy on B forwards to B. All policy enforced at the proxy hop.
**Failure points:** sidecar adds latency (~1–2 ms) and CPU; control plane outage leaves last config but no new; iptables rules need to be right; cert rotation issues.

### 🔹 5. Key Tradeoffs
**Pros**: uniform cross-cutting concerns, zero-trust security, rich observability.
**Cons**: ops complexity, resource overhead (sidecar per pod), learning curve, debugging another layer.
**Alternatives**: library-based (Finagle, Spring Cloud) — coupled to language; or gateway-only.

### 🔹 6. Interview Questions
**Beginner**
1. What's a sidecar?
2. Data plane vs control plane?

**Intermediate**
1. Why mesh over libraries?
2. How does mTLS rotate certs automatically?

**Advanced**
1. Debug a request timing out in a mesh — where to look?
2. Cost/benefit of a mesh for 5 services vs 500.

### 🔹 7. Real System Mapping
- **Istio** (Envoy-based; Google + IBM + Lyft).
- **Linkerd** (Rust-based, light).
- **Consul Connect**.
- **AWS App Mesh**.
- **NGINX Service Mesh**.
- Lyft originally built Envoy.

### 🔹 8. What Most People Miss
- **Small-service-count meshes are usually overkill**. Mesh pays off at 30–50+ services.
- **Sidecar memory** (~50 MB × pods) is real infra cost.
- **Zero-trust = mTLS everywhere by default** — you can build this without a mesh but the mesh makes it turnkey.
- **eBPF-based alternatives** (Cilium) sidestep the sidecar overhead — emerging.
- **Traffic shifting** (10% canary) becomes a config push, not a deploy.

### 🔹 9. 30-Second Revision
Sidecar proxy per pod handles mTLS, retries, breakers, observability. Control plane pushes policy. Envoy via xDS. Adds latency + complexity; worth it at 30+ services. eBPF-based (Cilium) is the emerging alternative.

---

## 🔗 Cross-Topic Connections
- **Load Balancing**: mesh LBs per-destination with L7 awareness.
- **Microservices**: mesh externalizes cross-cutting concerns.
- **TLS/mTLS**: zero-trust security story.
- **Observability**: uniform telemetry.

---

### Confidence Check
- [ ] Can I explain data vs control plane?
- [ ] Can I decide mesh-yes-or-no for a given service count?

### Gaps
- Cilium / eBPF details.
- Istio perf tuning.
