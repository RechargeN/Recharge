# PVR-01 / 01 — Viewer archive and handoff

STAGE: 01; RESULT: ready; DATE: 2026-10-10 (Europe/Moscow).
TARGET_ROOT: C:/Users/User/.codex/worktrees/7275/Recharge.
HEAD input/output: 8c69715bba03eb1cef7309d4496ebfddd6d11a1e.
BRANCH: codex/recharge-integration.
Ready means archive prerequisite for stage 02; runtime cutover is not approved
by this result. No commit/push/merge/deploy or other stage was performed.

## Inputs and actual baseline

[00-baseline](00-baseline.md) exists and all 35 source hashes in its table
matched before copying. Its file hash also matches the verification index:
4759C8671AD6BE8BA91FAE5D1915B931EC0770E36933810894ACCCA0078262BE.
Master plan remains Proposed and unchanged:
EBE73441EC483F795F6A1BF4F863BE4F4D0E51DAAC0A0E4E2BCDE5FC652742E0.
The source 00 hash/table is preserved in the archive as related untracked WIP.
The prepared product/handoffs folder contains instructions, not execution reports.

Target AGENTS.md version 2026-09-29 read; root is the only AGENTS discovered.
Applicable user-provided instructions also followed. Actual accepted ADRs:
- docs/adr/0015-authenticated-viewer-verified-creator-professional-page.md
- docs/adr/0016-bounded-identity-workspace-during-stabilization.md
- docs/adr/0017-admin-experience-preview-and-user-created-pages.md

Status Accepted and Deciders Recharge team are present in their source files.
No new PVR ADR was created or marked Accepted. Their snapshots are historical.
Source F01–F07/T01–T05 still match 00. Viewer branches remain in runtime.
Backend emulator-stand.mjs and emulator-stand.test.mjs became dirty since 00;
this unrelated external WIP is acknowledged, excluded from snapshots and kept.
HEAD did not change. Full input WIP is recorded below, not assumed clean.

## Result and exact archive

Archive root:
C:/Users/User/.codex/worktrees/7275/Recharge/docs/archive/viewer-profile/2026-10-10/.
[README](../../archive/viewer-profile/2026-10-10/README.md),
[MANIFEST](../../archive/viewer-profile/2026-10-10/MANIFEST.md),
[RESTORE](../../archive/viewer-profile/2026-10-10/RESTORE.md),
[SYMBOLS](../../archive/viewer-profile/2026-10-10/SYMBOLS.md).

65 complete raw snapshots + four explanatory Markdown files = 69 archive files:
8 specs/reference, 22 source/context Dart files, 18 tests/support, 17 context.
Manifest is the exhaustive file list with source root/path, copy path, purpose,
HEAD, dirty state, byte size, SHA-256 and source document version. Each copy
adds only .txt, preserving all bytes/encoding/line endings. Actual source
schema and Draft/Accepted headers are unchanged. AGENTS is AGENTS.md.txt.

Viewer/Public Viewer, Creator/Public Creator, Professional Page/Public Page,
Profile Documents Index and historical Page Decision Package are copied whole.
Identity Publisher slice, VISION, Architecture Baseline, ADR 0015/16/17,
full common profile_page.dart, all F01–F07/T01–T05, conditional consumers,
additional existing regression/support and selected dependency context are included.
Related untracked PVR-00 plan/report are actual-byte copies, marked in manifest.
Unrelated backend/media WIP, secrets, user storage, assets/build/cache and .git
are not archived. No standalone runnable package or transitive source closure
is claimed. Whole repo/SDK/dependencies remain necessary for historical research.

apps/mobile/pubspec.lock is absent. Dart workspace has root pubspec.lock;
actual copy is context/pubspec.lock.txt. Mobile/root/local-package pubspecs,
melos and analysis options preserve dependency resolution context; no invented
mobile lock or dependency edits. Flutter 3.44.9, framework 6b182d2c75, engine
5a2a6a42cc, Dart 3.12.2 were read live; C:/src/flutter/bin executables.

## Own file delta and unchanged boundaries

New: the 69 files below the archive root and this 01 report.
Updated: docs/verification/PVR_01_VERIFICATION.md, only stage 01 entry/section.
No source/spec/pubspec/ADR/00 report/master plan was edited. Index preserves
00 commands, evidence and hashes. Stage 00 no-archive notes describe that time.
No Viewer removal, enum change, authority change or production functionality.
Symbols/routes are recorded in SYMBOLS: _ViewerProfileBody/_ViewerUpgradeRow,
_RoleTrack, ProfileRoleTier.user, AccountExperience/AdminExperiencePreview,
presentation summaries/badges, Settings WorkspaceSection/host, /profile and
/profile/workspace (no separate Viewer URL). Shared Scenario library, Visits,
Favorites, Create, auth/routing and design-system dependencies stay in app.

