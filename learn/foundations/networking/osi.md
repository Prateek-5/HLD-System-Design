# OSI Model — The Mental Map of All Networking

> **Prereq**: [IP](ip.md)
> **What you will understand by the end**: why engineers still use OSI as a vocabulary even though TCP/IP is what actually runs the internet, what happens at each layer, and why debugging becomes 10× faster when you know which layer is broken.

---

## A. Intuition First

### The analogy

Think of sending a letter internationally.
- **You** write the message (Application).
- **You** translate it into English so the recipient can read it (Presentation).
- **You** seal the envelope, write "this is correspondence #5 of 12" (Session).
- The **post office** checks the destination is reachable and breaks large packages into smaller ones (Transport).
- The **postal routing network** figures out which country, then which city (Network).
- The **local delivery service** physically hands it from truck to mailbox (Data Link).
- The **road/mailbox** is the literal physical medium (Physical).

Each step is independent. The sender doesn't need to know which airline carried the letter. The airline doesn't care what's written inside. **Separation of concerns** is the entire point.

### Why it *had* to exist

In the 1970s, every vendor had their own networking stack (IBM SNA, DEC DECnet, Xerox XNS). A minicomputer from Vendor A literally could not talk to one from Vendor B. The ISO (International Organization for Standardization) proposed OSI in 1977 as a **vendor-neutral reference model**: if everyone splits their stack into the same 7 layers with the same contracts between layers, everyone interoperates.

OSI the *protocol suite* lost to TCP/IP. OSI the *reference model* won completely. Engineers today say "that's a Layer 7 problem" and everyone knows what they mean.

---

## B. Mental Model

**Two core insights:**

1. **Each layer talks to its peer.** Layer 4 on your laptop logically talks to Layer 4 on the server. It doesn't care how Layer 3 delivers its bytes.
2. **Each layer adds a header, peels a header.** As data goes *down* the stack on the sender, each layer adds its own header. As data goes *up* on the receiver, each layer peels it off. This is called **encapsulation**.

```
Sender                             Receiver
[Application data            ]     [Application data            ]
[TCP hdr | Application data  ]     [TCP hdr | Application data  ]
[IP  | TCP | Application data]     [IP  | TCP | Application data]
[Ether|IP|TCP|Application data]    [Ether|IP|TCP|Application data]
        ↓                                   ↑
        └───── wire ──────────────────────→ ┘
```

This is why Wireshark / tcpdump output shows nested headers when you capture a packet.

---

## C. Internal Working — The Seven Layers

### L7 — Application
- **Examples**: HTTP, HTTPS, FTP, SMTP, DNS.
- **What it does**: generates the meaningful content. A browser's GET request starts here.
- **Unit**: "message" or "data".

### L6 — Presentation
- **Examples**: TLS/SSL (partly), JPEG/PNG encoding, character encoding (UTF-8).
- **What it does**: translation, compression, encryption. Ensures the sender and receiver agree on format.
- In practice, modern TCP/IP conflates L5/L6/L7 into "application". But TLS is a useful mental home at L6.

### L5 — Session
- **Examples**: NetBIOS, RPC session layer, SQL sessions.
- **What it does**: establishes, manages, terminates "conversations" between apps. Checkpoints so a broken transfer resumes.
- Again, in the modern stack, sessions are often handled inside the application.

### L4 — Transport
- **Examples**: TCP, UDP.
- **What it does**: end-to-end delivery between processes. Uses **port numbers** to address the right process on the host. TCP adds reliability; UDP does not.
- **Unit**: TCP "segment" / UDP "datagram".

### L3 — Network
- **Examples**: IP, ICMP, routing protocols (BGP, OSPF).
- **What it does**: routes packets across multiple networks. This is where IP addresses and longest-prefix matching live.
- **Unit**: "packet".

