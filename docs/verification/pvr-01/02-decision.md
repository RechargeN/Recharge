# PVR-01 / 02 — narrow ADR and bounded contract

STAGE: 02; RESULT: ready; DATE: 2026-10-10 (Europe/Moscow).
authoring_done: true
decision_accepted: true
TARGET_ROOT: C:/Users/User/.codex/worktrees/7275/Recharge.
HEAD input/output: 8c69715bba03eb1cef7309d4496ebfddd6d11a1e.
BRANCH: codex/recharge-integration.
No runtime edits, later stage, agents, commit/push/merge/deploy performed.

## Inputs checked

[00-baseline](00-baseline.md) and [01-archive](01-archive.md) exist; their hashes
match the verification index. All 65 manifest source/copy hashes and byte sizes
matched on entry. README/MANIFEST read; F01–F07/T01–T05 baseline remains available.
No stage was inferred from prepared product/handoffs instructions.
AGENTS.md target version 2026-09-29 read; root only, no nested AGENTS discovered.
Master plan §§1,6,15,16, Identity Publisher slice v1.3.1 Approved read.
Accepted ADRs 0013/0015/0016/0017 read at their actual target paths.
Their Accepted headers and Deciders Recharge team are recorded in real files;
no current request accepts the new ADR's specific text.

Actual new ADR: [0021-unified-personal-profile.md](../../adr/0021-unified-personal-profile.md).
Status: Proposed. Inventory on entry has numbered ADRs 0011–0020; 0021 is next
and no existing/untracked 0021 file or filename prefix was present.
Existing ADR contents and hashes are preserved. Proposal cannot supersede
Accepted policy until this concrete ADR text is explicitly accepted.

## Concrete delta / review contract

New files:
- docs/adr/0021-unified-personal-profile.md
- docs/verification/pvr-01/02-decision.md (this handoff)

Updated files:
- docs/product/VIEWER_PROFILE_RETIREMENT_PLAN.md, v2.1 → v2.2:
  link to Proposed ADR, §6.1 exact bounded contract, actual 00/01/02 status rows.
- docs/verification/PVR_01_VERIFICATION.md: stage 02 row/section/hashes;
  00/01 evidence retained, earlier hashes remain historical.

The ADR changes on acceptance only ADR 0015 §2's personal UI terminology and
ADR 0017's presentation preview values. ADR 0016's Viewer/Creator references
are read as the unified personal UI; its existing timing/guard exception and
navigation/authority contract are preserved. No old Accepted ADR is edited.
One personal UI Creator; one Settings personal row; Admin preview creator /
professionalPage. Existing tools and actions remain subject to actual access.

Persisted User/Creator/Admin, Creator verification, capability/ownership/
account/lifecycle/operation guards, mandatory auth, WorkspaceRef personal/page,
PublisherRef user/page, exact-page membership and private libraries are preserved.
Personal profile/library access and owned personal planning do not acquire
publishing-verification gate; refusal of one protected operation does not select
another profile. Public/searchable identity does not follow from UI title.
Scenario viewer/unlistedViewer/PublicPageViewerContext remain distinct meanings.
No Follow/Payments/backend/cloud/real verification or full Draft implementation.

Future file scope is existing plan §13: F01–F07, conditional consumers only for
specific presentation reasons, T01–T05/additional existing regression, named
stage 03 documentation scope. Future runtime work requires explicit acceptance
of ADR and that bounded scope plus separately dispatched stage; this task
performs only authoring. Old profile/router from 012d is never copied over target.
Shared profile_page.dart and all Saved/Visited/Scenario/Created/Settings/page
handoffs remain in runtime at this stage. There is no separate Viewer route.

## Archive and data compatibility

Archive remains exactly:
C:/Users/User/.codex/worktrees/7275/Recharge/docs/archive/viewer-profile/2026-10-10/.
[Manifest](../../archive/viewer-profile/2026-10-10/MANIFEST.md) and all 69 files
are preserved. This is a historical/reference snapshot, not standalone code.
Expected migration is zero per baseline storage evidence: stable keys/schema,
personal/page workspace, user/page publisher, session preview. A newly found
persisted experience consumer would require narrow compatibility plan/tests;
no data deletion, reset, role rename or publisher rewrite is allowed by title.

