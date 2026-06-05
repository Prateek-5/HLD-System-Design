# TCP & Network Fundamentals

> *"Every distributed system you've ever built sits on top of TCP. The decisions made by Vint Cerf and Bob Kahn in 1974 about how to make unreliable IP packets feel like reliable streams shape every API latency, every connection limit, every cascading failure you've ever debugged. The fact that most engineers don't think about TCP is a testament to how well it works — until the day it's the bottleneck."*

## 🎯 Start Here — Intuition

> **In one line:** the internet only knows how to fling tiny packets that can get lost, duplicated, or arrive out of order — TCP is the machinery that turns that mess into a reliable, in-order stream of bytes your app can just read and write.
>
> **Analogy:** mailing a long book one postcard at a time. Postcards get lost, arrive jumbled, sometimes show up twice. So you number each card, the reader says "got 1–5, send me 6," you re-mail anything they never confirmed, and you slow down if the post office looks swamped. The reader ends up with the whole book, in order — that bookkeeping is TCP.
>
> **New to this?** Build the basics first in [`learn/foundations/networking/tcp-udp.md`](../../learn/foundations/networking/tcp-udp.md) — *then* come back for the depth.
>
> **Level:** this file is 🟡/🔴 overall. The handshake and the postcard intuition are approachable; congestion-control algorithms, connection state machines, and kernel tuning are senior-level. Sections below are tagged. If the basics feel shaky, that tag is your signal to slow down — **you are not behind.**

---

## Topic Overview 🟢

TCP (Transmission Control Protocol) is the layer that turns the internet's lossy, reordering, packet-dropping reality into the smooth byte streams your application code reads from. HTTP, gRPC, databases, message queues — almost every connection your service makes is TCP underneath. The protocol is half a century old; its core ideas have aged remarkably well; its quirks shape modern system design in ways most engineers don't notice until something breaks.

The fundamentals: handshakes (the SYN/SYN-ACK/ACK three-way), congestion control (slow start, AIMD, modern algorithms like BBR), flow control (sliding windows), retransmission (timeouts, fast retransmit), connection state machines (TIME_WAIT, CLOSE_WAIT). Each is a piece of engineering shaped by the network's reality.

This is the topic where the abstraction leaks. When your service is slow under load, when your connection pool exhausts, when your application sees mysterious resets — the answers live in TCP. Understanding the layer below your application is what separates "the network is unreliable" hand-waving from "the SYN backlog filled because Accept() can't keep up" diagnosis.

---

## Intuition Before Definitions 🟢

Imagine sending a long letter to someone, but only being allowed to use postcards.

The naive way: number the postcards (1, 2, 3...), mail them. The recipient reassembles them. But: postcards get lost. Some arrive out of order. Some duplicate.

The TCP way:
- Recipient acknowledges each batch ("got 1-5; awaiting 6").
- Sender retransmits anything not acknowledged within a reasonable time.
- Recipient buffers out-of-order arrivals; reassembles in order.
- Sender slows down if losses suggest the postal system is overwhelmed.
- Recipient tells sender "stop, my mailbox is full" if they're behind.

The end result: the recipient gets the original letter, in order, complete. The unreliable post becomes a reliable channel — at the cost of some round-trips, some buffering, some adaptive pacing.

That's TCP. The network is the postal system; postcards are packets; TCP turns them into streams. Every guarantee you take for granted (in-order delivery, no duplicates, no losses, fairness with other senders) is something the protocol works for, behind your application's abstraction.

---

## Historical Evolution 🟡

**Era 1 — ARPANET protocols.**
1970s. NCP and others. Cerf and Kahn publish TCP/IP design (1974). Implementation deployed on ARPANET.

**Era 2 — TCP/IP standardization.**
1981-1983. RFC 793 (TCP), RFC 791 (IP). Internet adopts TCP/IP.

**Era 3 — Congestion collapse and recovery.**
1986. Internet experiences "congestion collapse" — too much retransmission saturates links. Van Jacobson's congestion control (1988) fixes it. Slow start, AIMD established.

**Era 4 — TCP improvements.**
1990s-2000s. SACK, ECN, window scaling, timestamps. Each fixes a specific shortcoming.

