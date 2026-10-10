# PVR-01 / 05 — Unified Creator UI and handoff

STAGE: **05**; RESULT: **ready**; DATE: **2026-10-10** (Europe/Moscow).
TARGET_ROOT: **C:/Users/User/.codex/worktrees/7275/Recharge**.
HEAD input/output: **8c69715bba03eb1cef7309d4496ebfddd6d11a1e**.
BRANCH input/output: **codex/recharge-integration** (ahead 7 at input).
Ready means bounded local UI cutover is implemented and verified, not completion
of the whole PVR-01 plan. No stage 06–08 work, commit, push, merge, deploy,
cloud operation, new agent or messages to another chat were performed.

## Input and accepted contract

Read the user-dispatched stage 05 attachment, target AGENTS v2026-10-10
(root is the only applicable AGENTS found), actual [00](00-baseline.md),
[01](01-archive.md), [02](02-decision.md), [03](03-spec-migration.md),
[04](04-presentation-access.md) handoff evidence and verification index,
archive manifest, current F02, current profile/library/routes and inline Settings
embedding. Master plan v2.3 §§1/9/13/15/16 and
[ADR 0021](../../adr/0021-unified-personal-profile.md) were checked.
ADR status is **Accepted**, on the user's explicit acceptance of that exact
ADR text and bounded §6.1/§13. Earlier Proposed/pending entries are historical.
The fixed 00–04 target remains 7275, not chat cwd 4d5f or old 012d.
All seven hashes recorded in 04 match the actual input. Source
hashes that change below are explained by this cutover; 04 report stays immutable.
No master plan, ADR or prior handoff was rewritten.

## Own files and bounded behavior

Seven runtime files F01–F07 changed as one delivery:

| File | Change |
|---|---|
| F01 `apps/mobile/lib/features/explore/presentation/pages/profile_page.dart` | All authenticated users use Creator Hero/title/badge and common Creator composition. Created, Visited/Photos shortcuts, compact Saved action and owner-scoped ScenarioLibraryPanel remain. Removed Viewer body/upgrade, visit-preview subscription, role selector and fallback tier selection. ProfileWorkspace remains the existing tool dashboard. Generator actions use actual hints in an optional tools panel, not another profile layout. Responsive workspace metrics size to text content. |
| F02 `apps/mobile/lib/features/explore/application/profile_role_summary.dart` | Use the already-tested ProfilePersonalPresentation in the real screen; clarify the retained legacy compatibility helper comment. No actual role/capability logic rewrite. |
| F03 `apps/mobile/lib/core/identity/account_experience.dart` | AccountExperience is personal / professionalPage. |
| F04 `apps/mobile/lib/features/identity/application/state/identity_workspace_state.dart` | Authorized active page keeps priority; Creator preview maps to personal, page preview maps to presentation only; default is personal independent of verification. |
| F05 `apps/mobile/lib/app/presentation/recharge_app_shell.dart` | Fallback is personal; existing personal/page destinations and redirects retained. |
| F06 `apps/mobile/lib/features/identity/domain/entities/admin_experience_preview.dart` | Preview values are creator / professionalPage; only presentation enum changed. |
| F07 `apps/mobile/lib/features/identity/presentation/widgets/workspace_section.dart` | One personal Creator row; subtitle reports the actual six verification states without inventing grants. Viewer preview removed; exact page rows/quota/creation/request UI retained. |

Four tests changed: T01 profile_page_test.dart, T02 workspace_section_test.dart,
T03 professional_app_shell_test.dart, T05 identity_workspace_usecase_test.dart.
T04 profile_role_summary_test.dart is byte-identical to input 04 and rerun.
Two documentation files: this new report and append-only verification index.
There are 11 own source/test changes plus these two documentation files.
No conditional consumer extension was necessary. WorkspaceSectionHost,
app_router/route_names, SettingsPage, identity controller and architecture baseline
were inspected and remain unchanged. No old switcher was restored.

No Auth user/snapshot copies, fake verification/page/membership, new storage,
backend/cloud behavior or extra publication capability was introduced.
WorkspaceRef personal/page and PublisherRef user/page IDs and persistence remain
unchanged. ProfileRoleSummary flags retain their legacy coarse Auth tool-hint
meaning; authoritative operation guards remain in their owning controllers and
usecases. A Creator title or preview is never verification or a mutation grant.
The static CREATOR badge is the personal UI label, not a verified badge.

