# The Actor Model & Message Passing

> *"Threads share memory and synchronize with locks. Actors share nothing and communicate with messages. The difference is whether your bugs can be diagnosed by reading the code, or only by witnessing them in production."*

---

## Topic Overview

The actor model is a different bet about concurrency. Where threads + locks share state and coordinate access, actors *don't share state* — each actor has private memory, and the only way to interact is to send a message. The receiving actor processes messages one at a time, in order, alone with its state. No locks. No race conditions. No shared mutable state.

This is not a niche academic idea. Erlang has been running telecom switches with nine-nines reliability since the 1980s using actors. Akka brought the model to the JVM. Microsoft Orleans powered Halo's matchmaking infrastructure. Go's goroutines + channels are actors with different vocabulary. Rust's tokio tasks share the spirit. The pattern, by various names, runs significant production systems where threading-with-locks would be unmaintainable.

The tradeoff is that actor code looks different. State machines, message protocols, supervision hierarchies — these are first-class concerns. The lock you didn't write is replaced by the message protocol you must design. Failures must be handled per-actor, with explicit policies. The mental shift is real.

This is the topic where the threads-vs-actors debate becomes concrete. Both work. Both have failure modes. The choice is about what kind of bugs you'd rather have, and what kind of systems you want to operate.

---

## Intuition Before Definitions

Two ways to coordinate a kitchen team for a dinner service.

**Threads + locks.** All chefs share one big counter (shared memory). When someone needs the chopping board, they shout "I'm using the board!" and everyone else waits. When they're done, they yell "done!" and the next person can grab it. The kitchen runs fine until two people both shout simultaneously, or one forgets to release the board, or three people are politely waiting for each other in a circle.

**Actors.** Each chef has their own station (private state). Orders move between stations on a conveyor belt (messages). The grill chef gets "make a steak" tickets; they grill the steak; they put a plated steak on the conveyor toward the plating chef. Nobody touches anyone else's station. If the grill chef is overwhelmed, tickets queue up at their station; the rest of the kitchen continues. If the grill chef burns out (crashes), a manager (supervisor) pulls a new chef from the bench and puts them at the station, possibly replaying recent tickets.

The actor kitchen is *isolated by design*. Each station's failure is contained. Each station's pace is independent. The only interactions are explicit messages. The price: no shared cutting boards. If two stations need to coordinate (the line cook and the saucier on a sauce that depends on the meat juices), they must explicitly send messages back and forth — there's no shortcut through shared state.

That's the actor model. Isolation, message passing, supervision. Different bugs, different operating model, different sweet spots.

---

## Historical Evolution

**Era 1 — Carl Hewitt's actor papers.**
1973. Hewitt proposes actors as a fundamental model of concurrent computation. Mostly theoretical for years; influenced Smalltalk's object model.

**Era 2 — Erlang and the telecom realization.**
Joe Armstrong and Robert Virding at Ericsson. Late 1980s. Telecom switches need extreme reliability under heavy concurrency. Threads + locks are unworkable. Erlang ships with cheap processes (actors), message passing, and "let it crash" supervision. AXD301 telephony switch achieves nine-nines availability.

**Era 3 — Akka and the JVM.**
Jonas Bonér creates Akka (2009). Brings Erlang's model to Scala/Java. Introduces actor systems to enterprise. Used by LinkedIn, Walmart, BBC. The tagline: "build resilient, message-driven applications on the JVM."

**Era 4 — Go's goroutines and channels.**
Go (2009) ships with cheap goroutines and CSP-style channels. Not strictly actors (channels are first-class, not actor inboxes), but the same family — message passing over shared memory. Adopted widely; influences Rust's async ecosystem.

**Era 5 — Microsoft Orleans and virtual actors.**
Orleans (2014, public 2015). Introduces *virtual actors* — actors that exist conceptually whether or not they're running, automatically activated on demand and deactivated when idle. Powers Halo's matchmaking and other services.