**Era 5 — Modern congestion control.**
2010s. CUBIC (default in Linux), BBR (Google, 2016). New algorithms tuned for modern networks (high-bandwidth, high-latency).

**Era 6 — Beyond TCP.**
QUIC (2012-2021) replaces TCP for HTTP/3. UDP-based, but with TCP-like reliability features. Google's bet that the OS-kernel TCP stack is too slow to evolve.

The pattern: TCP is a half-century-old protocol still used unchanged for most traffic. Its quirks shape modern system design.

---

## Deep Technical Explanation 🔴

> ⚠️ The rest assumes the basics above are solid — handshake, ACKs, and the postcard intuition.

### The three-way handshake

```
Client                Server
  |  ---- SYN ---->     |
  | <-- SYN-ACK --      |
  |  ---- ACK ---->     |
  |   (data flows)      |
```

- **SYN**: client says "I want to talk; my initial sequence is X."
- **SYN-ACK**: server says "OK; my initial sequence is Y; I acknowledge X+1."
- **ACK**: client acknowledges Y+1.

After this, both sides know each other's sequence numbers; data can flow.

Cost: 1 RTT before any data. For a Singapore-to-US connection (200ms RTT), that's 200ms before the first byte.

TCP Fast Open (RFC 7413) lets data flow with the SYN under specific conditions. Reduces overhead for re-connections.

### Sequence numbers and acknowledgments

Each byte has a sequence number. Receiver acknowledges the next expected byte.

If receiver gets bytes 1-1000 then 2001-3000 (1001-2000 missing): they ACK 1001 (expecting 1001 next). Sender realizes 1001-2000 may be lost.

**Cumulative ACK**: ACK X means "I've received everything up through X-1."

**Selective ACK (SACK)**: ACK 1001 + "I also have 2001-3000." Lets sender retransmit only the missing range.

### Retransmission

Two mechanisms:

**Timeout-based.** Sender starts a timer when sending; if no ACK, retransmit.

**Fast retransmit.** Three *duplicate* ACKs (the original ACK plus three more repeating the same number, e.g., ACK 1001, 1001, 1001, 1001) signal a missing packet — retransmit immediately, don't wait for timeout.

Modern stacks use both. Fast retransmit is much faster than timeout for single losses.

### Congestion control — Tahoe, Reno, CUBIC, BBR

The challenge: send as fast as possible without congesting the network. Loss = signal of congestion.

**Slow start.**
Historically started with cwnd=1 segment; modern stacks use an initial window of ~10 segments (IW10, RFC 6928). Double per RTT until first loss. Exponential ramp.

**Congestion avoidance (AIMD).**
After slow start, increase cwnd by 1 per RTT (additive). On loss, halve (multiplicative). The sawtooth pattern.

**TCP Reno** (1990): the classic implementation.

**TCP CUBIC** (default on Linux since ~2006): cubic function instead of linear. Better for high-bandwidth high-latency links.

**BBR** (Google, 2016): doesn't use loss as congestion signal. Models bandwidth and RTT. Performs better on lossy links (mobile, wireless). Not yet universal.

The differences matter. A flow with BBR can outperform CUBIC by orders of magnitude on lossy networks.

### Flow control vs congestion control

These are different things:

- **Flow control**: receiver-driven. "My buffer is X bytes; don't send more." Uses the receive window in TCP headers.
- **Congestion control**: network-driven. "The network is congested; back off." Uses the sender-side congestion window.

Effective window = min(receive window, congestion window). Whichever is smaller limits the rate.

### Window scaling

Original TCP receive window: 16 bits = 64KB max. On a 100ms RTT 1Gbps link: ideal window is 12.5MB. 64KB caps throughput at ~640KB/s.

Window scaling option (RFC 1323): multiply receive window by 2^N. Modern systems use scaling factor 7 or higher.

If both sides don't enable scaling, throughput is bandwidth-delay-product limited. A common production tuning issue.

### Nagle's algorithm and delayed ACKs

**Nagle (RFC 896)**: don't send small packets if there's already unacknowledged data. Buffer until ACK arrives or buffer fills.

