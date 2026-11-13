# PVR-01 / 04 — Presentation/access preparation

STAGE: **04**; RESULT: **ready**; DATE: **2026-10-10** (Europe/Moscow).
TARGET_ROOT: **C:/Users/User/.codex/worktrees/7275/Recharge**.
HEAD input/output: **8c69715bba03eb1cef7309d4496ebfddd6d11a1e**.
BRANCH input/output: **codex/recharge-integration**.
Ready means compile-safe preparation for separately dispatched stage 05.
No full UI cutover, enum deletion, stage 05, commit, push, merge, deploy,
cloud operation, new agent or messaging another chat was performed.

## Input and authority

Input: user attachment “PVR-01 / заход 04: Разделение представления и полномочий”;
actual [03 handoff](03-spec-migration.md), verification index, accepted decision
and bounded master plan. Earlier 00–02 evidence is retained and hash-protected;
this report does not relabel earlier execution as new verification.
Target root remains 7275, rather than the chat cwd 4d5f, following the fixed
00–03 target. Target root AGENTS and user instructions apply.
[ADR 0021](../../adr/0021-unified-personal-profile.md) is **Accepted**: explicit
user acceptance “Принимаю конкретный текст ADR 0021 и связанный bounded scope
плана §6.1/§13”. [Master plan](../../product/VIEWER_PROFILE_RETIREMENT_PLAN.md)
v2.3 retains that bounded contract. Both hashes and 03 hash match input.
No prior ADR or master-plan content changed.

## Own bounded delta — five files

1. `apps/mobile/lib/features/explore/application/profile_role_summary.dart`:
   pure `ProfilePersonalPresentation` exposes one Creator title/personal layout,
   independent of tool access; missing role/capability input fails closed.
   `profileRoleSummaryForPresentation` changes legacy labels/layout while
   retaining actual canCreate/canGenerate and the same descriptive capabilities
   list. No account entity/snapshot is copied or rewritten.
2. `apps/mobile/lib/features/explore/presentation/pages/profile_page.dart`:
   `_profilePresentationSummary` and direct-workspace fallback use that decorator;
   publications/actions use actual tool flags, not selected display tier.
3. `apps/mobile/test/unit/profile_role_summary_test.dart`: 13 total cases, 10 new;
   unknown inputs, all preview tiers, shared personal projection, six verification
   states through the real CreateProfessionalPageUseCase and missing page grant.
4. This new handoff.
5. `docs/verification/PVR_01_VERIFICATION.md`: append-only stage 04 result/link.

No imports were added to Explore UI. Identity domain imports are confined to the
unit test. No backend, repository/domain, storage, Auth, identity snapshot,
PublisherRef, router, form engine, dependency, generated file or asset changed.
`ProfileRoleTier`, legacy generator/route features, screen composition and current
labels remain until 05. The new personal projection is unit-tested preparation;
it has not replaced ProfilePage's entire rendering.

## Action map (final profile_page.dart lines)

| Uses/symbol | Classification | Owner and treatment |
|---|---|---|
| 80–84, 360–375: actual summary / presentation decorator | Actual UI hints versus display | Actual Auth role/caps retained; selected tier cannot add flags |
| 90–98: dashboard default and VisitHistory watch/load | Legacy layout/query composition | Remains for 05; do not assume visits already available in every personal composition |
| 112,154,158,171–186: title/Hero/tabs/body branch | Legacy display/layout | Kept compile-safe; 05 must unify without deleting personal content |
| 303–323: title, badge, context line | Display only | Legacy terminology, not verified identity or operation authority |
| 371: direct workspace selected tier | Display | Decorator retains actual flags; `_activeRoleTierFor` uses existing unlock hints |
| 619/632,673/701/712: Hero and DashboardTabs | Display/tab composition | Existing tier layout remains for 05 |
| 1552–1567: legacy role track | UI tool selector hint | Uses actual accessSummary.canCreate/canGenerate; no mutation grant |
| 1786: creator publications panel | Tool visibility | Real canCreate retained, no preview promotion; original listing callbacks unchanged |
| 1829/1855: workspace generator/creator actions | Tool visibility/handoff | Real canGenerate/canCreate; eligible legacy actions retained independent of preview |
| 2676: CreatorNextSteps generator variant | Legacy suggestion/handoff variant | Display-tier branch remains; route/controller guards remain operation authority |

