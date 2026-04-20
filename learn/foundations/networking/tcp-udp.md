# TCP and UDP — Reliability vs Speed

> **Prereq**: [IP](ip.md), [OSI](osi.md)
> **What you will understand by the end**: why IP alone isn't enough, what the 3-way handshake actually does, how TCP guarantees reliability (and what it costs), and why UDP is the right answer for video calls and DNS.

---

## A. Intuition First

### The analogy
- **TCP is a phone call.** You dial, the other side picks up, you exchange "hello, hello" to confirm both can hear each other, and then you speak. If you miss a word, you say "sorry, repeat that". When done, you both hang up.
- **UDP is dropping a paper airplane with a note.** You fold it, throw it, and hope it lands somewhere useful. No confirmation. No retry. Fast and cheap.

Both are valid. You use the phone to tell your bank your account number (you *need* them to hear every digit). You use paper airplanes in a gym where speed matters more than any one airplane landing.

### Why these *had* to exist

IP alone is:
- **Unreliable** — packets may be dropped, duplicated, reordered.
- **Unaddressed to a process** — an IP only identifies a machine, not the *app* on the machine.

You need a layer on top of IP to solve **both**. That layer is **L4 — Transport**. TCP and UDP are the two choices, each solving the "identify a process" problem but differing wildly on reliability.

---

## B. Mental Model

### Ports — the missing piece
IP gets you to a host. Port gets you to a process on that host.
- 80 = HTTP, 443 = HTTPS, 22 = SSH, 53 = DNS, 25 = SMTP.
- Ports 0–1023 are "well-known" (need root to bind). 1024–49151 are "registered". 49152–65535 are "ephemeral" (short-term client-side ports).

When your browser connects to Google, your OS picks an ephemeral source port (say 54321) and the destination is port 443. The 4-tuple `(src_ip, src_port, dst_ip, dst_port)` uniquely identifies that connection.

### TCP's three jobs
1. **Reliability** — lost packets are retransmitted; duplicates are dropped; out-of-order packets are reassembled.
2. **Connection** — an explicit handshake sets up shared state; an explicit teardown ends it.
3. **Flow & congestion control** — the sender slows down if the receiver or network is overwhelmed.

### UDP's zero jobs
UDP's only job is to carry a payload with ports attached. No connection, no retry, no ordering. If you want any of those, you build them yourself on top.

---

## C. Internal Working — Packet/Request Level

### TCP 3-way handshake

Every TCP connection begins with three packets:

```
Client                                Server
  │                                     │
  │ ─── SYN (seq=X) ──────────────────▶ │  "I want to talk, my seq starts at X"
  │                                     │
  │ ◀─── SYN+ACK (seq=Y, ack=X+1) ───── │  "OK, my seq starts at Y, I got your X"
  │                                     │
  │ ─── ACK (ack=Y+1) ────────────────▶ │  "Got it, we're connected"
  │                                     │
  │ ═══ data flows both ways ═════════ │
```

The handshake costs **1 round-trip time (RTT)** of latency before a single byte of data is sent. If your server is across the ocean at 200 ms RTT, that's 200 ms of pure setup. This is why connection reuse (keep-alive) and 0-RTT optimizations (TLS 1.3, QUIC) matter.

### How TCP guarantees reliable delivery

- **Sequence numbers**: every byte has a number. Receiver knows if bytes were skipped.
- **Acknowledgements (ACKs)**: receiver tells sender "I have up through byte N". If sender doesn't see an ACK within a retransmission timeout (RTO), it resends.
- **Sliding window**: sender can have many unacknowledged bytes in flight. The window size (advertised by the receiver) caps how much.
- **Fast retransmit**: if receiver sees 3 duplicate ACKs for byte N, it means N+1 was lost; retransmit immediately, don't wait for timeout.
- **Congestion control** (TCP Reno, Cubic, BBR): if the network drops packets, slow down. TCP literally probes for how much bandwidth exists and backs off when it sees signs of congestion.

### TCP teardown (FIN handshake)

```
Client              Server
  │── FIN ────────▶ │
  │◀── ACK ──────── │
  │◀── FIN ──────── │
  │── ACK ────────▶ │   (TIME_WAIT state here — 2×MSL, ~60s on Linux)
```

Either side can initiate. The side that does ends up in `TIME_WAIT` — a state where the socket is kept around to absorb any stragglers. At high connection churn, `TIME_WAIT` exhaustion is a real operational issue (Google "TIME_WAIT tuning").

