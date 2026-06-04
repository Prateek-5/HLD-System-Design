# LLM Serving & Vector Databases

> *"Serving large language models in production has emerged as one of the hardest infrastructure problems of the 2020s. Models that need 80GB of GPU memory; latency expectations measured in tokens per second; cost per query that makes traditional API economics look cheap. Vector databases are the new index — semantic similarity instead of keyword match. Together they're the substrate of every retrieval-augmented generation system, every modern semantic search, every AI-native product."*

---

## Topic Overview

The deployment of large language models has created an entirely new infrastructure category. Traditional web services serve sub-millisecond responses from megabytes of state. LLM serving systems handle requests that take seconds, run on multi-GPU hardware, generate output token-by-token, and cost dollars per query. The constraints are different; the architecture is different; the operations are different.

**Vector databases** — Pinecone, Weaviate, Qdrant, pgvector, Chroma, Milvus — emerged in parallel. They store and query vector embeddings using approximate nearest neighbor (ANN) algorithms. The killer use case: retrieval-augmented generation (RAG), where the LLM is given relevant context retrieved by semantic similarity.

Together they form the modern "AI stack": embeddings in vector databases; LLMs serving inference; orchestration layers gluing them together. Engineering teams that built scalable web services in the 2010s are learning new disciplines: GPU scheduling, attention computation, KV cache management, semantic chunking, prompt engineering at scale.

