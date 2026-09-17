# BCK-20 — Translation Governance Product Localization and Content Review Package

- ID: **BCK20-OD02-PC-REV-01**
- Version: **0.1**
- Date: **2026-09-17**
- Status: **Proposed — review package ready; both specialist verdicts Pending**
- Exact review target: [BCK20-OD02-L10N-01 v0.2](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Parent specification: [BCK-20 v0.2.11](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Technical owner decision: [BCK20-OD02-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_GOVERNANCE_OWNER_DECISION.md)
- Runtime effect: **none**

## 1. Purpose and decision boundary

This package turns the next `BCK20-OD-02` gate into two explicit, attributable
specialist reviews:

1. Product Localization review of locale quality, terminology, workflow,
   provenance, review depth and publication governance;
2. Content review of source authority, meaning, record-family ownership,
   lifecycle, correction, withdrawal and user-authored-content separation.

The package does not supply, infer or pre-approve either verdict. Document
presence, Product-owner approval, Codex analysis or a generic “looks good” is
not specialist evidence. `BCK20-OD-02` remains Open.

Mobile, Security/Privacy and applicable qualified Legal reviews remain later
independent gates. This package does not select a provider or schema and does
not authorize tooling, upload, credentials, runtime, Firebase or deployment.

## 2. Frozen review inputs

SHA-256 uses UTF-8 text normalized to LF line endings.

| Input | Frozen version/status | SHA-256 |
|---|---|---|
| Translation workflow | `BCK20-OD02-L10N-01 v0.2`; technical baseline, specialist evidence pending | `f26e780cb8080404dc82afa5432fcb10db0005900f6f017ff2db13d063d81265` |
| Technical decision | `BCK20-OD02-DEC-01 v0.1`; bounded technical decision | `0f073a89f03215e2eeeadebeb192c4d0b95d4089e68e6e597186c128a52f1fd1` |
| Parent BCK-20 | `BCK-20 v0.2.11`; Draft | `7e2fe0431d98262fc85dc1bc26f07b6ac81c4208c78daf691ffb8db22f38ffc9` |
| Coverage matrix | `BCK-20-PRE v0.2.11`; Draft | `c1eb3a8c5ccd836062a666a1c66b88b1ed3989c0d246a9d6cb6db0aad0c4ce56` |

The workflow checksum is 19 sections, 41 sequential AC, five translation
classes, nine named roles, eight semantic record types and 23 typed failures.
A checksum/version mismatch, excerpt-only review or changed normative target
makes the verdict Inconclusive until this package is revised.

## 3. Reviewer identity and authority

Each reviewer records:

- named identity and organization/team;
- exact role and authority basis for the reviewed boundary;
- relevant language, localization or content-governance competence;
- independence/conflict disclosure;
- access to the complete frozen input;
- exact checksum, scope, verdict, findings and evidence reference.

One person may hold both roles only when both authority bases are real and each
verdict is recorded separately. Combined-role review is disclosed and does not
satisfy Mobile, Security/Privacy or qualified Legal independence. The Product
owner who issued the technical decision cannot silently self-assign specialist
qualification through that decision.

## 4. Required sign-off matrix

| Sign-off ID | Required reviewer | Review scope | Initial status | Blocking result |
|---|---|---|---|---|
| `BCK20-OD02-SIG-L10N` | Named Product Localization owner/reviewer | Classes, locales, glossary, provenance, review depth, provider neutrality, portability, approval/publication/correction workflow and quality evidence | Pending — unnamed | OD-02 remains Open; no production translation publication |
| `BCK20-OD02-SIG-CONTENT` | Named Content/source-governance owner/reviewer | Source authority and meaning, record families, revision impact, policy conflicts, publication/withdrawal, user-authored exclusion and correction semantics | Pending — unnamed | OD-02 remains Open; no canonical localized content publication |

Both rows are required. One accepted row cannot compensate for a Pending,
Reject or Inconclusive row.

## 5. Product Localization review checklist

The Product Localization reviewer evaluates the complete workflow and answers:

1. Are `lv-LV`, `en` and `ru` treated as distinct canonical locale targets
   without conflating viewer locale, content locale or source locale?
2. Are BCP 47 canonicalization and locale aliases deterministic and safe from
   duplicate effective candidates?
3. Are the five translation classes sufficient and are escalation/no-lowering
   rules enforceable?
4. Is per-unit independent review mandatory for high-impact and Legal/safety
   text, with sampling limited to an approved `reference_standard` plan?
5. Are translator, linguistic reviewer, domain reviewer, approver and publisher
   responsibilities unambiguous and conflict-aware?
6. Does glossary revisioning preserve stable terms, prohibited substitutions,
   impact propagation and re-review?
7. Are placeholders, plural/select branches, rich text, links, Unicode and
   message-format versions validated without weakening meaning?
8. Is assisted translation always attributable untrusted draft input with no
   automatic publication or reduced review?
9. Can provider export/delete and semantic portability work without vendor
   lock-in while retaining provenance and review evidence?
10. Are approval freshness, atomic publication, correction, withdrawal and
    safe rollback coherent for localization operations?
11. Do privacy-safe quality metrics avoid raw text, personal data, automatic
    publication and false Legal authority?
12. Does the workflow remain usable through a human/offline path when every
    external provider is disabled?

Any unresolved contradiction in class, locale, terminology, review depth or
publication governance is a finding, not an implicit local convention.

## 6. Content review checklist

The Content reviewer evaluates the complete workflow and answers:

1. Is one accountable source owner identifiable for every future record family
   and field without turning translated output into source authority?
2. Do stable record/field IDs, immutable source revision/hash and change reason
   preserve meaning across translation and correction?
3. Can source, glossary, domain/Product and qualified Legal conflicts be raised
   without allowing a translator to choose policy?
4. Does each source/glossary/policy change create a bounded affected-unit set
   and re-review queue rather than silently retaining stale copy?
5. Are Content and Product boundaries clear for category labels, descriptions,
   destructive actions, privacy text and mandatory notices?
6. Are publication, market/feature activation and client rollout separate
   authorities?
7. Do candidate withdrawal, manifest revocation and surface disablement have
   distinct meaning and safe user-facing outcomes?
8. Can correction and rollback preserve history without reviving withdrawn,
   restricted, erased, expired or legally invalid text?
9. Are exceptions attributable, expiring and unable to weaken source identity,
   market isolation, privacy, independent review or Legal controls?
10. Is user-authored content excluded unless a separate consent, provenance,
    moderation, privacy and deletion contract exists?
11. Are local/mock strings correctly treated as migration candidates rather
    than automatically approved source or translation records?
12. Are disabled EE/LT markets protected from using Latvia text, glossary or
    approval as activation evidence?

The Content verdict accepts only governance of canonical product/reference
copy. It cannot decide Legal meaning, runtime presentation or provider data
processing.

## 7. Mandatory paper evidence vectors

Reviewers must evaluate the normative workflow against all vectors below.
These are design-review vectors, not executable test evidence.

| Vector | Scenario | Required outcome |
|---|---|---|
| PC-V01 | exact neutral taxonomy label for LV | attributable `reference_standard` path with stable ID |
| PC-V02 | long Latvian text exceeds a Mobile layout hint | meaning preserved; Mobile finding required; no silent truncation of source |
| PC-V03 | typed placeholder and plural branch differ from source | structural rejection; no approval/publication |
| PC-V04 | glossary term changes after linguistic approval | impact set and re-review; old approval cannot publish |
| PC-V05 | source meaning changes with unchanged-looking target text | new source-bound candidate/review; no record rebinding |
| PC-V06 | glossary, Product and Legal instructions conflict | typed `policy_conflict`; accountable reconciliation required |
| PC-V07 | approver access revoked or approval expires | publication and rollback blocked |
| PC-V08 | competing manifest wins expected-current compare | atomic `publication_conflict`; authoritative state queried |
| PC-V09 | current candidate is withdrawn for a safety defect | manifest revoked or surface disabled; unsafe prior text not exposed |
| PC-V10 | rollback target was later restricted or legally invalidated | rollback refused; fail closed |
| PC-V11 | provider export deletion cannot be confirmed | `deletion_unconfirmed`; escalation/evidence remains open |
| PC-V12 | EE/LT pretranslation exists while market is disabled | no publication/activation through LV evidence |
| PC-V13 | user-authored description is offered for automatic translation | rejected from this authority; separate feature contract required |
| PC-V14 | provider and network are unavailable | approved human/offline workflow remains possible |

For every vector each reviewer records `Accept`, a finding ID, or
`NotApplicable` with rationale. Missing vector disposition is Inconclusive.

## 8. Findings register

Every finding uses stable ID `BCK20-OD02-PC-F-###` and records:

| Field | Required content |
|---|---|
| Sign-off | `SIG-L10N`, `SIG-CONTENT` or both |
| Reviewer | named identity and authority basis |
| Frozen target | workflow version and SHA-256 |
| Sections/AC | exact normative references |
| Severity | Blocking / Major / Minor / Editorial with rationale |
| Finding | concrete contradiction, omission or ambiguity |
| Required amendment | exact change, accountable owner and affected documents |
| Status | Open / Integrated / Rejected with rationale / Superseded |
| Re-review evidence | exact amended version/hash and reviewer disposition |

Open Blocking or Major findings are incompatible with an effective acceptance.
Editorial findings may be batched only when they do not change meaning, scope,
authority, status or an AC.

## 9. Allowed verdict vocabulary

Each sign-off uses exactly one verdict:

| Verdict | Meaning |
|---|---|
| `Accept design boundary with retained gates` | No unresolved contradiction in the reviewed scope; other specialist and runtime gates remain |
| `Accept with amendments` | Listed amendments are mandatory; acceptance is not effective until integration and exact-version re-review |
| `Reject` | A blocking contradiction and replacement direction are recorded |
| `Inconclusive` | Identity, authority, input, evidence or scope is insufficient; row remains Pending |

`Pass`, `Approved`, a blank response or approval of only this review package is
not a specialist verdict.

## 10. Required signature records

Each role submits its own complete record:

```text
Sign-off ID: BCK20-OD02-SIG-L10N | BCK20-OD02-SIG-CONTENT
Named reviewer identity:
Organization/team:
Reviewer role:
Qualification or authority basis:
Independence/conflict disclosure:
Target: BCK20-OD02-L10N-01 v0.2
Observed SHA-256:
Verdict:
Accepted scope:
Checklist items reviewed:
Vector dispositions: PC-V01..PC-V14
Finding IDs:
Required amendments:
Retained gates:
Date/timezone:
Evidence reference:
```

Missing identity, authority basis, target/hash, verdict, scope, all vector
dispositions or evidence reference makes the record Inconclusive.

## 11. Reconciliation sequence

1. Freeze and verify the exact v0.2 target/hash.
2. Assign named Product Localization and Content reviewers.
3. Collect both independent signature records and findings.
4. If either verdict is `Accept with amendments`, integrate amendments in a new
   workflow revision without renumbering AC-01–41.
5. Recompute hashes, update this package and obtain exact-version re-review
   from every reviewer whose scope changed.
6. Keep each row Pending until its effective verdict has no Open Blocking/Major
   finding.
7. Reconcile BCK-20, coverage, D1 records and LAUNCH_STATUS only after both
   effective specialist verdicts are recorded.
8. Prepare the separate Mobile and Security/Privacy review gate next.
9. Keep qualified Legal review attached only to its applicable exact classes
   and policy revisions; never infer it from either row here.

If the target changes before both verdicts become effective, stale signatures
remain historical evidence and cannot be copied to the new revision.

## 12. Result-state matrix

| L10N result | Content result | Package result | BCK20-OD-02 effect |
|---|---|---|---|
| Effective Accept | Effective Accept | Product/Content boundary complete | remains Open for Mobile, Security/Privacy and applicable Legal |
| Accept with amendments | any | Amend/re-review required | Open |
| Reject | any | Blocked | Open; replacement direction required |
| Inconclusive/Pending | any | Incomplete | Open |
| Effective Accept | Reject/Inconclusive/Pending | Incomplete or blocked | Open |

No row in this matrix authorizes runtime or provider use.

## 13. Rollback and staleness

Before any signature exists, rollback is deletion or supersession of this
proposal in a new attributable documentation revision. After signatures exist,
the record is immutable history and must be superseded rather than rewritten.

The package becomes stale when the workflow's normative text, AC, classes,
roles, record semantics, failure vocabulary or retained gates change. Editorial
formatting that leaves the normalized hash changed still requires an updated
frozen hash, even if re-review scope may be documented as non-semantic.

## 14. Acceptance criteria

1. **BCK20-OD02-PC-AC-01:** exact workflow v0.2 and normalized hash are frozen.
2. **BCK20-OD02-PC-AC-02:** Product Localization and Content use separate
   attributable sign-off IDs.
3. **BCK20-OD02-PC-AC-03:** both specialist verdicts start Pending and unnamed.
4. **BCK20-OD02-PC-AC-04:** reviewer identity, authority and conflict disclosure
   are mandatory.
5. **BCK20-OD02-PC-AC-05:** full target review cannot be replaced by excerpts.
6. **BCK20-OD02-PC-AC-06:** Product Localization reviews locale, glossary,
   review depth, provenance and publication governance.
7. **BCK20-OD02-PC-AC-07:** Content reviews source authority, meaning,
   lifecycle, withdrawal and user-authored separation.
8. **BCK20-OD02-PC-AC-08:** all fourteen paper vectors receive a disposition.
9. **BCK20-OD02-PC-AC-09:** findings have stable IDs and exact normative scope.
10. **BCK20-OD02-PC-AC-10:** Open Blocking/Major findings prevent effective
    acceptance.
11. **BCK20-OD02-PC-AC-11:** amendments require integration and exact-version
    re-review.
12. **BCK20-OD02-PC-AC-12:** stale signatures cannot transfer to a changed
    normative target.
13. **BCK20-OD02-PC-AC-13:** one accepted row cannot compensate for the other.
14. **BCK20-OD02-PC-AC-14:** combined-role review is explicitly disclosed.
15. **BCK20-OD02-PC-AC-15:** neither verdict supplies Mobile,
    Security/Privacy or qualified Legal evidence.
16. **BCK20-OD02-PC-AC-16:** Latvia evidence cannot activate EE/LT.
17. **BCK20-OD02-PC-AC-17:** user-authored translation remains separately
    gated.
18. **BCK20-OD02-PC-AC-18:** provider/schema selection remains outside scope.
19. **BCK20-OD02-PC-AC-19:** document presence does not close BCK20-OD-02.
20. **BCK20-OD02-PC-AC-20:** no runtime, Firebase, deployment, push or merge
    authority is created.

## 15. Immediate next action

Assign named Product Localization and Content reviewers and provide each the
complete frozen input plus this package. Do not prefill either verdict. Until
both effective records exist, do not update BCK-20 or D1 status.
