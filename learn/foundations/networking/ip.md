# IP — The Address of Every Machine on the Planet

> **Prereq**: none. This is the first file.
> **What you will understand by the end**: why an IP address exists, what actually gets put into a packet header, the difference between IPv4/IPv6 and public/private/static/dynamic, and how a packet finds its destination across the planet.

---

## A. Intuition First

### The analogy that makes everything click

Imagine the internet is the postal system.
- A **packet** is a letter.
- A **router** is a post office.
- An **IP address** is the house address on the envelope.

If you write "Send this to Ravi" on a letter with no address, the postal system has no idea what to do with it. It needs a **globally unique, structured identifier** to route the letter.

IP gives computers that address.

### Why it *had* to exist

Early networks (1960s ARPANET) were tiny — a handful of machines, each with a hand-assigned ID. But the moment you wanted Network A to talk to Network B, you needed a **universal addressing scheme** that both networks agreed on.

Two non-negotiable properties:
1. **Uniqueness** — no two machines on the internet have the same address at the same time.
2. **Routability** — the address has structure so that routers in the middle can make forwarding decisions without a full table of every address on Earth.

IP is the protocol that defined this scheme, in 1981 (IPv4). Everything that runs on the modern internet assumes it.

---

## B. Mental Model (First Principles)

An IP address is **a number**. That's it. We render it in two forms for humans:

- IPv4: 32 bits, shown as four 8-bit decimals separated by dots: `192.168.1.10`
- IPv6: 128 bits, shown as eight hex groups: `2001:0db8:85a3::8a2e:0370:7334`

The **only** thing the number fundamentally does is:
1. **Identify** a network interface uniquely (or nearly so — more on NAT below).
2. **Have structure** — the *prefix* (left-hand bits) identifies the network, the *suffix* identifies the host within the network. This is what lets routers forward packets without knowing every IP on Earth.

That second property is the whole magic. A router looking at `74.125.224.72` doesn't need to know *that specific host* exists — it only needs to know "traffic for `74.125.0.0/16` goes out on interface 3". This is called **longest-prefix matching**, and it's how the entire internet scales.

> **🧭 Pointer for beginners**: the notations `/16` and `/24` above are **CIDR** — don't worry if that's unfamiliar yet; there's a full walkthrough in Section F → CIDR below. Come back to this line afterward; it'll click.

---

## C. Internal Working — Packet Level

### What's in an IPv4 packet header

