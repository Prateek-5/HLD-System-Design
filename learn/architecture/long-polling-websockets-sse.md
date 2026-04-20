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
- WebRTC for p2p (different beast).
- QUIC / HTTP/3 streaming.
- MQTT for IoT.
