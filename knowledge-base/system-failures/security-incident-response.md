# Security Incident Response

> *"Operational incidents are about restoring service. Security incidents are about restoring service AND containing the breach AND preserving evidence AND complying with regulations AND notifying customers AND managing legal exposure. The skills are similar; the stakes and constraints are different. Teams that haven't trained for security incidents discover, during their first one, just how different."*

---

## 🎯 Start Here — Intuition

> **In one line:** what to do, in what order, when someone breaks into your systems — so you actually evict them, know what they took, and stay on the right side of the law.
>
> **Analogy:** discovering a burglar in your house. The amateur move is to yell and scare them off — but now you don't know what they took, whether they copied a key, or if they'll be back. The disciplined move is to quietly call the police, watch without tipping the burglar off, block the exits, evict them, check for hidden ways back in, and preserve evidence for court.
>
> **Assumes you already know:** the basics of incident response and recovery. Build those first in [`learn/reliability/disaster-recovery.md`](../../learn/reliability/disaster-recovery.md) and [`learn/reliability/sla-slo-sli.md`](../../learn/reliability/sla-slo-sli.md) — *then* come back for the security-specific constraints (evidence, attackers watching, disclosure law).
>
> **Level:** this file is 🟡 overall — the lifecycle is teachable to anyone, but the forensics and disclosure-law sections are 🔴 senior territory. If a section feels heavy, that tag is your signal to slow down — **you are not behind.**

---

## Topic Overview 🟢

A security incident is a confirmed or suspected compromise: an account takeover, a data breach, a malware infection, a leaked secret, an unauthorized access event. The response combines the operational discipline of incident response with the additional constraints of security: evidence preservation, attacker awareness, regulatory notification, legal coordination.

The framework is well-established (NIST 800-61, SANS, vendor playbooks): **Preparation → Detection → Containment → Eradication → Recovery → Lessons Learned**. Each phase has specific work different from operational incidents. Containment, in particular, is about *cutting off the attacker* without tipping them off; recovery is about ensuring you've actually evicted them, not just kicked them out the front door while they remain through a back one.

This is the topic where engineering meets security meets law meets PR. Teams that handle security incidents well have rehearsed the choreography. Teams that haven't make mistakes that compound: they alert the attacker; they destroy evidence; they violate disclosure timelines; they reassure customers prematurely. The cost of getting this wrong is regulatory action, customer churn, and brand damage that lasts years.

---

## Intuition Before Definitions 🟢

Imagine discovering a burglar in your house.

**Operational instinct**: yell, scare them off, lock the doors. The burglar leaves; problem solved? No — you don't know what they took, where they went, whether they have a key, whether they'll be back. The "incident" looks resolved but isn't.

**Security incident response**: silently call the police. They arrive carefully (without alerting the burglar). They observe what's stolen, what's touched, what evidence exists. They contain (block exits) before announcing themselves. They evict the burglar. They check for hidden ways back in (was a window unlocked? a key copied?). They preserve evidence for prosecution. You change your locks, your security system, your habits.

That's security incident response. The work isn't done when the immediate threat seems gone. The work is done when you're sure they're gone, you know what was taken, you've fixed the holes, and you've recorded what happened. Each step has its own discipline.

---

## Historical Evolution 🟢

**Era 1 — Ad-hoc response.**
1990s, 2000s. Most companies had no formal security incident process. IT handled it; sometimes well, often badly.

**Era 2 — Formal frameworks.**
~2008. NIST 800-61, SANS frameworks. Formal phases; documented practices.

**Era 3 — Disclosure regulations.**
2010s. State breach notification laws; HIPAA; GDPR (2018). Legal requirements drove formal processes.

**Era 4 — DFIR (Digital Forensics & Incident Response).**
Specialized field. Tools (EnCase, Volatility); methodology; training programs.

**Era 5 — Detection-driven response.**
2015+. SIEM, EDR, XDR systems. Detection improves; response time shrinks.

**Era 6 — Industrialized response.**
Today. Specialized teams (SOC, CSIRT). Tabletop exercises. Vendor partnerships. Cyber insurance.

The pattern: each generation formalized response. The methodology is well-documented; many companies still don't practice it.

---

## Deep Technical Explanation 🔴

