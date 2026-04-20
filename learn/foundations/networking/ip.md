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

### Beginner
1. What is an IP address, in one sentence?
2. Why do we need IP addresses at all?
3. What's the difference between IPv4 and IPv6?
4. What's a private vs public IP?

### Intermediate (Why / How)
1. Why did IPv6 have to exist when NAT was already working?
2. How does a router decide where to send a packet?
3. What does TTL do in an IP header?
4. How does NAT allow 50 devices in your house to share one public IP?
5. What does `/24` mean in `192.168.1.0/24`?

### Advanced (Interview)
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
