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
