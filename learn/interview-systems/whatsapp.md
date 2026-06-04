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
