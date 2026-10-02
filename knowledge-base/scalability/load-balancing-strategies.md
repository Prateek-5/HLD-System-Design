# Load Balancing Strategies

> *"Load balancing is the art of pretending you have one big computer when you actually have many small ones. The art is mostly in noticing when the pretense leaks — which is always at the worst moment."*

---

## Topic Overview

Load balancing is what makes horizontal scale work. The instant you have more than one instance of a service, somebody — a piece of hardware, a piece of software, a piece of DNS configuration — is deciding which instance handles each request. That decision has consequences for latency, fairness, failure isolation, cache efficiency, session continuity, and operational complexity.

The naive answer is "round robin" — alternate requests across instances. It works until it doesn't: hot keys land on slow instances, sticky sessions fight against rebalancing, slow downstream calls cascade through fast frontends, and the simple uniform distribution turns out to be neither uniform nor effective.

Modern load balancing is a pipeline of decisions: at the DNS layer, at the network layer (L4), at the application layer (L7), at the service mesh, sometimes inside the application itself. Each layer has different tradeoffs around latency, observability, and routing intelligence. Understanding the full stack is the difference between "we have a load balancer" and "we have load balancing as a designed property of the system."

---

## Intuition Before Definitions

Imagine an airport with multiple check-in counters.

**Round robin.** People queue in arrival order; each goes to the next available counter. Simple. Fair. Doesn't notice that one passenger has 14 bags and is taking 20 minutes while everyone else takes 2.

**Least busy.** A staff member directs each passenger to the counter with the shortest queue. Better — adapts to actual load. But requires the staff member to monitor every queue continuously, and to make a decision per passenger.

**By passenger type.** Status passengers go to one set of counters; regular passengers to another. Frequent flyers get faster service; non-frequent passengers wait longer. Specializes the workload at the cost of utilization (idle premium counters during off-peak).

**By hash of last name.** A→F to counter 1, G→M to counter 2, etc. Predictable; some passengers always go to the same counter (helpful if the counter "remembers" them — sticky sessions). But uneven distribution if names cluster.

**By geographic origin.** International arrivals to one set; domestic to another. Co-locates expertise. But empty counters when one segment is light.

Real airports use combinations. Real load balancers do too. The strategy is downstream of the workload's properties: are requests uniform or skewed? Is "memory" of past requests useful? Are failures localized or correlated? Is fairness explicit?

There is no universally best algorithm. There are workload-fitness questions and tradeoffs.

---

## Historical Evolution

**Era 1 — DNS round robin.**
1990s. The first load balancers were DNS records returning multiple A records. Clients picked one (usually the first). No health checking, no failover, slow propagation. Worked surprisingly well for static content; inadequate for anything dynamic.

**Era 2 — Hardware load balancers.**
F5, Cisco, Citrix Netscaler. Dedicated appliances doing L4/L7 routing in custom silicon. Fast, expensive, opaque. Dominated the 2000s. Still common in enterprise.

**Era 3 — Software load balancers.**
HAProxy (2001), nginx (2004). Free, programmable, cloud-friendly. Replaced hardware in many shops. The era of "load balancer is just another server" arrived.

**Era 4 — Cloud and managed LBs.**
AWS ELB (2009) → ALB/NLB. GCP Cloud Load Balancing. Managed services with auto-scaling, health checks, integration with cloud networks. The infrastructure layer becomes elastic.

**Era 5 — Service mesh.**
Linkerd (2016), Envoy (2016), Istio (2017). Load balancing pushed into a sidecar proxy alongside every application. Per-call decisions, request-level retries, fine-grained policies. Operational complexity multiplied; visibility multiplied too.

