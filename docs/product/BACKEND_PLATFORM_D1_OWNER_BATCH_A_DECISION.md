# Recharge Backend — D1 Owner Batch A Decision

- ID: **BCK-D1-OWN-A-DEC-01**
- Version: **0.1**
- Date: **2026-09-08**
- Status: **Accepted with controls — documentation disposition only**
- Accountable verdict: **RechargeN / Product owner**
- Combined-role disclosure: **accepted; no independent review**
- Legal/Privacy qualification: **not claimed**
- Source recommendation snapshot: **BCK-D1-OWN-REV-01 v1.11**
- Reconciled workbook: [BCK-D1-OWN-REV-01 v1.12](BACKEND_PLATFORM_D1_COMBINED_OWNER_REVIEW_WORKBOOK.md)
- Sign-off ledger: [BCK-D1-SIG-01 v1.14](BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md)
- Review package: [BCK-D1-REV-01 v1.16](BACKEND_PLATFORM_D1_REVIEW_EVIDENCE_PACKAGE.md)
- Runtime effect: **none**
- Canonical path: `docs/product/BACKEND_PLATFORM_D1_OWNER_BATCH_A_DECISION.md`

## 1. Recorded instruction

On 2026-09-08 the Product owner explicitly approved D1 Owner Batch A exactly
as recommended:

```text
API-DEC-01–05 — Deferred with the listed controls;
OD-09 — remains Proposed;
BCK-03 v0.3.8 — Accept with required amendments;
all other BCK/OD statuses remain unchanged;
Legal/Privacy qualification is not claimed;
runtime, Firebase, deployment, push and merge are not authorized.
```

This record applies that verdict to the reconciled D1 snapshot. It does not
infer a specialist, independent, Legal/Privacy or Finance signature.

## 2. Scope reconciliation

Two earlier decisions already accept `API-DEC-01` and `API-DEC-03` for the
strictly bounded Booking v1 scope through `BCK09-API-NAMED-DEC-01 v0.2`.
Batch A does not revoke or weaken them. `Deferred` below means the broader
platform/non-Booking disposition remains deferred outside that accepted scope.

| Decision | Recorded disposition | Preserved control |
|---|---|---|
| `API-DEC-01` | **Deferred outside Accepted Booking v1** | no general transport mapping or endpoint before the executable API scaffold and its approval |
| `API-DEC-02` | **Deferred** | no generator/tooling change before a separately approved codegen/tooling slice |
| `API-DEC-03` | **Deferred outside Accepted Booking v1** | no platform-wide hash adoption or non-Booking mutation before exact contract/parity evidence |
| `API-DEC-04` | **Deferred** | no production minimum-client enforcement before the client-gate slice |
| `API-DEC-05` | **Deferred** | no language-neutral schema beyond Booking without a separate architecture decision |
| `OD-09` | **Proposed — unchanged** | no worker/effect before OD-09 Acceptance and D3 approval |
| `BCK-03` | **Owner review: Accept with required amendments** | specification remains Draft until required reviews and amendments pass |

Every deferred decision is reviewed at the start of its named blocking slice or
by 2026-11-20, whichever occurs first. Reaching a protected gate without a
resolved decision fails closed.

## 3. Required BCK-03 amendments

1. Preserve the Booking-v1-only Accepted scope of API-DEC-01/03.
2. Record explicit Deferred dispositions, reasons, review date and protected
   gates for the broader API-DEC-01/03 scope and API-DEC-02/04/05.
3. Keep OD-09 Proposed and all effects disabled.
4. Complete the required Operations, Security/Privacy and Mobile boundary
   reviews; combined-owner review is not independent evidence.
5. Require accepted executable decisions and parity evidence before any
   corresponding schema, generator, endpoint, client gate or effect activates.

## 4. Status effect

- `D1-SIG-API`: **Accept with required amendments — combined owner; independent
  evidence still required**.
- BCK-03: remains **Draft**.
- BCK-04, BCK-05 and BCK-20: remain **Draft**.
- OD-07: remains **Accepted with controls**.
- OD-09 and OD-10: remain **Proposed**.
- OD-11: remains **Open**.
- every other Pending or Inconclusive signature remains unchanged.
- D1, G1–G7, R1, provisioning and product/cloud runtime remain blocked.

## 5. Explicit non-authority

This decision does not authorize runtime code, Firebase or cloud resources,
Firestore/Admin access, credentials, deployment, activation, production data
processing, push or merge. It does not constitute qualified Legal/Privacy or
independent specialist approval.

## 6. Acceptance criteria

1. **D1-A-DEC-AC-01:** the exact Product-owner instruction and date are recorded.
2. **D1-A-DEC-AC-02:** API-DEC-01/03 retain their Accepted Booking-v1 scope.
3. **D1-A-DEC-AC-03:** broader API-DEC-01/03 and API-DEC-02/04/05 are Deferred.
4. **D1-A-DEC-AC-04:** every Deferred decision has a reason, review trigger and
   fail-closed protected gate.
5. **D1-A-DEC-AC-05:** OD-09 remains Proposed.
6. **D1-A-DEC-AC-06:** BCK-03 remains Draft with an owner review verdict of
   Accept with required amendments.
7. **D1-A-DEC-AC-07:** combined-role review is not described as independent.
8. **D1-A-DEC-AC-08:** Legal/Privacy qualification is not claimed.
9. **D1-A-DEC-AC-09:** all other BCK/OD/signature statuses are preserved.
10. **D1-A-DEC-AC-10:** no runtime, Firebase, deployment, push or merge authority
    is created.

## 7. Next action

Apply the recorded amendments to BCK-03 and obtain evidence-based
Operations, Security/Privacy and Mobile boundary verdicts. D1 exit is rerun
only after those and the remaining BCK-04/BCK-05/BCK-20 blockers are actually
closed.
