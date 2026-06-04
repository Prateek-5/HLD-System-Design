# 🔍 Audit — `architecture-patterns/`

**Reviewed:** 12 files (~5,436 lines) · **Lens:** brutal-honest, held to the corpus's own "senior/staff 3000+ word deep dive" claim · **Avg score: ~3.5/5**

---

## Verdict in one line
Above-average **intermediate** study material that is **reliable on principles and unreliable on particulars** — the classic profile of LLM-generated "deep dives" reviewed for vibe, not fact-checked for detail.

## Per-file scores (out of 5)

| File | Score | One-liner |
|---|---|---|
| `cqrs-and-event-sourcing.md` | **4.8** | Genuinely staff-level; accurate on the parts that bite |
| `microservices-vs-monolith.md` | **4.0** | Strong decision framework + worked example; ignore the latency numbers |
| `api-design-rest-vs-grpc.md` | **3.9** | Polished; great pagination/errors; latency framing misleads |
| `grpc-internals-and-streaming.md` | **3.6** | K8s LB trap is gold; proto3/backpressure slips |
| `anti-corruption-layer-and-domain-driven-design.md` | **3.6** | Most technically trustworthy; correct DDD |
| `saga-pattern-and-distributed-transactions.md` | **3.4** | Right concepts, but a **code bug** + vague citations |
| `idempotency-receivers-and-exactly-once-semantics.md` | **3.4** | Nails delivery-vs-effect; miscites FLP; CRDT overclaim |
| `strangler-fig-and-legacy-migration.md` | **3.4** | Best original judgment; **hallucinated history + reference** |
| `event-driven-architecture.md` | **3.4** | Solid fundamentals; "effectively-once" muddle, padded |
| `graphql-deep-dive.md` | **2.8** | Cheat sheet dressed as deep dive; avoids hard parts |
| `llm-serving-and-vector-databases.md` | **2.8** | Decent RAG primer; muddles latency, shallow quantization |
| `kafka-internals-and-stream-processing.md` | **2.6** | Broad-and-shallow; real omissions |

## Concrete errors found (must-fix)
- 🚩 **Hallucinated reference:** "GitHub MySQL → MariaDB migration" (strangler-fig) — does not exist; GitHub runs MySQL, famous tooling is `gh-ost`/Vitess.
- 🚩 **Fabricated history:** Roman-aqueduct "valve-by-valve strangler migration" presented as fact (strangler-fig).
- 🚩 **Code bug:** saga `compensate()` will refund a **post-pivot** payment, contradicting the pivot logic the same file teaches.
- 🚩 **Wrong theorem:** exactly-once impossibility attributed to **FLP**; it's the **Two Generals Problem** (idempotency).
- 🚩 **Overclaim:** "CRDTs are inherently idempotent" — it's the *merge* that's idempotent, not the operation (idempotency).
- 🚩 **Invented authority:** an "80/90/95 rule" dressed as an established named rule (strangler-fig).
- 🚩 **Repeated across 2 files:** "never change protobuf field types" — false; varint-family + string↔bytes are wire-compatible (grpc, api-design).
- 🚩 **proto3 "optional by default"** misstates field-presence semantics (grpc).
- 🚩 **Latency framing:** "gRPC 5–10× faster than REST," "REST is 100–500ms," microservices "~10ms minimum" — conflates serialization overhead with end-to-end latency.
- 🚩 **Kafka omissions:** `min.insync.replicas` never mentioned; partition-count-change-breaks-key-routing never warned; sticky partitioner (modern default) not flagged; compaction declared "its own beast" then never explained.
- 🚩 **GraphQL:** N+1 framed as a *benefit* (line 11) while correctly a server-side disaster later; "mutations sequential by spec" overstated (only top-level fields).
- 🚩 **LLM file:** self-contradictory latency taxonomy (TTFT vs total, lines 67 vs 140); quantization with no GPTQ/AWQ/FP8; "Pinecone: HNSW-based" shaky; int8 called "most production" (dated).
- 🚩 **Unsourced round numbers** as fact: "trillions of events," EOS "~10–30%."

## Genuine strengths (keep)
Correct on the commonly-botched marquee concepts (compensation ≠ rollback, pivot transactions, exactly-once *effect* vs *delivery*, snapshot-invalidation-on-logic-change, crypto-shredding, DataLoader array-ordering, DDD aggregate-sizing-by-invariant, PagedAttention/continuous batching). High-signal production gotchas: K8s gRPC load-balancing trap, `200`-with-error-body antipattern, offset-pagination drift, "measure migration by what's *deleted*." Honest failure-mode framing throughout.

---

## 🛠️ Improvement plan (tailored to this directory)

**Theme: this dir's problem is *factual particulars + padding*, not concepts.**

1. **Fix the 13 flagged errors above first** — these actively mislead. Priority order: saga code bug → hallucinated GitHub/Roman refs → FLP→Two Generals → proto-type rule → Kafka `min.insync.replicas`.
2. **De-pad every file (~30–50% reduction).** Collapse the five repeating summary sections ("Junior Misses / Senior Notices / 20% Knowledge / Interview Perspective / Final Mental Model") into **one** "Key takeaways" block. The repetition is what fakes the "3000+ word" depth.
3. **Replace name-drop citations with real ones.** "Stripe's extensive public engineering" → link the actual blog post, or delete. Every "company X did Y" needs a source or a hedge.
4. **Go deep where it currently bails.** Kafka: add compaction/tombstones, `min.insync.replicas`, ISR mechanics (`replica.lag.time.max.ms`), partition immutability. GraphQL: execution algorithm, complexity scoring, APQ vs allowlisted persisted queries. LLM: GPTQ/AWQ/FP8, parallelism, real TTFT/TPOT taxonomy.
5. **Add a "verify before you cite" disclaimer** at the top of the dir's index until the fact-pass is done.
6. **Promote the two best files** (`cqrs-and-event-sourcing`, `microservices-vs-monolith`) as the template the weak ones should imitate.