**Delayed ACK**: receiver waits ~40ms before ACKing, hoping to piggyback on outgoing data.

Together: a small write that waits for an ACK that's waiting for outgoing data → 40-200ms latency. The infamous "200ms latency for short writes" bug.

Mitigation: `TCP_NODELAY` socket option (disable Nagle). Used by default in many high-performance servers and most web frameworks.

### Connection state machine

TCP connections have states:
- **LISTEN**: server waiting.
- **SYN_SENT, SYN_RECEIVED**: handshake.
- **ESTABLISHED**: data flowing.
- **FIN_WAIT_1, FIN_WAIT_2**: closing initiated.
- **CLOSE_WAIT**: passive close pending.
- **TIME_WAIT**: post-close wait period.

**TIME_WAIT** is a famous source of operational pain. After active close, the connection sits in TIME_WAIT for 2 × MSL (typically 60-120 seconds). This prevents stale packets from interfering with new connections on the same port pair.

A server with high connection churn accumulates many TIME_WAIT entries. If port range exhausts, new connections fail. Mitigations: connection reuse, larger ephemeral port range, `SO_REUSEADDR`/`SO_REUSEPORT`.

### Connection establishment cost at scale

TLS adds 1-2 RTTs. So:
- TCP: 1 RTT.
- TCP + TLS 1.2: 2-3 RTTs.
- TCP + TLS 1.3: 1-2 RTTs.
- TLS 1.3 with 0-RTT: 0 RTTs (with replay risk).

For services hitting many backends per request, each new connection is expensive. Connection pooling is mandatory.

### MTU and fragmentation

**MTU (Maximum Transmission Unit)**: largest packet a network can carry. Ethernet typically 1500 bytes.

If a packet exceeds MTU, IP fragmentation breaks it into smaller pieces. Reassembly at destination. Inefficient and prone to failure.

TCP's **Path MTU Discovery** finds the smallest MTU on the path; sends packets that fit. Modern TCP avoids fragmentation.

Network changes (VPNs, tunnels) reduce MTU. PMTUD failures cause connections that establish but can't send data — a classic "blackhole" failure.

### Connection limits

OS limits:
- **File descriptors per process**: typically 1024 default; tunable to millions.
- **Ports per IP**: ~65000 ephemeral; effective limit usually lower.
- **Backlog (listen queue)**: pending connections; if full, SYNs are dropped.

A high-traffic server tunes all of these. Linux's `net.core.somaxconn`, `net.ipv4.tcp_max_syn_backlog`, ulimit -n. Default values are low for production.

### TCP keepalives

After establishment, long-idle connections may be silently dropped by NATs, firewalls. Keepalives detect:
- After idle period, send a keepalive probe.
- If no response after retries, declare connection dead.

Default: idle 7200s, then 9 probes 75s apart. Way too long for most use cases. Application-level heartbeats are more common.

### Slow start after idle

After an idle period, many TCP implementations restart slow start. A connection that's been quiet for seconds re-ramps from the initial window (IW10).

This causes "first request after idle is slow." Long-lived HTTP connections used periodically can be surprisingly slow on the first request after idle.

`net.ipv4.tcp_slow_start_after_idle = 0` disables this on Linux.

### TCP and modern challenges

**Lossy mobile networks**: BBR helps; CUBIC suffers.

**High-bandwidth high-latency**: needs window scaling, large initial cwnd.

**Head-of-line blocking**: a single lost packet blocks all later data; HTTP/2 multiplexing makes this worse. HTTP/3 uses QUIC over UDP to avoid.

**Connection setup cost**: TLS handshakes; mitigations include TLS 1.3, 0-RTT.

---

## Real Engineering Analogies 🟢

**The reliable letter exchange.**
Two scribes corresponding via unreliable mail. They number letters; acknowledge by number; resend missing ones; pace based on perceived congestion. Same protocol; the "letter" is the byte; the "post office" is the IP layer.

**The factory inventory pipeline.**
A factory ships products to a warehouse via trucks. Trucks sometimes break down (lost packets). The warehouse acknowledges receipts; the factory retransmits what's missing. The pipeline pacing adapts to the rate the warehouse can unload.

