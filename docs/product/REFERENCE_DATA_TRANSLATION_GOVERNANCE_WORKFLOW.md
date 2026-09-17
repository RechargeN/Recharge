# Recharge Backend — Translation Governance Workflow

- ID: **BCK20-OD02-L10N-01**
- Version: **0.4**
- Date: **2026-09-17**
- Status: **Corrected combined-owner technical baseline — owner review pending**
- Decision served: **BCK20-OD-02 — translation source/review workflow**
- Decision status: **Open — technical decision does not close specialist gates**
- Accountable owner: **Product Localization owner**
- Required boundaries: **Reference Data, Content, Mobile, Security/Privacy and qualified Legal where applicable**
- Parent specification: [BCK-20](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Owner decision input: [BCK20-OWN-DEC-01 v0.1](REFERENCE_DATA_LOCALIZATION_OWNER_DECISION.md)
- Technical review: [BCK20-OD02-REV-01 v0.2](REFERENCE_DATA_TRANSLATION_GOVERNANCE_OWNER_REVIEW.md)
- Technical decision: [BCK20-OD02-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_GOVERNANCE_OWNER_DECISION.md)
- Product/Content pre-review: [BCK20-OD02-PC-PRE-01 v0.2](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_PRE_REVIEW.md)
- Pre-review decision: [BCK20-OD02-PC-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_PRE_REVIEW_DECISION.md)
- Mobile/Security pre-review: [BCK20-OD02-MS-PRE-01 v0.2](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW.md)
- Mobile/Security pre-review decision: [BCK20-OD02-MS-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW_DECISION.md)
- LocalizedText input: [BCK-D1-OD10-EV-01 v0.1](BACKEND_OD_10_LOCALIZATION_EVIDENCE.md)
- Runtime effect: **none**

## 0. Changelog

### v0.4 — 2026-09-17

- recorded BCK20-OD02-MS-PRE-DEC-01 and integrated MS-F-001–MS-F-007 before
  Mobile and Security/Privacy owner review;
- bound render-profile compatibility and current scoped actor authority to the
  immutable evidence chain;
- defined atomic consumer installation, monotonic invalidation precedence and
  trusted-origin verification without selecting a distribution mechanism;
- added a conservative BCK-04-aligned translation-artifact inventory and a
  final-render safe rich-content contract;
- preserved AC-01–50 and appended AC-51–62;
- retained v0.3 Product/Content verdicts as historical exact-hash evidence,
  with explicit v0.4 revalidation required;
- retained BCK20-OD-02 Open, OD-10 Proposed, BCK-20 Draft, BCK20-OD-03
  Deferred and every provider/schema/runtime/infrastructure gate.

### v0.3 — 2026-09-17

- recorded BCK20-OD02-PC-PRE-DEC-01 and integrated F-001–F-008 before named
  Product Localization/Content review;
- completed the source snapshot/candidate ID chain and added an unpopulated
  source-authority matrix template;
- separated immutable publication manifest intent from attributable commit
  receipt, completed revoke/correction/impact/exception audit fields and bound
  locale-normalization profile revisions;
- clarified mandatory Legal plus Product/domain approval semantics;
- preserved AC-01–41 and appended AC-42–50;
- retained both specialist signatures Pending, BCK20-OD-02 Open, OD-10
  Proposed, BCK-20 Draft and all provider/schema/runtime gates.

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
20. Render capability is revision-bound; an unsupported render profile is an
    atomic typed state, never permission to partially interpret content.
21. A consumer activates one complete verified manifest revision atomically;
    mixed-revision key merging is forbidden.
22. Revoke, withdraw and disable markers are monotonic authority state and win
    over cache, retry, restore and rollback.
23. Actor identity and capability are resolved by a trusted authority and
    revalidated for every privileged action; client or provider role claims are
    never authority.
24. Every translation artifact inherits an explicit BCK-04 data class and
    remains non-public until a sanitized approved projection says otherwise.
25. A matching integrity hash does not prove trusted origin, publisher,
    environment, market or current authorization.
26. Translated text remains untrusted through final rendering; raw executable
    markup and arbitrary translator-supplied destinations are forbidden.

## 3. Translation classes and review depth

| Class | Examples | Minimum review | Fallback/activation treatment |
|---|---|---|---|
| `identifier` | IDs, enum codes, schema keys, currency/market codes | not translatable | exact canonical value only |
| `reference_standard` | category labels, filters, neutral taxonomy descriptions | translator plus Product Localization review | deterministic OD-10 fallback may apply |
| `product_high_impact` | account, booking, payment-adjacent, privacy or destructive-action UI | translator, independent linguistic reviewer, owning-domain and Mobile review | fail closed where incorrect text could change informed action |
| `legal_safety_mandatory` | terms, consent, age/safety, rights, emergency or mandatory notices | translator, independent reviewer, qualified Legal approval plus Product/domain approval where exact policy requires it, bound to exact market/locale revision | `fallbackForbidden` unless qualified policy says otherwise |
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
  sourceSnapshotId
  recordFamily
  stableRecordId
  fieldId
  sourceLocale
  canonicalSourceLocale
  marketConfigRevision
  localeNormalizationProfileRevision
  messageFormatVersion
  renderProfileRevision
  placeholderSchemaHash
  sourceRevision
  sourceHash
  sourceText
  translationClass
  glossaryRevision
  owningDomain
  sourceOwnerIdentity
  sourceAuthorityEvidenceId
  changeReason
  createdAtUtc
}
```

### 5.2 Translation candidate

```text
TranslationCandidate {
  candidateId
  sourceSnapshotId
  sourceRevision
  sourceHash
  targetLocale
  canonicalTargetLocale
  marketConfigRevision
  localeNormalizationProfileRevision
  messageFormatVersion
  renderProfileRevision
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
  reviewerAuthorityEvidenceId
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
  localeNormalizationProfileRevision
  messageFormatVersion
  renderProfileRevision
  placeholderSchemaHash
  approvedScope
  requiredReviewIds[]
  legalPolicyRevision?
  status: active | revoked | expired | superseded
  reviewDueAtUtc?
  expiresAtUtc?
  revokedReason?
  revokedBy?
  revokedAtUtc?
  revocationEvidenceId?
  approverIdentity
  approverAuthorityEvidenceId
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
  localeNormalizationProfileRevision
  messageFormatVersion
  renderProfileRevision
  placeholderSchemaHash
  datasetRevision
  sourceRevisionSetHash
  manifestIntegrityHash
  expectedCurrentManifestRevision
  approvalIds[]
  candidateIds[]
  createdAtUtc
}

