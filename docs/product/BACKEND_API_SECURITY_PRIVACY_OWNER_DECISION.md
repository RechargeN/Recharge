# Recharge Backend — API Security & Privacy Owner Decision

- ID: **BCK03-SEC-DEC-01**
- Version: **0.1**
- Date: **2026-09-08**
- Status: **Accepted with required amendments — documentation boundary only**
- Accountable verdict: **RechargeN / Product owner**
- Independence: **combined-owner review; independent evidence absent**
- Reviewed evidence: [BCK03-SEC-REV-01 v0.2](BACKEND_API_SECURITY_PRIVACY_BOUNDARY_REVIEW.md)
- Target: [BCK-03 v0.3.11](BACKEND_API_CONTRACT_STANDARD.md)
- Runtime effect: **none**

## 1. Verdict

The Product owner explicitly approved `D1-SIG-SEC` for
`BCK03-SEC-REV-01 v0.1` as `Accept with required amendments` on 2026-09-08.
Version 0.2 of the review records that verdict without changing its findings.

This is a documentation-boundary verdict. It is not an independent
Security/Privacy assessment, qualified Legal advice or approval of BCK-03,
BCK-04, D1 or G1.

## 2. Binding amendments

1. Reauthorize protected result disclosure on every idempotent replay without
   re-executing an already committed mutation.
2. Define a bounded, stable and anti-enumerating ingress decision order for
   every API surface.
3. Treat all client context as untrusted and resolve current actor, scope,
   market and policy authority server-side.
4. Register anti-enumeration against the complete observable response profile.
5. Enforce the five BCK-04 data classes, purpose and allowed sinks at schema
   level; mixed payloads use the most restrictive applicable handling.
6. Validate tracing values before structured logging and prohibit their use in
   log text, metric names, paths or authorization keys.
7. Require declared webhook/callback and outbound-fetch controls before an
   external boundary can activate.
8. Make security emergency compatibility changes bounded, auditable and
   reversible.
9. Keep OD-09 effects disabled until required privacy/retention/audit evidence
   is accepted.
10. Keep Mobile, independent Security/Privacy and qualified Legal reviews
    separate.

## 3. Preserved status

- `D1-SIG-SEC`: **Accept with required amendments — BCK-03 boundary only**.
- `D1-SIG-API` and `D1-SIG-OPS`: unchanged.
- BCK-03 and BCK-04 remain **Draft**.
- BCK04-OD-01/BCK04-OD-09 and OD-09 remain **Proposed**.
- OD-11 remains **Open**.
- D1-SIG-LEGAL remains Pending; qualification is not inferred.
- all other D1 signatures remain as recorded in the ledger.
- runtime, Firebase, deployment, push and merge remain unauthorized.

## 4. Acceptance criteria

1. **BCK03-SEC-DEC-AC-01:** the exact owner verdict is recorded.
2. **BCK03-SEC-DEC-AC-02:** the verdict is limited to the BCK-03 boundary.
3. **BCK03-SEC-DEC-AC-03:** combined review is not called independent or Legal.
4. **BCK03-SEC-DEC-AC-04:** all ten amendments remain binding.
5. **BCK03-SEC-DEC-AC-05:** BCK-03/BCK-04 remain Draft.
6. **BCK03-SEC-DEC-AC-06:** OD/BCK04-OD statuses are preserved.
7. **BCK03-SEC-DEC-AC-07:** other signatures are not inferred.
8. **BCK03-SEC-DEC-AC-08:** no runtime or external action is authorized.

## 5. Next action

Complete the Mobile BCK-03 boundary review. D1 remains blocked until all
required evidence and verdicts actually pass.
