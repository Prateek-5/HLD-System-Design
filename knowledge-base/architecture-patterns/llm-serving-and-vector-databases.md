# LLM Serving & Vector Databases

> *"Serving large language models in production has emerged as one of the hardest infrastructure problems of the 2020s. Models that need 80GB of GPU (Graphics Processing Unit) memory; latency expectations measured in tokens per second; cost per query that makes traditional API economics look cheap. Vector databases are the new index — semantic similarity instead of keyword match. Together they're the substrate of every retrieval-augmented generation (RAG) system, every modern semantic search, every AI-native product."*

---

## 🎯 Start Here — Intuition

> **In one line:** how to run an AI model as a real production service — answering quickly and affordably — and how to feed it the *right* background facts so it answers about *your* data instead of making things up.
>
> **Analogy:** a research librarian with a fast archive. You ask a question; the librarian doesn't answer from memory alone — they pull the few most *relevant* passages from the archive and lay them on the desk, *then* write your answer from those passages. The archive that finds passages "by meaning" is the **vector database**; the librarian who writes the answer is the **LLM (Large Language Model)**.
>
> **Assumes you already know:** what a web API and request/response look like, and the basics of caching. Build those first in [`learn/architecture/rest-graphql-grpc.md`](../../learn/architecture/rest-graphql-grpc.md) and [`learn/foundations/scaling/caching.md`](../../learn/foundations/scaling/caching.md) — *then* come back for the depth. (This is a KB-only senior/staff topic with no beginner learning-path counterpart.)
>
> **Level:** this file is 🟡/🔴 overall — the intuition and RAG flow are approachable, but the serving internals (KV cache, batching, ANN algorithms) are genuinely advanced. Sections below are tagged. If the basics feel shaky, that tag is your signal to slow down — **you are not behind.**

---

## Topic Overview 🟢

The deployment of large language models has created an entirely new infrastructure category. Traditional web services serve sub-millisecond responses from megabytes of state. LLM serving systems handle requests that take seconds, run on multi-GPU hardware, generate output token-by-token, and cost dollars per query. The constraints are different; the architecture is different; the operations are different.

**Vector databases** — Pinecone, Weaviate, Qdrant, pgvector, Chroma, Milvus — emerged in parallel. They store and query vector embeddings using approximate nearest neighbor (ANN) algorithms. The killer use case: retrieval-augmented generation (RAG), where the LLM is given relevant context retrieved by semantic similarity.

Together they form the modern "AI stack": embeddings in vector databases; LLMs serving inference; orchestration layers gluing them together. Engineering teams that built scalable web services in the 2010s are learning new disciplines: GPU scheduling, attention computation, KV (Key-Value) cache management, semantic chunking, prompt engineering at scale.