## Final action/route map

| Surface | Final owner/handoff |
|---|---|
| `/profile` Hero and title | ProfilePersonalPresentation; existing Explore editable profile sources; settings action unchanged |
| Created / View all events | Existing `/profile/workspace` tool dashboard; listing data from current Create state, no fake publication |
| Saved list | Existing Favorites route/repository, same user scope and personal bottom-nav destination |
| Visited | Existing `/profile/visited`; Visit History screen performs its own load; canonical Details route remains there unchanged |
| ScenarioLibraryPanel | Existing facade/repository, actual Auth userId owner scope and exact scenarioDraftId via PlanningNavigationResolver |
| Create Scenario / personal dashboard planning | Existing form-engine Create route with type=scenario; no publishing verification gate added |
| Eligible Create Hub / route / event shortcuts | Actual Auth tool hints control visibility; same Create params, type-specific controllers/guards still enforce operations |
| User without publishing tools | Same Creator screen, honest no-created-events state and personal actions; Settings action explains verification/tool status and promises no immediate upgrade |
| Generator control center | Actual canGenerate; Manage page opens existing Settings selection, Created events and Event insights open existing workspace, Bookings & requests opens existing Notifications |
| Generator workspace tools | Existing Generate scenario / Smart prompt / Publish idea and route/search/map/draft handoffs retained; now actual hints also control next-step generator suggestions |
| Admin Creator preview | personal composition only; real snapshot and active workspace unchanged |
| Admin Professional Page preview | Page navigation and real empty onboarding; no invented page or membership |
| Page Account | Existing ProfessionalPageWorkspacePage account section → existing Settings route with inline WorkspaceSection; Creator preview and personal return preserve nav |

The previous generator profile body and its synthetic “Managed page” card were
replaced by the existing control-center actions within the common composition.
No alternate Pro profile or invented page card remains. The two old self-select
callbacks (Manage page / Created events) now reach the existing Settings/workspace
surfaces. Existing operational Insights/Notifications and generator/route tools
remain. Only helpers made unused by this cutover were removed, including visit
preview rows, role-track cards/status badges and synthetic managed-page card.
Shared surface/action/listing/search/route widgets remain.

No new auth redirect or Viewer alias was added. Router/Create/Favorites/Visit
History/Scenario library implementations are unchanged. The same verified and
exact-page guards still apply to protected operations. Public identity visibility
is unchanged and no account becomes searchable from this label.

## Verification on the final scope

Flutter cwd: `C:/Users/User/.codex/worktrees/7275/Recharge/apps/mobile`.
Executables: `C:/src/flutter/bin/flutter.bat`, `C:/src/flutter/bin/dart.bat`.

| Exact command | Exit | Result |
|---|---:|---|
| `flutter test --no-pub --reporter expanded test/widget/profile_page_test.dart test/widget/workspace_section_test.dart test/widget/professional_app_shell_test.dart` | 0 | 18 passed |
| `flutter test --no-pub --reporter expanded test/widget/professional_app_shell_test.dart test/widget/workspace_section_test.dart test/unit/profile_role_summary_test.dart test/unit/identity_workspace_usecase_test.dart test/unit/identity_workspace_repository_test.dart test/unit/create_controller_test.dart` | 0 | 51 passed (before the additional ordinary Settings case; final group above covers it) |
| `flutter test --no-pub --reporter expanded test/widget/app_shell_test.dart test/widget/settings_page_test.dart test/widget/visited_places_page_test.dart` | 0 | 10 passed |
| `flutter analyze --no-pub` | 0 | No issues, 11.2 s |
| `flutter test --no-pub --reporter compact` | 0 | 1319 passed / 20 pre-existing skipped / 0 failed, 04:03 |