Every IP packet on the internet has a header that looks (simplified) like this:

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-------+-------+---------------+-------------------------------+
|Version|  IHL  |    Type of    |          Total Length         |
|  (4)  |       |    Service    |                               |
+-------+-------+---------------+-------------------------------+
|         Identification        |Flags|     Fragment Offset     |
+---------------+---------------+-------------------------------+
|  Time to Live |   Protocol    |        Header Checksum        |
+---------------+---------------+-------------------------------+
|                       SOURCE IP ADDRESS                       |
+---------------------------------------------------------------+
|                    DESTINATION IP ADDRESS                     |
+---------------------------------------------------------------+
|                    Options (if any) + Padding                 |
+---------------------------------------------------------------+
|                         ... Data ...                          |
+---------------------------------------------------------------+
```

The two fields that carry the work: **Source IP** and **Destination IP**. Everything else is plumbing:
- **TTL (Time to Live)**: decremented by every router the packet crosses. When it hits 0, the packet is dropped. This prevents infinite loops if routing tables are broken. When you see "ttl=64" in `traceroute`, this is it.
- **Protocol**: tells the receiver what's in the payload — TCP (6), UDP (17), ICMP (1).

### Step-by-step: how a packet from your laptop reaches Google

You type `google.com` in your browser. After DNS resolves it to, say, `142.250.72.206`:

1. **Laptop OS** builds a packet with:
   - Source IP = your laptop's private IP (e.g., `192.168.1.10`)
   - Destination IP = `142.250.72.206`

2. **Laptop routing table** says: "destination is not on my local network → send to default gateway (the home router) at `192.168.1.1`".

3. **Home router** receives the packet. Its routing table says: "not on any of my interfaces' networks → forward upstream to my ISP."

4. **NAT happens here (critical).** Your home router rewrites the **source IP** from your private `192.168.1.10` to its own public IP assigned by the ISP, say `49.207.44.100`. It remembers this mapping in a NAT table so the response can find its way back.

5. **ISP router** does longest-prefix match on destination `142.250.72.206`. The prefix `142.250.0.0/15` is Google's. ISP forwards toward the next hop in that direction, likely an internet backbone peer.

6. **Backbone routers** (Tier-1 providers) forward the packet hop by hop. Each router decrements TTL by 1. If TTL hits 0, packet is dropped and an ICMP "time exceeded" is returned to sender.

7. **Google's edge router** receives the packet. Inside Google's network, internal routing protocols (not BGP — likely IS-IS or OSPF) take over.

8. **Google front-end server** at `142.250.72.206` receives the packet. It reads the Protocol field (6 = TCP), passes payload to TCP layer.

9. **Response packet** flows back: Destination IP = `49.207.44.100` (your home router's public IP). The internet delivers it to your home router.

10. **Home router NAT lookup** sees the destination port + its own IP matches the NAT table entry → rewrites destination to `192.168.1.10`, delivers to your laptop.

Note: at no point does any router in the middle know "this is Prateek's laptop". They only know prefixes.

### 🪜 NAT return-path (the part most explanations skip)

When Google replies to `49.207.44.100`, how does your home router know the reply belongs to *your* laptop (192.168.1.10) and not your phone (192.168.1.11), both of which are behind the same public IP?

1. **Outbound**: your laptop's packet has `src = 192.168.1.10:54321 → dst = 142.250.72.206:443`.
2. **At the router**: NAT picks an external port (say 61000) and rewrites to `src = 49.207.44.100:61000 → dst = 142.250.72.206:443`. It stores the mapping `(61000) → (192.168.1.10, 54321)` in its NAT table with a timer.
3. **Google's reply** comes back to `49.207.44.100:61000`.
4. **Router** looks up 61000 → finds `(192.168.1.10, 54321)` → rewrites destination → forwards to your laptop.
5. **Timer resets** on each packet so the mapping stays alive.

Because port 61000 is unique per flow, your laptop and phone can both use the same public IP without collision. This is why NAT needs a concept of **ports** — which is why the TCP/UDP layer matters even for NAT.

> **🧠 What if NAT didn't exist?** Then every device in your house would need a globally unique public IPv4. We ran out in 2011 — the internet would have stalled or forced IPv6 adoption a decade earlier.

> **🔎 Quick Check** — Can you answer in 10 seconds: why does removing a NAT entry from the router's table mid-download break the connection? (Hint: the return port no longer maps.)
> **🎯 Recall** — NAT uses the external port as a lookup key to route replies back to the correct private host.

---

## D. Visual Representation

```
Your Laptop                    Home Router (NAT)              Google
+---------+                   +------------------+         +-----------+
|192.168.1.10| --packet-->   | Pub: 49.207.44.100|-packet->|142.250.72 |
|         |                   | Priv:192.168.1.1 |         |   .206    |
+---------+                   +------------------+         +-----------+
    ^                                 ^
    |                                 |
    | NAT rewrites source             |
    | 192.168.1.10 → 49.207.44.100    |
    | and remembers the mapping       |
    |                                 |
    v                                 v
 [private network]         [public internet]