### UDP — what a packet looks like

```
+----------------+----------------+
|  Source Port   | Destination Port|
+----------------+----------------+
|    Length      |   Checksum     |
+----------------+----------------+
|            Data                 |
+----------------+----------------+
```

8 bytes of header. That's it. No handshake, no state, no ordering.

### Walk-through: HTTPS request over TCP

1. Browser resolves `google.com` → 142.250.72.206 (DNS, via UDP usually).
2. OS opens a socket, picks ephemeral source port 54321.
3. **TCP handshake**: SYN → SYN+ACK → ACK. +1 RTT.
4. **TLS handshake**: ClientHello → ServerHello + cert → verify → key exchange. +1–2 RTTs (TLS 1.3 is 1 RTT; 1.2 is 2).
5. Finally, client sends `GET / HTTP/2`.
6. Server responds with 200 OK + HTML.
7. Connection kept alive for subsequent requests (HTTP/2 multiplexes many).
8. When idle long enough, connection closed via FIN handshake.

The whole "IP gets bytes to a host, TCP gets bytes to a process reliably, TLS encrypts, HTTP is the app-level protocol" stack is real and you can see it in Wireshark.

---

## D. Visual Representation

```
TCP                              UDP
─────────────────────────────    ──────────────────────────
Reliability: ✅  (retry, ACK)    Reliability: ❌
Ordering:    ✅  (seq numbers)   Ordering:    ❌
Handshake:   ✅  (3-way)          Handshake:   ❌
Flow ctrl:   ✅  (window)         Flow ctrl:   ❌
Header:      20 bytes min        Header:      8 bytes
Latency:     +1 RTT setup        Latency:     0-RTT
Use when:    correctness         Use when:    latency matters
             matters more        more than any one packet
             than latency
```

---

## E. Tradeoffs

### When TCP wins
- Anything where missing bytes breaks correctness: HTTP/S, SSH, file transfer, databases, email.
- Long-lived connections where per-packet overhead amortizes quickly.

### When UDP wins
- **DNS** — one query, one response. TCP's handshake would triple the cost.
- **Video/voice (WebRTC, RTP)** — late data is worse than lost data. Skipping a dropped audio frame is better than pausing to retransmit.
- **Gaming** — state updates at 60 Hz; a lost update is obsolete by the time a retry would arrive.
- **QUIC/HTTP/3** — runs on UDP specifically to avoid head-of-line blocking inherent to TCP, while implementing reliability at the application layer on its own terms.

### The head-of-line blocking problem (senior-level)
TCP guarantees in-order delivery. If packet 5 is lost, packets 6, 7, 8 can't be handed to the application until 5 is retransmitted — even if they've already arrived. This is fine for file transfer, bad for multiplexed streams (HTTP/2 suffers from it). QUIC fixes this by running independent streams over UDP.

### TCP's costs
- Handshake latency.
- Memory for per-connection state on the server (FDs, send/recv buffers, TCB). A server handling 1M concurrent TCP connections burns real RAM.
- `TIME_WAIT` pressure in high-churn workloads.

### UDP's costs
- Anything you want reliable, you implement yourself (ordering, retries, congestion control). This is hard. Most "UDP-based reliable protocols" people invent in prod are worse than TCP.

---

## F. Interview Lens

### Classic questions
- "Walk me through the TCP 3-way handshake." — know SYN, SYN+ACK, ACK by heart.
- "Why does DNS use UDP?" — latency, small payload, retries done at app layer.
- "What's `TIME_WAIT` and why does it exist?" — to absorb late packets so they don't corrupt a new connection reusing the same 4-tuple.
- "What is head-of-line blocking?" — covered above.
- "How does TCP know how fast to send?" — congestion control; slow start, then AIMD-style probing, backing off on loss.

### Pitfalls
- Saying "UDP is unreliable" without nuance. More precise: UDP provides *no reliability guarantees*; the app can add them.
- Thinking TCP is "secure". TCP has no encryption — that's TLS (L6).
- Confusing flow control (receiver-imposed) with congestion control (network-imposed).

### Depth by level
- **Junior**: knows TCP = reliable, UDP = fast. Knows HTTP uses TCP, DNS uses UDP.
- **Mid**: explains 3-way handshake, ports, sequence numbers, teardown.
- **Senior**: discusses head-of-line blocking, congestion control algorithms (Cubic vs BBR), `TIME_WAIT`, why QUIC exists.

