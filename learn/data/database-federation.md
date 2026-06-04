# Database Federation — Split by Function

## A. Intuition First
Sharding splits *rows* of one big table across machines. **Federation** splits *whole tables / domains* across machines by function. Users DB on one node; products DB on another; analytics DB on a third.

## B. Mental Model
- Good for separating concerns (and scaling them independently).
- Natural step when you move toward microservices — each service owns its DB.

## C. Internal Working
- One writer per function; each DB has its own schema and backups.
- Joins across functional DBs must happen in the application layer (or via CDC into a data warehouse).

## D. Visual Representation
```
[Users service] → [Users DB]
[Products service] → [Products DB]
[Orders service] → [Orders DB]
```

## E. Tradeoffs
### Pros
- Scale each DB independently.
- Isolated failure domains.
- Smaller per-DB working set (better cache hit ratio).

### Cons
- No cross-functional joins in SQL.
- Need orchestration for cross-functional transactions (see [Distributed Transactions](distributed-transactions.md)).
- More ops overhead.

## F. Interview Lens
- "Federation vs sharding?" — federation = by function, sharding = by key within a table.
- "How do you report across federated DBs?" — ETL/CDC into a warehouse (BigQuery, Snowflake, Redshift).
- Pitfalls: starting microservices too early; needing joins you now can't do.

## G. Real-World Mapping
Every microservice architecture. Amazon's earliest rearchitecture (circa 2001) was essentially federation.

## H. Questions
**Beginner**: What's DB federation?
**Intermediate**: When do you pick federation over one big DB?
**Advanced**: How do you do cross-service transactional workflows after federating?

## I. Mini Design
An e-commerce app with users, catalog, orders, analytics. Federate into 4 DBs; use a message bus for cross-domain events; ETL all to BigQuery for reporting.

## J. Cross-Topic Connections
- [Sharding](sharding.md), [Microservices](../architecture/monolith-vs-microservices.md), [Event-Driven Architecture](../architecture/event-driven-architecture.md).

## K. Confidence Checklist
- [ ] Can contrast with sharding.
- [ ] Knows cross-functional joins require analytics warehouse or aggregation service.

## L. Potential Gaps & Improvements
- **CDC (Change Data Capture)** — tools like Debezium tail a database's write-ahead log and stream every row change out as events; the core trick for keeping federated DBs and warehouses in sync without dual writes. (→ see Interview Lens)
- **Kafka Connect** — a framework of ready-made connectors that pipe data between Kafka and external stores; lets you wire up CDC pipelines with config instead of custom code.
- **Data warehouse** — a query-optimized store (BigQuery, Snowflake, Redshift) that ingests data from all your federated DBs so you can run cross-domain reports and joins you can't do live. (→ see Interview Lens)
- **Data lakehouse** — a newer architecture (Delta Lake, Apache Iceberg) blending a cheap raw-file data lake with warehouse-style tables and transactions; worth knowing when interviewers ask "warehouse vs lake."

**🔧 How to close:** Spin up Debezium against a local Postgres with `docker compose` (the official `debezium/example-postgres` stack), `INSERT` a row, then `kafka-console-consumer --topic dbserver1.public.customers` to watch the change event arrive — see CDC end to end in five minutes.

---

### 🧭 Guided Deep-Learning Layer

> ⚠️ **Come here only after the rest of this file feels solid.** These are deliberately-skipped advanced topics — they are *not* prerequisites. If the basics above are shaky, go back; you are not behind.

#### 🔄 Gap 1 — CDC (Change Data Capture) & the Dual-Write Problem
- 🔹 **What it is**: A pattern where tools like Debezium tail a database's write-ahead log and emit every row change as an event stream, so other stores can stay in sync without your app writing to two places.
- 🔹 **Why it matters**: The moment you federate, "report across DBs" and "keep the warehouse fresh" become real problems. The naive fix — have the app write to both the DB and the warehouse — silently corrupts data when one write succeeds and the other fails (the dual-write problem). CDC sidesteps it by deriving events from the one authoritative log.
- 🔹 **Connection**: This file says cross-functional joins "must happen in the application layer (or via CDC into a data warehouse)" — CDC is the mechanism that makes that ETL pipeline reliable and near-real-time.
- 🔹 **When needed**: 🟡 **Mid-level** — shows up the instant an interviewer asks "how do you keep two stores consistent?"
- 🔹 **Intuition**: A security camera recording everything that happens at a store entrance. You don't ask each shopper to also fill out a logbook (dual write); you just replay the tape to reconstruct exactly who came and went.
- 🔹 **If you go deeper**: Read the Debezium architecture docs and the "Turning the database inside-out" talk by Martin Kleppmann; build the `debezium/example-postgres` docker stack from the How-to-close line.
- 🔹 **Interview hook**: *"Why not just have the service write to both the orders DB and the analytics DB?"* → That's a dual write with no shared transaction; a partial failure leaves them diverged forever. Capture changes from one source of truth (the WAL) via CDC instead.

