# GPU & Accelerator Computing

> *"GPUs were designed for graphics. The discovery that they were also vastly better at parallel numerical computation than CPUs reshaped scientific computing, machine learning, and now AI infrastructure. The architecture — thousands of cores, massive memory bandwidth, SIMT execution — demands a different style of programming. Understanding what GPUs are good at (and what they're not) is foundational to modern AI infrastructure."*

---

## Topic Overview

A modern GPU has thousands of cores, hundreds of GB/sec memory bandwidth, and a programming model utterly different from CPUs. CPUs are optimized for *latency* — finish one task fast. GPUs are optimized for *throughput* — finish many parallel tasks faster than CPUs could.

For workloads that fit (data-parallel, regular access patterns), GPUs are 10-100× faster per dollar than CPUs. For workloads that don't (branching control flow, sequential dependencies, tiny data), GPUs underperform.

The infrastructure category emerged with CUDA (2006); now spans GPU training/inference, custom ASICs (TPUs, IPUs, NPUs), specialized accelerators (FPGAs). For modern ML, AI infrastructure, and HPC, accelerator awareness is non-optional.

This artifact covers the engineering reality: when to use GPUs, what they cost, how to think about programming them, and how AI/ML infrastructure depends on them.

---

## Intuition Before Definitions

Imagine two factories making the same product.

**CPU factory.** A few master craftsmen, each highly skilled and versatile. They handle complex jobs end-to-end, each working on a different product simultaneously. Excellent for varied work; expensive per unit.

**GPU factory.** A thousand specialized workers in parallel assembly lines. Each handles one specific repetitive task very fast. Excellent for mass-producing identical items; useless for unique custom orders.

If you need to add 1 + 1, the CPU factory is better — one craftsman, done. If you need to add a million pairs of numbers, the GPU factory is better — a thousand workers each handling 1000 additions in parallel.

That's the GPU vs CPU trade-off. Different shapes of work; different optimal architectures.

---

## Historical Evolution

**Era 1 — Graphics-only GPUs (1990s-2000s).**
GPUs as graphics accelerators. Fixed-function pipelines.

**Era 2 — General-purpose GPU (GPGPU).**
~2003. Researchers discover GPUs can do non-graphics computation.

**Era 3 — CUDA (2006).**
NVIDIA releases CUDA — a C-like programming model for GPUs. Inflection point.

**Era 4 — ML revolution.**
2012+. AlexNet wins ImageNet on GPUs. Deep learning rapidly adopts GPUs. NVIDIA's market cap grows.

**Era 5 — Custom accelerators.**
2016+. Google's TPU. AWS Trainium/Inferentia. Apple Neural Engine. Many specialized chips.

**Era 6 — AI infrastructure dominant.**
2024+. GPUs are the bottleneck of AI; H100s have multi-month lead times. Custom accelerators emerge.

The pattern: GPUs went from niche graphics to the core of compute. Custom accelerators emerging for specialized workloads.

---

## Core Mental Models

**1. CPU optimizes latency; GPU optimizes throughput.**
Different goals; different architectures.

**2. Data parallelism is the GPU's sweet spot.**
Many independent operations on different data. Branching/sequential code is hostile.

**3. Memory bandwidth is the limit.**
GPUs have huge bandwidth (1+ TB/sec) but compute is even faster. Often you're memory-bandwidth-bound, not compute-bound.

**4. The host-device boundary is expensive.**
Data must move from CPU memory to GPU memory. PCIe is slow (50-100 GB/sec) compared to GPU memory (1+ TB/sec).

**5. SIMT execution.**
Single Instruction Multiple Threads. Threads in a warp execute together; divergent branches serialize.

---

## Deep Technical Explanation

### CPU vs GPU architecture

**CPU:**
- Few cores (8-128 typical).
- Each core: complex; out-of-order execution; large caches; branch prediction.
- Optimized for single-threaded performance.
- Memory bandwidth: ~50-200 GB/sec.

**GPU:**
- Thousands of cores (10,000+ on flagship cards).
- Each core: simple; in-order; small caches; designed for throughput.
- Optimized for data-parallel workloads.
- Memory bandwidth: 500-3000 GB/sec.

NVIDIA H100: 80GB HBM3 memory; 3 TB/sec bandwidth; ~67 teraflops FP32 / 1000 teraflops FP16.

### CUDA programming model

