# Recharge Backend — API Mobile Owner Decision

- ID: **BCK03-MOB-DEC-01**
- Version: **0.1**
- Date: **2026-09-09**
- Status: **Accepted with required amendments — documentation boundary only**
- Accountable verdict: **RechargeN / Product owner**
- Independence: **combined-owner review; independent Mobile evidence absent**
- Reviewed evidence: [BCK03-MOB-REV-01 v0.2](BACKEND_API_MOBILE_BOUNDARY_REVIEW.md)
- Target: [BCK-03 v0.3.12](BACKEND_API_CONTRACT_STANDARD.md)
- Runtime effect: **none**

## 1. Verdict

The Product owner explicitly approved `D1-SIG-MOBILE` for
`BCK03-MOB-REV-01 v0.1` as `Accept with required amendments` on 2026-09-09.
Version 0.2 of the review records that verdict without changing its findings.

This is a documentation-boundary verdict for BCK-03. It is not independent
Mobile Platform evidence and does not approve BCK-03, BCK-18, BCK-20, D1, G1,
runtime or any production integration.

## 2. Binding amendments

1. Every physical query and command attempt uses a fresh `requestId`; logical
   command retry preserves its idempotency key and normalized payload.
2. Local cancellation before send, post-send ambiguity and authoritative
   backend `cancelled` remain distinct outcomes.
3. Every enabled mutation declares its unknown-outcome recovery method and
   safe receipt/result window.
4. Cursor pages declare completion, typed invalidation and snapshot-safe merge
   behavior.
5. Server evidence, never device time or connectivity state, determines
   freshness.
6. Response arrival order does not authorize overwriting newer client state.
7. Error message keys and field paths use bounded, safe localized fallbacks;
   raw server/provider/SDK text is never displayed.
8. API-DEC-04 remains Deferred until minimum-client bootstrap/offline behavior
   is separately Accepted.
9. BCK-18/BCK-20, Money, generated-client, binding and per-domain cutover gates
   remain separate.
10. Independent Mobile Platform evidence remains required wherever the D1
    package calls for independence.

## 3. Preserved status

- `D1-SIG-MOBILE`: **Accept with required amendments — BCK-03 boundary only**.
- D1-SIG-API/OPS/SEC: unchanged.
- BCK-03 remains **Draft**.
- BCK-18 remains **Review — documentation only**.
- BCK-20 remains **Draft**.
- API-DEC-04/05 remain **Deferred**; OD-09/10 remain **Proposed**.
- all other D1 signatures remain as recorded in the ledger.
- runtime, Firebase, deployment, push and merge remain unauthorized.

## 4. Acceptance criteria

1. **BCK03-MOB-DEC-AC-01:** the exact owner verdict is recorded.
2. **BCK03-MOB-DEC-AC-02:** the verdict is limited to the BCK-03 boundary.
3. **BCK03-MOB-DEC-AC-03:** combined review is not called independent Mobile evidence.
4. **BCK03-MOB-DEC-AC-04:** all ten amendments remain binding.
5. **BCK03-MOB-DEC-AC-05:** BCK-03/BCK-18/BCK-20 statuses are preserved.
6. **BCK03-MOB-DEC-AC-06:** API-DEC-04/05 and OD-09/10 statuses are preserved.
7. **BCK03-MOB-DEC-AC-07:** other signatures and gates are not inferred.
8. **BCK03-MOB-DEC-AC-08:** no runtime or external action is authorized.

## 5. Next action

Continue the remaining D1 owner/signature reviews. D1 and G1 remain blocked
until every required evidence item and verdict actually passes.
