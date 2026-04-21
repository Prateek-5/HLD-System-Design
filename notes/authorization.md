# Authorization

> **📎 Prereqs** — If rusty:
> - [`learn/reliability/oauth-oidc.md`](../learn/reliability/oauth-oidc.md) — authn vs authz.
> - [`learn/reliability/sso.md`](../learn/reliability/sso.md) — identity providers.
> - RBAC vs ABAC conceptual difference.

### 🔹 1. What This Topic Actually Is
Who can do what on which resource. Distinct from authentication (who are you). Models: RBAC, ABAC, ReBAC (relationship-based), policy-as-code.

### 🔹 2. Why It Exists
- Every multi-tenant or privileged system needs consistent, auditable access decisions.
- Naive if-branches scatter auth logic across codebase → bugs + compliance risk.

### 🔹 3. Core Concepts (High Signal)
- **RBAC (Role-Based)**: users → roles → permissions. Simple, scales to moderate complexity.
- **ABAC (Attribute-Based)**: rules over attributes (time, department, resource tags).
- **ReBAC (Relationship-Based)**: "can access if owner or shared with or member of group". Google's Zanzibar is the canonical implementation — the model behind Google Docs/Drive sharing.
- **Policy-as-code**: OPA (Open Policy Agent), Cerbos — decouple policy from app.
- **Centralized vs embedded**: centralized policy engine vs inline checks. Zanzibar sits in a middle "centralized check service with low-latency reads".
- **Consistency**: auth checks must be fresh ("New Enemy" problem — revoked access still working because of caching).

### 🔹 4. Internal Working (Zanzibar-like)
- Relations stored as tuples: `(object#relation@subject)`, e.g., `doc:123#viewer@user:alice`.
- Policy defines composition (viewer ← editor ← owner).
- Check API: "can user X do action Y on resource Z?" → evaluated via relation traversal + caching.
- Snapshot reads for staleness control.

**Failure points:** cache staleness → revoked access still working; complex policies → slow checks; relationship graphs that explode.

### 🔹 5. Key Tradeoffs
- RBAC: easy, limited expressiveness.
- ABAC: expressive, hard to audit.
- ReBAC: best for sharing/permission graphs (Docs, Drive).
- Centralized: consistent, SPOF risk.
- Embedded: fast, scatter risk.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. Authn vs authz?
2. RBAC vs ABAC?

**Intermediate 🟡**
1. Why ReBAC for Google Docs sharing?
2. What's the "new enemy" problem in auth?

**Advanced 🔴**
1. Design auth for a multi-tenant SaaS with 10M rules.
2. Implement Zanzibar-like check service.

### 🔹 7. Real System Mapping
- **Google Zanzibar**: paper; powers Docs/Drive/Cloud IAM.
- **AWS IAM**: JSON policies over users + roles + resources.
- **OPA (Open Policy Agent)**: de-facto policy-as-code; used by k8s, Envoy.
- **Cerbos, Aserto**: modern ReBAC engines.

### 🔹 8. What Most People Miss
- **Performance matters** — auth checks on hot paths must be <ms. Caching is critical, consistency is critical; Zanzibar's Zookies solve the staleness-vs-speed tradeoff.
- **Audit logs** for every allow/deny — compliance.
- **Delegated authz** (grant X permission to act as Y) needs careful audit.
- **Attribute explosion**: too many attributes makes policies unreadable + slow.

### 🔹 9. 30-Second Revision
RBAC for simple orgs, ReBAC (Zanzibar) for sharing-heavy products, OPA for policy-as-code. Centralized check service with caching + consistency tokens. Every decision logged for audit. "New enemy" = stale cache serving revoked access.

---

## 🔗 Cross-Topic Connections
- **OAuth/OIDC**: provides identity (authn) → authz decides access.
- **API Gateway**: often the first authz checkpoint.
- **Caching**: authz decisions must be carefully cached.

---

### Confidence Check
- [ ] Can I pick RBAC vs ABAC vs ReBAC per problem?
- [ ] Can I articulate the caching/consistency tradeoff?

### Gaps
- Zanzibar Zookie internals.
- SCIM provisioning.
