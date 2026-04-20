# 🧭 The System Design Thinking Framework

> The goal of this document: give you a **repeatable mental script** so that when an interviewer says *"design Instagram"*, you do not freeze. You run a known procedure.

---

## The 60-second orientation

Before you draw anything, **say these four sentences out loud** (or in your head):

1. "Let me clarify the scope and the scale."
2. "Let me list the functional and non-functional requirements."
3. "Let me do a rough back-of-envelope estimate."
4. "Let me draw the high-level architecture, and then zoom into the one or two pieces that matter most."

Interviewers are not testing whether you know every buzzword. They are testing whether **you can structure your thinking under pressure**. These four sentences are the structure.

---

## Stage 1 — Clarify (3–5 min)

You will get a vague prompt. **Do not start drawing.** Convert the prompt into a concrete problem.

### Ask these questions, in this order

| Question | What you are actually figuring out |
|---|---|
| What are the core use cases? | Scope. Instagram could be photo upload, feed, DM, stories, reels — pick 2–3. |
| Who is the user? Geography? | Global vs regional. Latency and replication change dramatically. |
| Read-heavy or write-heavy? | Determines whether you need read replicas, caches, CQRS. |
| What is the expected scale (users, QPS, storage)? | Drives estimation and fundamentally shapes the architecture. |
| Consistency strict or eventual? | Shapes your CAP choice. Bank balance ≠ Twitter feed. |
| Latency budget? | "Must feel instant" → 50–200 ms p99. "Batch analytics" → minutes. |

### The one sentence you write at the top of the board

> *"I am designing a system that supports [X core use cases] for [Y users] at [Z QPS], with [strict/eventual] consistency and a [latency budget]."*

This sentence is your **contract** for the rest of the interview. Every decision later refers back to it.

---

## Stage 2 — Estimate (2–3 min)

Do the math. Out loud.

### The numbers to know cold

| Thing | Rough number |
|---|---|
| 1 KB text post | 1,000 bytes |
| 1 photo | 200 KB – 2 MB |
| 1 short video (15s) | 5 – 20 MB |
| 1 user/day engagement | 10 – 50 reads, 1 – 5 writes (typical social) |
| 1 year in seconds | ~31.5 M |
| Read from RAM | ~100 ns |
| Read from SSD | ~100 μs (1000× RAM) |
| Read from disk | ~10 ms (100× SSD) |
| Read across datacenter | ~100 ms (10× disk) |
| Typical DB single-node QPS ceiling | 10k – 100k for simple queries |

### The template

```
Daily Active Users (DAU):       _____
Actions per user per day:       _____
Total actions/day:              _____
QPS (actions/day / 86400):      _____
Peak QPS (2–3× avg):            _____
Data per action:                _____
Daily storage:                  _____
Yearly storage (× 365):         _____
```

Then interpret: "200k QPS peak means a single DB node will not survive. We need either sharding or a cache layer absorbing 95%+ of reads."

**This is where real senior signal is earned.** Juniors skip estimation and then hand-wave "we'll add a cache." Seniors derive the cache from the numbers.

---

## Stage 3 — High-level architecture (5–10 min)

Draw left to right: **client → edge → app → data**.

A default skeleton you can always start from:

```
[Client] → [CDN / Edge cache]
         → [Load Balancer]
            → [API Gateway]
               → [Service A]  → [Cache]
               → [Service B]  → [Primary DB] ←→ [Read replicas]
                              → [Object storage]
               → [Message Queue] → [Async workers]
```

**Then justify each box.** For every arrow, be ready to answer:
- Why is this component here?
- What does it cost (latency, $, ops complexity)?
- What breaks if I remove it?

### Default choices to lean on (until you have a reason to deviate)

| Problem | Default first pick | When to change |
|---|---|---|
| Read traffic > write | Cache in front | Almost always. Redis / Memcached. |
| Write > 10k QPS on one node | Shard | Consistent hashing, range, or lookup table. |
| Global user base, static content | CDN | For images, JS, video segments. |
| Need eventual-OK cross-service coordination | Message queue | Kafka, SQS, RabbitMQ. |
| Read-heavy complex queries | Read replicas | Or denormalized view / CQRS. |
| Unpredictable bursts | Queue + worker pool | Decouples producer from consumer. |
| Service-to-service REST | gRPC or REST | gRPC for internal, REST for external. |
| Real-time bidirectional client | WebSocket | SSE if it's one-way server → client. |

