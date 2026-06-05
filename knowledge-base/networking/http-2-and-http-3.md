# HTTP/2, HTTP/3 & QUIC

> *"HTTP/1.1 ran the web for two decades. Then mobile internet, complex pages, and global users exposed its limits. HTTP/2 fixed the multiplexing problem; HTTP/3 abandoned TCP entirely. Each evolution was driven by the workloads HTTP was failing — and each made the protocol stack more complex in exchange for substantial performance gains."*

---

## 🎯 Start Here — Intuition

> **In one line:** newer versions of HTTP let a browser fetch all the pieces of a web page over one connection at once, instead of waiting in line for each one — so pages load faster, especially on slow or mobile networks.
>
> **Analogy:** ordering at a restaurant. HTTP/1.1 is one waiter who takes one dish order, walks to the kitchen, brings it back, and only then takes your next order. HTTP/2 is one waiter who takes your whole order at once and brings dishes as they're ready — but if a tray gets dropped in the kitchen, the whole order waits. HTTP/3 gives each dish its own runner, so a dropped tray only delays that one dish.
>
> **Assumes you already know:** TCP (Transmission Control Protocol) vs UDP (User Datagram Protocol) and the TCP handshake (see [`learn/foundations/networking/tcp-udp.md`](../../learn/foundations/networking/tcp-udp.md)) and TLS (Transport Layer Security)/SSL (Secure Sockets Layer) basics (see [`learn/reliability/ssl-tls-mtls.md`](../../learn/reliability/ssl-tls-mtls.md)). This is a KB-only deep dive with no beginner learn/ counterpart — build those fundamentals first.
>
> **Level:** this file is 🟡 overall, leaning 🔴 in the QUIC/QPACK/handshake internals. Sections below are tagged. If the basics feel shaky, that tag is your signal to slow down — **you are not behind.**

---

## Topic Overview 🟢

HTTP, the protocol that defines the web, has gone through three major versions. **HTTP/1.1** (1997) is the textual, human-readable protocol most engineers learned. **HTTP/2** (2015) added binary framing, multiplexing, header compression, and server push — major performance improvements while running on TCP. **HTTP/3** (2022) replaces TCP with **QUIC** (Quick UDP Internet Connections) (over UDP), eliminating head-of-line blocking and reducing connection-establishment latency.

The improvements are real but not free. Each version adds complexity: HTTP/2's flow control mirroring TCP's; HTTP/3 reimplementing reliability features in user space. The benefit at scale (tens of milliseconds saved per page load) compounds across billions of requests.

This is the topic where networking, web architecture, and protocol design meet. Most production engineers don't need to implement these protocols, but understanding the differences shapes architecture decisions: what to deploy at the edge, how to design APIs, how to debug performance issues that span TCP and HTTP layers.

---

## Intuition Before Definitions 🟢

Imagine fetching a webpage with 100 resources.

**HTTP/1.1.** Open a TCP connection. Request resource 1; receive it. Request resource 2; receive it. Repeat. Each request waits for the previous to finish. Browsers parallelize by opening 6 connections to the same server. 100 resources / 6 = ~17 round-trips. Each round-trip is 50-200ms. Page load is slow.

**HTTP/2.** One TCP connection. Send all 100 requests immediately, multiplexed on one connection. Server streams responses interleaved. The server can prioritize. 100 resources in *one* connection's worth of round-trips. Much faster.

**HTTP/3.** Same multiplexing as HTTP/2, but: if a single packet is lost, HTTP/2 stalls *all* streams (TCP head-of-line blocking). HTTP/3 over QUIC handles loss per-stream — only the affected stream pauses; others keep going. Plus QUIC has fewer round-trips for connection setup.

Each generation reduced the number of round-trips required to deliver content. For a modern web app, the difference is the difference between "the page feels snappy" and "the page is sluggish."

---

## Historical Evolution 🟢

**Era 1 — HTTP/0.9 and 1.0.**
1990s. Simple text protocols. New connection per request.

**Era 2 — HTTP/1.1 (1997).**
Persistent connections; pipelining (rarely worked); chunked transfer. Dominant for two decades.

**Era 3 — SPDY (2009).**
Google's experimental protocol; binary, multiplexed, header-compressed. Demonstrated benefits.

**Era 4 — HTTP/2 (2015).**
Standardized SPDY's ideas. Binary framing; multiplexing; HPACK (HTTP/2 Header Compression) header compression; server push. Adoption rapid.

**Era 5 — QUIC and HTTP/3.**
Google develops QUIC (~2012); IETF (Internet Engineering Task Force) standardizes (2021). HTTP/3 (2022) maps HTTP semantics onto QUIC. Eliminates TCP head-of-line blocking.

**Era 6 — Modern adoption.**
2023+. HTTP/3 deploys on Cloudflare, Google, Facebook. Browsers support natively. Older HTTP/2 still common.

