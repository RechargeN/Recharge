# PVR-01 / 03 — Spec migration and handoff

STAGE: **03**; RESULT: **ready**; DATE: **2026-10-10** (Europe/Moscow).
TARGET_ROOT: **C:/Users/User/.codex/worktrees/7275/Recharge**.
HEAD input/output: **8c69715bba03eb1cef7309d4496ebfddd6d11a1e**.
BRANCH: **codex/recharge-integration**.
authoring_done=true; decision_accepted=true (inherited accepted ADR 0021).
Ready means the docs-transfer prerequisite for user-dispatched stage 04.
No stage 04/runtime cutover, commit, push, merge, deploy, cloud work, agent
launch or messaging other chats was performed.

## INPUT_READ / start evidence

- Target AGENTS.md at input v2026-09-29; only root AGENTS found by
  `rg --files -g AGENTS.md -g '!node_modules' -g '!build' -g '!.dart_tool'`.
  User-provided instructions also applied. UI-policy metadata now v2026-10-10.
- Actual [00](00-baseline.md), [01](01-archive.md), [02](02-decision.md) reports,
  verification index, archive README/MANIFEST and original spec snapshots.
  Prepared handoffs are instructions, not proof of execution.
- [ADR 0021](../../adr/0021-unified-personal-profile.md) is Accepted, not only
  authored. Explicit 2026-10-10 user acceptance: “Принимаю конкретный текст
  ADR 0021 и связанный bounded scope плана §6.1/§13”. Accepted plan v2.3
  §7 / §15 read; its bounded scope is the authorization for these docs edits.
- Full source texts loaded: Viewer v1.17 and Public Viewer v1.0. Active
  personal/public blocks and critical Creator/Page consumers checked; source
  histories are retained as histories, not promoted to current policy.
- Current Creator v1.10 / Public Creator v1.9 / Page v2.34 / Public Page v1.3 /
  index v1.8 / decision package v1.4 / Approved Identity slice v1.3.1 / VISION.
- Cwd 4d5f is not the implementation baseline. Target 7275 was confirmed by
  stages 00–02 and by actual HEAD/branch. No older shared files copied over it.

Input related product docs/AGENTS had no stage-03 edits. Earlier PVR archive,
Accepted ADR, plan and reports remain uncommitted related WIP. Unrelated
backend/Media D2 and API-contract WIP remains in place. The final complete
status snapshot below is labeled as completion status, not an invented
pre-edit full status. Pre-edit hashes of 3302 protected files provide the
preservation comparison: apps/packages (excluding dependency/build caches),
archive files, Viewer sources, ADR 0021, master plan and reports 00–02.
All 3302 matched after changes/checks. No unrelated WIP was rewritten.

## Result / bounded changes

1. Creator v1.11 has an explicitly anchored **Общая личная часть**. Viewer
   numbered sections keep the VP namespace; original Creator §§0–23 retain
   verification/publisher responsibilities. Profile remains a projection /
   entry surface, never a new aggregate or store for its libraries.
2. Original Creator §3.1's unconditional verified-identity formula is replaced
   by authenticated personal access plus the owning action's conditions;
   verification is conditional on that action requiring Creator authority.
   Account restrictions, current revision, resource grant and lifecycle remain.
3. Public Creator v1.10 separates **Базовая контекстная identity projection**
   from the eligible opt-in extended card. At most name/avatar/optional city;
   no searchable ordinary User, private library/contact/session exposure or
   new photo visibility. Existing overlay reads remain consistent.
4. All **16 VP-D** questions/defaults and **43 VP-AC** full criteria survive
   with their IDs. Full-text normalization compares them to source v1.17;
   decision tracking rows preserve every status, target slice, owner and gate.
   No aliases merge different meanings, no silent retirement of an active rule.
5. AccountStatus's full section and exact five-state shape survive. Verification,
   moderation, public-card review/enforcement and session-purpose step-up remain
   separate. VP-D15 security review/human recovery remains Open. Target exploit
   tests are carried forward, not claimed implemented by this documentation.
6. Consumer references/ownership route to the new anchors. AGENTS / VISION /
   Approved Identity slice adopt ADR 0021's UI label and two Admin preview
   choices. Page ID/membership/publisher/lifecycle/decisions remain unchanged.
   Index current registry has four active owners; old audit is visibly historical.
   Page decision package remains non-normative v1.4; dated routing note only.
