# 🔍 Audit — `distributed-systems/`

**Reviewed:** 5 files (~1,943 lines) · **Lens:** brutal-honest, held to the corpus's own "senior/staff 3000+ word deep dive" claim · **Avg score: ~4.0/5**

---

## Verdict in one line
The strongest directory in the corpus so far: it actually gets the famously-botched theory right (CAP-only-during-partition, PACELC, FLP, 2PC-vs-Paxos, joint consensus, even-N anti-pattern) — dragged down by a recurring **SWIM detection-vs-dissemination conflation**, a **Figma/Linear CRDT overclaim**, and the corpus-wide ~35% redundancy from the repeating summary sections.

## Per-file scores (out of 5)

| File | Score | One-liner |
|---|---|---|
| `leader-election-and-consensus.md` | **4.5** | Genuinely staff-level; FLP/Raft/joint-consensus/lease-clock all correct |
| `cap-consistency-and-replication.md` | **4.3** | Excellent CAP/PACELC framing; CRDT-user list is the one soft spot |
| `clocks-time-and-ordering.md` | **4.2** | Accurate on Lamport/VC/HLC/TrueTime; UUIDv1 epoch detail is a nice flex |
| `distributed-transactions-2pc-3pc.md` | **3.9** | Correct on the blocking/coordinator/3PC-synchrony story; thin & padded in the back half |
| `gossip-protocols-and-membership.md` | **3.4** | Good intuition, but repeatedly miscites SWIM detection as O(log N) |

## Concrete errors found (must-fix)

- 🚩 **SWIM failure-detection time is mislabeled O(log N) — it's constant.** (`gossip-protocols-and-membership.md`) Line 108: *"Failure detection time: O(log N) rounds"* and line 68: *"`O(log N)` rounds to suspect."* SWIM's headline result is the opposite: expected time-to-first-detection is **independent of N** (each node probes one random member per protocol period, so first detection is O(1) in cluster size). What's O(log N) is *dissemination* of the membership update once detected. The file fuses the two. Correction: "detection latency ≈ constant (a small multiple of the protocol period, independent of N); dissemination of the update is O(log N)."

- 🚩 **Figma and Linear listed as CRDT users.** (`cap-consistency-and-replication.md`) Line 173: *"Used in: Riak, Redis (some types), collaborative editing (Yjs, Automerge), Figma, Linear, AWS DynamoDB Streams patterns."* Figma's own engineering blog ("How Figma's multiplayer technology works") explicitly states they did **not** use CRDTs — they use a server-authoritative last-writer-wins model closer to OT. Linear uses a custom client sync engine, not classic CRDTs. "AWS DynamoDB Streams patterns" is also a vague non-sequitur — Streams is a CDC feature, not a CRDT. Correction: keep Riak, Yjs, Automerge, Redis Enterprise Active-Active; drop Figma/Linear/DynamoDB-Streams or hedge them.

- 🚩 **"Redis (some types)" is imprecise.** (`cap-consistency-and-replication.md`, line 173) CRDTs live in **Redis Enterprise (Active-Active / CRDB)**, not open-source Redis. As written a reader will assume OSS Redis ships CRDTs. Minor but a real factual slip.

- 🚩 **Causal+ attribution is loose.** (`clocks-time-and-ordering.md`, lines 168–177) Causal+ ("causal + convergent conflict handling") comes specifically from the **COPS paper (Lloyd et al., 2011)**; the file presents it as generic vocabulary with no source. Not wrong, but for a "staff deep dive" the term deserves its origin. Low severity.

- 🚩 **No genuinely *false* statements in the other three files.** The 2PC, clocks, and consensus files were scrutinized hard against the hint list (FLP miscite, "3PC solves everything," CAP oversimplification) and **none of those traps was triggered** — see Strengths. Stating this explicitly so it isn't read as "didn't check."

### Things I checked that are actually CORRECT (resisting the urge to flag)
- CAP "formally proven by Gilbert & Lynch, 2002" — correct. (`cap`, line 82)
- The whole **"CA point is fictional / P is not optional"** framing — correct and is exactly the nuance most docs miss. (`cap`, line 89)
- **PACELC 2×2 with DynamoDB=PA/EL, Spanner=PC/EC** — correct. (`cap`, lines 97–102)
- **FLP**: "fully asynchronous … even one faulty process … no deterministic algorithm guarantees progress" — correctly stated and correctly used (not miscited for exactly-once, unlike the architecture-patterns dir). (`consensus`, line 44; `cap`, line 148)
- **3PC** "removes blocking *if the network is synchronous* … real networks aren't … correctness issues under partition" — exactly right; does NOT claim 3PC solves everything. (`2pc`, lines 129–131)
- **2PC vs Paxos**: "2PC requires unanimous participants; Paxos requires majority" — correct and well-put. (`2pc`, line 313)
- **Even-N tolerates same failures as N−1** (4 tolerates 1, same as 3) — correct. (`consensus`, line 163)
- **ZooKeeper reads are sequentially consistent, not linearizable** — correct and a genuinely senior nuance. (`consensus`, line 297)
- **Lease + clock-skew correctness coupling**, Pre-Vote optimization, snapshot install for far-behind followers, multi-Raft (~64MB ranges in Cockroach) — all correct. (`consensus`)
- **UUIDv1 timestamp = 100ns intervals since 1582-10-15** — correct Gregorian epoch. (`clocks`, line 234)
- **HLC = (physical, logical), monotonic, consistent-with-causality, constant size** and adopters (Cockroach/Mongo/FDB) — correct. (`clocks`)