⚠️ The rest assumes the basics above are solid.

### The phases

**Preparation.** Before anything happens. Tools, runbooks, training, contacts.

**Detection.** Recognizing an incident occurred. Often the slowest phase; many breaches go undetected for months.

**Containment.** Preventing further damage. Short-term: block the immediate access. Long-term: prepare a sustainable cut-off.

**Eradication.** Removing the threat. Patching the vulnerability; wiping infected systems; rotating credentials.

**Recovery.** Restoring services. Verifying the threat is gone before going back online.

**Lessons learned.** Postmortem. What happened; what improved; what's left.

### Detection sources

Where security incidents are caught:
- **SIEM/SOC alerts**: log analysis flagging anomalies.
- **EDR (Endpoint Detection and Response)**: laptop/server-level threat detection.
- **External notification**: customer, security researcher, law enforcement.
- **Bug bounty reports**: security researchers reporting vulnerabilities.
- **Outage causes**: investigation of an outage reveals it was malicious.

The first three are detected internally; the last three are external.

The Verizon DBIR consistently shows: many breaches are detected externally, not by the victim. Investing in detection capability is a major maturity step.

### Containment

Short-term containment: stop the bleeding immediately.
- Block the attacker's IP at the firewall.
- Disable compromised accounts.
- Take affected systems offline.
- Rotate exposed credentials.

Long-term containment: prepare for sustained cut-off.
- Patch the entry vulnerability.
- Rebuild compromised systems.
- Implement MFA where missing.
- Network segmentation.

The risk: containing too aggressively tips the attacker off; they may pivot, escalate, or destroy evidence. Containing too slowly: more damage.

### Evidence preservation

Before changes are made, preserve:
- Memory dumps of affected systems (volatile).
- Disk images.
- Network packet captures.
- Logs (system, application, security).
- Authentication records.

Chain of custody: who handled the evidence; what they did. Critical for legal use.

Tools: forensic disk imagers; memory acquisition tools (Volatility, Rekall); log preservation.

A common mistake: rebuild the affected system before preserving evidence. The attacker's traces are gone; the investigation is much harder.

### Eradication

Vulnerability patching:
- Fix the entry vector (often the original vulnerability).
- Patch all systems with the same vulnerability.
- Audit for similar vulnerabilities.

Credential rotation:
- All credentials potentially compromised.
- Service accounts; user accounts; API keys; certificates.
- Often overlooked: credentials embedded in code, in configs.

System rebuild:
- Compromised systems wiped and reinstalled.
- Don't trust "I cleaned the malware"; rebuild from known-good.

Persistence mechanisms:
- Attackers establish multiple footholds (backdoor accounts, scheduled tasks, modified binaries, cloud IAM roles).
- Eradication must find and remove all.

### Recovery

Verification:
- Threat actor is no longer present.
- Vulnerability is patched.
- Monitoring is enhanced to catch return.
- Services restored to known-good state.

Phased restoration:
- Restore critical services first.
- Monitor intensely for re-compromise.
- Gradually expand.

### Communication during incidents

**Internal**: dedicated secure channel (not email if email is compromised). Need-to-know basis. Document everything.

**External**: customer notifications. Regulatory disclosure. Public statements (sometimes via legal).

**To attackers (indirectly)**: in incident response, public statements may telegraph what you've discovered. PR is timed carefully.

### Disclosure

**Customers**: depends on jurisdiction; sometimes within hours.
- GDPR: 72 hours to data protection authority.
- HIPAA: 60 days to affected individuals.
- State laws: vary; often within days.

**Regulators**: SEC (4 business days), state AGs, sector-specific.

**Law enforcement**: often optional; sometimes mandatory; may slow notification timelines.

**Public**: depends on materiality. Public companies must disclose material breaches.

### Common attack patterns

**Phishing → credential theft.** Most common entry point. User enters credentials in fake login.

**Supply chain compromise.** Attacker compromises a dependency; victim ingests it. SolarWinds, log4shell.

**Misconfigured cloud.** Public S3 buckets, exposed databases. Many breaches.

**Insider threat.** Disgruntled employee or contractor.

**Ransomware.** Encryption + extortion. Mature response capability needed.

**Zero-day exploitation.** Rare but devastating; specialized actors.