**Era 6 — Adaptive and learning.**
Modern systems use adaptive algorithms (least latency with EWMA), client-side load balancing (gRPC's pick_first, round_robin, custom), and policy-driven routing. The distinction between "load balancer" and "service infrastructure" is increasingly meaningless.

The pattern: each generation moved the routing decision closer to the request. From DNS (slow, coarse) to hardware (fast, central) to software (flexible) to per-service mesh (per-request, contextual). The trend is increasingly fine-grained and intelligent.

---

## Core Mental Models

**1. Load balancing happens at multiple layers.**
DNS, L4 (TCP/UDP), L7 (HTTP), service mesh, client-side. Each layer adds capability and overhead. Modern stacks use several in series.

**2. The "right" algorithm depends on workload shape.**
Uniform requests → round robin or least connections. Skewed requests → least latency or least busy. Cacheable requests → consistent hashing. Long-lived connections → sticky sessions. There is no universal best.

**3. Health checks determine availability.**
The load balancer's job is to *not* send traffic to dead or degraded instances. Health checks must be accurate (true positives/negatives), low-latency, and not themselves cascade failures.

**4. Slow is worse than down.**
A failed instance fails fast; the load balancer routes around it. A *slow* instance still responds, accumulates queues, and degrades the requests routed to it. Sophisticated load balancers detect slowness and shed traffic before timeout.

**5. Connection state shapes the strategy.**
Stateless requests can go anywhere. Stateful (sticky-session, cache-warmed, connection-pooled) requests have penalties for switching servers. Acknowledge this in design or accept the cost.

---

## Deep Technical Explanation

### L4 vs L7 load balancing

**L4 (Layer 4, TCP/UDP):**
- Routes by IP and port. No application-layer awareness.
- Very fast (kernel-level on modern systems; XDP, eBPF).
- Cannot inspect HTTP path, headers, or body.
- Used for raw TCP services, databases, anything not HTTP.

**L7 (Layer 7, HTTP):**
- Routes by HTTP method, path, headers, query parameters.
- Can do path-based routing (`/api/v1` → service A, `/api/v2` → service B).
- Can inspect, modify, or terminate TLS.
- Slower than L4 (parses HTTP); typically still microseconds.

Modern load balancers often do both: L4 for TCP termination, L7 for HTTP routing. AWS ALB is L7; NLB is L4.

### Algorithms

**Round Robin.**
Each instance gets the next request in sequence. Simple, predictable. Bad if requests have varying cost.

**Weighted Round Robin.**
Instances have weights; bigger instances get more traffic. Useful for heterogeneous fleets.

**Random.**
Pick any instance uniformly. Surprisingly close to round robin in distribution; simpler to implement.

**Least Connections.**
Pick the instance with the fewest active connections. Good for long-lived connections (databases, websockets). Less effective for short HTTP requests where connections are reused.

**Least Latency / Least Response Time.**
Pick the instance with lowest recent response time. Adaptive — automatically routes around slow instances. Implementation: exponentially-weighted moving average (EWMA) per instance.

**Power of Two Choices (P2C).**
Pick two instances at random; pick the less-loaded one. Surprisingly effective: nearly optimal load distribution with minimal coordination. Default in many modern load balancers.

**Consistent Hashing.**
Hash the request (by URL, header, or key) to a position on a ring; route to the closest instance clockwise. Same key always goes to same instance — cache-friendly. Adding/removing instances moves only ~1/N of keys.

**Maglev Hashing.**
Google's variant of consistent hashing with even better distribution and minimal disruption. Used in many CDN and load balancer implementations.

### Health checks

Two layers:

**Active health checks.** Load balancer probes each instance periodically. `GET /health`, expects 200. If consecutive failures exceed threshold, instance is removed from the pool.

**Passive health checks.** Load balancer monitors actual traffic. If real requests to an instance fail at high rate, instance is removed.

Best practice: combine both. Active alone has low false positives but slow detection; passive alone may not detect a "no-traffic-to-it-yet" sick instance.

Anti-patterns:
- **Health checks that hit dependencies.** A health check that calls the database means a database blip removes all instances. Health checks should reflect *this instance's* health, not its dependencies'.
- **Health checks that always pass.** A health check returning 200 if the process is alive — but the process is locked up serving traffic. Real health checks should reflect serving capacity.
- **Health check intervals too long.** A failed instance receiving traffic for 30s before health-check detects it = 30s of failed requests.

### Sticky sessions

When the application keeps per-session state in memory (or in a local cache), routing the same session to the same instance is much faster.

Mechanisms:
- **Cookie-based**: load balancer sets a cookie pointing to the instance.
- **IP-based**: hash client IP. Breaks behind shared NATs.
- **Header-based**: load balancer reads a session ID and routes accordingly.

Costs:
- **Imbalance.** A "popular" session pins traffic to one instance.
- **Failover difficulty.** When the sticky instance fails, the session loses state.
- **Rebalancing costs.** Adding new instances doesn't help existing sessions.

Modern best practice: avoid sticky sessions where possible. Push session state to a fast external store (Redis); make all instances stateless.

### Client-side load balancing

In gRPC, the client itself maintains a list of instances and picks one per request. Properties:
- **No middlebox latency.**
- **Per-call decisions** without coordination.
- **Health awareness** via gRPC's built-in mechanisms.
- **Customizable** via pickers (round_robin, pick_first, custom).

Tradeoffs: clients must know about instances (typically via service discovery: Consul, etcd, Kubernetes DNS). Each client has its own view; coordination is implicit.

### Service mesh load balancing

Service mesh sidecars (Envoy in Istio, Linkerd's proxy) do L7 load balancing per-request:
- **Per-call routing**: round robin, P2C, EWMA-based, customizable.
- **Retries** with budgets.
- **Circuit breakers**.
- **Outlier detection**: sidecars notice slow/failing instances and eject them temporarily.
- **Locality-aware**: prefer same-zone instances to minimize latency.

This is where modern load balancing happens for internal traffic. The application sees a local proxy; the proxy makes intelligent decisions.

### Locality-aware routing

In multi-zone or multi-region deployments, network latency varies by topology. Cross-zone calls within a region: ~1ms. Cross-region: 50–200ms.

Locality strategies:
- **Same-zone preference.** Route to local instances when possible; failover to other zones.
- **Topology hints** (Kubernetes' `topology.kubernetes.io/zone` labels).
- **Weighted routing** giving local instances higher weight.

The benefit: lower latency, lower cross-zone bandwidth costs (cloud charges per byte).
The risk: loss of resilience if local zone has fewer instances than failover capacity required.

### Connection management

L7 load balancers maintain connection pools to backends. Tuning matters:
- **Max connections per backend.** Too low: requests queue. Too high: backend can be overwhelmed.
- **Connection idle timeouts.** Too short: connections recycle constantly. Too long: stale connections cause errors.
- **Keep-alive settings.** Longer keep-alive reduces TCP handshake overhead.
- **HTTP/2 multiplexing.** One connection per backend can carry many concurrent requests; reduces connection count.

The TCP RST storm is a classic failure: tens of thousands of concurrent reconnections after a load balancer restart, each triggering kernel-level handshake costs.

### TLS termination

Where TLS is decrypted shapes the architecture:
- **At the load balancer.** Backends speak plain HTTP. Simple. Less secure (cleartext between LB and backend).
- **At the backend.** End-to-end encryption. Backends do TLS work. Higher CPU.
- **Re-encrypted at the LB.** Decrypt for inspection, re-encrypt to backend. Most secure; more CPU.

Modern best practice: terminate at the LB for external traffic, but use mTLS internally (service mesh) for service-to-service.

---

## Real Engineering Analogies

**The hospital triage nurse.**
Patients arrive at the ER. The triage nurse decides who goes to which doctor. They consider:
- Severity (priority routing).
- Doctor specialties (path-based routing).
- Doctor availability (least-busy).
- Continuity of care if returning (sticky sessions).
- The nurse must also notice when a doctor is overwhelmed and route around them.

A bad triage nurse sends everyone to the closest door. A good one balances throughput, quality, and patient outcomes — the same metrics a good load balancer tracks.

**The grocery store checkout coordinator.**
On busy days, a person stands at the front of the checkout area directing shoppers: "Lane 4 is open, ma'am." They watch all the lanes, notice when one is slow, redirect future shoppers. They don't move shoppers already in line — that would cause chaos. The "stickiness" of being in a lane is intentional; switching costs are real.

This is exactly L7 load balancing with sticky sessions: route new arrivals intelligently, leave existing flows undisturbed.

---

## Production Engineering Perspective

What goes wrong:

- **The cascading health check.** A bad health check probes the database. Database has a hiccup. *All* instances fail health checks. Load balancer marks them all unhealthy. Service is "down" while every backend is fine.
- **The slow-instance amplifier.** Round-robin sends 1/N of traffic to a slow instance. The slow instance accumulates a queue; latencies grow. Without smart routing, this percentage of requests is degraded indefinitely.
- **The sticky session failover.** Customer's session is sticky to instance A. A goes down. Customer must re-authenticate, lose cart, start over. Mitigation: external session storage.
- **The uneven load from consistent hashing.** A "celebrity" key (hot key) hashes to one instance. That instance is overwhelmed; others are idle. Mitigation: bucket the hot key across multiple positions on the ring.
- **The connection pool thrash.** Load balancer restarts; all connections drop; backends see massive reconnection storm. CPU spikes; TCP handshake overhead for thousands of connections.
- **The TLS termination CPU pin.** A small backend serving TLS traffic at the LB has CPU usage 80% on TLS alone. Move termination to dedicated proxies or use hardware TLS offload.
- **The health-check race.** Newly-deployed instance starts; LB sends traffic before warm-up is complete. First requests fail. Mitigation: a "ready" probe distinct from "alive" probe (Kubernetes' liveness vs readiness pattern).
- **The DNS TTL trap.** Old DNS responses cached in clients for hours. New backend deployed; clients still hit old IPs. Mitigation: short TTLs; service discovery instead of DNS for dynamic systems.

The senior operator's habits:
- **Layer health checks**: liveness (process alive), readiness (can serve), deep (deeper integration).
- **Use P2C or least-latency** by default — better than round robin for variable workloads.
- **Avoid sticky sessions** unless externally-stored sessions aren't an option.
- **Locality-aware routing** in multi-zone deployments.
- **Monitor distribution**, not just aggregate request rate. P99 of *least-loaded* and *most-loaded* instances should be close.
- **Rate limit at the LB** to protect backends from upstream surges.
- **Connection draining on shutdown** — let in-flight requests finish before terminating instances.

---

## Failure Scenarios

**Scenario 1 — The health check that took down everything.**
Health endpoint hit `SELECT 1` against the database. DB had brief unavailability. Health checks failed across all instances. LB marked all instances unhealthy. Site appeared down for 90 seconds while DB recovered.

**Scenario 2 — The slow-instance death spiral.**
One instance has a slow disk. Round-robin sends it 1/10 of traffic. Latency on that instance is 5s vs others' 50ms. Affected users see slow responses but health checks pass (slow ≠ dead). Smart LB with EWMA-based routing would have detected slowness and reduced traffic; round robin doesn't.

**Scenario 3 — The thundering reconnect after restart.**
LB instance restart drops 50K open connections. All clients reconnect immediately. TCP handshake CPU spike on backends. Health checks fail momentarily. Cascading restart attempts. Mitigation: connection draining; staggered restarts.

**Scenario 4 — The hot-key consistent-hashing nightmare.**
A consistent hash routed by user ID. A celebrity user generates 50% of traffic. One instance handles all of it; others are idle. Mitigation: detect hot keys; route them via bucketing across multiple ring positions.

**Scenario 5 — The DNS-based failover that didn't.**
Multi-region active-active behind DNS. Region 1 fails. DNS TTL is 5 minutes. Clients with cached DNS hit failed region for 5 minutes. Mitigation: shorter TTLs (cost: more DNS queries); use Anycast IP for instant failover.

---

## Performance Perspective

- **L4 LB**: microsecond overhead; near-line-rate throughput on modern hardware.
- **L7 LB**: tens of microseconds per request; HTTP parsing cost.
- **TLS termination**: CPU-intensive; can dominate small backends if not isolated.
- **Connection establishment** (TCP + TLS handshake) is expensive. Pool aggressively.
- **HTTP/2 multiplexing** reduces connection counts but doesn't help with backend processing time.
- **Locality-aware routing** can cut p50 by 5-10ms in multi-zone deployments.

---

## Scaling Perspective

- **Vertical**: bigger LB instances; or hardware (for L4) for tens of millions of requests/second.
- **Horizontal**: multiple LB instances behind DNS or Anycast IP.
- **Geographic**: regional LBs; global routing via Anycast or geo-DNS.
- **Cell-based**: each cell has its own LB; cross-cell traffic is exceptional.
- **At hyperscale**: custom load balancers (Google's Maglev, Facebook's Katran). Off-the-shelf options aren't fast enough.

---

## Cross-Domain Connections

- **Sharding**: consistent hashing in load balancing is the same algorithm as in databases. (See [sharding-and-partitioning-strategies.md](./sharding-and-partitioning-strategies.md).)
- **Caching**: edge caches (CDNs) are load balancers with caching. The same algorithms with content-aware routing. (See [caching-hierarchy.md](../caching/caching-hierarchy.md).)
- **Cascading failures**: bad health checks cause cascades; smart routing contains them. (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)
- **Backpressure**: rate limiting at the LB is a primary backpressure mechanism. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Observability**: per-instance metrics from the LB are critical for detecting hot spots. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)
- **API design**: API gateway is a specialized L7 load balancer. (See [api-design-rest-vs-grpc.md](../architecture-patterns/api-design-rest-vs-grpc.md).)

The unifying observation: **load balancing is the visible face of distribution.** Every other distributed-systems decision (sharding, replication, sagas) is invisible to clients; the load balancer's choices are felt directly.

---

## Real Production Scenarios

- **Google's Maglev**: high-performance L4 LB. Public paper details consistent hashing algorithm and packet-level performance optimizations.
- **Facebook's Katran**: XDP-based L4 LB. Pushes packet processing into the kernel for line-rate performance.
- **Netflix's Zuul**: Java-based gateway with extensive customization. Public engineering posts on adaptive routing and resilience.
- **Envoy at scale**: powers Lyft, Stripe, many cloud-native architectures. Service mesh foundation (Istio, Consul Connect).
- **Cloudflare's anycast network**: load balancing at the global routing layer, not application layer.
- **The 2017 Cloudflare outage**: cascading effects of a bug in load balancer regex handling. Postmortem details how a single LB rule can take down a global service.

---

## What Junior Engineers Usually Miss

- That **round robin is rarely best** at scale.
- That **health checks must reflect serving capacity**, not just process aliveness.
- That **slow instances are worse than dead ones** for round robin.
- That **sticky sessions multiply failure impact**.
- That **DNS TTL matters** for failover speed.
- That **hot keys break consistent hashing**.
- That **connection draining** matters for graceful shutdown.
- That **TLS termination is CPU-heavy**.

---

## What Senior Engineers Instinctively Notice

- They **monitor per-instance distribution**, not just aggregate.
- They **distinguish liveness from readiness**.
- They **avoid sticky sessions** when possible.
- They **prefer P2C or least-latency** to round robin.
- They **plan for hot keys** in consistent hashing.
- They **use locality-aware routing** in multi-zone setups.
- They **drain connections** on graceful shutdown.
- They **rate-limit at the edge** to protect backends.

---

## Interview Perspective

What gets tested:

1. **"Round robin vs least connections vs P2C — when each?"** Tests algorithmic awareness.
2. **"How do you health-check?"** Layered: liveness, readiness, deep checks. Avoid checks that depend on shared resources.
3. **"What's consistent hashing?"** Hash to ring; closest node clockwise. Adding nodes moves only 1/N keys. Bonus for explaining hot-key mitigations.
4. **"Sticky sessions — when to use?"** Answer: rarely; prefer external session stores. Tests practical judgment.
5. **"How do you do failover?"** Health checks, connection draining, possibly Anycast.
6. **"Where does TLS terminate?"** At the LB for external; mTLS internally for service-to-service.
7. **"How would you load-balance gRPC traffic?"** Client-side load balancing or service mesh; gRPC's HTTP/2 multiplexing breaks naive L4 LBs.

Common traps:
- Treating load balancing as "just round robin."
- Health checks that probe dependencies.
- Believing sticky sessions are free.
- Not knowing about gRPC's specific LB challenges.

---

## 20% Knowledge Giving 80% Understanding

1. **L4 = TCP/IP routing**; **L7 = HTTP-aware**.
2. **Round robin is the baseline**; P2C or least-latency adapts to variability.
3. **Consistent hashing** for cache-friendly routing.
4. **Health checks must not depend on shared resources**.
5. **Sticky sessions multiply failure pain**. Avoid where possible.
6. **Connection draining** on shutdown.
7. **TLS termination** is a CPU cost — isolate it.
8. **Locality-aware routing** in multi-zone deployments.
9. **Service meshes** push LB to per-call decisions.
10. **Monitor per-instance distribution**, not just totals.

---

## Final Mental Model

> **A load balancer is a continuous decision-making process about where work should go. The naive version makes one rule and applies it forever. The mature version watches the system, notices what's working, and adapts. The skill is in choosing what signals to trust — and what to ignore.**

The senior architect, designing load balancing, asks: *what's the workload? what's the failure model? what's the latency budget? what state do servers carry?* The answers shape the strategy. There's no universal best — only "what fits this system" and "what's the cost of the wrong choice."

The systems that scale gracefully are the ones with thoughtful load balancing layered through DNS, network, application, and mesh — each making decisions appropriate to its scope. The systems that struggle are the ones with one round-robin rule and the silent assumption that all instances are equivalent. Reality is rarely that uniform.

That's load balancing. That's the layer that turns "many machines" into "one service." That's the part of the system the user never sees — until it stops working, and they suddenly see it everywhere.
