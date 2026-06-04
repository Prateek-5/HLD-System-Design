# 📋 Audit Report — "Potential Gaps & Improvements" + "Guided Deep-Learning Layer"

**Scope:** All 56 topic files across the learning path (foundations, data, architecture, reliability, interview-systems, frameworks).
**Lens:** Quality *for an absolute-beginner reader* (someone new to system design who does **not** already know terms like BGP, mTLS, quorum, EDNS0, PKCE, LSM-tree).
**Date:** 2026-06-04

---

## TL;DR — the verdict

Your instinct is **half right, and the other half is more interesting than "bad writing."**

1. **"Potential Gaps & Improvements" (§L / §K): genuinely below average for a beginner.** Average score **2.5 / 5**. These are terse keyword/acronym dumps, rarely have the promised "How to close" note, and frequently reference terms the file never defined.
2. **"Guided Deep-Learning Layer": NOT badly written — it's actually the *best-written* content in the whole path (avg 3.0/5, peaks at 4/5).** Its problems are different and arguably worse: **it exists in only 12 of 56 files (79% missing)**, and where it exists it is pitched at **senior-interview altitude** for a reader the file itself just declared "not ready." So it's high-quality content aimed at the wrong audience and inconsistently present.

So: "far below average" is fair for the **Gaps** sections. For the **Guided** layer, the accurate criticism is **mis-targeted + missing**, not "low quality."

---

## Scorecard

| Metric | Value |
|---|---|
| Files audited | 56 |
| Files with a §L/§K Gaps section | 54 (frameworks files have none) |
| Avg Gaps score (beginner lens) | **2.5 / 5** |
| Files with a Guided Deep-Learning Layer | **12 / 56 (21%)** |
| Avg Guided score *where present* | **3.0 / 5** |
| Files where Guided layer is ABSENT | **44 / 56 (79%)** |
| Formatting defects (dup lines, broken md) | **None found** (the previously-reported dns.md duplicate headings are already fixed) |

---

## The three core problems (for a beginner)

### Problem 1 — The "deliberately-skipped-then-pushed" contradiction
By design, the Gaps section lists what the file **omitted because it was too advanced**. The Guided layer then expands those same topics and stamps nearly every one **"🔴 Important for senior interviews."** A beginner is simultaneously told "you weren't ready for this" and "go deep on this now." There is almost never a "master the fundamentals first" gate. This is a **structural design flaw**, not a wording problem.

### Problem 2 — Jargon with no scaffolding
The Gaps bullets are written as **topic labels for someone who already knows the topic**, not as learning prompts. Real examples pulled from the files:
- `acid-base.md`: *"Linearizability (another level above ACID)"* — also **factually sloppy** (conflates a consistency model with a transaction guarantee).
- `db-and-dbms.md`: *"Page layout on disk (slotted pages in Postgres)"* — deep internals in the gentlest intro file.
- `message-brokers.md`: *"Kafka internals (partitions, offsets, ISR)"* — **ISR never expanded.**
- `indexes.md`: *"BRIN, GIN, GiST details."* — three bare acronyms, one bullet.
- `service-discovery.md`: *"xDS protocol (Envoy)"* — opaque to a newcomer.
- `oauth-oidc.md`: *"PKCE for SPA / mobile"*, *"Token binding / mTLS tokens"* — acronym soup on a topic just introduced.
- `geohashing-quadtrees.md`: *"S2 Cells (Google)"* — a bare proper noun with no what/why.

Several gaps even reference a term **the same file used but never defined** (burn rate in `sla-slo-sli.md`, sidecar in `service-discovery.md`, ciphers in `ssl-tls-mtls.md`).

### Problem 3 — The promised "How to close" note is mostly missing
The template implies each Gaps list ends with an actionable "How to close" step. In practice it is **absent in the large majority of files**. The networking files are the exception and show what good looks like — concrete, hands-on commands a beginner can actually run:
- `dns.md`: *"run `dig +trace google.com` and read every line."*
- `osi.md`: *"run `tcpdump -nn -vv -X` on a local curl request and watch the headers unwrap."*
- `ip.md`: *"Run `traceroute google.com` … stare at the output."*
- `tcp-udp.md`: *"run `ss -tan` on a live server and read the states."*

