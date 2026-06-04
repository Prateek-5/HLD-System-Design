# OAuth 2.0 and OpenID Connect — Delegated Authorization and Authentication

## A. Intuition First
- **OAuth 2.0** = delegated **authorization**. "Here's a token that proves the user granted you access to X."
- **OpenID Connect (OIDC)** = authentication on top of OAuth. "Here's who this user is."

If you've ever clicked "Sign in with Google", you used OIDC (which uses OAuth under the hood).

## B. Mental Model
Actors:
- **Resource Owner** — the user.
- **Client** — the app requesting access.
- **Authorization Server** — issues tokens (Google, Okta).
- **Resource Server** — the API that accepts tokens.

Token types:
- **Access token** — short-lived (minutes); API uses it to authorize.
- **Refresh token** — long-lived; mint new access tokens.
- **ID token (OIDC)** — JWT describing who the user is.

## C. Internal Working — Authorization Code flow (web, most common)
1. Client redirects user to auth server with scopes.
2. User logs in + consents.
3. Auth server redirects back with a code.
4. Client exchanges code + client_secret → access token (+ id token for OIDC).
5. Client uses access token in API calls.

## D. Visual Representation
```
User ─click→ Client
     Client ─redirect→ AuthServer
     User logs in & consents
     AuthServer ─redirect w/ code→ Client
     Client ─code+secret→ AuthServer ─access_token→ Client
     Client ─api+token→ ResourceServer
```

## E. Tradeoffs
- Short-lived access tokens reduce exposure if leaked.
- Refresh tokens enable long sessions but are very sensitive.
- JWTs are stateless but can't be revoked without allow-lists or short TTLs.

## F. Interview Lens
- "OAuth vs OIDC?"
- "Why is Implicit flow deprecated?" — token exposed in URL/browser history.
- "How to revoke a JWT?" — short TTL + deny-list by jti.
- Pitfalls: confusing authentication with authorization.

## G. Real-World Mapping
Google, Facebook, Okta, Auth0, Azure AD — all OIDC providers.

## H. Questions
**Beginner**: OAuth vs OIDC?
**Intermediate**: Authorization Code flow?
**Advanced**: Design OAuth for 3rd-party integrations on your API platform.

## I. Mini Design
Your SaaS exposes an API. 3rd-party apps register → get client_id + secret → use Authorization Code flow. Tokens are JWTs signed by your auth service. Scopes define permissions.

## J. Cross-Topic Connections
- [SSO](sso.md), [SSL/TLS](ssl-tls-mtls.md), [API Gateway](../architecture/api-gateway.md).

## K. Confidence Checklist
- [ ] Can describe auth code flow.
- [ ] Knows access vs refresh vs id token.
- [ ] Knows OAuth = authorization, OIDC = authentication.

## L. Potential Gaps & Improvements
- **PKCE (Proof Key for Code Exchange)** — adds a one-time secret to the auth code flow so a stolen code is useless to an attacker; now the default for SPAs (Single-Page Apps) and mobile where no client secret can be hidden.
- **Device Code Flow** — lets input-limited devices (TVs, CLIs) show a short code the user enters on their phone to authorize; key when a device has no keyboard or browser.
- **Token Binding** — cryptographically ties a token to the client's TLS (Transport Layer Security) connection so a leaked token can't be replayed elsewhere; raises the bar against token theft.
- **mTLS (mutual TLS) tokens** — both client and server present certificates and the access token is bound to the client cert, proving the holder is the rightful client; common in high-security or machine-to-machine APIs.

**🔧 How to close:** Spin up a local OAuth provider with `docker run -p 8080:8080 quay.io/keycloak/keycloak start-dev`, register a public client, and walk the Authorization Code + PKCE flow by hand — generate a verifier/challenge (`openssl rand -base64 32 | tr -d '=+/' | cut -c1-43`), hit the `/auth` endpoint, then exchange the code at `/token` with `curl` and inspect the returned JWT at jwt.io.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔐 Gap 1 — PKCE (Proof Key for Code Exchange)
- 🔹 **What it is**: An add-on to the Authorization Code flow where the client invents a one-time secret (the `code_verifier`), sends only its hash up front, and proves it later — so a stolen authorization code is useless.
- 🔹 **Why it matters**: SPAs and mobile apps can't safely hide a `client_secret`; PKCE replaces it and is now the recommended default for *all* clients in OAuth 2.1.
- 🔹 **Connection**: Section C's flow exchanges `code + client_secret`. PKCE is what you swap in when there is no secret to send — directly the gap the "How to close" exercise walks you through.
- 🔹 **When needed**: 🟢 **Foundational** — almost every modern frontend uses it, and interviewers expect you to know why Implicit flow died (§F) and what replaced it.
- 🔹 **Intuition**: You mail a padlock (the challenge) to a locker now, but keep the only key (the verifier) in your pocket. Even if someone copies your locker ticket, they can't open it without your key.
- 🔹 **If you go deeper**: Read RFC 7636, then implement S256 challenge generation yourself and watch the `/token` call fail when the verifier doesn't match.
- 🔹 **Interview hook**: *"How do you secure OAuth for a single-page app with no backend?"* → Authorization Code + PKCE; the verifier never leaves the client, so an intercepted code can't be redeemed.

