# Single Sign-On (SSO)

## A. Intuition First
Sign in once; access many apps without re-authing. The SSO provider asserts your identity to each app.

## B. Mental Model
- **Identity Provider (IdP)** — authenticates users (Okta, Google Workspace, Azure AD).
- **Service Provider (SP)** — the app that trusts the IdP.
- Protocols: **SAML** (enterprise), **OIDC** (modern), **Kerberos** (intranet).

## C. Internal Working (OIDC-based SSO)
1. User hits App A → redirected to IdP.
2. IdP authenticates (or recognizes existing session).
3. Redirects back with an id_token.
4. User hits App B → redirected to IdP → already signed in → IdP immediately redirects back with id_token.

## D. Visual Representation
```
User → App A → IdP (login) → id_token → App A
User → App B → IdP (already auth) → id_token → App B
```

## E. Tradeoffs
- Convenience + centralized policy vs IdP being a SPOF (if IdP dies, nobody logs into anything).
- Session management complex across many apps (logout semantics).

## F. Interview Lens
- "SAML vs OIDC?" — SAML XML-heavy, enterprise; OIDC JSON, modern.
- "SSO vs federated identity?" — SSO across your apps; federation is cross-org trust.
- Pitfalls: no logout propagation (back-channel logout / front-channel logout needed).

## G. Real-World Mapping
Okta, Auth0, Azure AD, Google Workspace.

## H. Questions
**Beginner**: What's SSO?
**Intermediate**: SAML vs OIDC?
**Advanced**: Design SSO across 20 SaaS apps with logout propagation.

## I. Mini Design
Okta as IdP; each app configured as OIDC relying party; back-channel logout endpoint on each app; session TTL on IdP controls max re-auth cadence.

## J. Cross-Topic Connections
- [OAuth/OIDC](oauth-oidc.md), [SSL/TLS](ssl-tls-mtls.md).

## K. Confidence Checklist
- [ ] Knows IdP/SP terminology.
- [ ] Knows SAML vs OIDC.

## L. Potential Gaps & Improvements
- **MFA (Multi-Factor Authentication)** — requires a second proof (app code, hardware key) beyond the password; SSO is a great place to enforce it once for all apps.
- **Session Fixation** — attacker plants a known session ID before login so they ride the victim's authenticated session; matters because the fix (rotate the session ID on login) is a classic interview gotcha.
- **CSRF (Cross-Site Request Forgery)** — a malicious site tricks your already-logged-in browser into firing state-changing requests; learners should know `state` params and SameSite cookies defend SSO redirect flows.
- **PKCE (Proof Key for Code Exchange)** — adds a one-time secret to the OAuth code exchange so a stolen authorization code is useless; now mandatory for public/SPA clients (→ see Interview Lens).
- **Back-channel / front-channel logout** — server-to-server vs browser-redirect ways to sign a user out of every app at once; the hard part of "design SSO logout" questions (→ see Interview Lens).

**🔧 How to close:** Spin up Keycloak locally with `docker run -p 8080:8080 -e KEYCLOAK_ADMIN=admin -e KEYCLOAK_ADMIN_PASSWORD=admin quay.io/keycloak/keycloak start-dev`, create one realm with two OIDC clients, and log into both from one browser session to watch the second app skip the login prompt; then decode the resulting `id_token` at https://jwt.io to inspect its claims.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔑 Gap 1 — MFA (Multi-Factor Authentication) at the IdP
- 🔹 **What it is**: Requiring a second proof of identity (a one-time code, push approval, or hardware key) on top of the password, enforced once at the Identity Provider.
- 🔹 **Why it matters**: Passwords leak constantly; MFA is the single highest-impact control against account takeover, and SSO lets you enforce it once for every connected app instead of per-app.
- 🔹 **Connection**: This file's Mini Design centralizes auth at Okta — that central choke point is exactly where you bolt on MFA so all 20 SaaS apps inherit it for free.
- 🔹 **When needed**: 🟢 **Foundational** — every learner should be able to explain why MFA belongs at the IdP, not in each app.
- 🔹 **Intuition**: An office with one guarded front desk — show your badge *and* your face once at reception, and every interior door opens. You don't get re-checked at each room.
- 🔹 **If you go deeper**: Read the FIDO2/WebAuthn spec for phishing-resistant hardware-key auth, and contrast TOTP (RFC 6238) with push-based and passkey flows.
- 🔹 **Interview hook**: *"How do you add MFA to 20 apps without touching all 20?"* → Enforce it at the IdP during the central authentication step; the apps only consume the resulting id_token and never see the second factor.

---