These are the single most beginner-valuable thing in any of these sections — and they appear in only a handful of files.

---

## Where it actually works (so we know what "good" looks like)

The Guided layer, where present, is **genuinely strong** and should be the model:
- `circuit-breaker.md` (4/5): *"Ships have compartments — one flooding doesn't sink the ship"* (bulkheads); *"If you're in a hurry, call 3 Ubers and take the first one"* (hedging).
- `sharding.md` (4/5): migration as concrete phases (dual-write → backfill → reconcile → cutover → retire); *"moving a house while everyone still lives there."*
- `rate-limiting.md` (4/5): *"Airline seats — economy, business, first… different quotas"*; and it correctly **differentiates 🟡 mid-level vs 🔴 senior** instead of flagging everything senior.
- `caching.md` (3/5): cache-aside vs read-through is the most genuinely beginner-reachable deep-dive in the set.
- `api-gateway.md` (4/5): *"Gateway = hotel front desk. Mesh = internal phone system between hotel departments."*

The consistent skeleton (What it is / Why it matters / Connection / When needed / Intuition / If you go deeper / Interview hook) is excellent. The problem is never the skeleton — it's coverage and altitude.

---

## Full per-file scores

Legend: scores are 1–5 through the **absolute-beginner** lens. "ABSENT" = section does not exist.