---

## Production Engineering Perspective 🔴

What goes wrong:

- **The TIME_WAIT exhaustion.** Service makes many short connections; ephemeral ports fill with TIME_WAIT entries. New connections fail. Mitigation: connection reuse; port range; `SO_REUSEADDR`.
- **The undisabled Nagle.** Small writes have 40-200ms latency due to Nagle + delayed ACK. Fix: `TCP_NODELAY`.
- **The PMTU blackhole.** VPN reduces MTU; PMTUD broken; connections establish but data drops. Fix: MTU clamping; ICMP not blocked.
- **The accept queue overflow.** Connections accepted faster than `accept()` calls. Backlog fills; SYNs dropped; connections fail. Fix: increase `somaxconn`, `tcp_max_syn_backlog`; faster accept loop.
- **The slow-start surprise.** Connections idle 5 minutes; first request after is slow due to restart. Mitigation: disable slow start after idle; use HTTP/2 multiplexing.
- **The connection pool too small.** App opens new TCP connections per request; each is 1 RTT + TLS. Fix: connection pooling.
- **The CDN connection breakage.** TCP connections through CDN are persistent; certificates rotate; connections must reconnect; cascading reconnect storm. Mitigation: gradual rollout.

---

## Failure Scenarios 🔴

**Scenario 1 — The TIME_WAIT epidemic.**
Web service hits backend with new connection per request. Backend's port range fills with TIME_WAIT. Connection failures cascade. Recovery: connection pooling deployed.

**Scenario 2 — The Nagle bug.**
Custom TCP protocol; small writes; 200ms latency mystery. Investigation: Nagle + delayed ACK. Fix: TCP_NODELAY.

**Scenario 3 — The MTU blackhole.**
New VPN deployed; some users can't reach service. Connections establish (small SYN); fail when actual data flows (large packets). Fix: MTU clamping.

**Scenario 4 — The accept queue overflow.**
Traffic spike; accept loop blocks on processing; backlog fills; new connections drop. Fix: dedicated accept thread; larger backlog.

**Scenario 5 — The mobile-network BBR win.**
Service used CUBIC; mobile users had poor performance. Switching to BBR: 5× throughput on lossy mobile links. No code change; kernel tuning.

---

## Performance Perspective 🟡

- **TCP handshake**: 1 RTT.
- **TLS 1.2 handshake**: 2 RTTs additional.
- **TLS 1.3 handshake**: 1 RTT additional.
- **0-RTT (TLS 1.3)**: 0 RTTs additional.
- **Per-connection memory**: ~10KB in kernel.
- **Throughput**: bandwidth × delay product caps a single connection.

---

## Scaling Perspective 🟡

- **Per-process connections**: tens of thousands easy; millions with tuning (epoll/kqueue/IOCP).
- **Per-host**: limited by ports, file descriptors, memory.
- **Across hosts**: load balancers distribute connections.
- **At hyperscale**: custom TCP stacks (Google's BBR, Facebook's TCP), or skipping TCP (QUIC).

---

## Cross-Domain Connections 🟡

- **Backpressure**: TCP's flow control is the original backpressure. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Cascading failures**: connection-pool exhaustion is a TCP-level cascade. (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)
- **HTTP/2 and HTTP/3**: protocols on top of TCP and beyond. (See [http-2-and-http-3.md](./http-2-and-http-3.md).)
- **Load balancing**: routes TCP connections. (See [load-balancing-strategies.md](../scalability/load-balancing-strategies.md).)
- **Edge computing**: TCP characteristics drive edge network design. (See [edge-computing-and-cdns.md](../scalability/edge-computing-and-cdns.md).)
- **Node.js / libuv**: epoll/kqueue handle TCP events. (See [nodejs-architecture-and-libuv.md](../js-runtime/nodejs-architecture-and-libuv.md).)

The unifying observation: **TCP is the layer between every application and the network. Its quirks shape the latency, throughput, and failure modes of every distributed system. Understanding TCP isn't optional; it's foundational.**

---

## Real Production Scenarios 🔴

