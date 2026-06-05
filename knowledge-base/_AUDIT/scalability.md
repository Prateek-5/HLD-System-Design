# 🔍 Audit — `scalability/`

**Reviewed:** 7 files (~2,967 lines) · **Lens:** brutal-honest, held to the corpus's own "senior/staff 3000+ word deep dive" claim · **Avg score: ~4.0/5**

---

## Verdict in one line
The **most technically reliable directory in the corpus so far** — the marquee concepts that are usually botched (consistent hashing, L4/L7, SIMT divergence, silo/pool/bridge/cell, light-speed latency) are all *correct* — but it pays for that accuracy with ~35–45% padding, two genuinely thin files (`kubernetes-internals`, and the listy back-half of `multi-tenancy`), and a conspicuous omission of the one formula the domain demands: **Little's Law**.

## Per-file scores (out of 5)

| File | Score | One-liner |
|---|---|---|
| `load-balancing-strategies.md` | **4.4** | Accurate across L4/L7, EWMA, P2C, consistent-hash, hot-key, gRPC-LB trap; minor padding |
| `sharding-and-partitioning-strategies.md` | **4.3** | Best file: real worked example + 6-phase migration; consistent hashing/vnodes correct; padded tail |
| `edge-computing-and-cdns.md` | **4.1** | Light-speed math right, V8 isolates / anycast / Vary / surrogate keys all correct |
| `gpu-and-accelerator-computing.md` | **4.0** | SIMT/warp divergence, HBM, host-device, PagedAttention correct; "1–2 TB/s" called both huge and slow |
| `auto-scaling-and-capacity-planning.md` | **3.9** | Saturation-vs-utilization and runaway-scaling are gold; **no Little's Law, no cooldown/stabilization window** |
| `multi-tenancy-strategies.md` | **3.9** | silo/pool/bridge/cell + RLS + noisy-neighbor correct; back half degrades into bullet lists |
| `kubernetes-internals.md` | **3.3** | Accurate but **shallow** — fails the 3000-word bar; HPA algorithm absent, scheduler-framework not named |

## Concrete errors found (must-fix)

This directory is unusually clean on *hard* factual errors. The findings are mostly **omissions and loose phrasing**, not hallucinations. Being honest: I found **no fabricated histories, no wrong theorems, no inverted component roles** of the kind flagged in `architecture-patterns/`. The K8s file in particular gets every component role *correct* (etcd = source of truth, API server = only writer to etcd, scheduler = filter/score/bind, kubelet = node agent, kube-proxy = service networking) — the trap this directory could have fallen into, it didn't.

What is actually wrong or misleading:

