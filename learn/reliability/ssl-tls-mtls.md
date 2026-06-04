# SSL, TLS, mTLS — How the Internet Gets Encrypted

## A. Intuition First
- **SSL** — obsolete predecessor. Don't use.
- **TLS** (1.2, 1.3) — what you mean when you say "SSL" today. Encrypts + authenticates (server to client).
- **mTLS** — both sides present certificates. Common in service-mesh / zero-trust networks.

## B. Mental Model
- **Confidentiality**: nobody in the middle can read.
- **Integrity**: nobody can tamper without detection.
- **Authentication**: you're talking to who you think.

Achieved via: asymmetric crypto (during handshake), symmetric crypto (for bulk data).

## C. Internal Working (TLS 1.3 handshake)
1. Client → ClientHello (supported ciphers, key share).
2. Server → ServerHello (chosen cipher, key share, certificate).
3. Both derive shared key.
4. Client → Finished; Server → Finished.
5. Application data flows, encrypted.

1-RTT handshake (TLS 1.2 was 2-RTT). 0-RTT for resumption possible.

Certificate chain: leaf → intermediate → root (trusted by OS/browser). On expiry or revocation, connection fails.

### mTLS
Same handshake + client also presents a cert. Server verifies client's identity. Used in zero-trust and service meshes.

## D. Visual Representation
```
TLS:    Client ──Hello──▶ Server
        Client ◀──cert + params── Server
        Derive shared key → encrypted data

mTLS:   Same, but client also sends its cert for server to verify.
```

## E. Tradeoffs
- TLS handshake adds latency (1 RTT in 1.3; 2 in 1.2). Mitigate with session resumption, keep-alive.
- Cert management (rotation, revocation) — real op cost. Use Let's Encrypt or AWS Certificate Manager.
- mTLS: stronger but cert distribution is painful.

## F. Interview Lens
- "TLS vs SSL?"
- "1-RTT vs 0-RTT?"
- "How does a client know it's really google.com?" — cert chain + trusted roots.
- "Where does TLS usually terminate?" — at the LB/reverse proxy; plaintext in private network (default) or mTLS end-to-end (secure).

## G. Real-World Mapping
Let's Encrypt, AWS ACM, Cloudflare Universal SSL. Istio/Linkerd auto-rotate mTLS certs for service meshes.

## H. Questions
**Beginner**: What does TLS encrypt?
**Intermediate**: 1.2 vs 1.3 handshake cost?
**Advanced**:
1. Design cert rotation for 10k services.
2. Explain how SNI helps multi-tenant HTTPS servers.

## I. Mini Design
Service mesh with Istio: per-pod sidecar; automatic mTLS cert issuance by Citadel/Istiod; certs rotated every 24h; strict mTLS enforced between services.

## J. Cross-Topic Connections
- [Proxy](../foundations/networking/proxy.md), [OSI](../foundations/networking/osi.md) (L6), [Load Balancing](../foundations/scaling/load-balancing.md) (termination), [OAuth/OIDC](oauth-oidc.md).

## K. Confidence Checklist
- [ ] Can describe TLS 1.3 handshake.
- [ ] Knows mTLS vs TLS.
- [ ] Knows cert chain of trust.

## L. Potential Gaps & Improvements
- **QUIC's integrated TLS** — QUIC (Quick UDP Internet Connections, the transport under HTTP/3) bakes TLS 1.3 directly into the transport so connection setup and encryption happen together; matters because it cuts handshake round-trips and powers modern HTTP/3.
- **Certificate Transparency (CT) logs** — public, append-only logs that record every TLS certificate a CA issues so rogue or mis-issued certs can be spotted; matters for catching attacks where someone fraudulently obtains a cert for your domain.
- **Cipher suite tuning** — choosing which encryption/key-exchange algorithms a server will accept (e.g. preferring modern AEAD ciphers, disabling weak ones); matters for balancing security against compatibility with older clients.
- **SNI (Server Name Indication)** — a field in the ClientHello telling the server which hostname you want, so one IP can serve many HTTPS sites with the right cert; matters for multi-tenant hosting and CDNs (→ see Advanced Questions).
- **OCSP (Online Certificate Status Protocol) stapling** — the server fetches and "staples" a signed proof that its cert isn't revoked into the handshake, so the client skips a separate revocation lookup; matters for faster, more private cert validation.

**🔧 How to close:** Run `openssl s_client -connect google.com:443 -servername google.com </dev/null 2>/dev/null | openssl x509 -noout -issuer -subject -dates` to see the live leaf cert's issuer, subject, and validity window; then re-run with `-tls1_2` vs `-tls1_3` and watch the handshake differences.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🪪 Gap 1 — Certificate Lifecycle: Rotation, Revocation & Chain of Trust
- 🔹 **What it is**: How certs are issued, renewed before expiry, and revoked early (CRL — Certificate Revocation List — and OCSP — Online Certificate Status Protocol, including OCSP stapling where the server attaches a fresh "still valid" proof to the handshake).
- 🔹 **Why it matters**: Most real TLS outages are not crypto failures — they are *expired certs*. Knowing rotation and revocation is the difference between "TLS works on my laptop" and "TLS works for 10k services at 3am."
- 🔹 **Connection**: This file says "on expiry or revocation, connection fails" and lists cert rotation as a real op cost — this gap is *how* you actually prevent that failure.
- 🔹 **When needed**: 🟢 **Foundational** — every engineer who deploys HTTPS hits expiry; the OCSP-stapling internals lean 🟡 **Mid-level**.
- 🔹 **Intuition**: A cert is like a passport with an expiry date. Rotation = renewing it before it lapses. Revocation = the passport office flagging a stolen passport so border control rejects it (OCSP stapling = you carry a stamped "not stolen" note so the guard skips calling the office).
- 🔹 **If you go deeper**: Read the ACME protocol (RFC 8555) behind Let's Encrypt and `certbot`; explore short-lived certs and OCSP stapling (`openssl s_client -status`).
- 🔹 **Interview hook**: *"How does a client know a cert was revoked before it expires?"* → CRL (download a revocation list) or OCSP (live status query); OCSP stapling moves that query to the server so the client gets a signed, cached proof for free during the handshake.