- **Google's BBR rollout**: documented engineering posts on the design and benefits.
- **Cloudflare's TCP tuning**: extensive public posts on kernel parameters.
- **Linux's TCP defaults**: discussed at length in kernel mailing lists.
- **The "TCP for high-performance servers" tradition**: Engelschall, Matthew Dillon, others.
- **AWS's enhanced networking**: documents that bypass parts of the kernel TCP stack.

---

## Key Takeaways

- **TCP turns lossy, reordering packets into an ordered, reliable byte stream.** That translation is the whole point; every guarantee (in-order, no dupes, no loss, fairness) is something the protocol works for behind your application.
- **Connection establishment costs RTT.** Three-way handshake = 1 RTT before any data; TLS 1.2 adds 2, TLS 1.3 adds 1, 0-RTT adds 0 (with replay risk). For services hitting many backends per request, connection pooling is mandatory.
- **Congestion control vs flow control are distinct.** Congestion control is network-driven (sender backs off on loss; this is what keeps the internet from collapsing). Flow control is receiver-driven (advertised window: "my buffer is X bytes"). Effective rate = min(receive window, congestion window).
- **Slow start ramps exponentially** (modern IW10 initial window, doubling per RTT until loss); **AIMD** then adds 1/RTT and halves on loss (the sawtooth). **CUBIC** is the Linux default; **BBR** ignores loss as a signal and models bandwidth/RTT, outperforming CUBIC by up to ~5x on lossy mobile/wireless links — often a kernel-tuning win with no code change.
- **Nagle + delayed ACK** can stack into 40-200ms latency on small writes; disable with `TCP_NODELAY` for latency-sensitive paths.
- **TIME_WAIT** accumulates under high connection churn (2 × MSL, ~60-120s) and can exhaust ephemeral ports. Mitigate with connection reuse, larger port range, `SO_REUSEADDR`/`SO_REUSEPORT`.
- **Window scaling** (RFC 1323) is required for high bandwidth-delay-product links; without it a single connection is BDP-capped (64KB window → ~640KB/s on a 100ms link).
- **Slow start after idle** re-ramps cwnd from the initial window, making the first request after an idle period slow; disable with `net.ipv4.tcp_slow_start_after_idle = 0`.
- **MTU/PMTUD failures cause blackholes**: connections establish on small SYNs but silently drop large data packets (common after VPNs/tunnels). Fix with MTU clamping and unblocked ICMP.
- **Default kernel params are low for production.** Tune `net.core.somaxconn`, `net.ipv4.tcp_max_syn_backlog`, and `ulimit -n`; a slow `accept()` loop overflows the backlog and drops SYNs.
- **Connection state machines explain "weird network bugs."** TIME_WAIT, CLOSE_WAIT, FIN_WAIT states are diagnostic gold; monitor connection-state counts.
- **Use HTTP/2 or HTTP/3** to reduce per-connection overhead; HTTP/3 (QUIC over UDP) avoids TCP's head-of-line blocking, where one lost packet stalls all later data.
- **Senior instinct:** pool connections by default, tune the kernel, monitor TIME_WAIT, plan for TLS handshake cost. TCP problems usually arrive wearing application-level disguises — pool exhaustion, mystery latency, reconnect storms, MTU blackholes — which is why understanding the layer below your application is foundational, not optional.

## Interview angle

- **"Walk me through the TCP handshake."** SYN / SYN-ACK / ACK; sequence-number exchange; 1 RTT before data.
- **"What's TIME_WAIT?"** Post-close state (2 × MSL) preventing stale packets from corrupting a new connection on the same port pair.
- **"What's Nagle's algorithm?"** Buffers small writes while unacked data is outstanding; interacts badly with delayed ACK.
- **"Congestion control vs flow control?"** Network-driven vs receiver-driven — a common trap is confusing the two.
- **"What's slow start?"** Exponential cwnd ramp at connection start.
- **"BBR vs CUBIC?"** Loss-based (CUBIC) vs bandwidth/RTT-model-based (BBR), the latter better on lossy links.
- Common trap: not accounting for TLS handshake RTT costs on top of the TCP handshake.