#### 🔁 Gap 2 — Session Fixation
- 🔹 **What it is**: An attack where the attacker plants a known session identifier in the victim's browser *before* login, then rides the same session once the victim authenticates.
- 🔹 **Why it matters**: It's a classic interview gotcha with a one-line fix (rotate the session ID at login), and it shows you understand that authentication must change the session, not just validate credentials.
- 🔹 **Connection**: SSO is all about establishing and reusing a session at the IdP (section C). If that session ID is attacker-controlled before login, the whole single-sign-on trust chain is compromised.
- 🔹 **When needed**: 🟡 **Mid-level** — expected once you're talking about session security seriously.
- 🔹 **Intuition**: A hotel hands you a key card, but the thief pre-registered that card number. When you check in, the front desk activates *their* card instead of issuing a fresh one — so they walk into your room.
- 🔹 **If you go deeper**: Read the OWASP Session Management Cheat Sheet on session-ID regeneration; check how your framework (e.g. Spring Security's `sessionFixation().migrateSession()`) handles it.
- 🔹 **Interview hook**: *"How do you defend against session fixation?"* → Issue a brand-new session ID on successful login and invalidate the pre-login one, so any value the attacker planted becomes worthless.

---

#### 🛡️ Gap 3 — CSRF (Cross-Site Request Forgery) in Redirect Flows
- 🔹 **What it is**: A malicious site tricks an already-logged-in browser into firing state-changing requests using its ambient session cookies — and in OIDC it can also forge or swap the authorization-code callback.
- 🔹 **Why it matters**: SSO leans on browser redirects and cookies, the exact surface CSRF abuses; knowing the `state` parameter and `SameSite` cookies separates rote OAuth knowledge from real understanding.
- 🔹 **Connection**: The redirect dance in section C (App → IdP → back with id_token) is vulnerable if the callback isn't tied to the request that started it — that binding is the `state` param's job.
- 🔹 **When needed**: 🟡 **Mid-level** — almost always probed in OAuth/OIDC security follow-ups.
- 🔹 **Intuition**: You're logged into your bank in one tab; a booby-trapped ad in another tab silently submits a transfer using your still-warm session. CSRF is a forged request riding your open door.
- 🔹 **If you go deeper**: Read the OWASP CSRF Prevention Cheat Sheet, and study how the OAuth `state` parameter (RFC 6749 §10.12) plus `SameSite=Lax/Strict` cookies close the gap.
- 🔹 **Interview hook**: *"Why does the OAuth redirect carry a `state` value?"* → It's a per-request random token the client checks on callback, proving the response belongs to a flow this user actually started — defeating CSRF/code-injection on the redirect.

---

#### 🧩 Gap 4 — PKCE (Proof Key for Code Exchange)
- 🔹 **What it is**: An OAuth extension where the client generates a one-time secret (the `code_verifier`), sends only its hash up front, and reveals the secret at token exchange — so a stolen authorization code alone is useless.
- 🔹 **Why it matters**: It's now mandatory for public clients (SPAs, mobile apps) that can't safely hold a client secret, and is rapidly becoming best practice for all OAuth clients.
- 🔹 **Connection**: → see Interview Lens (the `state`/PKCE hardening of the OIDC code flow this file's section C describes).
- 🔹 **When needed**: 🟡 **Mid-level** — standard for anyone implementing OIDC on web/mobile front-ends.
- 🔹 **Intuition**: You mail a locked box (the hash) ahead, keeping the only key (the verifier) in your pocket. Even if someone intercepts the box in transit, they can't open it without the key you produce in person at pickup.
- 🔹 **If you go deeper**: Read RFC 7636 (PKCE) and OAuth 2.1, which folds PKCE into the baseline; try the verifier/challenge generation by hand with SHA-256 + base64url.
- 🔹 **Interview hook**: *"Why can't a public SPA use a client secret, and what replaces it?"* → A secret in browser JS is readable by anyone, so PKCE substitutes a per-request dynamic proof that never has to be pre-shared or stored.

---

#### 🚪 Gap 5 — Back-channel vs Front-channel Logout
- 🔹 **What it is**: Two ways to sign a user out everywhere at once — front-channel uses hidden browser redirects/iframes to ping each app, back-channel uses direct server-to-server logout calls from the IdP.
- 🔹 **Why it matters**: → see Interview Lens (single logout is the hard half of "design SSO," and the choice trades reliability against browser-only reach).
- 🔹 **Connection**: Section E flags logout semantics as the complex part of SSO, and section I bakes a back-channel logout endpoint into each app — this gap explains the two mechanisms behind that decision.
- 🔹 **When needed**: 🔴 **Senior** — genuinely deep; comes up in "design SSO across N apps with single logout" rounds.
- 🔹 **Intuition**: Front-channel is the receptionist running around knocking on every office door as you leave (fast but fails if a door is jammed/offline); back-channel is the receptionist phoning each office directly (reliable, but needs every office reachable from the desk).
- 🔹 **If you go deeper**: Read the OpenID Connect Front-Channel Logout and Back-Channel Logout specs, plus the `logout_token` format; see how Keycloak implements both.
- 🔹 **Interview hook**: *"Why might back-channel logout be more reliable than front-channel?"* → It's a direct server-to-server call that doesn't depend on the user's browser executing every redirect/iframe, so logout still propagates even if a tab is closed or an app is slow to render.

---

### 🏆 Start here if you have limited time
1. **MFA at the IdP** — foundational, universally asked, and the clearest payoff of centralizing auth.
2. **CSRF + the `state` parameter** — directly secures the redirect flow this file is built on; expected in any OAuth follow-up.

---

### 🧭 Suggested Deep Dive Order
1. **MFA at the IdP** (~30 min; foundational and high-frequency).
2. **CSRF in redirect flows** (~45 min; secures the core SSO flow and pairs naturally with `state`).
3. **PKCE** (~45 min; mandatory for SPA/mobile, builds on the redirect security from step 2).
4. **Session fixation** (~30 min; rounds out session-security depth).
5. **Back-channel vs front-channel logout** (~1h; senior-level, the hard half of SSO design questions).
