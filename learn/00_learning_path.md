# 📘 System Design Learning Path — The Pipeline

> You are here because you want to pass system design interviews and actually *understand* what you are saying when you do. This path is built for that.

## How to use this

Read this file first. Then read topics **in order**. Every topic is a single `.md` file structured identically:

1. **Intuition First** — the real-world analogy, in plain English
2. **Mental Model** — first principles; why this thing had to exist
3. **Internal Working** — packet/request-level step-through
4. **Visual Representation** — ASCII diagram + pointer to the Excalidraw
5. **Tradeoffs** — alternatives, limits, breakage modes
6. **Interview Lens** — what interviewers probe, common pitfalls
7. **Real-World Mapping** — where Netflix / Uber / WhatsApp / AWS actually use this
8. **Questions** — beginner → intermediate → advanced interview
9. **Mini Design Problem** — a small-scale version of the concept
10. **Cross-Topic Connections** — how this links to other topics
11. **Confidence Checklist** — red flags that mean you should re-read
12. **Potential Gaps & Improvements** — what *this file* still does not cover

If any of those sections feels too fast, **slow down, do not skip**. The whole thing is built so that a concept introduced later never assumes you silently understood something earlier.

---

## The five layers (and why they are in this order)

### Layer 1 — Foundations: Networking
You cannot reason about distributed systems if you do not know what a packet, a port, a TCP handshake, and a DNS lookup actually *are*. Every later topic quietly assumes you know this.

- [`foundations/networking/ip.md`](foundations/networking/ip.md) — what an address is and why we need one
- [`foundations/networking/osi.md`](foundations/networking/osi.md) — the mental scaffolding for every network debate
- [`foundations/networking/tcp-udp.md`](foundations/networking/tcp-udp.md) — reliability vs speed, handshake vs fire-and-forget
- [`foundations/networking/dns.md`](foundations/networking/dns.md) — the world's largest distributed key-value store
- [`foundations/networking/proxy.md`](foundations/networking/proxy.md) — forward vs reverse, and why the reverse one is everywhere

### Layer 2 — Foundations: Scaling & Availability
Now you have packets arriving. The question becomes: *how do I keep the system up and fast when traffic 100×?*

- [`foundations/scaling/load-balancing.md`](foundations/scaling/load-balancing.md) — horizontal scaling's entry point
- [`foundations/scaling/clustering.md`](foundations/scaling/clustering.md) — a group of servers pretending to be one
- [`foundations/scaling/caching.md`](foundations/scaling/caching.md) — the single biggest performance lever in any system
- [`foundations/scaling/cdn.md`](foundations/scaling/cdn.md) — cache at the edge of the planet
- [`foundations/scaling/availability.md`](foundations/scaling/availability.md) — what "five nines" actually means
- [`foundations/scaling/scalability.md`](foundations/scaling/scalability.md) — vertical vs horizontal, and when each breaks
- [`foundations/scaling/storage.md`](foundations/scaling/storage.md) — block vs file vs object, RAID, NAS vs SAN

### Layer 3 — The Data Layer
Every serious system design question becomes "where do I put the data and how do I keep it consistent?" This layer teaches you how to answer.

- [`data/db-and-dbms.md`](data/db-and-dbms.md)
- [`data/sql-databases.md`](data/sql-databases.md)
- [`data/nosql-databases.md`](data/nosql-databases.md)
- [`data/sql-vs-nosql.md`](data/sql-vs-nosql.md)
- [`data/database-replication.md`](data/database-replication.md)
- [`data/indexes.md`](data/indexes.md)
- [`data/normalization-denormalization.md`](data/normalization-denormalization.md)
- [`data/acid-base.md`](data/acid-base.md)
- [`data/cap-theorem.md`](data/cap-theorem.md)
- [`data/pacelc-theorem.md`](data/pacelc-theorem.md)
- [`data/transactions.md`](data/transactions.md)
- [`data/distributed-transactions.md`](data/distributed-transactions.md)
- [`data/sharding.md`](data/sharding.md)
- [`data/consistent-hashing.md`](data/consistent-hashing.md)
- [`data/database-federation.md`](data/database-federation.md)

### Layer 4 — Architecture
You have network and data. Now: *how do services talk to each other?*

