# VMs and Containers — Two Flavors of Isolation

## A. Intuition First
Both isolate workloads. VMs isolate at the hardware level (via hypervisor); containers at the OS level (via namespaces + cgroups). Containers are much lighter but share the host kernel.

## B. Mental Model
| | VM | Container |
|---|---|---|
| Isolation | Strong (own kernel) | Shared kernel |
| Start time | Minutes | Seconds |
| Size | GBs | MBs |
| Density | Dozens/host | Hundreds/host |
| Security | Stronger boundary | Weaker (kernel shared) |

## C. Internal Working
- **Hypervisor** (Type 1: KVM, Xen; Type 2: VirtualBox) — runs multiple VMs, each with own OS kernel.
- **Container runtime** (Docker → containerd → runc) — uses Linux **namespaces** (process, network, mount, PID, user) and **cgroups** (resource caps).
- Container image = layered filesystem + metadata; runs as isolated process group.

## D. Visual Representation
```
VMs:
  Host OS → [Hypervisor] → [Guest OS kernel + app]...

Containers:
  Host OS kernel ──── [Runtime] → [Container proc] [Container proc]...
```

## E. Tradeoffs
- VMs: strong isolation, slower start, OS per VM = waste for lots of apps.
- Containers: fast, dense, but shared kernel = weaker security boundary; kernel exploit escapes.
- Hybrid: **Firecracker**/AWS Lambda-style microVMs give container-like density with VM-like isolation.

## F. Interview Lens
- "VM vs container?" — see table.
- "Why Kubernetes?" — orchestration at container scale.
- Pitfalls: treating containers as fully isolated (kernel panics, CPU noisy neighbors).

## G. Real-World Mapping
Docker, Kubernetes, AWS Fargate, GCP Cloud Run, Firecracker (AWS Lambda).

## H. Questions
**Beginner**: What's a container?
**Intermediate**: namespaces vs cgroups?
**Advanced**: Compare Kubernetes vs VMs for multi-tenant isolation.

## I. Mini Design
SaaS platform with customer workloads: use containers per tenant for speed, but run each tenant in a separate Firecracker microVM if hard isolation is required.

## J. Cross-Topic Connections
- [Clustering](../foundations/scaling/clustering.md), [Service Discovery](service-discovery.md), [Scalability](../foundations/scaling/scalability.md).

## K. Confidence Checklist
- [ ] Knows VM vs container tradeoffs.
- [ ] Knows namespaces + cgroups.

## L. Potential Gaps & Improvements
- Kubernetes pod networking (CNI).
- Image security / supply chain.
