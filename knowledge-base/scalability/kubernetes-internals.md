# Kubernetes Internals

> *"Kubernetes is the de facto operating system of cloud-native infrastructure. Its design — declarative configuration, control loops, eventual consistency — is borrowed directly from Google's Borg. Understanding the internals is understanding why Kubernetes works the way it does: why state takes time to converge, why the API server is central, why etcd's health is the cluster's health."*

---

## 🎯 Start Here — Intuition

> **In one line:** you tell the system *what* you want running ("keep 3 copies of my app alive"), and it figures out *how* to make that true and keeps it true even when machines die.
>
> **Analogy:** a thermostat for your apps. You set the target ("70°F" / "3 healthy replicas"); the thermostat constantly checks the actual temperature and turns the heat on or off to close the gap. Kubernetes does the same — it watches the real state, compares it to your declared target, and acts to converge — forever, automatically.
>
> **New to this?** Build the basics first in [`learn/reliability/vms-and-containers.md`](../../learn/reliability/vms-and-containers.md) — *then* come back for the depth.
>
> **Level:** this file is 🔴 overall — it's a senior/staff deep-dive into cluster internals. Sections below are tagged. If the basics feel shaky, that tag is your signal to slow down — **you are not behind.**

---

## Topic Overview 🟢

Kubernetes (K8s) orchestrates containers across a cluster. You describe desired state ("3 replicas of this service, with these resource requests, exposed on port 8080"); Kubernetes works toward that state continuously. The architecture is built around a few key components: **etcd** (the source of truth); the **API server** (the central interface); **schedulers** (decide where pods run); **controllers** (drive state toward desired); **kubelets** (run pods on nodes).

The model is **declarative + eventual consistency**. You declare; Kubernetes converges. The reconciliation loop pattern — observe state, calculate diff, take corrective action — runs continuously across hundreds of controllers.

This is the topic that explains why Kubernetes feels both magical and frustrating. The system is highly resilient, self-healing, and operationally demanding. Understanding the internals — etcd, API server, controllers, networking, storage — is what separates "I deploy YAML" from "I operate Kubernetes clusters."

---

## Intuition Before Definitions 🟢

Imagine running a fleet of warehouses with thousands of robots, where you specify what should happen ("there should be 3 robots in aisle 5 sorting boxes") and a manager works to make it true.

You don't tell each robot what to do. You declare desired state. The manager continuously checks: are there 3 robots in aisle 5? If only 2, dispatch another. If 4, recall one. The manager handles failures: robot breaks, dispatch a replacement.

That's Kubernetes. You declare desired state; controllers reconcile reality toward it. Failures trigger automatic recovery. The system is resilient by design — at the cost of complexity, eventual consistency, and operational depth.

---

## Historical Evolution 🟢

**Era 1 — Borg.**
2003+. Google's internal cluster manager. Documented in 2015 paper. Scheduled millions of jobs across hundreds of thousands of machines.

**Era 2 — Kubernetes 1.0 (2015).**
Open-source successor to Borg. CNCF (Cloud Native Computing Foundation) stewardship. Slow initial adoption.

**Era 3 — Mainstream adoption.**
2017+. Kubernetes wins the orchestration wars. Docker Swarm, Mesos fade. Cloud providers offer managed K8s (EKS — Elastic Kubernetes Service, GKE — Google Kubernetes Engine, AKS — Azure Kubernetes Service).

**Era 4 — Operator pattern.**
~2018. Custom controllers extend Kubernetes for stateful workloads (databases, etc.). CRDs (Custom Resource Definitions) ubiquitous.

**Era 5 — Service mesh integration.**
~2019. Istio, Linkerd, others. Networking-heavy features push down into infrastructure.

**Era 6 — Mature platform.**
2024+. Production at every scale; complex but standard. Argo CD, Helm, ecosystem rich.

The pattern: Kubernetes won by combining Borg's design with open-source community. Now it's the platform underneath most cloud-native infrastructure.

---

## Deep Technical Explanation 🔴

⚠️ The rest assumes the basics above are solid.

### Architecture overview