---

## Stage 4 — Deep dive (10–15 min)

The interviewer will now pick a piece and say "go deeper". **Anticipate which one.** Usually it's the one most critical to the scale you quoted.

### The checklist to apply when zooming in

For whatever component you zoom into, hit these:

1. **Data model** — concrete schema / key structure
2. **Storage choice** — SQL / NoSQL / blob / time-series; *defend the choice*
3. **Partitioning** — what's the shard key, and what's its skew risk?
4. **Replication** — primary-replica? multi-primary? quorum?
5. **Caching** — what's cached, where, with what TTL and invalidation strategy?
6. **Indexes** — what are the read patterns, and what indexes support them?
7. **Failure modes** — what happens when this box dies, or when the network partitions it?

If you hit all 7, you sound like a senior engineer on this component.

---

## Stage 5 — Tradeoffs & alternatives (ongoing)

The most common senior-level signal: **proactively name alternatives and explain why you did not pick them.**

Phrases to use:
- "I picked X over Y because _____. The cost is _____."
- "If requirements were _____, I would switch to Y."
- "A simpler version is Z, but it breaks at _____ scale."

This proves you are not reciting a pattern — you are reasoning.

---

## Stage 6 — Non-functional checklist (last 3–5 min)

Before the interviewer ends the session, cover these **explicitly** so they can check their boxes:

- [ ] **Availability** — what's the SLA target? multi-AZ? multi-region?
- [ ] **Consistency** — strong where (money, auth), eventual where (feeds)?
- [ ] **Durability** — replication factor, backups, point-in-time recovery?
- [ ] **Latency** — p50 / p95 / p99 targets?
- [ ] **Scalability** — how does this scale 10×? 100×?
- [ ] **Monitoring** — what metrics, alerts, dashboards?
- [ ] **Security** — authN/authZ, TLS everywhere, secrets management, rate limits?
- [ ] **Cost** — hot path vs. cold path; where is the money going?

---

## The meta-framework: "why does it exist?"

For **every** concept you mention, you should silently be able to complete:

> *"X exists because without X, the system would fail at _____."*

Examples:
- *Load balancer exists because without it, one server caps your throughput and becomes a SPOF.*
- *Cache exists because without it, every read hits disk and costs 100 ms per query.*
- *Sharding exists because without it, one DB hits a write ceiling around 10k–50k QPS.*
- *Circuit breaker exists because without it, a slow downstream cascades the outage to every upstream.*
- *Consistent hashing exists because without it, adding/removing a shard remaps every key.*

If you can say *why it exists* for every box, you are reasoning, not pattern-matching.

---

## The 6 interview red flags to avoid

1. **Jumping to components before clarifying requirements.** You cannot pick storage before knowing consistency needs.
2. **Vague "use a cache" or "add a queue" with no math behind it.** Derive it from QPS.
3. **Inventing custom algorithms when a well-known one fits.** Use consistent hashing, Raft, etc. by name.
4. **Ignoring failure modes.** Every box must be questioned: what if it dies?
5. **Not mentioning monitoring/observability.** Seniors always instrument. Juniors never do.
6. **One-size-fits-all consistency.** Different data has different consistency needs — say so.

---

## The closing flourish

When the interviewer says "what else?", these are the topics you sprinkle to show depth:

- Backpressure (queue fills → reject new work → client retries with jitter)
- Idempotency (every mutating endpoint has an idempotency key)
- Feature flags / gradual rollout (deploy risky changes to 1% first)
- Graceful degradation (if recommendations service dies, show trending feed)
- Chaos engineering (Netflix's Chaos Monkey approach)
- Tenancy isolation (noisy neighbor problem in multi-tenant systems)

You are not expected to design all of these. You are expected to **name** them so the interviewer knows you know they exist.

---

## The 30-second self-check

At the end of any design, ask yourself:
1. Did I justify every component with numbers or a concrete failure it prevents?
2. Did I name at least 2 tradeoffs I explicitly considered and rejected?
3. Did I cover at least one failure mode per critical component?
4. Did I land the non-functional checklist (availability, consistency, latency)?

If yes to all four, you did the job of a senior engineer in that session.
