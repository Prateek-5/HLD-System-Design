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

### 🧨 Retry storm — the failure pattern circuit breakers mitigate

Bad retry (DON'T do this):
```python
while True:
    try: return call_downstream()
    except: pass   # immediate retry
```
1000 clients doing this → downstream goes from slow to dead.

Good retry (DO this) — exponential backoff + jitter:
```python
for attempt in range(5):
    try: return call_downstream()
    except TransientError:
        sleep(min(cap, base * 2**attempt) * random.uniform(0.5, 1.5))
raise
```
- **Exponential**: each retry waits longer.
- **Jitter**: randomizes so 1000 clients don't all retry at the same microsecond (the "thundering herd" amplification).
- **Cap**: never wait more than N seconds.

> **🧠 What if you skip jitter?** Retry synchronization → load spikes every backoff interval → downstream oscillates between "recovering" and "dying". Known as the **retry synchronization storm**.
>
> **🔎 Quick Check** — You added exponential backoff. One million clients still DDoS the downstream. What did you forget?
> **🎯 Recall** — Jitter. Without it, everyone retries at identical moments.

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

---

### 🧭 Guided Deep-Learning Layer

#### 🚢 Gap 1 — Bulkheads (Resource Isolation)
- 🔹 **What it is**: Partition your thread pools / connection pools per downstream dependency, so one sick dependency can't exhaust shared resources starving healthy dependencies.
- 🔹 **Why it matters**: Circuit breakers protect you *after* failures accumulate. Bulkheads prevent one slow downstream from starving threads used by other (healthy) downstreams.
- 🔹 **Connection**: Circuit breakers stop calls to a sick downstream. Bulkheads ensure the "sick downstream" doesn't burn shared resources while the breaker is deciding to open.
- 🔹 **When needed**: 🔴 **Important for senior interviews** on resilience.
- 🔹 **Intuition**: Ships have compartments — one flooding doesn't sink the ship. Your app has thread pools — one slow dependency shouldn't freeze the rest.
- 🔹 **If you go deeper**: Study Hystrix's bulkhead pattern (now in Resilience4j). Per-dependency thread pool sized to concurrency need + some headroom. Combine with timeouts + circuit breakers.
- 🔹 **Interview hook**: *"A slow dependency freezes your entire service even with a circuit breaker. Why?"* → All shared threads are waiting for it. Fix: bulkhead per-dep thread pool.

---

#### ⚡ Gap 2 — Hedging (Tail-latency Reduction)
- 🔹 **What it is**: Send the request to multiple backends; use the first response; cancel the rest. Trades some extra load for reduced p99 latency.
- 🔹 **Why it matters**: Tail latency (p99, p999) kills perceived performance. Hedging can shave p99 from 500ms to 100ms at ~2× resource cost.
- 🔹 **Connection**: Circuit breakers and retries don't help with *tail latency* (slow-but-succeeded calls). Hedging does.
- 🔹 **When needed**: 🔴 **Important for senior latency-critical interviews** (ads, search, real-time).
- 🔹 **Intuition**: If you're in a hurry, call 3 Ubers and take the first one. Cancel the rest. More cost, less waiting.
- 🔹 **If you go deeper**: Read Google's "Tail at Scale" paper (Dean, 2013). Study hedged requests at replica level (send to 2 replicas, take first response). Understand the cost model: extra 2× load for 1 second is worth it for a fraction of the requests.
- 🔹 **Interview hook**: *"Your p99 is 500ms but p50 is 50ms. How do you reduce p99?"* → hedging to 2 replicas after e.g., 100ms delay.

---

### 🏆 Start here if you have limited time

Both gaps are **important for senior interviews**. Bulkheads come up more often; hedging is the more exotic pick.

---

### 🧭 Suggested Deep Dive Order

1. **Bulkheads** (~45 min; resilience completeness).
2. **Hedging + "Tail at Scale" paper** (~1h; senior-performance signaling).
