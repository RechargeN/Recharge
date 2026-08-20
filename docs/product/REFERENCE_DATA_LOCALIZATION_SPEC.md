# Recharge Backend — Reference Data & Localization Specification

- ID: **BCK-20**
- Version: **0.1**
- Date: **2026-08-20**
- Spec status: **Draft — Reference Data review required**
- Runtime status: **Absent**
- Accountable owner: **Reference Data owner**
- Interim review coordinator: **RechargeN / Product owner**
- Parent architecture: [BCK-01 v0.4.2](RECHARGE_BACKEND_MASTER_SPEC.md) (Review)
- Coordination baseline: [BCK-02 v2.4.6](RECHARGE_BACKEND_DELIVERY_MAP.md)
- API boundary: [BCK-03 v0.2.4](BACKEND_API_CONTRACT_STANDARD.md) (Draft)
- Operations boundary: [BCK-05 v0.1](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md) (Draft)
- Canonical taxonomy: [Category System v1.4.3](CATEGORY_SYSTEM.md) (Accepted)
- Delivery annex: [BCK-02-A1 v1.0](RECHARGE_BACKEND_LATVIA_IMPLEMENTATION_ROADMAP.md) (Draft)
- Runtime effect: **none**
- Canonical path: `docs/product/REFERENCE_DATA_LOCALIZATION_SPEC.md`

---

## 0. Changelog

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

States: `fresh`, `stale_usable_for_read`, `stale_blocked_for_mutation`,
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
  values: Map<BCP47, non-empty normalized string>
}
```

Constraints:

- `defaultLocale` must exist in `values`;
- locale keys are canonicalized BCP 47; duplicate-equivalent keys rejected;
- empty/whitespace-only value is absent, not a translation;
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

Fallback steps are deduplicated and restricted to locales permitted by the
effective MarketConfig. Legal/safety-critical copy may declare
`fallbackForbidden`; missing required locale then fails closed.

### 21.3 Missing translation and content language

- UI may display an explicit fallback-language indicator where product policy
  requires it;
- backend never fabricates/machine-translates text in v1;
- missing optional label is typed and observable without logging the text;
- user-authored source language remains explicit and is not changed by viewer locale;
- publication readiness separately checks required market locales by content type;
- search may index declared translations but records locale/provenance.

### 21.4 OD-10 status

Status is **Proposed — not Accepted**. Acceptance requires API Platform,
Reference Data, Product Localization, Content, Mobile and Legal review,
fixtures for LV/EE/LT and explicit migration/rollback evidence.

## 22. Exact conditional implementation map

Future targets, absent and unauthorized in v0.1:

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

# Only after Accepted API-DEC-05:
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
| OD-10 | Proposed LocalizedText v1 | Reference Data + API Platform | wire/fallback/missing/content-language fixtures and owner sign-off | BCK-20/BCK-07 Approval, G1 |
| BCK20-OD-01 | Open | Reference Data + API Platform | Dart-only vs cross-language artifact after API-DEC-05 | executable contract slice |
| BCK20-OD-02 | Open | Product Localization | translation source/review workflow and reviewer independence | production locale content |
| BCK20-OD-03 | Open | Reference Data + Operations | snapshot/delta distribution, cache TTL and artifact size | executable slice |
| BCK20-OD-04 | Open | Market/Product owners | EE `ru` and any LT additional locale policy | EE/LT activation |
| BCK20-OD-05 | Open | Legal + Product | fallbackForbidden classes and mandatory local-copy matrix | market activation |
| BCK20-OD-06 | Open | Category/Product owner | genres/music_genres/topics accepted sources | those dictionaries |
| BCK20-OD-07 | Open | Reference Data + domains | deprecation support window/minimum-client policy | destructive retirement |

Each Open decision has a disabled/fail-closed default in this document and
must record owner, evidence, decision date, migration and rollback.

## 25. Definition of Ready for Review

- BCK-01 is Review and BCK-02 lists BCK-20 Present/Draft;
- Category System v1.4.3 integrity is reconciled without ID changes;
- 22/22 coverage matrix and local-link checks pass;
- named Reference Data and Product Localization reviewers are assigned;
- OD-10 proposal is reviewed by API/Content/Mobile/Legal perspectives;
- no schema/runtime/distribution/mobile implementation is created;
- all Open Decisions have owner/gate/fail-closed default.

## 26. Definition of Done for Approved BCK-20

- BCK-03, BCK-04 and BCK-05 applicable boundaries are ready and
  Approved/reconciled atomically as the D1 platform set;
- OD-10 is Accepted with LV/EE/LT fixtures and migration/rollback evidence;
- Category System 28/530 integrity and legacy migration fixtures pass;
- market/locale/currency/timezone/service-area/policy references are versioned;
- LocalizedText, fallback, missing and content-language rules are exact;
- EE/LT remain independently disabled until their gates;
- BCK20-OD-01–07 are Accepted or explicitly Deferred without bypassing gates;
- 50 AC are unique/sequential and unimplemented status is honest;
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
28. **BCK-20-AC-28:** cross-language schema waits for Accepted API-DEC-05.
29. **BCK-20-AC-29:** generated contract files are not manually edited.
30. **BCK-20-AC-30:** LocalizedText v1 requires non-empty defaultLocale value.
31. **BCK-20-AC-31:** locale keys use canonical BCP 47 normalization.
32. **BCK-20-AC-32:** empty string is missing, not a translation.
33. **BCK-20-AC-33:** fallback order is deterministic and market-scoped.
34. **BCK-20-AC-34:** no arbitrary-first-locale fallback exists.
35. **BCK-20-AC-35:** Legal/safety copy can forbid fallback and fail closed.
36. **BCK-20-AC-36:** contentLocale remains independent from viewer locale.
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
50. **BCK-20-AC-50:** v0.1 creates no backend/schema/mobile/runtime effect.

AC numbers are stable; new criteria append. Semantic change/removal requires a
new revision and migration note.

## 28. Explicitly unimplemented

At v0.1 the following remain absent:

- Reference Data backend module, persistence, API or distribution;
- LocalizedText/MarketConfig executable schema or generated clients;
- accepted OD-10 and Product Localization workflow;
- backend/mobile reference cache, deltas or activation pointers;
- production taxonomy/reference snapshots and service-area datasets;
- EE/LT locale/legal/content activation;
- runtime migrations, traffic, credentials or Firebase resources.

## 29. Next action

1. confirm BCK-20 coverage/reconciliation matrix;
2. assign named Reference Data, Product Localization, API, Content, Mobile and
   Legal reviewers;
3. run OD-10 fixtures/decision review;
4. reconcile BCK20-OD-01–07 with BCK-03/04/05;
5. move BCK-20 to Review, then Approved only after §26;
6. keep schema/runtime/distribution implementation blocked until G1 and a
   separately Approved executable file plan.