7. [Retirement map](../../product/identity/VIEWER_PROFILE_RETIREMENT_MAP.md)
   records each source section/ID/version/status, destination, treatment,
   conflict, aggregate and verifying stage. It creates no authority.

A source-consumer omission is explicitly recorded: Public Viewer §4/§6 prose
named suspended/securityLocked only, although VP §15.1's existing table also
withdraws deletionPending. Baseline consumer prose now names all three to
match that unchanged table and the existing Public Creator resolver. This
preserves the target privacy rule rather than deciding a new account policy.

VP-D02 / VP-D06 partial defaults remain partial; VP-D04 backend dependency,
VP-D08 / VP-D10 product/legal/child-safety, VP-D12 joint Follow shape decision,
VP-D14 legal/privacy export, VP-D15 security review and VP-D16 Media dependency
are preserved. Original owners TBD are not replaced by invented owners.

Viewer files remain byte-identical, with no retirement pointers until 07.
Archive 01 remains historical immutable evidence. Runtime source, tests,
workspace/storage payloads, dependency files, assets/generated code and earlier
Accepted ADRs were not changed by this stage. Draft specs remain Draft;
Approved Identity slice's authority scope expands only by Accepted UI policy,
without production activation or acceptance of other Draft defaults.

## Exact changed files / current SHA-256

Ten product/instruction/reference files plus this report and an append to
verification index, all within the task's allowed list. Existing documents
were edited from the current target, not replaced by earlier archive copies.

| File | Version / treatment | Current SHA-256 |
|---|---|---|
| `docs/product/identity/CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | 1.11 Draft | `2A34F5BEED6644C168CB29FA2A364DF627AF5CADE95CE19785E294E259C82D7B` |
| `docs/product/identity/PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | 1.10 Draft | `339E0C7F944A56B186C1D8B605C8F4CE94BE0A8E28A89489F0318FB17B1FDE41` |
| `docs/product/identity/PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` | 2.35 Draft; existing decisions unchanged | `DEFD4B16A8752694D22F4A412A8C02B5F49D4022337B99D49DCA708439CBE910` |
| `docs/product/identity/PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md` | 1.4 Draft; existing decisions unchanged | `65CBE8D46799628236ECDBDCB1DE4BA2CC6A22772486D6D1D771258A7964033D` |
| `docs/product/identity/PROFESSIONAL_PAGE_DECISION_PACKAGE.md` | 1.4 historical; appended reference note | `20A80F6D825B31E41FC561339E410393F9DDF27D191DB73EB3CC9D89E7EF4F90` |
| `docs/product/identity/PROFILE_DOCUMENTS_INDEX.md` | 1.9 non-normative | `957296831EDA5CDA097317DCCEBC221A6063BD7DEC11A328A93D7138E365851E` |
| `AGENTS.md` | 2026-10-10; UI policy only | `CEBFEF37EA242A6D4917A50A8B50FA0F7A0772CAB6BAD06A1B8F1D59019B2B98` |
| `docs/product/VISION.md` | 2026-10-10; target UI policy | `F8339F5A5314A006C57C91C4158BE060F589D97302E24E274D5C92CB81ADC667` |
| `docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md` | 1.3.2; Approved scope/authority preserved | `FC7EC24F7AF4FDF8E9E24F401E7DEF3EF8D062223F5F43E9D050105D1479F92F` |
| `docs/product/identity/VIEWER_PROFILE_RETIREMENT_MAP.md` | 1.0 non-normative; new | `515B2E649D94E50E9FCE4423F9600B779CFA931F929877933EA83B3C72E3AB4B` |

Report SHA is recorded in the verification index, not recursively here.
The index's earlier bytes are preserved verbatim; only a stage-03 addendum
is appended. Its prior 03–08/not-performed row is the pre-03 snapshot.

## Verification / actual commands and scope

