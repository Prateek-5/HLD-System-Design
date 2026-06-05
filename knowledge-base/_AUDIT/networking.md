# 🔍 Audit — `networking/`

**Reviewed:** 5 files (~1,982 lines) · **Lens:** brutal-honest, held to the corpus's own "senior/staff 3000+ word deep dive" claim · **Avg score: ~4.0/5**

---

## Verdict in one line
The **most technically trustworthy directory in the corpus so far** — it nails the exact traps the prompt warned about (TCP-layer HoL survives HTTP/2, HTTP/3-over-UDP, TLS 1.3 1-RTT + 0-RTT replay, CNAME-at-apex) — but it is **structurally padded**: every file runs the same 11 ritual sections, and the "Junior/Senior/20%/Final Mental Model" cluster restates identical bullets 4–5×, faking the word count.

## Per-file scores (out of 5)

| File | Score | One-liner |
|---|---|---|
| `http-2-and-http-3.md` | **4.3** | Gets the HoL nuance exactly right; 0-RTT replay + coalescing gotchas are real staff-level signal |
| `tcp-and-network-fundamentals.md` | **4.2** | Accurate and well-sequenced; only the textbook `cwnd=1` slow-start is dated vs modern IW10 |
| `tls-and-mtls.md` | **4.1** | Clean 1.3 vs 1.2 table, correct forward-secrecy/0-RTT framing; thin on the actual key-exchange math |
| `dns-deep-dive.md` | **4.0** | Strong on hierarchy/TTL/anycast/failover; GeoDNS-vs-resolver-cache insight is genuinely good |
| `websockets-and-realtime-protocols.md` | **3.6** | Solid scaling/fan-out coverage; misses the SSE-over-HTTP/1.1 6-connection trap and is the most padded |

## Concrete errors found (must-fix)
This directory is **unusually clean on facts** — there are no outright hallucinations or fabricated citations of the kind found in `architecture-patterns/`. The marquee, commonly-botched concepts are all correct. What remains are a handful of **dated defaults and small imprecisions**, not falsehoods:

- 🚩 **`tcp-and-network-fundamentals.md`** — *"Slow start. Start with cwnd=1 segment. Double per RTT."* The textbook value, but **outdated**: RFC 6928 / modern Linux use an **initial window of 10 segments (IW10)**. A staff doc should note IW10 because it materially changes first-RTT throughput (the whole point of the "slow start after idle" section that follows).
- 🚩 **`tcp-and-network-fundamentals.md`** — *"Fast retransmit. Three duplicate ACKs (e.g., ACK 1001, 1001, 1001)..."* Minor but worth tightening: fast retransmit triggers on **three *duplicate* ACKs** (i.e., the original ACK plus three more carrying the same number), commonly mis-taught as "three ACKs total." The example as written is the loose convention; precise enough to pass but imprecise for a "deep dive."
- 🚩 **`http-2-and-http-3.md`** — *"HTTP/2 allows reusing a connection for any origin matching the certificate."* Incomplete: coalescing requires the cert to cover the host **AND** the hostnames to resolve to the **same IP** (per RFC 7540 §9.1.1). The file mentions "sharding by IP" parenthetically but never states the IP-match requirement as a precondition — readers will conclude cert-match alone is sufficient.
- 🚩 **`websockets-and-realtime-protocols.md`** — **Omission that bites in production:** SSE over **HTTP/1.1** is capped by the browser's **~6 connections per origin** limit (each `EventSource` holds one open connection), a classic real-world failure. The file praises SSE as "HTTP-compatible (works through proxies)" but never warns about this — it's the single most common reason teams abandon SSE for WebSockets. HTTP/2 multiplexing fixes it; that linkage is absent.
- 🚩 **`websockets-and-realtime-protocols.md`** — *"WebTransport ... standardized 2024-ish."* Hedged with "-ish," but as of this audit WebTransport is still a **W3C Candidate Recommendation / IETF draft**, not a finished standard. Fine with the hedge; flag if the hedge is removed.
- 🚩 **`dns-deep-dive.md`** — *"`example.com` ... 93.184.216.34"* was the real IANA reference IP for years but was **decommissioned in 2025**. Harmless as illustration; only flagged for freshness.

