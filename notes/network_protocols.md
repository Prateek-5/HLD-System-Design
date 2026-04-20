# Network Protocols — TCP, HTTP, QUIC, WebRTC, WebSocket

### 🔹 1. What This Topic Actually Is
The wire formats and protocols that carry your bytes. Interview focus: understand HTTP versions, TCP vs UDP, QUIC's role, when to use WebSocket vs SSE vs WebRTC.

### 🔹 2. Why It Exists
- The choice of protocol changes latency, reliability, and server cost by orders of magnitude.
- Senior design requires "why HTTP/3?" or "why WebSocket over polling?" answers.

### 🔹 3. Core Concepts (High Signal)
- **TCP**: reliable, ordered, flow + congestion controlled. 3-way handshake. Head-of-line blocking.
- **UDP**: unreliable, unordered, no handshake. Fire-and-forget.
- **HTTP/1.1**: one request per connection (keep-alive reuses connection but serializes requests).
- **HTTP/2**: multiplexed streams over one TCP connection. Solves per-resource handshake cost. Still HOL-blocked by TCP.
- **HTTP/3 (QUIC)**: runs on UDP. Independent streams → no cross-stream HOL block. Faster handshake (0-RTT resumption). Integrated TLS 1.3.
- **WebRTC**: p2p audio/video/data over UDP (via SRTP/DTLS). ICE/STUN/TURN for NAT traversal.
- **WebSocket**: full-duplex over TCP, starts as HTTP upgrade. Used for chat, games, realtime.
- **SSE (Server-Sent Events)**: unidirectional server→client HTTP stream. Auto-reconnects. Simpler than WS when only server-push needed.
- **gRPC**: HTTP/2 + protobuf. Binary, fast, typed, multi-language.
- **TCP congestion control**: classic paper (Jacobson's "Congestion Avoidance and Control"). Modern: Cubic, BBR (Google).

### 🔹 4. Internal Working
**HTTP/1.1 request**: DNS → TCP (1 RTT) → TLS (1–2 RTT) → send request → serialized response.
**HTTP/2**: multiple requests multiplexed over one TCP/TLS stream.
**QUIC (HTTP/3)**: combines TCP + TLS into one handshake (1-RTT new, 0-RTT resumption); parallel streams not blocked by per-stream loss.
**WebSocket**: HTTP Upgrade → switch protocol → bidirectional frames.

**Failure points:** HOL blocking (HTTP/2), TLS handshake cost (reduced by session resumption), NAT issues (WebRTC), proxy/CDN compatibility for WebSocket.

### 🔹 5. Key Tradeoffs
- **TCP**: default for correctness. HOL block can hurt.
- **UDP + QUIC**: avoids HOL block; handles loss per-stream.
- **WS vs SSE vs long-polling**: pick based on directionality and server cost.
- **gRPC**: internal microservices default; not browser-native (need gRPC-web).

### 🔹 6. Interview Questions
**Beginner**
1. TCP vs UDP?
2. Why does HTTP/2 multiplex?

**Intermediate**
1. What's HOL blocking and how does HTTP/3 fix it?
2. WS vs SSE — pick for notification bell.

**Advanced**
1. Why did Google design QUIC over UDP, not improve TCP?
2. BBR vs Cubic congestion control — when each?

### 🔹 7. Real System Mapping
- **Google**: pushed QUIC → HTTP/3; BBR congestion control.
- **Cloudflare**: QUIC everywhere.
- **Discord, WhatsApp**: WebSocket.
- **Meta Messenger**: custom HTTP/2-like for battery efficiency.
- **Zoom/Meet**: WebRTC + proprietary UDP.

### 🔹 8. What Most People Miss
- **TLS 1.3 reduces handshake to 1 RTT** (0 on resumption). Upgrade aggressively.
- **HTTP/2 still suffers HOL blocking on TCP** — one lost packet stalls all streams. HTTP/3 fixes.
- **QUIC's real win** is mobile networks that flap — it identifies connections by a connection ID, not IP:port, so switching Wi-Fi → LTE mid-call doesn't drop it.
- **WebSocket + CDN is tricky** — not all CDNs support persistent upgrades.
- **Nagle's algorithm** + TCP_NODELAY: classic latency-vs-bandwidth knob; always disable Nagle for interactive workloads.

### 🔹 9. 30-Second Revision
TCP reliable; UDP fast. HTTP/1.1 serialized; HTTP/2 multiplexed but TCP HOL; HTTP/3 = QUIC over UDP, per-stream. WebSocket = bi-dir persistent; SSE = server-push only. gRPC = HTTP/2 + protobuf for internal. TLS 1.3 is 1-RTT. BBR beats Cubic on noisy links.

---

## 🔗 Cross-Topic Connections
- **Load Balancing**: L4 handles TCP/UDP; L7 HTTP.
- **TLS**: handshake latency shaped by protocol choice.
- **Caching (CDN)**: HTTP cache semantics.
- **Real-time push (WS/SSE)**: at the client boundary.

---

### Confidence Check
- [ ] Can I compare WS / SSE / long-poll by requirement?
- [ ] Can I explain why HTTP/3 matters on mobile?

### Gaps
- BBR internals (bandwidth-delay product probing).
- WebRTC signaling + TURN complexities.