The pattern: each version reduced round-trips and head-of-line blocking. Adoption follows browsers and CDNs (Content Delivery Networks).

---

## Deep Technical Explanation 🔴

⚠️ The rest of this section assumes the basics above are solid.

### HTTP/1.1 limitations

**Head-of-line blocking at HTTP layer.**
Pipelining theoretically lets you send multiple requests; in practice, responses must be in order. A slow response blocks all subsequent ones. Most browsers don't pipeline.

**Connection limit.**
Browsers open ~6 connections per origin. Pages with hundreds of resources are bottlenecked.

**Header overhead.**
Headers re-sent in full per request. A request with 1KB of cookies sent 100 times = 100KB of header overhead.

**Redundant connections.**
Different sub-domains = different connection pools. Sharding tricks to parallelize made the problem worse.

### HTTP/2 — what changed

**Binary framing.**
Replaces text. Each frame has type (DATA, HEADERS, etc.), length, stream ID. Parsers are simpler and faster.

**Multiplexing.**
Multiple streams (requests) on one connection. Streams are independent; frames interleave.

**HPACK header compression.**
Headers compressed using shared dictionary. Repeated headers (cookies, User-Agent) shrink dramatically.

**Server push.**
Server can send resources the client will need. Often disabled in production due to cache complications; deprecated in modern HTTP/3.

**Stream prioritization.**
Client tells server "this stream is more important." Server orders responses accordingly.

**Flow control.**
Per-stream and connection-wide. Mirrors TCP's flow control at the HTTP layer.

### HTTP/2's TCP head-of-line problem

HTTP/2 multiplexes 100 streams on one TCP connection. If the network drops one packet:
- TCP retransmits.
- All 100 streams pause until the packet arrives (TCP delivers in order).