---

#### 🚚 Gap 2 — Streaming Backbone: Kafka Connect & the Event Bus
- 🔹 **What it is**: Kafka Connect is a framework of ready-made source/sink connectors that move data between Kafka and external stores via config instead of custom code; combined with Kafka topics it becomes the pipe that carries CDC events and cross-domain messages.
- 🔹 **Why it matters**: Federation pushes cross-domain communication out of SQL joins and into asynchronous events. A durable, replayable log (Kafka) plus connectors is what most real systems use to fan those events out to every downstream consumer and warehouse.
- 🔹 **Connection**: The Mini Design says to "use a message bus for cross-domain events" and "ETL all to BigQuery" — Kafka + Kafka Connect is the concrete realization of both that bus and that ETL pipe.
- 🔹 **When needed**: 🟡 **Mid-level** — knowing the moving parts (topic, source connector, sink connector) is enough; tuning them is deeper.
- 🔹 **Intuition**: A postal sorting hub with pre-built conveyor belts. You don't hand-carry each parcel; you drop it on the belt labeled for its destination and the hub routes it.
- 🔹 **If you go deeper**: Set up a JDBC sink connector or the BigQuery sink connector to land CDC topics into a warehouse table; skim Confluent's Kafka Connect docs and the "Designing Data-Intensive Applications" chapter on stream processing.
- 🔹 **Interview hook**: *"What carries data from a federated service DB into the warehouse?"* → A CDC source connector publishes WAL changes to a Kafka topic; a sink connector continuously loads that topic into the warehouse — no custom batch jobs.

---

#### 🏛️ Gap 3 — Warehouse vs Lakehouse: Where Cross-Domain Joins Live
- 🔹 **What it is**: A data warehouse (BigQuery, Snowflake, Redshift) is a query-optimized store that ingests data from all your federated DBs so you can run the cross-domain reports and joins you can't do live; a lakehouse (Delta Lake, Apache Iceberg) blends a cheap raw-file data lake with warehouse-style tables and ACID transactions.
- 🔹 **Why it matters**: Federation deliberately gives up cross-functional SQL joins. The warehouse/lakehouse is *where those joins come back* — it's the architectural answer to "I federated; now how do I report across everything?"
- 🔹 **Connection**: The Interview Lens explicitly asks "How do you report across federated DBs?" and the Cons list flags "No cross-functional joins in SQL" — this gap is the resolution to both.
- 🔹 **When needed**: 🟢 **Foundational** — every learner should know "federated DBs for live traffic, warehouse for analytics"; the warehouse-vs-lakehouse nuance is 🟡 **Mid-level**.
- 🔹 **Intuition**: Specialty shops on a street (each federated DB) versus a central wholesale market (the warehouse) where buyers compare goods from every shop in one place. A lakehouse is that market built on a cheap open-air lot but with the same price tags and receipts as the indoor market.
- 🔹 **If you go deeper**: Read the Apache Iceberg table-format spec and a "warehouse vs lake vs lakehouse" comparison; load your CDC topics from Gap 2 into BigQuery and run a join across two formerly-separate domains.
- 🔹 **Interview hook**: *"Warehouse or lake — what's the difference and when do you pick a lakehouse?"* → Warehouse = structured, query-tuned, pricier storage; lake = cheap raw files, weak guarantees; lakehouse = lake storage cost plus warehouse-style ACID tables, chosen when you want both cheap scale and reliable analytics.

---

### 🏆 Start here if you have limited time
1. **Warehouse vs Lakehouse (Gap 3)** — directly answers the file's "how do you report across federated DBs?" interview question and is foundational.
2. **CDC & the dual-write problem (Gap 1)** — the single most common follow-up once you mention federation or microservices DBs.

---

### 🧭 Suggested Deep Dive Order
1. **Warehouse vs Lakehouse** (~30 min; closes the cross-domain-reporting gap conceptually).
2. **CDC & dual writes** (~1h; run the Debezium stack — the "aha" moment for keeping stores in sync).
3. **Kafka Connect & event bus** (~1.5h; wire CDC topics into a warehouse sink to see the full federation-to-reporting pipeline end to end).
