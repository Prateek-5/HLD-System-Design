# 🔍 Audit — `system-failures/`
**Reviewed:** 7 files (~3080 lines) · **Lens:** brutal-honest, held to the corpus's "senior/staff 3000+ word deep dive" claim · **Avg score: 4.0/5**

## Verdict in one line
The two flagship files (cascading failures, timeouts/retries/idempotency) are genuinely excellent staff-level material with correct, deep, well-worked content; the other five are accurate and useful but visibly thinner, bullet-heavy, and below the 3000-word bar — and one real technical inversion (CDP and RPO) plus a cross-file retry-math inconsistency need fixing.

## Per-file scores (out of 5)

| File | Score | One-liner |
|------|-------|-----------|
| `cascading-failures-and-circuit-breakers.md` | 4.7 | Best-in-corpus: correct breaker states, real phased cascade walkthrough, sharp production scenarios. |
| `timeouts-retries-and-idempotency.md` | 4.6 | Excellent; correct on exactly-once myth, deadlines vs timeouts, idempotency keys — minor retry-math looseness. |
| `chaos-engineering-and-game-days.md` | 4.2 | Accurate on hypothesis/blast-radius/game-days; thorough but the section-list format pads it. |
| `feature-flags-and-progressive-delivery.md` | 4.0 | Solid on deploy≠release, stable hashing, flag debt; canary vs blue-green correct; a bit list-heavy. |
| `postmortems-and-incident-response.md` | 3.9 | Correct on blameless/ICS/5-whys/mitigate-first; the MTTR/MTBF availability math is hand-wavy. |
| `disaster-recovery-and-rto-rpo.md` | 3.4 | RTO/RPO and DR tiers mostly right, but contains a real RPO inversion on CDP and is the shallowest deep-dive. |
| `security-incident-response.md` | 3.2 | Phases/timelines correct (GDPR 72h, SEC 4 business days) but thinnest file, ~2435 words, terse bullet lists. |

## Concrete errors found (must-fix)

🚩 **`disaster-recovery-and-rto-rpo.md` line 144 — RPO inversion (the exact swap the brief warns about).** The doc says of Continuous Data Protection: *"**Continuous (CDP).** Every change captured. Highest RPO; expensive."* This is backwards. CDP gives the **lowest** RPO (near-zero data loss). "Highest RPO" means the *most* data lost, which is the opposite of what CDP delivers. Correction: "near-zero / lowest RPO." This is a genuine technical error in a definitions section, exactly the RTO/RPO confusion class flagged.

🚩 **Cross-file retry-amplification inconsistency (27× vs 64×).** `cascading-failures-and-circuit-breakers.md` line 129 says *"Three layers of retries is 27× amplification under failure"* (3×3×3) and line 126 says *"each retries 3×, a single failure becomes 27 calls."* But `timeouts-retries-and-idempotency.md` line 78 says *"Three layers of retries (client, gateway, service mesh) compound to 64×"* and line 190/309 use *"1× × 4 × 4 × 4 = 64×."* Both are internally consistent (27 = retries-only with 3 retries; 64 = (1 attempt + 3 retries)³) but the two files use different conventions for the identical "3 retries, 3 layers" scenario without reconciling them. A reader comparing the two will be confused. Pick one convention and state it (the 4³=64 "total attempts" framing is the more honest one).

🚩 **`timeouts-retries-and-idempotency.md` line 192 — loose amplification phrasing.** *"A 1% downstream failure rate becomes a 27% load amplification with naive retries."* The "27" is conflating the 27× multiplier with a percentage; a 1% failure rate triggering 3-retry amplification does not cleanly equal "27% load amplification." The qualitative point (small failure rate → large added load) is right, but the stated number is not arithmetic. Reword to avoid implying a precise figure.

🚩 **`postmortems-and-incident-response.md` line 196 — availability math is hand-wavy and partly wrong.** *"1 hour MTTR with 1 month MTBF is ~99.86% availability."* 1h / 730h ≈ 0.137% downtime → 99.86% is roughly right, fine. But the next clause — *"Get to 5 minutes MTTR or 1 year MTBF and you're at 99.99%"* — is sloppy: 5min MTTR with 1-month MTBF is ~99.99%, but 1-year MTBF with 1-hour MTTR is also ~99.99%; presenting them as an "or" of independent levers without stating the other variable makes the claim ambiguous/misleading. State both variables when quoting an availability figure.

🚩 **No hallucinated facts found in the historical/reference sections — credit where due.** Spot-checks all hold: GDPR 72h, HIPAA 60 days, SEC 4 business days (security file lines 68, 179–180), Flickr "10+ deploys per day" 2009 (feature-flags line 40), James Governor/RedMonk coining "progressive delivery" 2018 (line 45), Hystrix 2012, Chaos Monkey ~2011, Allspaw "Blameless PostMortems" 2012, Etsy. The circuit-breaker closed/open/half-open state machine (cascading file lines 96–98) is correct. NIST 800-61 phase ordering is correct. This is a notable strength versus corpora that fabricate citations.