Plan source hash intentionally changes in 02. Its archived v2.1 copy and prior
00/01 handoffs retain their old hashes. Only this live-plan delta explains the
new hash below; never update archived bytes to match a later plan.

## Acceptance state and required decision

The product goal is already confirmed and is not asked again. Concrete text
acceptance has not occurred. Requested decision: accept Proposed ADR 0021
and its linked bounded PVR plan §6.1/§13 as the UI/preview architecture basis.
Accepting it does not start stage 03 or authorize commit/push/cloud operations.

Basis: AGENTS document priority item 1, Accepted ADR wins; rule 9 says
“Перед крупным куском — план файлов без кода, ждать подтверждения.”
The supplied stage 02 task explicitly says “Proposed ADR получает Accepted
только после принятия конкретного текста”. This is an explicit requirement,
not a inferred extra approval policy. Until acceptance, decision_accepted stays
false and dependent stage 03/04/05 changes must not be assumed authorized.

PVR-AC-04: authoring/content scope checked, docs-only; decision acceptance
pending. Do not close architecture-acceptance prerequisite as passed solely
from this Proposed text. PVR-AC-01/02/03 retain earlier evidence; no additional
runtime AC or A01–A12/U01–U16 scenario was checked in stage 02.

## Checks and limitations

All PowerShell commands cwd TARGET_ROOT, 2026-10-10:
- git rev-parse HEAD; git branch --show-current; git status --short: exit 0.
- rg --files -g AGENTS.md: exit 0, root only.
- Get-ChildItem docs/adr -File; filename number/prefix checks: exit 0,
  max 0020 on entry, free 0021 reserved for this new Proposed file.
- Get-FileHash -Algorithm SHA256 for prior handoffs/manifest copies/sources:
  exit 0, 00/01 index hashes match; 65/65 raw snapshot source/size/hash agreement
  before edits. Live plan changes after this check are explicitly recorded.

Markdown/fences/links, own document diff and preservation checks are recorded
below after final verification. Flutter analyze/test and boundary were not
run: task is documentation-only, application/dependencies are untouched.
Prior test results are previous evidence, not new/final runtime gates.
No device/cloud/production or restore drill evidence is claimed.

## Rollback / next

While Proposed, delete only the two new files and reverse the bounded live-plan/
index delta after checking later edits; preserve all 00/01 evidence, archive,
old Accepted ADRs and unrelated WIP. Stored user data is untouched.
The exact pre-edit plan/index were saved outside Git for this comparison in
C:/Users/User/AppData/Local/Temp/pvr-01-stage02-20261010-state.json.
Do not blanket reset, clean, copy archived profile over runtime or silently
change an Accepted ADR. After acceptance, architecture changes use a new ADR.

Next stage can review concrete text, unchanged baseline and archive. It cannot
assume decision_accepted, runtime approval or final gates. The only unresolved
issue of this authoring stage is explicit acceptance of the concrete ADR text.

## Final hashes for the next stage

These pin ADR text, live-plan version and preserved prior evidence. Changing
Proposed to Accepted later necessarily changes ADR hash and needs an acceptance
record/new handoff, not a retroactive modification of this historical report.
02 report hash is recorded in the index; index self-hash is not embedded there.
- docs/adr/0021-unified-personal-profile.md: 9444AE1F0F7C110D30F491C1991792550D59EB9F734B134B72D473D2A144D2C9
- docs/product/VIEWER_PROFILE_RETIREMENT_PLAN.md: E8AB099FD6341A9DFC961E133D263D502A982B8E746F442FBF5C1651BB1796E0
- docs/verification/pvr-01/00-baseline.md: 4759C8671AD6BE8BA91FAE5D1915B931EC0770E36933810894ACCCA0078262BE
- docs/verification/pvr-01/01-archive.md: 665385299924F5BDC273812FE2C8AA0375DF477A0793152C568D1B924F1984F0
- docs/archive/viewer-profile/2026-10-10/README.md: CB9F99C116E3764662F788A0EAD2E3549D9CA147C84E388B7CD99F1120029A08
- docs/archive/viewer-profile/2026-10-10/MANIFEST.md: CE309F4E5BD8952A7AF4F0C4CADD4865396BCA6DDC12376AE2EC5C32C0DFF214
- docs/archive/viewer-profile/2026-10-10/RESTORE.md: CBCE980935DFB53916B939F78EDE5FE12E1B22EE044A15BCA5C911667547BE6A
- docs/archive/viewer-profile/2026-10-10/SYMBOLS.md: F4BED9B4E453D4DB092669562932C64ED9E3476411B78E71DA446EE3D6516F3B
- docs/adr/0013-domain-policy-baseline.md: EEFDB740F0B31765A873C185819C90F31EFF0F09A997FD26FB01C253F1877E06
- docs/adr/0015-authenticated-viewer-verified-creator-professional-page.md: 652644110624C051A48899D37F83613A63D696673B12D6975F2F22842A8A8964
- docs/adr/0016-bounded-identity-workspace-during-stabilization.md: 8FD069E1ABB9EE6F76C88B4A374C47EA46F62A75F16F28BDD8F44EC063062CF1
- docs/adr/0017-admin-experience-preview-and-user-created-pages.md: 9833A56B97B73FD848AAE5EEF51C149AFC42C3BAA1DF3820E5D96A63A6336DA9

