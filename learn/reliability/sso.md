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