Targeted analyzer exact command, same cwd (exit 0, no issues, 8.6 s):
```powershell
flutter analyze --no-pub lib/features/explore/presentation/pages/profile_page.dart lib/features/explore/application/profile_role_summary.dart lib/core/identity/account_experience.dart lib/features/identity/application/state/identity_workspace_state.dart lib/app/presentation/recharge_app_shell.dart lib/features/identity/domain/entities/admin_experience_preview.dart lib/features/identity/presentation/widgets/workspace_section.dart test/widget/profile_page_test.dart test/widget/workspace_section_test.dart test/widget/professional_app_shell_test.dart test/unit/identity_workspace_usecase_test.dart
```

Root cwd TARGET_ROOT:
- `dart tools/scripts/check_boundaries.dart --repo-root . --format text`: exit 0,
  567 Dart files / 71 findings and existing suppressions / 0 violations,
  stale exceptions 0, expired exceptions 0, unchanged 71/71 budget.
- Standard `git diff --check`: exit 0; Windows line-ending warnings only.
- `git status --short --branch`: captured input/output; HEAD/branch unchanged.
- Retired-symbol scan with `rg -n` over mobile lib/tests for
  AccountExperience.viewer/creator, AdminExperiencePreview.viewer,
  _ViewerProfileBody, _ViewerUpgradeRow, _RoleTrack: no matches, expected rg exit 1.
- Profile/F03/F07 scan for Viewer/VIEWER/profile mode and role-tier layout
  branches: no matches. Unrelated Scenario viewer/unlistedViewer and
  PublicPageViewerContext are untouched.
- AccountExperience/AdminExperiencePreview consumers were scanned; no persisted
  name/ordinal reader/writer exists, consistent with baseline 00. Workspace and
  publisher data types/datasources are unchanged and storage regression passes.
- PowerShell Get-FileHash SHA256 plus manifest size validation: 65/65 valid,
  0 errors. Markdown links/whitespace and index prefix checked after writing.

Temporary local logs in `C:/Users/User/AppData/Local/Temp/`:
`pvr05-widgets-green.log`, `pvr05-focused-final.log`, `pvr05-extra.log`,
`pvr05-analyze-final.log`, `pvr05-full-test.log`, `pvr05-diff.log`.
Full suite ends `04:03 +1319 ~20: All other tests passed!`.
Six meaningful cases were added versus 04's 1313 passed; no skip added.
Earlier diagnostic runs failed on new test fixture API/nullability/const/finder
assumptions and responsive metric overflow; these failures were fixed and the
final affected focused and general gates above are green. The first formatter
run also caught a missing list comma before compilation; it was corrected.
This is Windows local/mock widget and unit evidence, not device/cloud/production
or a manual visual session. No native app/device screenshot claim is made.

## Acceptance and A/U evidence limits

| Criterion / scenarios | Evidence and scope |
|---|---|
| PVR-AC-07, A02, U01/U02 | Ordinary User reaches the shared Creator screen without publishing verification; direct workspace has no fallback selector. User tests cover no scope, personal scope and explicit page scope. Existing router auth ownership unchanged. |
| PVR-AC-09, A05, U07–U09 | Creator/generator actions retained; listing/status, search/map, draft, route-context and smart-route handoffs pass existing meaningful tests; actual Create guard regressions pass. |
| PVR-AC-13 | No Viewer composition, upgrade, mode selector or removed enum reference in runtime; single common personal layout and direct dashboard tested. |
| PVR-AC-14, A07/A08, U15 | One Creator row for ordinary User and Admin; only two preview choices. Real Account→inline Settings→Creator preview preserves snapshot/workspace and restores personal nav. Empty page preview never creates a page. |
| PVR-AC-15, U11 | Existing personal/page nav preserved; real page Account and Settings link exercised in shell test; additional app-shell Smart Search regression passes. |
| PVR-AC-08/20 support, A03/A04/A06 | 04 helper/real page-operation tests retained; six verification states and initial/loading/error state map to personal, snapshot flags unchanged. Ordinary Settings page-create denied by real guard. Async end-to-end loading/error auth-return matrix is not fully closed here. |
| PVR-AC-10/11 support, U03–U07 | Saved/Visited entrypoints, real unchanged Visit History suite, owned Scenario library read/handoff, private Scenario-save/public-publish guard pass. Full scenario data/access matrix remains for 06. |
| PVR-AC-18 support, U14 | Existing Event draft page publisher stays unchanged when opening Profile/workspace under all three presentation scopes and navigating owned Scenario. Full real active-workspace switch/default/non-rewrite matrix remains 06. |
| PVR-AC-21 support, U16 | New 360 dp / 150% widget case passes for common personal Profile and direct workspace; no render exception. Broader page/Settings/content combinations remain for planned regression/final stages. |

