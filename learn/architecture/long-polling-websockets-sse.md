# Long Polling, WebSockets, Server-Sent Events — Real-Time Client ↔ Server

## A. Intuition First
HTTP request/response is client-initiated. For server-pushed data (chat, notifications, tickers), you need persistence or server-initiated flows.

Three tools:
- **Long Polling**: client holds request open until server has data.
- **WebSockets**: full-duplex, persistent connection.
- **Server-Sent Events (SSE)**: server → client stream, unidirectional, HTTP-based.

## B. Mental Model
| Tech | Direction | Protocol | Complexity | Firewall-friendly |
|---|---|---|---|---|
| Long Polling | Req/Resp loop | HTTP | Low | Yes |
| SSE | Server → Client | HTTP | Low | Yes |
| WebSocket | Bi-directional | ws:// (TCP, starts as HTTP Upgrade) | Medium | Mostly |

## C. Internal Working

### Long Polling
1. Client sends HTTP request.
2. Server holds it open until data or timeout.
3. Server responds with data.
4. Client immediately re-requests.
Close to real-time but wastes per-request overhead.

### WebSocket
1. Client sends HTTP Upgrade request with `Upgrade: websocket`.
2. Server responds 101; connection switches protocol.
3. Both sides send frames any time.

### SSE
1. Client opens `EventSource("/stream")`.
2. Server responds with `Content-Type: text/event-stream` and streams events.
3. Auto-reconnects on disconnect.

## D. Visual Representation
```
Polling:    Client  ──req──▶ Server   (loop)
Long poll:  Client  ──req──▶ Server   (held, replies on event)
SSE:        Client  ───────────◀── events  (stream, server→client)
WS:         Client  ◀═══════▶  Server  (full duplex)
```

## E. Tradeoffs
- **Long poll**: simple, works everywhere, inefficient at scale.
- **WebSocket**: full-duplex, best for chat/games; stateful connections are heavy on servers; need sticky LB; proxy/CDN issues.
- **SSE**: simplest for server→client only; reconnection free; one-way; browser-only; limit of ~6 concurrent per origin.

## F. Interview Lens
- "Design chat — WebSocket, SSE, or long poll?" — WebSocket (bi-directional).
- "Notifications (server → client only)?" — SSE is elegant.
- "Live ticker on public internet?" — SSE or WebSocket.
- Pitfalls: forgetting sticky sessions for WS; forgetting max-connection limits.

## G. Real-World Mapping
- **WhatsApp, Slack, Discord**: WebSocket.
- **Twitter notification bell**: was long-poll; modern = SSE/WS.
- **Server-sent health dashboards**: SSE.

## H. Questions
**Beginner**: When would SSE suffice over WS?
**Intermediate**: Why do WS servers need sticky LBs?
**Advanced**: Design a WS-backed chat for 10M concurrent users.

## I. Mini Design
Chat app 1M concurrent users. Shard users across WS server pool by hash(user_id). Sticky routing via consistent hashing. Presence via Redis pub-sub. Persistence in Cassandra.

## J. Cross-Topic Connections
- [TCP/UDP](../foundations/networking/tcp-udp.md), [Load Balancing](../foundations/scaling/load-balancing.md), [Caching](../foundations/scaling/caching.md).

## K. Confidence Checklist
- [ ] Can pick the right tech for each real-time use case.
- [ ] Knows WS + LB implications.

## L. Potential Gaps & Improvements
- **WebRTC (Web Real-Time Communication)** — a browser standard for direct peer-to-peer audio, video, and data streams without routing through your server; a different beast you reach for in video-call and screen-share designs.
- **QUIC (Quick UDP Internet Connections)** — a UDP-based transport that powers HTTP/3, giving multiplexed streams without head-of-line blocking and faster reconnects; matters when mobile clients roam between networks mid-stream.
- **HTTP/3** — the latest HTTP version running over QUIC instead of TCP, so a dropped packet on one stream no longer stalls the others; relevant for low-latency push over flaky links.
- **MQTT (Message Queuing Telemetry Transport)** — a lightweight publish/subscribe protocol built for low-bandwidth, high-latency IoT (Internet of Things) devices; the go-to answer when millions of sensors must push tiny messages cheaply.

**🔧 How to close:** Spin up a quick SSE (Server-Sent Events) demo: run `python3 -m http.server` next to a tiny Node/Flask endpoint that emits `data: <ts>\n\n` every second, open it with `curl -N http://localhost:PORT/events`, and watch the stream stay open — then compare the connection lifetime against a plain `curl` request using `ss -tan | grep :PORT` in another terminal.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 📹 Gap 1 — WebRTC for Peer-to-Peer Media
- 🔹 **What it is**: A browser standard for direct peer-to-peer audio, video, and arbitrary data channels that bypass your server once the call is set up.
- 🔹 **Why it matters**: WebSocket/SSE all relay through your server, which is fine for text but ruinous for video bandwidth and latency; WebRTC moves the heavy media stream client-to-client.
- 🔹 **Connection**: This file routes everything through a server (the WS pool in §I Mini Design). WebRTC is the answer when "chat" grows into "video call" and relaying every frame through your servers stops scaling.
- 🔹 **When needed**: 🟡 **Mid-level** — shows up the moment a design mentions video calls, screen share, or live audio.
- 🔹 **Intuition**: A phone switchboard operator connects two callers, then steps out of the conversation — they only handled the setup, not the talking.
- 🔹 **If you go deeper**: Learn the signaling/STUN/TURN/ICE pipeline (RFC 8445); STUN discovers your public address, TURN relays when NAT traversal fails. Build a 2-peer call with `simple-peer` or raw `RTCPeerConnection`.
- 🔹 **Interview hook**: *"If media is peer-to-peer, why do I still need a server?"* → for signaling (exchanging SDP offers/ICE candidates) and TURN relay fallback when direct connection is blocked.