```

A packet's Source/Destination pair changes as it crosses NAT. Routers in the public internet only ever see `49.207.44.100 → 142.250.72.206`. They have no idea your laptop exists.

---

## E. Tradeoffs

### IPv4 vs IPv6
- **IPv4**: 32 bits → 4.3 billion addresses. Ran out around 2011. We've survived via NAT, but NAT breaks end-to-end connectivity (a host behind NAT cannot be reached directly).
- **IPv6**: 128 bits → 340 undecillion addresses. Effectively infinite. Restores end-to-end connectivity. Adoption is slow because IPv4 still mostly works via NAT — classic backward-compatibility inertia.

### Public vs Private
- **Private** IPs (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) are not routable on the public internet. Multiple networks reuse them. Requires NAT to communicate outside.
- **Public** IPs are globally unique and assigned by regional registries (ARIN, RIPE, APNIC, etc.).

### Static vs Dynamic
- **Static**: manually configured, never changes. Used for servers, because clients need a stable target.
- **Dynamic (DHCP)**: leased by a server for hours/days. Used for clients, because they come and go and reusing addresses is fine.

### Limits / where IP alone is not enough
- IP has **no port**. A server at one IP can't serve two apps without TCP/UDP ports (which is why the next topic — TCP/UDP — exists).
- IP is **unreliable** — no guarantee the packet arrives, arrives once, or arrives in order. Again, TCP fixes this on top.
- IP has **no security** — anyone can spoof a source IP. IPsec, TLS layer above.

---

## F. Interview Lens

### What interviewers probe
- "What's the difference between IPv4 and IPv6?" (softball — know the bit count and why we needed IPv6.)
- "What is NAT?" (mid — explain private/public with a concrete packet flow.)
- "What happens when I type an IP into my browser?" (deeper — they want you to walk the routing.)
- "Why do home networks use 192.168?" (they want the private IP range answer.)
- "What's a /24?" (CIDR — see below.)

### CIDR (you will be asked this)

> **❓ Why does CIDR even exist? (Read this *before* the definition.)**
>
> In the 1990s internet, addresses were handed out in rigid **classes** — Class A (~16M addresses each), Class B (~65k each), Class C (256 each). If you needed 1000 addresses, Class C (256) was too small, Class B (65k) wasted 64,000 addresses. Every organization was taking too much, and routers kept one entry **per network**. By 1993, routing tables were ballooning toward the point where routers would run out of memory. The internet was days away from collapse.
>
> **CIDR (1993) fixed this in two moves:**
> 1. **Give each organization only the addresses it needs** — in any power-of-2 size (not just 256 / 65k / 16M). 1024 addresses? Use a `/22` (2¹⁰ = 1024). Problem solved.
> 2. **Summarize many smaller networks into one "bigger" entry** in the routing table. Instead of 256 routes for `203.0.113.0/24` through `203.0.143.0/24`, advertise one `203.0.0.0/19`. Router tables shrank by an order of magnitude.
>
> Without CIDR, the internet as we know it simply couldn't scale.

### 🧠 Intuition — the "range" way of thinking

Forget the dots for a second. An IP address is a **number** (for IPv4, a 32-bit number). A CIDR block is an **interval of numbers**.

Analogy: imagine house numbers 0 to 4 billion. A CIDR block is a contiguous stretch of that range. `/24` means "the stretch you get by fixing the first 24 bits and letting the last 8 vary" — exactly 256 consecutive addresses.

Small prefix number = big range. `/8` = 16 million addresses. `/30` = 4 addresses.

### 📐 Formal definition

**CIDR** (Classless Inter-Domain Routing) notation: `A.B.C.D/N`.
- The `/N` is the **prefix length** — how many leading bits are fixed ("the network part").
- The remaining `32 − N` bits are free ("the host part").
- Size of the block = 2^(32−N).

| CIDR | Prefix bits | Host bits | # addresses |
|---|---|---|---|
| `/8` | 8 | 24 | 16,777,216 |
| `/16` | 16 | 16 | 65,536 |
| `/24` | 24 | 8 | 256 |
| `/28` | 28 | 4 | 16 |
| `/30` | 30 | 2 | 4 |

### 🔬 Worked example — break down `192.168.1.42/24`

```
Address:   192 . 168 . 1 . 42
Binary:    11000000.10101000.00000001.00101010
           └───── 24 bits (prefix) ─────┘└host┘
           
