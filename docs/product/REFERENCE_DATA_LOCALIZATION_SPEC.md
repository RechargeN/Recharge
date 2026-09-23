# Recharge Backend — Reference Data & Localization Specification

- ID: **BCK-20**
- Version: **0.2.29**
- Date: **2026-09-23**
- Spec status: **Review — D1 reference/localization technical baseline closed; source/legal/market gates retained**
- Runtime status: **Local synthetic disabled LV/EE/LT schemas, repositories, activation pointers and compatibility evidence Present; external-source and production localization runtime Absent**
- Accountable owner: **Reference Data owner**
- Interim review coordinator: **RechargeN / Product owner**
- Local R1 technical decision: **Accepted and verified locally — every market/capability remains disabled**
- Production source/content/Legal approval: **Pending**
- Parent architecture: [BCK-01 v0.4.83](RECHARGE_BACKEND_MASTER_SPEC.md) (Review; local foundation verified)
- Coordination baseline: [BCK-02 v2.4.91](RECHARGE_BACKEND_DELIVERY_MAP.md)
- API boundary: [BCK-03 v0.3.20](BACKEND_API_CONTRACT_STANDARD.md) (Review; local platform contracts verified)
- Security/privacy boundary: [BCK-04 v0.4.31](BACKEND_SECURITY_PRIVACY_SPEC.md) (Review; production gates retained)
- Operations boundary: [BCK-05 v0.2.37](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md) (Review; local R1 verified)
- Canonical taxonomy: [Category System v1.4.3](CATEGORY_SYSTEM.md) (Accepted)
- Delivery annex: [BCK-02-A1](RECHARGE_BACKEND_LATVIA_IMPLEMENTATION_ROADMAP.md) (Draft)
- Owner review: [BCK20-OWN-REV-01 v0.2](REFERENCE_DATA_LOCALIZATION_OWNER_REVIEW.md)
- Owner decision: [BCK20-OWN-DEC-01 v0.1](REFERENCE_DATA_LOCALIZATION_OWNER_DECISION.md)
- Translation workflow: [BCK20-OD02-L10N-01 v0.4](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Translation technical decision: [BCK20-OD02-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_GOVERNANCE_OWNER_DECISION.md)
- Product/Content review package: [BCK20-OD02-PC-REV-01 v0.3](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_REVIEW_PACKAGE.md)
- Product/Content pre-review decision: [BCK20-OD02-PC-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_PRE_REVIEW_DECISION.md)
- Product/Content combined-owner review: [BCK20-OD02-PC-COMB-REV-01 v0.2](REFERENCE_DATA_TRANSLATION_COMBINED_OWNER_REVIEW.md)
- Product/Content combined-owner decision: [BCK20-OD02-PC-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_COMBINED_OWNER_DECISION.md)
- Mobile/Security pre-review: [BCK20-OD02-MS-PRE-01 v0.2](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW.md)
- Mobile/Security pre-review decision: [BCK20-OD02-MS-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW_DECISION.md)
- Product/Content v0.4 revalidation: [BCK20-OD02-PC-REVAL-01 v0.2](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_V04_REVALIDATION.md)
- Mobile review: [BCK20-OD02-MOB-REV-01 v0.2](REFERENCE_DATA_TRANSLATION_MOBILE_OWNER_REVIEW.md)
- Security/Privacy review: [BCK20-OD02-SEC-REV-01 v0.2](REFERENCE_DATA_TRANSLATION_SECURITY_PRIVACY_OWNER_REVIEW.md)
- Exact-v0.4 combined-owner decision: [BCK20-OD02-V04-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_V04_COMBINED_OWNER_DECISION.md)
- Source-authority matrix: [BCK20-OD02-SRC-AUTH-01 v0.2](REFERENCE_DATA_SOURCE_AUTHORITY_MATRIX.md)
- Source-authority decision: [BCK20-OD02-SRC-AUTH-DEC-01 v0.1](REFERENCE_DATA_SOURCE_AUTHORITY_OWNER_DECISION.md)
- Internal source records: [BCK20-OD02-SRC-REC-01 v0.2](REFERENCE_DATA_INTERNAL_SOURCE_RECORDS.md)
- Source-record decision: [BCK20-OD02-SRC-REC-DEC-01 v0.1](REFERENCE_DATA_SOURCE_RECORDS_OWNER_DECISION.md)
- External-evidence plan: [BCK20-OD02-EXT-EV-PLAN-01 v0.2](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_PLAN.md)
- External-evidence plan decision: [BCK20-OD02-EXT-EV-PLAN-DEC-01 v0.1](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_OWNER_DECISION.md)
- EXT-A–D technical baseline decision: [BCK20-OD02-EXT-AD-SRC-TERMS-DEC-01 v0.1](REFERENCE_DATA_EXT_A_D_SOURCE_TERMS_OWNER_DECISION.md)
- External source register: [BCK20-OD02-EXT-EV-01 v0.3](REFERENCE_DATA_EXTERNAL_SOURCE_EVIDENCE_REGISTER.md)
- Qualified terms/access review package: [BCK20-OD02-EXT-AD-TERMS-ACCESS-REV-01 v0.1](REFERENCE_DATA_EXT_A_D_QUALIFIED_TERMS_ACCESS_REVIEW.md)
- OD-10 amended evidence: [BCK-D1-OD10-EV-01 v0.2](BACKEND_OD_10_LOCALIZATION_EVIDENCE.md)
- OD-10 documentation decision: [OD10-DOC-DEC-01 v0.1](BACKEND_OD_10_LOCALIZATION_OWNER_DECISION.md)
- OD-10 multi-owner review: [OD10-OWN-COMB-REV-01 v0.1](BACKEND_OD_10_MULTI_OWNER_REVIEW_PACKAGE.md)
- Source-governance owner review: [BCK20-OD02-SRC-GOV-REV-01 v0.1](REFERENCE_DATA_SOURCE_GOVERNANCE_OWNER_REVIEW.md)
- D1 Owner Batch B review: [BCK-D1-OWN-B-REV-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_B_REVIEW_PACKAGE.md)
- Mandatory-copy policy review: [BCK20-OD05-POL-REV-01 v0.1](REFERENCE_DATA_MANDATORY_COPY_POLICY_REVIEW.md)
- D1 Owner Batch C review: [BCK-D1-OWN-C-REV-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_C_REVIEW_PACKAGE.md)
- Runtime effect: **none**
- Canonical path: `docs/product/REFERENCE_DATA_LOCALIZATION_SPEC.md`

---

## 0. Changelog

### v0.2.29 — 2026-09-23

- records the implemented and verified local synthetic LV/EE/LT reference
  schemas, immutable repositories, activation pointers and compatible
  rollback while every market/capability remains disabled;
- keeps external datasets, source/license eligibility, translations,
  mandatory policy copy, qualified review and production activation absent;
- aligns the platform/API/security/operations references with the Stage 8
  local foundation and changes no OD-10 or acceptance-criteria semantics.

### v0.2.28 — 2026-09-21

- reconciles Reference Data to BCK-01 v0.4.81, BCK-03 v0.3.19, BCK-04
  v0.4.30, BCK-05 v0.2.36 and the sole BCK-02 v2.4.87 R1 manifest;
- separates synthetic local MarketConfig implementation from external-source,
  content, qualified Legal and market-activation approval;
- confirms the two Reference Data collection writers, explicit Money/timezone,
  LV/EE/LT default-off fixtures and compatible-pointer rollback;
- delegates exact owner approval to BCK-02 §29 and changes no schema/runtime.

### v0.2.27 — 2026-09-21

- normalized Reference Data freshness-state enum values to the BCK-03
  lowerCamelCase rule;
- retained snake_case only for registered typed error/reason codes;
- changed no source eligibility, owner, Review status, runtime or market gate.

### v0.2.26 — 2026-09-21

- bound Reference Data to the sole exact R1 manifest in BCK-02 §26;
- specified the exact MarketCapability schema, disabled synthetic fixtures,
  collection writers, indexes, activation-pointer and rollback boundaries;
- retained all external-source, mandatory-copy, translation, Legal, runtime,
  Firebase, deployment and market-activation gates.

### v0.2.25 — 2026-09-21

- hardened `MarketConfigRevision` as a pointer manifest for independent LV/EE/LT
  locale/copy, residency, provider, age, UGC/DSA, retention/DSR and support data;
- defined mandatory-copy no-fallback behavior and currency/timezone semantics;
- separated Reference Data publication from BCK-04 compliance decisions and
  BCK-05 operational release state;
- retained all source/copy/Legal/schema/runtime/activation gates.

### v0.2.24 — 2026-09-20

- added the Stage 2 normalized Reference Data entity inventory;
- made the single writer/readers/revision/activation split explicit for source
  records, datasets, MarketConfig and localization policy;
- aligned Money/time/market/locale terminology and all operational controls
  with BCK-01 §30 and the BCK-02 writer ledger.

### v0.2.23 — 2026-09-20

- accepted LocalizedText v1, deterministic fallback, MarketConfig and
  reference-revision semantics as the D1 technical OD-10 contract;
- separated technical contract readiness from external source eligibility,
  license/terms, qualified mandatory-copy, translation and market-activation
  evidence, all of which remain fail-closed;
- aligned language-neutral schemas with Accepted API-DEC-05 and removed the
  obsolete schema prohibition and stale D1-review routing;
- reconciled BCK-01 v0.4.72, BCK-03 v0.3.16, BCK-04 v0.4.26 and BCK-05
  v0.2.32; fixed the conditional implementation map and next action;
- advanced the specification to Review for exact R1 planning only; no dataset,
  schema artifact, ingestion, Firebase, mobile adapter or market activation is
  authorized.

### v0.2.22 — 2026-09-20

- prepared a conservative mandatory Legal/safety copy classification,
  fail-closed behavior, policy-record boundary and qualified decision matrix;
- prepared Batch C as one owner action over the Product copy boundary,
  external-review routing baseline and factual D1/G1 blocked-state matrix;
- recorded no Product verdict, qualified review, independent review, source
  advancement, OD acceptance or D1/G1 transition;
- retained BCK20-OD-05 Open, OD-10 Proposed, BCK-20 Draft, every market
  disabled and all executable/cloud gates closed.

### v0.2.21 — 2026-09-19

- prepared one exact Batch B owner action covering five separate OD-10
  documentation perspectives and a separate EXT-A–D source-governance
  boundary;
- added bounded field-authority ceilings, freshness classes, future-review
  thresholds, changed-hash, withdrawal and cross-source conflict rules as
  Proposed owner-review input only;
- recorded no verdict, qualified conclusion or source advancement;
- retained OD-10 Proposed, BCK-20 Draft, BCK20-OD-02/05 Open, EXT-G5/G6
  closed and every schema/fixture/runtime/Firebase/deployment gate.

### v0.2.20 — 2026-09-19

- recorded OD10-DOC-DEC-01 and integrated F-001–F-012 into documentation
  evidence v0.2;
- corrected the `value_default` vector and distinguished unsupported viewer
  reads from authoritative use;
- added typed resolution union, revision-bound locale normalization,
  duplicate-key, withdrawal/stale/integrity and content-free telemetry rules;
- retained OD-10 Proposed, BCK-20 Draft, BCK20-OD-02/05 Open and every
  Legal/schema/fixture/runtime/Firebase/deployment gate.

### v0.2.19 — 2026-09-19

- recorded the accepted EXT-A–D technical evidence baseline for the exact four
  P6 hashes and reconciled the external source register to v0.3;
- recorded bounded technical/partial/blocked evidence separately from lawful
  allowed use, source acceptance and executable readiness;
- prepared one consolidated qualified terms/access review package without
  claiming a qualified verdict;
- advanced no source to `eligible_for_slice_review`; retained EXT-G5/G6,
  BCK20-OD-02/05, OD-10, BCK-20, all markets and runtime gates unchanged.

### v0.2.18 — 2026-09-18

- recorded BCK20-OD02-EXT-EV-PLAN-DEC-01 and accepted the frozen external-
  evidence collection procedure as EXT-G0 documentation baseline only;
- retained EXT-G1–G6 closed and every source artifact/terms/validation Pending;
- retained all markets disabled, BCK20-OD-02/05 Open, OD-10 Proposed,
  BCK-20 Draft and BCK20-OD-03 Deferred;
- created no network, download, parser, repository-data, ingestion, schema or
  runtime authority.

### v0.2.17 — 2026-09-18

- recorded BCK20-OD02-SRC-REC-DEC-01 and accepted 23 frozen internal source
  records as documentation inputs plus eight external candidates as a work
  queue only;
- retained all markets disabled and six unresolved families in their exact
  Pending/Blocked/Deferred states;
- retained external artifacts, license/terms, pinned ingestion evidence,
  independent Security/Privacy and applicable qualified Legal evidence as
  incomplete;
- retained BCK20-OD-02/05 Open, OD-10 Proposed, BCK-20 Draft,
  BCK20-OD-03 Deferred and all network/schema/runtime gates.

### v0.2.16 — 2026-09-17

- recorded BCK20-OD02-SRC-AUTH-DEC-01 and accepted the frozen source-authority
  matrix v0.1 as a design boundary with retained gates;
- kept official external registries as candidate authorities only within their
  named field scope; license/terms, pinned ingestion evidence and executable
  use remain Pending;
- retained unresolved source records, independent Security/Privacy and
  applicable qualified Legal evidence as Pending/Blocked/Deferred;
- retained BCK20-OD-02/05 Open, OD-10 Proposed, BCK-20 Draft and
  BCK20-OD-03 Deferred with no provider/schema/runtime authority.

### v0.2.15 — 2026-09-17

- recorded four separately attributable exact-v0.4 verdicts through
  BCK20-OD02-V04-COMB-DEC-01 with one disclosed owner and zero independence;
- retained source-authority content, independent Security/Privacy and
  applicable qualified Legal evidence as Pending;
- retained BCK20-OD-02/05 Open, OD-10 Proposed, BCK-20 Draft and
  BCK20-OD-03 Deferred;
- authorized documentation reconciliation only; provider, schema,
  IAM/runtime, Firebase, deployment, activation, push and merge stay closed.

### v0.2.14 — 2026-09-17

- recorded BCK20-OD02-MS-PRE-DEC-01 and integrated MS-F-001–MS-F-007 in
  translation workflow v0.4;
- added render compatibility, atomic consumer installation, monotonic
  invalidation, trusted actor authority, artifact inventory, trusted-origin
  separation and final-render safety boundaries;
- retained Product/Content v0.3 verdicts as historical exact-hash evidence and
  made their v0.4 revalidation explicit;
- prepared separate Proposed Mobile and Security/Privacy owner reviews without
  recording either verdict;
- retained BCK20-OD-02/05 Open, OD-10 Proposed, BCK-20 Draft, BCK20-OD-03
  Deferred and all provider/schema/runtime/Firebase/deployment gates.

### v0.2.13 — 2026-09-17

- recorded separate effective BCK20-OD02-SIG-L10N and SIG-CONTENT verdicts
  through BCK20-OD02-PC-COMB-DEC-01 against exact workflow v0.3/hash;
- disclosed the shared Product owner, combined roles and absent independence;
- completed only the Product/Content review boundary while retaining Mobile,
  Security/Privacy and applicable qualified Legal review;
- retained BCK20-OD-02/05 Open, OD-10 Proposed, BCK-20 Draft and every
  source-authority/provider/schema/runtime/Firebase/deployment gate.

### v0.2.12 — 2026-09-17

- recorded BCK20-OD02-PC-PRE-DEC-01 and integrated F-001–F-008 in translation
  workflow v0.3 before named specialist review;
- re-froze Product/Content review package v0.2 against exact v0.3 while both
  specialist signatures remain Pending and unnamed;
- retained BCK20-OD-02 Open, OD-10 Proposed, BCK-20 Draft, empty source-
  authority content and every specialist/Legal/provider/schema/runtime gate.

### v0.2.11 — 2026-09-16

- recorded BCK20-OD02-DEC-01 and integrated sixteen amendments in the
  provider-neutral translation-governance workflow v0.2;
- accepted only the combined-owner technical workflow boundary while keeping
  BCK20-OD-02 Open, OD-10 Proposed and BCK-20 Draft;
- retained Product Localization, Content, Mobile, Security/Privacy, qualified
  Legal, provider, schema, runtime and infrastructure gates.

### v0.2.10 — 2026-09-16

- recorded BCK20-OWN-DEC-01 and integrated all twelve owner-review amendments;
- deferred BCK20-OD-01/03/04/06/07 with exact later gates and fail-closed
  defaults while retaining BCK20-OD-02/05 Open;
- retained OD-10 Proposed, BCK-20 Draft and every specialist/Legal/runtime gate;
- authorized no schema, dataset, Firebase, deployment, push or merge.

### v0.2.9 — 2026-09-15

- reconciled BCK04-OD01-DEC-01, threat-model v0.2 and BCK-04 v0.4.23 without
  accepting BCK-20 or OD-10;
- preserved Reference Data, Localization, Mobile, Content, Legal and runtime
  gates;
- changed no schema, dataset, runtime, Firebase, deployment, push or merge
  state.

### v0.2.8 — 2026-09-12

- reconciled BCK04-SEC-DEC-01 and BCK-04 v0.4.22 without accepting BCK-20 or
  OD-10;
- retained Reference Data, Localization, Content, Mobile and qualified Legal
  verdicts plus all runtime gates;
- changed no schema, mobile/backend runtime, Firebase, deployment, push or
  merge state.

### v0.2.7 — 2026-09-09

- reconciled the bounded BCK-03 Mobile verdict without accepting BCK-20;
- retained D1-SIG-REF/L10N/CONTENT/LEGAL and BCK-20 Mobile scope Pending,
  API-DEC-05 Deferred and OD-10 Proposed;
- changed no schema, dataset, mobile adapter, runtime, push or merge state.

### v0.2.6 — 2026-09-08

- reconciled the bounded BCK-03 Security/Privacy verdict and current platform,
  API, Security and Operations anchors;
- retained BCK-20 Draft, API-DEC-05 Deferred, OD-10 Proposed and every
  Reference/Localization/Mobile/Content/Legal and runtime blocker.

### v0.2.5 — 2026-09-08

- reconciled the BCK-03 Operations verdict and current parent/API/Operations
  anchors;
- retained BCK-20 Draft, API-DEC-05 Deferred, OD-10 Proposed and runtime Absent.

### v0.2.4 — 2026-09-08

- reconciled BCK-01 v0.4.52, BCK-02 v2.4.56, BCK-03 v0.3.9, BCK-05
  v0.2.25 and BCK-02-A1 v1.3 after Owner Batch A;
- retained OD-10 Proposed and every Reference Data, Localization, Mobile,
  Content and qualified Legal verdict Pending;
- treated Deferred API-DEC-05 as the unchanged fail-closed blocker for any
  language-neutral schema beyond Booking;
- changed no taxonomy, locale policy, schema, dataset, adapter or runtime.

### v0.2.3 — 2026-09-07

- reconciled current anchors to BCK-01 v0.4.51, BCK-02 v2.4.55,
  BCK-03 v0.3.8, BCK-05 v0.2.24 and BCK-02-A1 v1.2;
- retained OD-10 Proposed, all Reference/Localization/API/Mobile/Content/Legal
  verdicts Pending and runtime Absent;
- changed no taxonomy, LocalizedText rule, dataset, schema, fixture, mobile
  adapter, Firebase resource or runtime behavior.

### v0.2.2 — 2026-08-20

- recorded the combined Reference Data/Localization/API/Mobile/Content/Legal
  assignments;
- retained Pending verdicts and the qualified Legal evidence boundary;
- reference/localization semantics, 50 stable AC, Draft status and runtime
  Absent are unchanged.

### v0.2.1 — 2026-08-20

- separated owner-approved OD-10 documentation vectors from future executable
  schema/fixture parity gated by API-DEC-05 and an executable slice;
- added explicit DoR current state and D1 owner sign-off ledger;
- reference/localization semantics, Category System 28/530 integrity, 50 stable
  AC, Draft status and runtime Absent are unchanged.

### v0.2 — 2026-08-20

- added BCK-D1-OD10-EV-01 with deterministic resolution output, LV exact/
  fallback/missing/forbidden vectors, EE/LT isolation and invalid cases;
- separated documentation fixtures from future executable schema/tooling and
  preserved Category System v1.4.3 identity/28/530 integrity;
- OD-10 remains Proposed pending named owner review; runtime remains Absent.

### v0.1.1 — 2026-08-20

- synchronized with BCK-D1-DEC-01 and BCK-03 v0.3;
- OD-10 remains Proposed and is not promoted without LV/EE/LT fixtures and
  Reference/API/Content/Mobile/Legal evidence;
- no taxonomy, schema, dataset, mobile adapter or runtime behavior changed.

### v0.1 — 2026-08-20

- defined one Reference Data authority for MarketConfig, taxonomy, service
  areas, locales, currencies, timezones and policy references;
- preserved Category System v1.4.3 IDs, aliases, status and 28/530 integrity;
- proposed OD-10 LocalizedText v1, deterministic fallback, missing-translation
  and content-language rules without marking them Accepted;
- specified immutable dataset revisions, publication/rollback, offline cache,
  Baltic market isolation, migration, exact conditional file map, tests,
  50 sequential AC and explicit unimplemented list.

## 1. Verdict

Recharge has one **Reference Data bounded module**. It publishes immutable,
versioned datasets and MarketConfig revisions consumed by backend domains and
mobile adapters through typed contracts. It is not a generic editable CMS and
does not own user-authored content, Legal policy text, domain state or product
analytics.

Latvia is prepared first with `lv-LV`, `en` and `ru`; Estonia and Lithuania are
modeled from the first revision but remain independently server-disabled until
their own locale, Legal, support and product gates pass.

This Draft creates no schema/runtime/dataset distribution service and does not
accept OD-10 by implication.

## 2. Authority and conflict priority

1. Accepted ADR.
2. Approved applicable domain/runtime slice.
3. Architecture Baseline and accepted cross-cutting policies.
4. BCK-02 and BCK-01.
5. Accepted Category System v1.4.3 for taxonomy IDs/aliases/governance.
6. Approved BCK-03/BCK-04/BCK-05.
7. This BCK-20 after Approval.
8. BCK-02-A1 and Proposed Firebase Architecture only as inputs.

BCK-20 may distribute an Accepted source but cannot silently rewrite it.
Changing Category System identity/meaning requires a new accepted taxonomy
revision and migration evidence before BCK-20 publishes a corresponding
dataset revision.

## 3. Product outcome and non-goals

### 3.1 Outcome

- stable IDs/revisions shared by mobile, backend and projections;
- deterministic market, locale, currency, timezone and fallback behavior;
- independently activatable LV/EE/LT configuration;
- reproducible offline-capable reference snapshots with honest freshness;
- explicit deprecation/alias/migration without destructive ID reuse;
- legal/product policy references linked by revision, not hardcoded as truth.

### 3.2 Non-goals

- no translation management UI or automatic/machine translation;
- no user-generated content ownership or moderation;
- no country-specific backend forks;
- no currency conversion, exchange rate or pricing authority;
- no device-timezone inference for persisted business dates;
- no production datasets, CDN, Firebase collection or client synchronization;
- no acceptance of EE/LT launch readiness.

## 4. BCK-02 §14 completeness map

| # | Mandatory section | BCK-20 evidence |
|---:|---|---|
| 1 | Header/status/owner | Header |
| 2 | Parents/priority | §2 |
| 3 | Outcome/non-goals | §3 |
| 4 | Scope | §5 |
| 5 | Ownership | §6 |
| 6 | Data classes/projections | §7 |
| 7 | Commands/queries/events/errors | §8 |
| 8 | Versions/evolution/minimum client | §9 |
| 9 | Authorization/revocation | §10 |
| 10 | Persistence/index/transaction boundaries | §11 |
| 11 | IDs/time/reference semantics | §12 |
| 12 | Idempotency/concurrency/retry/partial failure | §13 |
| 13 | Offline/cache/freshness/degraded | §14 |
| 14 | Migration/compatibility | §15 |
| 15 | Outbox/replay/dedupe | §16 |
| 16 | Privacy/retention/Legal | §17 |
| 17 | Abuse/rate/App Check/fraud | §18 |
| 18 | Logs/SLO/alerts/analytics/cost | §19 |
| 19 | Flags/rollout/rollback | §20 |
| 20 | Exact implementation map | §21 |
| 21 | Test matrix | §22 |
| 22 | AC/DoR/DoD/unimplemented | §25–28 |

## 5. Scope

### 5.1 Included datasets

- `MarketConfig` and market activation/policy revision references;
- countries, country codes and market-to-country association;
- supported locales, locale metadata and deterministic fallback policy;
- ISO currency allowlist metadata (not exchange rates);
- IANA timezone allowlist/reference metadata;
- Category System dataset: categories, subcategories, profiles, fields,
  aliases, implied facets, status, applicability and l10n keys;
- service-area/region references and revision pointers;
- bounded auxiliary dictionaries such as genres/topics only after their owning
  source is accepted;
- dataset manifests, hashes, compatibility/minimum-client metadata.

### 5.2 Excluded/delegated

| Concern | Owner |
|---|---|
| User-authored localized fields/contentLocale | Content/domain BCK specs |
| Translation copy production/review workflow | Product Localization owner |
| Legal/privacy/minors/T&S policy meaning | Legal/BCK-04/BCK-22 |
| Pricing/exchange rates/tax | Payments/business policy |
| Search keyword ranking/analytics | BCK-08/BCK-21 |
| Runtime distribution/deployment/IAM | BCK-05 |
| API envelope/generic compatibility | BCK-03 |
| Mobile cache/import adapters | BCK-18 |

## 6. Aggregate and writer ownership

### 6.1 `ReferenceDatasetRevision`

Immutable aggregate containing manifest metadata and bounded dataset entries.
Reference Data is sole writer. Domain modules store stable IDs and the revision
they interpreted; they never edit the dataset.

### 6.2 `MarketConfigRevision`

Immutable aggregate containing market activation and references to other
accepted policy/dataset revisions. Reference Data publishes it only after all
required owners approve their referenced revisions. It does not author Legal,
Privacy, T&S or provider policy contents.

### 6.3 `ReferenceDraft`

Operational/admin-only proposal with validation findings and review evidence.
It has no public/runtime authority until published as an immutable revision.

| Consumer | May read | Must not do |
|---|---|---|
| Domain command | effective revision + stable IDs | infer authority from display text |
| Discover | category/service-area projections | mutate taxonomy source |
| Mobile | versioned snapshot and l10n keys/text | publish local cache as server revision |
| BCK-05 | deploy/cache/health metadata | change dataset semantics |
| Admin | draft/review/publish command | direct database edit |

## 7. Data model and classification

Reference datasets are generally Public after publication, but drafts, review
notes, approval identity and unpublished policy links are Operational/Protected.

### 7.1 Dataset manifest

```text
datasetId
datasetType
schemaVersion
revisionId
revisionNumber
status: draft | published | superseded | withdrawn
contentHash
entryCount
supportedLocales[]
effectiveAtUtc
minimumClientContract?
supersedesRevisionId?
sourceRefs[]
createdBy / approvedBy[]
createdAtUtc / publishedAtUtc?
```

### 7.2 MarketConfig v1 target

```text
marketId
countryCode
status: disabled | internal | invited | cohort | enabled | suspended
primaryLocale
supportedLocales[]
fallbackLocaleOrder[]
currencyCodes[]
defaultIanaZone
allowedIanaZones[]
serviceAreaRevision
categoryDatasetRevision
contentPolicyRevision
privacyPolicyRevision
minorsPolicyRevision
trustSafetyPolicyRevision
mandatoryCopyManifestRevision
residencyTransferPolicyRevision
retentionDsrPolicyRevision
ugcDsaPolicyRevision
providerRegistryRevision
supportPolicyRevision
featureFlagsRevision
effectiveAtUtc
supersedesRevisionId?
```

No secret, credential, personal data or provider token belongs here.

### 7.3 Initial market facts

| Market | Country | Currency | Primary locale | Product locales | Default zone | Initial state |
|---|---|---|---|---|---|---|
| `lv` | `LV` | `EUR` | `lv-LV` | `lv-LV`, `en`, `ru` | `Europe/Riga` | first cohort candidate |
| `ee` | `EE` | `EUR` | `et-EE` | `et-EE`, `en`; `ru` only by accepted policy | `Europe/Tallinn` | disabled |
| `lt` | `LT` | `EUR` | `lt-LT` | `lt-LT`, `en`; additions by accepted policy | `Europe/Vilnius` | disabled |

These are versioned launch inputs, not permission to hardcode or activate.

## 8. Command/query/event and typed failures

### 8.1 Commands

- `CreateReferenceDraft`
- `ReplaceReferenceDraftEntries`
- `ValidateReferenceDraft`
- `SubmitReferenceRevisionForReview`
- `PublishReferenceRevision`
- `WithdrawReferenceRevision`
- `PublishMarketConfigRevision`
- `ActivateMarketConfigRevision`
- `RollbackMarketConfigRevision`

Every publish/activate command uses server-resolved capability, expected draft
revision, idempotency key, source approvals, validation report and effective
time. Publishing one dataset cannot activate a market implicitly.

### 8.2 Queries

- `GetReferenceManifest`
- `GetReferenceSnapshot`
- `GetReferenceDelta`
- `GetEffectiveMarketConfig`
- `ListSupportedMarkets`
- `ResolveLocalizedValue`

Queries return exact revision/freshness and typed unsupported/missing states.
Public consumers never receive draft review notes or approver internals.

### 8.3 Events

`ReferenceRevisionPublished`, `ReferenceRevisionWithdrawn`,
`MarketConfigRevisionActivated` and `MarketStatusChanged` are future internal
events. OD-09 governs delivery, replay and dedupe; consumers must also reconcile
the source revision and cannot blind-apply out-of-order changes.

### 8.4 Typed failures

Domain codes include `dataset_not_found`, `revision_not_found`,
`revision_unsupported`, `reference_unknown`, `reference_deprecated`,
`locale_unsupported`, `translation_missing`, `fallback_forbidden`,
`source_revision_unapproved`, `market_disabled`, `market_policy_incomplete`,
`integrity_failed` and `activation_conflict`.

## 9. Schema, revision and compatibility

Independent axes:

- dataset schema major/minor;
- immutable dataset revision ID/number;
- MarketConfig schema/revision;
- taxonomy semantic version (Category System v1.4.3 initially);
- localized wire contract version;
- policy references and minimum client contract.

Rules:

- revision IDs are immutable and content hash verified;
- additive entry/locale changes do not rewrite an old revision;
- ID meaning is never reused after deprecation;
- removal becomes `deprecated`/`withdrawn` plus migration mapping;
- breaking schema or fallback behavior requires new major and consumer window;
- unknown/newer critical schema or policy fails closed;
- old clients may keep a supported snapshot for reads but cannot mutate against
  an unsupported policy revision;
- non-Booking language-neutral schema artifacts remain prohibited until
  BCK-03 `API-DEC-05` is Accepted.

## 10. Authorization and revocation

| Capability | Scope | Requirements |
|---|---|---|
| `reference.draft.write` | dataset type | authenticated staff/service, exact scope |
| `reference.review` | dataset revision | reviewer independent from unsafe self-approval policy |
| `reference.publish` | dataset type/environment | accepted sources + validation + expected revision |
| `market_config.publish` | market | all referenced policies approved |
| `market_config.activate` | market/environment | BCK-05 flags/gates + market owner approval |
| `reference.rollback` | dataset/market | compatible previous revision + incident/change evidence |

Revocation blocks future commands immediately. Previously published immutable
facts remain auditable; withdrawal/rollback is a new command, not history edit.
Client role/capability fields are ignored.

## 11. Persistence, indexes and transaction boundaries

Target logical records:

- immutable manifests and entries/snapshot blobs;
- one effective pointer per dataset type/environment where applicable;
- one effective MarketConfig pointer per market/environment;
- drafts/review/validation evidence separated from public snapshot;
- append-only publication/activation audit;
- optional deltas derived from two immutable revisions.

Publishing atomically commits manifest, content hash, audit and effective
pointer only when all validation/source preconditions pass. Large snapshots are
bounded artifacts, not unbounded Firestore documents. Exact storage/index/CDN
technology belongs to the executable slice/BCK-05.

## 12. IDs, references, time, money and locale

- IDs are globally stable slugs only where the Accepted source defines them;
  otherwise opaque ULID/UUID;
- relationships use ID + revision, never display text;
- authoritative times use UTC; local date semantics use the owning object's
  IANA timezone;
- currency is ISO 4217 and always explicit even when all initial markets use EUR;
- locale is BCP 47 and independent from market/country/authorization;
- language-only locale (`en`, `ru`) is allowed only as an explicit supported
  product locale, never inferred from arbitrary regional tags;
- `homeMarketId` is preference, not authority.

## 13. Idempotency, concurrency and partial failure

- publish key binds dataset ID + content hash + intended revision;
- same key/same hash returns original result;
- same key/different hash returns idempotency conflict;
- expected draft/effective revision prevents lost updates;
- validation is deterministic for the same source set/tool version;
- partial publication is not visible; pointer activates only after durable
  manifest/snapshot/audit commit;
- consumer notification failure does not roll back the published source;
  outbox/retry handles effects after commit;
- timeout returns unknown outcome and client reuses identical key/payload.

## 14. Offline, cache, freshness and degraded state

Mobile/backend consumers may cache the last verified supported snapshot with:

- dataset/revision/schema/hash;
- fetched/verified/expires timestamps;
- market/environment scope;
- source and fallback policy revision.

States: `fresh`, `staleUsableForRead`, `staleBlockedForMutation`,
`unavailable`, `unsupported`, `integrity_failed`, `market_disabled`.

Stale taxonomy may support browsing already-loaded objects when the domain
allows it; publication/mutation using an unknown or stale policy revision fails
closed. Cache never activates a market or policy.

## 15. Taxonomy governance and migration

Category System v1.4.3 is the initial canonical source:

- 28 categories (27 user + `other`);
- 530 canonical subcategories under the accepted counting rules;
- stable global subcategory IDs;
- 21 criteria profiles plus fallback;
- 36 field IDs;
- 5 aliases and accepted related-link distinctions;
- non-empty l10n keys for en/ru/lv.

Rules:

1. Never clone/reparent by changing canonical ID meaning.
2. Duplicates use accepted alias semantics, not a second entity.
3. Removal is deprecation; historical references remain resolvable.
4. Migration mapping is versioned, one-way, idempotent and fixture-tested.
5. `route` remains continuous Route only; Scenario/Quick Plan are distinct.
6. `quickPlan` legacy Create type remains read compatibility only.
7. Reference distribution does not invent genres/topics until source accepted.
8. Region expansion adds scope metadata without changing global IDs.

## 16. Outbox, delivery, replay and reconciliation

Consumers subscribe only after OD-09 acceptance. Each event includes dataset
ID/type, schema/revision, content hash, effective time and previous revision.

- at-least-once delivery; consumer deduplicates by event/revision;
- out-of-order/gap triggers source manifest fetch/reconciliation;
- event never embeds an unbounded full dataset;
- replay is bounded and auditable;
- withdrawn/rolled-back revision is a new fact;
- projection/cache acknowledgement is operational evidence, not source ownership.

## 17. Privacy, Legal and content-language boundary

Reference data must contain no personal data unless separately classified and
approved. Published locale/taxonomy/service-area data is Public; drafts and
approval evidence are Operational/Protected.

- Legal copy is referenced by exact market/version/locale but authored and
  approved by Legal/Product, not BCK-20;
- missing mandatory local Legal text blocks market activation;
- translations never silently substitute for legally required local text;
- user-authored content preserves declared `contentLocale` and available
  locales; no automatic translation claim;
- logs/analytics record stable IDs/revisions, not full text by default;
- withdrawn policy references remain auditable under BCK-04 retention.

## 18. Abuse, rate and integrity controls

- publish/activate commands are staff/service-only and rate bounded;
- snapshot/query responses are size/page/cache bounded;
- manifests use deterministic canonicalization and cryptographic content hash;
- source provenance and approvals are required before publish;
- duplicate IDs, broken aliases, cycles, invalid locales/zones/currencies and
  impossible fallback chains fail validation;
- App Check may protect public distribution endpoints but does not replace
  AuthZ for draft/publish/activate commands;
- integrity failure disables mutation use and alerts Operations.

## 19. Observability, SLO, analytics and cost

Operational signals:

- publish/activation success/failure and duration;
- effective revision by environment/market;
- cache age, hash mismatch, unsupported revision and fallback miss ratio;
- consumer acknowledgement/reconciliation lag;
- snapshot size, reads/egress/cache hit and cost;
- disabled-market access attempts without raw user content.

BCK-05 owns operational SLO/alerts/budgets. BCK-21 owns product analytics and
may consume only registered minimized events. High-cardinality full localized
text is prohibited in telemetry.

## 20. Flags, rollout and rollback

- dataset publication does not activate consumer features automatically;
- activation pointer and BCK-05 server market/feature flags are distinct;
- Latvia revision can advance without changing EE/LT effective pointers;
- rollout order: validate → publish immutable revision → dev → stage fixture
  parity → bounded LV internal/cohort → enabled after gates;
- rollback activates a previously compatible verified revision;
- if old revision is unsafe, affected mutation is disabled rather than
  silently downgrading;
- EE/LT remain disabled until independent locale/Legal/support/content evidence.

## 21. OD-10 — Proposed LocalizedText v1

### 21.1 Wire semantics

```text
LocalizedTextV1 {
  defaultLocale: BCP47
  values: Map<BCP47, non-empty Unicode string>
}
```

Constraints:

- `defaultLocale` must exist in `values`;
- `defaultLocale` resolves only when enabled by effective MarketConfig;
- locale keys are canonicalized BCP 47; duplicate-equivalent keys rejected;
- duplicate raw object members are rejected before map materialization;
- locale identity carries `localeNormalizationProfileRevision`; unknown/newer
  critical profiles fail closed;
- empty/whitespace-only value is absent, not a translation;
- approved text is not silently trimmed, Unicode-normalized or rewritten;
- no arbitrary dynamic fields outside bounded locale/value rules;
- `contentLocale` and `availableLocales` belong to the owning content record;
- reference label and user content are distinct contracts;
- critical enum/ID remains stable and is never replaced by localized text.

### 21.2 Deterministic fallback

For non-Legal presentation text:

1. exact requested supported locale;
2. explicitly configured language fallback for that requested locale;
3. market `fallbackLocaleOrder` in order;
4. `defaultLocale` of the localized value;
5. typed `translation_missing` — never empty success or arbitrary first key.

Fallback steps are canonicalized, deduplicated and restricted to locales
permitted by the effective MarketConfig. V1 performs no recursive fallback
graph traversal; self-reference, canonical duplicates and cyclic/recursive
configuration fail closed. Candidate eligibility excludes withdrawn, revoked,
expired, wrong-market, wrong-environment and disallowed stale values before
lookup. Legal/safety-critical copy may declare `fallbackForbidden`; missing
required locale then fails closed.

An unsupported requested locale may use its configured fallback list and then
market fallback only for a non-Legal requester read, and the result remains
marked as an unsupported request. Authoring, publication, mutation and
fallback-forbidden resolution return typed `unsupported_locale`.

Resolution is a discriminated `Resolved | Unresolved` result. Resolved results
include requested-locale support, resolved locale, resolution kind and exact
market/dataset revisions. Unresolved results carry a typed code such as
`translation_missing`, `unsupported_locale`,
`unsupported_contract_revision` or `stale_reference_data`, without a fake
resolved locale or success kind.

### 21.3 Missing translation and content language

- UI may display an explicit fallback-language indicator where product policy
  requires it;
- backend never fabricates/machine-translates text in v1;
- missing optional label is typed and observable without logging the text;
- user-authored source language remains explicit and is not changed by requester locale;
- publication readiness separately checks required market locales by content type;
- search may index declared translations but records locale/provenance.
- diagnostics may record canonical locale/status/revision/freshness/timing but
  never localized values, user-authored text or arbitrary raw locale input.

### 21.4 OD-10 status

Status is **Accepted technical contract with retained gates**. D1 accepts the
versioned `LocalizedText v1`, deterministic market-scoped fallback,
`MarketConfig`, immutable revision and typed unresolved-state semantics defined
in this document. This is a design decision, not source, translation, Legal,
schema-runtime, publication or market-activation approval.

`OD10-DOC-DEC-01` remains the historical documentation decision that integrated
F-001–F-012. The D1 closure supersedes its `Proposed` routing status for the
technical contract only. Product Localization, Content and Mobile evidence,
qualified Legal review where applicable, approved source/license records,
executable fixtures and migration/rollback evidence remain required by their
named gates before production use.

The review vectors and owner checklist are maintained in
[BCK-D1-OD10-EV-01 v0.2](BACKEND_OD_10_LOCALIZATION_EVIDENCE.md). They make
the proposal testable on paper but do not constitute Accepted or executable
fixtures. EE/LT vectors prove isolation only and do not decide future market
locale policy.

## 22. Exact conditional implementation map

Future targets, absent and unauthorized in v0.2.28:

```text
apps/backend/functions/src/modules/reference_data/
  domain/
  application/
  infrastructure/
  transport/
apps/backend/functions/test/reference_data/
  unit/
  contract/
  emulator/
  integration/
  security/
  reconciliation/

packages/api_contracts/lib/src/contracts/reference_data/
packages/api_contracts/test/reference_data/

# Canonical under Accepted API-DEC-05; physical files require an Approved
# executable slice:
packages/api_contracts/schema/reference_data/v1/
  *.schema.json
  fixtures/valid/
  fixtures/invalid/
  fixtures/forward/

apps/mobile/lib/features/reference_data/data/
apps/mobile/test/features/reference_data/
```

Exact files/runtime/toolchain/persistence are defined in a separately Approved
executable slice. No generated file is manually authored. The existing
Category System remains canonical until an approved migration explicitly
changes its source workflow.

## 23. Test and evidence matrix

| Family | Required proof |
|---|---|
| Unit | fallback, locale normalization, ID/revision and market state |
| Category integrity | 28/530, unique IDs, profiles, aliases, l10n keys, facets |
| Contract/fixtures | valid/invalid/forward LocalizedText/MarketConfig/dataset |
| Compatibility | current/previous/newer schema and minimum client |
| Idempotency/concurrency | same/different hash, stale draft/effective pointer |
| Persistence/emulator | atomic publish/audit/pointer, no partial visibility |
| Security | public snapshot vs protected drafts/publish capability |
| Cache/offline | hash/freshness/stale/unsupported/fail-closed mutation |
| Localization | LV exact/fallback/missing/forbidden; EE/LT disabled |
| Migration | legacy IDs/aliases/deprecated/history, repeatable dry run |
| Replay/reconciliation | duplicate/out-of-order/gap/withdraw/rollback |
| Market isolation | LV activation leaves EE/LT unchanged |
| Legal | mandatory local copy/policy reference blocks correctly |
| Load/cost | bounded snapshot/delta/cache/read/egress at catalog scale |
| Accessibility/UI contract | fallback indicator and missing-state semantics |

Every evidence record includes source revision, commit/build ID, environment,
date, command, owner, result and limitations. Hand review alone is not pass.

## 24. Open decisions

| ID | Status | Owner | Evidence/decision | Blocks |
|---|---|---|---|---|
| OD-10 | Accepted technical `LocalizedText v1`/fallback/MarketConfig contract; source, copy, Legal and executable gates retained | Reference Data + API Platform | approved source/license and mandatory-copy records, applicable qualified Legal/Product evidence, migration/rollback and executable parity | production publication/activation only; not D1 or exact-R1 planning |
| BCK20-OD-01 | Accepted/reconciled with API-DEC-05 | Reference Data + API Platform | canonical JSON Schema plus generated consumers where the pinned generator exists; otherwise maintained consumers must pass the same canonical fixtures | physical schema/generation remains in the Approved executable contract slice |
| BCK20-OD-02 | Open; internal records and exact EXT-A–D technical evidence recorded; no source eligible; EXT-G5/G6 closed | Product Localization | qualified terms/access and freshness dispositions, per-source owner decisions, approved source snapshots/translations, independent Security/Privacy and applicable qualified Legal review | no production locale publication |
| BCK20-OD-03 | Deferred to executable distribution slice | Reference Data + Operations | measure snapshot size, change frequency, client storage and stale-read requirements before snapshot/delta/TTL choice | no distribution/cache contract |
| BCK20-OD-04 | Deferred to EE/LT activation | Market/Product owners | decide EE `ru` and any LT additional locale only with market evidence | EE/LT stay disabled; no LV activation fallback |
| BCK20-OD-05 | Open; Product classification/fail-closed review prepared in BCK20-OD05-POL-REV-01 but unsigned | Qualified Legal + Product | exact Product owner verdict plus qualified market/surface/purpose locale-copy matrix | affected market/legal surface disabled |
| BCK20-OD-06 | Deferred until a required dictionary has an accepted source | Category/Product owner | genres/music_genres/topics source and governance per dictionary | dictionary absent; no ad-hoc free-text canonical IDs |
| BCK20-OD-07 | Deferred until minimum-client/adoption evidence | Reference Data + domains | support window, observation period, destructive-retirement and rollback policy | additive/deprecated compatibility only; no destructive retirement |

Each Open or Deferred decision has a disabled/fail-closed default and must
record owner, evidence, decision date, migration and rollback before promotion.
Deferred does not mean Accepted or optional and cannot bypass its named later
gate. BCK20-OD-01 cannot reopen API-DEC-05 or introduce a private parallel
schema toolchain.

## 25. Definition of Ready for Review

- BCK-01 is Review and BCK-02 lists BCK-20 Present/Review;
- Category System v1.4.3 integrity is reconciled without ID changes;
- 22/22 coverage matrix and local-link checks pass;
- named Reference Data and Product Localization reviewers are assigned;
- OD-10 technical contract is reconciled with API/Content/Mobile/Security and
  applicable Legal boundaries without claiming their retained production evidence;
- no schema/runtime/distribution/mobile implementation is created;
- all Open/Deferred Decisions have owner/gate/fail-closed default.

Current readiness: the four exact-v0.4 design verdicts, frozen source-authority
boundary, 23 internal documentation records, EXT-G0 plan and exact EXT-A–D
technical evidence are recorded under disclosed combined ownership with zero
independence. All markets remain disabled and no source is eligible. Qualified
terms/access, freshness/source decisions, source snapshots/translations,
independent Security/Privacy and applicable qualified Legal evidence remain
unresolved in
[BCK-D1-SIG-01](BACKEND_PLATFORM_D1_OWNER_SIGNOFF_LEDGER.md). BCK20-OD-02/05
remain Open, so production reference/localization activation remains blocked;
BCK-20 may nevertheless remain Review with its D1 technical boundary closed.

## 26. Definition of Done for D1 Review and later Approved BCK-20

- BCK-03, BCK-04 and BCK-05 applicable technical boundaries are
  Review/reconciled atomically as the D1 platform set;
- OD-10 is Accepted as a technical contract; production publication still
  requires approved source/copy/Legal evidence and executable
  schema/fixture/migration/rollback parity in a later Approved slice;
- Category System 28/530 integrity and legacy migration fixtures pass;
- market/locale/currency/timezone/service-area/policy references are versioned;
- LocalizedText, fallback, missing and content-language rules are exact;
- EE/LT remain independently disabled until their gates;
- BCK20-OD-01–07 are Accepted or explicitly Deferred without bypassing gates;
- 93 AC are unique/sequential and unimplemented status is honest;
- runtime remains Absent until a separate Approved executable slice.

## 27. Acceptance criteria

1. **BCK-20-AC-01:** one Reference Data module owns published revisions.
2. **BCK-20-AC-02:** Reference Data does not own user-authored content.
3. **BCK-20-AC-03:** MarketConfig links but does not author domain/Legal policies.
4. **BCK-20-AC-04:** published revisions are immutable/content-hashed.
5. **BCK-20-AC-05:** draft/review data never leaks into public snapshots.
6. **BCK-20-AC-06:** stable IDs/revisions, not labels, form relationships.
7. **BCK-20-AC-07:** deprecated ID meaning is never reused.
8. **BCK-20-AC-08:** removal uses deprecation/withdrawal plus migration.
9. **BCK-20-AC-09:** Category System v1.4.3 remains canonical.
10. **BCK-20-AC-10:** integrity preserves 28 categories and 530 subcategories.
11. **BCK-20-AC-11:** aliases point to existing canonical IDs without clones.
12. **BCK-20-AC-12:** `route`, Scenario and Quick Plan remain distinct.
13. **BCK-20-AC-13:** market/country/locale/currency/environment/timezone differ.
14. **BCK-20-AC-14:** currency is explicit ISO 4217, never inferred from market.
15. **BCK-20-AC-15:** local business date uses owning-object IANA timezone.
16. **BCK-20-AC-16:** LV starts with `lv-LV`, `en`, `ru` product locales.
17. **BCK-20-AC-17:** EE/LT are modeled but independently disabled.
18. **BCK-20-AC-18:** LV revision/activation cannot enable EE/LT.
19. **BCK-20-AC-19:** `homeMarketId` is preference, not authorization.
20. **BCK-20-AC-20:** market activation checks referenced policy revisions.
21. **BCK-20-AC-21:** publishing a dataset does not activate a market.
22. **BCK-20-AC-22:** publish uses idempotency, hash and expected revision.
23. **BCK-20-AC-23:** partial dataset publication is never visible/success.
24. **BCK-20-AC-24:** mutation timeout returns unknown outcome semantics.
25. **BCK-20-AC-25:** unknown/newer critical schema/policy fails closed.
26. **BCK-20-AC-26:** stale cache may support bounded reads, never authority.
27. **BCK-20-AC-27:** cache carries schema/revision/hash/freshness/scope.
28. **BCK-20-AC-28:** Accepted API-DEC-05 defines canonical cross-language
    schema architecture; physical artifacts wait for an Approved executable slice.
29. **BCK-20-AC-29:** generated contract files are not manually edited.
30. **BCK-20-AC-30:** LocalizedText v1 requires non-empty defaultLocale value.
31. **BCK-20-AC-31:** locale keys use canonical BCP 47 normalization.
32. **BCK-20-AC-32:** empty string is missing, not a translation.
33. **BCK-20-AC-33:** fallback order is deterministic and market-scoped.
34. **BCK-20-AC-34:** no arbitrary-first-locale fallback exists.
35. **BCK-20-AC-35:** Legal/safety copy can forbid fallback and fail closed.
36. **BCK-20-AC-36:** contentLocale remains independent from requester locale.
37. **BCK-20-AC-37:** v1 performs no silent/machine translation.
38. **BCK-20-AC-38:** fallback/missing state is typed and observable.
39. **BCK-20-AC-39:** user-facing text is absent from telemetry by default.
40. **BCK-20-AC-40:** events use at-least-once dedupe and source reconciliation.
41. **BCK-20-AC-41:** out-of-order/gap never blind-applies a revision.
42. **BCK-20-AC-42:** rollback activates a compatible immutable revision.
43. **BCK-20-AC-43:** unsafe rollback disables mutation rather than downgrade.
44. **BCK-20-AC-44:** service-area/region expansion does not change global IDs.
45. **BCK-20-AC-45:** legal copy has market/version/locale approval reference.
46. **BCK-20-AC-46:** App Check does not replace publish authorization.
47. **BCK-20-AC-47:** snapshot/query sizes and rates are bounded.
48. **BCK-20-AC-48:** target file map does not authorize runtime.
49. **BCK-20-AC-49:** Approval still requires G1 and an executable slice.
50. **BCK-20-AC-50:** the current documentation revision creates no backend/schema/mobile/runtime effect.
51. **BCK-20-AC-51:** BCK20-OD-01 is reconciled with Accepted API-DEC-05 and
    cannot introduce a private schema source or bypass executable-slice gates.
52. **BCK-20-AC-52:** BCK20-OD-03 waits for measured distribution evidence.
53. **BCK-20-AC-53:** disabled EE/LT cannot activate through Latvia fallback.
54. **BCK-20-AC-54:** BCK20-OD-05 remains qualified Legal/Product scope.
55. **BCK-20-AC-55:** absent dictionaries cannot use ad-hoc canonical IDs.
56. **BCK-20-AC-56:** destructive retirement remains prohibited until its
    support, observation, minimum-client and rollback policy is Accepted.
57. **BCK-20-AC-57:** BCK20-OWN-DEC-01 changes no specialist, runtime,
    Firebase, deployment, push or merge authority.
58. **BCK-20-AC-58:** BCK20-OD02-DEC-01 accepts only the amended technical
    translation-governance boundary; OD-02 and every specialist/Legal/runtime
    gate remain open.
59. **BCK-20-AC-59:** BCK20-OD02-PC-PRE-DEC-01 integrates eight technical
    corrections without supplying source-authority content, specialist/Legal
    verdicts or implementation authority.
60. **BCK-20-AC-60:** BCK20-OD02-PC-COMB-DEC-01 makes only the two separate
    non-independent Product/Content v0.3 verdicts effective; it does not itself
    close OD-02/05, Mobile/Security/Privacy/Legal or implementation gates; its
    earlier OD-10 routing limitation is superseded only by the D1 technical decision.
61. **BCK-20-AC-61:** BCK20-OD02-MS-PRE-DEC-01 integrates seven
    documentation-only corrections in workflow v0.4; it does not itself
    supply Product/Content or Mobile/Security verdicts, BCK20-OD-03 stays
    Deferred and no implementation authority is created.
62. **BCK-20-AC-62:** BCK20-OD02-V04-COMB-DEC-01 records four separate
    exact-v0.4 combined-owner verdicts with zero independence; source-authority,
    independent Security/Privacy, applicable qualified Legal and every
    provider/schema/IAM/runtime/Firebase/deployment gate remain open.
63. **BCK-20-AC-63:** BCK20-OD02-SRC-AUTH-DEC-01 accepts only the frozen
    source-authority design boundary; actual source records, external-source
    license/terms, pinned ingestion evidence, independent/qualified review and
    every provider/schema/IAM/runtime/Firebase/deployment gate remain open.
64. **BCK-20-AC-64:** BCK20-OD02-SRC-REC-DEC-01 accepts 23 internal records
    only as documentation inputs and eight external candidates only as a work
    queue; all markets remain disabled and external/source-copy/independent/
    qualified/runtime gates remain open.
65. **BCK-20-AC-65:** at plan acceptance,
    BCK20-OD02-EXT-EV-PLAN-DEC-01 satisfies only EXT-G0 and grants no network,
    evidence, parser/fixture, repository-data, ingestion,
    independent/qualified or runtime authority.
66. **BCK-20-AC-66:** BCK20-OD02-EXT-AD-SRC-TERMS-DEC-01 accepts exact
    EXT-A–D technical evidence only; no source becomes
    `eligible_for_slice_review`, EXT-G5/G6 stay closed and the prepared
    qualified-review package supplies no qualified verdict.
67. **BCK-20-AC-67:** OD10-DOC-DEC-01 historically integrates F-001–F-012;
    D1 separately accepts the technical OD-10 contract without creating schema,
    executable fixture, dataset, runtime or qualified Legal authority.
68. **BCK-20-AC-68:** BCK-D1-OWN-B-REV-01, OD10-OWN-COMB-REV-01 and
    BCK20-OD02-SRC-GOV-REV-01 are prepared review inputs only; their verdicts
    remain Pending and no source, OD, D1/G1 or executable status advances.
69. **BCK-20-AC-69:** BCK20-OD05-POL-REV-01 and BCK-D1-OWN-C-REV-01 are
    prepared inputs only; BCK20-OD-05 remains Open, all external lanes remain
    Pending and no copy, market, OD, D1/G1 or executable status advances.
70. **BCK-20-AC-70:** OD-10 is Accepted only as the versioned technical
    `LocalizedText v1`, fallback, `MarketConfig` and revision contract.
71. **BCK-20-AC-71:** API-DEC-05 makes JSON Schema the canonical wire source;
    generated and maintained consumers prove parity against the same fixtures.
72. **BCK-20-AC-72:** technical OD-10 acceptance does not make any external
    source, license, translation or mandatory policy copy eligible.
73. **BCK-20-AC-73:** every market and risky mutation remains independently
    server-flagged and fail-closed when required policy/source revisions are absent.
74. **BCK-20-AC-74:** D1 closure permits exact R1 design only; schema files,
    datasets, runtime, Firebase, deployment and activation remain unauthorized.
75. **BCK-20-AC-75:** retained Product Localization, Content,
    Security/Privacy and applicable qualified Legal gates are not represented as
    independent or production approval.
76. **BCK-20-AC-76:** MarketConfig carries immutable pointers and never
    approves Legal/Security policy, provider terms or operational traffic.
77. **BCK-20-AC-77:** every MarketConfig and policy pointer is independently
    versioned for LV, EE and LT; no Baltic-wide activation shortcut exists.
78. **BCK-20-AC-78:** mandatory copy is keyed by market, capability, purpose,
    locale and revision, with explicit fallback prohibition/allowance.
79. **BCK-20-AC-79:** missing or unapproved mandatory copy disables the
    affected capability and cannot fall back to ordinary product text.
80. **BCK-20-AC-80:** currency remains explicit on Money and market currency
    configuration never rewrites historical values.
81. **BCK-20-AC-81:** default market timezone is bootstrap/display metadata;
    owning-object IANA timezone controls calendar interpretation.
82. **BCK-20-AC-82:** residency, retention/DSR, age, UGC/DSA, provider and
    support pointers require exact compatible revisions or explicit reviewed
    not-applicable dispositions.
83. **BCK-20-AC-83:** a MarketConfig publication cannot change BCK-05 release
    status or activate a capability.
84. **BCK-20-AC-84:** a Latvia source/copy/policy revision cannot satisfy,
    overwrite or fallback-enable Estonia or Lithuania.
85. **BCK-20-AC-85:** one shared schema supports LV/EE/LT; market-specific
    values remain data/config and do not create country forks.
86. **BCK-20-AC-86:** v0.2.25 is documentation-only and creates no schema,
    dataset, copy, runtime, Firebase, deployment, activation, push or merge.
87. **BCK-20-AC-87:** BCK-02 §26 is the sole exact R1 path/action manifest;
    BCK-20 cannot create alternate schema, config, fixture or repository paths.
88. **BCK-20-AC-88:** R1's canonical bounded MarketCapability configuration
    source is exactly `apps/backend/config/market-capability.schema.json`.
89. **BCK-20-AC-89:** `referenceMarketConfigRevisions` and
    `referenceActivationPointers` have Reference Data as their only writer and
    remain denied to direct clients.
90. **BCK-20-AC-90:** all R1 LV/EE/LT fixtures are synthetic, internally
    bounded and disabled; they contain no external dataset or mandatory copy.
91. **BCK-20-AC-91:** R1 activation-pointer swap uses expected revision and
    cannot activate an unsupported/newer/incomplete market configuration.
92. **BCK-20-AC-92:** R1 rollback selects a previously verified compatible
    immutable pointer or leaves the market/capability disabled.
93. **BCK-20-AC-93:** v0.2.27 and its exact map are documentation-only and
    create no schema file, fixture, dataset, runtime, Firebase resource,
    deployment, activation, push or merge authority.
94. **BCK-20-AC-94:** v0.2.28 is reconciled to BCK-02 v2.4.87 §26 as the sole
    exact R1 path/action manifest.
95. **BCK-20-AC-95:** local R1 uses only synthetic disabled LV/EE/LT fixtures;
    external sources, translations and mandatory policy copy remain excluded.
96. **BCK-20-AC-96:** Reference Data remains the sole writer of market-config
    revisions and activation pointers; Operations is a reader/validator only.
97. **BCK-20-AC-97:** Money carries integer minor units plus explicit currency,
    and timezone follows the owning object rather than market/device inference.
98. **BCK-20-AC-98:** local technical acceptance and production source/content/
    qualified Legal/market activation approval remain separate decisions.
99. **BCK-20-AC-99:** this preflight creates no schema, fixture, dataset,
    parser, Firebase resource, deployment, activation, push or merge.

AC numbers are stable; new criteria append. Semantic change/removal requires a
new revision and migration note.

## 28. Explicitly unimplemented

At v0.2.28 the following remain absent:

- Reference Data backend module, persistence, API or distribution;
- LocalizedText/MarketConfig executable schema or generated clients;
- executable OD-10 schemas/fixtures and specialist-accepted production
  Product Localization workflow;
- backend/mobile reference cache, deltas or activation pointers;
- production taxonomy/reference snapshots and service-area datasets;
- executable LV/EE/LT policy-pointer manifests and market release evidence;
- EE/LT locale/legal/content activation;
- runtime migrations, traffic, credentials or Firebase resources.

## 29. Next executable step

Design one exact R1 platform/reference-data slice that uses only the internal
Category System, technical `MarketConfig` and bounded `LocalizedText` fixtures.
It must enumerate exact files, pinned tools, negative fixtures, server flags,
rollback and evidence commands. External datasets, production translations,
mandatory policy copy and all markets remain disabled until their retained
source, terms, specialist and Legal gates pass. No file in this target map may
be created before that slice and G1 are separately approved.

## 30. Stage 2 normalized Reference Data entity contract

All rows inherit BCK-01 §30 and the BCK-02 writer ledger; existing domain
sections remain authoritative for commands, queries, events and typed outcomes.

| Entity family | Accountable owner / single writer | Readers/projections | ID/reference contract |
|---|---|---|---|
| SourceRecord | Reference Data / source registry | ingestion review, Security/Privacy, Legal and dataset publisher | sourceId + immutable evidence/license/freshness revision; candidate is not eligible |
| DatasetRevision | Reference Data / dataset publisher | all domains and cached client snapshots | datasetId + immutable revision/content hash; stable item IDs never labels |
| MarketConfigRevision | Reference Data / market-config publisher | all market-aware modules and mobile bootstrap | marketId + immutable revision; locale/currency/timezone/policy refs by ID |
| LocalizationPolicyRevision | Reference Data / localization policy publisher after Product/Content/Legal gates | backend resolvers and mobile rendering | policyId/revision, supported locales and deterministic fallback graph |
| LocalizedText | owning domain / owning domain command handler; BCK-20 validates policy only | locale resolver/search index | defaultLocale plus canonical BCP 47 value map; not a standalone authority |
| ActivationPointer | Reference Data / activation command handler | bootstrap, domains, clients and rollback controller | market/dataset/policy → one compatible immutable revision |

Source records move candidate → reviewed → eligible or rejected; dataset and
policy revisions move draft → validated → published → activated/superseded or
withdrawn. Published revisions never mutate. Forbidden transitions include
candidate-to-active without evidence, partial publication, LV activation that
enables EE/LT and locale fallback used as Legal copy. Publish/activate commands
use idempotency hash and expected pointer revision; revision publication and
pointer swap are separate atomic transactions. Public reference data remains
Public, while drafts/source/license evidence follow BCK-04 classification and
capabilities. Retention preserves provenance/deprecation history; deletion or
withdrawal never reuses meaning. Audit/telemetry records IDs/revisions/fallback
kind, not text. Migrations are alias-mapped and reversible; rollback selects a
compatible immutable revision. Market and mutation flags are server-owned and
safe-off. Tests cover integrity, fixtures, fallback, market isolation,
concurrency, migration, rollback and source/license evidence.

## 31. Stage 6 Baltic market policy-pointer contract

### 31.1 MarketConfig is a manifest, not an approval

`MarketConfigRevision` publishes exact immutable references needed to resolve
a market experience. It does not approve the referenced policy, select legal
meaning, accept provider terms or switch traffic. BCK-04 owns compliance
evidence and BCK-05 owns `MarketCapabilityReleaseManifest` state.

For every market-capability tuple, pointers cover or explicitly disposition:

```text
mandatoryCopyManifestRevision
privacyPolicyRevision
minorsPolicyRevision
trustSafetyPolicyRevision
ugcDsaPolicyRevision
residencyTransferPolicyRevision
retentionDsrPolicyRevision
providerRegistryRevision
supportPolicyRevision
featureFlagsRevision
```

An omitted pointer is not `not_applicable`. The owning reviewer must publish a
bounded not-applicable decision with scope, rationale and review/expiry trigger.
Unknown/newer/incompatible pointers fail closed in authoritative commands.

### 31.2 Mandatory-copy manifest

Mandatory product, privacy, age, safety, transactional and support copy is
resolved by an immutable manifest entry containing:

```text
marketId
capabilityId
purposeId
locale
copyId
copyRevision
contentHash
approvalReference
effectiveAtUtc
fallbackPolicy: forbidden | exact_allowlist
allowedFallbackLocales[]
supersedesRevisionId?
```

Ordinary `LocalizedText` fallback cannot satisfy mandatory copy. If the exact
entry is missing, expired, unsupported or not approved, the affected action is
disabled with a typed availability state. Existing immutable receipts keep the
copy/policy revision actually shown; later publication does not rewrite them.

### 31.3 Currency and timezone

- `EUR` is initial configuration for LV/EE/LT, not a derivation rule;
- every Money value carries ISO 4217 currency and integer minor units;
- changing market currency support cannot reinterpret stored Money;
- default market zone is bootstrap/display metadata only;
- Place, Event occurrence, Booking obligation, Visit History and Route/Scenario
  calendar semantics use their owning-object IANA timezone;
- device timezone and current market never silently rewrite UTC instants or
  local-calendar dates.

### 31.4 Independent market publication

LV, EE and LT have separate draft, validated, published and activation
pointers. Publishing or activating a Latvia dataset/copy/policy pointer cannot
advance, overwrite or act as fallback for Estonia or Lithuania. Shared source
artifacts may be referenced by multiple markets only through independent
market manifests and evidence.

Reference Data withdrawal invalidates new resolution but does not mutate
historical domain facts. BCK-05 disables affected traffic or selects a previous
compatible manifest; if compatibility or safety is unproven, the capability
stays disabled. No country-specific schema or module fork is created.

This section is documentation-only. Actual copy, translations, approvals,
provider/source terms, schemas, datasets, runtime and market activation remain
behind their existing gates.

## 32. Stage 7 exact R1 Reference Data/config map

### 32.1 Exact artifacts and ownership

[BCK-02 §26](RECHARGE_BACKEND_DELIVERY_MAP.md) is the sole exact R1
file/action manifest. BCK-20 owns the meaning and write policy of these R1
artifacts, but does not add alternate paths:

- `apps/backend/config/market-capability.schema.json` is the canonical
  configuration source for the bounded R1 market-capability envelope;
- `apps/backend/functions/src/config/market_capability.ts` validates and
  resolves that envelope and never becomes a second schema source;
- `referenceMarketConfigRevisions` stores immutable validated revisions;
- `referenceActivationPointers` stores the current compatible pointer by
  exact environment, market and capability;
- BCK-20/Reference Data is the only writer of both collection families;
  Platform Operations reads and validates them when composing a release.

Both collections deny direct client reads and writes in R1. Server access is
through the typed repository boundary and logical `reference-publisher`
identity only; documenting the identity creates no grant or credential.
`referenceMarketConfigRevisions` has the one exact composite index specified
in BCK-02 §26.7. Pointer reads use exact document lookup and need no composite
index.

### 32.2 R1 fixture boundary

The exact configuration fixture paths are those in BCK-02 §26.2; shared
platform-envelope parity fixtures remain separately owned by BCK-03 in §26.4.
Fixture content is synthetic and bounded to schema/parity/negative evidence.
It may exercise:

- exact `LV`, `EE` and `LT` identifiers;
- explicit `EUR` currency and valid IANA timezone identifiers;
- supported locale identifiers and deterministic fallback structure;
- immutable revision/hash, schema version and expected-pointer revision;
- `disabled` capability state and missing/newer/incompatible failure cases.

Every market and capability remains disabled. R1 fixtures contain no downloaded
CLDR/IANA/ISO/ECB/SIX data, production service area, translation, mandatory
policy copy, provider terms, Legal approval or production endpoint. They are
not seed data and cannot be promoted or ingested.

### 32.3 Write, activation and rollback semantics

Publication validates canonical schema, content hash, market scope and all
references, then creates one immutable revision idempotently. Activation is a
separate expected-revision pointer transaction. Missing, stale, unsupported,
newer or incomplete dependencies return typed fail-closed outcomes and leave
the pointer unchanged. Publishing a revision never changes BCK-05 release
state or enables traffic.

Rollback may select only a previously verified, schema-compatible immutable
revision for the same environment/market/capability. If none exists, the
pointer remains unchanged or the capability remains disabled. Rollback never
copies Latvia values into Estonia/Lithuania, rewrites historical Money/time,
reuses retired IDs, or treats ordinary localized text as mandatory copy.

### 32.4 Dependencies and exclusions

BCK-03 owns schema generation/parity, BCK-04 owns authorization/data-class
policy, and BCK-05 owns release/rollback operations. No R1 Reference Data file
may import a product-domain module or RAW-C Booking source. Product modules may
later consume only the typed config/read boundary after their own Approved
slice.

This map is documentation only. It does not authorize creating its target
files, external-source acquisition, parser/fixtures beyond the synthetic R1
set, datasets, localization runtime, Firebase changes, deployment, activation,
push or merge.

## 33. Local R1 technical-approval preflight

BCK-20 is technically consistent with the config/schema/fixture/collection
rows in BCK-02 v2.4.87 §26. Local R1 is limited to synthetic, disabled
MarketCapability evidence for LV/EE/LT and the two Reference Data-owned
collection families. It cannot ingest an external source, translation,
mandatory policy copy, service area or production identifier.

The owner subsequently accepted `BCK-R1-FOUNDATION-TECH-DEC-01`; Stage 8
verified the bounded synthetic schemas/config repositories, independent
disabled LV/EE/LT revisions and compatible rollback. Source/license, Product
Localization, mandatory copy, qualified Legal, market activation and
production runtime remain Pending. BCK07-LOCAL-01 may pin these local synthetic
revisions only for tests and cannot make any source, copy or market eligible.
