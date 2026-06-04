# CQRS — Separate Writes from Reads

## A. Intuition First
CQRS = Command Query Responsibility Segregation. **Commands** (writes) use one model; **queries** (reads) use another. Two models, optimized separately.

Why: reads and writes have wildly different patterns — denormalized read models, different storage tech, different scaling.

## B. Mental Model
- **Command side**: normalized, transactional (SQL, event store).
- **Query side**: denormalized, eventually-consistent read views (materialized views, search index, cache).
- **Sync** between them via events / CDC.

## C. Internal Working
1. Client submits a command → command handler validates + persists (maybe emits event).
2. Event is propagated → query-side projector updates read models.
3. Clients read from read models (possibly stale but fast).

## D. Visual Representation
```
[Client]──Cmd──▶ [Write model / DB] ──events──▶ [Projector] ──▶ [Read model]
[Client]─────── Query ─────────────────────────────────────────▶ [Read model]
```

## E. Tradeoffs
**Pros**: scale reads and writes independently, optimize schemas per side, natural fit with event sourcing.
**Cons**: complexity, eventual consistency on read side, more moving parts.

Use CQRS where reads dominate and require aggressive denormalization. Don't use it for a simple CRUD app.

## F. Interview Lens
- "When CQRS?" — heavy-read + complex-write systems with divergent requirements.
- "CQRS without event sourcing?" — yes, often done (just sync read model via CDC).
- Pitfalls: applying CQRS everywhere; stale reads breaking user expectations.

## G. Real-World Mapping
Amazon product catalog, Twitter feed, most large e-commerce platforms.

## H. Questions
**Beginner**: What is CQRS?
**Intermediate**: How is consistency maintained between sides?
**Advanced**: Design a CQRS system for a forum (posts, comments, feeds).

## I. Mini Design
Forum:
- Write side: Postgres (users, posts, comments with FKs).
- Events on every write.
- Read model: Elasticsearch for search + Redis for feeds.

## J. Cross-Topic Connections
- [Event Sourcing](event-sourcing.md), [EDA](event-driven-architecture.md), [Caching](../foundations/scaling/caching.md).

## K. Confidence Checklist
- [ ] Knows command vs query separation.
- [ ] Knows it's eventual on the read side.

## L. Potential Gaps & Improvements
- **CDC (Change Data Capture)** — tools like Debezium stream every row change out of the write database into the read side so the two models stay in sync; the standard answer to "how do you sync without dual-writes?"
- **Read model rebuilds** — replaying the full event/change log to regenerate a query view from scratch; lets you fix bugs, add new projections, or recover a corrupted read store without touching the write side.
- **Eventual consistency lag** — the delay between a write landing and the read model reflecting it; matters because users may not see their own change immediately (→ see Interview Lens).
- **Projection idempotency** — making the projector safe to re-run the same event twice without double-counting; essential because at-least-once delivery means events repeat.

**🔧 How to close:** Spin up the Debezium tutorial stack with `docker-compose -f debezium-mysql.yaml up`, insert a row into the source MySQL table, then `kafka-console-consumer --topic dbserver1.inventory.customers` and watch the change event appear — that captured event is exactly what a CQRS projector would consume to update a read model.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔄 Gap 1 — Syncing the Two Models with CDC (Change Data Capture)
- 🔹 **What it is**: Streaming every committed row change out of the write database (via tools like Debezium reading the transaction log) so the read side updates automatically — no second write call.
- 🔹 **Why it matters**: The naive sync is a "dual write" — write to the DB *and* publish an event in app code — which silently loses data when the second call fails. CDC makes the log the single source of truth, so the read model can never drift from what was actually committed.
- 🔹 **Connection**: Section B says the two sides "Sync via events / CDC" and the How-to-close exercise consumes a Debezium topic. This gap is *how* that arrow in the diagram (`Write model ──events──▶ Projector`) is actually built reliably.
- 🔹 **When needed**: 🟢 **Foundational** — "how do you keep two stores in sync without dual-writes?" is the most common CQRS follow-up and the answer (CDC / outbox) is approachable now.
- 🔹 **Intuition**: A security camera recording everyone who walks through the front door. You don't ask each person to also sign a guestbook (dual write — they'll forget); you replay the tape. The DB's transaction log *is* the tape.
- 🔹 **If you go deeper**: Read about the **Transactional Outbox pattern** (write the event into an `outbox` table inside the same transaction as your data, then CDC ships the outbox row). Debezium's docs and Chris Richardson's *microservices.io* both cover Outbox + CDC.
- 🔹 **Interview hook**: *"How do you update the read model without dual-writes?"* → Write to the DB only; capture committed changes from its log via CDC (Debezium), optionally through an outbox table, and feed those into the projector.

---