| Cwd | Exact command / audit | Exit / result | Limit |
|---|---|---|---|
| apps/mobile | `flutter analyze --no-pub` | exit 0; No issues found; 100.5 s | Current local checkout; no dependency update |
| apps/mobile | `flutter test --no-pub --reporter compact` | exit 0; 1303 passed, 20 skipped; 3:39 | Existing environment-gated tests skipped; not device/Emulator/production evidence |
| target root | `dart tools/scripts/check_boundaries.dart --repo-root . --format text` | exit 0; 567 scanned, 71 findings/suppressions, 0 violations, 0 stale/expired exceptions, budget 71/71 | No new boundary exception |
| target root | `git -c core.autocrlf=false diff --check -- AGENTS.md docs/product/VISION.md docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md docs/product/identity` | exit 0; clean | Bounded tracked documentation diff; new files also whitespace-checked explicitly |
| target root | normalized full-text comparisons of source/destination VP §20, §22 and §15.1 | PASS: AC / decisions / full AccountStatus section | Strip relocation namespace/anchors/whitespace only; no runtime proof |
| target root | source/destination VP declaration grouping | PASS: 16/16 decisions, 43/43 criteria; order/set/uniqueness | Source declarations are retained provenance, not duplicate active owners |
| target root | source/destination §22.1 tracking rows | PASS: all 16 rows exactly match | Owners/defaults/gates unchanged |
| target root | CP/PCP/PP/PPP existing AC declaration sequences / decision ID-status table columns | PASS: all 8 comparisons | Does not accept Open decisions |
| target root | all 122 explicit anchors / 166 new anchor links, fences, whitespace, version headers and transferred enum fields | PASS; 0 errors | Existing historical citations retain dated meaning |
| archive root | MANIFEST raw snapshot byte lengths / SHA-256 | PASS: 65/65 | Raw copies compared with manifest, not live migrated docs |
| target root | pre/post protected SHA-256 comparison | PASS: 3302/3302 unchanged | Excludes generated build/dependency caches; verifies source/WIP preservation |

Local audit helpers were kept outside the repository in
`C:/Users/User/AppData/Local/Temp/pvr03-nf6akrh9/` and sibling pvr03-*.py
scripts. They are inspection/backup aids, not a new product dependency.
`final-audit.json`, `protected.json`, `archive-result.json` and exact pre-edit
allowed-document bytes are local evidence there. Stable evidence for future
work is this report, map, current hashes and immutable archive manifest.

Old source filename scan was reviewed separately: Creator historical §§0.5–0.14,
Public Creator historical §§0.4–0.12, Page/Public Page Revision History,
index's explicitly historical previous audit and the historical decision
package retain old names. Active consumers use new VP/PVP anchors. Source
Viewer documents themselves stay unchanged through 07; no blanket replacement
of domain `viewer` / `unlistedViewer` / PublicPageViewerContext occurred.

## PVR-AC / A-U evidence

| Criteria / scenarios | Stage-03 result |
|---|---|
| PVR-AC-05 | confirmed docs-only: all live common sections mapped to active Creator/Public Creator owners |
| PVR-AC-06 | confirmed docs-only: every VP-D / VP-AC transferred with unchanged ID/maturity; full text/rows audited |
| PVR-AC-22 | confirmed docs-only: baseline field allowlist/private exclusions and block/deletion privacy preserved; eligible extended card separate |
| PVR-AC-01–04 | prior prerequisite evidence retained; target/HEAD/accepted ADR/archive rechecked; no overwrite of prior reports |
| PVR-AC-07–21, 23 and A01–A12/U01–U16 | Not executed as post-cutover acceptance; existing local suite is regression baseline only |
| Remaining final slice / device / cloud / production gates | Open; stage-03 ready does not mean full PVR-01 Done |

## Archive / rollback / next handoff

Archive root: `C:/Users/User/.codex/worktrees/7275/Recharge/docs/archive/viewer-profile/2026-10-10/`.
[Manifest](../../archive/viewer-profile/2026-10-10/MANIFEST.md) and
[restore guide](../../archive/viewer-profile/2026-10-10/RESTORE.md) unchanged.

Rollback only stage 03's coherent document delta / reference set, including
the new map/report and stage-03 index append. Exact input document bytes are
in the temporary backup; archive 01 also retains the corresponding source
snapshots. Do not revert unrelated WIP or undo Accepted ADR 0021/02 acceptance,
and do not copy old complete shared files over later work. Runtime/data need
no rollback because this stage made no such edits.

Ready for separately dispatched 04: use target 7275, accepted ADR and plan
v2.3, map and current Creator/Public Creator docs. Settings workspace switcher
is `features/identity/presentation/widgets/workspace_section.dart`, wired by
`app/presentation/workspace_section_host.dart`; old 012d standalone switcher
is not this baseline. Recheck WIP/HEAD before any later edits. Do not assume
runtime has lost Viewer branches yet; do not clear/reassign stored payloads,
change membership/publisher authority, ship Follow or implement full Draft
profiles. No next stage starts automatically.