---

#### 🚀 Gap 2 — QUIC & TLS 1.3 Integration (HTTP/3 Handshakes)
- 🔹 **What it is**: QUIC (Quick UDP Internet Connections, the transport under HTTP/3) folds the TLS 1.3 handshake into the transport handshake, so connection setup and encryption negotiation happen in the same round-trips — including 0-RTT resumption.
- 🔹 **Why it matters**: It removes the separate TCP-then-TLS handshake stack, cutting latency on mobile/lossy links, and it's how every major CDN now serves traffic.
- 🔹 **Connection**: This file notes TLS 1.3 is 1-RTT and "0-RTT for resumption possible" — QUIC is where that promise is fully realized by merging transport + crypto.
- 🔹 **When needed**: 🟡 **Mid-level** — useful once you're comfortable with the TLS 1.3 handshake and want to explain modern web performance.
- 🔹 **Intuition**: TCP+TLS is like clearing airport security and *then* walking to a separate gate-check desk. QUIC merges both desks into one stop on the way to the plane.
- 🔹 **If you go deeper**: Read RFC 9000 (QUIC) and RFC 9001 (using TLS with QUIC); experiment with `curl --http3` against Cloudflare or Google.
- 🔹 **Interview hook**: *"Why is HTTP/3 faster to connect than HTTPS over TCP?"* → QUIC merges transport and TLS 1.3 into one handshake (often 1-RTT, 0-RTT on resume) and avoids head-of-line blocking across streams.

---

#### 🏷️ Gap 3 — SNI & Encrypted Client Hello (Multi-Tenant HTTPS)
- 🔹 **What it is**: SNI (Server Name Indication) is a field in the ClientHello naming the target hostname so one IP can present the right cert for many sites; ECH (Encrypted Client Hello) encrypts that field to stop eavesdroppers from seeing which site you're visiting.
- 🔹 **Why it matters**: SNI is what makes CDNs and shared hosting economically possible (thousands of HTTPS domains per IP); ECH closes the last metadata leak in an otherwise-encrypted handshake.
- 🔹 **Connection**: The Interview Lens already asks "how SNI helps multi-tenant HTTPS servers" — this gap adds the privacy frontier (ECH) on top.
- 🔹 **When needed**: 🟡 **Mid-level** for SNI (common multi-tenant question); 🔴 **Senior** for ECH internals.
- 🔹 **Intuition**: SNI is writing the recipient's name on an envelope so the mailroom (one building, many tenants) routes it correctly. ECH puts that name inside a sealed inner envelope so only the mailroom can read it.
- 🔹 **If you go deeper**: Read RFC 6066 (SNI) and the ECH draft (draft-ietf-tls-esni); inspect SNI with Wireshark on a plain TLS 1.2 handshake.
- 🔹 **Interview hook**: *"How does one IP serve HTTPS for thousands of domains?"* → SNI tells the server which hostname is wanted in the ClientHello, so it picks the matching cert before completing the handshake.

---

#### 🛡️ Gap 4 — Cipher Suites, Forward Secrecy & Certificate Transparency
- 🔹 **What it is**: Cipher suite tuning is choosing which key-exchange + encryption algorithms a server accepts (preferring ephemeral ECDHE for forward secrecy and modern AEAD ciphers, disabling weak/legacy ones); Certificate Transparency (CT) logs are public append-only records of every issued cert so mis-issuance is detectable.
- 🔹 **Why it matters**: Forward secrecy means a stolen server key can't decrypt *past* traffic; CT is how a fraudulent cert for your domain gets caught publicly.
- 🔹 **Connection**: This file lists cipher suite tuning and CT logs as gaps and mentions the "chain of trust" — these are the mechanisms that keep that trust honest and resilient.
- 🔹 **When needed**: 🔴 **Senior** — security/infra interviews and TLS-config reviews; most app developers rely on sane defaults.
- 🔹 **Intuition**: Forward secrecy is using a fresh, single-use key for each conversation so stealing today's master key can't unlock yesterday's recordings. CT is a public notary ledger: every "passport" issued is logged where anyone can audit it.
- 🔹 **If you go deeper**: Read RFC 6962 (Certificate Transparency); run your domain through SSL Labs' server test and Mozilla's SSL Config Generator to see graded cipher suites.
- 🔹 **Interview hook**: *"What is forward secrecy and why care?"* → ephemeral key exchange (ECDHE) generates per-session keys, so compromising the long-term private key cannot decrypt previously captured sessions.

---

### 🏆 Start here if you have limited time
1. **Certificate lifecycle (Gap 1)** — expiry/rotation is the single most common real-world TLS failure and the most-asked operational question.
2. **QUIC & TLS 1.3 integration (Gap 2)** — directly extends the handshake this file already teaches and explains modern web performance.

---

### 🧭 Suggested Deep Dive Order
1. **Certificate lifecycle: rotation & revocation** (~1h; foundational, prevents real outages, high interview frequency).
2. **QUIC & TLS 1.3 integration** (~45 min; builds on the 1-RTT/0-RTT handshake you already know).
3. **SNI & Encrypted Client Hello** (~30 min; unlocks multi-tenant HTTPS and a privacy talking point).
4. **Cipher suites, forward secrecy & CT** (~1h; senior-security depth and TLS-config review skills).