## Genuine strengths (keep)

- **The consensus file is the template the rest of the corpus should imitate.** It separates safety vs liveness, ties FLP to "must make timing assumptions," gets the Raft safety invariant right ("a leader for term T has all entries committed in any term ≤ T"), and correctly insists membership changes use library joint consensus. The lease/clock-skew scenario (Scenario 5) is exactly the bug Jepsen finds in real systems.
- **CAP done by someone who has been burned by it.** "CAP isn't a steady-state choice — it only applies during partitions" and the immediate pivot to PACELC is precisely the senior framing. The tunable-consistency inventory worked example (eventual for bulk stock, consensus for last-N units, strong for payment) is real production reasoning, not a textbook recap.
- **Clocks file resists the NTP myth** ("Believing NTP makes clocks 'the same'" flagged as a trap), correctly separates monotonic vs wall-clock, and the ordering hierarchy (no-order → causal → sequential → linearizable → external) maps cost to coordination accurately.
- **2PC file's core thesis is correct and well-argued**: coordinator blocking is *inherent to the protocol structure*, Spanner "fixes" it by making the coordinator's decision a Paxos result, and sagas (compensation ≠ rollback) are the cross-service answer. The "rollback vs compensation" distinction (lines 182–187) is the part juniors miss.
- **Gossip file's anti-entropy vs rumor-mongering split, push-pull digest mechanics for Cassandra, phi-accrual mention, and the gossip-blocking-firewall failure scenario** are all real and useful, even though the O(log N) detection claim is wrong.

## Padding / redundancy assessment
**~35% redundant.** Every file carries the full suite of "Core Mental Models" → "What Junior Engineers Miss" → "What Senior Engineers Notice" → "20% Knowledge" → "Final Mental Model," and across those five sections the *same* bullet is frequently restated 3–4 times. Examples:
- "Even-sized consensus clusters are an anti-pattern / never run 4 nodes / 3,5,7 never 4" appears in **CAP** (lines 293, 305, 452) **and** in **consensus** (lines 163, 220, 229, 305, 317, 350) — i.e. ~6 times in one file plus 3 in another.
- "Use HLCs / reach for HLCs / HLCs for distributed timestamps" appears in clocks at lines 73, 153, 239, 332, 368, 380.
- "Gossip is eventually consistent, not strongly" appears in gossip at lines 70, 167, 307, 354.
The 2PC and gossip files in particular pad their back halves: the Performance/Scaling/Senior-Notices/20%/Final sections collapse into one-line restatements that add no new information. This repetition is exactly what inflates the word count to hit the "3000+" claim.

---

## 🛠️ Improvement plan (tailored to this directory)

**Theme: this dir is factually the *best* in the corpus — fix three real errors, then cut the padding that's hiding how good the theory already is.**

1. **Fix the SWIM detection complexity (highest priority — it's the one outright-wrong algorithm claim).** In `gossip`, change every "failure detection in O(log N)" to "detection latency is ~constant (independent of N); *dissemination* of the update is O(log N)." Add one sentence on SWIM's actual mechanism: round-robin (not purely random) ping target + indirect K-probe + suspicion mechanism (the "suspect" state that reduces false positives) — the file mentions K-probe but omits the suspicion sub-protocol that is SWIM's other contribution.
2. **Correct the CRDT adopter list** in `cap`: drop Figma (publicly NOT CRDT), Linear, and "DynamoDB Streams"; qualify Redis as "Redis Enterprise Active-Active." Add the genuinely-correct deep example the file is missing: **why LWW-Element-Set is the one CRDT that reintroduces the clock-skew problem the clocks file warns about** — that cross-file tension is a staff-level insight sitting right there unused.
3. **De-pad ~35%.** Collapse "Junior Misses / Senior Notices / 20% Knowledge / Final Mental Model" into a single "Key takeaways" block per file. The consensus and CAP files survive this easily; the 2PC and gossip files will lose almost nothing of value.
4. **Add the depth the 2PC file bails on.** It never explains **presumed-abort vs presumed-commit** optimizations (the standard way real XA implementations reduce log writes), never mentions **heuristic outcomes / heuristic hazard** (the actual XA term for the "manually committed/rolled-back a prepared txn" scenario it describes in prose), and never shows the **read-only optimization** (a participant that did no writes can vote read-only and drop out of phase 2). These are the things a staff interview on 2PC actually probes.
5. **Source the name-drops.** "GitHub's MySQL split-brain (2018)" (cap, line 279) — link the real postmortem or hedge it; "The 2023 GCP IAM outage" / "2023 GitHub partial outage" (cap, lines 404, 408) are vague enough to be unverifiable as written. Attribute Causal+ to COPS (clocks).
6. **Promote `leader-election-and-consensus.md` as the directory's reference template** — it is the model for how to be deep AND correct AND honest about operating (not just understanding) the system.