TranslationPublicationReceipt {
  publicationAttemptId
  logicalIdempotencyKey
  manifestId
  manifestIntegrityHash
  expectedCurrentManifestRevision
  publisherIdentity
  publisherAuthorityEvidenceId
  result: committed | conflict | unknown
  authoritativeCurrentManifestId?
  authoritativeCurrentManifestRevision?
  committedAtUtc?
  observedAtUtc
}

TranslationCorrectionRecord {
  correctionId
  targetType: candidate | manifest | surface
  targetId
  replacementId?
  reason
  severity: normal | urgent | safety_critical
  resolutionRevision
  effectiveAtUtc
  affectedMarkets[]
  affectedLocales[]
  affectedSurfaceIds[]
  action: supersede | withdraw_candidate | revoke_manifest | disable_surface
  approvedBy
  approvedByAuthorityEvidenceId
  createdAtUtc
}
```

### 5.5 Impact and exception records

```text
TranslationImpactSet {
  impactSetId
  causeType: source_change | glossary_change | policy_change
  causeRevision
  affectedSourceSnapshotIds[]
  affectedRecordFieldIds[]
  affectedGlossaryTermIds[]
  affectedCandidateIds[]
  affectedManifestIds[]
  analysisStatus: complete | incomplete | unknown
  completenessRationale
  analyzerIdentity
  analyzedAtUtc
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
  approvedByAuthorityEvidenceId
  createdAtUtc
  expiresAtUtc
  status: active | expired | revoked | closed
  closedAtUtc?
  closedBy?
  closureReason?
  closureEvidenceIds[]
}
```

### 5.6 Source-authority matrix template

```text
TranslationSourceAuthorityEntry {
  recordFamily
  fieldScope
  owningDomain
  accountableSourceOwnerRole
  sourceLocale
  defaultTranslationClass
  minimumReviewClass
  policyReferenceIds[]
  fallbackPolicyReference?
}
```

This revision defines only the required template. It does not populate owner or
policy values. Named Content/Product Localization owners supply and approve
that content; missing entries remain blocked rather than inferred.

### 5.7 Translation-artifact data inventory seed

This seed applies BCK-04 conservatively without selecting storage or inventing
Legal conclusions. Every future schema inventory must additionally complete
all BCK-04 §6.1 fields, including data subjects, legal basis, recipients,
processor/transfer references, retention trigger, rights handling, backup,
region, ROPA and DPIA references.

| Record/artifact family | Baseline class | Purpose/access boundary | Publication treatment |
|---|---|---|---|
| `TranslationSourceSnapshot` | Protected before publication | exact source meaning; task-scoped source/reviewer access | only sanitized approved field output may become Public |
| `TranslationCandidate` | Protected before publication | translation/review task participants | never Public merely because a candidate exists |
| `TranslationReviewRecord` | Operational | attributable reviewers and governance operators | no public projection |
| `TranslationApprovalRecord` | Operational | approvers/publishers and audit operators | bounded status may accompany an authorized projection |
| `TranslationPublicationManifest` | Operational | publication control plane and trusted consumers | manifest metadata is not automatically public copy |
| `TranslationPublicationReceipt` | Operational | publisher, reconciliation and audit operators | no public projection |
| `TranslationCorrectionRecord` | Operational | incident/governance operators and affected owners | only bounded withdrawal/disabled state is exposed |
| `TranslationImpactSet` | Operational | source/glossary/policy owners and reviewers | no public projection |
| `TranslationExceptionRecord` | Operational | accountable owner, approver and audit operators | no public projection |
| `TranslationSourceAuthorityEntry` | Operational until approved | source-governance operators | separately approved reference fields may project Public |
| temporary context, screenshot, work package or provider export | highest inherited field class | named task recipient only, bounded lifetime | never a public projection; undeclared personal/Sensitive content is rejected or separately authorized |

Reviewer/translator identities, provenance and access/export evidence are not
Public merely because the translated product copy may later be public. Exact
legal basis, numeric retention, processor/transfer, ROPA and DPIA evidence
remain BCK-04/qualified-owner gates before production processing.

Every ID is immutable and every relationship is ID-based. The future physical
schema follows BCK-03/BCK-20 decisions and is not selected here.
`manifestIntegrityHash` is calculated over the canonical immutable manifest
payload excluding the hash field itself and every receipt/outcome field.
The hash proves deterministic payload integrity only; it does not authenticate
the publisher or trusted origin. `renderProfileRevision` participates in
identity, compatibility and freshness checks for source, candidate, approval
and manifest.
For a revoked approval, `revokedReason`, `revokedBy`, `revokedAtUtc` and
`revocationEvidenceId` are required together. For an exception, closure fields
are required together only in `closed`; incoherent combinations fail closed.
Correction target/action combinations are closed: `supersede` targets a
candidate and requires a replacement candidate, `withdraw_candidate` targets a
candidate, `revoke_manifest` targets a manifest and `disable_surface` targets
a surface. Every other combination is rejected. For `product_high_impact` and
`legal_safety_mandatory`, an `incomplete` or `unknown` impact set blocks
approval and publication until a new attributable `complete` analysis exists.
Each revoke, withdraw or disable action advances a strictly monotonic
`resolutionRevision` at the owning authority boundary. A lower or missing
revision cannot clear or replace a newer tombstone/disable marker.

Every authority-evidence ID is immutable and refers to a trusted-system
decision for the exact actor, scope, action and time. Reviewer, approver,
publisher, corrector and exception authority is revalidated at the action;
client-declared or provider-declared identities/capabilities are never trusted
as authorization.

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
- a render-profile revision change marks incompatible candidates, approvals
  and manifests stale until explicit compatible review exists;
- source, glossary or policy change creates an attributable impact set and
  re-review queue; unknown impact blocks high-impact and mandatory publication;
- revoked, expired or superseded approvals cannot publish, roll back or
  authorize cached artifacts;
- a newer revoke/withdraw/disable resolution always dominates an older cached,
  restored or replayed manifest;
- published text is never returned to Draft or edited in place.

## 7. Standard workflow

1. **Intake:** resolve a specialist-approved source-authority matrix entry;
   source owner supplies stable record/field IDs, source locale, meaning,
   class, context, screenshots where safe, authority evidence and change reason.
2. **Freeze source:** calculate immutable revision/hash and reject mutable or
   unidentified source input.
3. **Prepare context:** attach glossary and render-profile revisions,
   character/layout constraints, placeholders and prohibited substitutions
   without secrets or user data.
4. **Translate:** create one candidate per target locale with attributable
   translator and method/provenance.
5. **Validate structure:** preserve placeholders, canonical safe markup nodes,
   plural/select syntax, approved target/policy IDs and bounded length rules;
   reject raw executable markup, arbitrary URIs and altered canonical IDs.
6. **Linguistic review:** compare against exact source, glossary and locale
   conventions; emit typed findings.
7. **Domain review:** verify product meaning and consequence-sensitive wording.
8. **Mobile review:** verify the exact render profile, layout, accessibility,
   scaling, truncation, right state/error meaning and screen-reader behavior.
9. **Legal review if required:** bind approval to exact market, locale, source,
   candidate and policy revision.
10. **Approve:** revalidate trusted actor authority and ensure every
    class-required review is accepted and current.
11. **Publish manifest:** create immutable manifest intent, compare the
    expected-current revision, verify integrity and atomically publish the exact
    candidate set. Record the authoritative outcome in a separate attributable
    receipt. Publication cannot edit content or activate a market, feature or
    client rollout.
12. **Consumer handoff:** only a separately Approved distribution boundary may
    stage a full compatible bundle, verify manifest/hash/revisions and trusted
    origin, then atomically switch its active pointer. Partial activation and
    cross-manifest key merging are forbidden.
13. **Observe:** collect missing/stale/rendering signals without logging text or
    personal data by default.
14. **Correct or withdraw:** create a new candidate/correction record and
    preserve full evidence; never overwrite published history.

## 8. Placeholders, formatting and terminology

- placeholders are named and typed; translation cannot add, remove or change
  their type;
- plural/select branches must be complete for the chosen message format;
- rich-text capability uses canonical structured nodes from the exact
  `renderProfileRevision`; plain text is escaped and unknown nodes fail closed;
- raw executable HTML, scripts, event handlers and arbitrary WebView rendering
  are forbidden;
- links use approved stable targets or policy references, never translator-
  supplied arbitrary destinations;
- link resolution rejects unknown targets and arbitrary URI schemes at the
  final render boundary;
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
- screenshots/context inherit the highest contained data class; undeclared
  personal or Sensitive content is rejected/quarantined rather than entering
  ordinary translation tooling;
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
- every privileged review, approval, publication, correction, exception and
  export action resolves actor and current scoped authority from the trusted
  system and records immutable decision evidence;
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
7. Publish a new manifest or explicit monotonic withdrawal/disable marker with
   the next `resolutionRevision`.
8. Reconcile caches/search/projections; the newest tombstone/disable marker
   wins over cached, restored or replayed content, and the unsafe revision must
   no longer resolve.
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
- canonical BCP 47 locale, effective `MarketConfig`, locale-normalization
  profile, message-format version, render-profile revision and
  placeholder-schema hash participate in identity and freshness checks;
- two approvals cannot make two candidates simultaneously effective for the
  same record/field/market/locale/revision;
- late reviews against superseded input are stored as stale evidence and cannot
  publish;
- timeout/unknown outcome is reconciled by querying the authoritative record,
  not by inventing success.
- partial publication and expected-current mismatch return a typed conflict;
  timeout/unknown outcome and retry first reconcile the authoritative receipt
  and manifest-pointer state.
- a consumer stages and verifies a complete compatible manifest before atomic
  active-pointer switch; interrupted installation leaves the prior complete,
  currently authorized revision or typed unavailable/disabled state;
- an unsupported render profile, trusted-origin mismatch or resolution gap
  fails closed and never produces partial output;
- a trusted-session authority check runs at every privileged action; cached or
  client-declared roles cannot satisfy it.

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
- unsupported render profile, interrupted atomic install, wrong-environment
  manifest, stale actor authority, monotonic tombstone and unsafe rich-content
  vectors;
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
| `render_profile_unsupported` | reject the manifest/bundle atomically; do not partially interpret |
| `unsafe_render_content` | quarantine/reject unsafe node, markup, URI or final-render output |
| `manifest_origin_untrusted` | integrity-valid payload lacks trusted environment/publisher authority |
| `actor_authority_stale` | current scoped authority is absent/revoked; privileged action is denied |
| `resolution_revision_gap` | refresh/reconcile authority state; do not expose older cached content |

## 16. Rollback and migration

Before runtime exists, rollback is a new documentation revision superseding
this baseline. No data migration exists.

Future rollout must import only approved immutable records with provenance,
dry-run validation, counts/hashes, checkpointing, reject report and rollback to
a previously compatible, currently authorized manifest. Current approval,
withdrawal, restriction and Legal-policy checks run before restoration; an
older manifest is never assumed safe merely because it once published.
Consumer migration stages one complete compatible bundle, verifies exact
manifest integrity plus trusted origin and performs an atomic active-pointer
switch. Rollback may select only a complete, compatible and currently
authorized bundle after reconciling the latest `resolutionRevision`; partial
key migration and revoked-cache restoration are forbidden.
Local/mock strings are migration candidates,
not automatically approved translations. No existing app string is silently
reclassified as Legal-approved or source-authoritative.

## 17. Open items retained

- BCK20-OD02-DEC-01 accepts the combined-owner technical workflow boundary;
  BCK20-OD02-PC-PRE-DEC-01 integrates eight technical corrections in v0.3
  before specialist review. BCK20-OD-02 remains Open until required
  Product Localization, Content, Mobile, Security/Privacy and applicable
  qualified Legal evidence accepts the exact revision.
- BCK20-OD02-MS-PRE-DEC-01 integrates seven Mobile/Security technical
  corrections in v0.4. Product/Content verdicts remain historical evidence for
  exact v0.3 and require explicit revalidation for this v0.4 hash; Mobile and
  Security/Privacy verdicts remain Pending.
- BCK20-OD-05 remains Open for mandatory copy and fallback-forbidden classes.
- OD-10 remains Proposed.
- API-DEC-05 and BCK20-OD-01 remain Deferred.
- BCK20-OD-03/04/06/07 remain Deferred under BCK20-OWN-DEC-01.
- Provider/tool selection, schema, distribution, Mobile runtime and metrics are
  future separately Approved work.

## 18. Acceptance criteria

1. **BCK20-OD02-AC-01:** translation governance is separate from OD-10 fallback.
2. **BCK20-OD02-AC-02:** stable IDs and enum values are never translated.
3. **BCK20-OD02-AC-03:** every candidate binds exact immutable source snapshot
   ID, revision and hash.
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
26. **BCK20-OD02-AC-26:** locale, normalization profile, MarketConfig, message
    format and placeholder schema are canonical revision-bound identity inputs.
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
42. **BCK20-OD02-AC-42:** source snapshots and candidates form an immutable
    ID-based authority chain.
43. **BCK20-OD02-AC-43:** source-authority matrix content remains blocked until
    named specialist owners supply it.
44. **BCK20-OD02-AC-44:** immutable manifest intent is separate from
    attributable publication receipt and unknown-outcome reconciliation.
45. **BCK20-OD02-AC-45:** approval revocation records exact actor, time, reason
    and evidence as a coherent set.
46. **BCK20-OD02-AC-46:** correction actions use typed candidate, manifest or
    surface targets.
47. **BCK20-OD02-AC-47:** impact completeness covers source, record-field,
    glossary, candidate and manifest identities with an attributable analyzer.
48. **BCK20-OD02-AC-48:** mandatory Legal approval cannot be replaced by
    Product/domain approval.
49. **BCK20-OD02-AC-49:** exception closure is attributable and state-coherent.
50. **BCK20-OD02-AC-50:** AC-01–41 retain their identifiers unchanged.
51. **BCK20-OD02-AC-51:** the accepted Mobile/Security pre-review corrections
    are integrated before owner verdicts.
52. **BCK20-OD02-AC-52:** render-profile compatibility is revision-bound and an
    unsupported profile fails atomically.
53. **BCK20-OD02-AC-53:** consumer installation cannot expose mixed manifest
    revisions or partial activation.
54. **BCK20-OD02-AC-54:** monotonic resolution state makes revoke, withdrawal
    and disablement dominate cache, retry, restore and rollback.
55. **BCK20-OD02-AC-55:** actor identity and current scoped authority come from
    trusted-system evidence for every privileged action.
56. **BCK20-OD02-AC-56:** all translation artifacts have a conservative
    BCK-04-aligned inventory boundary before physical schema work.
57. **BCK20-OD02-AC-57:** manifest integrity is not treated as publisher,
    environment, market or current-authority authentication.
58. **BCK20-OD02-AC-58:** translated rich content stays untrusted through a
    canonical allowlisted final-render boundary.
59. **BCK20-OD02-AC-59:** typed failures cover unsupported render profile,
    unsafe output, untrusted origin, stale authority and resolution gaps.
60. **BCK20-OD02-AC-60:** Product/Content v0.3 verdicts are historical
    exact-hash evidence and cannot silently authorize v0.4.
61. **BCK20-OD02-AC-61:** BCK20-OD-03 remains Deferred and owns physical
    distribution, cache and delta design.
62. **BCK20-OD02-AC-62:** AC-01–50 retain their identifiers unchanged.

## 19. Recorded technical owner decision

On 2026-09-16 the Product owner accepted BCK20-OD02-REV-01 v0.1 with required
amendments for the combined-owner technical translation-governance boundary.
Version 0.2 integrated all sixteen amendments and recorded the bounded verdict
in BCK20-OD02-DEC-01 v0.1. On 2026-09-17 the Product owner additionally
approved BCK20-OD02-PC-PRE-01 v0.1; this v0.3 integrates F-001–F-008 through
BCK20-OD02-PC-PRE-DEC-01. Both specialist rows remain Pending, BCK20-OD-02 stays
Open, OD-10 stays Proposed and BCK-20 stays Draft. No specialist/Legal verdict,
source-authority content, provider, schema, runtime, Firebase, deployment, push
or merge authority is created.
On 2026-09-17 the Product owner approved BCK20-OD02-MS-PRE-01 v0.1. This v0.4
integrates MS-F-001–MS-F-007 while keeping both Mobile and Security/Privacy
verdicts Pending. The Product/Content v0.3 verdicts remain immutable historical
evidence and require explicit v0.4 revalidation. BCK20-OD-02 remains Open,
OD-10 Proposed, BCK-20 Draft and BCK20-OD-03 Deferred; no implementation or
external-system authority is created.
