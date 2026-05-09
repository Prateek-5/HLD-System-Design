# Worked Examples

> Concrete scenarios that walk through the patterns from the corpus end-to-end. Each example: a real-shaped problem, the wrong way, the right way, and which artifacts to read for context. Code is illustrative — pseudocode where it clarifies, real syntax where it matters.

---

## 1. The Idempotent Charge API

### The problem

You're building a payment service. A POST `/charges` creates a charge. The client may retry on network failure. Without care: customer charged twice.

### The wrong way

```python
@app.post("/charges")
def create_charge(amount: int, source: str):
    charge_id = uuid.uuid4()
    db.execute("INSERT INTO charges (id, amount, source) VALUES (?, ?, ?)",
               charge_id, amount, source)
    stripe.charge(amount, source)
    return {"id": charge_id, "status": "ok"}
```

What goes wrong: client times out; retries; we charge the card again. Or: card charged but client never gets the response (network blip on the way back); client retries; double charge.

### The right way

```python
@app.post("/charges")
def create_charge(
    request: ChargeRequest,
    idempotency_key: str = Header(...),
):
    # Atomic check-and-insert via UNIQUE constraint
    try:
        with db.transaction():
            db.execute(
                "INSERT INTO idempotency_records (key, status) VALUES (?, ?)",
                idempotency_key, "in_progress"
            )
    except UniqueViolation:
        # Already seen this key
        existing = db.fetch_one(
            "SELECT response, status FROM idempotency_records WHERE key = ?",
            idempotency_key
        )
        if existing.status == "in_progress":
            raise HTTPException(409, "Request already in progress")
        return json.loads(existing.response)

    # Process normally
    try:
        charge_id = str(uuid.uuid4())
        # Pass idempotency_key downstream too — Stripe accepts it
        stripe_response = stripe.charge(
            amount=request.amount,
            source=request.source,
            idempotency_key=idempotency_key,
        )
        result = {"id": charge_id, "status": "succeeded", "stripe_id": stripe_response.id}

        with db.transaction():
            db.execute(
                "INSERT INTO charges (id, amount, source, stripe_id) VALUES (?, ?, ?, ?)",
                charge_id, request.amount, request.source, stripe_response.id
            )
            db.execute(
                "UPDATE idempotency_records SET status = ?, response = ? WHERE key = ?",
                "succeeded", json.dumps(result), idempotency_key
            )
        return result
    except Exception as e:
        # Mark failed; future retries with same key get the same error
        with db.transaction():
            db.execute(
                "UPDATE idempotency_records SET status = ?, response = ? WHERE key = ?",
                "failed", json.dumps({"error": str(e)}), idempotency_key
            )
        raise
```

What's right: client provides `Idempotency-Key`. Server's UNIQUE constraint on the key handles concurrent retries. Same key → same response, no duplicate charge. Idempotency propagates to Stripe. Window of "in progress" handled.

### Read for more

- [Idempotency Receivers & "Exactly-Once" Semantics](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)
- [Timeouts, Retries & Idempotency](system-failures/timeouts-retries-and-idempotency.md)
- [API Design](architecture-patterns/api-design-rest-vs-grpc.md)

---

## 2. The Saga for Order Placement

### The problem

User places an order. The flow: validate cart → reserve inventory → charge payment → schedule fulfillment → notify user. Each step can fail. We can't 2PC across services. How do we handle partial failure?

### The wrong way

```python
def place_order(order):
    inventory.reserve(order.items)  # what if this succeeds but next fails?
    payment.charge(order.total)
    fulfillment.schedule(order)
    notify.send(order.user_id)
```

Failure at step 3 leaves inventory reserved and payment taken — but no fulfillment. Customer charged for nothing.

### The right way (orchestrated saga)

