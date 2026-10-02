# WebSockets & Real-Time Protocols

> *"HTTP is great for request-response. It's terrible for 'tell me when something changes.' For decades, web developers worked around this with long polling, comet, and other increasingly desperate hacks. WebSockets fixed it: a persistent bidirectional channel that browsers actually support. Combined with Server-Sent Events and modern alternatives like WebTransport, real-time web is finally a normal pattern."*

---

## Topic Overview

Real-time communication on the web — chat, live updates, collaborative editing, multiplayer games, financial tickers — needs persistent bidirectional connections, not request-response. **WebSockets** (RFC 6455, 2011) provide this: after an HTTP upgrade handshake, the connection becomes a persistent full-duplex channel.

Adjacent technologies: **Server-Sent Events (SSE)** for server-to-client streams; **WebRTC** for peer-to-peer audio/video; **WebTransport** (over QUIC) emerging as a modern alternative; **gRPC streaming** for service-to-service.

This is the topic where networking, browser APIs, and scaling realities meet. Real-time protocols have unique operational concerns: persistent connections strain load balancers; reconnection storms after outages; per-connection state explodes memory; backpressure looks different than HTTP.

---

## Intuition Before Definitions

Imagine the difference between mailing letters and a phone call.

**HTTP (mail).** Send a request; wait for reply; close. Each interaction is independent. To know about updates, you keep sending letters: "any news? any news? any news?" Wasteful.

**WebSocket (phone call).** Make one call; stay connected. Either side can speak whenever. The call lasts as long as both want.

For chat, real-time updates, multiplayer games — phone calls fit. For browsing, mail is fine.

The cost: the phone line is open even when nothing's being said. Servers must hold one connection per active user. Scaling means handling many open connections.

---

## Historical Evolution

**Era 1 — Polling.**
Pre-2010. Client polls server every few seconds. Wasteful; high latency.

**Era 2 — Long polling.**
~2005. Client makes request; server holds it open until update or timeout. Better; still HTTP-shaped.

**Era 3 — Comet.**
Early streaming via HTTP hacks. Fragile.

**Era 4 — WebSockets standardized (2011).**
RFC 6455. Bidirectional persistent connection. Browser support grows.

**Era 5 — Server-Sent Events.**
Around the same time. Server-to-client streams over HTTP.

**Era 6 — Modern era.**
WebRTC for P2P; gRPC streaming for services; WebTransport emerging. Real-time as a normal pattern.

The pattern: web protocols evolved from "request-response only" to first-class persistent connections.

---

## Core Mental Models

**1. WebSocket = persistent bidirectional channel.**
After upgrade, both sides send messages anytime.

**2. SSE = server-to-client stream.**
Simpler than WebSocket; one-way; HTTP-compatible.

**3. Connections cost memory.**
Each open connection is some KB on the server.

**4. Scaling persistent connections is different.**
Load balancers, sticky sessions, fan-out — all have specific patterns.

**5. Reconnection is normal.**
Networks blip; mobile networks switch; clients should reconnect.

---

## Deep Technical Explanation

### WebSocket protocol

Starts as HTTP:
```
GET /chat HTTP/1.1
Host: example.com
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==
Sec-WebSocket-Version: 13
```

Server responds:
```
HTTP/1.1 101 Switching Protocols
Upgrade: websocket
Connection: Upgrade
Sec-WebSocket-Accept: s3pPLMBiTxaQ9kYGzzhZRbK+xOo=
```

After this handshake, the connection is a WebSocket: framed binary protocol with text or binary messages.

### Frames

A WebSocket frame:
- Opcode (continuation, text, binary, close, ping, pong).
- Payload length.
- Masking key (client→server is masked).
- Payload data.

Messages can be fragmented across frames; small messages are one frame.

Ping/pong frames maintain connection liveness.

### Server-Sent Events (SSE)

```
GET /events HTTP/1.1
Accept: text/event-stream
```

Response is a stream of events:
```
data: {"type": "update", "value": 42}

data: {"type": "update", "value": 43}

```

Built-in browser support (`EventSource`); auto-reconnect on disconnect.

Pros: simple; HTTP-compatible (works through proxies).
Cons: server-to-client only.

For many use cases (notifications, live updates), SSE is enough.

### Use cases

**Chat / messaging.** WebSocket; both sides send messages.

**Live updates / notifications.** SSE; server pushes; client doesn't push back over the same channel.

**Collaborative editing** (Figma, Google Docs). WebSocket; CRDTs or OT for conflict resolution.

**Multiplayer games.** WebSocket; sometimes WebRTC for low-latency.

**Stock tickers.** SSE or WebSocket.