**Era 6 — Modern actor frameworks.**
Akka Typed (2019), Pekko (Akka's open-source fork, 2022), Erlang/Elixir's continued growth, Rust's actix and ractor, JS's Comlink — actors as a pattern recur across languages with different ergonomics.

The pattern: every generation realized that *isolation + messages* is a more robust foundation for concurrent systems than *shared state + locks*. The model moves from telecom to mainstream because the bugs that come with it are *fewer and more localized* than the bugs that come with locks.

---

## Core Mental Models

**1. Each actor is a single-threaded thing.**
Within one actor, code runs sequentially, processing one message at a time, with full access to its private state. *No concurrent access to that actor's state can occur.* This eliminates an entire class of bugs.

**2. Communication is message passing.**
Actors don't call each other's methods; they send messages. The receiver decides when to process. This decoupling — temporal, spatial, and semantic — is the source of most of the model's benefits.

**3. State is encapsulated.**
Each actor owns its data. To change another actor's state, you ask via a message. There's no `if` clause where two actors can race to update the same variable, because no two actors *share* a variable.

**4. Failure is local, supervised, and recoverable.**
When an actor crashes (uncaught exception, invariant violation), it dies. A *supervisor* — typically another actor — decides what to do: restart, replace, escalate, give up. This is "let it crash" — the philosophy that you can write simpler code by accepting that failures happen and handling them at a higher level.

**5. Location transparency.**
An actor's message protocol doesn't depend on whether the actor is in the same process or on a different machine. The same code that works locally can scale to distributed systems. The framework handles the network.

---

## Deep Technical Explanation

### The actor primitive

An actor has:
- **A unique address** (process ID in Erlang, ActorRef in Akka).
- **A mailbox** — a queue of incoming messages.
- **State** — private to the actor.
- **Behavior** — a function from (state, message) → (new state, possibly outgoing messages, possibly spawning new actors).

The runtime ensures that one message is processed at a time per actor. The actor's behavior runs to completion (or until an asynchronous wait) before the next message is dequeued.

```
Actor: TemperatureSensor
  State: { lastReading: 0, readings: [] }
  Behavior:
    on message Read(value):
      state.readings.append(value)
      state.lastReading = value
    on message Query(replyTo):
      replyTo ! Average(mean(state.readings))
    on message Reset:
      state.readings = []
```

Notice: no locks anywhere. Notice: no concurrent reads of `state.readings`. Notice: every interaction is a message.

### Mailboxes and message ordering

Default behavior:
- Messages from actor A to actor B arrive in the order A sent them.
- Messages from different senders may interleave at B in any order.
- Messages may be lost if the network drops them or B crashes (depends on guarantees).

The semantics shape design. Actors with multiple senders cannot assume global order. Patterns:
- **Sequence numbers** in messages for explicit ordering.
- **Idempotent messages** so reordering doesn't cause incorrect state.
- **Single-source aggregation** — one actor handles a flow start-to-end.

### Supervision

In Erlang and Akka, every actor has a supervisor. When an actor crashes, the supervisor decides:

- **Restart**: start a fresh instance of the actor. State is lost (or recovered from persistence).
- **Stop**: don't restart; let the failure propagate.
- **Escalate**: the supervisor itself crashes, propagating to its supervisor.
- **Resume** (rare): pretend nothing happened, continue from next message.

Supervision *trees* are hierarchies of actors, with crash policies at each level. A single child crashing → restart. Repeated crashes within a window → escalate to the parent. Repeated crashes there → escalate further. Eventually the application restarts (or some persistent layer takes over).

This is "let it crash": don't try to handle every conceivable error in business logic; let failures propagate to supervisors that have the context to recover. The result is simpler code with explicit failure handling at architectural boundaries.

### Backpressure

Actors with bounded mailboxes apply backpressure naturally — if you send a message to a full mailbox, you block (or fail). Unbounded mailboxes have the obvious memory-grows-to-infinity failure mode.

In practice:
- Akka and similar frameworks support bounded and unbounded mailboxes.
- Unbounded is the default (convenient, dangerous).
- Production usage almost always bounds mailboxes with explicit policies.

The design: actors are queues; queues need bounds. (See [backpressure-and-queues.md](./backpressure-and-queues.md).)

### Location transparency

An ActorRef is just an address. The framework figures out whether the target is local or remote, serializes the message if needed, sends it across the network, and delivers it.

```
val remoteActor = system.actorSelection("akka://cluster@host:port/user/myActor")
remoteActor ! ReadTemperature
```

This abstraction is *powerful* but *leaky*:
- Network latencies are real.
- Network failures introduce message loss.
- Serialization costs CPU.
- Security boundaries between clusters need explicit attention.

The benefit: testing locally against in-process actors; deploying distributed without code changes (mostly).

### Virtual actors (Orleans)

Orleans introduces *grains* (virtual actors). Properties:
- Always exist conceptually, identified by a key.
- Activated on demand (first message creates the in-memory instance).
- Deactivated when idle (instance discarded; state persisted).
- Reactivated on the next message, possibly on a different node.

This eliminates lifecycle management — the developer thinks of actors as *always there*, and the framework handles the actual placement and persistence.

Trade-off: grain activation is slower than direct actor messaging; persistence layer is mandatory.

### CSP and channels (Go)

Go's model is closely related but not identical:
- Goroutines are like actors (lightweight concurrent units).
- Channels are explicit communication primitives.
- A channel can be passed around, multiple goroutines can send/receive.
- Goroutines don't have a privileged inbox — they can have many channels.

The mental model is *channels as first-class*, not *actors as first-class*. Equivalent expressive power; different ergonomics. Go programs are often written as pipelines of goroutines connected by channels, rather than as supervision trees.

### Erlang's killer features

Some properties Erlang has had for decades that other languages are still rediscovering:
- **Lightweight processes**: spawning a process is microseconds. Millions per node feasible.
- **Preemptive scheduling**: the runtime preempts long-running processes at fixed reductions, ensuring fairness.
- **Hot code reloading**: deploy new code to a running system without restarting.
- **Pattern matching in receive blocks**: pull specific message types out of the mailbox.
- **Selective receive**: process messages out of order based on shape.
- **Distributed by default**: connecting nodes is a single function call.

The price: a quirky language, a learning curve, ecosystem smaller than mainstream languages. Elixir (built on Erlang's BEAM VM) addresses the syntax issue; Erlang's underlying primitives remain unmatched.

---

## Real Engineering Analogies

**The post office.**
Each post office has a post master (actor). They process letters one at a time. To send a message to another post office, you write a letter and mail it. The letter goes through the mail system (network), arrives at the destination's mailbox (queue), and is processed in arrival order.

If the post master quits, headquarters (supervisor) sends a replacement. The post office reopens, often after losing some in-flight letters. The system as a whole continues.

This is exactly the actor model, made of paper.

**The factory assembly line.**
Each station does one task. Items flow on a belt between stations. Each station is single-threaded (one worker). Stations don't share tools or workspace. If a station breaks, a supervisor pulls a substitute worker; the line continues, possibly replaying buffered items.

The whole system is built around isolation and explicit handoffs. That's not a metaphor — that's literally the actor model in physical form. Industrial engineering arrived at this design for the same reasons computer scientists later did: isolation makes the system robust under failure.

---

## Production Engineering Perspective

What goes wrong in actor systems:

- **The unbounded mailbox.** A producer faster than a consumer fills the mailbox. Memory grows. OOM. Always bound mailboxes in production.
- **The "hot" actor.** One actor receives all the traffic (e.g., a singleton "manager"). Throughput is capped at one CPU's worth. Sharded actors avoid this.
- **The supervision-tree disaster.** A misconfigured supervisor restarts indefinitely. Repeated crashes consume CPU; the system runs but accomplishes nothing. Mitigations: backoff between restarts, limits on restart count, escalation policies.
- **The lost message.** Default actor messaging is at-most-once. A network drop or actor crash loses the message. If the application assumes at-least-once, bugs surface intermittently. Mitigation: explicit acknowledgment patterns, persistent queues for critical paths.
- **The deadlock via request-response.** Actor A sends a request to B and waits for a response. B sends a request to A and waits. Neither processes the other's request because they're "waiting." Modern frameworks support timeouts and async response patterns; older code sometimes blocks.
- **The location-transparency surprise.** Code works locally, fails distributed. Reason: in-process messages were always-delivered; remote messages aren't. Always-delivered was an accidental property of locality.
- **Stale ActorRefs after restart.** After an actor restarts, references to the old instance still appear valid but messages go to a new instance with fresh state. Subtle bugs.

The senior engineer's habits:
- **Bound all mailboxes**.
- **Design supervision hierarchies explicitly**, with escalation and backoff.
- **Distinguish at-most-once from at-least-once** in critical message paths.
- **Use persistence** (Akka Persistence, Orleans grain persistence) for actors with important state.
- **Avoid request-response patterns that block** the actor; prefer fire-and-forget with callbacks.
- **Monitor mailbox sizes** as a primary metric — saturation indicator.
- **Plan for actor placement** in distributed deployments — locality matters.

---

## Failure Scenarios

**Scenario 1 — The mailbox bomb.**
A producer actor pushes events at 10K/s. The consumer can handle 5K/s. Mailbox unbounded. Memory grows by 100MB/min. OOM in 30 minutes. Production restart "fixes" it; recurs. Permanent fix: bound the mailbox; producer must handle backpressure.

**Scenario 2 — The supervisor restart loop.**
A bug in actor initialization causes immediate crash on startup. Supervisor restarts. Crash. Restart. Crash. The CPU is fully consumed by restart attempts; nothing else runs. Mitigation: exponential backoff between restarts; max restart count.

**Scenario 3 — The lost message in remote context.**
Code tested locally works. Deployed across nodes; ~0.1% of messages silently lost during network blips. Application bugs accumulate. Mitigation: explicit acks for critical messages; persistent queues for events that must not be lost.

**Scenario 4 — The deadlock via synchronous ask.**
Actor A's handler does `b.ask(query).await(5s)`. Actor B's handler does the symmetric thing. They never process each other's queries. Both time out. Mitigation: design async patterns; never `await` from inside an actor's message handler.

**Scenario 5 — The hot virtual actor.**
A grain representing "all global counters" receives every counter increment. Throughput is bottlenecked at one node. Mitigation: shard the counters across many grains; aggregate elsewhere.

---

## Performance Perspective

- **Actor message dispatch** is microseconds in modern frameworks. Negligible per-message overhead.
- **Mailbox enqueue/dequeue** is fast for unbounded; bounded with blocking has more contention.
- **Per-actor scheduling** is cheap (Erlang famously schedules millions of processes per node).
- **Cross-node messaging** has network latency + serialization cost — orders of magnitude slower than local.
- **Message size matters**: serializing huge payloads is expensive; reference-and-fetch patterns sometimes win.

---

## Scaling Perspective

- **Vertical**: a single node can host millions of actors with appropriate runtime (Erlang BEAM, Akka).
- **Horizontal**: actor systems scale across nodes; framework handles routing.
- **Sharding**: actors sharded by ID across nodes (Akka Cluster Sharding, Orleans grains).
- **Geographic**: cross-region actor messaging is possible but pays network costs; usually structured as eventual-consistency between regions.
- **At hyperscale**: Erlang-based systems (WhatsApp, Discord) have run on relatively few nodes serving hundreds of millions of users.

---

## Cross-Domain Connections

- **Locks**: actors avoid most lock pitfalls by *not sharing state*. The locks within frameworks (mailbox, scheduler) are infrastructure, not application code. (See [locks-mutexes-and-lock-free.md](./locks-mutexes-and-lock-free.md).)
- **Backpressure**: actor mailboxes are queues; bounded mailboxes implement backpressure naturally. (See [backpressure-and-queues.md](./backpressure-and-queues.md).)
- **Cascading failures**: supervision trees contain failures by design. The "let it crash" philosophy is a structured cascade-containment strategy. (See [cascading-failures-and-circuit-breakers.md](../system-failures/cascading-failures-and-circuit-breakers.md).)
- **Event loop**: the actor model is, in essence, *many event loops cooperating*. Each actor is its own single-threaded loop. (See [event-loop-and-async-runtime.md](../js-runtime/event-loop-and-async-runtime.md).)
- **CQRS / Event sourcing**: actor state is naturally event-sourced; akka-persistence and orleans-event-sourcing make this explicit. (See [cqrs-and-event-sourcing.md](../architecture-patterns/cqrs-and-event-sourcing.md).)
- **Sagas**: a saga can be modeled as an actor whose state is the saga's progress. Compensation = reverse messages. (See [saga-pattern-and-distributed-transactions.md](../architecture-patterns/saga-pattern-and-distributed-transactions.md).)

The unifying observation: **the actor model takes "share nothing, communicate explicitly" as its founding principle, and gets a different set of tradeoffs than shared-memory concurrency.** Both approaches work; both have failure modes; the choice is about which failure modes you'd rather face.

---

## Real Production Scenarios

- **WhatsApp at billions of users** ran on Erlang. Famous slide: "2 million connections per server." Documented in conference talks.
- **Discord's Elixir voice servers**: managed millions of concurrent voice connections per cluster on Erlang's runtime. Public engineering posts describe the model.
- **LinkedIn's Akka usage**: large-scale actor-based services for messaging and feeds.
- **Halo's matchmaking on Orleans**: documented case study of virtual actors managing millions of concurrent players.
- **Riak (Erlang)**: distributed database built natively on actor primitives.
- **Klarna (Erlang)**: payment infrastructure at significant scale.
- **The Erlang AXD301 telecom switch**: nine-nines availability achieved through Erlang's actor model and supervision hierarchy. Reference point for "highly reliable concurrent system."

---

## What Junior Engineers Usually Miss

- That **actors don't share memory** — `state` is private to the actor.
- That **default messaging is at-most-once** — message loss is possible.
- That **unbounded mailboxes are deferred crashes**.
- That **actor supervision is structured failure handling**, not an exception substitute.
- That **request-response patterns can deadlock** if not designed carefully.
- That **"let it crash" is a discipline**, not "ignore errors."
- That **hot actors are scalability bottlenecks**.
- That **location transparency is leaky** — distributed differs from local.

---

## What Senior Engineers Instinctively Notice

- They **bound mailboxes** by default.
- They **design supervision hierarchies** explicitly.
- They **distinguish persistent from ephemeral actors**.
- They **shard hot actors** across many instances.
- They **use async patterns** rather than synchronous `ask` everywhere.
- They **monitor mailbox sizes** as a primary metric.
- They **understand at-most-once vs at-least-once** for their use case.
- They **plan actor placement** in distributed systems.

---

## Interview Perspective

What gets tested:

1. **"Explain the actor model."** Tests basic literacy. Bonus for naming Erlang, Akka, the isolation property.
2. **"How does an actor handle concurrency?"** Single-threaded within actor; messages serialized via mailbox.
3. **"What's 'let it crash'?"** Failures propagate to supervisors; supervisors decide recovery; simpler code with explicit failure boundaries.
4. **"Actors vs threads + locks?"** Tests practical understanding. Senior answer: tradeoffs in failure modes, not just performance.
5. **"How do actors scale across nodes?"** Location transparency, cluster sharding, location-aware routing.
6. **"What's a virtual actor?"** Activated on demand; state persisted; reactivated as needed. Orleans pattern.
7. **"How do you handle backpressure in an actor system?"** Bounded mailboxes; rejection or blocking on full; explicit flow control.

Common traps:
- Believing actors eliminate concurrency bugs entirely (they eliminate *some*; deadlocks via messaging are still possible).
- Confusing actors with goroutines (similar family; different specifics).
- Assuming default messaging is at-least-once.

---

## 20% Knowledge Giving 80% Understanding

1. **Each actor is single-threaded** with private state.
2. **Communication is messages**, never direct method calls.
3. **Bounded mailboxes** are mandatory in production.
4. **Supervision** structures failure handling.
5. **"Let it crash"** is a discipline, not chaos.
6. **At-most-once messaging** by default — design for loss when it matters.
7. **Hot actors are bottlenecks**; shard them.
8. **Location transparency is leaky** — local ≠ remote.
9. **Virtual actors** simplify lifecycle management.
10. **Use async patterns**; don't block in handlers.

---

## Final Mental Model

> **Actors trade shared state for explicit messages. The bug categories shift: no race conditions, no lock convoys, no deadlocks-on-shared-data. In their place: lost messages, mailbox bombs, supervision misconfigurations. The new bugs are usually easier to diagnose and the new code is usually easier to reason about — at the cost of structural changes in how you write systems.**

The senior engineer evaluating "should we use actors?" doesn't ask "are actors better?" — they ask "what concurrency bugs are we currently fighting?" If the answer is "lock contention, race conditions, deadlocks across services," actors solve real problems. If the answer is "we don't actually have much concurrency," actors are overengineering.

Erlang's 30+ years of running telecom infrastructure, WhatsApp's billion-user scale on a small Erlang cluster, Discord's voice chat infrastructure — these are not curiosities. They're proof that for certain classes of system (high concurrency, fault tolerance, long uptime), actor-based design beats threading-with-locks decisively. The pattern doesn't fit every problem. Where it fits, it fits powerfully.

That's the actor model. That's message passing. That's what concurrency looks like when you stop trying to share memory and start designing protocols instead.