---

## G. Real-World Mapping

- **HTTP/1.1, HTTP/2**: TCP.
- **HTTP/3, QUIC**: UDP (with reliability built into QUIC).
- **DNS**: UDP for queries under 512 bytes; falls back to TCP for larger (e.g., DNSSEC responses, zone transfers).
- **WebRTC** (Google Meet, Zoom p2p, Discord voice): UDP-based.
- **Kafka, PostgreSQL, Redis**: TCP.
- **Load balancers**: NLB (AWS) is TCP/UDP at L4. ALB is HTTP/HTTPS at L7 (TCP only).
- **Netflix video streaming**: actually TCP over HTTPS (because CDN caching + existing infra), even though the use case seems UDP-ish. The system design decision: reuse battle-tested HTTP infra over "the theoretically right" protocol.

---

## H. Questions

### Beginner
1. What does TCP guarantee that IP doesn't?
2. Why does HTTP use TCP but DNS use UDP?
3. What's a port and why do we need it in addition to an IP?

### Intermediate
1. Walk me through the 3-way handshake. What does each packet carry?
2. Why is TCP connection setup "expensive"? Quantify it.
3. What happens if a TCP packet is lost?
4. What's TCP congestion control — what is it reacting to?

### Advanced (interview)
1. Explain head-of-line blocking. How does HTTP/2 suffer from it, and how does HTTP/3 fix it?
2. `TIME_WAIT` — why does it exist and what operational problem does it cause at scale?
3. If I wanted to add reliability on top of UDP, what would I need to build? (Hint: QUIC.)
4. Design a heartbeat system for a long-lived connection pool. TCP keep-alive vs app-layer pings — pros/cons.
5. At what scale of concurrent connections do TCP per-connection buffers become your bottleneck? How do you mitigate?

---

## I. Mini Design Problem — "Pick the right protocol"

For each system, pick TCP or UDP and justify in one sentence:

| System | Answer | Reasoning |
|---|---|---|
| Bank transfer API | **TCP** | Every byte matters; we'd rather be slow than wrong. |
| Multiplayer FPS game state updates | **UDP** | 60 Hz updates; a dropped frame is obsolete before retry arrives. |
| DNS lookup | **UDP** | Small payload, app-layer retries, latency matters. |
| Database replication | **TCP** | Ordering + durability. |
| VoIP call audio stream | **UDP** (RTP) | Lost frame → silence blip; retry → worse. |
| VoIP signaling (call setup) | **TCP** (SIP over TCP) | Setup correctness matters; one-time cost. |
| Real-time stock ticker (broadcast) | **UDP** multicast | Many receivers; late data is wrong data anyway. |
| File upload | **TCP** (HTTPS) | Byte-accurate. |

Being able to answer this table fluently = senior signal.

---

## J. Cross-Topic Connections
- **[IP](ip.md)** — TCP and UDP run *on top of* IP.
- **[DNS](dns.md)** — uses UDP (mostly).
- **[Load Balancing](../scaling/load-balancing.md)** — L4 LBs operate on TCP/UDP.
- **[Long-polling / WebSockets / SSE](../../architecture/long-polling-websockets-sse.md)** — all run over TCP.
- **[SSL/TLS](../../reliability/ssl-tls-mtls.md)** — handshake cost *on top of* TCP handshake.

---

## K. Confidence Checklist
- [ ] I can explain 3-way handshake with exact packet types.
- [ ] I know why DNS picked UDP and can defend it.
- [ ] I know what a port is and the rough port ranges.
- [ ] I can define head-of-line blocking.
- [ ] I know `TIME_WAIT` exists and what it's for.

### Red flags
- ❌ "TCP is reliable and secure." No — TLS does security.
- ❌ Can't explain why HTTP/3 moved to UDP.
- ❌ Treats ports as interchangeable with IPs.

---

## L. Potential Gaps & Improvements
- Congestion control deserves a dedicated deep-dive (slow start, AIMD, Cubic vs BBR).
- Nagle's algorithm and `TCP_NODELAY` — classic interview topic I glossed over.
- TCP buffer sizes and how they interact with bandwidth-delay product (BDP).
- SCTP (a third transport protocol used in telecom) — rarely asked but worth 10 min.
- QUIC deserves its own file since it's the future of the transport layer.

**How to close:** run `ss -tan` on a live server and read the states (ESTABLISHED, TIME_WAIT, FIN_WAIT). Seeing real counts is more educational than any theory.
