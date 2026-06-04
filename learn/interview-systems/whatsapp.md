# Case Study — Design WhatsApp

## A. Intuition First
A messaging system must push messages to online users in real time, queue them for offline users, and work across 2B daily devices.

## B. Requirements
**Functional**
- 1:1 chat, group chat, delivery receipts, read receipts, media, last-seen.
- Offline messages delivered on reconnect.
- E2E encryption.

**Non-functional**
- Latency < 500 ms for message delivery.
- Scale: billions of DAU.
- Available during partial failures.

## C. Estimation
- 100B messages/day → 1M/s average; 3M/s peak.
- 100 KB avg message (mostly text + metadata) → 10 PB/day.
- Most messages are small text; media is S3.

## D. High-Level Architecture
```
Mobile ── WebSocket ── Chat service (millions of conns)
                         │
                         ├─ Presence service (Redis)
                         ├─ Message store (Cassandra)
                         ├─ Message queue (Kafka) for async delivery
                         └─ Media: S3 + CDN
```

## E. Deep Dives

### Connection management
- Each user has a persistent WebSocket to a chat server.
- Chat servers shard users via consistent hashing.
- Gateway LB with sticky routing ensures reconnect lands on same shard (or handoff).

### Message delivery flow
1. Alice's phone → chat server A (her server).
2. Server A writes message to Cassandra (durable).
3. Server A looks up Bob's chat server (service discovery).
4. Sends message via internal RPC to server B.
5. Server B pushes over Bob's WebSocket.
6. Bob's app sends ack → server B → publishes delivery event.
7. Server A updates Alice's UI with "delivered".

If Bob offline: message stays in Cassandra with `pending_delivery` flag. On Bob's reconnect, server B flushes pending.

### Group chat
- Fan-out to N recipients.
- Small groups: per-recipient queue write.
- Large groups (256+): fan-out on read — recipients poll a group timeline.

### Encryption (Signal protocol)
- End-to-end: server never sees plaintext.
- Key exchange: X3DH + Double Ratchet.
- Server just stores ciphertext and routes.

### Presence (online, typing, last-seen)
- Redis sorted set: `user_id → last_seen_timestamp`.
- Updated on every connection heartbeat.
- Queried via pub-sub to subscribers (chat partners).

### Media
- Upload to object store (S3-equivalent).
- Reference URL in message.
- Served via CDN.

## F. Tradeoffs
- WebSocket → stateful servers → harder to scale (pod restarts drop connections).
- Cassandra for writes — massive throughput; eventual consistency is fine for messages (user apps handle ordering via message IDs + timestamps).
- Sticky routing to connection: consistent hashing + session reassignment on pod removal.

## G. Interview Lens
- "How many concurrent WebSockets per server?" — 500k–1M with careful tuning (WhatsApp famously pushed limits with Erlang/OTP).
- "How do you handle typing indicators at scale?" — ephemeral pub-sub, not persisted.
- "What about read receipts?" — optional event published on read.
- "How does media differ from text?" — upload to blob store, send reference.

## H. Questions
**Beginner**: Why WebSocket?
**Intermediate**: Presence design?
**Advanced**:
1. Design group chat for 1M-member groups.
2. Handle network partitions between chat regions.

## I. Cross-Topic Connections
- [WebSockets](../architecture/long-polling-websockets-sse.md), [Pub-Sub](../architecture/pub-sub.md), [Cassandra / NoSQL](../data/nosql-databases.md), [Consistent Hashing](../data/consistent-hashing.md), [CDN](../foundations/scaling/cdn.md).

## J. Confidence Checklist
- [ ] Full write-and-deliver message path.
- [ ] Presence via Redis.
- [ ] Group-chat fan-out strategies.

## K. Potential Gaps & Improvements
- **Multi-device sync** — keeping the same chat state in agreement across a user's phone, laptop, and tablet at once; matters because each device must converge on the same message order without a single source of truth.
- **State reconciliation** — the algorithm that merges divergent per-device views (e.g. CRDTs or vector clocks) so no message is lost or duplicated when devices reconnect; the hard core of any multi-device feature.
- **Disappearing messages** — messages auto-deleted after a timer (TTL, Time To Live) on both server and every client; care because you must guarantee deletion even on offline devices.
- **Spam/abuse detection at scale** — real-time classification of bad actors (bulk senders, scams) across billions of messages; matters because false positives block real users while misses harm them.