```python
@dataclass
class OrderSagaState:
    order_id: str
    inventory_reserved: bool = False
    payment_charged: bool = False
    fulfillment_scheduled: bool = False
    payment_id: Optional[str] = None

def place_order_saga(order):
    state = OrderSagaState(order_id=order.id)
    save_saga_state(state)  # durable; resumable

    try:
        # Step 1: Reserve inventory
        inventory.reserve(
            items=order.items,
            idempotency_key=f"order-{order.id}-inventory"
        )
        state.inventory_reserved = True
        save_saga_state(state)

        # Step 2: Charge payment (the pivot — after this, must succeed)
        payment_response = payment.charge(
            amount=order.total,
            source=order.payment_source,
            idempotency_key=f"order-{order.id}-payment"
        )
        state.payment_id = payment_response.id
        state.payment_charged = True
        save_saga_state(state)

        # Step 3: Schedule fulfillment (post-pivot — retry until success)
        retry_until_success(
            lambda: fulfillment.schedule(
                order,
                idempotency_key=f"order-{order.id}-fulfillment"
            )
        )
        state.fulfillment_scheduled = True
        save_saga_state(state)

        # Step 4: Notification (best-effort; not critical)
        try:
            notify.send(order.user_id, order.id)
        except Exception as e:
            log.warning(f"Notification failed: {e}")  # not fatal

        return {"order_id": order.id, "status": "placed"}

    except Exception as e:
        # Compensate in reverse order of completed steps
        compensate(state)
        raise

def compensate(state):
    if state.payment_charged:
        retry_until_success(
            lambda: payment.refund(
                state.payment_id,
                idempotency_key=f"order-{state.order_id}-refund"
            )
        )
    if state.inventory_reserved:
        retry_until_success(
            lambda: inventory.release(
                state.order_id,
                idempotency_key=f"order-{state.order_id}-release"
            )
        )
    # Note: fulfillment_scheduled doesn't compensate here — it's post-pivot
```

What's right:
- Each step is idempotent (idempotency keys).
- Saga state is persisted (resumable on crash).
- Pivot transaction identified (after payment, must succeed).
- Compensation in reverse order.
- Notification is best-effort (failure tolerated).
- Better still: use Temporal or AWS Step Functions for production.

### Read for more

- [Sagas & Distributed Transactions](architecture-patterns/saga-pattern-and-distributed-transactions.md)
- [Idempotency Receivers](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)
- [Distributed Transactions 2PC/3PC](distributed-systems/distributed-transactions-2pc-3pc.md)

---

## 3. The Cache Stampede Fix

### The problem

A popular cache key (`product:12345`) expires. 1000 concurrent requests miss simultaneously. All 1000 query the database. Database CPU spikes; latency degrades; sometimes the database falls over.

### The wrong way

```python
def get_product(id):
    cached = redis.get(f"product:{id}")
    if cached:
        return json.loads(cached)
    product = db.fetch_one("SELECT * FROM products WHERE id = ?", id)
    redis.setex(f"product:{id}", 300, json.dumps(product))
    return product
```

Every cache miss for a hot key = thundering herd to the database.

### The right way (single-flight + probabilistic refresh)

```python
import random
import time
import threading
from concurrent.futures import Future

# In-process single-flight: only one fetch per key in-flight
_in_flight: dict[str, Future] = {}
_in_flight_lock = threading.Lock()

def get_product(id):
    cache_key = f"product:{id}"
    cached = redis.get(cache_key)

    if cached:
        data = json.loads(cached)
        # Probabilistic early refresh: as TTL gets close to expiry,
        # increasing probability that we refresh in the background
        ttl_remaining = redis.ttl(cache_key)
        if should_early_refresh(ttl_remaining, data["fetched_at"]):
            schedule_background_refresh(id)
        return data

    # Cache miss: single-flight to prevent stampede
    return single_flight_fetch(id)

def should_early_refresh(ttl_remaining, fetched_at):
    age = time.time() - fetched_at
    total_ttl = age + ttl_remaining
    # XFetch: probabilistic early expiration
    # Probability rises as we approach expiration
    beta = 1.0  # tunable
    return random.random() < beta * (age / total_ttl) ** 2

def single_flight_fetch(id):
    cache_key = f"product:{id}"
    with _in_flight_lock:
        if cache_key in _in_flight:
            future = _in_flight[cache_key]  # wait for the one in flight
        else:
            future = Future()
            _in_flight[cache_key] = future
            # Spawn the actual fetch
            threading.Thread(target=_do_fetch, args=(id, future)).start()
    return future.result(timeout=5)

def _do_fetch(id, future):
    try:
        product = db.fetch_one("SELECT * FROM products WHERE id = ?", id)
        product["fetched_at"] = time.time()
        redis.setex(f"product:{id}", 300, json.dumps(product))
        future.set_result(product)
    except Exception as e:
        future.set_exception(e)
    finally:
        with _in_flight_lock:
            _in_flight.pop(f"product:{id}", None)
```