Control plane:
- **etcd**: distributed KV (Key-Value) store; cluster's source of truth.
- **kube-apiserver**: REST (Representational State Transfer) API; the only thing that writes to etcd.
- **kube-scheduler**: assigns pods to nodes.
- **kube-controller-manager**: runs core controllers.
- **cloud-controller-manager**: cloud-specific integration.

Worker nodes:
- **kubelet**: runs pods on the node; reports status.
- **kube-proxy**: implements service networking.
- **Container runtime**: containerd, CRI-O (Container Runtime Interface for OCI).

CNI (Container Network Interface) plugins: pod networking. CSI (Container Storage Interface) plugins: storage.

### etcd

A consensus-based KV store (Raft). Stores all cluster state.


Properties:
- 3-, 5-, or 7-node clusters typical.
- Strong consistency.
- Write throughput is workload- and fsync-bound; under real K8s object churn it is often far lower than headline benchmark numbers, so treat it as latency-sensitive rather than high-throughput. Reads cached.
- Latency-sensitive: SSD (Solid-State Drive) storage required.

When etcd is unhealthy, the cluster is effectively unusable. Operators monitor etcd carefully.

### API server

Central HTTP API. Everything goes through it:
- `kubectl` talks to it.
- Controllers talk to it.
- kubelets talk to it.

Properties:
- Stateless; scales horizontally.
- Authentication, authorization, admission control.
- Persists state to etcd.
- Watch-based change notifications.

### The watch / list pattern

Components don't poll; they watch:
1. List all resources of a type (initial state).
2. Watch for changes (incremental).
3. Reconnect on disconnect (resume from last seen version).

Watches are HTTP long-poll connections. Efficient at scale; one of K8s's key design choices.

### Controllers

A controller watches resources, compares desired vs actual, takes action. Pattern:

```
# Driven by watches via an informer, not a poll loop:
# the informer maintains a local cache and enqueues changed keys.
on event (add/update/delete) from informer watch:
    enqueue(resource_key)

# Worker drains the work queue:
for resource_key in work_queue:
    resource = informer_cache.get(resource_key)
    if resource.status != desired:
        take_action(resource)
```

Examples:
- Deployment controller: ensures N replicas of pods.
- ReplicaSet controller: same, lower-level.
- Service controller: implements service endpoints.
- Endpoints controller: maintains list of pod IPs per service.

Custom controllers (Operators) extend this for any resource type.

### Scheduler

Watches for unscheduled pods. For each:
1. **Filtering**: which nodes can run this pod? Filters by resource requests, taints, affinity.
2. **Scoring**: rank candidate nodes. Considers spread, packing, etc.
3. **Binding**: assign pod to node.

Scheduling is a hard problem at scale; the binding step (write to the API server), not raw filtering, is typically the throughput limit, so sustained scheduling rate is well below the per-pod filter/score speed.

### Kubelet

Runs on each node. Watches for pods scheduled to itself; runs them.

Responsibilities:
- Pull container images.
- Start containers via CRI (Container Runtime Interface).
- Health probes (liveness, readiness, startup).
- Report status.
- Handle volume mounts.
- Execute pod lifecycle.

The kubelet is the "agent" on each node.

### Pods

A pod is the unit of scheduling and the smallest deployable unit. Contains one or more containers that:
- Share network namespace (same IP).
- Can share volumes.
- Are co-scheduled (always on same node).

Most pods are single-container. Multi-container patterns: sidecar (logging, proxy), init containers (run before main).

### Services and networking

Services give pods stable VIPs (Virtual IPs):
- ClusterIP: internal only.
- NodePort: exposed on each node's port.
- LoadBalancer: cloud LB (Load Balancer).
- Headless: no virtual IP; DNS only.

Service IPs are routed by `kube-proxy` (iptables, IPVS — IP Virtual Server, or eBPF — extended Berkeley Packet Filter) on each node.

DNS (Domain Name System): each service has a DNS name (`my-service.my-namespace.svc.cluster.local`). CoreDNS resolves.

### Storage

CSI (Container Storage Interface) abstracts storage.
- PVs (PersistentVolumes): backed by storage provisioners (cloud disk, NFS — Network File System, etc.).
- PVCs (PersistentVolumeClaims): pod's request for a PV.
- StorageClasses: templates for dynamic provisioning.

