# Cluster & Workflow Management

### 🔹 1. What This Topic Actually Is
Two related topics:
1. **Cluster management** — scheduling containers/VMs across a fleet (k8s, Twine, Borg, ECS).
2. **Workflow orchestration** — reliably running multi-step business processes (Conductor, Temporal, Airflow, Step Functions).

### 🔹 2. Why It Exists
- Bare-metal / VM provisioning does not scale — you need a system that packs workloads, handles failures, autoscales.
- Saga/long-running business processes need durable state and retry logic that is impossible in a plain process.

### 🔹 3. Core Concepts (High Signal)
**Cluster mgmt:**
- **Scheduler** decides where workloads run (k8s scheduler, Borg master). Bin-packing vs spread + constraints.
- **Autopilot (Google)**: auto-tunes resource limits based on observed usage — major efficiency win.
- **Capacity management (Meta)**: global view — shift workloads between DCs to match power + demand.
- **Control plane** (API + state) separate from data plane (workers). Control plane HA on etcd/Paxos.

**Workflow:**
- **Durable state machine** — workflow engine persists every step so crashes resume.
- **Temporal / Cadence**: code-first durable workflows (Go/Java SDK — code looks normal but actually resumes across crashes).
- **Conductor (Netflix)**: JSON DSL for workflows; good for cross-team + polyglot.
- **Airflow**: batch ETL DAGs; not great for online flows.
- **Step Functions (AWS)**: JSON state machine; integrates with AWS services.

### 🔹 4. Internal Working
**k8s scheduling loop:** watch pending pods → filter feasible nodes (resources, taints) → score (spread, affinity) → bind pod to node. Kubelet on node runs container.
**Temporal:** worker polls task queue → executes a step → records result to history → engine persists. Crash mid-step → another worker picks up, replays history deterministically to reach current state → continues.

**Failure points:** scheduler starvation, noisy-neighbor bin-pack failures, workflow engine itself SPOF, non-deterministic workflow code (breaks replay), unbounded workflow history.

### 🔹 5. Key Tradeoffs
- Cluster mgmt: k8s is standard; simpler alternatives (Nomad, ECS) for narrower needs.
- Workflow: Temporal for code-first, Airflow for batch, Step Functions for AWS-native.
- Autopilot-style autosizing saves ~30% capacity but requires tight integration.

### 🔹 6. Interview Questions
**Beginner**
1. What does a scheduler do?
2. Why is a workflow engine different from a queue?

**Intermediate**
1. How does Temporal survive crashes mid-workflow?
2. Why is Airflow bad for online workflows?

**Advanced**
1. Design a multi-region scheduler with capacity + locality constraints.
2. Design subscription renewal workflow with retries, compensations, timeouts.

### 🔹 7. Real System Mapping
- **Google Borg / Kubernetes**: modern scheduler.
- **Facebook Twine**: cluster manager paper.
- **Google Autopilot**: resource autosizing (paper).
- **Meta Global Capacity Assignment**: cross-DC workload placement.
- **Netflix Conductor / Cadence/Temporal**: workflow.
- **Luigi (Spotify)**: batch workflows.
- **AWS EC2 Container Service (ECS)**: Amazon's container orchestrator.

### 🔹 8. What Most People Miss
- **Scheduler constraints compound quickly**: affinity, anti-affinity, topology, taints — can easily make pods unschedulable. Observe scheduling failures.
- **Autosizing beats human tuning** at scale — Autopilot cut Google's resource waste substantially.
- **Workflows are not queues**: queue = work unit. Workflow = durable state machine with branches, waits, retries.
- **Non-deterministic code** in Temporal workflows breaks replay (time.Now, random). Use workflow-SDK helpers.
- **Signals + queries** in workflows let you interact with long-running processes.

### 🔹 9. 30-Second Revision
k8s scheduler bin-packs + spreads pods on constraints. Autopilot auto-tunes resources. Temporal = durable workflows with replay-on-crash. Airflow = batch DAGs. Step Functions = AWS-native. Workflow engine != queue; it persists state + branches. Don't write non-deterministic workflow code.

---

## 🔗 Cross-Topic Connections
- **Containers**: cluster mgmt schedules them.
- **Distributed transactions/saga**: workflow engines orchestrate sagas.
- **Consensus**: control planes sit on etcd/Raft.
- **Microservices**: cluster + workflow infra is table stakes.

---

### Confidence Check
- [ ] Can I differentiate cluster scheduler from workflow engine?
- [ ] Can I pick Temporal / Airflow / Step Functions per use case?

### Gaps
- Borg paper deep read.
- k8s scheduling framework extensions.
