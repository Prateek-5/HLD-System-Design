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
- Multi-factor auth (MFA) integration.
- Session fixation and CSRF.