**WebRTC**: peer-to-peer for audio/video; uses signaling (often WebSocket) to set up.

### Scaling persistent connections

Each open connection:
- TCP socket: ~10KB kernel memory.
- App-level state: variable.
- 1M connections = ~10GB+ just for sockets.

**Connection limits**:
- File descriptors (`ulimit -n`).
- Ephemeral ports per IP (with reuse).
- Memory.

Tuning matters. Modern servers can hold millions of connections per box (Erlang/Elixir famously; Node, Go, modern Java with Loom too).

### Load balancing WebSockets

L4 load balancing works (TCP).

L7 load balancing must support WebSocket upgrade (most do):
- nginx: `proxy_pass` + appropriate headers.
- HAProxy: WebSocket-aware.
- AWS ALB: native support.

Sticky sessions often needed (state on specific server).

### Sticky sessions

Once a client connects, route them to the same server (where state lives).

Mechanisms:
- Cookies: ALB / load-balancer-set cookies.
- IP hash: route by client IP.
- Token-based: session ID in the connection.

Cost: a server's failure loses its connections; clients must reconnect.

### Fan-out

A common pattern: pub/sub channels. Many subscribers; each event delivered to all.

Implementation:
- In-memory: server holds connections; broadcasts to local subscribers.
- Across servers: use Redis pub/sub or Kafka to fan messages between servers; each server fans to its connections.

At scale, fan-out is its own engineering problem.

### Backpressure in real-time

If the client can't keep up:
- Buffer queues fill on the server.
- Memory grows.
- Eventually: disconnect or drop messages.

Strategies:
- Bounded queues; drop oldest.
- Coalescing (combine multiple updates).
- Lossy delivery for non-critical streams.

Different from HTTP backpressure; real-time apps must explicitly handle.

### Reconnection

Networks fail. Mobile networks switch. WiFi drops.

Robust client reconnection:
- Exponential backoff.
- Auth re-establishment.
- Resume from last seen offset (for ordered streams).
- Idempotent message handling (in case of duplicate delivery).

Server-side: handle reconnect storm gracefully (rate limit reconnects; capacity buffer).

### Heartbeats

Connections can become silently dead (NAT timeouts, half-open). Heartbeats detect:
- Send periodic ping.
- If no pong within timeout, declare dead; reconnect.

Both client and server should heartbeat; intervals tunable (often 15-60s).

### WebRTC

Peer-to-peer audio, video, data. Used for video calls.

Components:
- ICE: NAT traversal.
- DTLS: encryption.
- SCTP for data; RTP for media.
- Signaling protocol: usually WebSocket; brokers initial connection.

WebRTC is its own world; complex; rich ecosystem.

### gRPC streaming

For service-to-service:
- Server-side streaming: client requests; server streams.
- Client-side streaming: client streams; server responds once.
- Bidirectional streaming: both stream.

Built on HTTP/2; benefits from multiplexing.

### WebTransport (emerging)

Modern alternative; QUIC-based; standardized 2024-ish.

Properties:
- Multiple streams per connection.
- Datagram support (unreliable, low-latency).
- No TCP head-of-line.
- Connection migration.

Browser support growing; may replace WebSocket for new applications.

---

## Real Engineering Analogies

**The phone call vs email.**
WebSocket is the phone; HTTP is email. Different patterns; different operational concerns.

