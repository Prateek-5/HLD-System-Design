# Acronyms by Domain

> Quick reference of acronyms grouped by where they show up in the corpus. Use when you encounter an acronym and want to know which world it belongs to. For full definitions, see [GLOSSARY.md](GLOSSARY.md).

---

## Database Internals

| Acronym | Expansion | One-liner |
|---|---|---|
| ACID | Atomicity, Consistency, Isolation, Durability | The four classic transaction guarantees |
| AOF | Append-Only File | Redis's WAL-style persistence |
| ARIES | Algorithm for Recovery and Isolation Exploiting Semantics | The 1992 paper that defined modern recovery |
| BRIN | Block Range Index | Postgres index for sequentially-correlated data |
| CDC | Change Data Capture | Stream of database changes to consumers |
| CRDT | Conflict-free Replicated Data Type | Inherently mergeable data structure |
| DBA | Database Administrator | Operator role |
| DDL | Data Definition Language | CREATE, ALTER, DROP |
| DML | Data Manipulation Language | INSERT, UPDATE, DELETE |
| DTC | Distributed Transaction Coordinator | Microsoft's XA implementation |
| ETL / ELT | Extract Transform Load / Extract Load Transform | Data pipeline patterns |
| GIN | Generalized Inverted Index | Postgres index for arrays, JSONB, full-text |
| GiST | Generalized Search Tree | Postgres index for custom types |
| HOT | Heap-Only Tuple | Postgres optimization for index-not-touched updates |
| HTAP | Hybrid Transactional-Analytical Processing | Single system serving both |
| LSM | Log-Structured Merge | Write-optimized storage tree |
| LWW | Last Write Wins | Conflict resolution by timestamp |
| MVCC | Multi-Version Concurrency Control | Versions instead of read locks |
| OLAP | Online Analytical Processing | Aggregation-heavy workloads |
| OLTP | Online Transactional Processing | Many small transactions |
| ORM | Object-Relational Mapping | Application-DB abstraction |
| PITR | Point-In-Time Recovery | Restore database to specific moment |
| PV / PVC | PersistentVolume / PersistentVolumeClaim | Kubernetes storage |
| SOA | Start of Authority | DNS metadata record |
| SOA | Service-Oriented Architecture | Pre-microservices architecture style |
| SSI | Serializable Snapshot Isolation | Postgres's serializable implementation |
| TPS | Transactions Per Second | Throughput metric |
| TSDB | Time-Series Database | Specialized DB for timestamped data |
| TTL | Time To Live | Cache or row expiration duration |
| TTW | Time To Wraparound | Postgres txid-wraparound countdown |
| WAL | Write-Ahead Log | Append-only log of intentions |
| XA | X/Open distributed transaction | Standard for cross-resource transactions |

## Distributed Systems

| Acronym | Expansion | One-liner |
|---|---|---|
| 2PC / 3PC | Two- / Three-Phase Commit | Classical distributed-transaction protocols |
| BFT | Byzantine Fault Tolerance | Consensus tolerating malicious nodes |
| CAP | Consistency, Availability, Partition tolerance | The trilemma |
| CRDT | Conflict-free Replicated Data Type | Mergeable distributed state |
| FLP | Fischer-Lynch-Paterson | The consensus impossibility result |
| HLC | Hybrid Logical Clock | Physical time + logical counter |
| ISR | In-Sync Replica | Kafka follower caught up to leader |
| MSL | Maximum Segment Lifetime | TCP packet expiration bound |
| MTBF | Mean Time Between Failures | Reliability metric |
| MTTR / MTTD | Mean Time To Recovery / Detection | Incident metrics |
| NTP | Network Time Protocol | Clock synchronization |
| PACELC | Partition: AC; Else: LC | Refinement of CAP |
| QPS | Queries Per Second | Read throughput |
| RPC | Remote Procedure Call | Method-call abstraction over network |
| SWIM | Scalable Weakly-consistent Infection-style Membership | Gossip + failure detection |
| TPS | Transactions Per Second | Write throughput |

## Concurrency

