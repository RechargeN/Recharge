# BCK-20 — Translation Governance Product/Content Technical Pre-Review

- ID: **BCK20-OD02-PC-PRE-01**
- Version: **0.2**
- Date: **2026-09-17**
- Status: **Owner decision recorded — F-001–F-008 integrated in workflow v0.3**
- Frozen target: [BCK20-OD02-L10N-01 v0.2](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Review package: [BCK20-OD02-PC-REV-01 v0.2](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_REVIEW_PACKAGE.md)
- Owner decision: [BCK20-OD02-PC-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_PRE_REVIEW_DECISION.md)
- Integrated target: [BCK20-OD02-L10N-01 v0.3](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Target SHA-256: `f26e780cb8080404dc82afa5432fcb10db0005900f6f017ff2db13d063d81265`
- Specialist verdicts: **SIG-L10N Pending — unnamed; SIG-CONTENT Pending — unnamed**
- Runtime effect: **none**

## 1. Outcome

The workflow direction is coherent and all fourteen paper vectors have an
intended fail-closed outcome. Technical pre-review nevertheless found eight
semantic gaps that should be corrected before named specialist review. Two
break the promised immutable ID/atomic-publication model, three weaken audit or
impact evidence, and three leave policy interpretation ambiguous.

Recommended disposition:

> **Integrate F-001–F-008 as documentation-only technical corrections, then
> recompute frozen hashes and start named Product Localization/Content review.**

This is not either specialist verdict. BCK20-OD-02 remains Open, BCK-20 remains
Draft and OD-10 remains Proposed.

## 2. Checklist summary

| Boundary | Items reviewed | Covered | Covered with finding | Uncovered |
|---|---:|---:|---:|---:|
| Product Localization checklist | 12 | 8 | 4 | 0 |
| Content checklist | 12 | 5 | 7 | 0 |
| Mandatory paper vectors | 14 | 8 | 6 | 0 |

`Covered with finding` means the intended outcome exists in prose but the
semantic records or authority binding cannot yet prove it unambiguously.

## 3. Findings

### BCK20-OD02-PC-F-001 — source identity/authority chain is incomplete

- Severity: **Blocking**
- Affects: workflow §§5.1–5.2, 7; AC-03/06/26
- Evidence: `TranslationSourceSnapshot` has no immutable `sourceSnapshotId` or
  attributable source-owner authority; `TranslationCandidate` has no
  `sourceSnapshotId` relationship despite the rule that relationships are
  ID-based.
- Risk: a revision/hash collision or ambiguous record-family context can detach
  a candidate from the exact source authority it claims to translate.
- Required amendment:
  - add `sourceSnapshotId`, `sourceOwnerIdentity` and
    `sourceAuthorityEvidenceId` to the source snapshot;
  - bind every candidate to exact `sourceSnapshotId`;
  - require a documentation-only source-authority matrix by record family with
    owner role, source locale, default/minimum review class and policy references.
- Retained gate: physical schema remains API-DEC-05/BCK20-OD-01 scope.

### BCK20-OD02-PC-F-002 — manifest intent and publication outcome are conflated

- Severity: **Blocking**
- Affects: workflow §§5.4, 7, 13; AC-30/31
- Evidence: immutable `TranslationPublicationManifest` contains
  `publicationCommitResult` and `publishedAtUtc`, which are unknown until after
  the pre-commit manifest hash and compare step.
- Risk: circular integrity semantics, mutable-after-hash data or an
  unattributable unknown outcome.
- Required amendment:
  - keep the manifest as immutable publication intent with `createdAtUtc`;
  - create semantic `TranslationPublicationReceipt` containing attempt ID,
    logical idempotency key, manifest ID/hash, expected-current identity,
    publisher identity, authoritative result/current identity and commit time;
  - require retries to reconcile the receipt/authoritative pointer first.
- Retained gate: no endpoint, database or activation pointer is authorized.

### BCK20-OD02-PC-F-003 — approval revocation is not attributable

- Severity: **Major**
- Affects: workflow §§5.3, 6, 10, 13; AC-19/29
- Evidence: approval has `revokedReason?` but no revoker identity, revocation
  time or evidence reference.
- Risk: a cached or disputed revoke cannot be audited or reconciled reliably.
- Required amendment: add optional `revokedBy`, `revokedAtUtc` and
  `revocationEvidenceId`, required together when status is `revoked`; define
  invalid state combinations fail-closed.

### BCK20-OD02-PC-F-004 — correction record cannot target all declared actions

- Severity: **Major**
- Affects: workflow §§5.4, 12, 15; AC-17/18/38
- Evidence: `TranslationCorrectionRecord` requires
  `supersededCandidateId`, while prose distinguishes candidate withdrawal,
  manifest revocation and surface disablement.
- Risk: manifest- or surface-scoped emergency action is forced into a fake
  candidate relationship or becomes unauditable prose.
- Required amendment: replace the mandatory candidate-only target with typed
  `targetType: candidate | manifest | surface`, `targetId`, exact action and
  optional replacement ID; preserve affected market/locale/surface scope.

### BCK20-OD02-PC-F-005 — change-impact completeness cannot be proved

- Severity: **Major**
- Affects: workflow §§5.5, 6, 14; AC-13/28
- Evidence: `TranslationImpactSet` lists candidates/manifests but not affected
  source snapshots, record fields or glossary terms and has no analysis owner
  or completion timestamp.
- Risk: untranslated, rejected or not-yet-manifested units may disappear from
  the impact set while it still appears complete.
- Required amendment: add affected source-snapshot/record-field/glossary-term
  IDs, analyzer identity, analysis time and completeness rationale; `unknown`
  and `incomplete` remain fail-closed for high-impact/mandatory scope.

### BCK20-OD02-PC-F-006 — Legal/Product approval wording is ambiguous

- Severity: **Blocking for `legal_safety_mandatory`**
- Affects: workflow §3; AC-08/18/24
- Evidence: class table says `qualified Legal/Product approval`, which can be
  read as either Legal **or** Product despite the invariant that qualified
  Legal approval cannot be inferred.
- Risk: mandatory copy could be approved through the wrong authority.
- Required amendment: state `qualified Legal approval plus Product/domain
  approval where the exact policy requires it`; OD-05 still decides exact
  mandatory classes and fallback policy.

### BCK20-OD02-PC-F-007 — exception lifecycle lacks closure attribution

- Severity: **Major**
- Affects: workflow §§5.5, 13; AC-33
- Evidence: exception has owner, approver, expiry and closure evidence but no
  created/closed timestamps, closing identity or closure reason.
- Risk: an expired exception may appear closed without accountable evidence or
  remain operationally ambiguous.
- Required amendment: add `createdAtUtc`, `closedAtUtc?`, `closedBy?` and
  `closureReason?`; require coherent field combinations per status and keep
  expiry fail-closed.

### BCK20-OD02-PC-F-008 — locale normalization authority is not revisioned

- Severity: **Major**
- Affects: workflow §§2, 5, 13; AC-26
- Evidence: records bind `marketConfigRevision` and canonical locales, but the
  canonicalization/alias profile itself has no explicit immutable revision.
- Risk: the same input tag may normalize differently across reviewers,
  migration tools or later clients without appearing stale.
- Required amendment: bind source, candidate, approval and manifest to
  `localeNormalizationProfileRevision`; BCK-20/OD-10 remains the authority for
  accepted canonicalization rules and duplicate-equivalent rejection.

## 4. Paper-vector disposition

| Vector | Technical disposition | Finding/gate |
|---|---|---|
| PC-V01 | Covered with finding | F-001 source authority/identity |
| PC-V02 | Covered | Mobile review retained |
| PC-V03 | Covered | structural rejection |
| PC-V04 | Covered with finding | F-005 impact completeness |
| PC-V05 | Covered with finding | F-001/F-005 |
| PC-V06 | Covered | typed policy conflict; F-006 applies to final authority |
| PC-V07 | Covered with finding | F-003 revocation attribution |
| PC-V08 | Covered with finding | F-002 publication receipt |
| PC-V09 | Covered with finding | F-004 typed target |
| PC-V10 | Covered | safe rollback rule |
| PC-V11 | Covered | Security/Privacy deletion evidence retained |
| PC-V12 | Covered | EE/LT disabled |
| PC-V13 | Covered | separate user-authored contract |
| PC-V14 | Covered | provider-neutral offline path |

These dispositions are technical pre-review evidence only. Named reviewers
must still record their own PC-V01–V14 dispositions.

## 5. Amendment integration contract

If the owner accepts this pre-review:

1. advance workflow to v0.3 without changing the bounded decision status;
2. integrate F-001–F-008 and append AC-42 onward; do not renumber AC-01–41;
3. advance the technical review/decision records only for traceability;
4. advance BCK-20/coverage factually while keeping Draft/Open/Proposed states;
5. recompute every frozen hash in the Product/Content review package;
6. reset both specialist rows to the new exact v0.3 target as
   `Pending — unnamed`;
7. reconcile BCK-01/BCK-02/D1/roadmap/LAUNCH_STATUS documentation only;
8. create no source matrix content until accountable Content owners provide it;
   define only its required template/fields;
9. authorize no provider, schema, runtime, Firebase, deployment, push or merge.

## 6. Acceptance criteria

1. **BCK20-OD02-PC-PRE-AC-01:** the exact v0.2 normalized hash is reviewed.
2. **BCK20-OD02-PC-PRE-AC-02:** 24 checklist items and 14 vectors are covered.
3. **BCK20-OD02-PC-PRE-AC-03:** F-001 fixes the immutable ID/authority chain.
4. **BCK20-OD02-PC-PRE-AC-04:** F-002 separates manifest intent from commit
   receipt and unknown-outcome reconciliation.
5. **BCK20-OD02-PC-PRE-AC-05:** F-003 makes approval revocation attributable.
6. **BCK20-OD02-PC-PRE-AC-06:** F-004 gives correction actions typed targets.
7. **BCK20-OD02-PC-PRE-AC-07:** F-005 makes impact-set completeness auditable.
8. **BCK20-OD02-PC-PRE-AC-08:** F-006 cannot weaken qualified Legal authority.
9. **BCK20-OD02-PC-PRE-AC-09:** F-007 makes exception closure attributable.
10. **BCK20-OD02-PC-PRE-AC-10:** F-008 revisions locale normalization rules.
11. **BCK20-OD02-PC-PRE-AC-11:** AC-01–41 remain stable; new criteria append.
12. **BCK20-OD02-PC-PRE-AC-12:** source-authority matrix content remains
    specialist-owned and is not fabricated.
13. **BCK20-OD02-PC-PRE-AC-13:** both specialist verdicts remain Pending.
14. **BCK20-OD02-PC-PRE-AC-14:** BCK20-OD-02 remains Open, OD-10 Proposed and
    BCK-20 Draft.
15. **BCK20-OD02-PC-PRE-AC-15:** no specialist/Legal verdict, provider, schema,
    runtime, Firebase, deployment, push or merge authority is created.

## 7. Exact owner decision requested

```text
Одобряю BCK20-OD02-PC-PRE-01 v0.1:
интегрировать F-001–F-008 как documentation-only technical corrections до
named Product Localization/Content review.
BCK20-OD-02 остаётся Open; OD-10 остаётся Proposed; BCK-20 остаётся Draft.
Specialist/Legal verdicts, source-authority content, provider selection,
schema, runtime, Firebase, deployment, push и merge не разрешаю.
```

## 8. Recorded disposition

On 2026-09-17 the Product owner approved the exact §7 decision. The decision is
recorded in BCK20-OD02-PC-PRE-DEC-01 v0.1 and F-001–F-008 are integrated in
workflow v0.3. Both specialist rows remain `Pending — unnamed`; this technical
pre-review does not supply Product Localization, Content, Mobile,
Security/Privacy or qualified Legal evidence.
