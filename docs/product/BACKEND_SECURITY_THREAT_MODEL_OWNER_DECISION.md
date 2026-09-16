# Recharge Backend — Security Threat Model Owner Decision

- ID: **BCK04-OD01-DEC-01**
- Version: **0.1**
- Date: **2026-09-15**
- Status: **Accepted with required amendments — combined-owner technical threat-model boundary only**
- Accountable verdict: **RechargeN / Product owner**
- Independence: **not evidenced**
- Legal qualification: **not inferred**
- Reviewed evidence: [BCK04-OD01-REV-01 v0.2](BACKEND_SECURITY_THREAT_MODEL_OWNER_REVIEW.md)
- Integrated target: [BCK04-OD01-TM-01 v0.2](BACKEND_SECURITY_THREAT_MODEL.md)
- Parent specification: [BCK-04 v0.4.23](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Runtime effect: **none**

## 1. Verdict

On 2026-09-15 the Product owner explicitly approved
`BCK04-OD01-REV-01 v0.1` as `Accept with required amendments` for the
combined-owner technical threat-model boundary.

This decision accepts the review direction and makes its twenty amendments
binding. It does **not** accept `BCK04-OD-01`. The OD stays Proposed until the
amended exact model receives independent Security/Privacy review and the
required API, Operations, Identity, Mobile and affected-domain confirmations.

## 2. Integrated amendment groups

1. Current BCK-01/02/03/04/05/20 anchors and runtime boundaries.
2. Stable asset, actor, trust-boundary and threat identifiers.
3. Explicit STRIDE plus privacy/abuse/cost/safety/operations classification.
4. Per-threat accountable ownership, evidence gate and residual disposition.
5. Target-control versus implemented/verified/exception state separation.
6. Bounded residual-risk decision and expiry requirements.
7. BCK-04 v0.4.23 DSR identity, scope, cancellation and export semantics.
8. Read/result reauthorization and anti-enumeration/inference coverage.
9. Identity linking, recovery, fixation, stuffing and revocation coverage.
10. App Check recovery that cannot bypass mandatory security controls.
11. Webhook/event, URL/SSRF and hostile-media ingress coverage.
12. Supply-chain, availability/cost and noisy-tenant coverage.
13. Privacy anti-resurrection, restore quarantine and market isolation.
14. Provider-specific addenda for future AI, provider and Payments activation.
15. Independent OD-01/OD-09 gates and revision checksum policy.

## 3. Preserved status and authority

- `BCK04-OD-01` remains **Proposed**.
- `BCK04-OD-09` remains **Proposed**; tabletop execution is absent.
- `OD-11` remains **Open**.
- BCK-04 remains **Draft**.
- Independent Security/Privacy and required cross-boundary confirmations are
  not inferred.
- Qualified Legal/Privacy conclusions are not inferred.
- D1, G1-G7 and R1 are not advanced.
- Runtime, Firebase, credentials, deployment, push and merge remain
  unauthorized.

## 4. Acceptance criteria

1. **BCK04-OD01-DEC-AC-01:** the exact owner verdict is recorded.
2. **BCK04-OD01-DEC-AC-02:** all twenty review amendments are binding.
3. **BCK04-OD01-DEC-AC-03:** the amendments are integrated in exact v0.2.
4. **BCK04-OD01-DEC-AC-04:** combined ownership is not independent evidence.
5. **BCK04-OD01-DEC-AC-05:** BCK04-OD-01 remains Proposed.
6. **BCK04-OD01-DEC-AC-06:** OD-09/OD-11/Legal statuses are not inferred.
7. **BCK04-OD01-DEC-AC-07:** cross-boundary confirmations remain required.
8. **BCK04-OD01-DEC-AC-08:** D1/G1/runtime readiness is not promoted.
9. **BCK04-OD01-DEC-AC-09:** no Firebase, credential or deployment authority
   is created.
10. **BCK04-OD01-DEC-AC-10:** no push or merge authority is created.

## 5. Next action

Obtain independent Security/Privacy review and the exact cross-boundary
confirmations against threat-model v0.2. Do not issue an OD-01 Acceptance record
or begin executable work before those gates pass.
