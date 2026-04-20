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
- Service mesh (Istio, Linkerd) — SD is built into sidecars.
- xDS protocol (Envoy).
