# Security Incident Response

> *"Operational incidents are about restoring service. Security incidents are about restoring service AND containing the breach AND preserving evidence AND complying with regulations AND notifying customers AND managing legal exposure. The skills are similar; the stakes and constraints are different. Teams that haven't trained for security incidents discover, during their first one, just how different."*

---

## Topic Overview

A security incident is a confirmed or suspected compromise: an account takeover, a data breach, a malware infection, a leaked secret, an unauthorized access event. The response combines the operational discipline of incident response with the additional constraints of security: evidence preservation, attacker awareness, regulatory notification, legal coordination.

The framework is well-established (NIST 800-61, SANS, vendor playbooks): **Preparation → Detection → Containment → Eradication → Recovery → Lessons Learned**. Each phase has specific work different from operational incidents. Containment, in particular, is about *cutting off the attacker* without tipping them off; recovery is about ensuring you've actually evicted them, not just kicked them out the front door while they remain through a back one.

This is the topic where engineering meets security meets law meets PR. Teams that handle security incidents well have rehearsed the choreography. Teams that haven't make mistakes that compound: they alert the attacker; they destroy evidence; they violate disclosure timelines; they reassure customers prematurely. The cost of getting this wrong is regulatory action, customer churn, and brand damage that lasts years.

---

## Intuition Before Definitions

Imagine discovering a burglar in your house.

**Operational instinct**: yell, scare them off, lock the doors. The burglar leaves; problem solved? No — you don't know what they took, where they went, whether they have a key, whether they'll be back. The "incident" looks resolved but isn't.

**Security incident response**: silently call the police. They arrive carefully (without alerting the burglar). They observe what's stolen, what's touched, what evidence exists. They contain (block exits) before announcing themselves. They evict the burglar. They check for hidden ways back in (was a window unlocked? a key copied?). They preserve evidence for prosecution. You change your locks, your security system, your habits.

That's security incident response. The work isn't done when the immediate threat seems gone. The work is done when you're sure they're gone, you know what was taken, you've fixed the holes, and you've recorded what happened. Each step has its own discipline.

---

## Historical Evolution

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

## Core Mental Models

**1. Security incidents have phases distinct from operational incidents.**
Detection → Containment → Eradication → Recovery → Lessons Learned. Each has security-specific work.

**2. The attacker may be watching.**
Monitor your monitoring. Communicate via secure channels. Don't tip them off until containment is ready.

**3. Evidence matters.**
For forensics, for legal, for understanding what happened. Don't wipe before preserving.

**4. Containment ≠ eradication.**
Cutting off access ≠ removing the threat. The attacker may have multiple footholds.

**5. Disclosure has timelines.**
GDPR: 72 hours. SEC: 4 days. State laws vary. Missing these has regulatory consequences.

---

## Deep Technical Explanation

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

## Real Engineering Analogies

**The hospital infection control.**
A hospital with an infectious disease outbreak: identify (test); isolate (quarantine); trace (who else was exposed); decontaminate (clean rooms); notify (public health authorities). Same phases, different domain.

**The bank robbery investigation.**
After a robbery: secure the scene; preserve evidence; interview witnesses; investigate; prevent recurrence. Don't reopen the bank until the security holes are fixed and you're sure the robbers aren't still inside.

---

## Production Engineering Perspective

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

## Failure Scenarios

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

## Performance Perspective

- **Detection latency**: ideally minutes; reality often days/weeks.
- **Containment time**: hours to days for sophisticated attacks.
- **Eradication time**: days to weeks.
- **Recovery time**: depends on damage scope.
- **Total incident lifecycle**: weeks for major incidents.

---

## Scaling Perspective

- **Small companies**: outsource to MSSP; have IR retainer.
- **Medium**: dedicated security team; SOC.
- **Large**: 24x7 SOC; specialized IR teams; threat intelligence.
- **At hyperscale**: extensive infrastructure; security as a competence.