**🔧 How to close:** Model multi-device convergence locally: spin up a tiny Redis instance (`docker run -p 6379:6379 redis`), open two `redis-cli` clients, and use a sorted set keyed by message timestamp (`ZADD chat:1 1717459200 "hi"`) from each "device", then `ZRANGE chat:1 0 -1 WITHSCORES` from both to watch how ordering converges and where clock ties would force you to add a tiebreaker.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 📱 Gap 1 — Multi-Device Sync
- 🔹 **What it is**: Letting one account's phone, laptop, and tablet all show the same chat history and stay in agreement, with no single device being the "real" copy.
- 🔹 **Why it matters**: It's a top WhatsApp follow-up question, and it breaks the clean "one user = one WebSocket" model this file assumed — now one user has N connections, all needing the same encrypted messages.
- 🔹 **Connection**: The file's delivery flow routes a message to "Bob's chat server" (one). Multi-device means fanning out to *every* one of Bob's linked devices and tracking per-device delivery state.
- 🔹 **When needed**: 🟡 **Mid-level** — expected in any WhatsApp/Slack/iMessage design round.
- 🔹 **Intuition**: Like email on three devices — each opens the same inbox, and a message read on your phone shows as read on your laptop because they sync against a shared mailbox.
- 🔹 **If you go deeper**: Read Signal's "sealed sender" and multi-device design, and WhatsApp's 2021 companion-device architecture (each device holds its own identity key, server fans out ciphertext per device).
- 🔹 **Interview hook**: *"How does a message reach all of Bob's devices when only the phone was online at send time?"* → server stores the message per-device (or keyed by device list) and flushes to each device on its own reconnect, tracking delivery independently.

---

#### 🔀 Gap 2 — State Reconciliation (CRDTs & Vector Clocks)
- 🔹 **What it is**: The merge algorithm that combines divergent per-device views after they reconnect, so message order converges and nothing is lost or duplicated — without a central referee.
- 🔹 **Why it matters**: It's the hard core under multi-device sync; "use vector clocks / CRDTs" is the phrase that signals you actually understand distributed convergence rather than hand-waving "they sync."
- 🔹 **Connection**: The Tradeoffs section says apps "handle ordering via message IDs + timestamps" and Cassandra is eventually consistent — reconciliation is exactly *how* clients turn that eventual, possibly-conflicting state into one agreed timeline.
- 🔹 **When needed**: 🔴 **Senior** — genuine distributed-systems depth; most interviews accept a named technique without the full proof.
- 🔹 **Intuition**: Three editors annotate copies of the same document offline, then merge — a CRDT is the rulebook guaranteeing everyone ends with the identical merged document regardless of merge order.
- 🔹 **If you go deeper**: Read the Amazon Dynamo paper (vector clocks), Shapiro et al.'s CRDT papers, and Automerge/Yjs as working CRDT libraries you can run.
- 🔹 **Interview hook**: *"Two devices edit chat state offline, then reconnect — how do you avoid lost or duplicated messages?"* → use commutative merge (CRDT) or causal ordering (vector clocks) so concurrent updates merge deterministically instead of overwriting.

---

#### ⏳ Gap 3 — Disappearing Messages (TTL Across Devices)
- 🔹 **What it is**: Messages that auto-delete after a timer (TTL, Time To Live) — enforced on the server *and* every client, including ones that were offline when the timer expired.
- 🔹 **Why it matters**: It tests whether you can guarantee deletion in a system with offline devices and no central plaintext — a subtle correctness problem, not just a UI toggle.
- 🔹 **Connection**: The file stores messages in Cassandra with a `pending_delivery` flag flushed on reconnect; disappearing messages add a competing rule — a message might need to be deleted *before* an offline device ever pulls it, or deleted on the device right after.
- 🔹 **When needed**: 🟢 **Foundational** — Cassandra/Redis TTL is a beginner-reachable concept and a clean talking point.
- 🔹 **Intuition**: A self-destructing Snapchat note, but you must also burn the copy that was mailed to a friend who hasn't opened their mailbox yet.
- 🔹 **If you go deeper**: Use Cassandra's native `TTL` on writes (`INSERT ... USING TTL 86400`) and Redis key expiry; study how Signal ships the expire-timer as part of the encrypted payload so each client deletes locally.
- 🔹 **Interview hook**: *"How do you guarantee a 24h-expiry message disappears from a device that was offline for 48h?"* → embed the timer in the message, set server-side TTL so it's purged before delivery, and have the client honor the expiry at sync time even if late.

