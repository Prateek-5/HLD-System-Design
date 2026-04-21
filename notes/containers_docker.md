# Containers & Docker

> **📎 Prereqs** — If rusty:
> - Basic Linux processes + file system.
> - [`learn/reliability/vms-and-containers.md`](../learn/reliability/vms-and-containers.md) — VM vs container.
> - OS namespaces + cgroups existence.

### 🔹 1. What This Topic Actually Is
A way to package + isolate a process with its dependencies, using Linux namespaces + cgroups, without virtualizing the whole OS.

### 🔹 2. Why It Exists
- VMs are heavy (minutes to start, GBs per image, own kernel).
- Containers share the host kernel → start in seconds, pack hundreds per host.
- Enable dev/prod parity and immutable deploys.

### 🔹 3. Core Concepts (High Signal)
- **Namespaces**: process, network, mount, PID, user — isolate what a process sees.
- **cgroups**: cap CPU, memory, I/O per process group.
- **Image**: layered filesystem (union FS). Each layer is immutable + cached.
- **Docker architecture**: CLI → Docker daemon → containerd → runc (OCI runtime). Image registry (Docker Hub, ECR, GCR).
- **Orchestration**: Kubernetes scheduling, networking (CNI), storage (CSI), secrets.
- **microVMs (Firecracker)**: container-fast, VM-isolated; used by AWS Lambda, Fargate.

### 🔹 4. Internal Working
- `docker run image`: daemon pulls image, unpacks layers, creates namespaces, applies cgroups, starts process via runc. From cold to running: ~hundreds of ms.
- Network: virtual ethernet pair; bridge or overlay.
- Storage: overlayFS for writable container layer.

**Failure points:** kernel exploits (shared kernel), noisy-neighbor CPU/IO, network plugin bugs, persistent state in containers (use volumes), image supply chain (signed images, scanning).

### 🔹 5. Key Tradeoffs
- Containers: fast, dense; security boundary weaker than VMs.
- VMs: strong isolation; slow, heavy.
- microVMs: best of both for multi-tenant.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. VM vs container?
2. What's a container image?

**Intermediate 🟡**
1. namespaces vs cgroups?
2. Why is Firecracker interesting for Lambda?

**Advanced 🔴**
1. Multi-tenant isolation: containers, VMs, microVMs — pick per tenant risk.
2. How do k8s networking and service discovery work at a high level?

### 🔹 7. Real System Mapping
- **Docker, containerd, runc**: de-facto runtime stack.
- **Kubernetes**: orchestration standard.
- **Facebook Twine**: their cluster/container fabric.
- **Cloudflare Workers Isolates** (V8-based, sub-ms cold start) — alternative to containers for edge compute.
- **AWS Lambda / Fargate** use Firecracker microVMs.

### 🔹 8. What Most People Miss
- **Images should be tiny** — distroless / alpine bases; fewer CVEs + faster pulls.
- **Secrets should never be in images** — inject at runtime (k8s secrets, Vault).
- **Noisy neighbor** is real on shared hosts. cgroup v2 helps but isn't perfect.
- **Cold-start latency** matters: Lambda's Firecracker starts in 125 ms; container cold-starts can be 1–5 s.
- **Immutable infrastructure** is the big win — rebuild + redeploy rather than mutate.

### 🔹 9. 30-Second Revision
Container = process isolated via namespaces + resource-capped via cgroups, sharing host kernel. Image = layered FS. Docker = CLI + daemon → containerd → runc. Firecracker gives VM isolation at container-ish cost. For multi-tenant high-risk workloads, prefer microVM or full VM.

---

## 🔗 Cross-Topic Connections
- **Microservices**: containers are the deploy unit.
- **Service mesh**: sidecar is another container per pod.
- **Observability**: container runtimes feed metrics (cAdvisor).
- **Load Balancing**: k8s Service types (ClusterIP, NodePort, LoadBalancer).

---

### Confidence Check
- [ ] Can I explain namespaces + cgroups in 30s?
- [ ] Can I pick container / VM / microVM per workload?

### Gaps
- CNI plugin internals.
- Image supply chain (Sigstore).