---

## Cross-Domain Connections

- **Postmortems**: security incidents end with a postmortem. (See [postmortems-and-incident-response.md](./postmortems-and-incident-response.md).)
- **Disaster recovery**: backups for ransomware. (See [disaster-recovery-and-rto-rpo.md](./disaster-recovery-and-rto-rpo.md).)
- **Observability**: detection depends on it. (See [metrics-logs-traces.md](../observability/metrics-logs-traces.md).)
- **API design**: most attacks target APIs; secure by design. (See [api-design-rest-vs-grpc.md](../architecture-patterns/api-design-rest-vs-grpc.md).)
- **Multi-tenancy**: tenant isolation matters for breach scope. (See [multi-tenancy-strategies.md](../scalability/multi-tenancy-strategies.md).)

The unifying observation: **security incidents are operational incidents with additional constraints — evidence, regulation, attacker awareness, communication discipline. Teams that prepare specifically for security incidents handle them; teams that don't make compounding mistakes.**

---

## Real Production Scenarios

- **The Equifax breach (2017)**: extensively documented; case study in poor IR.
- **SolarWinds (2020)**: supply chain compromise; far-reaching.
- **Colonial Pipeline (2021)**: ransomware; payment.
- **Twitter (2020)**: insider threat; high-profile compromise.
- **Many ransomware case studies**: documented response patterns.

---

## What Junior Engineers Usually Miss

- That **disclosure timelines are legal**.
- That **evidence must be preserved**.
- That **attackers may be watching**.
- That **containment ≠ eradication**.
- That **service accounts need rotation too**.
- That **air-gapped backups** matter.
- That **tabletop exercises** are real preparation.

---

## What Senior Engineers Instinctively Notice

- They **practice tabletop exercises**.
- They **maintain incident runbooks**.
- They **preserve evidence** before remediation.
- They **track disclosure timelines**.
- They **use out-of-band communication**.
- They **have established vendor relationships**.
- They **understand cyber insurance** terms.

---

## Interview Perspective

What gets tested:

1. **"What's the IR lifecycle?"** Tests fundamental.
2. **"What's containment?"** Stop the bleeding without tipping off.
3. **"What's evidence preservation?"** Before remediation.
4. **"What's a tabletop exercise?"** Simulated response.
5. **"GDPR notification timeline?"** 72 hours.
6. **"How do you handle ransomware?"** Tests practical knowledge.

Common traps:
- Treating security incidents as operational ones.
- Believing immediate containment is enough.

---

## 20% Knowledge Giving 80% Understanding

1. **IR phases**: Prep → Detect → Contain → Eradicate → Recover → Learn.
2. **Preserve evidence** before remediation.
3. **Containment ≠ eradication.**
4. **Disclosure timelines are legal**: 72h GDPR.
5. **Out-of-band communication** during incidents.
6. **Air-gapped backups** for ransomware.
7. **Service accounts** need rotation too.
8. **Tabletop exercises** prepare teams.
9. **Cyber insurance** is now standard.
10. **Forensics matter** for understanding scope.

---

## Final Mental Model

> **Security incidents are operational incidents in a hostile environment. The attacker is intelligent; the timeline is regulatory; the evidence is fragile; the consequences span legal, brand, and customer trust. The teams that handle them well have rehearsed; the teams that haven't make mistakes that compound. The cost of preparation is small relative to the cost of unpreparedness.**

The senior security-aware engineer treats IR as a discipline alongside operational IR. Rehearse. Document runbooks. Preserve evidence. Communicate carefully. Disclose on schedule. Verify eradication before recovery.

The teams that survive their first major security incident gracefully are the ones who prepared. The teams that bumble through learn lessons painfully. The framework is well-established; following it is the difference between an incident and a catastrophe.

That's security incident response. That's the discipline that handles the days you hope never come — and the practice that determines whether your company's first major breach is a footnote or a defining event.