What's right:
- Single-flight ensures only one DB query per key (within a process).
- Probabilistic early refresh prevents the cliff at TTL expiry — keys are refreshed *before* they expire under load.
- For multi-instance: use a Redis-based mutex (`SET NX`) instead of in-process lock.
- Stale-while-revalidate variant: serve stale; refresh in background.

### Read for more

- [Caching Hierarchy](caching/caching-hierarchy.md)
- [Cascading Failures & Circuit Breakers](system-failures/cascading-failures-and-circuit-breakers.md)

---

## 4. Diagnosing a Slow Service with Flame Graphs

### The problem

Your Node.js service averaged 5ms per request. Yesterday's deploy: average is now 150ms. Nothing in the diff looks suspect.

### The wrong way

Try things. Increase memory. Roll back. Add a cache. Pray.

### The right way (profile-driven)

```bash
# Step 1: Confirm the regression in metrics
# - Average latency up: yes
# - p99 up: 30ms → 800ms (much worse than average suggests)
# - CPU usage up: 30% → 75%
# - GC time as % of CPU: 5% → 15%

# Step 2: Capture a CPU profile
node --prof server.js
# Generate load (or wait for prod traffic)
# kill the process; process the log
node --prof-process isolate-*.log > processed.txt

# Or use clinic for higher-level diagnostics
clinic doctor -- node server.js

# Step 3: Generate a flame graph for visual analysis
0x server.js
# generates flame graph SVG
```

Reading the flame graph:

```
Width = time spent. Read width-first.

[==========================] handle_request                          (full width)
   [==================] parse_json                                      (60%)
       [================] string_to_object                                (45%)
           [==========] decode_utf8                                       (30%)
   [======] business_logic                                                (20%)
   [===] db_query                                                         (10%)
   [=] response_serialization                                              (4%)
```

Diagnosis: 60% of CPU is in JSON parsing! The recent deploy added a feature that parses a 200KB config blob on every request.

### The fix

```javascript
// Before: parse on every request
function handler(req, res) {
    const config = JSON.parse(loadConfig());  // 200KB parse, every request
    processWith(req, config);
}

// After: parse once, cache
let cachedConfig = null;
let cacheTime = 0;

function getConfig() {
    if (!cachedConfig || Date.now() - cacheTime > 60000) {
        cachedConfig = JSON.parse(loadConfig());
        cacheTime = Date.now();
    }
    return cachedConfig;
}

function handler(req, res) {
    const config = getConfig();
    processWith(req, config);
}
```

### Verify

Re-run profile after deploy. Flame graph should show JSON parsing dropped from 60% to <5%. Latency back to baseline. Confirmed fix.

### Read for more

- [Profiling & Flame Graphs](observability/profiling-and-flame-graphs.md)
- [V8 Internals & Hidden Classes](js-runtime/v8-internals-and-hidden-classes.md)
- [Caching Hierarchy](caching/caching-hierarchy.md)

---

## 5. Burn-Rate Alerting for an SLO

### The problem