Passing a summary into Hero/workspace/next-steps does not create another access
source. `ProfileRoleSummary.capabilities` is legacy descriptive UI text, **not**
the account's grant set. `canCreate`/`canGenerate` are existing Auth-derived coarse
tool hints, **not** proof of verified Creator, submission/publication or page
membership. This slice deliberately does not infer verification from role.

Personal Saved, self-reported Visit History and private Scenario operations retain
their existing repositories/controllers and owner/auth checks. Current navigation
routes `/profile`, `/profile/workspace`, visited/details, Create and legacy route
handoffs are unchanged. Actual Create/Scenario operation checks stay in
`features/create/application/controllers/create_controller.dart`: route selection
needs `create.route`; personal Scenario save is private and public publication is
blocked by its own guard. Actual page creation stays in
`CreateProfessionalPageUseCase`: verification plus page.create, exact user and
owner/membership rules, not a presentation tier. Existing publish/submit/page
mutation checks and Publisher selection are untouched. Auth redirect ownership
stays in app router/Auth. No new verified badge was introduced.

## Checks — executed on the current delta

Working directory for all Flutter commands:
`C:/Users/User/.codex/worktrees/7275/Recharge/apps/mobile`.

| Exact command | Exit | Result |
|---|---:|---|
| `flutter test --no-pub --reporter expanded test/unit/profile_role_summary_test.dart test/unit/identity_workspace_usecase_test.dart test/unit/identity_workspace_repository_test.dart test/unit/create_controller_test.dart` | 0 | 48 passed |
| `flutter test --no-pub --reporter compact test/widget/profile_page_test.dart test/widget/workspace_section_test.dart test/widget/professional_app_shell_test.dart` | 0 | 13 passed |
| `flutter test --no-pub --reporter compact test/widget/app_shell_test.dart test/widget/settings_page_test.dart test/widget/visited_places_page_test.dart` | 0 | 10 passed |
| `flutter analyze --no-pub lib/features/explore/application/profile_role_summary.dart lib/features/explore/presentation/pages/profile_page.dart test/unit/profile_role_summary_test.dart` | 0 | No issues; 12.8 s |
| `flutter analyze --no-pub` | 0 | No issues; 34.4 s |
| `flutter test --no-pub --reporter compact` | 0 | 1313 passed, 20 skipped, 0 failed; 03:00 |

Final root gates, cwd TARGET_ROOT:
- `dart tools/scripts/check_boundaries.dart --repo-root . --format text`: exit 0;
  567 files, 71 findings/suppressions, 0 violations/stale/expired exceptions;
  budget 71/71 unchanged.
- `git diff --check`: exit 0 (existing Windows LF/CRLF informational warnings).
- `git diff --check --` followed by the three own source/test paths: exit 0.
- `dart format` on the three own paths: exit 0, no extra files formatted.
- Exploratory `git -c core.autocrlf=false diff --check` exited 1, treating existing
  CRLF in unrelated WIP as trailing whitespace. This was not a green result;
  the required standard Git configuration check above passed. No line-ending
  rewrites of unrelated files were made.

Full test output was captured at
`C:/Users/User/AppData/Local/Temp/pvr04-full-test.log` (local ephemeral evidence),
ending `03:00 +1313 ~20: All other tests passed!`. All 20 skips predate this slice;
no skip was added. Analyzer/boundary/focused output is in this chat's tool evidence.
This is Windows local/mock evidence, not device/cloud/production evidence.

## Acceptance/scenario scope

- PVR-AC-08: confirmed for current helper/decorator and real existing guards;
  no additional flags/grants from preview. This does not close every post-cutover
  screen scenario.
- PVR-AC-20: confirmed for null/unknown projection fail-closed behavior;
  existing auth/shell tests passed. Async missing/loading/error snapshot screen
  integration and post-cutover auth return must still be checked in later stages.
- A02/A03: helper plus operation-specific evidence; all six verification states
  use the real page-creation guard (five denied, verified+grant succeeds).
  Creator-role hints never replace that verification guard.
- A04: verified without page.create denied, no invented generator/page grant.
- A05: verified+page.create positive guard; existing Creator listings, route
  grant rejection and private Scenario save/public publish rejection tested.
- A07/A08: existing identity/usecase/widget preview regression passed; new
  projection preserves actual flags. No fake page/membership or publisher input.
