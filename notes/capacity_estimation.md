# Capacity Estimation (Back-of-Envelope)

> **📎 Prereqs** — None, but helpful:
> - Numeric comfort (exponents, unit conversions).
> - [`load_balancing.md`](load_balancing.md), [`databases.md`](databases.md) — understanding where tiers bottleneck.

### 🔹 1. What This Topic Actually Is
Converting user scale to system scale: QPS, storage, bandwidth, memory. Done out loud in interviews.

### 🔹 2. Why It Exists
- Drives all architecture decisions. You can't pick "add a cache" without QPS.
- Demonstrates reasoning, not memorization.

### 🔹 3. Core Concepts (High Signal)
- **DAU → QPS**: `QPS_avg = DAU × actions_per_user / 86400`; peak = 2–3×.
- **Storage**: `bytes_per_record × records_per_day × retention_days`.
- **Bandwidth**: `QPS × avg_response_size`.
- **Memory**: cache working set = hot_percent × total_data.
- **Redundancy factor**: ×3 for HA replicas, ×2 for cross-region.
- **Numbers to memorize**:
  - 1 year = ~31.5 M seconds.
  - 1 day = 86,400 seconds.
  - RAM 100 ns; SSD 100 μs; HDD 10 ms; RTT cross-country ~50 ms.
  - Single DB node ≈ 10–50k QPS; Redis ≈ 100k+.

### 🔹 4. Internal Working (template)
```
DAU: _____
Actions/user/day: _____
Total actions/day: _____
QPS avg: actions / 86400 = _____
QPS peak: 2–3× avg = _____
Record size: _____ bytes
Daily data: records/day × size = _____
Yearly data: × 365 = _____
Cache: hot% × total = _____
Bandwidth: QPS × response size = _____
```

### 🔹 5. Key Tradeoffs
- Over-estimate → over-provision cost; under-estimate → failure.
- Peak matters more than average; p99 latency matters more than mean.

### 🔹 6. Interview Questions
**Beginner 🟢**
1. 10M DAU, each posting 2×/day. QPS?
2. Each record 1 KB, 100M/day. Daily bytes?

**Intermediate 🟡**
1. Design storage plan for 3-year retention of 100M events/day @ 500B each.
2. How much Redis RAM for 10M hot users × 1 KB profile?

**Advanced 🔴**
1. Model QPS growth 10× over 5 years — which tier breaks first?
2. Calculate bandwidth and cost of serving 4K video at 15 Mbps × 10M concurrent.

### 🔹 7. Real System Mapping
- **Google / YouTube capacity planning talks** (Jeff Dean's Stanford-295 slides are gold).
- **AWS re:Invent back-of-envelope sessions**.
- **Instagram**: 500M stories/day → 5800 QPS avg, ~17k peak.

### 🔹 8. What Most People Miss
- **Write amp for replication** — a 1 MB write ×3 replicas = 3 MB of disk/network.
- **Index overhead** — a table with 5 indexes has 5× write cost, plus storage.
- **JSON overhead** — serializing a 100-field record as JSON often doubles storage vs protobuf.
- **Headroom** — budget ≤70% utilization so you have room for spikes/failover.
- **People answer "1M QPS" from a single box** — that's cross-DC-tier math; a single box does thousands, not millions.

### 🔹 9. 30-Second Revision
Always: DAU → actions → QPS → peak (×3). Record size × records → storage; × retention → total. RAM = hot% × total. Bandwidth = QPS × size. Compare to single-node limit (10–50k DB QPS) to justify caches, shards, CDN. Keep ≤70% utilization.

---

## 🔗 Cross-Topic Connections
- **Databases**: estimation decides when to shard.
- **Caching**: cache size = hot working-set sizing.
- **Load Balancing**: peak QPS → LB capacity & backend count.
- **CDN**: bandwidth decides CDN necessity.

---

### Confidence Check
- [ ] Can I run the template out loud in 2 min?
- [ ] Can I translate numbers to architectural decisions?

### Gaps
- Cost modeling ($/month for a given QPS).
- Network egress costs (AWS surprise bills).