### L2 — Data Link
- **Examples**: Ethernet, Wi-Fi (802.11), PPP.
- **What it does**: delivery between *adjacent* nodes on the same physical network. Uses **MAC addresses**. Handles collision detection (CSMA/CD for Ethernet).
- **Unit**: "frame".

### L1 — Physical
- **Examples**: copper cables, fiber optics, radio waves, the electrical signaling spec.
- **What it does**: turns bits into physical signals (voltage changes, pulses of light, radio waves).
- **Unit**: "bit".

---

## D. Visual Representation

```
┌─────────────────────────────────────────────────────────────────┐
│ L7 Application     │ HTTP, DNS, SMTP        │ "message"         │
├─────────────────────────────────────────────────────────────────┤
│ L6 Presentation    │ TLS, JPEG, UTF-8       │ "data"            │
├─────────────────────────────────────────────────────────────────┤
│ L5 Session         │ sockets, RPC sessions  │ "data"            │
├─────────────────────────────────────────────────────────────────┤
│ L4 Transport       │ TCP, UDP               │ "segment"/"dgram" │  ← ports
├─────────────────────────────────────────────────────────────────┤
│ L3 Network         │ IP, ICMP, BGP          │ "packet"          │  ← IPs
├─────────────────────────────────────────────────────────────────┤
│ L2 Data Link       │ Ethernet, Wi-Fi        │ "frame"           │  ← MACs
├─────────────────────────────────────────────────────────────────┤
│ L1 Physical        │ copper, fiber, radio   │ "bit"             │
└─────────────────────────────────────────────────────────────────┘
```

**One trick for remembering**: "**A**ll **P**eople **S**eem **T**o **N**eed **D**ata **P**rocessing" (L7 → L1).

---

## E. Tradeoffs

### OSI vs TCP/IP
- OSI has 7 layers; TCP/IP in practice has 4 (Link, Internet, Transport, Application).
- TCP/IP collapses L5–L7 into "Application" and L1–L2 into "Link". For most discussions this is fine.
- OSI lost as a protocol suite because TCP/IP was simpler, already deployed, and free (US gov funded). OSI won as a *vocabulary*.

### Why the layered model is not perfect
- Modern reality blurs layers: TLS spans L5/L6, QUIC replaces both TCP and parts of TLS, HTTP/3 runs on QUIC over UDP.
- Some protocols cheat (e.g., ICMP sits at L3 but is neither routed nor addressed like normal packets).
- "Layer violations" — an optimization that lets a higher layer peek into a lower layer's state — are common in high-performance systems.

---

## F. Interview Lens

### What interviewers actually ask
- "What layer does a load balancer operate at?" — L4 or L7. The difference is enormous (L4 balancers cannot route on URL path; L7 can).
- "Is HTTPS layer 7 or layer 6?" — HTTP is L7, TLS is L6 (or "between" L6 and L7 depending on who you ask).
- "What layer does a switch operate at? A router?" — switch L2, router L3.
- "If I can ping a server but not curl it, which layer is the problem?" — L4+ (TCP or application). Ping uses ICMP at L3, so L3 is fine.

### The "what layer is the problem" debugging script
Learn this script. It's how seniors actually debug:

1. **L1** — is the cable plugged in? `ip link` on Linux.
2. **L2** — is the device on the LAN? `arp -a` shows neighbors.
3. **L3** — can I reach it? `ping <ip>`. ICMP → L3 reachability.
4. **L4** — is the port open? `nc -zv host 443` or `telnet host 443`.
5. **L7** — does the app respond correctly? `curl -v`.

When you walk into an interview and say "I'd debug top-down: does the HTTP response come back? No → then I'd check TCP with `nc`. Also fails → I'd check `ping`...", you look like a senior.

### Common pitfalls
- Memorizing "**A**ll **P**eople **S**eem **T**o **N**eed **D**ata **P**rocessing" but not understanding what each layer *does*.
- Thinking switches do routing. No — switches operate on MAC addresses (L2). Routers operate on IPs (L3).
- Forgetting that TLS is a layer; treating HTTPS as "magic encryption on HTTP".