- 🚩 **`auto-scaling-and-capacity-planning.md` — Little's Law is never mentioned.** A "staff deep dive" on capacity planning that does workload characterization ("1 RPS = 0.05 CPU cores + 200 connection slots…", line 81) without ever stating `L = λW` (concurrency = arrival-rate × latency) has a hole exactly where the interview question lives. The connection-pool-ceiling scenario (line 270) is *literally Little's Law in disguise* and the doc never names it. Add it.
- 🚩 **`auto-scaling-and-capacity-planning.md` — no cooldown / stabilization window.** The doc discusses the scale-down race ("Scale-down too aggressive… Mitigation: longer scale-down windows", line 250) but never names the mechanism: HPA's `--horizontal-pod-autoscaler-downscale-stabilization` / `behavior.scaleDown.stabilizationWindowSeconds`, or ASG cooldown. For a deep dive this should be a named, explained primitive, not a hand-wave.
- 🚩 **`kubernetes-internals.md` — HPA is described in another file but the *algorithm* appears nowhere.** Neither this file nor the auto-scaling file gives `desiredReplicas = ceil(currentReplicas × currentMetricValue / desiredMetricValue)` or the tolerance band (default 10%). That formula is the single most-tested HPA fact.
- 🚩 **`kubernetes-internals.md` — scheduler section is correct but unnamed-and-shallow.** "Filtering / Scoring / Binding" (lines 145–147) is right, but the modern **scheduling framework** (plugins, extension points, `PreFilter`/`Filter`/`Score`/`Reserve`/`Bind`) is never mentioned, and "default scheduler handles thousands of pods/sec" (line 149) is an unsourced round number that's optimistic for scheduling *throughput* (binding latency, not raw filtering, is the limit).
- 🚩 **`kubernetes-internals.md` — controller pseudocode is misleadingly a poll loop.** Lines 126–132 show `loop forever: observed = api_server.list(...)`, which contradicts the file's own (correct) "Components don't poll; they watch" section three paragraphs earlier (line 115). Real controllers use informers/work-queues over watches; the pseudocode teaches the anti-pattern the doc just warned against.
- 🚩 **`kubernetes-internals.md` — etcd "~10K writes/sec at scale" (line 95)** is an unsourced figure presented as fact; real etcd write throughput is workload- and fsync-bound and commonly far lower under K8s object churn. Hedge it or cite it.
- 🚩 **`gpu-and-accelerator-computing.md` — self-muddled bandwidth framing.** Line 66 calls GPU bandwidth "huge (1+ TB/sec)"; line 141 calls **global memory** "slow but large (1-2 TB/sec)" — the same number is both "huge" and "slow" with no framing that it's slow *relative to on-chip SRAM/shared memory*, fast *relative to PCIe*. A reader can't tell which.
- 🚩 **`gpu-and-accelerator-computing.md` — "~67 teraflops FP32 / 1000 teraflops FP16" (line 92)** is loose: the ~1000 TFLOPS figure is **Tensor Core FP16 (dense)**, not vanilla FP16 on CUDA cores, and doubles again with sparsity. Stated without "Tensor Core," it reads as a 15× CUDA-core speedup that doesn't exist. Label it.
- 🚩 **`load-balancing-strategies.md` — Maglev called "Google's variant of consistent hashing" (line 121).** Defensible-but-loose: Maglev hashing is a distinct lookup-table scheme designed to trade a little disruption-on-failure for *much* better load evenness than ring-based consistent hashing — not simply "consistent hashing with better distribution." Worth a one-line correction.
- 🚩 **Name-drop citations without links (every file).** "Stripe's 'rate-limited rebalances'", "Discord's Cassandra → ScyllaDB", "Netflix's predictive autoscaling", "Notion's 2023 sharding (Citus)", "the 2021 Fastly outage" — these are *real* (good, unlike the architecture-patterns hallucinations) but presented as bare assertions. Several mix verifiable (Notion→Citus, Discord→ScyllaDB are publicly documented) with vaguer ones ("AWS internal multi-tenancy… re:Invent talks"). Link or hedge.

## Genuine strengths (keep)