| Acronym | Expansion | One-liner |
|---|---|---|
| AIO | Asynchronous I/O | Non-blocking I/O syscalls |
| ARC | Automatic Reference Counting | Swift's memory management |
| BEAM | Erlang's VM | Bogdan's Erlang Abstract Machine |
| CAS | Compare-And-Swap | Foundational atomic instruction |
| CSP | Communicating Sequential Processes | Channel-based concurrency model (Hoare) |
| GIL | Global Interpreter Lock | Python's bytecode serialization |
| GVL | Global VM Lock | Ruby's equivalent |
| HOT | Hot path / hot code | Frequently-executed code |
| JIT | Just-In-Time compilation | Compile bytecode to native at runtime |
| JFR | Java Flight Recorder | JVM profiling and event recording |
| JMC | Java Mission Control | JFR analysis tool |
| JNI | Java Native Interface | Java-to-native FFI |
| MESI | Modified, Exclusive, Shared, Invalid | Cache coherence protocol states |
| NUMA | Non-Uniform Memory Access | Multi-socket memory architecture |
| RCU | Read-Copy-Update | Linux kernel's lock-free read pattern |
| SIMD | Single Instruction Multiple Data | Vector instructions |
| TLAB | Thread-Local Allocation Buffer | Per-thread allocation region |
| TLS | Thread-Local Storage | Per-thread variables (also Transport Layer Security; context matters) |
| VM | Virtual Machine | Language runtime (also virtual machine in OS sense) |

## JS Runtime

| Acronym | Expansion | One-liner |
|---|---|---|
| AOT | Ahead-Of-Time compilation | Compile before execution (vs JIT) |
| AST | Abstract Syntax Tree | Parsed code structure |
| C1 / C2 | Client / Server compiler tier | HotSpot JIT tiers |
| CMS | Concurrent Mark-Sweep | Deprecated JVM GC |
| CPython | C-based Python | Reference Python implementation |
| CRX | (V8) Crankshaft | Earlier V8 JIT (pre-TurboFan) |
| DOM | Document Object Model | Browser document tree |
| EOL | End of life | Deprecated runtime version |
| ES / ESM | ECMAScript / ES Modules | JavaScript standard |
| FFI | Foreign Function Interface | Calling native code |
| FFM | Foreign Function & Memory API | Java's modern FFI |
| G1 | Garbage First | Default JVM GC since Java 9 |
| GC | Garbage Collection | Automatic memory reclamation |
| HTOP | (heap of TurboFan) — informal | Top tier of V8 compiler |
| JS / JSON | JavaScript / JS Object Notation | Language / data format |
| JVM | Java Virtual Machine | The Java runtime |
| LTS | Long Term Support | Stable runtime version |
| MGV | Maglev | V8's mid-tier compiler |
| OOM | Out Of Memory | Heap exhaustion |
| PGO | Profile-Guided Optimization | Optimize from runtime data |
| TF | TurboFan | V8's top-tier compiler |
| ZGC | Z Garbage Collector | Sub-ms-pause JVM GC |

## Networking