---

## G. Real-World Mapping

- **AWS**: ELB (Classic) is L4/L7. ALB is L7 only. NLB is L4 only. Understanding which one you need *is* a layered-model question.
- **Kubernetes Service types**: ClusterIP and NodePort are L4. Ingress is L7.
- **CDN**: operates at L7 for HTTP caching, but Anycast routing (how you reach the nearest edge) is L3.
- **Firewalls**: traditional firewalls filter on L3/L4 (IP + port). Next-gen firewalls inspect L7 (do deep packet inspection into HTTP).

---

## H. Questions

### Beginner
1. What are the 7 layers of the OSI model?
2. What's the difference between a switch and a router in OSI terms?
3. What layer is HTTP at?

### Intermediate (Why / How)
1. Why do we even use layering? What would break if we didn't?
2. What's encapsulation and why is it necessary?
3. What layer does TLS sit at, and why is there disagreement?
4. Why did TCP/IP win over OSI as the actual internet stack?

### Advanced (Interview)
1. A user's request fails. Walk me through how you'd diagnose which layer is broken.
2. Explain the tradeoffs between an L4 and L7 load balancer. When would you pick each?
3. HTTP/3 runs over QUIC which runs over UDP. Map that onto the OSI layers. What did the designers get by breaking tradition?
4. If you were designing a new networking stack from scratch in 2025, would you keep 7 layers? Why or why not?

---

## I. Mini Design Problem — "Which layer is the bottleneck?"

Scenario: users report that your web app is slow. You have one giant monolith server serving HTTP.

**Diagnostic walk (layer by layer):**
- **L1/L2**: is the NIC saturated? (`iftop`, link speed) → maybe you need a bigger instance.
- **L3**: is there network-level latency between user and server? → maybe you need a CDN / edge nodes.
- **L4**: are TCP handshakes piling up? Are you hitting file descriptor limits? → tune kernel, add load balancer.
- **L6**: is TLS the bottleneck? Every new connection pays TLS handshake cost → session resumption, TLS termination at LB.
- **L7**: is the app just slow at rendering? → profiling, caching, DB indexes.

Almost every real performance problem maps cleanly to a layer. This is why the model is useful.

---

## J. Cross-Topic Connections

- **[IP](ip.md)** — Layer 3.
- **[TCP/UDP](tcp-udp.md)** — Layer 4.
- **[Proxy](proxy.md)** — forward/reverse proxies often operate at L7.
- **[Load Balancing](../scaling/load-balancing.md)** — L4 vs L7 LB is a direct consequence of this model.
- **[SSL/TLS/mTLS](../../reliability/ssl-tls-mtls.md)** — lives at L6.

---

## K. Confidence Checklist
- [ ] I can list all 7 layers in order (with the mnemonic).
- [ ] For each layer I can name 1 example protocol/device.
- [ ] I can explain what a switch vs router vs L7 LB does in OSI terms.
- [ ] I can use the "which layer is broken?" debugging script.

### Red flags
- ❌ "OSI is just an outdated academic thing." No — it's the working vocabulary of every network discussion you'll ever have.
- ❌ Thinking L4 LB can route on URL path.
- ❌ Believing every stack slavishly follows 7 layers (they don't — QUIC, HTTP/3 bend it).

---

## L. Potential Gaps & Improvements
- No coverage of specific protocols at each layer beyond names. A focused deep-dive on BGP (L3) and ARP (L2) would strengthen this.
- The "encapsulation" section deserves a worked example with actual byte counts.
- I did not cover TCP/IP's 4-layer model in parallel — that would help since most real-world docs use it.
- QUIC / HTTP/3 deserve their own mini-section because they meaningfully break the traditional layering.

**How to close these:** run `tcpdump -nn -vv -X` on a local curl request and watch the headers unwrap. One afternoon with Wireshark on a localhost HTTP call teaches more about layers than any diagram.
