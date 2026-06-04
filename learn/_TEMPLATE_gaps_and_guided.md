# 📐 Section Template — "Potential Gaps & Improvements" + "Guided Deep-Learning Layer"

> **This file is the canonical rulebook.** Every topic file's §L Gaps section and 🧭 Guided layer must match the shape below. It is not a topic file itself — it documents the *contract*. When in doubt, copy the patterns here verbatim and swap in topic-specific content.
>
> **Golden rule: enrich, never delete.** Existing bullets, analogies, and deep-dive prose are preserved. We only add glosses, the difficulty gate, honest tiering, and the "How to close" action.

---

## Spec A — "## L. Potential Gaps & Improvements"

**Rules:**
1. Every bullet = **term + a 5–15 word plain-English gloss** (*what it is* + *why a reader would care*). No bare acronyms or product names.
2. Spell out **every acronym on first use**: `ISR (In-Sync Replicas)`, `PKCE (Proof Key for Code Exchange)`, `CNI (Container Network Interface)`, `CDC (Change Data Capture)`.
3. End with a mandatory **`🔧 How to close`** line: ≥1 concrete, beginner-doable action — a runnable command or a specific exercise, not "go read more."
4. If a gap repeats the file's own *Interview Lens* / *Advanced Questions*, replace the duplicate with a cross-link: `→ see Interview Lens`.

### ✅ Good (target state)
```markdown
## L. Potential Gaps & Improvements
- **CDC (Change Data Capture)** — tools like Debezium stream every row change out of a database so other systems stay in sync. Worth knowing for any "keep two stores consistent" question.
- **Read-model rebuilds** — how you regenerate a query-side view from scratch after a bug or schema change, without downtime.

**🔧 How to close:** spin up Postgres + Debezium locally (docker compose), make an `UPDATE`, and watch the change event land on a Kafka topic. You'll never forget what CDC *is* after seeing one event flow.
```

### ❌ Bad (current state — what we are fixing)
```markdown
## L. Potential Gaps & Improvements
- CDC tooling (Debezium) for sync.
- Read model rebuilds.
```
*Why it fails for a beginner: "CDC" is never expanded, "Debezium" is a bare product name, there's no why, and no actionable next step.*

---

## Spec B — "### 🧭 Guided Deep-Learning Layer"

**Rules:**
1. Open with the **difficulty gate** (verbatim):
   > ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.
2. Tag each gap with **honest difficulty** in the `When needed` line — and do **not** flag everything 🔴:
   - 🟢 **Foundational** — most readers benefit; reachable now.
   - 🟡 **Mid-level** — useful once basics are solid; common in mid-level interviews.
   - 🔴 **Senior** — deep/infra; senior-interview signaling only.
3. Keep the existing per-gap skeleton: **What it is / Why it matters / Connection / When needed / Intuition / If you go deeper / Interview hook.**
4. Always include both companions: **🏆 Start here if you have limited time** and **🧭 Suggested Deep Dive Order**.

### ✅ Reference example (drawn from the strongest existing files)
```markdown
### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🎫 Gap 1 — Weighted Limits by Plan/Tier
- 🔹 **What it is**: Different rate limits per user tier (free vs pro vs enterprise), endpoint, or time-of-day.
- 🔹 **Why it matters**: Real SaaS products monetize rate limits; flat limits leave money on the table.
- 🔹 **Connection**: This file treats limits as uniform. Real products multiply per-plan, per-endpoint, per-tenant.
- 🔹 **When needed**: 🟡 **Mid-level** for most products; 🔴 **Senior** for SaaS product-design rounds.
- 🔹 **Intuition**: Airline seats — economy, business, first. Same airplane, different quotas.
- 🔹 **If you go deeper**: Study Stripe's tiered-limit architecture (limits in plan metadata, applied at the gateway).
- 🔹 **Interview hook**: *"Design rate limits for free/pro/enterprise tiers."* → tier-aware bucket capacity.

---

### 🏆 Start here if you have limited time
1. **Weighted limits by tier** — applies to most product interviews.
2. **Distributed gossip limiter** — senior-infra depth.

---

### 🧭 Suggested Deep Dive Order
1. **Weighted / tiered limits** (~45 min; widely applicable).
2. **Distributed gossip token bucket** (~1h; senior-infra signaling).
```

### Tiering discipline (the #1 fix)
The current failure is flagging *every* gap 🔴 "important for senior interviews" — which tells a beginner they're perpetually behind. Calibrate honestly: a gap most readers can absorb now is 🟢, not 🔴. Use the gate + tiering together so a beginner always knows *whether this is for them yet*.

---

## Coverage contract
- **Every** topic file gets a Spec-A Gaps section **and** a Spec-B Guided layer (full parity).
- Depth scales with interview weight: a high-frequency topic (e.g. `distributed-transactions`) earns 4–5 gaps; a niche one (e.g. `enterprise-service-bus`) earns 2.
- Synthesis files (`frameworks/*`) get lightweight versions, not full topic treatment.