The HTTP layer's multiplexing is undone by the TCP layer's in-order delivery. On lossy networks, HTTP/2 can be *slower* than HTTP/1.1 (which uses multiple connections; loss on one doesn't affect others).

### QUIC

QUIC is essentially "TCP redesigned in userspace, on top of UDP."

Properties:
- **UDP-based**: kernel doesn't reorder; QUIC handles in userspace.
- **Per-stream loss handling**: a lost packet only affects its stream.
- **Built-in encryption**: TLS 1.3 integrated; can't run unencrypted.
- **0-RTT (Round-Trip Time) handshake** (when both ends support).
- **Connection migration**: connections survive IP changes (mobile network switches).
- **Faster handshakes**: 1 RTT typical; 0 RTT possible.

QUIC was Google's bet that TCP can't evolve fast enough; userspace protocol can.

### HTTP/3

HTTP/3 = HTTP semantics + QUIC transport.

Same HTTP requests/responses; different transport. Browsers fall back to HTTP/2 over TCP if QUIC fails.

Performance:
- **Lossy networks**: significant gains over HTTP/2 (no TCP head-of-line).
- **Mobile**: connection migration helps.
- **High-quality networks**: smaller gains; HTTP/2 is fine.

### Connection establishment comparison

| Protocol | Round trips |
|---|---|
| HTTP/1.1 over TCP | 1 RTT TCP + 2 RTT TLS = 3 RTT |
| HTTP/1.1 over TLS 1.3 | 1 RTT TCP + 1 RTT TLS = 2 RTT |
| HTTP/2 over TLS 1.3 | 2 RTT (same as 1.1 with TLS 1.3) |
| HTTP/3 over QUIC | 1 RTT typical; 0 RTT for repeated |

Saving 1 RTT matters: on a 100ms link, that's 100ms off every connection establishment.

### Server push (and its problems)

HTTP/2's server push: server sends `link.css` along with `index.html` (predicting client will need it).

Problems:
- Server doesn't know client's cache.
- Pushed-but-cached resources waste bandwidth.
- Implementation complexity.

Most production deployments disabled it. HTTP/3 deprecated it.

Alternative: 103 Early Hints; tells client to start fetching specific resources.

### HPACK and HTTP/3's QPACK (QUIC Header Compression)

**HPACK (HTTP/2)**: shared dynamic table; sender and receiver track. Vulnerable to ordering issues.

**QPACK (HTTP/3)**: redesigned to handle out-of-order frame delivery. Slightly more complex; works correctly with QUIC's per-stream model.

Both compress headers; effective compression rates 50-90% for repeated headers.

### TLS evolution

**TLS 1.0/1.1**: deprecated; insecure.
**TLS 1.2**: 2008; widely deployed.
**TLS 1.3**: 2018; faster handshake; smaller cipher suite.

QUIC requires TLS 1.3. HTTP/2 can use TLS 1.2 or 1.3.

### Connection coalescing

HTTP/2 allows reusing a connection for another origin only when two conditions hold (RFC (Request for Comments) 7540 §9.1.1): the connection's certificate covers the host, **and** that host resolves to the same IP address as the existing connection. So a connection to `*.example.com` can serve requests for `api.example.com`, `cdn.example.com`, etc. — but only if those names point at the same IP. Cert match alone is not sufficient.

Reduces connections; improves efficiency. Some operational care needed (sharding by IP, etc.).

### Production deployment

To deploy HTTP/2:
- TLS certificate (HTTP/2 in browsers requires HTTPS).
- Server supports HTTP/2 (most do; nginx, Apache, Envoy, etc.).
- Client negotiation (ALPN (Application-Layer Protocol Negotiation) extension).

To deploy HTTP/3:
- All HTTP/2 prerequisites.
- UDP must be open at firewalls (sometimes blocked).
- Server supports QUIC (Cloudflare, nginx with quiche, LiteSpeed, AWS (Amazon Web Services) CloudFront).
- Browsers support natively.
- `Alt-Svc` header advertises HTTP/3 availability.

### Debugging

HTTP/2:
- Wireshark with TLS keys.
- `nghttp2` tools.
- Browser DevTools show protocol used per request.

HTTP/3:
- Wireshark + QUIC dissector.
- `qlog` format for debugging traces.
- Browser DevTools show "h3" protocol.

Debugging encrypted protocols is harder than HTTP/1.1; logs and instrumentation are critical.

---

## Real Engineering Analogies 🟢

**The single-lane bridge vs the multi-lane highway.**
HTTP/1.1: one lane; one car at a time. Slow car blocks everyone.
HTTP/2: highway with many lanes; cars travel in parallel. But all lanes share one bridge — a wreck on the bridge stops everyone.
HTTP/3: multiple parallel bridges; a wreck on one doesn't stop the others.

**The conversation analogy.**
HTTP/1.1: send a letter; wait for reply; send next.
HTTP/2: phone call; you can talk and listen simultaneously, but if the line drops, the whole call ends.
HTTP/3: video call with breakout rooms; each subtopic is independent; one person's connection issue doesn't disrupt the whole call.

---

## Production Engineering Perspective 🟡

What goes wrong:

- **The HTTP/2 connection-coalescing surprise.** Two services share a certificate; coalesce into one connection; one service's outage breaks the other. Mitigation: separate certs or origins.
- **The mobile-network HTTP/2 sluggishness.** Lossy mobile network; HTTP/2's TCP HoL (Head-of-Line) blocks streams. Switch to HTTP/3 — performance recovers.
- **The QUIC-blocked enterprise.** UDP blocked at corporate firewall; HTTP/3 fails; falls back to HTTP/2. Subtle performance issue; not always noticed.
- **The TLS handshake cliff.** New connection per request; each handshake is ~100ms. Mitigation: connection reuse; HTTP/2 multiplexing.
- **The server push miss.** Pushed resources not used (already cached); bandwidth wasted. Disable; use 103 Early Hints.
- **The HPACK state confusion.** Long-lived HTTP/2 connections; HPACK state bloats; memory grows. Tune HPACK table size.

---

## Failure Scenarios 🔴

**Scenario 1 — The connection-coalescing outage.**
Two services share `*.example.com` cert; HTTP/2 coalesces connections. Service A has issue; HTTP/2 connection is reused for service B; B fails too despite being healthy. Recovery: split certs.

**Scenario 2 — The mobile-network performance gap.**
US users see fast page loads; Brazilian mobile users see slow. Investigation: high packet loss on Brazilian mobile networks. HTTP/2's TCP HoL is the issue. Deploy HTTP/3 — fixes mobile performance.

**Scenario 3 — The corporate QUIC block.**
Enterprise customers can't use HTTP/3 (firewall blocks UDP). Service falls back to HTTP/2 silently. Performance gap between consumer and enterprise users. Mitigation: detect and report; or improve HTTP/2 path.

**Scenario 4 — The HPACK explosion.**
HTTP/2 server with high-cardinality headers (per-request tracing IDs). HPACK dynamic table fills with one-time entries; compression ratio drops. Memory grows. Mitigation: don't put high-cardinality data in headers.

**Scenario 5 — The 0-RTT replay risk.**
TLS 1.3 0-RTT data is replayable by attackers. Application must ensure idempotency for 0-RTT requests. A non-idempotent endpoint with 0-RTT enabled: replay attack. Mitigation: limit 0-RTT to safe operations.

---

## Performance Perspective 🟡

- **HTTP/1.1**: slowest; multiple connections required for parallelism.
- **HTTP/2**: 1 connection multiplexes many streams; significant improvement.
- **HTTP/3**: similar to HTTP/2 on good networks; better on lossy.
- **TLS 1.3 + 0-RTT**: minimum connection latency.
- **HPACK / QPACK**: 50-90% header compression.

---

## Scaling Perspective 🟡

- **Connection count**: HTTP/2 reduces connections by 6×; HTTP/3 similar.
- **Bandwidth**: header compression saves bytes; major win at scale.
- **Edge deployment**: HTTP/3 latency wins compound.
- **At hyperscale**: own QUIC implementations; tight kernel integration.

---

## Cross-Domain Connections 🟡

- **TCP**: HTTP/2 over TCP; HTTP/3 over UDP/QUIC. (See [tcp-and-network-fundamentals.md](./tcp-and-network-fundamentals.md).)
- **API design**: gRPC (gRPC Remote Procedure Calls) uses HTTP/2; HTTP/3 emerging. (See [api-design-rest-vs-grpc.md](../architecture-patterns/api-design-rest-vs-grpc.md).)
- **Edge computing**: HTTP/3 deployed at edge first. (See [edge-computing-and-cdns.md](../scalability/edge-computing-and-cdns.md).)
- **Caching**: HTTP cache headers semantics. (See [caching-hierarchy.md](../caching/caching-hierarchy.md).)
- **Load balancing**: L7 (Layer 7, the application layer) LBs (Load Balancers) handle HTTP/2 / HTTP/3. (See [load-balancing-strategies.md](../scalability/load-balancing-strategies.md).)

The unifying observation: **HTTP's evolution is a story of removing round-trips. Each version reduced what's needed to fetch a page; each compounds at the global scale of the modern web.**

---

## Real Production Scenarios 🟡

- **Cloudflare's HTTP/3 deployment**: extensive public engineering on QUIC implementation.
- **Google's QUIC origin**: papers and design docs.
- **Facebook's adoption**: documented HTTP/2 to HTTP/3 transitions.
- **The "Web Almanac"**: annual statistics on protocol adoption.

---

## Key Takeaways

- **HTTP/1.1 is one-request-at-a-time per connection.** Browsers open ~6 connections per origin to parallelize; pages with hundreds of resources are bottlenecked.
- **HTTP/2 multiplexes many streams over one TCP connection** with binary framing and header compression — a major efficiency win.
- **HTTP/2 still suffers TCP head-of-line blocking**: a single lost packet stalls *all* streams sharing the connection. The thing HTTP/2 fixed at the HTTP layer remains at the TCP layer, and on lossy networks HTTP/2 can be slower than HTTP/1.1.
- **HTTP/3 = HTTP over QUIC.** QUIC is UDP + reliability + encryption + multiplexing, with per-stream loss handling and faster handshakes — but **HTTP/3 runs over UDP**, which corporate firewalls sometimes block.
- **The improvements compound.** HTTP/3 vs HTTP/1.1 can be 2-5× faster for resource-heavy pages; mobile and lossy networks benefit most. On high-quality networks the HTTP/3 gain over HTTP/2 is small.
- **TLS handshakes are a major source of latency.** Use TLS 1.3 (required by QUIC) for faster handshakes; TLS 1.3 0-RTT gives the fastest reconnects — but 0-RTT data is replayable, so restrict it to idempotent operations.
- **HPACK (HTTP/2) / QPACK (HTTP/3) compress headers** by 50-90% for repeated headers. Avoid high-cardinality headers (per-request tracing IDs), which defeat compression and bloat connection state.
- **Server push is mostly deprecated** (cache-blindness, complexity); prefer 103 Early Hints.
- **Connection coalescing has gotchas**: cert match alone isn't enough (same IP required), and coalescing can let one service's outage break another.
- **Operational defaults**: deploy HTTP/2 minimum for production; enable HTTP/3 at the edge/CDN; monitor connection reuse and protocol-version distribution; keep certificates fresh; test on lossy networks. The benefits are configuration, not code changes.

> **The unifying idea: HTTP's evolution is the web's optimization story — each version removed round-trips and inefficiencies that mattered at the previous version's scale. HTTP/2 fixed the connection problem; HTTP/3 fixed the head-of-line problem. The gains compound across billions of requests.**

---

## Interview angle 🟡

What gets tested:

1. **"HTTP/1.1 vs HTTP/2?"** Multiplexing, binary framing, header compression.
2. **"What's TCP head-of-line blocking?"** A lost packet stalls all streams on the connection.
3. **"What's QUIC?"** UDP + reliability + encryption + multiplexing.
4. **"Why is HTTP/3 different?"** No TCP HoL; faster handshake.
5. **"What's HPACK?"** HTTP/2 header compression.
6. **"When wouldn't you use HTTP/3?"** Corporate firewalls blocking UDP; not yet ubiquitous.

Common traps: believing HTTP/2 fixes all HTTP/1.1 problems; not knowing UDP underlies HTTP/3.