You have an SLO: 99.9% of requests complete with success in <500ms over a 28-day rolling window. You want to alert on real degradation, not noise.

### The wrong way

```yaml
# Static threshold — fires constantly on transient blips
- alert: HighErrorRate
  expr: error_rate > 0.001
  for: 1m
  severity: page
```

Noisy: blips fire pages. Alert fatigue.

Or:

```yaml
# Only on sustained breach — too late
- alert: SLOBreached
  expr: avg_over_time(error_rate[28d]) > 0.001
  severity: page
```

Fires *after* you've burned the entire budget. Useless for prevention.

### The right way (multi-window, multi-burn-rate)

The error budget is `1 - 0.999 = 0.001` (0.1%). Over 28 days: ~40 minutes of "down" allowed.

A burn rate of 14.4× means: at this rate, you'd burn the entire monthly budget in 1/14.4 of the window = 2 days. Page-worthy.

```yaml
# Page: fast burn (sustained for 5 min, observed for 1 hour)
- alert: SLOFastBurn
  expr: |
    (
      sum(rate(http_requests_failed[1h])) / sum(rate(http_requests_total[1h])) > (14.4 * 0.001)
    ) and (
      sum(rate(http_requests_failed[5m])) / sum(rate(http_requests_total[5m])) > (14.4 * 0.001)
    )
  for: 2m
  severity: page
  description: "Error budget burning at 14.4× normal rate. Will exhaust in 2 days."

# Page: medium burn (sustained for 30 min, observed for 6 hours)
- alert: SLOMediumBurn
  expr: |
    (
      sum(rate(http_requests_failed[6h])) / sum(rate(http_requests_total[6h])) > (6 * 0.001)
    ) and (
      sum(rate(http_requests_failed[30m])) / sum(rate(http_requests_total[30m])) > (6 * 0.001)
    )
  for: 5m
  severity: page

# Ticket: slow burn
- alert: SLOSlowBurn
  expr: |
    (
      sum(rate(http_requests_failed[24h])) / sum(rate(http_requests_total[24h])) > (3 * 0.001)
    )
  for: 30m
  severity: ticket
```

Why two windows: long window confirms sustained behavior; short window confirms it's *currently* happening. Both must trigger to fire.

### What this catches

- **14.4× burn**: severe; immediate page. Catches actual outages.
- **6× burn**: significant; immediate page. Catches partial degradations.
- **3× burn**: trending bad; ticket for engineering review. Catches drift before it's an outage.

The team's pager doesn't fire on transient blips. It fires when the SLO is genuinely at risk.

### Read for more

- [SLOs, Error Budgets & Alerting](observability/slos-error-budgets-and-alerting.md)
- [Cascading Failures & Circuit Breakers](system-failures/cascading-failures-and-circuit-breakers.md)

---

## 6. Sharding a Large Table

### The problem

A `users` table has 500M rows. Single Postgres can no longer handle the load. You need to shard.

### The wrong way

Pick a partition key by hash and migrate. Discover later that:
- "All my reports break" — they joined users with orders, but now orders are on different shards.
- "Some shards are 10× larger than others" — your distribution is skewed.
- "The CEO's account is on a hot shard" — celebrity user generates 50% of traffic.

### The right way

#### Step 1: Analyze query patterns

```sql
-- Top queries by frequency:
-- 1. SELECT * FROM users WHERE id = ?           (95% of reads)
-- 2. SELECT * FROM users WHERE email = ?        (4%)
-- 3. SELECT COUNT(*) FROM users WHERE region=?  (1%; reports)

-- Joins:
-- - users JOIN orders ON orders.user_id = users.id    (very common)
-- - users JOIN sessions ON sessions.user_id = users.id  (common)
```

Insight: most operations are by user_id; joined tables are by user_id; reports scatter-gather is acceptable. **Partition key: user_id**.

#### Step 2: Choose a sharding strategy

