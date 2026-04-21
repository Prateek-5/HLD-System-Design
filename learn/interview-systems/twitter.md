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
- Deletion propagation.
- Ranking model serving.
- DM (messaging) subsystem.