## WIP input/output map

Related runtime/tests WIP absent. Existing PVR 00/01 docs and archive untracked
on entry and preserved; only live plan/index are authorized modifications.
Backend/media/contracts WIP below remains excluded and unchanged. Full expanded
status and pre-existing file hashes captured in the temporary state above.

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
?? packages/api_contracts/schema/media/v1/media_delivery.schema.json
```

## Final verification results

2026-10-10, cwd TARGET_ROOT. PowerShell Markdown/link validator: exit 0 for
all four own docs; trailing whitespace 0, paired fences, all relative links
resolve. git -c core.safecrlf=false diff --check: exit 0. Old ADR hash comparison:
10/10 unchanged. Archive raw size/hash comparison: 65/65 unchanged. All other
manifest sources unchanged; only live master plan intentionally changes from
archived v2.1 to v2.2. All other captured pre-existing dirty/untracked regular
files unchanged; foreign status delta 0; HEAD unchanged.

Exact own pre-edit plan/index copies written outside Git for inspection:
C:/Users/User/AppData/Local/Temp/pvr-01-stage02-plan-before.md and
C:/Users/User/AppData/Local/Temp/pvr-01-stage02-index-before.md.
Commands:
```powershell
git --no-pager -c core.safecrlf=false diff --no-index --stat -- $tempBefore docs/product/VIEWER_PROFILE_RETIREMENT_PLAN.md
git --no-pager -c core.safecrlf=false diff --no-index --stat -- $tempIdx docs/verification/PVR_01_VERIFICATION.md
```

$tempBefore/$tempIdx are the respective exact temporary paths above.
Exit 1 for both means actual intended difference, not green exit 0:
plan 31 insertions/4 deletions, index initially 15 insertions/1 deletion,
prior to final 02 report-hash refresh. New Proposed ADR and report independently
validated as Markdown. ADR status explicitly rechecked Proposed. No Flutter
run required/performed for this documentation stage; no runtime gates closed.
## Explicit acceptance addendum — 2026-10-10

The product owner directly accepted in this chat:
“Принимаю конкретный текст ADR 0021 и связанный bounded scope плана §6.1/§13”.
Current state: authoring_done=true; decision_accepted=true; RESULT=ready.
ADR 0021 is now Accepted. The earlier authoring/Proposed/pending sections and
hashes above remain the historical pre-acceptance record, not current blockers.
PVR-AC-04 decision prerequisite is confirmed by that explicit acceptance;
no runtime A/U scenarios or final gates were run or closed by acceptance.
Only metadata/acceptance record changed in ADR, and linked status in plan/report/
index. The substantive accepted decision/scope is unchanged. Plan v2.3 pins
accepted §6.1/§13; this does not accept unresolved Draft decisions elsewhere.
HEAD remains 8c69715bba03eb1cef7309d4496ebfddd6d11a1e. No later stage dispatched.
An accepted architecture decision is changed later by a new superseding ADR;
do not use the earlier Proposed-only deletion rollback to undo acceptance.

Current hashes after acceptance:
- ADR 0021: 5CEEF9575528B71DE454952D5DB82D9073C9ADE3F81B549471FC0526E5B88184
- Plan v2.3: AA31BE37FF411BF96CB5F95E30E8405B20B8B86B3FE99A45F902EE5363CF1232