Network:   192.168.1.0  (host bits zeroed)
Broadcast: 192.168.1.255 (host bits all-ones)
Usable:    192.168.1.1 — 192.168.1.254  (254 hosts; first and last are reserved)
```

Why "minus 2"? The first address (`.0`) is the network identifier (how routers name the whole range); the last (`.255`) is the broadcast address (send-to-all-on-this-network). Neither can be assigned to a host.

### 🗺️ Where you actually use CIDR

- **AWS VPC**: you pick a CIDR block when you create a VPC, e.g., `10.0.0.0/16` = 65,536 addresses. You then carve it into subnets (`10.0.1.0/24`, `10.0.2.0/24`, ...) — one per availability zone.
- **Firewall / security-group rules**: "allow SSH from `10.0.0.0/8`" means allow the entire private 10.x.x.x range.
- **Kubernetes**: pod networks use CIDR (e.g., pod CIDR `10.244.0.0/16`, service CIDR `10.96.0.0/12`).
- **BGP advertisements**: ISPs announce CIDR blocks to the internet; `8.8.8.0/24` = Google's block.

### 🧭 Longest-prefix matching — how routers actually use CIDR

Here's the part that makes CIDR scale: **a router doesn't look up the full IP, it matches the longest CIDR prefix that contains it.**

Imagine a routing table:
```
0.0.0.0/0        →  interface eth0 (default route — "internet")
10.0.0.0/8       →  interface eth1 (the VPC)
10.0.5.0/24      →  interface eth2 (a specific subnet)
```

An outgoing packet to `10.0.5.42`:
- Matches `0.0.0.0/0` (everything does).
- Matches `10.0.0.0/8` (first 8 bits match).
- Matches `10.0.5.0/24` (first 24 bits match).
- Router picks the **longest match** (`/24`) → sends out eth2.

This is why the internet scales to billions of addresses with routers holding **only hundreds of thousands of entries** — each entry summarizes a whole range, and routers deterministically pick the most specific one.

> **🧠 What breaks without longest-prefix matching?**
> Routers would need an entry per individual address (4 billion for IPv4, infinity for IPv6). RAM alone wouldn't fit. The internet stops working at 1990s scale.

### 🎤 Interview hook — CIDR traps

- "How many usable hosts in a `/26`?" → 2⁶ − 2 = **62**.
- "Design a VPC for 3 AZs × 4 subnets each with room to grow." → pick `/16` for VPC, `/20` per AZ, `/22` per subnet. Always leave headroom.
- "If I advertise `10.0.0.0/8` and `10.0.5.0/24`, which wins?" → `/24` wins (longest prefix).
- **Common trap**: confusing `/24` with 255 addresses. It's 256 *addresses*, 254 *usable hosts*.

### 🔄 Micro reinforcement

1. **Quick recall**: How many addresses in `/28`? How many usable hosts?  *(16; 14.)*
2. **Quick recall**: Given `10.0.0.0/16` and `10.0.5.0/24`, which route wins for `10.0.5.12`?  *(The /24 — longest prefix.)*
3. **What if** CIDR had a maximum of `/24` (i.e., you could never go smaller than 256 addresses)? *(You'd waste addresses on every tiny network — back to the 1990s IP-exhaustion crisis.)*

---

**(The original two-line CIDR note is preserved here as a quick restatement):**

**CIDR** = Classless Inter-Domain Routing. Notation: `192.168.1.0/24`. The `/24` means the first 24 bits are the network prefix, the remaining 8 bits are host addresses. So `/24` = 256 addresses (2⁸), `/16` = 65,536 addresses, `/8` = 16 million.

A senior will ask: "If I give you `10.0.0.0/16`, how many hosts can you put in it?" Answer: 2¹⁶ − 2 = 65,534 (subtract network and broadcast addresses).

### Common pitfalls
- Saying "IP guarantees delivery" — no, TCP does.
- Confusing MAC address with IP address. MAC is layer 2 (within a network), IP is layer 3 (across networks).
- Forgetting that NAT is *why* IPv4 survived past 2011.

### Expected depth at different levels
- **Junior**: knows IPv4/IPv6, public/private, dynamic/static.
- **Mid**: packet flow, NAT, CIDR basics.
- **Senior**: understands longest-prefix matching, the BGP-level picture, why IPv6 adoption is slow, how NAT breaks P2P.

---

## G. Real-World Mapping

- **AWS VPC** is basically "your own private IP range in the cloud." You pick a CIDR like `10.0.0.0/16` and subnet it across availability zones.
- **Kubernetes pod networking** assigns every pod its own IP in a flat overlay network — this is specifically to avoid NAT complexity between pods.
- **Cloudflare, Google, Netflix** all use **anycast**: the *same* IP is announced from many locations worldwide, and BGP routes your packet to the nearest one. This is how one IP like `1.1.1.1` (Cloudflare DNS) can respond from hundreds of data centers.
- **CGNAT (Carrier-Grade NAT)**: your ISP NATs thousands of subscribers behind a smaller pool of public IPs. This is why your "public" IP from `whatismyip.com` is often shared.

---

## H. Questions

> **📈 Depth markers** — 🟢 Beginner questions establish vocabulary; 🟡 Intermediate questions expect mechanism; 🔴 Advanced questions expect design tradeoffs.

### Beginner 🟢
1. What is an IP address, in one sentence?
2. Why do we need IP addresses at all?
3. What's the difference between IPv4 and IPv6?
4. What's a private vs public IP?

### Intermediate (Why / How) 🟡
1. Why did IPv6 have to exist when NAT was already working?
2. How does a router decide where to send a packet?
3. What does TTL do in an IP header?
4. How does NAT allow 50 devices in your house to share one public IP?
5. What does `/24` mean in `192.168.1.0/24`?

### Advanced (Interview) 🔴
1. Walk me through the IP-level flow when your laptop in Bangalore requests `google.com`.
2. Why is longest-prefix matching critical to internet scalability?
3. How does anycast let Cloudflare serve `1.1.1.1` from 300 locations?
4. Design an IP allocation system for a cloud provider: 10 million customers, each needing their own private subnet. What breaks first?
5. Why can two devices on the same public IP (behind NAT) have independent connections to the same server?

---

## I. Mini Design Problem — "Design a DHCP-like IP allocation service"

### Requirements
- Lease IPs to clients on request.
- Reclaim IPs when the lease expires or the client releases them.
- Handle 100k clients per region, <10 ms lease latency.

### Constraints
- IPs in a region come from a known pool (say `10.0.0.0/16` = 65k addresses).
- A client should usually get the *same* IP on renewal (stability).

### Sketched solution
1. **Data model**: a Redis hash keyed by MAC → `{ip, lease_expiry, last_renewed}`.
2. **Allocation**: on request, check if MAC already has a live lease. If yes, extend. If no, pop an IP from a Redis set of free IPs.
3. **Reclamation**: a background worker scans leases with `lease_expiry < now` and returns those IPs to the free set.
4. **Scale-out**: partition by MAC hash → multiple DHCP servers own disjoint subnets.
5. **What breaks first?** The free-IP pool. At /16 you run out at 65k leases. Solutions: larger pool (/12), or CGNAT-style over-subscription with shorter lease times.

This is a microcosm of how real cloud VPC IP management works.

---

## J. Cross-Topic Connections

- **[DNS](dns.md)** — DNS *resolves a name to an IP*. IP is the answer DNS gives you.
- **[TCP/UDP](tcp-udp.md)** — run on top of IP. They add ports and (for TCP) reliability.
- **[OSI Model](osi.md)** — IP is Layer 3 (Network).
- **[Load Balancing](../scaling/load-balancing.md)** — L4 balancers route on IP + port; L7 balancers on HTTP.
- **[Proxy](proxy.md)** — proxies forward IP traffic and can rewrite Source/Destination.

---

## K. Confidence Checklist

You should now be able to:
- [ ] Explain in one breath why IP addresses exist.
- [ ] Draw the packet flow from your laptop to Google, naming NAT, routing, TTL.
- [ ] Answer "what's a /24?" without hesitating.
- [ ] Explain why IPv6 exists despite NAT "solving" the problem.
- [ ] State one failure mode of NAT (hint: inbound connections to a device behind NAT).

### Red flags (go back and reread)
- ❌ You think "an IP is just a number the OS assigns" with no intuition for the network-prefix/host split.
- ❌ You can't explain what `TTL` does.
- ❌ You think routers maintain a table of every IP on the internet.
- ❌ You think an IP is a device identifier (it's a network interface identifier — a device with Wi-Fi + Ethernet has two).

---

## L. Potential Gaps & Improvements

**What this file does not yet cover (gaps you should be aware of):**
- **BGP** (Border Gateway Protocol) — the actual protocol that routers use to exchange reachability information. I only hinted at it. A senior interview for a network-heavy role will go deep on BGP.
- **ICMP** — the protocol underneath `ping` and `traceroute`. Worth a deeper read if you want to *see* TTL in action.
- **IPsec** — network-layer encryption. Relevant if the interview veers into VPNs.
- **IP fragmentation** — what happens when a packet exceeds the MTU (typically 1500 bytes). Mostly a legacy concern but occasionally asked.
- **Ephemeral port range** — closer to the TCP/UDP topic, but relevant here because NAT needs ports to disambiguate.

**How to close these gaps:**
- Run `traceroute google.com` on your laptop. Stare at the output. Every hop decremented TTL.
- Read the first 20 pages of *Computer Networking: A Top-Down Approach* (Kurose & Ross) on the network layer.
- Set up a tiny home lab with two subnets and a static route — you'll never forget how routing tables work.

**Where this topic is intentionally thin because it belongs elsewhere:**
- Port numbers → [TCP/UDP](tcp-udp.md)
- How DNS produces the IP → [DNS](dns.md)
- Layer semantics → [OSI](osi.md)