This is the topic for the AI era. Not the model training (that's research-grade); the *serving* and *retrieval* infrastructure that makes AI products work in production.

---

## Intuition Before Definitions 🟢

Imagine running a research library where every book is indexed by *meaning* rather than keyword.

A query "tell me about ancient maritime trade" doesn't find books with those exact words; it finds books *about that topic*, even if they say "Mediterranean shipping in the 4th century BC." The matching is semantic.

To do this: every book is converted to a numerical fingerprint (embedding) capturing its meaning. Queries also become fingerprints. Similar fingerprints = similar meaning. Find similar.

Now: "for a question about ancient maritime trade, retrieve relevant passages, then ask a knowledgeable librarian (LLM) to write an answer using those passages." The librarian doesn't have to know everything — they have the right passages in front of them.

That's RAG. Vector database for semantic retrieval; LLM for generation. The combination is the dominant pattern for AI-augmented information systems.

---

## Historical Evolution 🟢

**Era 1 — Word embeddings.**
2013. Word2Vec demonstrates that words can be represented as vectors capturing semantic relationships.

**Era 2 — Sentence/document embeddings.**
2018+. BERT, sentence-transformers. Rich vector representations of longer text.

**Era 3 — Transformer LLMs.**
2017+. Attention is all you need. Transformer architecture. GPT family scales it.

**Era 4 — ChatGPT moment.**
2022. ChatGPT launches; mainstream adoption. Demand for LLM serving infrastructure skyrockets.

**Era 5 — RAG and vector databases.**
2022+. RAG pattern crystallizes. Vector databases (Pinecone funded; pgvector grows; many alternatives) explode.

**Era 6 — Production maturation.**
2024+. Inference servers (vLLM, TensorRT-LLM, etc.); serving optimization; cost reduction. Open-source models (Llama, Mistral) rival commercial. Edge inference emerging.

The pattern: an entirely new infrastructure category, evolving rapidly. Standards still forming.

---

## Deep Technical Explanation 🔴

> ⚠️ The rest of this section assumes the basics above are solid — it dives into GPU memory, KV cache, batching, and ANN internals.

### LLM inference fundamentals

A transformer LLM takes input tokens and predicts the next token. Generation: predict next; append; predict next; until done.

Computation per token:
- Many matrix multiplications.
- Attention over previous tokens.
- Vocabulary projection at the end.

Memory:
- Model weights (GBs to TBs).
- KV cache (previous tokens' attention state).

For a 70B parameter model in fp16 (16-bit floating point): 140GB just for weights. Inference requires GPU memory for weights + KV cache + activations.

### KV cache

The "memory" of generation. For each input token, attention computation produces key and value tensors that subsequent tokens attend to. Caching these across tokens avoids recomputation.

KV cache grows with each generated token. For long sequences, can be GBs per request.

KV cache management is one of the dominant infrastructure problems in LLM serving.

### Inference servers

**vLLM**: open-source; introduces PagedAttention for KV cache management.
**TensorRT-LLM**: NVIDIA's optimized inference.
**TGI (Text Generation Inference)**: Hugging Face's server.
**Triton Inference Server**: NVIDIA's general-purpose.

Common features:
- **Dynamic batching**: process multiple requests in one GPU pass.
- **Continuous batching**: add new requests to running batch.
- **KV cache management**: efficient memory layout.
- **Quantization support**: smaller weights for less memory.

### Continuous batching

Traditional batching: group N requests; process together; wait for slowest.

Continuous batching: at each generation step, dynamically include any new requests. Throughput much higher; latency more uniform.

vLLM and similar implement this. Throughput improvements 2-10× over naive batching.

### Quantization

Reduce weight (and sometimes activation) precision: fp32 (32-bit floating point) → fp16/bf16 (brain floating point) → fp8 → int8 → int4.

Trade-offs:
- Smaller memory; can fit larger models.
- Faster inference.
- Slightly worse quality (varies by model, method, and task).

High-quality serving commonly runs at fp16/bf16. For compression, weight-only 4-bit methods such as GPTQ (Generative Pre-trained Transformer Quantization) and AWQ (Activation-aware Weight Quantization) are widely used, and FP8 has become common on newer hardware (e.g. NVIDIA Hopper/Ada and later). The right choice depends on the model, the accelerator, and the accuracy budget — there is no single "default" precision across production.

### Streaming output

LLMs generate token-by-token. Server streams to client:
- Server-sent events (SSE) is common.
- HTTP/2 or HTTP/3 streams.
- Each token as it's generated.

User experience: text appears progressively. The key latency metrics are time-to-first-token (TTFT, how soon output starts) and inter-token latency / TPOT (how fast it then streams); together with output length they determine total response time.

### Vector embeddings

A vector in some high-dimensional space (typically 384-3072 dimensions) representing meaning.

Producing embeddings:
- Pass text through an encoder model (sentence-transformers, OpenAI's embeddings, etc.).
- Output is a vector.

Properties:
- Similar meaning → similar vectors (cosine similarity, dot product, or Euclidean).
- Different meanings → different vectors.

Quality of embeddings depends on the encoder model.

### Approximate Nearest Neighbor (ANN)

Exact nearest-neighbor search: O(N) — compare query to every vector. Doesn't scale.

ANN: find approximately-nearest vectors much faster. Trade some accuracy for massive speed.

Common algorithms:
- **HNSW (Hierarchical Navigable Small World)**: graph-based; fast; high quality.
- **IVF (Inverted File Index)**: cluster-based; scales to billions.
- **PQ (Product Quantization)**: compresses vectors; smaller memory.

Most vector databases use HNSW or hybrid approaches.

### Vector databases

**Pinecone**: fully managed; proprietary indexing (the exact ANN algorithm isn't publicly specified — don't assume plain HNSW).
**Weaviate**: open-source; rich features.
**Qdrant**: open-source; Rust; performant.
**pgvector**: Postgres extension; SQL integration.
**Chroma**: simple; embedded-first.
**Milvus**: open-source; large-scale.

Differences: managed vs self-hosted; query language; features (filters, hybrid search); performance; ecosystem.

### Hybrid search

Combine vector search with keyword search:
- Vector: semantic similarity.
- Keyword: exact-match (BM25, Best Matching 25).
- Reranker: combines results.

Often produces better results than either alone. Standard pattern in production RAG.

### RAG pattern

Retrieval-Augmented Generation:

1. **Query** comes in: "What's our return policy?"
2. **Embed** the query.
3. **Retrieve** top-K similar passages from vector DB.
4. **Construct prompt**: query + retrieved passages.
5. **Generate** with LLM, given the context.
6. **Return** answer.

Critical: the LLM is given the context; it doesn't need to "know" the answer. RAG works because LLMs are good at synthesizing from context.

### Chunking

Documents are split into chunks before embedding. Why:
- LLMs have context limits.
- Smaller chunks = more precise retrieval.
- Larger chunks = more context per match.

Strategies:
- Fixed-size (e.g., 500 tokens).
- Semantic (split at paragraph/section boundaries).
- Overlapping windows (avoid losing info at chunk boundaries).

Chunking quality dramatically affects retrieval quality.

### Production challenges

**Cold start.** Loading a 70B model into GPU memory takes minutes. Auto-scaling is slow.

**Cost.** GPU instances are expensive. Cost per query is significant.

**Latency variance.** Generation time depends on output length. Variable.

**Quality drift.** Updates to the model or embedding can change behavior. Monitoring quality.

**Hallucination.** LLMs make things up. RAG mitigates but doesn't eliminate.

**Context limits.** Even with RAG, limits hit on complex queries.

### Operational patterns

- **Caching**: identical queries; cache responses.
- **Routing**: cheap models for easy queries; expensive for hard.
- **Streaming**: improve perceived latency.
- **Quotas**: per-user rate limits; cost management.
- **Quality monitoring**: track outputs; detect regressions.
- **Prompt management**: version prompts; A/B test.

### Latency taxonomy: prefill vs. decode 🔴

Two distinct phases with different cost profiles, and conflating them is the classic mistake.

- **Prefill** processes the entire prompt in one parallel forward pass and produces the first token. It is **compute-bound** (one big matmul over all prompt tokens) and its cost scales with *input* length. The latency it produces is **TTFT (time-to-first-token)**.
- **Decode** generates the remaining tokens one at a time, each pass attending over the growing KV cache. It is **memory-bandwidth-bound** (you re-read all weights + KV cache per token, doing little compute), and its cost scales with *output* length. The per-token latency here is **TPOT (time-per-output-token)**, also called **ITL (inter-token latency)**.

The total wall-clock for a request is approximately:

```
total ≈ TTFT + (output_tokens − 1) × TPOT
```

Implications that interviewers probe:
- A long prompt with short output is dominated by TTFT (prefill); a short prompt with long output is dominated by output_tokens × TPOT (decode). Optimizing the wrong phase wastes effort.
- Because decode is bandwidth-bound, **batching helps decode dramatically** (amortize the weight read across many concurrent requests) but helps prefill less. This is why continuous batching is mostly a decode-throughput win.
- **Prefix caching** (reusing the KV cache for a shared prompt prefix, e.g. a fixed system prompt) cuts prefill cost and TTFT directly.
- SLOs are usually written as p50/p99 on **TTFT** and on **TPOT** separately, not on a single "latency" number.

### Quantization methods (not just a bit-width ladder) 🔴

Precision reduction is a family of *methods* with different mechanisms and accuracy profiles — the `fp16 → int4` ladder hides this.

- **Weight-only PTQ (post-training quantization)** — **GPTQ** and **AWQ**. Weights are stored in int4/int3 while activations and the matmul accumulate in higher precision (weights are dequantized on the fly). This targets the *memory-bandwidth* bottleneck of decode, since fewer bytes are read per token. GPTQ uses a second-order (Hessian-based) error-correction to choose rounding; AWQ scales the most "activation-salient" weight channels before rounding to protect them. Both are mainly aimed at memory/throughput, not raw compute.
- **GGUF k-quants** (the llama.cpp ecosystem, e.g. `Q4_K_M`, `Q5_K_M`, `Q6_K`) — mixed-precision blockwise quantization where different tensors/blocks get different bit-widths, keeping sensitive layers (e.g. attention output, some FFN) at higher precision. This is the dominant format for CPU/Apple-silicon and consumer-GPU local inference.
- **FP8** (E4M3 / E5M2) on **NVIDIA Hopper (H100) and Ada (L4/L40S) and later** — a *hardware-accelerated* low-precision format with native tensor-core support, so it speeds up the actual matmul (not just memory) and can quantize activations too. This is now common for high-throughput datacenter serving.
- **int8** (e.g. LLM.int8(), SmoothQuant) — weight+activation 8-bit; SmoothQuant migrates activation outliers into the weights so activations quantize cleanly.

Accuracy caveat: int8 and good 4-bit weight-only quant are often near-lossless on many tasks, but **int4 quality loss is not uniformly "slight."** It is highly model-, method-, and task-dependent — small models, long-context reasoning, and code/math tasks degrade noticeably more than short factual QA, and aggressive 3-bit or activation quantization can be sharply worse. Always evaluate on your own task, not on a generic benchmark.

### HNSW tuning: M, efConstruction, efSearch 🔴

HNSW exposes three knobs that trade recall against latency and memory; knowing what each does is a common vector-DB interview check.

- **`M`** — max number of graph neighbors (edges) per node per layer. Higher `M` → denser graph → better recall and more robust connectivity, but **higher memory** (edges stored per vector) and somewhat slower inserts. Typical values ~8–48 (≈16 is a common default).
- **`efConstruction`** — size of the candidate list explored while *building* the index. Higher → better-quality graph (higher achievable recall) at the cost of slower, more expensive index builds. It is a build-time-only cost; it does not affect query latency directly.
- **`efSearch`** (a.k.a. `ef`) — size of the candidate list explored at *query* time. This is the primary recall/latency dial: higher `efSearch` → higher recall but more distance computations → higher query latency. It can be tuned per-query without rebuilding the index. Note `efSearch` must be ≥ the requested `top_k`.

The tradeoff triangle: **recall ↔ latency ↔ memory.** `M` and `efConstruction` are baked in at build time (and `M` drives memory); `efSearch` is the live latency/recall lever. The usual workflow is to fix a recall target (e.g. recall@10 ≥ 0.95) and raise `efSearch` until you hit it, then read off the resulting latency. For very large or memory-constrained indexes, HNSW is often combined with **PQ** (product quantization) to compress the stored vectors, or replaced by **IVF** partitioning to bound the search space.

### Multi-GPU parallelism & speculative decoding 🔴

When a model (or its KV cache) exceeds one GPU, or when decode latency must drop, two orthogonal techniques appear:

- **Tensor parallelism (TP)** — split *each* layer's weight matrices across GPUs; every GPU holds a shard of every layer and they combine via an all-reduce each layer. Low added latency per token but **communication-heavy**, so it is normally kept *within one node* over fast interconnect (NVLink).
- **Pipeline parallelism (PP)** — assign *different layers* to different GPUs/nodes; activations flow stage-to-stage. Far less communication, so it spans nodes, but it introduces pipeline "bubbles" and needs micro-batching to keep stages busy. TP and PP are commonly combined (TP within a node, PP across nodes) for the largest models.
- **Speculative decoding** — a fast *draft* model proposes several tokens ahead; the large *target* model then verifies them in a single parallel forward pass, accepting the longest correct prefix and rejecting the rest. Because verification is one batched pass rather than N sequential decode steps, accepted tokens are nearly free — cutting effective TPOT (often ~1.5–3× faster) **with no change to the output distribution** (the target model's tokens are guaranteed identical to greedy/sampled decode). Self-speculative variants (e.g. Medusa, n-gram/prompt lookup) avoid maintaining a separate draft model.

---

## Real Engineering Analogies 🟢

**The research librarian with relevant excerpts.**
You ask a question. The librarian doesn't just answer from memory. They first consult the archive, find relevant excerpts, lay them in front of you, and *then* synthesize an answer. The archive is the vector database; the librarian's synthesis is the LLM.

**The on-call doctor with patient charts.**
The doctor has expertise but doesn't know specific patients. They consult charts; they synthesize a recommendation. The chart system is the retrieval; the doctor's reasoning is the model.

---

## Failure Scenarios 🟡

**Scenario 1 — The cost shock.**
Product launches with LLM features. Token usage 10× expected. Bill in first month: $200K. Recovery: prompt optimization; cheaper model for simple queries; cap usage per tier.

**Scenario 2 — The hallucination.**
Customer support chatbot confidently makes up policy. Customer makes business decisions on it. Legal exposure. Recovery: strict grounding via RAG; "I don't know" training; legal review of outputs.

**Scenario 3 — The retrieval gap.**
RAG misses relevant docs because of bad chunking. Users frustrated; they keep asking; LLM hallucinates. Mitigation: better chunking; semantic search tuning.

**Scenario 4 — The slow cold start.**
GPU instance restarts; takes 5 minutes to load model. Auto-scaler triggered by load; new instances slow. Mitigation: provisioned concurrency.

**Scenario 5 — The privacy leak.**
Embeddings of customer data sent to third-party API. GDPR (General Data Protection Regulation) concerns. Mitigation: self-host embedding model.

---

## Performance Perspective 🟡

- **Inference latency**: hundreds of ms to seconds.
- **Throughput**: tokens per second; varies by model.
- **Vector search**: milliseconds for tens of millions of vectors.
- **Cost**: $0.001-$0.10 per query depending on model and tokens.

---

## Scaling Perspective 🟡

- **Vertical**: bigger GPUs; H100s, B100s.
- **Horizontal**: many GPUs serving in parallel.
- **Tiered**: cheap model first; escalate to expensive.
- **Caching**: aggressive at every layer.
- **Edge**: inference at edge becoming feasible for smaller models.

---

## Cross-Domain Connections 🟡

- **Caching**: LLM responses cached aggressively. (See [caching-hierarchy.md](../caching/caching-hierarchy.md).)
- **API design**: LLM APIs have streaming, special semantics. (See [api-design-rest-vs-grpc.md](./api-design-rest-vs-grpc.md).)
- **GPU computing**: inference is GPU-bound.
- **Edge computing**: inference at edge for low-latency. (See [edge-computing-and-cdns.md](../scalability/edge-computing-and-cdns.md).)
- **Backpressure**: rate limits per user; tiered. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Observability**: quality and cost monitoring. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)

The unifying observation: **LLM serving and vector databases are the new infrastructure layer for AI-native applications. The operational patterns differ from traditional web serving; the engineering disciplines (caching, batching, quality monitoring, cost optimization) recur with new specifics.**

---

## Real Production Scenarios 🟡

- **OpenAI's serving infrastructure**: extensively documented.
- **Anthropic's Claude serving**: similar scale.
- **Cohere's serving**: enterprise focus.
- **Open-source self-hosted**: vLLM, llama.cpp deployments.
- **Pinecone customers**: many public case studies.
- **Hybrid RAG patterns**: standard at most AI-native companies.

---

## Key Takeaways 🟢

- **LLM inference is GPU-bound, latency-variable, and expensive** — different constraints and optimizations than traditional web serving.
- **Token-by-token generation is the dominant pattern.** Latency splits into time-to-first-token (TTFT, prefill before the first token) and inter-token latency (TPOT, per-token streaming rate); total response ≈ TTFT + (output tokens × TPOT). Which matters depends on the use case.
- **Prefill (compute-bound, scales with input → TTFT) and decode (memory-bandwidth-bound, scales with output → TPOT) are different phases**; batching mostly helps decode, prefix caching cuts TTFT, and SLOs are set on TTFT and TPOT separately.
- **Quantization is a family of methods, not a bit ladder**: weight-only GPTQ/AWQ and GGUF k-quants attack memory bandwidth; FP8 on Hopper/Ada accelerates the matmul itself. int8 and good 4-bit are often near-lossless, but **int4 quality loss is model/task-dependent** — evaluate on your own task.
- **Vector embeddings represent meaning numerically**; similarity in vector space ≈ similarity in meaning, and ANN algorithms (HNSW graph-based, IVF cluster-based) find similar vectors fast.
- **HNSW has three knobs** — `M` (neighbors, drives memory + recall), `efConstruction` (build-time graph quality), `efSearch` (query-time recall/latency dial); fix a recall target, raise `efSearch` to hit it, accept the resulting latency.
- **Tensor parallelism (intra-node, communication-heavy) and pipeline parallelism (cross-node, has bubbles) shard models that don't fit one GPU; speculative decoding** uses a draft model verified in one target pass to cut effective TPOT with an unchanged output distribution.
- **RAG** = retrieve relevant context via semantic similarity, then have the LLM synthesize; the LLM doesn't need to "know" the answer.
- **Context windows are limited** (4K → 1M tokens); RAG fits relevant context within the window, but limits still bite on complex queries.
- **Chunking quality drives retrieval quality**; **hybrid search** (vector + keyword/BM25 + reranking) beats vector search alone.
- **Cost per query is a primary engineering concern** — cents to dollars vs. fractions of a cent for traditional APIs. At a million queries even $0.10 each is $100K; model selection and prompt optimization become primary work.
- **Hallucination is a real risk**; RAG with cited sources and explicit "I don't know" behavior mitigates but does not eliminate it.
- Senior practitioners' default habits: **cache aggressively at every layer, use hybrid search, cite sources, stream responses for perceived latency, monitor quality continuously, cost-model queries per usage tier, and plan for cold starts** (keep instances warm / provisioned concurrency).
- Treat LLM serving as serious infrastructure (cost models, quality monitoring, retrieval tuning, prompt versioning), not magic — that's what turns demos into production systems.

---

## Interview angle 🟡

What gets tested:

1. **"How does LLM inference work?"** Token-by-token; transformer; attention.
2. **"What's RAG?"** Retrieve relevant context; generate with it.
3. **"Vector databases?"** Store embeddings; ANN search.
4. **"What's HNSW?"** Graph-based ANN.
5. **"Why streaming?"** Token-by-token output; perceived latency.
6. **"How do you handle hallucination?"** RAG; citations; "I don't know."

Common traps:
- Treating LLM serving like web serving.
- Ignoring context limits.
