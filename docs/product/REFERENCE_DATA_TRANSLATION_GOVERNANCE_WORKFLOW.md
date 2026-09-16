# Recharge Backend — Translation Governance Workflow

- ID: **BCK20-OD02-L10N-01**
- Version: **0.2**
- Date: **2026-09-16**
- Status: **Combined-owner technical baseline — specialist evidence pending**
- Decision served: **BCK20-OD-02 — translation source/review workflow**
- Decision status: **Open — technical decision does not close specialist gates**
- Accountable owner: **Product Localization owner**
- Required boundaries: **Reference Data, Content, Mobile, Security/Privacy and qualified Legal where applicable**
- Parent specification: [BCK-20 v0.2.11](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Owner decision input: [BCK20-OWN-DEC-01 v0.1](REFERENCE_DATA_LOCALIZATION_OWNER_DECISION.md)
- Technical review: [BCK20-OD02-REV-01 v0.2](REFERENCE_DATA_TRANSLATION_GOVERNANCE_OWNER_REVIEW.md)
- Technical decision: [BCK20-OD02-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_GOVERNANCE_OWNER_DECISION.md)
- LocalizedText input: [BCK-D1-OD10-EV-01 v0.1](BACKEND_OD_10_LOCALIZATION_EVIDENCE.md)
- Runtime effect: **none**

## 0. Changelog

### v0.2 — 2026-09-16

- recorded BCK20-OD02-DEC-01 and integrated all sixteen owner-review
  amendments;
- added canonical locale/message identity, conflict and impact propagation,
  approval freshness, atomic publication and safe rollback rules;
- added exception, retention/deletion, portability, metric and withdrawal
  controls while preserving AC-01–25 and appending AC-26–41;
- retained BCK20-OD-02 Open, OD-10 Proposed, BCK-20 Draft and every specialist,
  Legal, schema, runtime and infrastructure gate.

## 1. Purpose and boundary

This document defines how a source string becomes an attributable, reviewed,
approved, published, corrected and withdrawn localized representation. It is a
provider-neutral governance contract, not a translation-management-system
selection and not a runtime implementation plan.

It owns:

- source ownership and immutable revision identity;
- translation provenance and assistance disclosure;
- linguistic, domain, Mobile and qualified Legal review boundaries;
- approval, publication, withdrawal, rollback and emergency correction;
- terminology/glossary governance and audit evidence;
- market isolation for Latvia, Estonia and Lithuania.

It does not own:

- `LocalizedTextV1` wire shape or deterministic fallback — OD-10/BCK-20;
- user-authored content or automatic translation of it — owning domain;
- legal meaning or mandatory-local-copy classes — BCK20-OD-05;
- mobile rendering implementation — BCK-18/Mobile;
- dataset distribution, cache or delta design — BCK20-OD-03;
- schema/toolchain choice — API-DEC-05/BCK20-OD-01;
- credentials, provider selection, procurement, runtime or deployment.

## 2. Non-negotiable invariants

1. Stable IDs, enum values and relationship keys are never translated.
2. A translation always references an immutable source revision and hash.
3. Published text is immutable; corrections create a new revision.
4. Missing, stale, rejected, withdrawn and unsupported are typed states.
5. Human or machine assistance never publishes automatically.
6. Translator, reviewer, approver and publisher actions are attributable.
7. Mandatory/high-impact text receives independent review.
8. Qualified Legal approval cannot be inferred from linguistic review.
9. `contentLocale`, viewer locale and translation target locale stay distinct.
10. Latvia approval cannot activate Estonia or Lithuania.
11. A disabled market never receives another market's text as activation proof.
12. Secrets, credentials, private user content and unnecessary personal data
    never enter a translation tool or provider.
13. Withdrawal cannot silently expose an older unsafe translation.
14. Missing mandatory copy disables the affected surface; it does not fall
    back unless the exact qualified policy explicitly allows it.
15. Locale aliases are canonicalized before identity comparison; aliases
    cannot create competing effective translations.
16. Policy conflict, unknown change impact and invalid approval are blocking
    states, never silent translator choices.
17. Publication is an atomic immutable-manifest operation and does not itself
    activate a market, feature or client rollout.
18. Rollback cannot resurrect withdrawn, erased, restricted, expired or
    otherwise invalid text.
19. Temporary exceptions cannot bypass mandatory independence, Legal,
    privacy, stable-ID or market-isolation controls.

## 3. Translation classes and review depth

| Class | Examples | Minimum review | Fallback/activation treatment |
|---|---|---|---|
| `identifier` | IDs, enum codes, schema keys, currency/market codes | not translatable | exact canonical value only |
| `reference_standard` | category labels, filters, neutral taxonomy descriptions | translator plus Product Localization review | deterministic OD-10 fallback may apply |
| `product_high_impact` | account, booking, payment-adjacent, privacy or destructive-action UI | translator, independent linguistic reviewer, owning-domain and Mobile review | fail closed where incorrect text could change informed action |
| `legal_safety_mandatory` | terms, consent, age/safety, rights, emergency or mandatory notices | translator, independent reviewer, qualified Legal/Product approval and exact market/locale revision | `fallbackForbidden` unless qualified policy says otherwise |
| `user_authored` | titles, descriptions, comments, messages | outside this workflow by default | no silent translation; explicit separate feature required |

The source owner assigns a class before translation begins. Classification may
only be raised during review, never silently lowered to reduce controls.
High-impact and mandatory review applies to every unit. Sampling is permitted
only for `reference_standard` under a separately approved sampling plan with
thresholds, escalation and whole-batch failure rules.

Any future translation of `user_authored` content requires an independent
consent, provenance, moderation, privacy and deletion contract. It cannot enter
reference-data authority or treat this workflow as implicit permission.

## 4. Roles and separation of duties

| Role | Authority | Prohibited shortcut |
|---|---|---|
| Source owner | owns meaning, source locale/revision and change reason | cannot treat translated text as a new source of truth |
| Product Localization owner | owns workflow, terminology, locale quality and release coordination | cannot provide qualified Legal judgment by role label alone |
| Translator | produces target text and records method/provenance | cannot self-approve mandatory/high-impact output |
| Linguistic reviewer | checks meaning, grammar, terminology and locale fitness | cannot approve a source revision they did not inspect |
| Domain reviewer | checks product/domain meaning and prohibited ambiguity | cannot change canonical IDs/contracts through wording |
| Mobile reviewer | checks layout, accessibility, truncation and state semantics | cannot weaken missing/fail-closed behavior to fit UI |
| Qualified Legal reviewer | approves exact market/locale/revision where legal judgment applies | approval is not transferable to another market/revision |
| Approver | accepts the completed evidence bundle for its bounded scope | cannot approve missing mandatory evidence |
| Publisher | publishes an already approved immutable manifest | cannot edit text or broaden scope during publication |

One person may hold multiple roles for `reference_standard` during early
documentation, but the combination is disclosed. For `product_high_impact`
and `legal_safety_mandatory`, translator and independent reviewer must be
different attributable identities. Product-owner coordination or Codex review
does not satisfy specialist or qualified Legal independence.
Reviewers disclose conflicts of interest; a conflicted identity cannot satisfy
the independent-review requirement.

## 5. Canonical records

These are semantic records, not authorized database collections.

### 5.1 Source snapshot

```text
TranslationSourceSnapshot {
  recordFamily
  stableRecordId
  fieldId
  sourceLocale
  canonicalSourceLocale
  marketConfigRevision
  messageFormatVersion
  placeholderSchemaHash
  sourceRevision
  sourceHash
  sourceText
  translationClass
  glossaryRevision
  owningDomain
  changeReason
  createdAtUtc
}
```

### 5.2 Translation candidate

```text
TranslationCandidate {
  candidateId
  sourceRevision
  sourceHash
  targetLocale
  canonicalTargetLocale
  marketConfigRevision
  messageFormatVersion
  placeholderSchemaHash
  translatedText
  method: human | human_assisted
  translatorIdentity
  providerProvenance?
  assistanceDisclosure?
  glossaryRevision
  createdAtUtc
}
```

`machine_only` is not a publishable method in v1. Assisted output is a draft
and receives the same review as human output.

### 5.3 Review and approval

```text
TranslationReviewRecord {
  reviewId
  candidateId
  reviewerIdentity
  reviewerRole
  reviewedSourceRevision
  reviewedGlossaryRevision
  verdict: accept | changes_requested | reject | inconclusive
  findingIds[]
  reviewedAtUtc
}

TranslationApprovalRecord {
  approvalId
  candidateId
  marketId
  locale
  canonicalLocale
  marketConfigRevision
  messageFormatVersion
  placeholderSchemaHash
  approvedScope
  requiredReviewIds[]
  legalPolicyRevision?
  status: active | revoked | expired | superseded
  reviewDueAtUtc?
  expiresAtUtc?
  revokedReason?
  approverIdentity
  approvedAtUtc
}
```

### 5.4 Publication and correction

```text
TranslationPublicationManifest {
  manifestId
  marketId
  locale
  canonicalLocale
  marketConfigRevision
  messageFormatVersion
  placeholderSchemaHash
  datasetRevision
  sourceRevisionSetHash
  manifestIntegrityHash
  expectedCurrentManifestRevision
  approvalIds[]
  candidateIds[]
  publishedAtUtc
  publicationCommitResult: committed | conflict | unknown
}

TranslationCorrectionRecord {
  correctionId
  supersededCandidateId
  replacementCandidateId?
  reason
  severity: normal | urgent | safety_critical
  affectedMarkets[]
  action: supersede | withdraw | disable_surface
  approvedBy
  createdAtUtc
}
```

### 5.5 Impact and exception records

```text
TranslationImpactSet {
  impactSetId
  causeType: source_change | glossary_change | policy_change
  causeRevision
  affectedCandidateIds[]
  affectedManifestIds[]
  analysisStatus: complete | incomplete | unknown
  reReviewTaskIds[]
  createdAtUtc
}

TranslationExceptionRecord {
  exceptionId
  boundedScope
  accountableOwner
  rationale
  compensatingControls[]
  approvedBy
  expiresAtUtc
  status: active | expired | revoked | closed
  closureEvidenceIds[]
}
```

Every ID is immutable and every relationship is ID-based. The future physical
schema follows BCK-03/BCK-20 decisions and is not selected here.

## 6. Lifecycle state machine

```text
source_frozen
  -> translation_draft
  -> linguistic_review
  -> domain_mobile_review
  -> legal_review_required? -> legal_review
  -> approved
  -> published
  -> superseded | withdrawn
```

Allowed return paths:

- any review may return `changes_requested` to a new candidate revision;
- `reject` closes the candidate without mutating its evidence;
- `inconclusive` blocks progression until missing authority/evidence exists;
- a source revision change marks linked unpublished candidates, reviews and
  approvals stale; prior text may seed a new candidate but no record is rebound
  to the new source revision;
- a glossary revision change triggers review according to affected term scope;
- source, glossary or policy change creates an attributable impact set and
  re-review queue; unknown impact blocks high-impact and mandatory publication;
- revoked, expired or superseded approvals cannot publish, roll back or
  authorize cached artifacts;
- published text is never returned to Draft or edited in place.

## 7. Standard workflow

1. **Intake:** source owner supplies stable record/field IDs, source locale,
   meaning, class, context, screenshots where safe, and change reason.
2. **Freeze source:** calculate immutable revision/hash and reject mutable or
   unidentified source input.
3. **Prepare context:** attach glossary revision, character/layout constraints,
   placeholders and prohibited substitutions without secrets or user data.
4. **Translate:** create one candidate per target locale with attributable
   translator and method/provenance.
5. **Validate structure:** preserve placeholders, markup, plural/select syntax,
   URLs/policy IDs and bounded length rules; never alter canonical IDs.
6. **Linguistic review:** compare against exact source, glossary and locale
   conventions; emit typed findings.
7. **Domain review:** verify product meaning and consequence-sensitive wording.
8. **Mobile review:** verify layout, accessibility, scaling, truncation,
   right state/error meaning and screen-reader behavior.
9. **Legal review if required:** bind approval to exact market, locale, source,
   candidate and policy revision.
10. **Approve:** ensure every class-required review is accepted and current.
11. **Publish manifest:** compare the expected-current revision, verify
    integrity and atomically publish the exact immutable candidate set.
    Publication cannot edit content or activate a market, feature or client
    rollout.
12. **Observe:** collect missing/stale/rendering signals without logging text or
    personal data by default.
13. **Correct or withdraw:** create a new candidate/correction record and
    preserve full evidence; never overwrite published history.

## 8. Placeholders, formatting and terminology

- placeholders are named and typed; translation cannot add, remove or change
  their type;
- plural/select branches must be complete for the chosen message format;
- HTML/Markdown or rich-text capability is allowlisted by record family;
- links use approved stable targets or policy references, never translator-
  supplied arbitrary destinations;
- glossary terms have stable IDs, source definition, allowed translations,
  prohibited variants, domain and revision;
- a glossary conflict is a review finding, not an invitation to create a local
  private term;
- length limits are UI evidence inputs, not permission to remove legal or
  safety meaning;
- bidi/control characters and suspicious Unicode are validated and surfaced.

Source meaning, approved glossary, product/domain policy and qualified Legal
policy are independent authorities. A contradiction becomes a typed blocking
finding routed to the accountable owners. A translator cannot resolve it by
choosing wording or silently changing source meaning.

## 9. Machine assistance and external providers

Machine assistance may be used only when a later Approved tool/provider policy
allows it. The policy must record provider, region, data-use terms, retention,
subprocessors, access control and deletion behavior.

Regardless of provider:

- only minimum necessary source/context is sent;
- secrets, credentials, private user content and personal data are excluded;
- provider output is untrusted draft input;
- prompt/output cannot become authority, policy or canonical ID;
- human review depth does not decrease;
- provider/model/version and assistance disclosure are attributable;
- kill switch and export/delete capability are required before production use;
- a complete attributable portable export must preserve IDs, revisions,
  provenance, findings and approval links without depending on one vendor;
- no provider account, API key, upload or paid service is authorized here.

If safe provider use is not approved, translation remains human/offline and the
workflow still functions.

## 10. Privacy and security

- translation input is product/reference copy, not production database data;
- screenshots/context are sanitized before leaving the owning team;
- access is least-privilege by market, locale, record family and task;
- exported work packages have bounded lifetime and attributable recipients;
- source, candidate, review, approval, publication, correction, audit and
  temporary work-package artifacts have distinct retention classes; exact
  periods remain a later Security/Privacy/Legal decision;
- temporary provider exports have deletion deadlines plus confirmed- or
  failed-deletion evidence while the lawful minimum immutable audit remains;
- logs contain IDs, revisions, verdicts and timing, not source/translated text
  by default;
- audit records preserve who viewed, changed, reviewed, approved, published,
  withdrew or exported a unit;
- suspicious links, markup, Unicode, instructions or embedded secrets are
  rejected/quarantined;
- revoked users/providers lose access and cannot publish with cached approval;
- old approval cannot authorize a changed source, glossary or target text.

## 11. Baltic market policy

### Latvia

- launch product locales remain `lv-LV`, `en` and `ru` as BCK-20 inputs;
- every publication is market-scoped to `LV` and exact locale/revision;
- mandatory Latvian or other legally required copy is decided only through
  BCK20-OD-05/qualified policy;
- supported product locale does not automatically mean every record is
  mandatory or legally approved in that locale.

### Estonia and Lithuania

- `EE` and `LT` stay disabled independently;
- pretranslation may be prepared but cannot publish/activate the market;
- Latvia approval, glossary, fallback or publication manifest is not evidence
  for Estonian/Lithuanian activation;
- additional locale policy remains BCK20-OD-04 and is Deferred;
- market-specific Legal, support, content and Product evidence is required.

## 12. Emergency correction and withdrawal

1. Classify the issue as normal, urgent or safety-critical.
2. Identify exact candidate, manifest, markets, locales and surfaces.
3. Stop further publication of the affected revision.
4. If safe fallback is explicitly allowed, activate only the approved prior
   compatible candidate after current compatibility and approval checks;
   otherwise withdraw or disable the affected surface. Never restore
   withdrawn, erased, restricted, expired or legally invalid text.
5. Create a correction record and new immutable candidate where applicable.
6. Apply the same mandatory review depth; an emergency may shorten timing but
   cannot erase attribution, Legal authority or post-review.
7. Publish a new manifest or explicit withdrawal marker.
8. Reconcile caches/search/projections and verify the unsafe revision no longer
   resolves.
9. Record root cause, affected interval and preventive action.

Candidate withdrawal, manifest revocation and surface disablement are distinct
typed actions. The applicable incident and accountable owners are notified;
exact response SLAs remain BCK-05 scope.

For safety/legal copy, “show any available language” is not an emergency
fallback. Fail closed unless exact policy permits otherwise.

## 13. Concurrency, idempotency and stale work

- candidate creation uses a logical key of source revision + target locale +
  translation task identity and an immutable candidate ID;
- retry with the same semantic input is idempotent; changed text creates a new
  candidate or conflict, never an overwrite;
- approval checks current source, candidate, glossary, market and policy
  revisions atomically at its authority boundary;
- canonical BCP 47 locale, effective `MarketConfig`, message-format version and
  placeholder-schema hash participate in identity and freshness checks;
- two approvals cannot make two candidates simultaneously effective for the
  same record/field/market/locale/revision;
- late reviews against superseded input are stored as stale evidence and cannot
  publish;
- timeout/unknown outcome is reconciled by querying the authoritative record,
  not by inventing success.
- partial publication and expected-current mismatch return a typed conflict;
  retry first reads the authoritative manifest state.

Temporary exceptions use immutable `TranslationExceptionRecord` evidence.
They expire fail-closed and cannot bypass stable IDs, market isolation,
secrets/privacy restrictions, independent high-impact review or qualified
Legal approval for mandatory copy.

## 14. Evidence and quality gates

Required documentation evidence before BCK20-OD-02 Acceptance:

- class-to-review matrix approved by Product Localization, Content and Mobile;
- exact role/separation rules and attributable review template;
- LV sample set covering exact, fallback, missing, long text, placeholders,
  plural/select, accessibility and correction/withdrawal;
- EE/LT disabled-state examples;
- provider-neutral privacy/security checklist;
- emergency withdrawal and unsafe-fallback tabletop on paper;
- approval revocation/expiry, policy conflict, unknown impact, atomic publish
  conflict, exception expiry and provider-export deletion vectors;
- BCK20-OD-05 boundary explicitly retained for mandatory Legal/safety copy;
- migration/rollback statement and exact future executable gate.

Workflow metrics may use privacy-safe IDs, state transitions, timing and
validated defect counts. Raw product text and personal data are excluded by
default. Metrics cannot auto-publish, reduce review depth or prove Legal
correctness.

Future executable evidence, separately authorized, includes contract fixtures,
repository/provider adapter tests, role enforcement, immutable publication,
cache/projection reconciliation and Mobile layout/accessibility checks.

A skipped, timed-out, unattributable or non-reproducible check is Inconclusive.

## 15. Typed failures

| Failure | Meaning / required outcome |
|---|---|
| `source_revision_stale` | source changed; candidate/review cannot advance |
| `glossary_revision_stale` | affected terminology must be re-reviewed |
| `translation_missing` | no approved candidate; apply only allowed fallback or fail closed |
| `translation_rejected` | candidate is immutable rejected evidence |
| `translation_withdrawn` | candidate cannot resolve or republish |
| `manifest_revoked` | manifest cannot resolve and prior text is not exposed |
| `surface_disabled` | affected surface remains fail-closed |
| `review_missing` | class-required review absent |
| `review_inconclusive` | authority/evidence insufficient |
| `legal_approval_required` | mandatory scope remains disabled |
| `market_disabled` | no publication/activation for the market |
| `placeholder_mismatch` | structural validation fails |
| `unsupported_locale` | locale is outside effective MarketConfig |
| `publication_conflict` | competing current candidate/revision exists |
| `unknown_outcome` | query authoritative state; do not report success |
| `provider_disabled` | use approved human/offline route or stop |
| `policy_conflict` | accountable authorities must reconcile meaning |
| `approval_revoked` | candidate cannot publish, resolve or roll back |
| `approval_expired` | fresh approval evidence is required |
| `manifest_integrity_failed` | publication is rejected atomically |
| `exception_expired` | exception scope fails closed |
| `impact_unknown` | high-impact/mandatory scope remains blocked |
| `deletion_unconfirmed` | provider artifact requires escalation/evidence |

## 16. Rollback and migration

Before runtime exists, rollback is a new documentation revision superseding
this baseline. No data migration exists.

Future rollout must import only approved immutable records with provenance,
dry-run validation, counts/hashes, checkpointing, reject report and rollback to
a previously compatible, currently authorized manifest. Current approval,
withdrawal, restriction and Legal-policy checks run before restoration; an
older manifest is never assumed safe merely because it once published.
Local/mock strings are migration candidates,
not automatically approved translations. No existing app string is silently
reclassified as Legal-approved or source-authoritative.

## 17. Open items retained

- BCK20-OD02-DEC-01 accepts the v0.2 combined-owner technical workflow
  boundary with amendments integrated; BCK20-OD-02 remains Open until required
  Product Localization, Content, Mobile, Security/Privacy and applicable
  qualified Legal evidence accepts the exact revision.
- BCK20-OD-05 remains Open for mandatory copy and fallback-forbidden classes.
- OD-10 remains Proposed.
- API-DEC-05 and BCK20-OD-01 remain Deferred.
- BCK20-OD-03/04/06/07 remain Deferred under BCK20-OWN-DEC-01.
- Provider/tool selection, schema, distribution, Mobile runtime and metrics are
  future separately Approved work.

## 18. Acceptance criteria

1. **BCK20-OD02-AC-01:** translation governance is separate from OD-10 fallback.
2. **BCK20-OD02-AC-02:** stable IDs and enum values are never translated.
3. **BCK20-OD02-AC-03:** every candidate binds immutable source revision/hash.
4. **BCK20-OD02-AC-04:** published translations are immutable revisions.
5. **BCK20-OD02-AC-05:** user-authored content is excluded by default.
6. **BCK20-OD02-AC-06:** class determines minimum review depth.
7. **BCK20-OD02-AC-07:** high-impact translator and reviewer are independent.
8. **BCK20-OD02-AC-08:** Legal approval is exact market/locale/revision scoped.
9. **BCK20-OD02-AC-09:** combined-owner/Codex review is not specialist evidence.
10. **BCK20-OD02-AC-10:** machine assistance is draft-only and attributable.
11. **BCK20-OD02-AC-11:** secrets/private user data never enter tooling.
12. **BCK20-OD02-AC-12:** placeholders/formatting/links are structurally checked.
13. **BCK20-OD02-AC-13:** glossary changes are revisioned and reviewable.
14. **BCK20-OD02-AC-14:** Mobile layout/accessibility review cannot weaken meaning.
15. **BCK20-OD02-AC-15:** Latvia approval cannot activate EE/LT.
16. **BCK20-OD02-AC-16:** disabled markets have no cross-market fallback activation.
17. **BCK20-OD02-AC-17:** emergency correction never mutates published history.
18. **BCK20-OD02-AC-18:** unsafe mandatory copy withdraws/disables fail-closed.
19. **BCK20-OD02-AC-19:** stale reviews and approvals cannot publish.
20. **BCK20-OD02-AC-20:** timeout/unknown outcome never invents success.
21. **BCK20-OD02-AC-21:** typed failures cover missing/rejected/withdrawn states.
22. **BCK20-OD02-AC-22:** local/mock strings are not automatically approved.
23. **BCK20-OD02-AC-23:** provider/tool selection remains separately gated.
24. **BCK20-OD02-AC-24:** OD-05/OD-10/API-DEC-05 remain unchanged.
25. **BCK20-OD02-AC-25:** this baseline authorizes no schema, runtime,
    Firebase, deployment, push or merge.
26. **BCK20-OD02-AC-26:** locale, MarketConfig, message format and placeholder
    schema are canonical revision-bound identity inputs.
27. **BCK20-OD02-AC-27:** policy conflicts block and route to accountable owners.
28. **BCK20-OD02-AC-28:** source/glossary/policy changes create attributable
    impact and re-review evidence.
29. **BCK20-OD02-AC-29:** revoked, expired or superseded approvals cannot
    publish or roll back.
30. **BCK20-OD02-AC-30:** manifest publication is integrity-checked and atomic.
31. **BCK20-OD02-AC-31:** publication cannot imply market, feature or client
    activation.
32. **BCK20-OD02-AC-32:** rollback cannot resurrect invalid text.
33. **BCK20-OD02-AC-33:** exceptions are attributable, expiring and cannot
    bypass mandatory controls.
34. **BCK20-OD02-AC-34:** high-impact and mandatory review is per unit and
    independently attributable.
35. **BCK20-OD02-AC-35:** retention classes and provider-export deletion
    require explicit policy and evidence.
36. **BCK20-OD02-AC-36:** provider portability preserves complete governance
    relationships without selecting a vendor schema.
37. **BCK20-OD02-AC-37:** metrics cannot auto-publish, weaken review or prove
    Legal correctness.
38. **BCK20-OD02-AC-38:** candidate withdrawal, manifest revocation and surface
    disablement are distinct.
39. **BCK20-OD02-AC-39:** user-authored translation remains separately gated.
40. **BCK20-OD02-AC-40:** the expanded typed-failure vocabulary never becomes
    silent fallback.
41. **BCK20-OD02-AC-41:** AC-01–25 retain their identifiers unchanged.

## 19. Recorded technical owner decision

On 2026-09-16 the Product owner accepted BCK20-OD02-REV-01 v0.1 with required
amendments for the combined-owner technical translation-governance boundary.
This v0.2 integrates all sixteen amendments and records the bounded verdict in
BCK20-OD02-DEC-01 v0.1. BCK20-OD-02 stays Open, OD-10 stays Proposed and BCK-20
stays Draft. No specialist/Legal verdict, provider, schema, runtime, Firebase,
deployment, push or merge authority is created.
