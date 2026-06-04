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