## Completion WIP snapshot (unrelated entries preserved)

```text
## codex/recharge-integration...origin/codex/recharge-integration [ahead 7]
 M AGENTS.md
 M apps/backend/config/manifests/execution-manifest.json
 M apps/backend/firestore.rules
 M apps/backend/functions/package.json
 M apps/backend/functions/src/content_effects_entry.ts
 M apps/backend/functions/src/content_entry.ts
 M apps/backend/functions/src/contracts/content_v1.ts
 M apps/backend/functions/src/contracts/media_schema_registry.ts
 M apps/backend/functions/src/index.ts
 M apps/backend/functions/src/media_entry.ts
 M apps/backend/functions/src/modules/catalog/application/catalog_projector.ts
 M apps/backend/functions/src/modules/catalog/domain/catalog_item.ts
 M apps/backend/functions/src/modules/catalog/infrastructure/content_catalog_source.ts
 M apps/backend/functions/src/modules/content/application/content_media_scope.ts
 M apps/backend/functions/src/modules/content/application/content_publication_service.ts
 M apps/backend/functions/src/modules/content/application/event_booking_handoff.ts
 M apps/backend/functions/src/modules/content/application/ports/media_readiness_port.ts
 M apps/backend/functions/src/modules/content/domain/event_internal_registration.ts
 M apps/backend/functions/src/modules/content/domain/publication_pointer.ts
 M apps/backend/functions/src/modules/content/domain/repositories.ts
 M apps/backend/functions/src/modules/content/infrastructure/firestore_content_repository.ts
 M apps/backend/functions/src/modules/content/infrastructure/in_memory_content_repository.ts
 M apps/backend/functions/src/modules/media/application/content_media_readiness.ts
 M apps/backend/functions/src/modules/media/application/media_deletion_service.ts
 M apps/backend/functions/src/modules/media/application/ports/actor_authority_port.ts
 M apps/backend/functions/src/modules/media/application/ports/object_store_port.ts
 M apps/backend/functions/src/modules/media/domain/media_asset.ts
 M apps/backend/functions/src/modules/media/domain/media_attachment.ts
 M apps/backend/functions/src/modules/media/domain/repositories.ts
 M apps/backend/functions/src/modules/media/infrastructure/emulator_media_composition.ts
 M apps/backend/functions/src/modules/media/infrastructure/fake_object_store.ts
 M apps/backend/functions/src/modules/media/infrastructure/firestore_media_repository.ts
 M apps/backend/functions/src/modules/media/infrastructure/in_memory_media_repository.ts
 M apps/backend/functions/src/modules/media/infrastructure/storage_emulator_object_store.ts
 M apps/backend/functions/src/modules/moderation/application/moderation_service.ts
 M apps/backend/functions/src/modules/moderation/application/ports.ts
 M apps/backend/functions/src/modules/moderation/domain/moderation.ts
 M apps/backend/functions/src/modules/moderation/infrastructure/emulator_moderation_composition.ts
 M apps/backend/functions/src/shared/feature_flags.ts
 M apps/backend/functions/test/emulator/content_rules_default_deny.test.ts
 M apps/backend/functions/test/emulator/media_real_tools_flow.test.ts
 M apps/backend/functions/test/integration/content_publication_security.test.ts
 M apps/backend/functions/test/integration/content_publication_service.test.ts
 M apps/backend/functions/test/integration/media_content_readiness.test.ts
 M apps/backend/functions/test/integration/media_deletion_reconcile.test.ts
 M apps/backend/functions/test/integration/media_privacy_boundary.test.ts
 M apps/backend/functions/test/integration/media_security.test.ts
 M apps/backend/functions/test/media_tools/clamd_scan.test.ts
 M apps/backend/functions/test/stand/media_tools_host.ts
 M apps/backend/functions/test/stand/stand_flags.ts
 M apps/backend/functions/test/stand/stand_main.ts
 M apps/backend/functions/test/stand/stand_media.ts
 M apps/backend/functions/test/stand/stand_moderation.ts
 M apps/backend/functions/test/support/content_event_world.ts
 M apps/backend/functions/test/support/content_repository_scenarios.ts
 M apps/backend/media-tools.lock.json
 M apps/backend/scripts/emulator-stand.mjs
 M apps/backend/scripts/emulator-stand.test.mjs
 M apps/backend/scripts/media-tools.mjs
 M apps/backend/scripts/run-emulator-tests.mjs
 M apps/backend/scripts/stand-d1-gate.mjs
 M apps/backend/scripts/stand-moderate.mjs
 M apps/backend/scripts/stand-seed.mjs
 M apps/backend/scripts/verify-content-persistence-layout.mjs
 M apps/backend/scripts/verify-r1-exports.mjs
 M apps/backend/scripts/verify-r1-layout.mjs
 M apps/backend/scripts/verify-toolchain.mjs
 M docs/architecture/LAUNCH_STATUS.md
 M docs/product/BACKEND_MEDIA_STORAGE_COVERAGE_MATRIX.md
 M docs/product/CONTENT_PUBLICATION_BACKEND_SPEC.md
 M docs/product/DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md
 M docs/product/IDENTITY_PUBLISHER_SLICE_SPEC.md
 M docs/product/MEDIA_D1_REAL_TOOLS_AMENDMENT.md
 M docs/product/MEDIA_STORAGE_BACKEND_SPEC.md
 M docs/product/VISION.md
 M docs/product/identity/CREATOR_PROFILE_FUNCTIONAL_SPEC.md
 M docs/product/identity/PROFESSIONAL_PAGE_DECISION_PACKAGE.md
 M docs/product/identity/PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md
 M docs/product/identity/PROFILE_DOCUMENTS_INDEX.md
 M docs/product/identity/PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md
 M docs/product/identity/PUBLIC_PROFESSIONAL_PAGE_FUNCTIONAL_SPEC.md
 M packages/api_contracts/schema/content/v1/fixtures/invalid.json
 M packages/api_contracts/schema/content/v1/fixtures/valid.json
 M packages/api_contracts/schema/content/v1/publication_pointer.schema.json
 M packages/api_contracts/schema/media/v1/fixtures/forward.json
 M packages/api_contracts/schema/media/v1/fixtures/invalid.json
 M packages/api_contracts/schema/media/v1/fixtures/valid.json
?? .github/workflows/backend-d1-linux.yml
?? apps/backend/ci/
?? apps/backend/functions/src/media_effects_entry.ts
?? apps/backend/functions/src/modules/content/application/content_media_availability.ts
?? apps/backend/functions/src/modules/content/application/ports/media_availability_port.ts
?? apps/backend/functions/src/modules/media/application/media_delivery_gate.ts
?? apps/backend/functions/src/modules/media/application/orphan_sweep.ts
?? apps/backend/functions/src/modules/media/application/ports/published_media_port.ts
?? apps/backend/functions/src/modules/media/infrastructure/media_effect_feed.ts
?? apps/backend/functions/src/modules/moderation/infrastructure/media_moderation_adapter.ts
?? apps/backend/functions/src/modules/moderation/infrastructure/media_restriction_verifier.ts
?? apps/backend/functions/test/emulator/media_delivery_callable.test.ts
?? apps/backend/functions/test/emulator/media_late_restriction_flow.test.ts
?? apps/backend/functions/test/integration/content_media_availability.test.ts
?? apps/backend/functions/test/integration/media_delivery_gate.test.ts
?? apps/backend/functions/test/integration/media_orphan_sweep.test.ts
?? apps/backend/functions/test/integration/moderation_media_restriction.test.ts
?? apps/backend/functions/test/stand/stand_media_reconcile.ts
?? apps/backend/functions/test/unit/catalog/catalog_media_suppression.test.ts
?? apps/backend/functions/test/unit/content/publication_pointer_media.test.ts
?? apps/backend/functions/test/unit/media/media_revocation_epoch.test.ts
?? apps/backend/scripts/media-tools-linux.mjs
?? apps/backend/scripts/media-tools-linux.test.mjs
?? apps/backend/scripts/stand-d1-linux-gate.mjs
?? apps/backend/scripts/stand-d2-gate.mjs
?? docs/adr/0021-unified-personal-profile.md
?? docs/archive/
?? docs/product/MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md
?? docs/product/VIEWER_PROFILE_RETIREMENT_PLAN.md
?? docs/product/identity/VIEWER_PROFILE_RETIREMENT_MAP.md
?? docs/product/viewer-profile-retirement-handoffs/
?? docs/verification/
?? packages/api_contracts/schema/media/v1/media_delivery.schema.json
```