```python
# Hash-based sharding with vnodes (consistent hashing)
NUM_VNODES = 256  # logical partitions
NUM_PHYSICAL_SHARDS = 8  # current physical shards

def shard_for_user(user_id: int) -> int:
    vnode = hash(user_id) % NUM_VNODES
    return vnode % NUM_PHYSICAL_SHARDS  # mapping changes as shards grow

# orders, sessions co-located with users
def shard_for_order(order: Order) -> int:
    return shard_for_user(order.user_id)
```

Why vnodes: future capacity additions remap only some vnodes; not catastrophic.

#### Step 3: Migration via dual-write + backfill

```python
# Phase 1: Write to both old and new (dual-write); read from old
def create_user(user):
    old_db.insert(user)
    new_db.insert(user, shard=shard_for_user(user.id))  # best-effort; reconcile if fails
    return user

# Phase 2: Backfill historical data to new shards
# Background job copies old → new in batches; idempotent

# Phase 3: Switch reads to new (with fallback)
def get_user(id):
    try:
        return new_db.fetch(id, shard=shard_for_user(id))
    except NotFound:
        # During migration, fall back to old; backfill missing
        user = old_db.fetch(id)
        new_db.insert(user, shard=shard_for_user(id))
        return user

# Phase 4: Stop dual-write to old
# Phase 5: Decommission old
```

#### Step 4: Handle hot keys

```python
# Detect: monitor per-shard load
# If shard X consistently 10× others, drill into top customers

# For a celebrity user (1% of total traffic):
# Option A: replicate their data to a read pool
celebrity_users = {"u-12345"}

def get_user(id):
    if id in celebrity_users:
        replica = pick_random(celebrity_replicas[id])
        return replica.fetch(id)
    return shard_for_user(id).fetch(id)

# Option B: bucket their data
# user_id "u-12345" becomes "u-12345#bucket-0", "...#bucket-1", etc.
```

#### Step 5: Cross-shard queries

```python
# "Count users per region" — scatter-gather
def count_users_per_region():
    futures = [
        executor.submit(shard.count_per_region) for shard in all_shards
    ]
    results = [f.result() for f in futures]
    return merge_counts(results)

# Better: precompute via CDC to a warehouse
# Reports run on the warehouse; OLTP shards stay clean
```

### Read for more

- [Sharding & Partitioning Strategies](scalability/sharding-and-partitioning-strategies.md)
- [Replication Strategies](database-internals/replication-strategies.md)
- [OLTP vs OLAP](database-internals/oltp-vs-olap-and-columnar-storage.md)

---

## 7. Implementing Backpressure in a Streaming Pipeline

### The problem

You're building a Node.js service that reads a multi-GB CSV file, transforms each row, and writes to a database. Naive code OOMs.

### The wrong way

```javascript
const fs = require('fs');
const csv = require('csv-parser');

async function process(filename) {
    const rows = [];
    fs.createReadStream(filename)
        .pipe(csv())
        .on('data', (row) => rows.push(row));  // accumulates everything

    return new Promise((resolve) => {
        stream.on('end', async () => {
            for (const row of rows) {  // process in memory
                await db.insert(transform(row));
            }
            resolve();
        });
    });
}
```

A 5GB CSV becomes 10GB of objects in memory. OOM.

### The right way (streams + backpressure via pipeline)

```javascript
const fs = require('fs');
const { pipeline } = require('stream/promises');
const csv = require('csv-parser');
const { Transform } = require('stream');

async function process(filename) {
    // Object-mode transform that batches and writes
    let batch = [];
    const BATCH_SIZE = 1000;

    const transformer = new Transform({
        objectMode: true,
        async transform(row, encoding, callback) {
            try {
                batch.push(transform(row));
                if (batch.length >= BATCH_SIZE) {
                    await db.insertBatch(batch);  // backpressure: stream waits
                    batch = [];
                }
                callback();
            } catch (err) {
                callback(err);
            }
        },
        async flush(callback) {
            if (batch.length > 0) {
                try {
                    await db.insertBatch(batch);
                    callback();
                } catch (err) {
                    callback(err);
                }
            } else {
                callback();
            }
        }
    });

    await pipeline(
        fs.createReadStream(filename),
        csv(),
        transformer
    );
}
```

