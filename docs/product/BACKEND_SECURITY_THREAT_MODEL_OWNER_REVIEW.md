# Recharge Backend — Security Threat Model Owner Review

- ID: **BCK04-OD01-REV-01**
- Version: **0.2**
- Date: **2026-09-15**
- Status: **Owner verdict recorded — amendments integrated; independent/cross-boundary evidence pending**
- Review result: **Accept with required amendments — technical threat-model boundary only**
- Reviewer: **RechargeN / Product owner** (combined Security/Privacy role)
- Independence: **not evidenced**
- Legal qualification: **not applicable to this technical verdict; qualified Legal conclusions remain separate**
- Reviewed target: **BCK04-OD01-TM-01 v0.1**
- Integrated target: [BCK04-OD01-TM-01 v0.2](BACKEND_SECURITY_THREAT_MODEL.md)
- Parent specification: [BCK-04 v0.4.23](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Technical-boundary decision: [BCK04-SEC-DEC-01 v0.1](BACKEND_SECURITY_PRIVACY_OWNER_DECISION.md)
- Owner decision: [BCK04-OD01-DEC-01 v0.1](BACKEND_SECURITY_THREAT_MODEL_OWNER_DECISION.md)
- Runtime effect: **none**

## 1. Scope and recommended verdict

The v0.1 threat model is a strong repository-wide proposal: it identifies the
main assets, actors, twelve trust boundaries, thirty-six threats, control
families and future evidence gates. It correctly treats authenticated clients,
providers and privileged operators as bounded rather than inherently trusted.

It is not yet decision-grade. The threat register promises STRIDE plus
privacy/abuse/cost classification but does not record those categories. It also
does not assign an accountable owner or residual disposition to each threat,
and several controls predate the accepted BCK-04 v0.4.22 DSR and App Check
amendments.

Recommended verdict: accept this review and its required amendments for the
combined-owner technical boundary. Do **not** accept `BCK04-OD-01` yet. The OD
remains Proposed until the amendments are integrated into an exact new threat-
model revision, independent Security/Privacy review is recorded and the
required API/Operations/Identity/Mobile/domain contradiction checks complete.

## 2. Review matrix

| Area | Result | Required treatment |
|---|---|---|
| Assets, actors and trust boundaries | Pass with amendment | Give assets stable IDs and reference them from every threat |
| STRIDE/privacy/abuse/cost method | Gap | The register has no category/tag field despite the declared method |
| Threat ownership | Gap | Control-family ownership is not a per-threat accountable owner |
| Control implementation state | Gap | Target controls and proved controls are not distinguished |
| Residual risk | Gap | Priority exists, but residual disposition, approver and expiry do not |
| Authentication lifecycle | Partial | Account linking, recovery, credential stuffing and session fixation need explicit cases |
| Authorization and IDOR | Strong with amendment | Protected reads, result disclosure and query/count side channels must re-authorize current grants |
| DSR/export/deletion | Outdated | Must use the three BCK-04 v0.4.22 identities and anti-resurrection rules |
| App Check/degraded mode | Partial | Recovery must never bypass AuthN/AuthZ/validation/rate/audit |
| Events, jobs and webhooks | Pass with amendment | Add ordering, signature rotation, replay-window and poison ownership detail |
| Provider URL and media ingress | Partial | Add DNS rebinding/private-target and polyglot/decompression/metadata threats |
| Supply chain and release | Pass with amendment | Make builder identity, provenance, dependency confusion and secret-exfiltration evidence explicit |
| Backup and restore | Partial | Restored data must remain quarantined until deletion/restriction reconciliation passes |
| Availability and cost abuse | Partial | Add hot-key, fan-out, cache-stampede and per-actor fairness cases |
| Market/workspace isolation | Pass with amendment | Include cross-market processing/configuration and disabled-market leakage |
| Incident coupling | Semantic gap | OD-01 and OD-09 must stay independently decidable without hiding response-path gaps |
| Verification matrix | Pass with amendment | Map every Critical/High threat to named negative evidence and an executable gate |

## 3. Required amendments

1. **Reconcile current anchors.** Advance the model to a new revision linked to
   BCK-01 v0.4.56, BCK-02 v2.4.60, BCK-03 v0.3.13, BCK-04 v0.4.22,
   BCK-05 v0.2.29 and BCK-20 v0.2.8. Record bounded local RAW-C evidence
   separately from absent product/cloud runtime.
2. **Give every asset a stable ID.** Each threat must identify one or more
   affected asset IDs and exact trust-boundary IDs; prose inference is not a
   traceability contract.
3. **Materialize the declared classification.** Add STRIDE category plus
   explicit `privacy`, `abuse`, `cost`, `safety` and `operations` tags where
   applicable. Multiple categories are allowed; an empty classification is
   invalid.
4. **Normalize every threat record.** The minimum fields are threat ID,
   scenario, actor, asset IDs, trust boundaries, category/tags, inherent
   priority, target controls, accountable owner, required evidence, blocking
   gate and residual disposition.
5. **Separate design from proof.** Mark controls as `target`, `implemented`,
   `verified` or `exception`; v0.1 target prose cannot be read as executable
   evidence.
6. **Make ownership per-threat.** Every Critical/High threat needs one
   accountable control owner and named collaborators. A BCK module family is
   insufficient when no accountable role is selected.
7. **Make residual decisions explicit.** Use `blocked`, `mitigatedPendingProof`,
   `acceptedResidual`, `transferred` or `notApplicable`. Residual acceptance
   requires owner, rationale, scope, expiry/review date and compensating
   controls; Critical residual risk cannot be silently accepted.
8. **Reconcile DSR identity and scope.** Model fresh attempt `requestId`, stable
   logical `idempotencyKey` and server-issued `privacyRequestId`; server-bind
   subject/scope and distinguish pre-send cancellation, unknown outcome and
   authoritative cancellation before the irreversible boundary.
9. **Strengthen privacy-result controls.** Add current-grant authorization for
   protected/sensitive reads and result disclosure, owner-bound short-lived
   export retrieval, monotonic revision/freshness and no raw email attachment.
10. **Prevent privacy resurrection.** Late jobs, projection rebuilds, local
    import, backup restore and identity teardown must preserve erasure/
    restriction markers and completion revisions.
11. **Cover identity lifecycle attacks.** Add credential stuffing, account-
    linking takeover, unsafe recovery, session fixation, revoked-provider and
    recent-auth/step-up bypass threats, while leaving exact policy to BCK-06
    and its gated decisions.
12. **Bound App Check recovery.** Monitor/disabled App Check may be an explicit
    degraded state, but no recovery path may disable AuthN, current AuthZ,
    schema/domain validation, rate limits or audit.
13. **Close read-side inference gaps.** Include list/search/count/timing/
    pagination/export side channels, stale authorization during streaming or
    pagination, and cross-workspace aggregate leakage.
14. **Strengthen untrusted ingress.** Provider/webhook cases must include key
    rotation, canonical signing input, ordering, replay windows and poison
    quarantine. URL/media cases must include DNS rebinding/private targets,
    redirect revalidation, MIME/polyglot spoofing, decompression bombs and
    sensitive metadata.
15. **Expand platform threats.** Add dependency confusion, compromised builder,
    provenance mismatch, secret exfiltration, hot documents, unbounded fan-out,
    cache stampede and per-actor/tenant quota starvation.
16. **Make restore and market isolation fail closed.** Restores remain
    quarantined until authorization, ledger and privacy reconciliation pass;
    disabled EE/LT markets cannot receive LV flags, data or processing by
    fallback.
17. **Keep future surfaces gated.** AI, provider and Payments activation each
    require a versioned threat-model addendum tied to the actual selected
    provider, data flow and executable slice; generic v0.1 coverage is not
    activation evidence.
18. **Decouple OD-01 from OD-09 without weakening either.** Every Critical/High
    threat must map to a current response-path identifier. Exact severity,
    privacy-risk judgment and tabletop proof remain BCK04-OD-09 gates; neither
    OD is inferred Accepted from the other.
19. **Create machine-checkable traceability.** Add a checksum summary for
    assets, trust boundaries, threats by priority/category, missing owners,
    missing gates and residual states. Counts are revision checksums, not
    permanent product limits.
20. **Preserve stable identifiers.** Existing `TM-01`–`TM-36` and
    `BCK04-TM-AC-01`–`20` keep their meaning. New threats and criteria append;
    semantic replacements are recorded explicitly rather than silently
    renumbered.

## 4. Preserved statuses and authority

- `BCK04-OD-01` remains **Proposed**.
- `BCK04-OD01-TM-01` remains **Draft v0.1** until amendments are integrated.
- `BCK04-OD-09` remains **Proposed** and its tabletop remains unexecuted.
- `OD-11` remains **Open**.
- BCK-04 remains **Draft**.
- The combined-owner review is not independent Security/Privacy evidence.
- Qualified Legal/Privacy conclusions are not inferred.
- D1, G1-G7 and R1 are not advanced.
- Runtime, Firebase, credentials, deployment, push and merge remain
  unauthorized.

## 5. Exact owner response requested

```text
Одобряю BCK04-OD01-REV-01 v0.1:
Accept with required amendments для combined-owner technical threat-model
boundary. BCK04-OD-01 остаётся Proposed до интеграции поправок в exact revision,
independent Security/Privacy review и требуемых cross-boundary confirmations.
BCK04-OD-09, OD-11, Legal, D1/G1, runtime, Firebase, deployment, push и merge
не разрешаю.
```

The Product owner explicitly approved this response on 2026-09-15.
`BCK04-OD01-DEC-01` records the bounded verdict, and all twenty amendments are
integrated in threat-model v0.2. `BCK04-OD-01` remains Proposed pending the
independent and cross-boundary gates stated above.

## 6. Acceptance criteria

1. **BCK04-OD01-REV-AC-01:** the review targets exact threat-model v0.1.
2. **BCK04-OD01-REV-AC-02:** the useful v0.1 asset/actor/boundary baseline is preserved.
3. **BCK04-OD01-REV-AC-03:** declared classification becomes explicit data.
4. **BCK04-OD01-REV-AC-04:** every threat references stable assets and boundaries.
5. **BCK04-OD01-REV-AC-05:** target controls are not called implemented or verified.
6. **BCK04-OD01-REV-AC-06:** each Critical/High threat has one accountable owner.
7. **BCK04-OD01-REV-AC-07:** residual disposition and exception authority are explicit.
8. **BCK04-OD01-REV-AC-08:** DSR semantics match BCK-04 v0.4.22.
9. **BCK04-OD01-REV-AC-09:** read/result disclosure re-authorizes current grants.
10. **BCK04-OD01-REV-AC-10:** erased/restricted data cannot silently resurrect.
11. **BCK04-OD01-REV-AC-11:** identity lifecycle and recovery threats are covered.
12. **BCK04-OD01-REV-AC-12:** App Check recovery cannot bypass core controls.
13. **BCK04-OD01-REV-AC-13:** read-side inference and hostile ingress are covered.
14. **BCK04-OD01-REV-AC-14:** platform, cost, restore and market threats fail closed.
15. **BCK04-OD01-REV-AC-15:** future provider-specific surfaces require addenda.
16. **BCK04-OD01-REV-AC-16:** OD-01 and OD-09 remain separately gated.
17. **BCK04-OD01-REV-AC-17:** checksum and stable-ID policies are explicit.
18. **BCK04-OD01-REV-AC-18:** no OD, D1/G1 or runtime status is promoted.
19. **BCK04-OD01-REV-AC-19:** combined ownership is not independent evidence.
20. **BCK04-OD01-REV-AC-20:** no code, Firebase, deployment, push or merge
    authority is created.

## 7. Next action

Complete independent Security/Privacy review and API, Operations, Identity,
Mobile and affected-domain contradiction checks against exact v0.2. Do not
create the OD-01 acceptance decision until those gates pass.