This is the topic for the AI era. Not the model training (that's research-grade); the *serving* and *retrieval* infrastructure that makes AI products work in production.

---

## Intuition Before Definitions

Imagine running a research library where every book is indexed by *meaning* rather than keyword.

A query "tell me about ancient maritime trade" doesn't find books with those exact words; it finds books *about that topic*, even if they say "Mediterranean shipping in the 4th century BC." The matching is semantic.

To do this: every book is converted to a numerical fingerprint (embedding) capturing its meaning. Queries also become fingerprints. Similar fingerprints = similar meaning. Find similar.

Now: "for a question about ancient maritime trade, retrieve relevant passages, then ask a knowledgeable librarian (LLM) to write an answer using those passages." The librarian doesn't have to know everything — they have the right passages in front of them.

That's RAG. Vector database for semantic retrieval; LLM for generation. The combination is the dominant pattern for AI-augmented information systems.

---

## Historical Evolution

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

## Deep Technical Explanation

### LLM inference fundamentals

A transformer LLM takes input tokens and predicts the next token. Generation: predict next; append; predict next; until done.

Computation per token:
- Many matrix multiplications.
- Attention over previous tokens.
- Vocabulary projection at the end.

Memory:
- Model weights (GBs to TBs).
- KV cache (previous tokens' attention state).

For a 70B parameter model in fp16: 140GB just for weights. Inference requires GPU memory for weights + KV cache + activations.

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

Reduce weight (and sometimes activation) precision: fp32 → fp16/bf16 → fp8 → int8 → int4.

Trade-offs:
- Smaller memory; can fit larger models.
- Faster inference.
- Slightly worse quality (varies by model, method, and task).

High-quality serving commonly runs at fp16/bf16. For compression, weight-only 4-bit methods such as GPTQ and AWQ are widely used, and FP8 has become common on newer hardware (e.g. NVIDIA Hopper/Ada and later). The right choice depends on the model, the accelerator, and the accuracy budget — there is no single "default" precision across production.

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
- Keyword: exact-match (BM25).
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

---

## Real Engineering Analogies

**The research librarian with relevant excerpts.**
You ask a question. The librarian doesn't just answer from memory. They first consult the archive, find relevant excerpts, lay them in front of you, and *then* synthesize an answer. The archive is the vector database; the librarian's synthesis is the LLM.

**The on-call doctor with patient charts.**
The doctor has expertise but doesn't know specific patients. They consult charts; they synthesize a recommendation. The chart system is the retrieval; the doctor's reasoning is the model.

---

## Failure Scenarios

**Scenario 1 — The cost shock.**
Product launches with LLM features. Token usage 10× expected. Bill in first month: $200K. Recovery: prompt optimization; cheaper model for simple queries; cap usage per tier.

**Scenario 2 — The hallucination.**
Customer support chatbot confidently makes up policy. Customer makes business decisions on it. Legal exposure. Recovery: strict grounding via RAG; "I don't know" training; legal review of outputs.

**Scenario 3 — The retrieval gap.**
RAG misses relevant docs because of bad chunking. Users frustrated; they keep asking; LLM hallucinates. Mitigation: better chunking; semantic search tuning.

**Scenario 4 — The slow cold start.**
GPU instance restarts; takes 5 minutes to load model. Auto-scaler triggered by load; new instances slow. Mitigation: provisioned concurrency.

**Scenario 5 — The privacy leak.**
Embeddings of customer data sent to third-party API. GDPR concerns. Mitigation: self-host embedding model.

---

## Performance Perspective

- **Inference latency**: hundreds of ms to seconds.
- **Throughput**: tokens per second; varies by model.
- **Vector search**: milliseconds for tens of millions of vectors.
- **Cost**: $0.001-$0.10 per query depending on model and tokens.

---

## Scaling Perspective

- **Vertical**: bigger GPUs; H100s, B100s.
- **Horizontal**: many GPUs serving in parallel.
- **Tiered**: cheap model first; escalate to expensive.
- **Caching**: aggressive at every layer.
- **Edge**: inference at edge becoming feasible for smaller models.

---

## Cross-Domain Connections

- **Caching**: LLM responses cached aggressively. (See [caching-hierarchy.md](../caching/caching-hierarchy.md).)
- **API design**: LLM APIs have streaming, special semantics. (See [api-design-rest-vs-grpc.md](./api-design-rest-vs-grpc.md).)
- **GPU computing**: inference is GPU-bound.
- **Edge computing**: inference at edge for low-latency. (See [edge-computing-and-cdns.md](../scalability/edge-computing-and-cdns.md).)
- **Backpressure**: rate limits per user; tiered. (See [backpressure-and-queues.md](../concurrency/backpressure-and-queues.md).)
- **Observability**: quality and cost monitoring. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)

The unifying observation: **LLM serving and vector databases are the new infrastructure layer for AI-native applications. The operational patterns differ from traditional web serving; the engineering disciplines (caching, batching, quality monitoring, cost optimization) recur with new specifics.**

---

## Real Production Scenarios

- **OpenAI's serving infrastructure**: extensively documented.
- **Anthropic's Claude serving**: similar scale.
- **Cohere's serving**: enterprise focus.
- **Open-source self-hosted**: vLLM, llama.cpp deployments.
- **Pinecone customers**: many public case studies.
- **Hybrid RAG patterns**: standard at most AI-native companies.

---

## Key Takeaways

- **LLM inference is GPU-bound, latency-variable, and expensive** — different constraints and optimizations than traditional web serving.
- **Token-by-token generation is the dominant pattern.** Latency splits into time-to-first-token (TTFT, prefill before the first token) and inter-token latency (TPOT, per-token streaming rate); total response ≈ TTFT + (output tokens × TPOT). Which matters depends on the use case.
- **Vector embeddings represent meaning numerically**; similarity in vector space ≈ similarity in meaning, and ANN algorithms (HNSW graph-based, IVF cluster-based) find similar vectors fast.
- **RAG** = retrieve relevant context via semantic similarity, then have the LLM synthesize; the LLM doesn't need to "know" the answer.
- **Context windows are limited** (4K → 1M tokens); RAG fits relevant context within the window, but limits still bite on complex queries.
- **Chunking quality drives retrieval quality**; **hybrid search** (vector + keyword/BM25 + reranking) beats vector search alone.
- **Cost per query is a primary engineering concern** — cents to dollars vs. fractions of a cent for traditional APIs. At a million queries even $0.10 each is $100K; model selection and prompt optimization become primary work.
- **Hallucination is a real risk**; RAG with cited sources and explicit "I don't know" behavior mitigates but does not eliminate it.
- Senior practitioners' default habits: **cache aggressively at every layer, use hybrid search, cite sources, stream responses for perceived latency, monitor quality continuously, cost-model queries per usage tier, and plan for cold starts** (keep instances warm / provisioned concurrency).
- Treat LLM serving as serious infrastructure (cost models, quality monitoring, retrieval tuning, prompt versioning), not magic — that's what turns demos into production systems.

---

## Interview angle

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