What's right:
- `pipeline` propagates backpressure: when transformer is busy (DB insert in progress), CSV parser pauses; CSV parser pauses, file read pauses.
- Memory bounded: at any moment, ~BATCH_SIZE rows in memory, not all of them.
- Errors propagate cleanly through pipeline.
- Cleanup automatic.

Even better — async iteration:

```javascript
async function process(filename) {
    const stream = fs.createReadStream(filename).pipe(csv());
    let batch = [];

    for await (const row of stream) {
        batch.push(transform(row));
        if (batch.length >= 1000) {
            await db.insertBatch(batch);  // implicit backpressure
            batch = [];
        }
    }
    if (batch.length > 0) {
        await db.insertBatch(batch);
    }
}
```

The `await` slows the iteration; the iteration's pace slows the stream; backpressure flows naturally.

### Read for more

- [Streams & Backpressure in Node](js-runtime/streams-and-backpressure-in-node.md)
- [Backpressure & Queues](concurrency/backpressure-and-queues.md)

---

## 8. Adding Distributed Tracing to a Microservice

### The problem

Your service receives requests from a frontend, calls 3 internal services, queries a database, and returns. Sometimes it's slow. You can't tell which downstream is at fault.

### The wrong way

Sprinkle `console.log` statements with timestamps. Try to correlate manually across services. Give up.

### The right way (OpenTelemetry)

```javascript
// 1. Initialize tracing at app startup
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { Resource } = require('@opentelemetry/resources');
const { SemanticResourceAttributes } = require('@opentelemetry/semantic-conventions');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');

const sdk = new NodeSDK({
    resource: new Resource({
        [SemanticResourceAttributes.SERVICE_NAME]: 'orders-service',
        [SemanticResourceAttributes.SERVICE_VERSION]: process.env.VERSION,
    }),
    traceExporter: new OTLPTraceExporter({
        url: 'http://otel-collector:4318/v1/traces'
    }),
    instrumentations: [
        // Auto-instrument HTTP, DB, etc.
        new HttpInstrumentation(),
        new ExpressInstrumentation(),
        new PgInstrumentation(),
    ],
});
sdk.start();
```

Auto-instrumentation handles HTTP server, HTTP client (outbound), Postgres, etc. Trace context propagation via `traceparent` header — automatic.

```javascript
// 2. Add manual spans for business-meaningful operations
const { trace } = require('@opentelemetry/api');
const tracer = trace.getTracer('orders-service');

async function processOrder(order) {
    return tracer.startActiveSpan('process_order', async (span) => {
        try {
            span.setAttribute('order.id', order.id);
            span.setAttribute('order.total', order.total);
            span.setAttribute('order.items_count', order.items.length);

            await tracer.startActiveSpan('validate_cart', async (validateSpan) => {
                await validateCart(order);
                validateSpan.end();
            });

            await tracer.startActiveSpan('reserve_inventory', async (resSpan) => {
                resSpan.setAttribute('downstream.service', 'inventory');
                await inventoryService.reserve(order.items);
                resSpan.end();
            });

            await tracer.startActiveSpan('charge_payment', async (paySpan) => {
                paySpan.setAttribute('downstream.service', 'payment');
                const result = await paymentService.charge(order.total);
                paySpan.setAttribute('payment.id', result.id);
                paySpan.end();
            });

            span.setStatus({ code: SpanStatusCode.OK });
            return { success: true };
        } catch (err) {
            span.recordException(err);
            span.setStatus({ code: SpanStatusCode.ERROR, message: err.message });
            throw err;
        } finally {
            span.end();
        }
    });
}
```

