# Recharge Backend — Security & Privacy Architecture Owner Decision

- ID: **BCK04-SEC-DEC-01**
- Version: **0.1**
- Date: **2026-09-12**
- Status: **Accepted with required amendments — technical documentation boundary only**
- Accountable verdict: **RechargeN / Product owner**
- Independence: **combined-owner review; independent Security/Privacy evidence absent**
- Legal qualification: **not evidenced**
- Reviewed evidence: [BCK04-SEC-REV-01 v0.2](BACKEND_SECURITY_PRIVACY_OWNER_REVIEW.md)
- Target: [BCK-04 v0.4.22](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Runtime effect: **none**

## 1. Verdict

The Product owner explicitly approved `BCK04-SEC-REV-01 v0.1` as `Accept
with required amendments` for the technical BCK-04 boundary on 2026-09-12.
Version 0.2 of the review records that verdict without changing its findings.

This is a combined-owner documentation verdict. It is not independent
Security/Privacy evidence, qualified Legal/Privacy advice, BCK-04 Review or
Approval, acceptance of any BCK04-OD, D1/G1 exit, or runtime authorization.

## 2. Binding amendments

1. Use a fresh `requestId` per attempt and preserve `idempotencyKey` plus
   normalized payload across retries of one logical DSR submission.
2. Keep server-issued `privacyRequestId` separate from request-attempt and
   idempotency identities.
3. Replace the stale BCK-04-AC-06 wording with the resolved split-key rule and
   record the semantic migration without renumbering the AC.
4. Re-evaluate current authority for protected/sensitive reads and result
   disclosure, not only mutations.
5. Resolve and bound DSR subject/workspace/resource scope server-side.
6. Separate pre-send cancellation, post-send unknown outcome and authoritative
   cancellation before the irreversible boundary.
7. Make DSR state monotonic, revisioned and server-fresh.
8. Require authenticated, short-lived, purpose-bound and audited export
   retrieval; ordinary raw email attachments are prohibited.
9. Prevent erased/restricted data from silently returning through late work,
   import, projection rebuild or restore.
10. Give each legal/security hold a bounded authority, scope, review/expiry and
    release record.
11. Ensure App Check recovery cannot bypass AuthN, AuthZ, validation, rate
    limits or audit.
12. Correct stale current-revision wording in the test/evidence section.
13. Keep BCK04-OD-01/09 behind their separate exact decision and evidence
    gates.
14. Preserve qualified Legal/Privacy independence for age, lawful basis,
    retention, processor/transfer, DPIA/ROPA and Article 22 conclusions.

## 3. Preserved status

- BCK-04 remains **Draft**.
- BCK04-OD-01 and BCK04-OD-09 remain **Proposed**.
- OD-11 remains **Open**.
- Other BCK04-OD statuses and narrower activation gates are unchanged.
- D1-SIG-SEC now records the combined-owner technical BCK-03 and BCK-04
  boundary verdicts; it is not independent evidence.
- D1-SIG-LEGAL remains **Pending**; qualification is not inferred.
- D1, G1-G7 and R1 remain blocked.
- Runtime, Firebase, deployment, push and merge remain unauthorized.

## 4. Acceptance criteria

1. **BCK04-SEC-DEC-AC-01:** the exact owner verdict is recorded.
2. **BCK04-SEC-DEC-AC-02:** all fourteen amendments remain binding.
3. **BCK04-SEC-DEC-AC-03:** combined ownership is not called independent review.
4. **BCK04-SEC-DEC-AC-04:** no qualified Legal conclusion is inferred.
5. **BCK04-SEC-DEC-AC-05:** BCK-04 and BCK04-OD statuses are preserved.
6. **BCK04-SEC-DEC-AC-06:** other signatures and gates are not inferred.
7. **BCK04-SEC-DEC-AC-07:** D1/G1/runtime readiness is not promoted.
8. **BCK04-SEC-DEC-AC-08:** no code, Firebase, deployment, push or merge
   authority is created.

## 5. Next action

Complete the independent Security/Privacy and qualified Legal review path and
the exact BCK04-OD-01/09 decisions. Do not begin executable work.