---

#### 📺 Gap 2 — Device Authorization Flow
- 🔹 **What it is**: A flow for input-limited devices (smart TVs, CLIs, IoT) that displays a short user code and a URL; the user authorizes on their phone while the device polls the token endpoint.
- 🔹 **Why it matters**: It's how you log a Roku, Apple TV, or `gh` CLI into your account without typing a password on a remote control.
- 🔹 **Connection**: Section C assumes a browser redirect can happen on the client device. Device flow is the answer when that assumption breaks — same actors (§B), different choreography.
- 🔹 **When needed**: 🟡 **Mid-level** — niche but a frequent "design login for a TV app" curveball; shows you understand the redirect dependency.
- 🔹 **Intuition**: A hotel front desk gives you a slip with a code; you confirm it from your own phone, and the desk lets you in once it sees the confirmation.
- 🔹 **If you go deeper**: Read RFC 8628, then trigger it live with `gh auth login` and watch the CLI poll while you approve in the browser.
- 🔹 **Interview hook**: *"How does a smart TV log into Netflix without a keyboard?"* → Device flow: TV shows a code, user approves on phone, TV polls `/token` until it gets one.

---

#### 🎟️ Gap 3 — Token Revocation & Introspection
- 🔹 **What it is**: Endpoints (RFC 7009 revocation, RFC 7662 introspection) that let you kill a token early and let a resource server ask the auth server "is this token still valid right now?"
- 🔹 **Why it matters**: Stateless JWTs can't be un-issued; revocation/introspection is how real systems handle logout, compromised tokens, and "sign out everywhere."
- 🔹 **Connection**: Section E names the core tradeoff — "JWTs are stateless but can't be revoked without allow-lists or short TTLs." This gap is the concrete machinery behind that sentence (and §F's "How to revoke a JWT?").
- 🔹 **When needed**: 🟡 **Mid-level** — the moment you move past toy auth, "how do I revoke?" is the first hard question you hit.
- 🔹 **Intuition**: A hotel keycard works offline (JWT) until checkout; a deactivation list at the door lock (introspection/deny-list) is what actually stops a lost card mid-stay.
- 🔹 **If you go deeper**: Read RFC 7662, then stand up Keycloak's introspection endpoint and compare a "reference token" (opaque, always checked) vs a self-contained JWT.
- 🔹 **Interview hook**: *"User clicks 'log out everywhere' — how do you invalidate active tokens?"* → short access-token TTL + refresh-token revocation, plus a `jti` deny-list for the access-token window.

---

#### 🛡️ Gap 4 — Sender-Constrained Tokens (mTLS & DPoP)
- 🔹 **What it is**: Techniques that bind a token to the specific client that requested it — via the client's TLS certificate (mTLS, RFC 8705) or a proof-of-possession key (DPoP, RFC 9449) — so a stolen "bearer" token can't be replayed elsewhere.
- 🔹 **Why it matters**: Default OAuth tokens are *bearer* tokens — whoever holds it wins. Sender-constraint turns "holds it" into "holds it *and* owns the key," closing the token-theft hole.
- 🔹 **Connection**: Directly merges the §L bullets on Token Binding and mTLS tokens; it's the hardening layer on top of the short-TTL defense from §E.
- 🔹 **When needed**: 🔴 **Senior** — open-banking, fintech, and high-security machine-to-machine APIs; rarely needed for typical web apps.
- 🔹 **Intuition**: A bearer token is cash — anyone holding it can spend it. A sender-constrained token is a credit card that also demands your signature; the number alone is worthless.
- 🔹 **If you go deeper**: Read RFC 8705 (mTLS) and RFC 9449 (DPoP), then trace how a financial-grade API (FAPI) profile mandates one of them.
- 🔹 **Interview hook**: *"How do you stop a leaked access token from being replayed by an attacker?"* → sender-constrain it: bind the token to the client's TLS cert (mTLS) or a DPoP proof key so possession alone isn't enough.

---

### 🏆 Start here if you have limited time
1. **PKCE** — foundational, ubiquitous, and the direct sequel to "why Implicit flow died"; you cannot discuss modern OAuth without it.
2. **Token Revocation & Introspection** — answers the single most common follow-up ("how do you log out / revoke?") that trips up JWT-only mental models.

---

### 🧭 Suggested Deep Dive Order
1. **PKCE** (~45 min; foundational, applies to every frontend you'll build).
2. **Token Revocation & Introspection** (~1h; resolves the stateless-JWT tradeoff you'll always be asked about).
3. **Device Authorization Flow** (~30 min; quick win, memorable interview curveball).
4. **Sender-Constrained Tokens (mTLS & DPoP)** (~1.5h; senior-infra signaling for fintech/high-security rounds).
