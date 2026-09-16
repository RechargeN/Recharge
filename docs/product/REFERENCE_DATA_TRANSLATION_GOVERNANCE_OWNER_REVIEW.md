# BCK-20 — Translation Governance Owner Review

- ID: **BCK20-OD02-REV-01**
- Version: **0.2**
- Date: **2026-09-16**
- Status: **Owner verdict recorded — amendments integrated in workflow v0.2**
- Review target: [BCK20-OD02-L10N-01 v0.1](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Parent specification: [BCK-20 v0.2.11](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Parent decision: **BCK20-OD-02 remains Open**
- Owner decision: [BCK20-OD02-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_GOVERNANCE_OWNER_DECISION.md)
- Runtime effect: **none**

## 1. Review outcome

The proposed workflow is a strong provider-neutral governance baseline. It
correctly separates stable IDs from labels, binds translations to immutable
source revisions, requires independent review for high-impact copy, isolates
markets, keeps user-authored content outside scope and fails closed for unsafe
mandatory text.

It is suitable for a bounded combined-owner technical verdict after the
amendments in this review are integrated. The verdict must not close
BCK20-OD-02: Product Localization, Content, Mobile and applicable qualified
Legal evidence is still absent. BCK-20 remains Draft and OD-10 remains
Proposed.

Recommended verdict:

> **Accept with required amendments — combined-owner technical translation-
> governance boundary only.**

## 2. Review matrix

| Area | Result | Required treatment |
|---|---|---|
| Scope and separation from fallback | Pass | Keep OD-02, OD-05 and OD-10 independently decidable |
| Translation classes | Strong with amendment | Add exact escalation and no-waiver rules |
| Role separation | Strong with amendment | Add conflicts of interest and per-unit review requirements |
| Immutable records | Pass with amendment | Bind locale, message format and integrity revisions explicitly |
| Lifecycle and stale work | Partial | Add approval revocation, expiry and impact propagation |
| Publication | Gap | Require atomic manifest activation and expected-current compare |
| Emergency correction | Strong with amendment | Prevent resurrection of withdrawn or unsafe text |
| Retention and deletion | Partial | Define semantic retention classes and provider-export deletion evidence |
| Provider neutrality | Strong with amendment | Require portable export without selecting a physical format |
| Baltic isolation | Pass | Preserve LV-only proof; EE/LT remain independently disabled |
| Quality evidence | Partial | Define safe batch/sampling behavior and non-authoritative metrics |
| Exceptions | Gap | Add attributable, expiring exception records; forbid critical bypasses |
| Schema/runtime authority | Pass | Remains absent and separately gated |

## 3. Required amendments

1. **Canonicalize locale and message format.** Every source, candidate,
   approval and manifest must bind a canonical BCP 47 locale, effective
   `MarketConfig` revision, message-format/version and placeholder-schema hash.
   Aliases are normalized before identity comparison and cannot create a
   second effective candidate.
2. **Define precedence and conflict handling.** Source meaning, approved
   glossary, product/domain policy and qualified Legal policy must not silently
   overwrite each other. Any contradiction is a typed blocking finding routed
   to the accountable owner; translators cannot resolve policy conflicts by
   wording alone.
3. **Materialize impact propagation.** Source or glossary changes must produce
   an attributable affected-unit set and re-review queue. Unknown impact fails
   closed for high-impact and mandatory classes; bulk invalidation cannot be
   represented only as prose.
4. **Add approval freshness.** Approval records need status, revocation reason,
   applicable policy revision and optional expiry/review deadline. Revoked,
   expired or superseded approval cannot authorize publication, rollback or a
   cached client artifact.
5. **Make publication atomic.** A manifest must bind its own integrity hash,
   exact candidate/approval set, expected-current manifest revision and
   activation result. Partial publication or compare failure is a typed
   conflict; retry reconciles authoritative state instead of republishing
   blindly.
6. **Separate publication from activation authority.** The publisher may
   execute only an approved immutable manifest. Market/feature activation,
   reference-data distribution and client rollout remain separate gated
   authorities and cannot be inferred from a successful publication.
7. **Prevent unsafe rollback.** A previous manifest may be restored only after
   current compatibility and approval checks. Rollback must never resurrect
   withdrawn, erased, restricted, expired or legally invalid text. If no safe
   prior manifest exists, the surface remains disabled or fail-closed.
8. **Define exception governance.** Any permitted temporary exception needs a
   stable ID, scope, owner, rationale, compensating controls, approval,
   expiration and closure evidence. Exceptions cannot bypass stable IDs,
   market isolation, secrets/privacy restrictions, independent high-impact
   review or qualified Legal approval for mandatory copy.
9. **Strengthen reviewer independence.** High-impact and mandatory review is
   per unit, not an unbounded sample. Reviewer conflicts are disclosed. Batch
   or sampled review is allowed only for `reference_standard` under a future
   approved sampling plan with thresholds, escalation and whole-batch failure
   rules.
10. **Close retention/deletion semantics.** Define retention classes for source,
    candidate, review, approval, publication, correction, audit and temporary
    work-package artifacts. Exact periods remain a later Security/Privacy/Legal
    decision, but temporary provider exports must have deletion deadlines and
    deletion/failed-deletion evidence while minimum immutable audit is
    preserved lawfully.
11. **Require semantic portability.** Before provider production use, the
    system must support complete attributable export, revocation and deletion
    without losing IDs, revisions, provenance, findings or approval links.
    This requirement does not select API-DEC-05 schema or a vendor format.
12. **Bound quality metrics.** Metrics may measure workflow states, timing and
    validated defects using privacy-safe identifiers. A score cannot
    auto-publish, weaken review depth or become proof of Legal correctness;
    raw product text and personal data stay out of telemetry by default.
13. **Type withdrawal and notification.** Emergency handling must distinguish
    candidate withdrawal, manifest revocation and surface disablement, record
    affected interval and trigger the applicable incident/owner notification.
    Exact operational SLAs remain BCK-05 scope.
14. **Keep user-authored translation separate.** Future automatic or assisted
    translation of user content requires an independent consent, provenance,
    moderation, privacy and deletion contract. It cannot enter reference-data
    authority or reuse this workflow as implicit permission.
15. **Extend typed failures.** Add at least `policy_conflict`,
    `approval_revoked`, `approval_expired`, `manifest_integrity_failed`,
    `exception_expired`, `impact_unknown` and `deletion_unconfirmed` without
    converting any of them into silent fallback.
16. **Append acceptance criteria without renumbering.** Preserve AC-01–25 and
    append AC-26 onward for every amendment above so existing references remain
    stable.

## 4. Binding interpretation after integration

The integrated workflow would become the required technical governance shape
for later translation tooling, but it would still be non-executable. In
particular:

- `Accepted` would apply only to this combined-owner technical boundary;
- BCK20-OD-02 would remain Open until named specialist evidence exists;
- qualified Legal authority would remain required for OD-05 classes;
- OD-10 would remain Proposed and could not be accepted through this review;
- BCK-20 would remain Draft;
- provider, schema, storage, API, runtime and distribution choices would remain
  unselected;
- Latvia evidence would not activate Estonia or Lithuania;
- no existing app string would become approved merely by being present;
- no runtime, Firebase, deployment, push or merge permission would be created.

## 5. Required later evidence

This owner verdict intentionally cannot supply:

1. Product Localization review of roles, terminology and locale quality.
2. Content/source-owner confirmation for record families and source authority.
3. Mobile review of layout, accessibility and typed state presentation.
4. Qualified Legal review for mandatory local copy, consent, rights, age,
   safety and fallback-forbidden policy.
5. Security/Privacy confirmation of retention, provider processing, access and
   deletion controls before any external tool is used.
6. Executable contract, migration, rollback and negative-test evidence after
   the relevant schema/runtime slices are separately approved.

Missing evidence is `Pending` or `Inconclusive`, never `Pass`.

## 6. Acceptance criteria

1. **BCK20-OD02-REV-AC-01:** the review targets exact workflow v0.1.
2. **BCK20-OD02-REV-AC-02:** the provider-neutral workflow direction is
   accepted only for the combined-owner technical boundary.
3. **BCK20-OD02-REV-AC-03:** BCK20-OD-02 remains Open.
4. **BCK20-OD02-REV-AC-04:** OD-10 remains Proposed and BCK-20 remains Draft.
5. **BCK20-OD02-REV-AC-05:** canonical locale, market, message-format and
   placeholder revisions are explicit.
6. **BCK20-OD02-REV-AC-06:** policy conflicts block instead of silently
   changing meaning.
7. **BCK20-OD02-REV-AC-07:** source/glossary changes produce bounded impact
   and re-review evidence.
8. **BCK20-OD02-REV-AC-08:** revoked, expired or stale approvals cannot
   publish or roll back.
9. **BCK20-OD02-REV-AC-09:** manifest publication is integrity-checked and
   atomic at the authority boundary.
10. **BCK20-OD02-REV-AC-10:** publication does not imply market, feature or
    client activation.
11. **BCK20-OD02-REV-AC-11:** rollback cannot resurrect invalid or withdrawn
    text.
12. **BCK20-OD02-REV-AC-12:** exceptions are attributable, expiring and cannot
    bypass mandatory controls.
13. **BCK20-OD02-REV-AC-13:** high-impact/mandatory review is independent and
    per unit.
14. **BCK20-OD02-REV-AC-14:** retention and provider-export deletion require
    explicit later policy and evidence.
15. **BCK20-OD02-REV-AC-15:** portability preserves IDs, revisions,
    provenance and decisions without selecting a vendor.
16. **BCK20-OD02-REV-AC-16:** quality metrics cannot auto-publish or prove
    Legal correctness.
17. **BCK20-OD02-REV-AC-17:** withdrawal, manifest revocation and surface
    disablement stay distinct.
18. **BCK20-OD02-REV-AC-18:** user-authored translation remains separately
    gated.
19. **BCK20-OD02-REV-AC-19:** original workflow AC numbering remains stable.
20. **BCK20-OD02-REV-AC-20:** specialist/Legal evidence is not inferred.
21. **BCK20-OD02-REV-AC-21:** schema, runtime, Firebase, deployment, push and
    merge remain unauthorized.

## 7. Exact owner decision requested

```text
Одобряю BCK20-OD02-REV-01 v0.1:
Accept with required amendments для combined-owner technical translation-governance boundary.
BCK20-OD-02 остаётся Open; OD-10 остаётся Proposed; BCK-20 остаётся Draft.
Product Localization, Content, Mobile, Security/Privacy и qualified Legal
verdicts, provider selection, schema, runtime, Firebase, deployment, push и
merge не разрешаю.
```

## 8. Recorded owner verdict

On 2026-09-16 the Product owner approved the exact §7 decision. The verdict is
recorded in BCK20-OD02-DEC-01 v0.1 and all sixteen amendments are integrated in
BCK20-OD02-L10N-01 v0.2. BCK20-OD-02 remains Open, OD-10 remains Proposed and
BCK-20 remains Draft. No specialist/Legal verdict or implementation authority
is inferred.