| Acronym | Expansion | One-liner |
|---|---|---|
| ACK / SYN / FIN / RST | TCP control flags | Acknowledge / Synchronize / Finish / Reset |
| ALPN | Application-Layer Protocol Negotiation | TLS extension for protocol selection |
| BGP | Border Gateway Protocol | Internet routing |
| CA | Certificate Authority | TLS trust anchor |
| CDN | Content Delivery Network | Edge caching network |
| CIDR | Classless Inter-Domain Routing | IP subnet notation |
| CN | Common Name | TLS certificate field |
| COOP / COEP | Cross-Origin Opener/Embedder Policy | Browser isolation headers |
| CRL | Certificate Revocation List | Revoked TLS certs |
| CSR | Certificate Signing Request | Cert request to CA |
| CT | Certificate Transparency | Public log of issued certs |
| DDoS | Distributed Denial of Service | Attack pattern |
| DH / DHE / ECDHE | Diffie-Hellman / Ephemeral / Elliptic Curve E. | TLS key exchange |
| DNS | Domain Name System | Name-to-IP resolution |
| DNSSEC | DNS Security Extensions | Cryptographic DNS signing |
| DoH / DoT | DNS over HTTPS / TLS | Encrypted DNS |
| ECN | Explicit Congestion Notification | TCP congestion signal |
| FQDN | Fully Qualified Domain Name | Complete DNS name |
| GSLB | Global Server Load Balancing | Geographic LB |
| HSTS | HTTP Strict Transport Security | Force HTTPS |
| HTTP / HTTPS | HyperText Transfer Protocol / Secure | Web protocol / TLS-secured |
| ICE | Interactive Connectivity Establishment | WebRTC NAT traversal |
| IPv4 / IPv6 | Internet Protocol v4/v6 | Network layer addressing |
| IOCP | I/O Completion Ports | Windows async I/O |
| L4 / L7 | Layer 4 / Layer 7 | OSI: transport / application |
| MITM | Man In The Middle | Attack pattern |
| MTU | Maximum Transmission Unit | Largest packet size |
| NAT | Network Address Translation | Private-public IP mapping |
| OCSP | Online Certificate Status Protocol | Cert status check |
| PMTUD | Path MTU Discovery | Find smallest MTU on path |
| PoP | Point of Presence | CDN edge location |
| QPACK | QUIC's HPACK variant | HTTP/3 header compression |
| QUIC | (informally Quick UDP Internet Connections) | UDP-based reliable transport |
| RFC | Request For Comments | Internet standards documents |
| RTT | Round-Trip Time | Network latency |
| SACK | Selective Acknowledgment | TCP option |
| SAN | Subject Alternative Name | TLS cert field |
| SCTP | Stream Control Transmission Protocol | WebRTC data |
| SNI | Server Name Indication | TLS extension for hostname |
| SSE | Server-Sent Events | One-way HTTP stream |
| STUN / TURN | Session Traversal Utilities for NAT | WebRTC NAT helpers |
| TCP / UDP | Transmission Control / User Datagram Protocol | Reliable / unreliable transport |
| TLS / mTLS | Transport Layer Security / Mutual | Encryption / both-ends auth |
| TTL | Time To Live | DNS / IP packet lifetime |
| URL / URI | Uniform Resource Locator / Identifier | Web address |
| WAF | Web Application Firewall | Layer-7 security |
| WS / WSS | WebSocket / Secure | Persistent bidir / TLS-secured |

## Observability

| Acronym | Expansion | One-liner |
|---|---|---|
| APM | Application Performance Monitoring | Commercial observability tools |
| EWMA | Exponentially Weighted Moving Average | Adaptive metrics |
| OTel | OpenTelemetry | Vendor-neutral instrumentation |
| RED | Rate, Errors, Duration | Per-service observability |
| SIEM | Security Information and Event Management | Security log aggregation |
| SLI / SLO / SLA | Service Level Indicator / Objective / Agreement | Reliability framework |
| SOC | Security Operations Center | 24x7 security team |
| SRE | Site Reliability Engineer | Operations role/discipline |
| TSDB | Time-Series Database | Metrics backend |
| USE | Utilization, Saturation, Errors | Resource observability |
| W3C | World Wide Web Consortium | Standards body (Trace Context) |
| XDR | Extended Detection and Response | Modern security platform |

## Scalability

| Acronym | Expansion | One-liner |
|---|---|---|
| AZ | Availability Zone | Cloud failure domain |
| ANN | Approximate Nearest Neighbor | Vector-search algorithm class |
| AS | Auto-Scaling group | Cloud scaling resource |
| CDN | Content Delivery Network | Edge caching network |
| CRD | Custom Resource Definition | Kubernetes extension |
| DR | Disaster Recovery | Catastrophic-failure planning |
| HNSW | Hierarchical Navigable Small World | Vector ANN graph |
| HPA | Horizontal Pod Autoscaler | Kubernetes scaling |
| K8s | Kubernetes | Container orchestrator |
| LB | Load Balancer | Distribution service |
| MPP | Massively Parallel Processing | Distributed analytics |
| P2C | Power of Two Choices | Load-balancing algorithm |
| PoP | Point of Presence | CDN edge location |
| RPS | Requests Per Second | Throughput metric |
| RTO / RPO | Recovery Time / Point Objective | DR targets |
| SaaS | Software as a Service | B2B software model |
| SLA | Service Level Agreement | Customer-facing uptime contract |
| SoA | Structure of Arrays | Cache-friendly layout |
| TPS | Transactions Per Second | Throughput metric |