Each has different response patterns. Generic IR plus pattern-specific runbooks.

### Forensics

Investigating *how* the breach happened:
- Timeline reconstruction.
- Indicators of compromise (IOCs).
- Attribution (sometimes).
- Lateral movement traces.
- Data exfiltration evidence.

Tools: Volatility (memory), Velociraptor (live forensics), commercial DFIR platforms.

Output: a clear story of "they entered here, did this, took this." Used for postmortem, legal, regulatory disclosure.

### Tabletop exercises

Simulated incident response. Walk through scenarios verbally:
- "We've detected unusual activity in the prod database."
- Each role describes what they do.
- Facilitator injects new information ("legal asks if we should notify customers").
- Identify gaps.

Frequency: quarterly to annually. Cheap; valuable.

### Cyber insurance

Most large companies have cyber insurance. Covers incident response costs, ransomware, regulatory fines, business interruption. Affects response: insurer must be notified; certain vendors must be used.

### Coordinated vulnerability disclosure

When you find a vulnerability in someone else's product:
- Report to vendor.
- Allow time for fix.
- Coordinate disclosure date.
- CVE assignment.

Different from an incident affecting your own systems.

---

## Real Engineering Analogies 🟢

**The hospital infection control.**
A hospital with an infectious disease outbreak: identify (test); isolate (quarantine); trace (who else was exposed); decontaminate (clean rooms); notify (public health authorities). Same phases, different domain.

**The bank robbery investigation.**
After a robbery: secure the scene; preserve evidence; interview witnesses; investigate; prevent recurrence. Don't reopen the bank until the security holes are fixed and you're sure the robbers aren't still inside.

---

## Production Engineering Perspective 🟡

What goes wrong:

- **The "we had backups" ransomware.** Backups in same network; encrypted too. Recovery from older off-site backups; significant data loss. Lesson: air-gapped, immutable backups.
- **The premature reassurance.** PR announced "the breach is contained" before forensics confirmed. Attackers still inside; second wave; embarrassment compounds. Lesson: PR follows containment, not assumption of containment.
- **The wiped evidence.** IT rebuilt compromised systems before forensics imaged. Investigation hampered; questions about scope unanswerable. Lesson: preserve before rebuild.
- **The disclosure timeline miss.** Discovered breach Tuesday; notified DPA Friday (96 hours). GDPR violation; fine in addition to breach. Lesson: 72-hour clock starts on awareness.
- **The credential rotation gap.** Rotated user passwords; forgot service accounts. Attacker maintains access via service account. Mitigation: comprehensive rotation including service identities.
- **The unmonitored persistence.** Attacker created scheduled task. Eradication missed it. Two weeks later, re-compromise from the task. Lesson: thorough persistence search.
- **The communication leak.** Discussion of incident in Slack channel that included a compromised account. Attacker reads response plans; pivots accordingly. Mitigation: out-of-band secure communication.

The senior security engineer's habits:
- **Tabletop exercises** quarterly.
- **Documented runbooks** for common scenarios.
- **Out-of-band communication** ready.
- **Forensics tooling** maintained and trained.
- **Disclosure templates** prepared.
- **Vendor relationships** (DFIR, legal, PR) established.
- **Cyber insurance** in place; understood.

---

## Failure Scenarios 🟡

**Scenario 1 — The early reveal.**
Detection occurred at 3am. Engineering started fixing immediately; visible to monitoring. Attacker noticed; pivoted; entrenched further. Recovery took 3× longer. Mitigation: coordinated, not ad-hoc, response.

**Scenario 2 — The disclosure miss.**
Discovered breach Sunday. Tried to investigate first. Disclosed Friday. GDPR violation = €€€ on top of breach cost. Lesson: clock starts at awareness.

**Scenario 3 — The supply chain unawareness.**
Vendor compromised; victim systems compromised via vendor's update. Detection: weeks late. Lesson: monitor third-party access; threat-model dependencies.

**Scenario 4 — The phishing-then-pivot.**
Employee phished; credentials taken. Attacker MFA-bypassed; pivoted to cloud; staged data exfil. Detection: cloud activity anomaly; weeks after initial compromise. Lesson: phishing-resistant MFA; detection at multiple layers.

