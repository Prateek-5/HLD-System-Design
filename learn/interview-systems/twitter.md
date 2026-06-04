# Case Study — Design Twitter

## A. Intuition First
The interesting part is **the home timeline** — how do you show each user a recent feed of tweets from the people they follow?

## B. Requirements
**Functional**
- Post tweet (text + media).
- Follow / unfollow.
- Home timeline (chronological / ranked).
- Like, retweet, reply.
- Search.

**Non-functional**
- Home timeline p95 < 200 ms.
- 200M DAU (peak ~500k QPS for timeline reads).
- Write rate much lower than read.

## C. Estimation
- 500M tweets/day → ~6k/s avg write.
- Timeline loads: 200M × 20 reads/day → 2B reads/day → ~25k/s avg, 75k/s peak.
- Read:write ≈ 100:1.
- Storage: 500M × 300 B tweet metadata ≈ 150 GB/day. With media → PBs.

## D. High-Level Architecture
```
Client ─→ CDN/Edge ─→ API Gateway ─→ Tweet svc (writes)
                                ─→ Timeline svc (reads)
                                ─→ Follow svc
                                ─→ Media svc (S3)
                                ─→ Search svc (Elasticsearch)
```

## E. Deep Dives

### The home timeline — the core question
Three models:

**1. Pull (fan-out on read)**
- On timeline request, query all followed users' tweets, merge by timestamp.
- Simple. Terrible for users following 1000+ people → too many queries.

**2. Push (fan-out on write)**
- On tweet, write to each follower's pre-built timeline (Redis list).
- Reads: single lookup. Very fast.
- Writes: expensive — for a celeb with 100M followers, one tweet = 100M writes.

