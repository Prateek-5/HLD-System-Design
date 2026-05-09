# Distributed Transactions — 2PC, 3PC, and the Coordinator Problem

> *"Two-phase commit is a beautiful idea that has been quietly betrayed by every production system that ever depended on it. The protocol works on paper. The real-world version blocks indefinitely on coordinator failure, doesn't tolerate certain network partitions, and has been the cause of more 'database is hung' tickets than perhaps any other distributed-systems mechanism. Knowing why is essential to understanding why modern systems mostly avoid it."*

---

## Topic Overview

Distributed transactions are the holy grail of "ACID across multiple resources." Update two databases atomically. Send a message and update a database in one transaction. Update databases in different regions as if they were one. The promise: cross-resource correctness with the same guarantees you have on a single database.

The reality is harder. Two-Phase Commit (2PC), introduced in 1978, was the first formal protocol. It's correct in theory but has fundamental problems: blocking on coordinator failure, vulnerability to network partitions, performance overhead. Three-Phase Commit (3PC, 1983) tried to fix the blocking; introduced its own issues.

Most modern distributed systems quietly avoid 2PC. Sagas with compensation, eventual consistency with reconciliation, consensus-backed transactions (Spanner, CockroachDB) — these are the workhorses today. But 2PC remains essential vocabulary; you can't understand modern alternatives without understanding what they're alternatives to.

This is the topic where database transactions meet distributed systems. The lessons of 2PC's failures shaped CAP theorem, sagas, microservice patterns. Understanding this history is understanding how the field arrived at its current pragmatic position: "true distributed ACID is expensive; we'll work without it most of the time."

---

## Intuition Before Definitions

Imagine three friends agreeing to chip in for a vacation rental.

**The naive way.** Friend 1 says "I'll pay my third"; Friend 2 says yes; Friend 3 says yes. Each Venmo's their share. But — what if Friend 2 sends; Friend 3 doesn't? Friend 1 has paid; Friend 3 hasn't; the deal can't proceed; refunds needed.

**Two-Phase Commit (Phase 1):** Each friend explicitly *promises* to pay if everyone else does. Coordinator (Friend 1) collects all three promises.

**Two-Phase Commit (Phase 2):** Coordinator says "all promised; commit!" Each friend pays. Or, if any didn't promise, "abort" — nobody pays.

The catch: what if Friend 1 (coordinator) collects promises and then drops dead? Friends 2 and 3 promised but don't know what to do. They're stuck holding their money — *blocked*. They can't proceed; they can't unilaterally back out (Friend 1 might still send the "commit" message later).

This is 2PC's central flaw. When the coordinator fails between phases, participants are blocked. In production: locks held; resources tied up; eventually manual intervention.

The protocols that came later (3PC, sagas, Paxos-backed transactions) all try to fix some version of this problem. None solves it elegantly without trade-offs.

---

## Historical Evolution

**Era 1 — 2PC (1978).**
Jim Gray's classical formulation. The protocol that databases use for distributed XA transactions. Worked beautifully on paper.

**Era 2 — XA and enterprise adoption.**
1990s. XA standard for cross-resource transactions. Java JTA. Microsoft DTC. Used heavily in enterprise; mixed reputation.

**Era 3 — 3PC and theoretical refinements.**
1983. Skeen, Stonebraker propose 3PC to remove blocking. Adds a "pre-commit" phase. Still has assumptions (synchronous network) that don't hold in real networks.

**Era 4 — The migration away.**
2000s-2010s. As web-scale systems grew, 2PC's blocking and performance problems became unacceptable. Saga patterns, eventual consistency, application-level coordination took over.

**Era 5 — Consensus-backed distributed transactions.**
~2012. Spanner uses 2PC across shards, but with Paxos (consensus) ensuring coordinator durability. Combined with TrueTime for external consistency. CockroachDB, FoundationDB follow.

