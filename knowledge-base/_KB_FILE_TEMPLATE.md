# 📐 Knowledge-Base File Template — the standard every topic file follows

> **This is the rulebook, not a topic file.** It documents the *contract* for every file under the content directories. Golden rule, same as the `learn/` corpus: **enrich, never delete.** We add a beginner on-ramp on *top* of the existing senior depth; we never dumb the depth down.

A compliant topic file is laid out in this order:

---

## 1. `# Title` (existing — unchanged)

## 2. `## 🎯 Start Here — Intuition` *(new — the beginner on-ramp)*
Inserted immediately after the title / opening blockquote, **before** the first deep section. Exactly this shape:

```markdown
## 🎯 Start Here — Intuition

> **In one line:** <the problem this solves, in plain English — no jargon>.
>
> **Analogy:** <one concrete, everyday analogy a non-expert gets instantly>.
>
> **New to this?** Build the basics first in [`learn/<path>`](../../learn/<path>) — *then* come back for the depth.
> *(KB-only topic with no learn/ counterpart? Replace with: "**Assumes you already know:** X, Y." — link those prerequisites if they exist in learn/.)*
>
> **Level:** this file is 🟢/🟡/🔴 overall. Sections below are tagged. If the basics feel shaky, that tag is your signal to slow down — **you are not behind.**
```

**Rules for the on-ramp:**
- The analogy must be genuinely intuitive (model the corpus's good ones: "ships have watertight compartments", "airline seat tiers", "hotel front desk").
- The `learn/` link path is **relative**: from a file at `knowledge-base/<dir>/<file>.md`, the path to a learn topic is `../../learn/<topic-path>`. Find the correct counterpart in [`CROSS-REF-LEARNING-PATH.md`](CROSS-REF-LEARNING-PATH.md). **The link target must resolve to a real file.**
- Honesty: a genuinely advanced/KB-only topic (e.g. `async-rust`, `v8-internals`, `gpu-and-accelerator-computing`) is 🔴 and says so — don't pretend everything is beginner-reachable.

## 3. Difficulty gate + tiering on the deep sections
- Tag the major `##` section headings with 🟢 **foundational** / 🟡 **mid-level** / 🔴 **senior**, **honestly mixed** (not everything 🔴 — copy the discipline from `learn/`).
- Before the single deepest internals section, a one-line gate is welcome: *"⚠️ The rest assumes the basics above are solid."*

## 4. The substantive body (existing — **untouched**)
Intuition, history, internals, diagrams, code, worked examples, failure scenarios, real-world references. **Never edited by the on-ramp pass.**

## 5. `## Key Takeaways` (+ `## Interview angle` where unique) — from Phase 2
One consolidated takeaways block; no repeating summary sections.

## 6. Jargon glossing — every acronym glossed on first use or linked to [`GLOSSARY.md`](GLOSSARY.md).

---

### Why this makes it beginner-intuitive *without* losing depth
The on-ramp is a **door**, not a renovation. A newcomer reads the one-line problem + analogy, follows the `learn/` link to build fundamentals, sees the difficulty tags telling them when to stop — and the full senior/staff depth sits untouched below for when they're ready. Depth and approachability coexist; the only things removed were the padding (Phase 2) and the errors (Phase 1).