## System Failures / Operations

| Acronym | Expansion | One-liner |
|---|---|---|
| ATC | Air Traffic Control | Common analogy for incident command |
| BCP | Business Continuity Plan | DR + organizational continuity |
| CSIRT | Computer Security Incident Response Team | Security IR team |
| DFIR | Digital Forensics & Incident Response | Security investigation discipline |
| DLQ | Dead-Letter Queue | Quarantine for failed messages |
| GDPR / HIPAA / PCI | Compliance regimes | EU data protection / health / payment-card |
| ICS | Incident Command System | Borrowed from emergency response |
| IR | Incident Response | Operational discipline |
| ITSM | IT Service Management | Operational framework (ITIL) |
| LB | Load Balancer | Routing infrastructure |
| MTTR | Mean Time To Recovery | Reliability metric |
| MoCK | Mean Time To Detect (similar) | Various variants |
| OCAP | Operational Capability | Org-readiness measure |
| PII | Personally Identifiable Information | Regulatory data category |
| PR | Pull Request | Code-review workflow |
| RTO / RPO | Recovery Time / Point Objective | DR targets |
| SOC2 | Service Org Controls 2 | Compliance audit framework |

## Architecture Patterns

| Acronym | Expansion | One-liner |
|---|---|---|
| ACL | Anti-Corruption Layer | DDD context-translation |
| ACL | Access Control List | Permission system (different ACL) |
| API | Application Programming Interface | Service contract |
| BFF | Backend For Frontend | Per-client API layer |
| CDC | Change Data Capture | DB change stream |
| CQRS | Command Query Responsibility Segregation | Separate read/write models |
| DDD | Domain-Driven Design | Eric Evans's modeling discipline |
| DTO | Data Transfer Object | Wire-shaped object |
| EDA | Event-Driven Architecture | Async fact-based design |
| ES | Event Sourcing | State as fold over events |
| FaaS | Function as a Service | Serverless functions |
| gRPC | (informally) Google RPC | HTTP/2 + protobuf RPC |
| HATEOAS | Hypermedia as Engine of App State | REST principle (rarely practiced) |
| IDL | Interface Definition Language | Schema for RPCs (proto, etc.) |
| LLM | Large Language Model | AI model class |
| MQ | Message Queue | Async messaging primitive |
| OWASP | Open Web Application Security Project | Web security org |
| RAG | Retrieval-Augmented Generation | Vector retrieval + LLM |
| REST | Representational State Transfer | HTTP-based API style |
| RPC | Remote Procedure Call | Method-call abstraction |
| SOAP | Simple Object Access Protocol | XML-based RPC (legacy) |
| URI / URL | Uniform Resource Identifier / Locator | Resource address |

---

## Note on Overloaded Acronyms

Some acronyms mean different things in different contexts. Watch out for:

- **ACL** = Access Control List vs. Anti-Corruption Layer (DDD).
- **TLS** = Transport Layer Security vs. Thread-Local Storage.
- **VM** = Virtual Machine (OS) vs. Virtual Machine (language runtime, like JVM).
- **CDN** = Content Delivery Network (the usual) vs. occasional "content distribution network."
- **CDC** = Change Data Capture (databases) vs. Centers for Disease Control (analogy in chaos engineering content).
- **TLS** in networking is encryption; **TLS** in concurrency is per-thread storage.
- **JIT** = Just-In-Time compilation in runtime contexts; sometimes "just in time" colloquially.
- **RPO** = Recovery Point Objective vs. (rarely) Resource Provider Object.

The corpus uses each term in context. When in doubt, search the corpus or check the [GLOSSARY.md](GLOSSARY.md).