## Genuine strengths (keep)

- **The phased cascade walkthrough** (`cascading-failures` lines 318–441) is the single best artifact in the directory: concrete numbers (100 instances × 1000 RPS), a T+0→T+5min timeline, the health-check-collapse mechanism, and a defended-client config with explicit rationale. This is exactly the staff-level depth the corpus claims.
- **The "three outcomes: success, failure, unknown"** framing (`timeouts-retries` lines 9–11, 71) and the check-in-the-mail intuition (lines 19–41) are genuinely good teaching. The exactly-once-is-a-myth section (lines 244–251) correctly states "at-least-once + idempotent = effectively-once" and correctly characterizes Kafka EOS as effectively-once *within Kafka*.
- **Correct, non-generic distinctions** appear repeatedly: slow-is-worse-than-down (cascading line 63); deadlines propagate, timeouts don't (timeouts line 122–126, with accurate Go `context` example); canary tests the deploy vs flags test the feature (feature-flags line 147); blameless ≠ accountability-free (postmortems line 65); containment ≠ eradication, "attacker may be watching" (security lines 64, 58).
- **The Go worked example** in `timeouts-retries` (lines 452–541) is real, idiomatic, and correct — same idempotency key on every retry, deadline propagation via context, retryable-error classification, backoff+jitter.
- **Production scenarios are specific and plausible** (DNS-induced cascade, shared-pool analytical query, kill-switch-with-propagation-delay, service-account rotation gap) rather than vague.

## Redundancy assessment
Every file carries the same five-section tail: "What Junior Engineers Usually Miss," "What Senior Engineers Instinctively Notice," "20% Knowledge Giving 80% Understanding," "Interview Perspective," and "Final Mental Model" — and these heavily restate the body. In the thinner files (security, DR) these five sections are roughly **30–40% redundant** with the Core Mental Models and Deep Technical sections (e.g., "containment ≠ eradication," "air-gapped backups," "service accounts need rotation" each appear 3–4 times in the security file). In the two strong files redundancy is lower (~20%) because the body is rich enough that the recaps add compression value. Directory-wide: roughly **25–30% of line count is restatement**. The "20% Knowledge" + "Final Mental Model" + the two Junior/Senior lists are the prime padding; collapsing Junior/Senior into one table and cutting the "20%" list would lose almost no information.

## 🛠️ Improvement plan (tailored to this directory)
**Theme: fix the two real technical defects, level the five thin files up to the flagship bar, and de-duplicate the boilerplate tail.**

1. **Fix the CDP/RPO inversion immediately** (`disaster-recovery` line 144): "Continuous (CDP). Every change captured. **Near-zero (lowest) RPO**; expensive." This is the one outright-wrong fact and it's in a definitions table where readers will memorize it.
2. **Reconcile the retry-amplification numbers across the two files.** Standardize on the "total attempts" convention (4³ = 64 for 3 retries × 3 layers), state it explicitly once, and cross-link. Fix the "27% load amplification" line so it doesn't present 27× as a percentage.
3. **Raise the security file to a real deep dive.** It is ~2435 words of terse bullets. Add: a concrete worked incident timeline (the way the cascade file does) — e.g., a phished-credential → cloud-pivot → exfil case with detection lag, containment-without-tipoff, evidence order, and the 72h clock — plus a real treatment of MFA-bypass techniques (SIM swap, push-fatigue, token theft) since the file mentions "MFA-bypassed" without explaining how.
4. **Deepen the DR file's hardest topic: split-brain and post-failover reconciliation.** It names split-brain (lines 185, 263) but never explains fencing, STONITH, quorum, or how you actually detect/measure the data divergence after an async failover. Add the "did we lose committed writes, and how do we find out?" mechanics. Also add concrete RTO/RPO-to-cost numbers tied to a real stack (e.g., Aurora global vs cross-region snapshots).
5. **Add a postmortem worked example and fix the availability math.** The file teaches the 5-whys with a good example (lines 132–139) but has no full sample postmortem document — add one (summary/timeline/impact/contributing-factors/action-items) and explicitly use "contributing factors," not "root cause," per the brief's own steer (the file leans on "root causes" at line 153; note that mature blameless practice prefers "contributing factors"). Replace the loose MTTR/MTBF→availability claim with a small correct table.
6. **De-duplicate the five-section tail across all seven files.** Merge "What Junior Engineers Miss" and "What Senior Engineers Notice" into one two-column contrast table; delete the "20% Knowledge" list where it merely restates the body (keep it only where it genuinely compresses, i.e., the two flagship files). This reclaims ~25% of line count for the new depth in items 3–5 without growing the files.
7. **Add the one missing failure-mode primitive: retry budgets vs token-bucket math.** Both strong files mention "retry budget (10% of base traffic)" but neither shows how it's computed or enforced (the Linkerd retry-budget formula: `retryRatio + minRetriesPerSecond`). Add the actual mechanism so the interview answer "use a retry budget" has substance behind it.
