# BCK-20 — Reference Data & Localization Owner Decision

- ID: **BCK20-OWN-DEC-01**
- Version: **0.1**
- Date: **2026-09-16**
- Status: **Accepted with required amendments — combined-owner technical BCK-20 boundary only**
- Accountable verdict: **RechargeN / Product owner**
- Reviewed evidence: [BCK20-OWN-REV-01 v0.2](REFERENCE_DATA_LOCALIZATION_OWNER_REVIEW.md)
- Integrated target: [BCK-20 v0.2.10](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Runtime effect: **none**

## 1. Verdict

On 2026-09-16 the Product owner explicitly approved
`BCK20-OWN-REV-01 v0.1` as `Accept with required amendments` for the
combined-owner technical BCK-20 boundary.

This decision makes the review amendments and decision triage binding. It does
not accept BCK-20 or OD-10 and does not supply any specialist or qualified
Legal/Privacy verdict.

## 2. Exact disposition

- `BCK20-OD-01`: **Deferred** until API-DEC-05; no schema/code generation.
- `BCK20-OD-02`: **Open**; Product Localization governance workflow is next.
- `BCK20-OD-03`: **Deferred** to measured executable distribution design.
- `BCK20-OD-04`: **Deferred** to separately gated EE/LT activation.
- `BCK20-OD-05`: **Open** for qualified Legal + Product policy.
- `BCK20-OD-06`: **Deferred** until a required dictionary has an accepted source.
- `BCK20-OD-07`: **Deferred** until minimum-client and adoption evidence
  supports a non-destructive retirement decision.
- `OD-10`: remains **Proposed**.
- BCK-20: remains **Draft**.

Every Deferred item retains the exact gate and fail-closed default recorded in
the review and integrated specification.

## 3. Preserved blockers

- API-DEC-05 remains Deferred and cannot be bypassed by BCK-20.
- EE/LT remain independently disabled without Latvia fallback activation.
- Mandatory Legal/safety copy remains blocked without qualified policy.
- Absent auxiliary dictionaries cannot be replaced by ad-hoc canonical IDs.
- Destructive retirement is forbidden without an Accepted support policy.
- Specialist Reference Data, Localization, API, Content, Mobile and Legal
  verdicts remain unresolved.
- D1/G1 and executable stages are unchanged.

## 4. Acceptance criteria

1. **BCK20-OWN-DEC-AC-01:** the exact owner verdict is recorded.
2. **BCK20-OWN-DEC-AC-02:** all twelve review amendments are binding.
3. **BCK20-OWN-DEC-AC-03:** five decisions are Deferred with exact gates.
4. **BCK20-OWN-DEC-AC-04:** BCK20-OD-02 and BCK20-OD-05 remain Open.
5. **BCK20-OWN-DEC-AC-05:** OD-10 remains Proposed.
6. **BCK20-OWN-DEC-AC-06:** BCK-20 remains Draft.
7. **BCK20-OWN-DEC-AC-07:** API-DEC-05 is not bypassed.
8. **BCK20-OWN-DEC-AC-08:** specialist and Legal verdicts are not inferred.
9. **BCK20-OWN-DEC-AC-09:** D1/G1/runtime readiness is not promoted.
10. **BCK20-OWN-DEC-AC-10:** no schema, Firebase, deployment, push or merge
    authority is created.

## 5. Next action

Prepare the provider-neutral BCK20-OD-02 translation governance workflow.
Keep OD-05 and every executable/specialist gate separate.
