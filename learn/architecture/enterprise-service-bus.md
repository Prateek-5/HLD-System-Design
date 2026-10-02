# Enterprise Service Bus (ESB)

## A. Intuition First
An ESB is a central communication bus that connects many services, handling routing, transformation, and protocol translation between them. Popular in 2000s SOA (Service-Oriented Architecture).

## B. Mental Model
- Services publish to the bus; the bus routes/transforms/delivers to destinations.
- Historically bundled with BPM (business process management), transformation engines.

## C. Internal Working
- Adapter per protocol (SOAP, JMS, file, FTP, DB).
- Message routing rules.
- Content-based routing, format conversion (XML ↔ JSON), orchestration.

## D. Visual Representation
```
[Service A] ─┐                           ┌─[ Service D]
[Service B] ─┼─[   ESB   (routing,      ─┼─[ Service E]
[Service C] ─┘  transform, orchestrate) ─┘ ...
```

## E. Tradeoffs
**Pros**: single integration point, adapters for legacy.
**Cons**: central SPOF; heavyweight; has gone out of favor in favor of lightweight APIs + async messaging + microservices.

## F. Interview Lens
- "ESB vs modern event broker?" — ESB had heavy orchestration; modern event-driven prefers dumb pipes, smart endpoints (Kafka).
- "Why do most shops move off ESB?" — vendor lock-in, central bottleneck, complexity.

## G. Real-World Mapping
Mule, IBM Integration Bus, Apache Camel (can be used as ESB or library), BizTalk.

## H. Questions
**Beginner**: What does an ESB do?
**Intermediate**: Why is ESB less popular now?
**Advanced**: Given a legacy enterprise with 30 systems, ESB or broker? Defend.

## I. Mini Design
Legacy SOAP services + mainframe + new REST microservices: ESB with adapters bridges them; later the new microservices are moved to Kafka-based event-driven integration.

## J. Cross-Topic Connections
- [Message Brokers](message-brokers.md), [Microservices](monolith-vs-microservices.md), [API Gateway](api-gateway.md).

## K. Confidence Checklist
- [ ] Knows what ESB is and its tradeoffs.

## L. Potential Gaps & Improvements
- Canonical data model anti-pattern.
- Why dumb pipes + smart endpoints won out.