### Foundations
| File | Gaps | Guided | Note |
|---|---|---|---|
| networking/dns.md | 2 | 2 | DNSSEC/DoH/EDNS0/anycast-BGP dump; well-written but mis-targeted |
| networking/ip.md | 2 | 2 | BGP/IPsec/BDP — senior topics for a "what is an IP" file |
| networking/osi.md | 3 | ABSENT | Short, fair; best "how to close" (tcpdump) |
| networking/proxy.md | 3 | ABSENT | Honest gaps, but no "how to close" |
| networking/tcp-udp.md | 2 | 2 | Nagle/BBR/BDP/SCTP; triage block helps |
| scaling/availability.md | 3 | ABSENT | Acronyms spelled out (MTTR/MTBF) — better hygiene |
| scaling/caching.md | 3 | 3 | Best beginner-reachable Guided block |
| scaling/cdn.md | 3 | ABSENT | Compact, honest |
| scaling/clustering.md | 3 | ABSENT | "SWIM" acronym unexplained |
| scaling/load-balancing.md | 2 | 2 | GSLB/DSR/BGP-anycast — staff/SRE altitude |
| scaling/scalability.md | 3 | ABSENT | Legit gaps (Amdahl's law) |
| scaling/storage.md | 3 | ABSENT | Solid (tiered storage, erasure coding) |

### Data
| File | Gaps | Guided | Note |
|---|---|---|---|
| acid-base.md | 2 | ABSENT | Jargon + a factual slip on linearizability |
| cap-theorem.md | 3 | 3 | Accurate, senior-pitched (CRDTs, Jepsen) |
| consistent-hashing.md | 3 | 3 | Great analogies; body has a dup sentence (lines 17/19) |
| database-federation.md | 2 | ABSENT | "lakehouse", CDC unglossed |
| database-replication.md | 3 | 3 | Strong; assumes Kafka/Paxos/TrueTime |
| db-and-dbms.md | 2 | ABSENT | Slotted pages/MVCC/2PL in the intro file |
| distributed-transactions.md | 2 | ABSENT | Paxos/TCC/outbox raw |
| indexes.md | 2 | ABSENT | BRIN/GIN/GiST dump |
| normalization-denormalization.md | 3 | ABSENT | Reasonably approachable |
| nosql-databases.md | 3 | ABSENT | Self-aware; LSM-tree unexplained |
| pacelc-theorem.md | 3 | ABSENT | TrueTime gets a helpful gloss |
| sharding.md | 3 | 4 | Best-in-data Guided block |
| sql-databases.md | 3 | ABSENT | Clear targets (isolation levels, EXPLAIN) |
| sql-vs-nosql.md | 3 | ABSENT | Most practical/beginner-friendly gaps |
| transactions.md | 3 | ABSENT | SSI/skew advanced but body primed it |

### Architecture
| File | Gaps | Guided | Note |
|---|---|---|---|
| api-gateway.md | 3 | 4 | Only architecture file with a Guided block; gold standard |
| cqrs.md | 2 | ABSENT | CDC/Debezium unexplained |
| enterprise-service-bus.md | 2 | ABSENT | "canonical data model anti-pattern" cryptic |
| event-driven-architecture.md | 2 | ABSENT | Avro/Schema Registry/Outbox dumped |
| event-sourcing.md | 3 | ABSENT | GDPR note is concrete & insightful |
| long-polling-websockets-sse.md | 3 | ABSENT | WebRTC/QUIC/MQTT, scoped to use case |
| message-brokers.md | 2 | ABSENT | Worst acronym density (ISR/Avro/Protobuf/DLQ) |
| message-queues.md | 3 | ABSENT | Lowest jargon barrier (FIFO, priority) |
| monolith-vs-microservices.md | 3 | ABSENT | Modular monolith / strangler fig — apt |
| n-tier-architecture.md | 3 | ABSENT | Single sensible pointer |
| pub-sub.md | 2 | ABSENT | EOS / schema registry — over the line |
| rest-graphql-grpc.md | 3 | ABSENT | Real next-steps (OpenAPI/Swagger) |

### Reliability
| File | Gaps | Guided | Note |
|---|---|---|---|
| circuit-breaker.md | 3 | 4 | Best-in-batch Guided block |
| disaster-recovery.md | 2 | ABSENT | Two bare jargon bullets |
| geohashing-quadtrees.md | 2 | ABSENT | H3/S2/R-tree product names |
| oauth-oidc.md | 2 | ABSENT | PKCE/mTLS acronym soup |
| rate-limiting.md | 3 | 4 | Good analogies; correctly tiers difficulty |
| service-discovery.md | 2 | ABSENT | "xDS protocol (Envoy)" unusable for beginner |
| sla-slo-sli.md | 2 | ABSENT | "multi-window, multi-burn-rate" name-drop |
| ssl-tls-mtls.md | 2 | ABSENT | QUIC/CT-logs/cipher tuning |
| sso.md | 3 | ABSENT | Most relatable (MFA/CSRF) |
| vms-and-containers.md | 2 | ABSENT | CNI/supply-chain abbreviations |

### Interview-systems & Frameworks
| File | Gaps | Guided | Note |
|---|---|---|---|
| interview-systems/netflix.md | 2 (§K) | ABSENT | DRM/A-B-testing bare nouns |
| interview-systems/twitter.md | 2 (§K) | ABSENT | "ranking model serving" insider shorthand |
| interview-systems/uber.md | 2 (§K) | ABSENT | Slight parentheticals help |
| interview-systems/url-shortener.md | 2 (§K) | ABSENT | Redundant with Interview Lens |
| interview-systems/whatsapp.md | 3 (§K) | ABSENT | Best gaps — multi-device bullet self-explains |
| frameworks/request-lifecycle.md | ABSENT | ABSENT | No gaps section at all |
| frameworks/thinking-framework.md | ABSENT | ABSENT | No gaps section at all |

---

## Recommendations (highest leverage first)

1. **Fix the audience contradiction.** Add a one-line gate at the top of every Guided layer: *"Only come here after the rest of this file feels solid."* And reserve 🔴-senior tags for genuinely senior topics — copy `rate-limiting.md`'s 🟢/🟡/🔴 tiering everywhere.
2. **Gloss every jargon term in the Gaps list.** Rule: no acronym or product name without a 5–10 word "what it is + why you'd care." Model: `whatsapp.md`'s *"Multi-device sync (state reconciliation is its own problem)."*
3. **Make "How to close" mandatory.** Every Gaps section ends with one concrete, beginner-doable action — ideally a runnable command like the networking files (`dig +trace`, `tcpdump`, `ss -tan`, `traceroute`).
4. **Resolve the coverage gap.** Either add a Guided layer to the other 44 files, or remove the feature from the 12 and stop advertising it in `00_learning_path.md` — current state is misleadingly inconsistent.
5. **Kill redundancy.** Several Gaps lists just restate the file's own "Interview Lens" / "Advanced Questions." Cut or cross-link.
6. **Fix the small accuracy slip** in `acid-base.md` ("linearizability … another level above ACID").