```javascript
// 3. Add trace ID to every log line
const { context, trace } = require('@opentelemetry/api');

function log(level, message, attrs = {}) {
    const span = trace.getActiveSpan();
    const ctx = span?.spanContext();
    logger.log(level, message, {
        ...attrs,
        trace_id: ctx?.traceId,
        span_id: ctx?.spanId,
    });
}
```

### What this gives you

A waterfall view of every request:

```
[================================================ process_order (450ms) ==]
  [== validate_cart (10ms) ==]
                              [================== reserve_inventory (180ms) ==]
                                                                              [==== charge_payment (220ms) ====]
```

Click any span to see attributes. Click the trace_id from a log line to jump to the trace. Click on a span to fetch logs from that exact time window.

The "why is this slow" question becomes: look at the waterfall, find the wide bar.

### Read for more

- [Distributed Tracing — A Deep Dive](observability/distributed-tracing-deep-dive.md)
- [Metrics, Logs & Traces](observability/metrics-logs-traces.md)
- [SLOs, Error Budgets](observability/slos-error-budgets-and-alerting.md)

---

## 9. Building an Idempotent Kafka Consumer

### The problem

Your service consumes events from Kafka. The events trigger side effects (email sends, payments). Kafka delivers at-least-once; consumer crashes can cause re-delivery. You need effectively-once processing.

### The wrong way

```python
def consume():
    for message in kafka_consumer:
        send_email(message.user_id, message.template)
        kafka_consumer.commit(message.offset)
```

Crash between `send_email` and `commit`: on restart, message redelivered; second email sent.

### The right way

```python
def consume():
    for message in kafka_consumer:
        process_message(message)
        kafka_consumer.commit(message.offset)

def process_message(message):
    msg_id = message.headers.get('message-id') or f"{message.topic}-{message.partition}-{message.offset}"

    with db.transaction():
        # Atomic check-and-record
        try:
            db.execute(
                "INSERT INTO processed_messages (msg_id, processed_at) VALUES (?, ?)",
                msg_id, time.time()
            )
        except UniqueViolation:
            log.info(f"Already processed {msg_id}; skipping")
            return  # idempotent: already done

        # The side effect AND the marker are atomic via the DB transaction
        # — but the email sending isn't transactional with the DB.
        # Pattern: outbox.

        # Insert into outbox; same transaction
        db.execute(
            "INSERT INTO email_outbox (recipient, template, sent) VALUES (?, ?, false)",
            message.user_id, message.template
        )
        # Commit happens at the end of the with block

    # Outbox sender (separate process):
    # SELECT FROM email_outbox WHERE sent = false
    # for each: send via SMTP; UPDATE sent = true
    # Crash between send and update: SMTP service has its own idempotency
    # (or accept the rare duplicate; emails usually idempotent for users)
```

Even better — at the DB level, use the message's effect itself for idempotency:

```python
def process_payment_message(message):
    msg_id = message.headers['message-id']

    with db.transaction():
        # The payment record has UNIQUE on idempotency_key
        try:
            db.execute(
                "INSERT INTO payments (id, user_id, amount, idempotency_key) VALUES (?, ?, ?, ?)",
                str(uuid.uuid4()), message.user_id, message.amount, msg_id
            )
        except UniqueViolation:
            return  # already processed; no-op

        # The transaction commit is the "marker" — automatic and atomic
        # No separate processed_messages table needed
```

What's right:
- Idempotency keyed on the message ID (or content hash).
- Atomic check-and-record via DB transaction.
- Side effects either (a) inside DB transaction (DB writes), (b) via outbox (other systems), or (c) idempotent at receiver (downstream services with their own idempotency).
- Kafka's `acks=all` + `enable.idempotence=true` for producer; transactional for consume-process-produce.

### Read for more

- [Kafka Internals & Stream Processing](architecture-patterns/kafka-internals-and-stream-processing.md)
- [Idempotency Receivers](architecture-patterns/idempotency-receivers-and-exactly-once-semantics.md)
- [Sagas](architecture-patterns/saga-pattern-and-distributed-transactions.md)