---

#### 🛡️ Gap 4 — Spam & Abuse Detection at Scale
- 🔹 **What it is**: Real-time classification of bad actors (bulk senders, scams, phishing) across billions of messages, while the server can't read message content.
- 🔹 **Why it matters**: It's a realistic curveball — moderation usually leans on content, but E2E encryption forbids that, so you must reason from metadata and behavior signals instead. False positives block real users; misses harm them.
- 🔹 **Connection**: The Encryption section establishes "server never sees plaintext" — that directly removes content-based filtering and forces you onto graph/velocity signals (send rate, new-account fan-out, report counts).
- 🔹 **When needed**: 🟡 **Mid-level** for the metadata-signals idea; 🔴 **Senior** for the streaming-ML pipeline behind it.
- 🔹 **Intuition**: A postal sorting office that can't open envelopes but flags the sender mailing 10,000 identical letters an hour to strangers.
- 🔹 **If you go deeper**: Study velocity/rate-based fraud detection, abuse-report feedback loops, and streaming feature pipelines (Kafka + Flink); read about WhatsApp's reliance on metadata signals and user reports.
- 🔹 **Interview hook**: *"How do you fight spam without reading messages?"* → score on metadata: send velocity, recipient fan-out to non-contacts, account age, and user-report rate, fed through a streaming classifier.

---

#### 🌍 Gap 5 — Cross-Region Routing & Partitions
- 🔹 **What it is**: Connecting two users whose chat servers live in different geographic regions, and keeping messaging working when the network between regions degrades or splits.
- 🔹 **Why it matters**: It's literally one of this file's own Advanced Questions, and it surfaces the availability-vs-consistency tradeoff that defines a senior answer.
- 🔹 **Connection**: The delivery flow does "service discovery → internal RPC to server B" assuming B is reachable; across regions that RPC crosses a WAN that can be slow or partitioned, so you need regional message queues and reconciliation on heal.
- 🔹 **When needed**: 🔴 **Senior** — multi-region design and partition handling are senior-infra signaling. → see Advanced Questions.
- 🔹 **Intuition**: Two post offices on different continents — if the undersea cable cuts, each keeps accepting local mail and forwards the backlog once the link is restored.
- 🔹 **If you go deeper**: Read about cross-region Kafka replication (MirrorMaker 2), the CAP theorem applied to messaging, and how systems queue-and-reconcile rather than block during a partition.
- 🔹 **Interview hook**: *"What happens to a message when the link between two regions drops mid-send?"* → durably queue it in the sender's region and asynchronously deliver on heal; favor availability (accept + retry) over blocking the sender.

---

### 🏆 Start here if you have limited time
1. **Multi-Device Sync (Gap 1)** — the single most common WhatsApp follow-up; it reshapes the whole routing model.
2. **Disappearing Messages (Gap 3)** — foundational and reachable now; a clean, concrete TTL story you can demo locally.

---

### 🧭 Suggested Deep Dive Order
1. **Multi-Device Sync** (~45 min; high interview payoff, sets up everything else).
2. **Disappearing Messages / TTL** (~30 min; foundational, hands-on with Cassandra/Redis TTL).
3. **Spam & Abuse without plaintext** (~1h; ties encryption to a realistic product constraint).
4. **State Reconciliation (CRDTs/vector clocks)** (~2h; deep distributed-systems theory, the engine under Gap 1).
5. **Cross-Region Routing & Partitions** (~1.5h; senior-infra; closes the loop with CAP and multi-region queues).