**Era 6 — The pragmatic era.**
Today. Distributed transactions exist on a spectrum: 2PC for tightly-bounded use cases (within a database's own shards); sagas for cross-service workflows; eventual consistency for most other cases. The "single distributed transaction across services" pattern is largely deprecated.

---

## Core Mental Models

**1. 2PC has two phases: prepare and commit.**
Prepare: ask all participants if they can commit. Commit: tell them to do it. Both phases require all participants to respond.

**2. The coordinator is a single point of failure (and blocking).**
If the coordinator dies between phases, participants don't know what to do. They block until the coordinator recovers (or manual intervention).

**3. 3PC tries to fix blocking; introduces other issues.**
Adds a "pre-commit" phase so participants can recover without the coordinator. Requires bounded message delays — an assumption that doesn't hold in real networks.

**4. Real-world 2PC is rare across services.**
Within a database (or a tightly-bounded resource set with consensus-backed coordinator), 2PC works. Across loosely-coupled services, it's a anti-pattern.

**5. The alternatives are sagas and eventual consistency.**
Modern distributed systems coordinate via sequences of local transactions with compensation, or via eventual reconciliation, rather than via distributed locks. (See [saga-pattern-and-distributed-transactions.md](../architecture-patterns/saga-pattern-and-distributed-transactions.md).)

---

## Deep Technical Explanation

### Two-Phase Commit (2PC) in detail

**Phase 1 — Prepare:**
1. Coordinator sends `PREPARE` to all participants.
2. Each participant:
   - Acquires necessary locks.
   - Writes a "prepared" record to its local log (durable).
   - Replies `YES` (can commit) or `NO` (cannot).
3. Coordinator collects responses.

**Phase 2 — Commit (or Abort):**
1. If all said YES: coordinator decides "commit"; writes commit record to its log; sends `COMMIT` to all.
2. If any said NO: coordinator decides "abort"; sends `ABORT` to all.
3. Each participant applies the commit/abort and replies `ACK`.

Properties:
- **Atomicity**: either all commit or all abort.
- **Locks held**: from prepare to commit.
- **Coordinator log**: the source of truth on the decision.

### What goes wrong in 2PC

**Coordinator failure between Phase 1 and Phase 2.**
Participants are in "prepared" state — locks held, can't unilaterally proceed. They wait for the coordinator. If coordinator stays down: indefinite blocking. Manual intervention needed (sometimes: kill the prepared transactions, accepting whatever inconsistency results).

**Coordinator failure during Phase 2.**
Some participants have committed; others haven't received the commit message. State is inconsistent across participants temporarily; coordinator must recover and re-send, or participants must talk to each other to figure out what happened.

**Participant failure during Phase 1 or 2.**
Participants have written "prepared" durably; on recovery, they query the coordinator: "what happened with this transaction?" Coordinator answers from its log.

**Network partition.**
Coordinator on one side; some participants on the other. Decisions can't propagate. Participants block.

**Deadlock potential.**
Multiple 2PC transactions competing for the same locks; participants in different "prepared" states; can deadlock across the global system.

### Three-Phase Commit (3PC)

Adds a "pre-commit" phase between prepare and commit.

**Phase 1 — Prepare:** as before.
**Phase 2 — Pre-commit:** coordinator sends `PRE-COMMIT` after all said YES; participants ack.
**Phase 3 — Commit:** coordinator sends `COMMIT`; participants commit.

If coordinator fails after Phase 2: surviving participants can elect a new coordinator and proceed with commit (because they all received PRE-COMMIT).

If coordinator fails before Phase 2: surviving participants can abort.

Removes blocking *if the network is synchronous* (bounded message delays). Real networks aren't. 3PC under network partitions has correctness issues.

3PC is rarely deployed; the conditions for its correctness are too restrictive in practice.

### XA and JTA

XA (X/Open standard, 1991) is the protocol for distributed transactions across resource managers. JTA (Java Transaction API) implements XA in Java.

Common usage:
- A Java application starts a transaction.
- Updates database A.
- Sends a message to a queue.
- Commits.

XA coordinates: 2PC across the database and the queue. If both prepare successfully, both commit; if either fails, both rollback.

The promise: "ACID across multiple resources."

The reality: heavy, slow, prone to coordinator-failure pathologies. Many enterprise systems used (and use) XA; many production headaches trace to it.

### Why 2PC works in some places

**Within a single database's shards (Spanner, CockroachDB).**
Coordinator is itself replicated via consensus (Paxos/Raft); its log is durable across failures. Coordinator can't "fail" in the unrecoverable way XA's coordinator can.

The coordinator+Paxos pattern: 2PC across shards, with consensus ensuring the coordinator's decisions are durable. Spanner's design.

**Within a tightly-coupled cluster.**
Bounded latency; reliable network; simple recovery. 2PC's blocking is acceptable when everyone is "close" and recovery is fast.

**Why not across services.**
Loose coupling; unbounded latency; independent failure domains; hostile networks. 2PC's blocking becomes catastrophic. Use sagas instead.

### The relationship to consensus

2PC is *not* consensus. Consensus (Paxos, Raft) tolerates coordinator failures by replicating the coordinator's role across multiple nodes. 2PC has a single coordinator; failure is fatal.

Modern distributed databases use consensus *under* 2PC: the coordinator's decisions are themselves a consensus result. Best of both: 2PC's atomicity across resources; consensus's tolerance for failures.

### Sagas as the alternative

(See [saga-pattern-and-distributed-transactions.md](../architecture-patterns/saga-pattern-and-distributed-transactions.md).)

Instead of 2PC: a sequence of local transactions, each with a compensation. If a step fails, run the compensations for the previous successful steps.

Properties:
- No locks held across services.
- No blocking on coordinator failure (orchestrator can be made HA).
- Eventual consistency; intermediate states visible.

The default modern pattern for cross-service workflows.

### Compensation vs rollback

Critical distinction:
- **Rollback** (in 2PC): undo as if it never happened. Locks released; nothing visible.
- **Compensation** (in sagas): a forward operation that semantically undoes a previous one. Both operations are visible; the net effect is "no change" but the audit trail shows both.

Rollback isn't always possible in cross-service settings (you can't unsend an email; you can refund a charge). Sagas explicitly accept this and design compensations.