**Scenario 5 — The ransomware nightmare.**
Ransomware encrypted production. Backups: same network; also encrypted. Recovery: 3-week-old off-site backup. Massive data loss. Lesson: air-gapped backups.

---

## Performance Perspective 🟡

- **Detection latency**: ideally minutes; reality often days/weeks.
- **Containment time**: hours to days for sophisticated attacks.
- **Eradication time**: days to weeks.
- **Recovery time**: depends on damage scope.
- **Total incident lifecycle**: weeks for major incidents.

---

## Scaling Perspective 🟡

- **Small companies**: outsource to MSSP; have IR retainer.
- **Medium**: dedicated security team; SOC.
- **Large**: 24x7 SOC; specialized IR teams; threat intelligence.
- **At hyperscale**: extensive infrastructure; security as a competence.

---

## Cross-Domain Connections 🟡

- **Postmortems**: security incidents end with a postmortem. (See [postmortems-and-incident-response.md](./postmortems-and-incident-response.md).)
- **Disaster recovery**: backups for ransomware. (See [disaster-recovery-and-rto-rpo.md](./disaster-recovery-and-rto-rpo.md).)
- **Observability**: detection depends on it. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)
- **API design**: most attacks target APIs; secure by design. (See [api-design-rest-vs-grpc.md](../architecture-patterns/api-design-rest-vs-grpc.md).)
- **Multi-tenancy**: tenant isolation matters for breach scope. (See [multi-tenancy-strategies.md](../scalability/multi-tenancy-strategies.md).)

The unifying observation: **security incidents are operational incidents with additional constraints — evidence, regulation, attacker awareness, communication discipline. Teams that prepare specifically for security incidents handle them; teams that don't make compounding mistakes.**

---

## Real Production Scenarios 🟡

- **The Equifax breach (2017)**: extensively documented; case study in poor IR.
- **SolarWinds (2020)**: supply chain compromise; far-reaching.
- **Colonial Pipeline (2021)**: ransomware; payment.
- **Twitter (2020)**: insider threat; high-profile compromise.
- **Many ransomware case studies**: documented response patterns.

---

## Key Takeaways

- **IR lifecycle**: Preparation → Detection → Containment → Eradication → Recovery → Lessons Learned. Each phase has security-specific work distinct from operational incidents.
- **Security incidents are operational incidents in a hostile environment**: the attacker is intelligent, the timeline is regulatory, the evidence is fragile, and the consequences span legal, brand, and customer trust.
- **The attacker may be watching** — monitor your monitoring, and don't tip them off until containment is ready.
- **Containment ≠ eradication.** Cutting off access (stop the bleeding) is not the same as removing the threat; attackers maintain multiple footholds.
- **Preserve evidence before remediation.** Wiping/rebuilding before forensics image the system destroys the investigation.
- **Disclosure timelines are legal obligations**: GDPR 72 hours (clock starts on awareness), SEC 4 business days, HIPAA 60 days, state laws vary. Missing them adds fines on top of the breach.
- **Service accounts need rotation too** — rotating user passwords while forgetting service accounts, API keys, and embedded credentials leaves the attacker in.
- **Use out-of-band, secure communication** during incidents (not email/Slack if those may be compromised).
- **Air-gapped, immutable backups** are essential for ransomware recovery; backups on the same network get encrypted too.
- **Tabletop exercises** (quarterly) are real, cheap preparation; documented runbooks and established vendor relationships (DFIR, legal, PR) matter.
- **Cyber insurance** is now standard and shapes response (insurer notification, mandated vendors).
- **Forensics matter** for reconstructing scope — "they entered here, did this, took this" — used for postmortem, legal, and disclosure.

## Interview angle

- **"What's the IR lifecycle?"** — Prep → Detect → Contain → Eradicate → Recover → Learn.
- **"What's containment?"** — Stop the bleeding without tipping off the attacker.
- **"What's evidence preservation?"** — Capture before remediation.
- **"What's a tabletop exercise?"** — Simulated, walked-through incident response.
- **"GDPR notification timeline?"** — 72 hours.
- **"How do you handle ransomware?"** — Tests practical knowledge of containment, air-gapped backups, and recovery.
- **Common traps**: treating security incidents as operational ones; believing immediate containment is enough.