- **Consistent hashing is correct everywhere it appears** (load-balancing line 119, sharding lines 108–119): ring, closest-node-clockwise, ~1/N movement on add, vnodes for finer rebalance and failure spreading, *and* the crucial caveat that it's still vulnerable to hot keys. This is the single most-botched concept in the hint list and the directory nails it three times.
- **`sharding` is the template the rest should imitate.** The worked multi-tenant SaaS example (lines 345–498) is genuinely staff-level: `pg_stat_statements`-driven key selection, tenant-size distribution analysis, the hybrid silo-for-enterprise/pool-for-rest model, composite PK `(tenant_id, id)` for physical co-location, and a realistic 6-month/6-phase dual-write → shadow-read → tenant-by-tenant cutover plan. The "shard later antipattern" and "design schemas as sharded from day one" are correct hard-won advice.
- **`load-balancing` "slow is worse than down"** (line 72) and the EWMA/outlier-detection framing, the cascading-health-check failure mode, liveness-vs-readiness, gRPC HTTP/2-breaks-L4-LB trap, and connection-draining-on-shutdown are all exactly what a senior reviewer wants to see.
- **`auto-scaling`: saturation ≠ utilization (line 66), "the bottleneck moves" (line 63), and the runaway-scaling positive-feedback loop (lines 158–168)** are the three insights that separate operators from button-pushers. The AZ headroom math (1.5× for N-1, 3× for N-2, lines 190–197) is correct and well-explained.
- **`edge-computing`: the latency math is physically correct** (200 km/ms in fiber, Frankfurt↔Sydney ~160ms RTT), V8-isolates-vs-container-vs-WASM runtime taxonomy is accurate, `Vary`/surrogate-key/cache-key-explosion and "purges are eventually consistent globally" are real production gotchas.
- **`gpu`: SIMT warp divergence with the 2× serialization example (lines 121–134), the host-device PCIe-vs-HBM bottleneck (lines 146–158), and the inference-optimization stack (PagedAttention/continuous batching/speculative decoding/Flash Attention, lines 260–268)** are correct and current.
- **`multi-tenancy`: the silo/pool/bridge/cell spectrum is correct,** RLS as DB-enforced leak prevention, "tenant context propagates everywhere (including cache keys)", and the cross-tenant cache-key-leak failure are the right things to teach.

## 🛠️ Improvement plan (tailored to this directory)

**Theme: this dir is accurate — fix the *depth asymmetry* and the missing formulas, then de-pad.**

1. **Add the formulas the domain is defined by.** `auto-scaling` must state **Little's Law** (`L = λW`) and use it to *derive* the connection-pool ceiling it already describes narratively, plus name **cooldown / stabilization windows** as first-class primitives. `kubernetes-internals` must give the **HPA scaling formula** and tolerance band. These are the highest-frequency interview facts and they're simply absent.
2. **Bring `kubernetes-internals` up to the 3000-word bar — it's the one file that fails the corpus's own claim.** It reads like an accurate glossary, not a deep dive: terse one-line summary sections, two-line failure scenarios. Go deep on (a) the **scheduling framework** plugins/extension points, (b) **informer/work-queue/level-triggered reconciliation** (and fix the poll-loop pseudocode that contradicts the watch section), (c) **etcd**: Raft, revisions/compaction/defrag, the resource-version watch mechanic, and why the 8GB DB-size limit matters, (d) **CNI dataplane** differences (iptables vs IPVS vs eBPF/Cilium). Use `sharding`'s worked-example structure as the model.
3. **Fix the loose hardware/algorithm phrasing** (3 items): label GPU "1–2 TB/s" relative to *what* (on-chip vs PCIe); tag the H100 FP16 number as **Tensor Core dense**; correct Maglev from "variant of consistent hashing" to "a distinct table-based scheme optimizing load evenness."
4. **De-pad ~35–45%.** Every file repeats itself across five tail sections — *What Junior Engineers Miss / What Senior Engineers Notice / 20% Knowledge / Interview Perspective / Final Mental Model* — that restate the same 8–10 bullets three times. In `gpu` and `multi-tenancy` the "What Junior/Senior" lists are near-verbatim inversions of each other. Collapse to **one** "Key takeaways" block per file. The `multi-tenancy` back half (lines 280–404) is the worst offender: failure scenarios, performance, scaling, junior/senior, 20%, and final-model all re-list "noisy neighbor / per-tenant rate limit / tenant_id everywhere / offboarding is hard."
5. **Convert name-drops to links or hedges.** Unlike `architecture-patterns/`, these references are real — so they're cheap to make rigorous. Link Notion→Citus, Discord→ScyllaDB, Netflix predictive autoscaling, the 2021 Fastly outage; hedge the vaguer ones ("AWS internal multi-tenancy via re:Invent talks").
6. **Promote `sharding-and-partitioning-strategies.md` and `load-balancing-strategies.md`** as the directory's reference quality bar; rewrite `kubernetes-internals` against them.