## Checks, commands and evidence

All commands in PowerShell, cwd TARGET_ROOT, 2026-10-10.
Git rev-parse HEAD; git branch --show-current; git status --short: exit 0.
rg --files -g AGENTS.md: exit 0, only root file.
flutter --version; dart --version: exit 0, versions above.
Get-FileHash -LiteralPath <path> -Algorithm SHA256 checked all 35 baseline
sources and input report/index hash: all match.

Copy used [IO.File]::Copy(source, destination, false), with explicit inventory
and final .txt suffix only. Every file was read before copying, all copy bytes
reread via [IO.File]::ReadAllBytes and strict UTF-8 decoding; all sizes/hashes
compared to source/pre-copy record; sources rehashed after copying.
Copy/read/hash validation: exit 0, 65/65 passed; no source moved during snapshot,
no resnapshot required. Existing archive would cause refusal to overwrite.

Independent manifest check used the actual MANIFEST rows, not writer inventory:
```powershell
$rows = @()
foreach ($line in Get-Content "$a/MANIFEST.md") {
  if ($line -match '^\| (.+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| (\d+) \| ([A-F0-9]{64}) \| (.*) \|$') {
    $rows += @{source=$Matches[1].Trim();copy=$Matches[2].Trim();size=[long]$Matches[5];hash=$Matches[6]}
  }
}
if ($rows.Count -ne 65) { throw 'Manifest row count' }
foreach ($row in $rows) {
  $src = Join-Path $r $row.source
  $copy = Join-Path (Join-Path $r $a) $row.copy
  if ((Get-Item $copy).Length -ne $row.size -or
      (Get-FileHash $copy).Hash -ne $row.hash -or
      (Get-FileHash $src).Hash -ne $row.hash) { throw "Mismatch $src" }
}
```

$r = TARGET_ROOT; $a = docs/archive/viewer-profile/2026-10-10.
Execution exit 0, manifest/hash/size/source check 65/65 PASS. Compare-Object
manifest copy paths vs every actual *.txt file: no missing or extra raw copies.
File inventory exactly 69, only .txt and four .md explanatory files; no actual
.dart/.yaml/.json/AGENTS.md file in archive to be discovered by runtime/tooling.

```powershell
rg -n 'docs/archive/viewer-profile|archive/viewer-profile' apps/mobile/lib apps/mobile/test apps/mobile/assets packages pubspec.yaml pubspec.lock melos.yaml
rg -n 'viewer-profile|docs/archive' apps/mobile/lib apps/mobile/test apps/mobile/assets packages -g '*.dart' -g 'pubspec.yaml'
```

Both exit 1 with no matches (expected successful negative search), not an
unrun gate. Root .dart_tool/package_config.json read: no archive registration;
mobile package_config absent, consistent with root workspace resolution.
Root pubspec workspace apps/mobile/packages and mobile assets exclude archive.

WIP preservation check: captured full untracked-expanded status and hashes of
all pre-existing dirty/untracked regular files outside Git in temporary evidence;
post-copy foreign status Compare-Object delta 0 and all captured file hashes
unchanged. After updating index, that single authorized file is excluded from
the preservation comparison. This does not turn unrelated WIP into archive input.
Temporary evidence: C:/Users/User/AppData/Local/Temp/pvr-01-stage01-20261010-state.json;
no large logs or external state copied into Git. Manifest/report contain durable
commands, hashes and results; temporary evidence is not required to locate archive.

Flutter tests/analyze not run: no app/dependency changes, task explicitly asks
archive/document checks. Stage 00 test/boundary results are previous evidence,
not rerun or final gates. No device/cloud/runtime walkthrough/restore drill.
PVR-AC-02 confirmed: pre-edit raw snapshots and source/copy hashes agree.
PVR-AC-03 confirmed: source/tests/specs/context/restore instructions complete
for the required inventory. A01–A12/U01–U16 not verified in 01; docs-only archive
cannot prove behavior after cutover. Remaining AC and stage 07 restore drill open.

## Rollback and next handoff

Keep verified snapshot immutable. Sources changing later require a new handoff
explaining hashes and, if needed, another snapshot; never refresh this snapshot.
Stage 02 can read it and draft a narrow ADR using the current actual ADR list.
It cannot assume new policy Accepted, runtime cutover, final tests or standalone
compilability. Master remains Proposed. Only stage 01 was executed here.
Rollback: after inspecting later changes, remove only this new archive folder/
01 report and reverse the added 01 index entry/section; keep 00 evidence and WIP.
No app rollback is needed; the archive may safely remain. No unresolved integrity
problem; whole dirty backend reconstruction and build remain outside scope.

