# The Request Lifecycle — "What Happens When I Type google.com"

> **This is the single most important file in this repo.** If you can narrate this from memory, you have understood the foundational stack.

This file connects every prior topic. A real senior-level question might be: *"walk me through what happens when a user opens your app from their phone."* You should be able to do it without hesitation.

---

## Stage 0 — User presses Enter / taps the icon

Browser/app has a URL: `https://api.myapp.com/v1/feed`.

---

## Stage 1 — URL parsing & cache

Browser parses URL into scheme, host, port, path.
- Checks its HTTP cache (Cache-Control, ETag). If fresh → return cached, done.
- Else needs to resolve host.

*→ Concept: [Caching](../foundations/scaling/caching.md)*

---

## Stage 2 — DNS resolution

1. OS stub resolver → configured resolver (e.g., 1.1.1.1).
2. Resolver cache hit? → return.
3. Else recurse: root → TLD → authoritative.
4. Returns A record → IP (e.g., `18.66.112.14`, behind Cloudflare anycast).

Takes 5–50 ms typically.

*→ Concept: [DNS](../foundations/networking/dns.md)*

---

## Stage 3 — TCP connection

1. Send SYN to `18.66.112.14:443`.
2. Packet routed through NAT, ISP, tier-1 peers to CDN edge.
3. SYN+ACK back. ACK out. TCP connected.

Cost: 1 RTT.

*→ Concepts: [IP](../foundations/networking/ip.md), [TCP/UDP](../foundations/networking/tcp-udp.md)*

---

## Stage 4 — TLS handshake

ClientHello → ServerHello + cert → key exchange → Finished.
- TLS 1.3: 1 RTT.
- Session resumption (previously connected): 0 RTT.

Cost: 1 RTT.

*→ Concept: [SSL/TLS/mTLS](../reliability/ssl-tls-mtls.md)*

---

## Stage 5 — CDN edge decision

Request arrives at nearest **CDN PoP** (Cloudflare/CloudFront).

- Edge serves cached response if it's a cacheable `GET` and cache is warm.
- Else forwards to origin.

*→ Concept: [CDN](../foundations/scaling/cdn.md)*

---

## Stage 6 — Origin load balancer

Edge → internet → your cloud VPC → **L7 Load Balancer** (ALB/Nginx).
- TLS terminated at LB.
- LB picks a backend from its healthy pool (least-connections).
- Headers rewritten (`X-Forwarded-For` added).

*→ Concepts: [Load Balancing](../foundations/scaling/load-balancing.md), [Proxy](../foundations/networking/proxy.md)*

---

## Stage 7 — API gateway

Request hits the **API Gateway**.
- Auth: validate JWT (issued via [OIDC](../reliability/oauth-oidc.md)).
- Rate limit: token bucket in Redis.
- Routing: path `/v1/feed` → feed service.
- Observability: assign trace ID.

*→ Concepts: [API Gateway](../architecture/api-gateway.md), [Rate Limiting](../reliability/rate-limiting.md), [OAuth/OIDC](../reliability/oauth-oidc.md)*

---

## Stage 8 — Service mesh / discovery

Inside the cluster:
- Feed service sidecar proxy (Envoy) handles mTLS, retry, timeout, circuit breaking.
- Service discovery via Kubernetes service (CoreDNS) or Consul.
- Feed service selected.

*→ Concepts: [Service Discovery](../reliability/service-discovery.md), [Circuit Breaker](../reliability/circuit-breaker.md), [VMs and Containers](../reliability/vms-and-containers.md)*

---

## Stage 9 — Feed service logic

Feed service receives request:
- Checks Redis cache for `feed:{user_id}`.
- Cache hit (most of the time): return serialized feed.
- Cache miss: fetch fresh data → populate cache.

*→ Concepts: [Caching](../foundations/scaling/caching.md), [CQRS](../architecture/cqrs.md)*

---

## Stage 10 — Database(s)

If cache miss:
- Query user's follow graph (Postgres or graph DB).
- Pull recent posts from Cassandra (partition by user_id, clustering by time).
- Possibly call a recommendation service (ML inference).
- Merge + rank in-memory.

Behind the scenes:
- Cassandra cluster: consistent hashing, replicated.
- Postgres: sharded by user_id; read replicas.

*→ Concepts: [SQL](../data/sql-databases.md), [NoSQL](../data/nosql-databases.md), [Replication](../data/database-replication.md), [Sharding](../data/sharding.md), [Consistent Hashing](../data/consistent-hashing.md), [CAP](../data/cap-theorem.md)*

---

## Stage 11 — Asynchronous side effects

- Impression tracked → event published to **Kafka**.
- Consumers: analytics (ClickHouse), ML training data (S3), fraud detection.

*→ Concepts: [Pub-Sub](../architecture/pub-sub.md), [EDA](../architecture/event-driven-architecture.md), [Message Brokers](../architecture/message-brokers.md)*

---

## Stage 12 — Response path

- Feed service → sidecar → API Gateway → LB → CDN edge.
- Each hop adds observability headers (trace IDs).
- CDN may cache the response (if cacheable).
- TLS encrypts back.
- Bytes stream down TCP, across NAT, to the user's phone.

---

## Stage 13 — Client rendering

Browser/app:
- Parses response.
- Fetches sub-resources (images → CDN).
- Renders.
- May open a WebSocket for real-time updates (notifications, likes).

*→ Concept: [Long Polling / WebSockets / SSE](../architecture/long-polling-websockets-sse.md)*

---

## Stage 14 — Observability

Every hop emitted:
- **Metrics** (Prometheus): latency, error rate, saturation.
- **Logs** (Elastic/Loki): structured per-trace.
- **Traces** (Jaeger/Tempo): connected via trace ID through all services.

Dashboards (Grafana) show health. Alerts fire on SLO burn rate.

*→ Concept: [SLA/SLO/SLI](../reliability/sla-slo-sli.md)*

---

## The "If X dies" questions

At each stage, ask: *what if this box dies?* That's the **failure analysis** you want to be ready to answer:

| Dies | Effect | Mitigation |
|---|---|---|
| DNS authoritative | New clients can't resolve | Multiple NS records, low TTL, anycast |
| CDN edge | Nearby users fail | DNS routes to next-nearest; origin shield absorbs |
| LB | All traffic fails | Redundant LBs, VRRP/DNS failover |
| API Gateway | All traffic fails | HA deployment, multi-AZ |
| Feed service (one instance) | Other instances absorb | Health check + LB removes, autoscaler replaces |
| Redis cache | Cache miss storm on DB | Cache stampede protection, warm secondary |
| Postgres primary | Writes fail briefly | Replica promotion, failover automation |
| Cassandra node | Other replicas serve | Consistency level tuning |
| Kafka broker | One partition leadership moves | Multi-broker, ISR guarantees |
| Whole region | Complete outage | Multi-region active-active + DNS failover |

*→ Concepts: [Availability](../foundations/scaling/availability.md), [Disaster Recovery](../reliability/disaster-recovery.md), [Circuit Breaker](../reliability/circuit-breaker.md)*

---

## Why this file matters

Every interview, every production incident, every design review: **you are tracing requests through this path**. If you internalize this, you can:
- Localize a problem to a layer ("the user reports slow feeds; is it DNS, CDN, LB, service, DB, or client render?").
- Design from scratch by filling in each stage.
- Justify every component's existence in terms of what would break without it.

Read this file more than once. Read it after a long design discussion. It ties everything together.