State-level active-page priority is tested along with controller-validated page
creation and switch back to personal: preview is reset, same actual access
snapshot retained. This does not invent or validate arbitrary page membership.
Owner/invited manager semantics and exact grants remain in unchanged domain and
repository checks; full A09–A12/U12/U14 data/logout matrix is not newly closed.
No full PVR-01 Done, stage 06 regression completion, stage 07 retirement/restore
or stage 08 release gate is claimed by this report.

## Archive, WIP and concurrent drift

Archive root:
`C:/Users/User/.codex/worktrees/7275/Recharge/docs/archive/viewer-profile/2026-10-10/`.
[MANIFEST](../../archive/viewer-profile/2026-10-10/MANIFEST.md) remains immutable;
all 65 raw files match recorded byte lengths and hashes; 69 total archive files
including guides remain unchanged. No original snapshot was overwritten.

Pre-05 exact copies of all agreed runtime/tests/index, protected hashes and full
input status are at:
`C:/Users/User/AppData/Local/Temp/pvr05-pfvkv_4o`.
Input WIP includes prior PVR docs/ADR/archive and 04 runtime/tests, plus backend
Media D2/tooling/rules/tests/scripts, API schemas/fixtures and launch/media docs.
The overall tree stays dirty; this slice was not committed.

Protected scan covered 2164 pre-existing regular tracked/untracked files outside
allowed paths; 2162 match entry bytes. Two backend scripts changed during this
turn outside this task's write operations. No edits, overwrite, rollback, tests
or authorization claim on that concurrent backend work were made. Drift hashes:

| Outside-scope file | Input SHA-256 | Observed output SHA-256 |
|---|---|---|
| `apps/backend/scripts/emulator-stand.mjs` | `5837C388337DBBB58E4C53F52A58B8F9EF4732C458A92F9DD374007622BAC15E` | `9DAF29BCF3886F6922E8A7A44CF12CF387E7206EA19479240449FBF14FC6C4D3` |
| `apps/backend/scripts/emulator-stand.test.mjs` | `CD80A6F6D1A229A6E07A56E6053DF1B99EBF64325EAABDCC1A63623D429B725C` | `C067BC73CBA02012149192D03775D37AAAE78E1CF58F79AAD1A382420E31525C` |

Full status snapshots are `status-input.txt` / `status-output.txt` in the backup
directory; the protected inventory is `protected.json`, concurrent changes are
`foreign-drift.json`. Output status is refreshed after final checks.
T04 is also explicitly byte-compared to its input backup and unchanged.
All previous handoffs, accepted ADR/plan, source archive and unrelated mobile
source/test/storage files are unchanged. The two foreign script hashes above
are observations, not PVR implementation changes.

## Important final hashes

All paths relative to TARGET_ROOT. Later changes to these must be explained in
a new handoff, rather than rewriting this report or previous evidence.