- [`architecture/n-tier-architecture.md`](architecture/n-tier-architecture.md)
- [`architecture/message-brokers.md`](architecture/message-brokers.md)
- [`architecture/message-queues.md`](architecture/message-queues.md)
- [`architecture/pub-sub.md`](architecture/pub-sub.md)
- [`architecture/enterprise-service-bus.md`](architecture/enterprise-service-bus.md)
- [`architecture/monolith-vs-microservices.md`](architecture/monolith-vs-microservices.md)
- [`architecture/event-driven-architecture.md`](architecture/event-driven-architecture.md)
- [`architecture/event-sourcing.md`](architecture/event-sourcing.md)
- [`architecture/cqrs.md`](architecture/cqrs.md)
- [`architecture/api-gateway.md`](architecture/api-gateway.md)
- [`architecture/rest-graphql-grpc.md`](architecture/rest-graphql-grpc.md)
- [`architecture/long-polling-websockets-sse.md`](architecture/long-polling-websockets-sse.md)

### Layer 5 — Advanced Reliability & Security
Interview gold. These are the topics that separate juniors from seniors.

- [`reliability/geohashing-quadtrees.md`](reliability/geohashing-quadtrees.md)
- [`reliability/circuit-breaker.md`](reliability/circuit-breaker.md)
- [`reliability/rate-limiting.md`](reliability/rate-limiting.md)
- [`reliability/service-discovery.md`](reliability/service-discovery.md)
- [`reliability/sla-slo-sli.md`](reliability/sla-slo-sli.md)
- [`reliability/disaster-recovery.md`](reliability/disaster-recovery.md)
- [`reliability/vms-and-containers.md`](reliability/vms-and-containers.md)
- [`reliability/oauth-oidc.md`](reliability/oauth-oidc.md)
- [`reliability/sso.md`](reliability/sso.md)
- [`reliability/ssl-tls-mtls.md`](reliability/ssl-tls-mtls.md)

### Layer 6 — Interview Systems (case studies)
Now you put everything together. Each case study walks from requirements → estimation → high-level → deep dive → tradeoffs.

- [`interview-systems/url-shortener.md`](interview-systems/url-shortener.md)
- [`interview-systems/whatsapp.md`](interview-systems/whatsapp.md)
- [`interview-systems/twitter.md`](interview-systems/twitter.md)
- [`interview-systems/netflix.md`](interview-systems/netflix.md)
- [`interview-systems/uber.md`](interview-systems/uber.md)

### Meta layer — Frameworks
- [`frameworks/thinking-framework.md`](frameworks/thinking-framework.md) — **read this AFTER the foundations are solid.** It is the scaffolding you mentally apply during an interview.
- [`frameworks/request-lifecycle.md`](frameworks/request-lifecycle.md) — the single best cross-topic connector: "what happens when I type google.com" — but at the depth of a senior engineer.
- [`99_interview_mastery.md`](99_interview_mastery.md) — final checklist before an interview.

---

## Suggested pacing

- **Week 1** — Foundations: Networking (5 topics)
- **Week 2** — Foundations: Scaling (7 topics)
- **Week 3–4** — Data Layer (15 topics)
- **Week 5** — Architecture (12 topics)
- **Week 6** — Reliability & Security (10 topics)
- **Week 7** — Case studies (5 systems) + thinking framework
- **Week 8** — Rereads, mock interviews

This is *aggressive*. Double it if you have a day job. The sections are written to be re-read; you are not meant to absorb everything on first pass.

---

## Why this path instead of "just read any one book"?

Books present topics as encyclopedias: IP is under "Networking", CAP is under "Distributed Databases", load balancer is under "Infrastructure". But **in a real interview, the interviewer draws a single arrow on the whiteboard and every one of those concepts has to fire at once.**

This path is layered precisely so that each topic can reference the previous ones:

- When you read **Load Balancing**, you already know what a TCP handshake costs, so "sticky sessions" makes immediate sense.
- When you read **Consistent Hashing**, you already know why a shared-nothing cluster rebalances painfully under naive modulo hashing.
- When you read **Netflix's design**, you already know what a CDN edge node does and why it matters for 4K video.

The whole point is that **by the end, you can defend every line you draw on a whiteboard, from the TCP segment up to the global CDN fan-out.**

---

## What "done" looks like

You are done when:

1. Given a new problem ("design Instagram Stories"), you can produce a rough architecture in under 5 minutes *without Googling*.
2. For every box you drew, you can answer: *why that box, not something else?*
3. You can explain the failure mode of every box and how you would mitigate it.
4. You can connect the lowest-level behavior (a retry with exponential backoff at the client) to the highest-level goal (meeting an SLO of 99.95% availability).

If any of those feels far, **you are not behind, you are on track.** Keep going.
