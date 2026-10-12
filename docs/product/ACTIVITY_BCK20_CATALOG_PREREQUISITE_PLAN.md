# Activity Catalog prerequisite: bounded BCK-20 delivery plan

Date: 2026-10-11. Status: Proposed dependency slice; not an accepted reader contract.
Input: accepted BCK08-OD-04-A. Target: existing recharge-d3-2 checkout, HEAD b1e678a23a4db584e496a9d44593fbcf86c45dc0 plus preserved WIP.

## Evidence and boundary

The accepted Category System v1.4.3 document contains type applicability and criteria profiles. Existing mobile sources are core/config/recharge_taxonomy.dart, recharge_taxonomy_seed.dart and recharge_category_criteria.dart. They are implementation inputs for parity verification, not automatically accepted immutable BCK-20 runtime artifacts. SRCREC-CATEGORY-143-001 explicitly states executable dataset absent.

Existing Catalog ContentFeedCatalogSource.toFact already carries suppressedMediaIds; preserve and test it rather than implementing a second propagation path. ReferenceDataRevisions.current only resolves current revisions. It cannot interpret an immutable Activity's historical taxonomy revision.

## Exact file plan for prerequisite, subject to contract acceptance

- docs/product/REFERENCE_DATA_LOCALIZATION_SPEC.md: bounded addendum defining immutable taxonomy dataset reading, revision identity, provenance, public criterion semantics and explicit unavailable outcomes. Preserve disabled market/production gates.
- apps/backend/functions/src/modules/reference_data/domain/repositories.ts: BCK-20-owned immutable taxonomy read boundary alongside the existing repository ports.
- apps/backend/functions/src/modules/content/application/ports/reference_data_port.ts: extend the existing reference-data boundary for a specifically pinned taxonomy revision; retain current resolve behavior compatibility.
- apps/backend/functions/src/modules/content/domain/type_rules/validation_context.ts: preserve applicability/required-criteria lookups; only add accepted public criterion metadata if the approved contract needs it.
- apps/backend/functions/src/modules/content/infrastructure/emulator_reference_data.ts: compose the accepted dataset reader for Activity without a second dictionary; retain other synthetic families as separately labelled debt.
- apps/backend/functions/src/modules/content/infrastructure/emulator_activity_taxonomy.ts: remove runtime fixture composition only after accepted artifact parity is demonstrated; keep the minimal fixture in tests.
- packages/api_contracts/schema/reference_data/v1/taxonomy_dataset.schema.json (new): only after the owning BCK-20 contract is accepted.
- apps/backend/functions/test/reference_data/contract/reference_data_contracts.test.ts and test/reference_data/integration/reference_data_service.test.ts: accepted artifact identity, hash, exact revision, unknown/unavailable outcomes and compatibility.
- apps/backend/functions/test/unit/content/emulator_activity_taxonomy.test.ts: test fixture separation, applicability and required criteria parity.

Artifact path, revision identifier and reader signature must be defined by the prerequisite contract; this plan deliberately does not invent them or label a generated artifact accepted.

## Required decisions and acceptance

Confirm whether the accepted v1.4.3 applicability and criteria profiles are sufficient to derive the executable artifact, and which criterion definitions are public Catalog facts. Optional/private criteria must not be exposed merely because they are present in Create. Resolve source/mobile discrepancies explicitly, never by automatic draft migration.

The dataset is immutable and content-addressed with a declared canonical serialization and provenance to the accepted source. Historical revisions remain readable. Unknown or unavailable revisions produce explicit failure; no latest or test-fixture fallback. Existing drafts and published immutable bodies are unchanged. Market activation and cloud remain outside scope.

Only after this prerequisite passes should the accepted Activity Catalog union, projection, Discover/Details mapping and replay/rebuild gates proceed according to BCK08-OD-04-A. No runtime stage is marked complete by this plan.

## Verification and rollback

Build before live Emulator runs. Run affected BCK-20 contract/domain/integration and Content applicability/required-criteria gates; verify historical revision lookup and unknown/unavailable refusal. After Catalog implementation, execute D2 duplicate/out-of-order/rebuild/reconcile/rollback cases and real stand Feed/Map/Search/Details with both kill switches, plus required Flutter analyze/test, boundary and diff checks.

Rollback restores the previous Emulator composition and disables Activity Catalog/Discover. Do not rewrite drafts, delete immutable datasets or undo unrelated WIP.

## Continuation 2026-10-11

После подготовки плана пользователь поручил выполнить заход 8 и явно подтвердил первую версию без dynamic criteria. Локальная реализация и фактический additive reader описаны в ACTIVITY_BCK20_TAXONOMY_SLICE_SPEC.md; проверенное evidence — D3_ACTIVITY_CATALOG_2026-10-11.md. Этот первоначальный план сохранён как история зависимости, не как актуальный отчёт об отсутствующем runtime.
