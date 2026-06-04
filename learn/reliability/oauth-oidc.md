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