No errors on: TCP 3-way handshake, AIMD/slow-start/Reno/CUBIC/BBR characterization, flow-vs-congestion control, Nagle + delayed-ACK 200ms interaction, TLS 1.3 1-RTT diagram, mandatory forward secrecy in 1.3, 0-RTT replay caveat (correct in **three** files), HTTP/2 TCP-layer HoL persisting after app-layer multiplexing (correct and explicit — the exact thing the prompt flagged), HTTP/3-over-QUIC-over-UDP, connection migration, HPACK→QPACK out-of-order rationale, CNAME-at-apex RFC violation + ALIAS/ANAME workaround, anycast root-server clusters, server-push deprecation. This is the correct call on every hint in the prompt.

## Genuine strengths (keep)
- **The HTTP/2 HoL framing is textbook-correct and rare:** *"The HTTP layer's multiplexing is undone by the TCP layer's in-order delivery. On lossy networks, HTTP/2 can be slower than HTTP/1.1."* This is exactly the nuance most docs get wrong ("HTTP/2 removes HoL blocking" — it does not, at the TCP layer).
- **0-RTT replay is correctly and repeatedly flagged** with the right mitigation (idempotent-only), including a concrete failure scenario about an endpoint with "hidden side effects."
- **DNS GeoDNS insight is genuinely senior:** *"The recursive resolver caches its answer; users behind that resolver get the same answer regardless of their actual location."* That resolver-locality caveat trips up real CDN routing.
- **Failure scenarios are concrete and plausible** across all five files: TIME_WAIT exhaustion, PMTU blackhole, Nagle 200ms, accept-queue overflow, HPACK dynamic-table bloat from per-request trace IDs, reconnection storms, fan-out collapse. These read like things the author actually debugged.
- **Cross-domain links** are consistent and non-fabricated (TCP↔HTTP↔TLS↔edge↔backpressure), giving the directory real cohesion.
- **TLS 1.3-vs-1.2 comparison table** is accurate on every row (RTTs, 0-RTT, forward secrecy, renegotiation removal, cipher-suite pruning).

## 🛠️ Improvement plan (tailored to this directory)

**Theme: the facts are right — the problem is ~35–45% structural padding and a few dated defaults, not accuracy.**

1. **De-pad aggressively (the #1 issue here).** Every file runs the identical 11-section ritual, and five of those sections — *What Junior Engineers Miss / What Senior Engineers Notice / 20% Knowledge / Interview Perspective / Final Mental Model* — restate the same 6–10 bullets. In `tcp-and-network-fundamentals.md` "pool connections / disable Nagle / monitor TIME_WAIT / tune kernel params" appears verbatim across **four** sections. Collapse those five into **one** "Key takeaways" block per file. Realistic reduction: 35–45% of lines with **zero** information loss.
2. **Fix the dated defaults (cheap, high-credibility).** `tcp`: add IW10 (RFC 6928) alongside the historical `cwnd=1`; tighten the "three duplicate ACKs" wording. `http`: state the **same-IP** requirement for HTTP/2 coalescing, not just cert-match.
3. **Close the one real omission:** add the **SSE / 6-connections-per-origin (HTTP/1.1)** trap and its HTTP/2-multiplexing fix to `websockets-and-realtime-protocols.md`, plus name **`Last-Event-ID`** as the SSE resume mechanism (currently the resume story is told only for WebSockets).
4. **Go one layer deeper where the docs stop at the surface.** `tls-and-mtls.md` describes the handshake message flow but never the **key exchange** (ECDHE: each side sends a key share, derives the shared secret) — the "clever protocol" in the intuition section is never cashed out technically. `dns`: the recursion section never mentions that DNS uses **UDP/53 with TCP fallback for responses >512 bytes / truncated (TC bit)** — only a passing parenthetical in the closing line. Add it; it's interview-standard.
5. **Replace name-drop "scenarios" with links or delete.** The "Real Production Scenarios" lists ("Cloudflare's TCP tuning," "Facebook's adoption," "Google's QUIC origin") are unsourced gestures. Either link the specific Cloudflare/Google blog posts (they exist) or cut the section — it currently adds length, not signal.
6. **Promote `http-2-and-http-3.md` as the directory template.** It is the strongest: correct on the hard part (TCP HoL), concrete on gotchas (coalescing outage, QUIC-blocked-by-corporate-UDP-firewall, 0-RTT replay), and the bridge/highway analogy actually clarifies. The weaker files should match its accuracy-to-padding ratio.