- A01/A06: existing auth regression plus null/unknown helper evidence only;
  not a claim that every missing/error runtime snapshot path was exercised.
- U01/U02 and full A01–A08 unified Creator screen matrix: **not checked after
  cutover**, because cutover is not part of 04.
- U03–U09: existing profile/visited/Create regression passed, including listing,
  saved/search/route handoffs and personal Scenario guards; unified screen reachability
  and full personal Scenario library route acceptance remain for 05/06.
- Remaining PVR-AC and A/U scenarios are not closed by this preparation.

## Archive, WIP and preservation

Immutable archive:
`C:/Users/User/.codex/worktrees/7275/Recharge/docs/archive/viewer-profile/2026-10-10/`.
[MANIFEST](../../archive/viewer-profile/2026-10-10/MANIFEST.md): 65 raw snapshots
checked individually for bytes and SHA-256, 65/65 valid; all 69 archive files
(including guides) protected from change. No archived source bytes were updated.
1018 protected files matched entry hashes (mobile lib/tests excluding the three
allowed paths, archive, reports 00–03, ADR and plan). This is the scope of the
hash check, not a claim of byte-level hashing every unrelated backend WIP file.

Input WIP included existing backend Media D2/real-tools/rules/tests/scripts,
api_contracts content/media fixtures/schemas, launch/media docs and prior PVR
AGENTS/VISION/identity docs plus untracked ADR/plan/archive/retirement map/reports.
Those files were read-only in 04. Input/output full status snapshots are local:
`C:/Users/User/AppData/Local/Temp/pvr04-8tuk75ms/status-input.txt` and
`status-output.txt` (refreshed after final checks). Output adds the
three allowed mobile edits and this report/index addition; HEAD/branch unchanged.
The overall working tree remains dirty; no claim of stabilization/release Done.

## Important final file hashes

| Path relative to TARGET_ROOT | SHA-256 |
|---|---|
| `apps/mobile/lib/features/explore/application/profile_role_summary.dart` | `813567BF0084B15478547663D1878243FD6E79DA72C5C9C383A72160A9B44937` |
| `apps/mobile/lib/features/explore/presentation/pages/profile_page.dart` | `5090E0D5DE7470DEE5C2207C0BFD81C4FFC44AA0D8B62B8A196E277297127872` |
| `apps/mobile/test/unit/profile_role_summary_test.dart` | `BE343442200E5A4A5DCB6E229C9B16CAC281A048BE77533EC213B7D8D6A1B23B` |
| `docs/adr/0021-unified-personal-profile.md` | `5CEEF9575528B71DE454952D5DB82D9073C9ADE3F81B549471FC0526E5B88184` |
| `docs/product/VIEWER_PROFILE_RETIREMENT_PLAN.md` | `AA31BE37FF411BF96CB5F95E30E8405B20B8B86B3FE99A45F902EE5363CF1232` |
| `docs/verification/pvr-01/03-spec-migration.md` | `9D2F0E47B0E5FA584953A46AF96223EA98E5D9B67761775D2E3DA826D1953E00` |
| `docs/archive/viewer-profile/2026-10-10/MANIFEST.md` | `CE309F4E5BD8952A7AF4F0C4CADD4865396BCA6DDC12376AE2EC5C32C0DFF214` |

## Rollback and next handoff

Rollback only own delta: restore the three edited source/test files from the
exact entry copies in `C:/Users/User/AppData/Local/Temp/pvr04-8tuk75ms/`, remove
this new report, and remove only the appended stage 04 block from verification
index (exact pre-append copy `verification-index-before04.md` in that directory).
Before rollback check that no later agent has edited those paths. Do not git-reset
unrelated WIP. Archive remains the historical 01 source, not a replacement for
later 02/03 edits.

05 can use `ProfilePersonalPresentation` for one personal layout and actual tool
hints, and the decorator as a transition helper. Do not treat
`profileRoleSummaryForTier` templates or selected tier as account access. Keep
operation guards and actual identity snapshot as authority. 05 still must perform
full Profile/workspace cutover, remove presentation Viewer branches/selector as
approved, expose shared personal content, preserve all eligible legacy actions,
and exercise post-cutover A/U routing and permissions. Enum deletion and
retirement documentation remain in their separately dispatched stages.
No unresolved blocker for bounded 04; no stage 05 work started.