### The CAP perspective

2PC is a CP system: consistency over availability. During partitions, it blocks. Sagas are AP: availability over strict consistency, with eventual reconciliation.

The choice depends on the workload. Money transfers: maybe CP makes sense (with consensus-backed 2PC). Order processing: AP with sagas usually wins.

---

## Real Engineering Analogies

**The wedding contract negotiation.**
Two families negotiating a marriage contract (multi-resource transaction). Each promises certain things if the other does (Phase 1). The matchmaker (coordinator) confirms all promises (Phase 2). If the matchmaker disappears between phases, neither family knows what to do — promised but not committed. Anxiety; sometimes the wedding is delayed for years.

This is exactly 2PC. The matchmaker as single point of failure; promises held in limbo; blocking. The cultural solution? Get married in front of an irrevocable witness (consensus); the matchmaker's word is durable.

**The dual-control nuclear launch.**
Two officers must turn keys simultaneously to launch. Each verifies the other will. If both turn: launch. If either doesn't: abort. But: what if the verification system fails between "we both said yes" and the launch? The officers must wait, hold their keys, until the system recovers. Blocking, by design.

This is why nuclear-launch protocols have multiple redundant verification systems. The single-coordinator 2PC failure mode is unacceptable for high-stakes coordination.

---

## Production Engineering Perspective

What goes wrong:

- **The XA hang.** Production XA transaction; coordinator dies; participants stuck in "prepared" state. Locks held; throughput collapses. Recovery: manual intervention to commit or rollback prepared transactions. Hours of downtime.
- **The "we'll just use XA" disaster.** Team adopts XA expecting "easy distributed transactions." Slow performance; coordinator failures; eventually re-architects with sagas.
- **The 2PC across microservices.** Architect imposes XA-like pattern on services. Network partitions cause indefinite blocking. Migration to sagas.
- **The Spanner/Cockroach success.** Used 2PC + consensus internally; transparent to applications; works because of careful engineering.

The senior architect's habits:
- **Avoid XA across services.**
- **Use 2PC only within a tightly-bounded resource set** (e.g., within a single database).
- **Reach for sagas** for cross-service workflows.
- **Use consensus-backed coordinators** when 2PC is necessary.
- **Have manual recovery procedures** for stuck prepared transactions.

---

## Failure Scenarios

**Scenario 1 — The XA-induced production halt.**
Application uses XA across DB and queue. DB has brief unavailability. Coordinator times out; tries to recover; participants are in "prepared" state. Throughput collapses. Recovery: manually rollback prepared transactions; production limps forward. Eventually re-architect to use sagas.

**Scenario 2 — The cross-region 2PC.**
Team tries 2PC across two regions. Network blip causes coordinator to think a region is dead; aborts transactions that actually committed. Inconsistency. Lesson: don't 2PC across regions.

**Scenario 3 — The deadlock storm.**
Multiple concurrent XA transactions deadlock across resources. Detection takes time. Throughput drops. Recovery: kill some transactions; restart.

**Scenario 4 — The Spanner success.**
Application writes to multiple shards atomically. Spanner coordinates internally with 2PC + Paxos. Application sees ACID semantics. No coordinator-failure surprises. The pattern works because Spanner engineers solved coordinator durability.

**Scenario 5 — The saga migration.**
Team replaces XA-based payment flow with saga. Compensation logic explicitly designed. No more stuck transactions; latency improves; correctness verified. Migration takes 6 months but pays off.

---

## Performance Perspective

- **2PC overhead**: 2 round trips to participants per transaction, plus log writes. Significant per-transaction cost.
- **Lock duration**: locks held for the entire 2PC duration; longer than single-resource transactions.
- **Throughput limit**: bounded by coordinator and lock contention.
- **Failure recovery**: slow; can require manual intervention.

