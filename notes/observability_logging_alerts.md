# Observability — Logging, Metrics, Tracing, Alerting, Anomaly Detection

### 🔹 1. What This Topic Actually Is
Turning a running distributed system into something you can understand, debug, and alert on. Three pillars: **logs, metrics, traces**. Plus alerts + anomaly detection on top.

### 🔹 2. Why It Exists
- Without observability, a microservices outage is unsolvable.
- SRE maturity ≈ observability maturity.

### 🔹 3. Core Concepts (High Signal)
- **Metrics**: numeric time-series (RED: Rate, Errors, Duration). Cheap, aggregated, alertable.
- **Logs**: high-cardinality structured records. Expensive at scale; sample/tier.
- **Traces**: end-to-end per-request flame graph across services. Need correlation IDs propagated (W3C trace-context).
- **RED method** (services) vs **USE method** (resources: Utilization, Saturation, Errors).
- **Cardinality limits**: unique label combos blow up Prometheus + Loki storage.
- **Log levels**: DEBUG/INFO/WARN/ERROR; don't log PII; JSON structured logs only.
- **Alerting**:
  - Alert on **symptoms** (error rate high), not causes.
  - Use **SLO burn rate** alerts (multi-window, multi-burn-rate) — fewer false pages.
  - Actionable alerts only; each should map to a runbook.
- **Anomaly detection**: ML for unusual patterns — Isolation Forests, Argos (Uber), ThirdEye (LinkedIn). Good for "unknown unknowns"; noisy without human tuning.

### 🔹 4. Internal Working
Services → emit metrics (Prometheus pull / StatsD push), logs (stdout → Fluent Bit / Vector → Loki/Elastic), traces (OpenTelemetry → Jaeger/Tempo).
Dashboards (Grafana). Alerts (Alertmanager → PagerDuty/Opsgenie).
SLO + burn rate → graded alerts.

**Failure points:** cardinality explosion kills metrics store; log floods during incidents; trace sampling too aggressive hides issues; alert fatigue.

### 🔹 5. Key Tradeoffs
- Metrics: cheap, low-cardinality; great for dashboards + alerts.
- Logs: detailed, expensive; keep for debugging.
- Traces: invaluable for cross-service issues; sample for cost.
- Use all three, linked via trace ID.

### 🔹 6. Interview Questions
**Beginner**
1. Logs vs metrics vs traces?
2. What's an SLO?

**Intermediate**
1. Burn rate alerting — why better than static thresholds?
2. Why is high cardinality a problem for Prometheus?

**Advanced**
1. Design distributed tracing for 1000 services.
2. Root-cause analysis system — symptoms + dependency + anomaly detection (Uber Argos).

### 🔹 7. Real System Mapping
- **Uber Argos**: real-time anomaly + RCA.
- **LinkedIn ThirdEye**: time-series alerting.
- **Pinterest Singer**: log agent.
- **Google Monitoring**: Borgmon → Prometheus lineage.
- **Jaeger, Zipkin, Tempo**: tracing.
- **Datadog, New Relic, Honeycomb**: commercial all-in-one.

### 🔹 8. What Most People Miss
- **Correlation IDs must propagate end-to-end** — missing one link breaks traces.
- **Sample traces, don't log everything** — head-based vs tail-based sampling.
- **Alert fatigue** kills SREs; every alert should map to a runbook and have a human on call.
- **SLO-based alerting** (Google SRE) uses error-budget burn rate; alerts when you're on track to miss the SLO, not on every blip.
- **Anomaly detection is ML on messy signals**; Isolation Forest is a popular unsupervised choice (ref: LinkedIn blog).

### 🔹 9. 30-Second Revision
Three pillars: metrics (cheap, aggregated), logs (rich, expensive), traces (cross-service). RED for services, USE for resources. Alert on symptoms + SLO burn rate, not static thresholds. Correlation IDs everywhere. Anomaly detection for unknown-unknowns but tune for alert fatigue.

---

## 🔗 Cross-Topic Connections
- **Microservices**: observability is what makes them operable.
- **SLA/SLO/SLI**: alerting is driven by SLOs.
- **Time-series DBs**: store metrics.
- **Stream processing**: real-time alerts on event streams.

---

### Confidence Check
- [ ] Can I design a 3-pillar observability stack for 50 services?
- [ ] Can I explain burn rate alerts?

### Gaps
- Tail-based sampling implementation.
- eBPF-based observability (Cilium Hubble).