**The cinema vs the radio.**
WebSocket: bidirectional like a phone (cinema's two-way doors). SSE: one-way like radio (broadcast).

---

## Production Engineering Perspective

What goes wrong:

- **The connection-pool exhaustion.** Server hits OS limit on file descriptors. New connections fail. Tune `ulimit -n`.
- **The reconnection storm.** Server restarts; all clients reconnect simultaneously. Capacity overwhelmed. Mitigation: stagger; rate-limit reconnects.
- **The sticky-session failover.** Server fails; clients reconnect; their state is lost. Mitigation: external session store; or stateless design.
- **The fan-out scaling.** Single chat room with 100K subscribers; 1 message → 100K writes. Scale: Redis pub/sub; per-region fan-out.
- **The slow-client backpressure.** Client behind slow network; server's buffer fills. Memory grows. Mitigation: bounded buffers; drop policy.
- **The proxy timeout.** Proxy closes idle connections after 60s; WebSockets need heartbeats.
- **The mobile network drop.** Connection dies; client doesn't notice immediately; messages lost. Mitigation: short heartbeats; offset-based resume.

The senior real-time engineer's habits:
- **Tune kernel limits**.
- **Heartbeats** at appropriate intervals.
- **Reconnect with backoff**.
- **Bounded buffers** with drop policies.
- **Plan for fan-out**.
- **Test on lossy networks**.

---

## Failure Scenarios

**Scenario 1 — The reconnection storm.**
Service restart; 1M clients reconnect simultaneously. CPU melts handling handshakes. Recovery: stagger reconnects; rate limit.

**Scenario 2 — The fan-out collapse.**
Popular channel has 100K subscribers. One server holds half. CPU saturates fanning. Mitigation: shard channel across servers; intermediate fan-out tier.

**Scenario 3 — The buffer-bloat memory leak.**
Slow client; server buffer grows; eventually OOM. Fix: bounded buffer; drop oldest.

**Scenario 4 — The silent disconnection.**
Mobile client goes through tunnel; connection dead but server doesn't know. Messages lost. Fix: heartbeats.

**Scenario 5 — The auth-token expiration.**
Long-lived connection; token expires mid-session; messages start failing. Mitigation: refresh tokens; re-auth without disconnect.

---

## Performance Perspective

- **Connection setup**: 1 RTT (TCP) + 1 RTT (TLS) + 1 RTT (WebSocket upgrade).
- **Message overhead**: small (frame header is 2-14 bytes).
- **Per-connection memory**: 10-100KB depending on framework.
- **Throughput**: language/runtime dependent; modern stacks: hundreds of thousands msg/sec/server.

---

## Scaling Perspective

- **Single server**: 100K-1M connections.
- **Cluster**: shard by user; fan-out via pub/sub.
- **Geographic**: regional servers; cross-region for global.
- **At hyperscale**: dedicated infrastructure (Slack, Discord).

---

## Cross-Domain Connections

- **TCP**: WebSockets are TCP. (See [tcp-and-network-fundamentals.md](./tcp-and-network-fundamentals.md).)
- **HTTP/2 and HTTP/3**: relevant for upgrade and modern alternatives. (See [http-2-and-http-3.md](./http-2-and-http-3.md).)
- **Load balancing**: WebSocket-aware LB. (See [load-balancing-strategies.md](../scalability/load-balancing-strategies.md).)
- **Backpressure**: real-time backpressure is different. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Coroutines / actors**: well-suited to many connections. (See [actor-model-and-message-passing.md](../concurrency/actor-model-and-message-passing.md).)
- **Sticky sessions**: in load balancing. (See [load-balancing-strategies.md](../scalability/load-balancing-strategies.md).)

The unifying observation: **real-time protocols turn the web from request-response into bidirectional channels. The operational concerns (persistent connections, fan-out, reconnection) are different from HTTP's; the architectural patterns must adapt.**

---

## Real Production Scenarios

- **Discord's real-time architecture**: Elixir-based; documented.
- **Slack's WebSockets**: at scale.
- **Twitch chat**: heavy fan-out.
- **Figma's collaborative editing**: WebSocket + CRDTs.
- **Cloudflare's WebTransport adoption**.

---

## What Junior Engineers Usually Miss

- That **persistent connections cost memory**.
- That **load balancers need WebSocket support**.
- That **heartbeats are mandatory**.
- That **reconnection storms** must be handled.
- That **fan-out scales differently**.

---

## What Senior Engineers Instinctively Notice

- They **tune kernel limits**.
- They **plan reconnection**.
- They **design fan-out** explicitly.
- They **bound buffers**.
- They **test on lossy networks**.

---

## Interview Perspective

What gets tested:

1. **"WebSocket vs HTTP?"** Persistent vs request-response.
2. **"WebSocket vs SSE?"** Bidirectional vs server-to-client.
3. **"How do you scale WebSockets?"** Sticky sessions; fan-out; sharding.
4. **"Heartbeats?"** Detect dead connections.
5. **"Reconnection?"** Exponential backoff; resume.

Common traps:
- Forgetting connection memory cost.
- Not handling reconnection.

---

## 20% Knowledge Giving 80% Understanding

1. **WebSocket = bidirectional persistent channel**.
2. **SSE = server-to-client stream**.
3. **Heartbeats** to detect dead connections.
4. **Reconnect with backoff**.
5. **Bounded buffers** with drop policies.
6. **Sticky sessions** typical.
7. **Fan-out scales differently** than request-response.
8. **WebRTC** for P2P audio/video.
9. **gRPC streaming** for services.
10. **WebTransport** emerging over QUIC.

---

## Final Mental Model

> **Real-time protocols turn the web's request-response into bidirectional flows. The new operational concerns — connection memory, fan-out scaling, reconnection storms, backpressure — are real and different. Engineers who master them ship the chat apps, collaborative tools, and live-update features that define modern web UX.**

That's WebSockets. That's real-time. That's the substrate under every chat app, every live dashboard, every collaborative document — and the scaling discipline that makes them work at scale.