---

## Scaling Perspective

- **Within a database (with consensus)**: scales reasonably.
- **Across services**: doesn't scale; replace with sagas.
- **Cross-region**: avoid; latency makes 2PC impractical.

---

## Cross-Domain Connections

- **Sagas**: the modern alternative for cross-service. (See [saga-pattern-and-distributed-transactions.md](../architecture-patterns/saga-pattern-and-distributed-transactions.md).)
- **Consensus**: backs modern 2PC implementations (Spanner). (See [leader-election-and-consensus.md](./leader-election-and-consensus.md).)
- **CAP**: 2PC is a CP choice. (See [cap-consistency-and-replication.md](./cap-consistency-and-replication.md).)
- **WAL**: 2PC requires durable logging at participants. (See [wal-and-crash-recovery.md](../database-internals/wal-and-crash-recovery.md).)
- **MVCC**: 2PC participants typically use MVCC for isolation. (See [mvcc-and-isolation-levels.md](../database-internals/mvcc-and-isolation-levels.md).)

The unifying observation: **2PC was the right answer to the wrong question. The question was "how do we get ACID across resources?"; the answer assumed a coordinator that doesn't fail. Modern systems answer different questions ("how do we coordinate eventually?") and use different patterns (sagas, consensus-backed transactions).**

---

## Real Production Scenarios

- **Spanner's design**: 2PC + Paxos. Documented in the Spanner paper.
- **CockroachDB's transactions**: 2PC across ranges, Raft-backed.
- **The XA enterprise stories**: countless production incidents from XA across databases and message queues.
- **Most microservice migrations**: from XA-style coordination to sagas.

---

## What Junior Engineers Usually Miss

- That **2PC blocks on coordinator failure** indefinitely.
- That **XA across services is an anti-pattern**.
- That **2PC works within databases** but rarely across them.
- That **sagas are the modern answer** for cross-service.
- That **3PC's assumptions don't hold** in real networks.
- That **lock duration in 2PC** is significant.

---

## What Senior Engineers Instinctively Notice

- They **avoid 2PC across services**.
- They **use sagas** for cross-service workflows.
- They **reach for consensus-backed transactions** when needed.
- They **have manual recovery procedures**.
- They **understand 2PC's failure modes**.

---

## Interview Perspective

What gets tested:

1. **"Explain 2PC."** Tests fundamental.
2. **"Why is 2PC's coordinator a problem?"** Single point of failure; blocking.
3. **"What's the difference between 2PC and Paxos?"** 2PC requires unanimous participants; Paxos requires majority.
4. **"How does Spanner do distributed transactions?"** 2PC + Paxos coordinator durability + TrueTime.
5. **"When would you use 2PC?"** Within tightly-bounded resources; never across services.
6. **"Sagas vs 2PC?"** Compensation vs rollback; eventual vs strict.

Common traps:
- Recommending XA for cross-service.
- Believing 3PC fixes 2PC.

---

## 20% Knowledge Giving 80% Understanding

1. **2PC = prepare + commit**, atomic across participants.
2. **Coordinator failure blocks** participants.
3. **3PC tries to fix blocking** but assumes synchronous network.
4. **XA = standard for distributed transactions**; problematic at scale.
5. **Spanner-style 2PC** uses consensus-backed coordinator.
6. **Avoid 2PC across services**; use sagas.
7. **Locks held** during 2PC; long durations.
8. **Manual recovery** for stuck prepared transactions.
9. **Modern pattern**: sagas with compensation.
10. **2PC is correct theory; problematic in practice** without consensus.

---

## Final Mental Model

> **2PC is the protocol that taught the field that "atomic across distributed resources" is much harder than it looks. The blocking on coordinator failure, the lock-duration problems, the sensitivity to network partitions — these aren't bugs in implementations; they're inherent to the protocol's structure. Modern systems either use 2PC carefully (with consensus-backed coordinators within a single database) or replace it entirely (sagas across services).**

The senior architect treats 2PC as historical context, not a current tool. They use it when it's been carefully designed (within Spanner-class systems); they avoid it when it would mean coordinating loosely-coupled services. Sagas replace it for most modern needs. Consensus replaces its coordinator role for tighter integrations.

The teams that depend on XA in production accumulate stories. The teams that adopted XA and migrated away accumulate scars. The teams that started with sagas avoided both. The lessons are well-understood; the protocol remains, mostly, in legacy systems and as a tool for understanding what alternatives are alternatives *to*.

That's distributed transactions. That's 2PC. That's the algorithm that defined the problem space — and made the limits of "easy distributed coordination" so clear that an entire generation of distributed systems was built on the alternatives.
