# Circuit Breaker — Fail Fast When Downstream Is Sick

## A. Intuition First
If service B is dying, and service A keeps hammering it with requests, A's own threads pile up waiting for B, and A dies too. Cascading failure.

A **circuit breaker** is a small state machine wrapping the call: after N failures, it **opens** and short-circuits future calls immediately (returns error), giving B time to recover.

## B. Mental Model
Three states:
- **Closed** — calls flow; count failures.
- **Open** — calls fail immediately without trying.
- **Half-Open** — after a timeout, let a few calls through; if they succeed, close; else reopen.

## C. Internal Working
```
Closed ── failures > threshold ─▶ Open
Open   ── cooldown elapsed ─────▶ Half-Open
Half-Open ── success ──────▶ Closed
Half-Open ── failure ──────▶ Open
```

## D. Visual Representation
```
      ┌──────────────┐
      │   Closed     │ ← all good
      └───┬──────────┘
          │ failures > N
          ▼
      ┌──────────────┐
      │    Open      │ ← fail fast
      └───┬──────────┘
          │ after Xs, try one
          ▼
      ┌──────────────┐
      │  Half-Open   │ ← probe
      └──────────────┘
```

## E. Tradeoffs
- Protects the caller from a sick downstream.
- Risk: false trip (transient blip) → use rolling window + multiple failure kinds.
- Half-open probe must be careful not to re-hammer.

## F. Interview Lens
- "How do you prevent cascading failure?" — circuit breaker, bulkheads, timeouts, retries with backoff.
- "Why is retry without backoff dangerous?" — self-inflicted DDoS on recovering service.
- Pitfalls: breaker without timeouts (still waits forever for slow calls); breaker alone without a fallback.

## G. Real-World Mapping
Netflix Hystrix (classic), Resilience4j, Istio / Envoy built-in, AWS SDK clients (most languages).

## H. Questions
**Beginner**: What does a circuit breaker do?
**Intermediate**: Half-open state?
**Advanced**: Design a circuit breaker with per-downstream independent state and metrics.

## I. Mini Design
Service A calls Service B via HTTP. Wrap with circuit breaker:
- 10 req sliding window.
- If >50% fail or p99 latency > 1s → open.
- Cooldown 30s → half-open (send 1 probe).
- On success: close. On failure: reopen with double cooldown.
Fallback: serve cached / degraded response while open.

## J. Cross-Topic Connections
- [Rate Limiting](rate-limiting.md), [API Gateway](../architecture/api-gateway.md), [Service Discovery](service-discovery.md).

## K. Confidence Checklist
- [ ] Can draw 3-state machine.
- [ ] Knows to combine with timeout, retry+backoff, and fallback.

## L. Potential Gaps & Improvements
- Bulkheads (resource isolation).
- Hedging (send duplicate requests to multiple backends).