---

## 10. Designing for Graceful Degradation

### The problem

Your e-commerce homepage shows: header, products, recommendations, related items, ads, footer. Recommendation service is slow today. The page should still load.

### The wrong way

```python
def homepage(user):
    return {
        "header": get_header(user),
        "products": get_products(),
        "recommendations": rec_service.get(user),  # 5 seconds today
        "related": rel_service.get(),
        "ads": ad_service.get(user),
        "footer": get_footer()
    }
```

Page hangs for 5 seconds. Or worse, recommendations service times out and the whole page returns 500.

### The right way (parallel + fallback + bounded)

```python
import asyncio
from typing import Optional

async def homepage(user):
    # Parallelize independent calls
    results = await asyncio.gather(
        with_timeout_and_fallback(get_header(user), timeout=0.2, fallback=DEFAULT_HEADER),
        with_timeout_and_fallback(get_products(), timeout=0.5, fallback=CACHED_PRODUCTS),
        with_timeout_and_fallback(rec_service.get(user), timeout=0.3, fallback=POPULAR_PRODUCTS),
        with_timeout_and_fallback(rel_service.get(), timeout=0.3, fallback=[]),
        with_timeout_and_fallback(ad_service.get(user), timeout=0.2, fallback=NO_ADS),
        get_footer(),  # synchronous, fast
        return_exceptions=False,
    )

    return {
        "header": results[0],
        "products": results[1],
        "recommendations": results[2],
        "related": results[3],
        "ads": results[4],
        "footer": results[5],
    }

async def with_timeout_and_fallback(coro, timeout: float, fallback):
    try:
        return await asyncio.wait_for(coro, timeout=timeout)
    except asyncio.TimeoutError:
        log.warning(f"Timed out after {timeout}s; using fallback")
        return fallback
    except Exception as e:
        log.warning(f"Failed: {e}; using fallback")
        return fallback
```

Better still — circuit breaker per dependency:

```python
class CircuitBreaker:
    def __init__(self, failure_threshold=5, recovery_time=30):
        self.failure_threshold = failure_threshold
        self.recovery_time = recovery_time
        self.failures = 0
        self.opened_at = None
        self.state = "closed"

    async def call(self, coro, fallback):
        if self.state == "open":
            if time.time() - self.opened_at > self.recovery_time:
                self.state = "half-open"
            else:
                return fallback

        try:
            result = await coro
            if self.state == "half-open":
                self.state = "closed"
            self.failures = 0
            return result
        except Exception:
            self.failures += 1
            if self.failures >= self.failure_threshold:
                self.state = "open"
                self.opened_at = time.time()
            return fallback

# Per-service breakers
rec_breaker = CircuitBreaker(failure_threshold=10, recovery_time=30)

async def get_recommendations(user):
    return await rec_breaker.call(
        rec_service.get(user, timeout=0.3),
        fallback=POPULAR_PRODUCTS
    )
```

What's right:
- Parallel fetching of independent data (no serial latency stacking).
- Per-call timeout (bounds latency).
- Per-call fallback (graceful degradation).
- Circuit breaker (don't keep hammering a known-broken service).
- The page always loads, even if 4 of 6 services are down.

### Read for more

- [Cascading Failures & Circuit Breakers](system-failures/cascading-failures-and-circuit-breakers.md)
- [Timeouts, Retries & Idempotency](system-failures/timeouts-retries-and-idempotency.md)
- [Backpressure & Queues](concurrency/backpressure-and-queues.md)

---

## How to Use These Examples

These examples illustrate patterns. The code is illustrative; production implementations need:

- Proper error handling and observability.
- Configuration externalized.
- Tests at every layer.
- Metrics, traces, and logs.

Read each example with its linked artifacts. The examples make the patterns concrete; the artifacts explain *why* they work and what alternatives exist.

When you encounter a similar problem, return to the relevant example. The shape of the right solution becomes recognizable with practice.