#### ♻️ Gap 2 — Idempotent, Ordered Projections
- 🔹 **What it is**: Building the projector so replaying the *same* event twice (or out of order) produces the same read model — typically by tracking the last-processed event offset/version and ignoring duplicates or stale updates.
- 🔹 **Why it matters**: Event/CDC pipelines deliver **at-least-once**, so duplicates are guaranteed, not rare. A non-idempotent "increment likes by 1" projector will over-count; an order-blind one can overwrite newer data with older.
- 🔹 **Connection**: Directly expands the "Projection idempotency" gap bullet and Section C step 2 ("projector updates read models"). The projector is where eventual consistency either works or quietly corrupts data.
- 🔹 **When needed**: 🟡 **Mid-level** — expected once you claim to have built an event-driven read side; interviewers probe "what if the event arrives twice?"
- 🔹 **Intuition**: A hotel front desk stamping each guest's key card with a sequence number. If the same instruction slip arrives twice, the clerk checks "already did #47" and tosses the duplicate instead of charging the room again.
- 🔹 **If you go deeper**: Implement a projector that stores `last_event_version` per aggregate and uses `UPSERT` with a version check (`WHERE incoming_version > stored_version`). Read Kafka's idempotent-consumer patterns and the "deduplication" section of the Debezium docs.
- 🔹 **Interview hook**: *"At-least-once delivery means events repeat — how does your read model survive it?"* → Make writes idempotent (upsert by key + version guard) and persist the processed offset so duplicates are no-ops.

---

#### 🛠️ Gap 3 — Read-Model Rebuilds & Blue/Green Projections
- 🔹 **What it is**: Regenerating a query view from scratch by replaying the full change/event log into a fresh store, then atomically switching reads over — used to fix projection bugs, add new views, or recover a corrupted read model.
- 🔹 **Why it matters**: Because the read side is *derived* and disposable, you can fix a bug in a projection by deleting and rebuilding it — something impossible if reads and writes shared one schema. This is a headline CQRS superpower, not just maintenance.
- 🔹 **Connection**: Expands the "Read model rebuilds" gap bullet and pairs with the I. Mini Design (rebuild Elasticsearch/Redis from Postgres events without touching the write DB).
- 🔹 **When needed**: 🟡 **Mid-level** — strong signal you understand *why* CQRS pays off, beyond just "two models."
- 🔹 **Intuition**: A bakery that keeps the original recipe cards (the log) and the finished display cake (read model). If the icing's wrong, you don't repair the cake on the shelf — you bake a fresh one from the recipe and swap it in while customers still see the old one.
- 🔹 **If you go deeper**: Build a second projection into a new index/table, replay events from offset 0, and flip a feature flag / alias to cut over (Elasticsearch index aliases are made for this). Study how Event Sourcing systems do "projection rebuilds."
- 🔹 **Interview hook**: *"You shipped a bug in a read projection — how do you fix it in production?"* → Build a corrected projection in a new store, replay the log into it, then atomically switch reads via an alias; the write side never pauses.

---

#### ⏱️ Gap 4 — Managing Eventual-Consistency Lag (Read-Your-Own-Writes)
- 🔹 **What it is**: Strategies to handle the window where a write has committed but the read model hasn't caught up — so a user doesn't refresh and see their just-posted comment vanish.
- 🔹 **Why it matters**: This is the single most visible CQRS UX risk. Interviewers love it because the "correct" architecture can still feel broken to users; mitigations are a maturity signal.
- 🔹 **Connection**: Expands the "Eventual consistency lag" gap bullet and the F. Interview Lens pitfall "stale reads breaking user expectations."
- 🔹 **When needed**: 🟡 **Mid-level** — directly testable; → see Interview Lens for the framing.
- 🔹 **Intuition**: Mailing a letter (write committed) — the recipient's mailbox (read model) is empty for a day. To avoid confusion you hand them a photocopy at the door (serve the write side or client cache for *that* user) while the real mail arrives.
- 🔹 **If you go deeper**: Implement **read-your-own-writes** by reading from the command side (or a local cache) for the author for N seconds, or by passing a version token the read side waits for. Read about "monotonic reads" and version-token / `consistent_prefix` patterns.
- 🔹 **Interview hook**: *"User posts a comment but doesn't see it on refresh — fix it without making reads strongly consistent."* → Read-your-own-writes: serve that user from the write model / cache (or a versioned wait) while everyone else reads the eventually-consistent view.

---

### 🏆 Start here if you have limited time
1. **Syncing with CDC (Gap 1)** — the #1 CQRS follow-up ("no dual-writes"); foundational and reachable now.
2. **Eventual-consistency lag (Gap 4)** — the most visible failure mode and the easiest interview trap to fall into.

---

### 🧭 Suggested Deep Dive Order
1. **CDC / Transactional Outbox** (~1h; unlocks the core sync answer and the outbox pattern).
2. **Eventual-consistency lag & read-your-own-writes** (~45 min; high interview payoff, light to grasp).
3. **Idempotent, ordered projections** (~1h; the correctness backbone once events flow).
4. **Read-model rebuilds & blue/green projections** (~1h; cements *why* CQRS is worth the complexity).