---

#### 🚀 Gap 2 — QUIC and HTTP/3 as the Transport
- 🔹 **What it is**: QUIC (Quick UDP Internet Connections) is a UDP-based transport with built-in TLS and multiplexed streams; HTTP/3 is HTTP running over QUIC instead of TCP.
- 🔹 **Why it matters**: TCP suffers head-of-line blocking — one lost packet stalls every multiplexed stream; QUIC isolates streams so a dropped packet only delays its own stream, and connection migration survives a network switch without a full reconnect.
- 🔹 **Connection**: WebSocket and SSE both ride on TCP here. On flaky mobile links those reconnect handshakes hurt; QUIC/HTTP3 is the transport-layer upgrade that makes server push smoother, and WebTransport rides on it as a WS successor.
- 🔹 **When needed**: 🔴 **Senior** — transport-layer detail relevant to CDN, edge, and mobile-latency designs; most product interviews never reach here.
- 🔹 **Intuition**: A single-lane road (TCP) where one stalled car blocks everyone, versus a multi-lane road (QUIC) where one breakdown only blocks its own lane.
- 🔹 **If you go deeper**: Read RFC 9000 (QUIC) and RFC 9114 (HTTP/3); test with `curl --http3` against Cloudflare, which serves HTTP/3 widely. Explore WebTransport as the bidirectional-stream API over QUIC.
- 🔹 **Interview hook**: *"Why move real-time push off TCP onto QUIC?"* → kill head-of-line blocking and survive client network changes via connection migration.

---

#### 📡 Gap 3 — MQTT and Pub/Sub for Fan-Out
- 🔹 **What it is**: MQTT (Message Queuing Telemetry Transport) is a lightweight publish/subscribe protocol designed for low-bandwidth, high-latency, constrained devices.
- 🔹 **Why it matters**: When millions of IoT sensors or mobile clients each push tiny messages, raw WebSocket frames and per-connection overhead get expensive; MQTT's compact framing, topic-based routing, and QoS levels are purpose-built for that scale.
- 🔹 **Connection**: §I uses Redis pub-sub to fan messages across the WS pool — MQTT generalizes that idea into a client-facing protocol with a broker doing the topic routing.
- 🔹 **When needed**: 🟡 **Mid-level** — the go-to answer in IoT, telemetry, and "millions of cheap devices" prompts.
- 🔹 **Intuition**: A radio station broadcasts on a frequency (topic); thousands of cheap receivers tune in without the station tracking each one individually.
- 🔹 **If you go deeper**: Run an Eclipse Mosquitto broker locally, publish/subscribe with `mosquitto_pub`/`mosquitto_sub`, and try the three QoS levels (at-most-once, at-least-once, exactly-once). Compare with AMQP/Kafka for heavier backends.
- 🔹 **Interview hook**: *"Design ingest for 10M IoT sensors sending readings every minute."* → MQTT broker with topic hierarchy and QoS 0/1, not a WebSocket per device.

---

#### ⚖️ Gap 4 — Scaling Stateful WebSocket Fleets
- 🔹 **What it is**: The operational reality of running a large persistent-connection fleet — sticky routing, connection-state offloading, and broadcasting across nodes.
- 🔹 **Why it matters**: A WS server holds OS-level state per connection (file descriptors, memory); you cannot freely move a connection between nodes, so load balancing, deploys, and fan-out all get harder than for stateless HTTP.
- 🔹 **Connection**: §E warns WS needs sticky LBs and §I sketches sharding by `hash(user_id)` with Redis pub-sub — this gap is the full picture behind those one-liners: why stickiness is mandatory and how a message reaches a user pinned to a different node.
- 🔹 **When needed**: 🔴 **Senior** — core to "design chat for 10M concurrent" (the §H advanced question) and any large real-time system-design round.
- 🔹 **Intuition**: A hotel guest is assigned one room key that only opens their room (sticky); to reach a guest, the front desk pages the right floor (pub-sub fan-out) rather than searching every room.
- 🔹 **If you go deeper**: Study how Slack/Discord shard gateway connections, Socket.IO's Redis adapter for cross-node broadcast, and graceful-drain strategies for deploying without dropping millions of live sockets.
- 🔹 **Interview hook**: *"A message is for user X, but X's socket lives on a different server — how does it get there?"* → publish to a shared bus (Redis/Kafka) keyed by user/room; the owning node is subscribed and pushes it down the socket.

---

### 🏆 Start here if you have limited time
1. **Scaling stateful WebSocket fleets** — directly answers the §H "10M concurrent chat" question that defines this topic in interviews.
2. **WebRTC** — the most common follow-up the moment a design touches video or audio.

---

### 🧭 Suggested Deep Dive Order
1. **Scaling stateful WS fleets** (~1h; unlocks the headline chat-at-scale design).
2. **WebRTC for P2P media** (~1h; high payoff for video/call prompts).
3. **MQTT and pub/sub fan-out** (~45 min; owns the IoT/telemetry branch).
4. **QUIC and HTTP/3** (~1h; transport-layer depth for senior/edge signaling).
