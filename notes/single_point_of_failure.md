# Single Points of Failure (SPOF)

> **📎 Prereqs** — If rusty:
> - [`learn/foundations/scaling/availability.md`](../learn/foundations/scaling/availability.md) — series vs parallel math.
> - [`database_replication.md`](database_replication.md) — DB failover.
> - [`load_balancing.md`](load_balancing.md) — front-door redundancy.

### 🔹 1. What This Topic Actually Is
Any component whose failure takes down the whole system. Removing SPOFs is the core of HA design.

### 🔹 2. Why It Exists
- You cannot achieve 99.9%+ with SPOFs in the critical path.
- Identifying SPOFs is literally "drawing arrows and asking: what if this dies?"

### 🔹 3. Core Concepts (High Signal)
- **Active-passive**: secondary takes over on failure. Simple but passive = wasted.
- **Active-active**: all nodes serve; redundancy + throughput.
- **Multi-AZ**: 2+ AZs inside a region; survives AZ outage.
- **Multi-region**: survives region outage; heavy lift (data sync, DNS, compliance).
- **DNS as SPOF**: low TTL + multiple NS + anycast to mitigate.
- **Human SPOF**: one engineer knows everything → documentation, runbooks, on-call rotation.
- **Netflix active-active blog** is the canonical reference.

### 🔹 4. Internal Working
Identify SPOFs by drawing request path, then ask each component: what's my replacement strategy?
For each: health check → detection → failover → rejoin.
Redundancy can be in **series** (bad: multiplies failure) or **parallel** (good: divides it).

### 🔹 5. Key Tradeoffs
- Active-active: max availability, needs careful data sync.
- Active-passive: cheap-ish, but passive instance must actually work when asked.
- Multi-region doubles or triples cost and complexity; needed only at specific SLOs.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. Define SPOF.
2. Active-active vs active-passive?

**Intermediate 🟡**
1. Draw an architecture and identify all SPOFs.
2. What does multi-AZ buy you? Multi-region?

**Advanced 🔴**
1. Design active-active multi-region for a writes-heavy service. (CRDTs or primary-per-region)
2. What's the cost/complexity of 4-nines vs 5-nines availability?

### 🔹 7. Real System Mapping
- **Netflix active-active multi-regional** (famous blog).
- **DNS GSLB** (Shopify, others).
- **Oracle reference** on DB HA patterns.

### 🔹 8. What Most People Miss
- **Ops SPOFs**: the deploy system, the IAM service, the CA — if any of these fail, recovery is impossible.
- **Cascading failure**: removing a SPOF sometimes just moves the failure to another node. Run load tests on the failover target first.
- **DNS failover is slow** (TTL-bound) — not a primary HA mechanism; use LB/anycast for fast failover.
- **Don't forget logs + metrics**: during an outage, if your observability is also down, you're blind.

### 🔹 9. 30-Second Revision
Walk the request path; every arrow is a suspect. Remove SPOFs via active-active + multi-AZ + multi-region (for top SLOs). DNS failover is slow — use anycast/LB failover. Ops SPOFs (deploy, CA, IAM) matter as much as infra ones.

---

## 🔗 Cross-Topic Connections
- **Load Balancing**: makes stateless tier redundant.
- **Replication**: removes DB SPOF.
- **Messaging**: broker clusters vs single broker.
- **CDN**: removes origin SPOF for reads.

---

### Confidence Check
- [ ] Can I spot SPOFs on any architecture diagram in 60s?
- [ ] Can I defend multi-AZ vs multi-region for a given SLO?

### Gaps
- Detailed DR playbooks.
- Quorum-based DB strategies.