## Hashes for next stage

Manifest lists every source/raw-copy hash. Below hashes pin the archive guides
and prior plan/00 handoff. 01 report hash is in the verification index to avoid
self-reference; subsequent legitimate edits must explain hash changes.
- docs/product/VIEWER_PROFILE_RETIREMENT_PLAN.md: EBE73441EC483F795F6A1BF4F863BE4F4D0E51DAAC0A0E4E2BCDE5FC652742E0
- docs/verification/pvr-01/00-baseline.md: 4759C8671AD6BE8BA91FAE5D1915B931EC0770E36933810894ACCCA0078262BE
- docs/archive/viewer-profile/2026-10-10/README.md: CB9F99C116E3764662F788A0EAD2E3549D9CA147C84E388B7CD99F1120029A08
- docs/archive/viewer-profile/2026-10-10/MANIFEST.md: CE309F4E5BD8952A7AF4F0C4CADD4865396BCA6DDC12376AE2EC5C32C0DFF214
- docs/archive/viewer-profile/2026-10-10/SYMBOLS.md: F4BED9B4E453D4DB092669562932C64ED9E3476411B78E71DA446EE3D6516F3B
- docs/archive/viewer-profile/2026-10-10/RESTORE.md: CBCE980935DFB53916B939F78EDE5FE12E1B22EE044A15BCA5C911667547BE6A

## Full input WIP (unchanged output except own archive/report/index)

```text
 M apps/backend/config/manifests/execution-manifest.json
 M apps/backend/firestore.rules
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
 M docs/product/MEDIA_D1_REAL_TOOLS_AMENDMENT.md
 M docs/product/MEDIA_STORAGE_BACKEND_SPEC.md
 M packages/api_contracts/schema/content/v1/fixtures/invalid.json
 M packages/api_contracts/schema/content/v1/fixtures/valid.json
 M packages/api_contracts/schema/content/v1/publication_pointer.schema.json
 M packages/api_contracts/schema/media/v1/fixtures/forward.json
 M packages/api_contracts/schema/media/v1/fixtures/invalid.json
 M packages/api_contracts/schema/media/v1/fixtures/valid.json
?? .github/workflows/backend-d1-linux.yml
?? apps/backend/ci/d1-linux-stage.json
?? apps/backend/functions/src/media_effects_entry.ts
?? apps/backend/functions/src/modules/content/application/content_media_availability.ts
?? apps/backend/functions/src/modules/content/application/ports/media_availability_port.ts
?? apps/backend/functions/src/modules/media/application/media_delivery_gate.ts
?? apps/backend/functions/src/modules/media/application/orphan_sweep.ts
?? apps/backend/functions/src/modules/media/application/ports/published_media_port.ts
?? apps/backend/functions/src/modules/media/infrastructure/media_effect_feed.ts
?? apps/backend/functions/src/modules/moderation/infrastructure/media_moderation_adapter.ts
?? apps/backend/functions/src/modules/moderation/infrastructure/media_restriction_verifier.ts
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
?? docs/product/MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md
?? docs/product/VIEWER_PROFILE_RETIREMENT_PLAN.md
?? docs/product/viewer-profile-retirement-handoffs/00-baseline.md
?? docs/product/viewer-profile-retirement-handoffs/01-archive.md
?? docs/product/viewer-profile-retirement-handoffs/02-decision.md
?? docs/product/viewer-profile-retirement-handoffs/03-spec-migration.md
?? docs/product/viewer-profile-retirement-handoffs/04-presentation-access.md
?? docs/product/viewer-profile-retirement-handoffs/05-unified-ui.md
?? docs/product/viewer-profile-retirement-handoffs/06-regression.md
?? docs/product/viewer-profile-retirement-handoffs/07-retirement-restore.md
?? docs/product/viewer-profile-retirement-handoffs/08-final-gates.md
?? docs/product/viewer-profile-retirement-handoffs/README.md
?? docs/verification/PVR_01_VERIFICATION.md
?? docs/verification/pvr-01/00-baseline.md
?? packages/api_contracts/schema/media/v1/media_delivery.schema.json
```

## Final documentation and preservation verification

PowerShell Markdown validation (new four guides, 01 report, index): exit 0;
trailing whitespace 0, paired fences, all explanatory Markdown links resolve.
Raw .txt originals intentionally retain original links/whitespace/headers.
Final source/archive rehash and size check: 65/65 unchanged. Final HEAD matches.
All captured pre-existing WIP regular-file hashes unchanged, excluding only
index authorized for update; full foreign Git status delta 0. Stage 00 evidence
and master hashes unchanged. Scoped git diff --check index: exit 0; new
untracked docs additionally checked by independent whitespace/fence validator.
No build/test/runtime or standalone restoration claim is made.