Stateful workloads use StatefulSets + PVCs.

### Ingress

L7 (Layer 7, application layer) routing into the cluster. Ingress objects describe routing rules; ingress controllers implement them (nginx, Traefik, Envoy, cloud-managed).

Modern alternative: Gateway API (more flexible).

### Network policies

Define which pods can talk to which. Implemented by CNI (Calico, Cilium, etc.).

Default: open. With network policies: deny by default; explicit allow rules.

### Authentication and authorization

- **Authentication**: who is the request from? (X.509, tokens, OIDC — OpenID Connect.)
- **Authorization**: what can they do? (RBAC — Role-Based Access Control — roles and bindings.)
- **Admission control**: should this request be allowed? (Validating/mutating webhooks.)

Multi-layer security; production clusters use all three.

### Custom Resource Definitions (CRDs)

Extend Kubernetes with new resource types:
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: databases.example.com
spec: ...
```

Combined with custom controllers (Operators), CRDs allow Kubernetes to manage anything: databases, message queues, ML (Machine Learning) pipelines.

### Operators

A pattern: CRD + controller = Operator. Encodes operational knowledge.

Examples:
- Database operators: CrunchyData Postgres, Strimzi Kafka.
- ML pipelines: Kubeflow.
- Infrastructure: cert-manager.

Operators are how Kubernetes extends to stateful and complex workloads.

### Helm

Package manager for Kubernetes. Helm charts bundle templates + defaults.

```
helm install my-app my-chart
```

Industry standard for sharing K8s configurations. Some teams replace with Kustomize, GitOps tools.

### Production challenges

**etcd performance.** Cluster state grows; etcd slows. Limits cluster size.

**API server load.** Watches don't scale infinitely. Custom controllers add load.

**Scheduling at scale.** Default scheduler handles thousands of pods; specialized schedulers for more.

**Network policies.** Complex to maintain; hard to debug.

**Resource sizing.** Pods OOMing (Out Of Memory) because requests/limits set wrong.

**Cost.** Idle nodes; oversized pods. FinOps (Financial Operations) for K8s is a discipline.

---

## Real Engineering Analogies 🟢

**The orchestra conductor.**
The conductor doesn't play instruments; they coordinate. Kubernetes doesn't run containers directly; it orchestrates kubelets that do. The conductor reads the score (declarative config); the musicians follow.

**The air traffic control tower.**
ATC (Air Traffic Control) doesn't fly planes; they direct. K8s doesn't run apps; it directs nodes. The flight plan is the deployment spec; the planes are pods; the airspace is the cluster.

---

## Production Engineering Perspective 🔴

What goes wrong:

- **The etcd outage.** etcd cluster fails; Kubernetes API stops responding. Cluster effectively down. Recovery: bring etcd back; sometimes lose state.
- **The API server thundering herd.** Watch reconnections after outage cause API server overload. Mitigation: rate limiting; staggered reconnects.
- **The scheduler overload.** Mass pod creation; scheduler can't keep up. Pods stuck Pending. Mitigation: scheduler tuning; horizontal API server scaling.
- **The bad config.** Deployment with wrong selector; existing pods orphaned. Fix: careful selectors; validation.
- **The cluster IP exhaustion.** Default pod CIDR (Classless Inter-Domain Routing) too small; new pods fail. Mitigation: larger CIDR; multiple subnets.
- **The PV reclaim policy.** PVCs deleted; storage retained or removed unexpectedly. Mitigation: explicit reclaim policies.
- **The OOMKilled cycle.** Pod limits too low; OOMKilled; restarted; fails again. Fix: tune limits.

The senior K8s operator's habits:
- **etcd health** as primary metric.
- **API server latency** monitoring.
- **Resource requests/limits** carefully.
- **RBAC** disciplined.
- **GitOps** for config.
- **Pod disruption budgets** for HA (High Availability).

---

## Failure Scenarios 🔴

**Scenario 1 — The etcd disk fill.**
etcd disk fills (revision history grows). Reads fine; writes fail. Cluster stuck. Recovery: compact etcd; defragment.

**Scenario 2 — The orphan pod cascade.**
Deployment selector changed; existing pods no longer matched; controller creates new ones; old persist. Manual cleanup needed.

**Scenario 3 — The scheduler starvation.**
Too few nodes; pods can't fit; stuck Pending. Add nodes or reduce pod requests.

**Scenario 4 — The network policy lockout.**
Strict default-deny network policy; pods can't communicate. Investigation: missing allow rules. Fix: add explicit allows.

**Scenario 5 — The Helm chart drift.**
Chart values diverge from cluster reality (manual kubectl edits). Helm upgrade reverts changes. Recovery: bring drift back into Helm or eliminate manual edits.

---

## Performance Perspective 🟡

- **API server latency**: typically <100ms; scales horizontally.
- **etcd write**: 5-50ms; latency-sensitive.
- **Scheduler decision**: typically ms.
- **Pod startup**: seconds (image pull dominates).

---

## Scaling Perspective 🟡

- **Single cluster**: 5,000-10,000 nodes; 100,000+ pods (with care).
- **Multi-cluster**: federation patterns; service mesh integration.
- **At hyperscale**: custom schedulers; sharded etcd; specialized API servers.

---

## Cross-Domain Connections 🟡

- **Consensus**: etcd uses Raft. (See [leader-election-and-consensus.md](../distributed-systems/leader-election-and-consensus.md).)
- **Service mesh**: extends K8s networking. (See [load-balancing-strategies.md](./load-balancing-strategies.md).)
- **Microservices**: K8s is the typical hosting. (See [microservices-vs-monolith.md](../architecture-patterns/microservices-vs-monolith.md).)
- **Cascading failures**: cluster failure modes. (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)
- **Observability**: K8s metrics, logs, events. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)

The unifying observation: **Kubernetes is a large distributed system with declarative semantics and eventual consistency. Its complexity is real; the operational discipline is non-trivial; the productivity benefits — once mastered — are substantial.**

---

## Real Production Scenarios 🟡

- **Google's Borg**: documented in 2015 paper.
- **Kubernetes at scale**: many public case studies (Spotify, Netflix, Reddit).
- **Argo CD**: GitOps standard.
- **Cilium / Calico CNI**: network policies in production.

---

## Key Takeaways

- **Declarative state, eventual consistency.** You declare desired state; controllers converge toward it. State change isn't instant — it's eventual. (Juniors miss that convergence takes time; seniors plan for it.)
- **The control plane is etcd + API server + controllers.** etcd holds the state and is the cluster's heart — when etcd is unhealthy, the cluster is effectively down. The API server is the central front door (everything goes through it); controllers drive convergence via reconciliation loops.
- **Pods are the unit of scheduling** — the smallest deployable unit, one or more containers sharing network/storage, ephemeral by design.
- **Services abstract pods.** Pods come and go; service IPs are stable. Selectors target pods by labels — getting selectors and labels right is critical (wrong selectors orphan pods).
- **Everything is an API resource** — pods, services, deployments, configmaps, ingresses — all accessed via the API server.
- **CRDs + controllers = Operators** extend Kubernetes to stateful and complex workloads (databases, queues, ML pipelines).
- **Resource requests/limits matter** — get them wrong and pods OOM or starve scheduling.
- **Network policies** secure pod-to-pod traffic (default open; deny-by-default with explicit allows).
- **GitOps** for config management; **monitor etcd health and API server latency** as primary operational signals; use **pod disruption budgets** and plan for cluster failures.

## Interview angle

- **"What's a pod?"** Smallest deployable unit; one or more containers sharing network and storage.
- **"What's etcd?"** The cluster's consensus-based (Raft) state store and source of truth.
- **"How does the scheduler work?"** Filter (which nodes can run it) + score (rank candidates) + bind (assign to node).
- **"What's a controller?"** A reconciliation loop: observe state, diff against desired, take corrective action.
- **"What's an Operator?"** A CRD plus a custom controller that encodes operational knowledge.
- Common traps: treating K8s as an opaque deploy tool; not understanding declarative-vs-imperative.