| Path | SHA-256 |
|---|---|
| `apps/mobile/lib/features/explore/presentation/pages/profile_page.dart` | `F61327774A67C27944B933C9BDB271086CCBD1DB6C193AE254575226692F5BE9` |
| `apps/mobile/lib/features/explore/application/profile_role_summary.dart` | `E7E304D6D0C744627C7B2637D4539185BA6F29F9F98EFE4645171F98EBCC1CE3` |
| `apps/mobile/lib/core/identity/account_experience.dart` | `847D09F0C50A5C14986BBA979262DAEC8BDBC3642F87DB14554F0FF6189F29B9` |
| `apps/mobile/lib/features/identity/application/state/identity_workspace_state.dart` | `0D1EA0C5E2885D4440143180C050C91F38E34B5F69C9FFEAA772D4C3EB7E0B30` |
| `apps/mobile/lib/app/presentation/recharge_app_shell.dart` | `79B7E02021AA28A3E510EA99D96E1A5D2DBD36BFE85A0041EA4371CD6C69EF8B` |
| `apps/mobile/lib/features/identity/domain/entities/admin_experience_preview.dart` | `F0567F96BE44FF5160F603AD058888A748A62D463A6A5A86D1C45D3D20628056` |
| `apps/mobile/lib/features/identity/presentation/widgets/workspace_section.dart` | `EDE8C7F53C940D2DA062190B02B24FE759445E8E2F8103E7AC8072EE24AEB17C` |
| `apps/mobile/test/widget/profile_page_test.dart` | `8A87E6D6B5FAD77F20EEE24E3274133FE03920A58A59D0B5CADE2DA0F81F0F38` |
| `apps/mobile/test/widget/workspace_section_test.dart` | `77838ABD5D256444BE481EAB3A409F47556D8C6A169D6D8F523FC3D5E3C857BA` |
| `apps/mobile/test/widget/professional_app_shell_test.dart` | `FA1AAE8D34B9B0D75AC9D8D8C7917412A7D94E465F6A8BAA8387F5F9DD6A7A51` |
| `apps/mobile/test/unit/identity_workspace_usecase_test.dart` | `54C9365217D94FFF121E2AAB458A76A74F7F2AE4863F6D3FF7928DB5148259DA` |
| `apps/mobile/test/unit/profile_role_summary_test.dart` | `BE343442200E5A4A5DCB6E229C9B16CAC281A048BE77533EC213B7D8D6A1B23B` |
| `docs/adr/0021-unified-personal-profile.md` | `5CEEF9575528B71DE454952D5DB82D9073C9ADE3F81B549471FC0526E5B88184` |
| `docs/product/VIEWER_PROFILE_RETIREMENT_PLAN.md` | `AA31BE37FF411BF96CB5F95E30E8405B20B8B86B3FE99A45F902EE5363CF1232` |
| `docs/verification/pvr-01/04-presentation-access.md` | `2FE5F84A9B77A8D837B4A28499DC176C020FD7896D4E8281BFEFFDA6DE63447D` |
| `docs/archive/viewer-profile/2026-10-10/MANIFEST.md` | `CE309F4E5BD8952A7AF4F0C4CADD4865396BCA6DDC12376AE2EC5C32C0DFF214` |
| `apps/mobile/lib/features/identity/domain/entities/workspace_ref.dart` | `25764E4187D58220E07F5E2E4394C052625A67B41C6B7C3B264B3C1F7B49302D` |
| `apps/mobile/lib/features/identity/data/datasources/identity_workspace_local_datasource.dart` | `2FA9F279EAA74D57286534440BC60C9878D1B57574EAA06A2BC39D71E5328BC3` |
| `apps/mobile/lib/app/application/active_create_publisher_provider.dart` | `0457F64543F30D7E258EB9EA603B3CC4DFFC480714DA1CF598EF6D52166E3514` |
| `apps/mobile/lib/features/explore/presentation/widgets/scenario_library_panel.dart` | `D697B6370E7BD7E2613E7A47CC4EDF173A8C24270A3741D0782D4A4772CEA2D4` |

## Rollback and next stage

Rollback is one coordinated unit: restore **all F01–F07 and the four changed
T01/T02/T03/T05 files** from the pre-05 exact copies above. T04 stays at 04 input.
Delete only this new 05 report and remove only the appended 05 index block;
pre-05 index copy is in that same backup. Check for later edits before restoring;
apply a reverse patch if subsequent work overlaps. Never return just the enum
or one consumer, never blanket reset, never overwrite prior 03/04 or concurrent
backend WIP. User storage/access/page/favorites/visits/plans is not rolled back.
The 01 archive is historical evidence, not a substitute for the 04 entry copies.

06 may start only when separately dispatched by the user. The coherent cutover
and local gates are ready for broader A/U regression; its agent must re-check
HEAD/WIP/hashes. Do not assume that page membership, logout/login isolation,
complete auth-error-return, actual workspace publisher non-rewrite, all page
small-screen variants or production/device gates were exhaustively exercised.
ProfileRoleTier and legacy compatibility projection remain internal access/tool
compatibility helpers; they no longer choose personal layouts. Cleanup and
Viewer documentation retirement/restore drill belong to 07; final launch/status
and full-plan verdict belong to 08. No unresolved blocker for bounded 05.