**3. Hybrid (Twitter's actual approach)**
- Push for normal users (low follower count).
- Pull for celebrities (high follower count) — compute their recent tweets at read time and merge.
- Stores per-user timeline in Redis (recent ~800 tweets).

🔗 **Related Questions**: [Q60: push vs pull vs hybrid](../03_interview_mode.md#q60-design-twitter-feed--push--pull--hybrid-) · ❗ [Confusion: "Twitter uses push for all users"](../04_confusion_resolver.md#-twitter-uses-push-fan-out-for-all-users)

### Celebrity threshold
~10k followers is a rough cutoff. Beyond that, pull.

### 🧮 The fan-out math that makes this obvious

| User type | Followers | Tweets/day | Writes (fan-out) |
|---|---|---|---|
| Normal | 200 | 2 | 400 / day (trivial) |
| Power user | 50,000 | 10 | 500,000 / day |
| Celebrity (e.g., Elon) | 100M | 50 | **5 billion writes / day** |

Push fan-out for a celeb = melt the feed-cache cluster. Pull for the celeb = at read time, just fetch their ~100 recent tweets from their own Cassandra partition and merge with pushed entries from normal follows.

**Storage note**: with hybrid, a user with 10 celeb follows pays 10 extra reads per feed load. Acceptable given the alternative is 5B writes/day per celeb.

> **🧠 What if Twitter used pure push for everyone?**
> The write-amplification for Taylor Swift alone (~95M followers × ~5 tweets/day = 475M writes/day) would consume ~5% of a Cassandra cluster's write capacity on one user. Hybrid is non-negotiable.
>
> **🔎 Quick Check** — Kim K tweets. Which path does that tweet take in a hybrid design?
> **🎯 Recall** — Stored in her own Cassandra partition; NOT fanned out. Her followers pull it at feed-load time.

### Storage
- Tweets: Cassandra keyed by user_id + tweet_id.
- Follows: graph DB or denormalized table in Cassandra.
- Timelines: Redis sorted sets per user.
- Search: Elasticsearch with a Kafka-driven indexer.

### Posting a tweet
1. Write to Cassandra.
2. Publish to Kafka `tweet.created`.
3. Fan-out service reads Kafka → writes to followers' Redis timelines.
4. Search indexer also reads Kafka → adds to Elasticsearch.

### Likes / retweets
- Counter per tweet (Redis hyperloglog / Redis INCR, then batched to DB).
- Eventually consistent: exact count not critical.

## F. Tradeoffs
- Push model: read-optimal, write-expensive. Acceptable because writes are much rarer.
- Hybrid handles celebrity fan-out tail.
- Eventual consistency on counters is OK.

## G. Interview Lens
- "Why push over pull?" — read latency.
- "How do you handle celebrities?" — hybrid.
- "How do you rank (vs chronological)?" — ML scoring service reorders timeline post-fan-out.
- "How do you dedupe retweets?" — timeline entries are tuples `(tweet_id, source_user_id)`.

## H. Questions
**Beginner**: Why is Twitter read-heavy?
**Intermediate**: Fan-out on read vs write?
**Advanced**:
1. Design ranked timeline (ML scoring).
2. Handle user deleting a tweet that's already fanned-out.

## I. Cross-Topic Connections
- [Caching](../foundations/scaling/caching.md), [Cassandra / NoSQL](../data/nosql-databases.md), [Pub-Sub](../architecture/pub-sub.md), [CDN](../foundations/scaling/cdn.md), [Sharding](../data/sharding.md).

## J. Confidence Checklist
- [ ] Can walk through tweet → fan-out → timeline.
- [ ] Knows hybrid fan-out.
- [ ] Can defend Cassandra for tweets.

## K. Potential Gaps & Improvements
- **Deletion propagation** — when a user deletes a tweet, you must remove it from every follower timeline it was already fanned-out to; matters because stale deleted content is a privacy and correctness bug (→ see Interview Lens).
- **Ranking model serving** — the online ML (Machine Learning) service that scores and reorders timeline entries in real time; key because chronological order alone misses what users actually want to see.
- **DM (Direct Message) subsystem** — the private one-to-one and group messaging feature, separate from the public tweet/timeline path; learners care because it needs its own storage, delivery, and read-receipt model.

**🔧 How to close:** Model fan-out yourself with a quick Redis experiment: `docker run --rm -d -p 6379:6379 redis`, then `redis-cli` and push a tweet ID into several follower timelines with `LPUSH timeline:1 tweet42`, `LPUSH timeline:2 tweet42`; now simulate deletion propagation by scanning and removing it from each list (`LREM timeline:1 0 tweet42`) and observe why per-follower deletion is O(followers) work.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🗑️ Gap 1 — Deletion & Edit Propagation Across Fanned-Out Timelines
- 🔹 **What it is**: Removing (or correcting) a tweet from the millions of pre-built Redis timelines it was already pushed into, plus from search indexes and caches.
- 🔹 **Why it matters**: A deleted tweet that still shows in feeds is a privacy and correctness failure — and the cleanup is O(followers), the mirror image of fan-out cost.
- 🔹 **Connection**: This file's posting flow pushes a tweet into every follower's Redis timeline via Kafka; deletion has to walk that same fan-out path *backwards*, and the celebrity/pull entries need handling too.
- 🔹 **When needed**: 🟢 **Foundational** — almost every "design Twitter/feed" interview asks "what happens on delete?"
- 🔹 **Intuition**: Mailing a flyer to 10,000 homes is one bulk action; recalling it means knocking on 10,000 doors. The send is cheap, the unsend is not.
- 🔹 **If you go deeper**: Read about tombstones in Cassandra (delete markers + compaction) and lazy filtering — many systems skip the O(followers) scrub and instead filter deleted IDs at read time against a "deleted set" (a Redis set or Bloom filter).
- 🔹 **Interview hook**: *"A user deletes a tweet already fanned out to 5M timelines — how?"* → don't eagerly scrub all 5M lists; keep a deleted-tweet set and filter at read time, then GC lazily during normal timeline rebuilds.

---

#### 🤖 Gap 2 — Ranking Model Serving (Chronological → ML-Ranked Timeline)
- 🔹 **What it is**: The low-latency ML (Machine Learning) service that scores candidate tweets and reorders the timeline by predicted engagement instead of pure recency.
- 🔹 **Why it matters**: Modern feeds aren't chronological; ranking drives engagement, and "how would you rank?" is the natural follow-up once the fan-out story is told.
- 🔹 **Connection**: This file fans out tweets into a per-user timeline, then notes an "ML scoring service reorders timeline post-fan-out" in the Interview Lens — this gap unpacks *how* that scoring service is built and served.
- 🔹 **When needed**: 🟡 **Mid-level** for product/ML-adjacent roles; 🔴 **Senior** when you must reason about feature stores and online inference latency budgets.
- 🔹 **Intuition**: A news editor doesn't print stories in the order they arrived — they put the most interesting ones above the fold. The model is that editor, scoring each item before layout.
- 🔹 **If you go deeper**: Study a two-stage candidate-generation → ranking pipeline (the pattern behind Twitter's open-sourced "the-algorithm" and YouTube's recommendation papers), and feature stores like Feast for serving precomputed features within a p95 budget.
- 🔹 **Interview hook**: *"How do you rank the timeline without blowing the 200 ms p95?"* → fan-out builds a small candidate set (~hundreds), a lightweight model scores them online using precomputed features, and heavy features are batched offline.

---

#### 💬 Gap 3 — Direct Message (DM) Subsystem
- 🔹 **What it is**: The private one-to-one and group messaging feature, with its own storage, delivery, ordering, and read-receipt model — separate from the public tweet/timeline path.
- 🔹 **Why it matters**: DMs are a different problem class (small fan-out, strict per-conversation ordering, often near-real-time delivery), so interviewers use it to test whether you can recognize when *not* to reuse the timeline design.
- 🔹 **Connection**: The whole file optimizes the public read-heavy timeline; DMs invert several assumptions (point-to-point, ordering matters, no celebrity fan-out), so it's a clean contrast to the fan-out machinery you just learned.
- 🔹 **When needed**: 🟡 **Mid-level** — common as a "now add DMs" extension question.
- 🔹 **Intuition**: The public timeline is a billboard everyone walks past; a DM is a sealed letter between two people. Different delivery system, different guarantees.
- 🔹 **If you go deeper**: Look at chat designs backed by a per-conversation partitioned store (Cassandra/HBase keyed by conversation_id + message_id) plus WebSocket gateways for push delivery; compare to WhatsApp/Messenger architecture write-ups.
- 🔹 **Interview hook**: *"Would you reuse the timeline fan-out for DMs?"* → no — DMs have tiny fan-out and need ordered delivery, so partition by conversation and push over a persistent connection rather than fanning into feed caches.

---

#### 🔥 Gap 4 — Hot Partitions & the Celebrity Read-Path Tail
- 🔹 **What it is**: The single-key overload that happens when one celebrity's tweets (in the pull path) or one viral tweet's counters are read by millions simultaneously, concentrating load on one partition/shard.
- 🔹 **Why it matters**: Hybrid fan-out solves the *write* amplification but creates a *read* hot spot — the celebrity's Cassandra partition and counter keys become the new bottleneck.
- 🔹 **Connection**: This file's hybrid model says celebrity tweets are pulled from "their own Cassandra partition" at read time and likes use a single Redis counter — both become hot keys at scale, the obvious next failure mode after fan-out.
- 🔹 **When needed**: 🔴 **Senior** — this is the depth that separates "I know the hybrid model" from "I know how it actually breaks."
- 🔹 **Intuition**: One popular checkout lane jams the whole store even when the building is huge. You fix it by replicating that lane's contents to many lanes, not by building a bigger store.
- 🔹 **If you go deeper**: Study read replicas / caching for hot celebrity partitions, key-splitting for counters (sharded counters that you sum on read), and request coalescing / negative caching; see the "hot key" handling in Facebook's TAO and Memcache papers.
- 🔹 **Interview hook**: *"A celebrity tweet goes viral — what's the new bottleneck after fan-out?"* → the read hot key; replicate/cache the celebrity partition and shard the like counter into N sub-counters summed at read time.

---

### 🏆 Start here if you have limited time
1. **Deletion & edit propagation** — the single most common follow-up to the fan-out story, and 🟢 reachable from what this file already taught.
2. **Ranking model serving** — the natural "now make it ML-ranked" pivot the Interview Lens already hints at.

---

### 🧭 Suggested Deep Dive Order
1. **Deletion & edit propagation** (~30 min; cements that unsend is O(followers) and teaches read-time filtering).
2. **Hot partitions & celebrity read tail** (~1h; reveals how the hybrid model breaks and how to defend it — senior signal).
3. **Ranking model serving** (~1.5h; two-stage candidate → ranking pipeline within a latency budget).
4. **DM subsystem** (~1h; contrast exercise — recognize when not to reuse fan-out).