CUDA introduced the abstraction:

- **Thread**: smallest unit of execution.
- **Warp**: 32 threads executing in lockstep (SIMT).
- **Block**: group of threads sharing fast memory.
- **Grid**: collection of blocks.

A CUDA kernel:

```cuda
__global__ void add_vectors(float* a, float* b, float* c, int n) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < n) {
        c[i] = a[i] + b[i];
    }
}

// Launch: 1M elements, 256 threads per block
add_vectors<<<numBlocks, 256>>>(a, b, c, n);
```

Each thread handles one element. With 1M threads, all compute runs in parallel (subject to GPU's actual capacity).

### SIMT and warp divergence

A warp executes one instruction across 32 threads. If threads in a warp have different control flow:

```cuda
if (threadIdx.x < 16) {
    do_a();  // 16 threads execute
} else {
    do_b();  // other 16 execute
}
```

The warp serializes: all 32 threads execute `do_a()` (with the second half masked off), then all execute `do_b()` (with the first half masked off). 2× slowdown.

Lesson: avoid branching within warps. Group similar work together.

### Memory hierarchy

GPU memory is layered:
- **Registers**: per-thread; fastest.
- **Shared memory**: per-block; fast (~1 TB/sec); programmer-managed.
- **L1/L2 cache**: per-SM and global.
- **Global memory**: per-device; slow but large (1-2 TB/sec).

Optimization: maximize use of fast memory. Cache reuse via shared memory. Coalesced access patterns (consecutive threads access consecutive memory).

### Host-device transfer

CPU and GPU have separate memory. Data must move:

```cuda
cudaMemcpy(d_a, h_a, size, cudaMemcpyHostToDevice);
// kernel
cudaMemcpy(h_c, d_c, size, cudaMemcpyDeviceToHost);
```

PCIe 4.0 x16 ≈ 32 GB/sec. PCIe 5.0 ≈ 64 GB/sec. Compare to GPU's 3 TB/sec internal bandwidth.

The bottleneck: data movement. For workloads where data is reused many times, GPU wins. For one-shot computations on small data, the transfer cost dominates.

### Use cases

**Excellent fit:**
- Matrix operations (the heart of ML training/inference).
- Image/video processing.
- Scientific simulation (CFD, molecular dynamics).
- Cryptocurrency mining (regular SHA-256 work).
- Cryptography (parallel block cipher).

**Mediocre fit:**
- Tasks with branching.
- Tasks with serial dependencies.
- Small data (transfer dominates).

**Poor fit:**
- Web servers.
- Database transactions.
- General-purpose application code.

### ML training and inference

Modern ML frameworks (PyTorch, TensorFlow, JAX) abstract GPU programming:

```python
import torch
x = torch.randn(1000, 1000).cuda()  # move to GPU
y = torch.randn(1000, 1000).cuda()
z = x @ y  # matrix multiply on GPU
```

The framework handles kernel launches, memory management, device transfer. Most ML engineers don't write CUDA directly.

Training: gradient computation, backprop, optimizer steps — all GPU-accelerated.

Inference: forward pass, attention computation, KV cache management — also GPU-accelerated.

(See [LLM Serving & Vector Databases](../architecture-patterns/llm-serving-and-vector-databases.md) for inference specifics.)

### Multi-GPU

For models too large for one GPU:

**Data parallelism**: same model replicated; different batches per GPU.
**Model parallelism**: different parts of model on different GPUs.
**Pipeline parallelism**: layers split across GPUs; pipelined.
**Tensor parallelism**: matrix operations split across GPUs.

NVLink (NVIDIA's GPU-to-GPU interconnect): 900 GB/sec on H100, much faster than PCIe.

Massive training (GPT-class) uses combinations: thousands of GPUs across many nodes; Infiniband for cross-node communication.

### Custom accelerators

**TPU (Google)**: matrix-multiply-optimized; used for Google's models. Available on GCP.

**Trainium / Inferentia (AWS)**: AWS's training/inference chips.

**Apple Neural Engine**: in iPhones and Macs; on-device ML.

**Cerebras**: wafer-scale (an entire wafer is one chip); for largest models.

**Groq**: inference-optimized; deterministic latency.

Each has its own programming model; vendor lock-in is real. Frameworks (PyTorch with various backends) abstract some of it.

### CUDA, ROCm, oneAPI

Vendor-specific APIs:
- **CUDA** (NVIDIA): the dominant ecosystem.
- **ROCm** (AMD): CUDA-equivalent for AMD GPUs.
- **oneAPI** (Intel): Intel's vision for unified accelerator programming.

CUDA's network effects (libraries, tooling, education) make NVIDIA dominant in production AI.

### Cost model

GPUs are expensive. H100 costs $30K+ retail; A100 around $10-15K. Cloud rentals: $4-10/hour for A100; $30/hour for H100.

For ML training, this is the dominant cost. For inference, depends on utilization.

Operational considerations:
- Reserved capacity vs on-demand vs spot.
- Multi-tenant inference (share GPU across users).
- Quantization (FP32 → FP16 → INT8) reduces memory and increases throughput.

### Frameworks and abstractions

**Low-level**:
- CUDA (C++)
- Triton (Python; OpenAI's; used by PyTorch internals)
- CUDA via cupy (Python)

**High-level**:
- PyTorch
- TensorFlow / JAX
- ONNX Runtime (cross-framework)

Most engineers work at the high level. Low-level matters when squeezing performance.

### Inference optimizations

For LLM serving:
- **Quantization**: FP16, INT8, INT4. Smaller weights; faster.
- **KV cache**: avoid recomputing attention for previous tokens.
- **PagedAttention** (vLLM): efficient KV cache memory.
- **Continuous batching**: process multiple requests in one GPU pass.
- **Speculative decoding**: smaller model proposes; larger validates.
- **Flash Attention**: cache-friendly attention computation.

These optimizations stack; modern inference is 5-10× faster than naive PyTorch.

### Profiling

NVIDIA tools:
- **nsight systems**: timeline profiler.
- **nsight compute**: kernel-level profiler.
- **nvprof** (deprecated; replaced by nsight).

Common findings:
- Memory-bandwidth-bound (most ML inference).
- Kernel launch overhead (many small kernels).
- Host-device transfer dominating.

---

## Real Engineering Analogies

**The factory assembly line.**
A car factory's assembly line has many workers each doing one repetitive task, in parallel. A custom-build shop has a few skilled mechanics each doing varied work end-to-end. Different shapes; different optimal architectures.

**The parallel printing press.**
A high-volume newspaper press prints thousands of identical pages per minute. A specialty book bindery handles unique custom jobs. Each is the right tool for its workload.

---

## Production Engineering Perspective

What goes wrong:

- **The host-device transfer dominates.** Data moves to GPU; tiny kernel runs; data moves back. 90% of time in transfer. Mitigation: keep data on GPU; batch operations.
- **The branchy kernel.** CUDA code with if/else; warps diverge; throughput drops. Mitigation: restructure to data parallelism without branching.
- **The memory wall.** Model too large for GPU. Mitigation: model parallelism; quantization; offload to CPU memory.
- **The cold-start cost.** GPU instance takes minutes to load model into memory. Latency for first request. Mitigation: keep instances warm; provisioned concurrency.
- **The cost shock.** Bills 10× expected because of underutilized GPUs. Mitigation: monitor utilization; right-size instance types; spot pricing.
- **The CUDA version mismatch.** Driver version incompatible with library version. Production crashes. Mitigation: containerize the entire stack.

The senior AI infrastructure engineer's habits:
- **Keep data on GPU** as much as possible.
- **Profile** with nsight before optimizing.
- **Use established frameworks** for production.
- **Monitor GPU utilization** as primary metric.
- **Plan for cost** — GPUs are expensive.

---

## Failure Scenarios

**Scenario 1 — The transfer-dominated workload.**
Service receives small requests; loads each onto GPU; runs kernel; reads back. GPU utilization 5%; transfer 80% of time. Recovery: batch requests; keep state on GPU.

**Scenario 2 — The branchy CUDA disaster.**
Custom kernel has many if/else paths. Warps diverge constantly. 10× slower than equivalent CPU code. Fix: redesign for data parallelism; or accept it's not GPU-friendly.

**Scenario 3 — The OOM during fine-tuning.**
Fine-tuning a model that should fit; activations grow during training; OOM. Mitigation: gradient checkpointing; smaller batch size; mixed precision.

**Scenario 4 — The CUDA version compatibility break.**
Container with CUDA 11.8; driver supports up to 11.7. Runtime error. Recovery: pin compatible versions; test in staging matching production.

**Scenario 5 — The bill shock.**
Team rents 8× A100s for training; forgets to release after experiment. Weekend bill: $20K. Lesson: budget alerts; auto-shutdown of idle instances.

---

## Performance Perspective

- **Matrix multiply**: GPUs 10-100× faster than CPU.
- **Memory bandwidth**: 1-3 TB/sec (vs CPU's ~100 GB/sec).
- **Latency for small ops**: CPU often faster (kernel launch overhead).
- **Throughput**: GPU dominant for parallel work.

---

## Scaling Perspective

- **Single GPU**: 80GB memory; tens of TFLOPs.
- **Multi-GPU on one node**: NVLink; up to 8 GPUs per node typical.
- **Multi-node**: Infiniband; thousands of GPUs.
- **At hyperscale**: dedicated AI infrastructure (Meta, Google, OpenAI, Anthropic).

---

## Cross-Domain Connections

- **LLM Serving**: GPUs are the substrate. (See [llm-serving-and-vector-databases.md](../architecture-patterns/llm-serving-and-vector-databases.md).)
- **Parallelism**: GPUs embody data parallelism. (See [parallelism-vs-concurrency.md](../concurrency/parallelism-vs-concurrency.md).)
- **Capacity planning**: GPU economics. (See [auto-scaling-and-capacity-planning.md](./auto-scaling-and-capacity-planning.md).)
- **Edge computing**: edge GPUs for inference. (See [edge-computing-and-cdns.md](./edge-computing-and-cdns.md).)
- **Profiling**: GPU profiling tools. (See [profiling-and-flame-graphs.md](../observability/profiling-and-flame-graphs.md).)

The unifying observation: **GPUs are the right tool for data-parallel, throughput-bound workloads. The architecture demands different programming styles; the cost demands utilization discipline; the rewards (orders-of-magnitude speedup for fitting workloads) are why AI runs on them.**

---

## Real Production Scenarios

- **NVIDIA's CUDA dominance**: ecosystem moat.
- **Google's TPU papers**: custom accelerator design.
- **OpenAI's training infrastructure**: documented scale.
- **Anthropic's Claude training**: thousands of accelerators.
- **Meta's Research SuperCluster**: 16K GPUs.

---

## What Junior Engineers Usually Miss

- That **transfer cost** often dominates.
- That **branching kills** GPU performance.
- That **memory bandwidth** is the typical bottleneck.
- That **CUDA versions** matter.
- That **GPUs are expensive** — utilization matters.

---

## What Senior Engineers Instinctively Notice

- They **profile before optimizing**.
- They **keep data on GPU**.
- They **use established frameworks**.
- They **monitor utilization**.
- They **plan cost** explicitly.

---

## Interview Perspective

What gets tested:

1. **"CPU vs GPU architecture?"** Latency vs throughput.
2. **"What's SIMT?"** Single Instruction Multiple Threads.
3. **"What's the bottleneck?"** Often memory bandwidth or transfer.
4. **"What workloads fit GPUs?"** Data-parallel, regular, large.
5. **"Multi-GPU strategies?"** Data, model, pipeline, tensor parallelism.

Common traps:
- Believing GPUs are universally faster.
- Ignoring transfer cost.

---

## 20% Knowledge Giving 80% Understanding

1. **CPU = latency**, **GPU = throughput**.
2. **Data parallelism** is the GPU sweet spot.
3. **Memory bandwidth** often the bottleneck.
4. **Host-device transfer** is expensive.
5. **SIMT** — branches serialize warps.
6. **Frameworks abstract** GPU programming.
7. **Quantization** (FP16, INT8) for inference.
8. **Multi-GPU** for large models.
9. **Custom accelerators** (TPU, etc.) are emerging.
10. **GPUs are expensive** — utilize them.

---

## Final Mental Model

> **GPUs are the right tool for data-parallel, throughput-bound work. They're the wrong tool for everything else. AI exists at the scale it does because GPUs made the necessary computation economically feasible. The infrastructure category is the engineering response to that.**

The senior AI infrastructure engineer treats GPUs as a constraint and a capability. Plan for data movement; optimize for throughput; bound costs; use frameworks. The architecture rewards alignment with its strengths; misalignment produces expensive disappointment.

That's GPU and accelerator computing. That's the substrate of modern AI. That's the hardware revolution that made deep learning, then large language models, then the AI era — possible.
