# C1–E2 closure review — 2026-10-08

Scope: local worktree 7275; no Desktop transfer, push, merge, cloud or device
completion. Base HEAD: `42f88508263e8b0634a4aa013622dff2a97c1263`.

## Closure follow-up file list

Runtime: `apps/mobile/lib/app/di/service_locator.dart`,
`apps/mobile/lib/features/create/application/event_create_coordinator.dart`,
`apps/mobile/lib/features/create/domain/usecases/validate_event_draft_usecase.dart`,
`apps/mobile/lib/features/create/domain/usecases/validate_event_access_configuration_usecase.dart`.

Tests: `apps/mobile/test/unit/event_access_readiness_test.dart`,
`apps/backend/scripts/verify-content-persistence-layout.test.mjs`,
`apps/backend/functions/test/integration/content_publication_security.test.ts`,
`apps/backend/functions/test/integration/media_security.test.ts`.

Diagnostics: `apps/backend/scripts/emulator-stand.mjs` and
`apps/backend/README.md` (process identity audit and cold-start command).
`apps/backend/functions/package.json` wires the negative allowlist test into
the existing `verify:content-persistence:layout` command.

Documents: `docs/architecture/LAUNCH_STATUS.md`, `docs/product/RECHARGE_BACKEND_DELIVERY_MAP.md`,
`docs/product/EVENT_INTERNAL_REGISTRATION_E2_0_AMENDMENT.md` and this review.
These are the closure edits on top of the preceding C1–E2 implementation.
The whole local change is divided into backend/contracts, mobile and
documentation commits; Desktop work has not been transferred.

Continuation authorized 2026-10-08: remaining local gates and conditional local
commits, with the gates' own identity-checked process cleanup. `emulator-stand.mjs`
now records PID/parent/start-time/executable after successful verified stop in
`%LOCALAPPDATA%/Recharge/emulator-stand/demo-recharge/process-stop-audit.jsonl`.
The stop checks are unchanged; no command lines or credentials are stored.
This diagnostic extension and the local discovery-timeout command are included
in `apps/backend/README.md`; no process rule is relaxed for unrelated work.

## Gate correction disclosure

The previous Content layout rule prohibited every outside consumer of the
Content persistence adapter. According to the preceding implementation report,
it was red from C1 through E1 and that failure was not disclosed in those
reports. This is a historical missing gate, not historical green evidence.
The accepted repair is an exact path/symbol allowlist, not unrestricted access.
Current negative tests reject an unknown consumer, a sibling `content_foreign`
consumer, a repository import in a guard-only consumer, and an additional
dynamic import in an allowed file; tests run in a disposable copy. The static
security tests likewise use directory boundaries, not name prefixes.

Approved consumers to review: Content entry (repository/composition), Media
composition (repository), Media repository (Emulator guard), Moderation
adapter (repository/collection IDs), Moderation composition (repository),
staff authority (guard), Moderation repository (guard), Catalog composition
(repository), Catalog repository (guard). Content remains the publication
writer; guard borrowing does not grant write authority.

| Exact allowed path under `apps/backend/functions/src/` | Reviewed imports and purpose |
|---|---|
| `content_entry.ts` | `FirestoreContentRepository`, `createEmulatorContentService`; guarded Content command/query entry |
| `modules/media/infrastructure/emulator_media_composition.ts` | `FirestoreContentRepository`; Content attachment/readiness integration |
| `modules/media/infrastructure/firestore_media_repository.ts` | `assertContentEmulatorContext`; guard only |
| `modules/moderation/infrastructure/content_moderation_adapter.ts` | `contentCollections`, `FirestoreContentRepository`; disposition through Content service |
| `modules/moderation/infrastructure/emulator_moderation_composition.ts` | `FirestoreContentRepository`; compose Content disposition adapter |
| `modules/moderation/infrastructure/emulator_staff_authority.ts` | `assertContentEmulatorContext`; guard only |
| `modules/moderation/infrastructure/firestore_moderation_repository.ts` | `assertContentEmulatorContext`; guard only |
| `modules/catalog/infrastructure/emulator_catalog_composition.ts` | `FirestoreContentRepository`; read published Content facts |
| `modules/catalog/infrastructure/firestore_catalog_repository.ts` | `assertContentEmulatorContext`; guard only |

Process diagnostic enhancement may name the refused process but must not change
identity verification or allow foreign executables. Cleanup in the authorized
2026-10-08 gate continuation retains those checks and records exact identities.

## Map and Details scope comparison

The accepted [Catalog specification §6.3](DISCOVER_SEARCH_CATALOG_BACKEND_SPEC.md)
defines Map as the map-eligible subset of Feed, with `onlineOnly`/`noPublicGeo`
reasons, and Details as the selected exact revision. Its geo contract forbids
invented coordinates. The map change filters non-finite public points from
markers and camera moves while retaining the Feed/list item; it implements
that contract, not a new filter policy.

E1 expressly excluded full description. It is now an explicit E2a scope
addition in the [accepted E2 amendment §12](EVENT_INTERNAL_REGISTRATION_E2_0_AMENDMENT.md)
and Catalog §34, with these acceptance criteria: Details receives the full
description from the selected published revision, Feed/Search/Map cards retain
only the short description, and hidden content cannot resolve to Details.
Projection v2 and its reader migrate together; the amendment records rollback.
The E2a stand gate checks revision parity and hide, and the Emulator query test
checks that cards never carry full description. This does not rewrite E1 scope.

Other explicitly accepted file-map deviations are visible in the local commits:
`scripts/emulator-stand.mjs` names the refused executable/process without changing
the refusal; `scripts/stand-seed.mjs` and `functions/test/stand/stand_main.ts`
expose the test-only `creator-fixture` implemented in `stand_creator_fixture.ts`;
`functions/test/support/content_event_world.ts` supplies the shared publication
fixture used by the Emulator effect/query/transition/handoff tests. These paths
are under `apps/backend/`; none grants a production endpoint or writer bypass.

## Desktop transfer plan — Step B not executed

Live Desktop HEAD: `be17822ed1ee7b750274430b39ba38e07c0c4a0a`, branch
`codex/wip-desktop-idp-04a-05a`. The current untracked WIP is `.claude/skills/`;
there are no tracked working-tree modifications. The older description of
large uncommitted Desktop WIP is not the current state.

1. Candidate transfer files: none of the current untracked skills are part of
   C1–E2. Keep `.claude/skills/` unchanged and outside this transfer.
2. The full branch diff includes unrelated canonical backend history. The
   actual Desktop contribution is one commit, `be17822` (IDP-04A/05A), with
   27 files relative to common base `a96efa7`. Use this commit/base for the
   transfer inventory below; do not copy the full branch diff. Shared changes
   are conflict candidates, not proof of a textual conflict.
3. Preserve original Desktop checkout and commit IDs. Before authorized
   transfer, create a recoverable snapshot of both checkouts and preserve
   untracked originals in `%LOCALAPPDATA%/Recharge/desktop-transfer/<UTC stamp>/`:
   `canonical.bundle`, `desktop.bundle`, `desktop-untracked-skills.zip` and
   `manifest.json` with original branches/HEADs, file inventory and SHA-256.
   Verify both Git bundles and compare a temporary archive extraction with
   the original untracked files before editing. No backup/transfer is run here.
4. Apply only approved hunks in an isolated integration checkout; for shared
   DI/Create/Details/status files use a three-way merge, never file replacement.
   Start from the completed canonical closure commits and apply the one
   Desktop contribution without modifying either original checkout. Resolve
   the seven textual conflict files explicitly; review the other 20 files for
   Publisher/capability semantics even if the merge is textually clean.
5. Verify focused tests, full Flutter analyze/test, backend gates if touched,
   boundaries and diff checks. Keep source originals until review and recovery
   verification; push/merge remain separately authorized.

The candidate Step B is the IDP-04A/05A commit below, subject to explicit owner
transfer approval. Preserve `.claude/skills/`. `AGENTS.md` and `LAUNCH_STATUS.md`
require semantic reconciliation, not replacement; accepted ADRs stay untouched.

2026-10-08 read-only three-way probe (temporary copies, LF-normalized;
`git merge-file --stdout`, no index or checkout changes): seven files have
textual conflicts, 20 conflict regions in total. They are `AGENTS.md` (2),
`discover_details_parity_test.dart` (2), `create_controller_test.dart` (2),
`create_page_test.dart` (1), `discover_details_page_test.dart` (8),
`profile_page_test.dart` (3), and `LAUNCH_STATUS.md` (2), at the exact paths in
the inventory below. The other 20 files merge textually; DI and Create still
require semantic review of Publisher/capability behavior. Nothing was applied.

| Candidate file from `be17822` | Comparison against canonical changes |
|---|---|
| `AGENTS.md` | both branches/worktree changed; three-way hunk review |
| `apps/mobile/lib/app/adapters/identity_publisher_access_check.dart` | Desktop-only relative to common base |
| `apps/mobile/lib/app/di/service_locator.dart` | both branches/worktree changed; three-way hunk review |
| `apps/mobile/lib/features/create/application/controllers/create_controller.dart` | both branches/worktree changed; three-way hunk review |
| `apps/mobile/lib/features/create/application/create_providers.dart` | Desktop-only relative to common base |
| `apps/mobile/lib/features/create/data/repositories/create_repository_impl.dart` | Desktop-only relative to common base |
| `apps/mobile/lib/features/create/domain/entities/draft_publisher.dart` | Desktop-only relative to common base |
| `apps/mobile/lib/features/create/domain/repositories/publisher_access_check.dart` | Desktop-only relative to common base |
| `apps/mobile/lib/features/create/presentation/widgets/find_people_create_block.dart` | both branches/worktree changed; three-way hunk review |
| `apps/mobile/lib/features/create/presentation/widgets/place_create_block.dart` | both branches/worktree changed; three-way hunk review |
| `apps/mobile/lib/features/create/presentation/widgets/rental_create_block.dart` | Desktop-only relative to common base |
| `apps/mobile/lib/features/create/presentation/widgets/session_create_block.dart` | Desktop-only relative to common base |
| `apps/mobile/lib/features/identity/application/controllers/identity_workspace_controller.dart` | Desktop-only relative to common base |
| `apps/mobile/lib/features/identity/presentation/pages/professional_page_workspace_page.dart` | Desktop-only relative to common base |
| `apps/mobile/test/features/discover/presentation/discover_details_parity_test.dart` | both branches/worktree changed; three-way hunk review |
| `apps/mobile/test/unit/create_controller_test.dart` | both branches/worktree changed; three-way hunk review |
| `apps/mobile/test/unit/create_publish_guards_test.dart` | Desktop-only relative to common base |
| `apps/mobile/test/unit/create_publisher_defaults_test.dart` | Desktop-only relative to common base |
| `apps/mobile/test/unit/identity_workspace_usecase_test.dart` | Desktop-only relative to common base |
| `apps/mobile/test/unit/rental_direct_publish_controller_test.dart` | Desktop-only relative to common base |
| `apps/mobile/test/widget/create_blocks_small_screen_test.dart` | Desktop-only relative to common base |
| `apps/mobile/test/widget/create_page_test.dart` | both branches/worktree changed; three-way hunk review |
| `apps/mobile/test/widget/discover_details_page_test.dart` | both branches/worktree changed; three-way hunk review |
| `apps/mobile/test/widget/event_details_page_test.dart` | both branches/worktree changed; three-way hunk review |
| `apps/mobile/test/widget/professional_page_workspace_guard_test.dart` | Desktop-only relative to common base |
| `apps/mobile/test/widget/profile_page_test.dart` | both branches/worktree changed; three-way hunk review |
| `docs/architecture/LAUNCH_STATUS.md` | both branches/worktree changed; three-way hunk review |

## B1-device checklist — physical Android and iOS remain open

- Record device/OS/build/commit, transport endpoint and runtime flags for each
  physical device. Use only the approved local demo stand and isolated users.
- Confirm guards deny release, disabled/localOnly and non-demo/non-loopback
  binding; physical routing needs an explicit supported transport plan rather
  than silently weakening the loopback guard. PC host tests cannot prove it.
- With an approved device endpoint, create/upload/submit/moderate/publish,
  discover in Feed/Search/Map, open the same revision in Details, book/retry/
  cancel; record identifiers and outcomes without private tokens.
- Check two independent users, no duplicate Booking or oversell, hide/restore
  and eventual rejection after Booking applies hide. Do not claim instant fence.
- Check app restart, interrupted upload/command, journal recovery, permissions
  and connectivity loss. Retain originals through recovery verification.
- Run platform build/signing and device-specific acceptance checks; record
  Android and iOS separately. Emulator is supplementary evidence only.

## Future bounded slices (not implemented here)

1. Booking hide fence: specify authoritative transaction fence, races and
   retry/idempotency behavior, migration/rollback and no-oversell tests before
   real Booking use; no implicit lifecycle change in E2.
2. Discover covers/organizer: Media read URL authority/lifetime/privacy and
   public organizer projection with revision/removal behavior.
3. Catalog extensions: BCK08-OD-04 plus OD-05/08/10, explicit supported types,
   contracts and negative tests. Cloud indexes require separate cloud approval.
4. Internal registration extensions require their own scope. Current v1 stays
   free/offline/instant, relative windows, no named guests/waitlist/manual
   confirmation; published protected fields stay immutable. Test limits stay
   test limits.

The following are proposed planning slices, not approved implementations:

| Slice and order | Bounded scope and acceptance | Decision and rollback boundary |
|---|---|---|
| F1 — Booking hide fence | Define a Booking-owned fence and its relation to the Content hide commit. Test the race before/after hide, retries and restore ordering; no new booking after the agreed fence, no duplicate booking or inventory leak. Preserve bookings accepted before that boundary. Candidate areas: `booking/create_internal_booking.ts`, `booking/event_projection_consumer.ts`, `booking/occurrence_lifecycle.ts`, Content handoff and their race tests. | Owner accepts the atomicity contract and exact file map first. Dual-aggregate writes are not silently introduced. Backfill existing occurrences before enabling; rollback disables new internal bookings rather than promising a fence that has been removed. Required before real Booking use. |
| F2a — Discover covers | Define authorized Media read delivery for published revision/attachment, hide/removal behavior, expiration and cache policy. A published cover renders; unauthorized or hidden assets remain inaccessible; missing/expired covers have a safe fallback. Candidate areas: Media read port/service/entry, Catalog projection, mobile Catalog datasource and Details. | Approve delivery authority and privacy policy, then exact files. Start on local demo fixtures; cloud signing/deployment needs separate authorization. Rollback removes delivery fields and uses the current cover fallback. |
| F2b — Organizer public projection | Project a public publisher label by stable user/page ID with revision and removal semantics. Feed/Details agree; a rename refreshes through the chosen projection policy, private identity fields never enter Catalog. | Approve the public label source and freshness contract. Rollback ignores the new optional label and keeps existing publisher IDs; no identity verification behavior changes. |
| F3 — Catalog type and query contracts | Decide BCK08-OD-04 ten-type mapping, OD-05 ranking features/weights, OD-08 cache/freshness thresholds and OD-10 numerical limits. Implement one accepted type family per file map; unsupported types remain denied. Validate revision, visibility, filtering, Details parity and no-public-geo behavior. | Product/architecture decisions precede code. Local fixture bounds remain test-only. Projection version and readers migrate together with rebuild/activation/rollback; cloud indexes and production limits remain separately gated. |

Payment, online/hybrid, absolute windows, named guests, waitlist and manual
confirmation are excluded from these slices; each extension needs its own
accepted Event-contract amendment and migration criteria.

## Current verification

Verified during the closure implementation; Dart runtime/test sources were not
changed in the 2026-10-08 continuation:

- Mobile `flutter analyze --no-pub`: no issues. The initial full
  `flutter test --no-pub` passed 1282 tests, with 18 stand tests skipped because
  the stand was not running. After the offset-zero adjustment, focused tests
  passed 10/10 and full analysis passed again; the repeated full suite also
  passed 1282 tests with 18 stand skips (exit 0, 23m25s elapsed).
- Create readiness behavior test passed; it checks default denial, live
  readiness change, unsupported online configuration and denial restoration.
  The valid E2 relative closing offset zero is allowed only when internal
  registration readiness is granted; other modes retain the original rule.
- `api_contracts` full suite: 23 passed.
- Backend build/typecheck and lint passed; separate unit/contract/integration
  suites: 582/45/179 passed. The initial combined suite failed five stale
  static security assertions; they are described below, not hidden.
- Content layout and its disposable-copy negative test passed. All nine
  outside persistence consumers were reviewed: Media uses Content's own scope,
  Catalog reads published facts, Moderation writes only through Content's
  verified disposition service; four guard-only users gain no repository.
- Format check passed. Boundary gate: 0 violations, 71 suppressed exceptions,
  71/71 budget. Normal Git `diff --check` passed. A diagnostic attempt forcing
  `core.autocrlf=false` reported CRLF as whitespace and was not the normal gate.
- Exact Node/npm/Java/Terraform toolchain passed after using the pinned Java
  and Terraform directories on PATH. IaC topology passed local mock-only
  authorization checks, fmt/validate and negative record checks, without cloud.
- Cloud-context denial, generated-output, R1 layout/config/exports, execution
  manifest, reference-data layout, security/privacy layout and
  identity/publisher layout gates passed through direct pinned-Node execution.
  All three literal npm verify-contract wrappers (Identity, reference data,
  security/privacy) subsequently passed through the intact pinned npm copy.
  Literal npm format/lint/typecheck wrappers also passed after the test changes.

### 2026-10-08 continuation

The intact pinned Node 22.23.2/npm 10.9.8 under
`apps/backend/.r0-tools/node/node-v22.23.2-win-x64` is used throughout. The older
Temp npm copy was incomplete; it was not installed over or used as evidence.
No global tool installation was needed.

| Literal local command | Current result |
|---|---|
| `npm run test:stand` | Passed, 24 tests; own spawned processes cleaned up |
| `npm run stand:e2-gate -- --yes` | Passed on retry; two independent PC clients, publication/Catalog/Details/Booking/cancel/hide/reconciliation |
| `npm run stand:discover-gate -- --yes` | Passed; shared revision, second account and hide |
| `npm run stand:catalog-gate -- --yes` | Passed; idempotency, moderation hide, rebuild/activation/rollback |
| `npm run stand:event-gate -- --yes` | Passed; interrupted seed recovery and publication through the test UI |
| `npm run stand:moderation-gate -- --yes` | Passed; staff guards, reason, receipts and stale restore |
| `npm run stand:media-gate -- --yes` | Passed; fixture upload, exact attachment, wrong bytes and denied gate |
| `npm run stand:mobile-gate -- --yes` | Passed; Session lifecycle and binding transitions |
| `npm run stand:booking-gate -- --yes` | Passed, three fresh runs; create/cancel, double tap, lost response, journal restart and offline, backend counts |
| `npm run stand:acceptance -- --yes` | Passed; export/import and reset/seed digests agree |
| `npm run test:emulator` | Passed, exit 0; complete default suite and Emulator shutdown |

The first E2 attempt failed during cold Functions discovery at the CLI's
default 10-second timeout, before acceptance tests began; its verified cleanup
completed. The sequential retry used local `FUNCTIONS_DISCOVERY_TIMEOUT=60`
and passed, retaining the stand's startup deadline and loaded-trigger checks.
This is local bootstrap configuration, not a production timeout/SLO default.
No repeat of the earlier short-lived-process stop refusal has occurred in the
current successful gates; the identity checks were not weakened.

The strengthened disposable-copy Content negative test passed (unknown path,
same-prefix sibling, excess symbol and extra dynamic import). The ordinary
Content layout npm gate now includes it. Final format, lint, typecheck and
integration suite passed (179/179), as did the generated-output and exact
toolchain gates. Boundary: zero violations, no stale/expired exceptions,
71/71 existing budget. Normal Git `diff --check` passed.

Two clean generated builds produced the same logical digest:
`0f4ffbc7538762d280dc1d5672cd57eb543b66ada3edfd6e9a720edd1c214c2a`.
The A2 export/import/reset/seed normalized-state digest was
`8c3c6c50d887ddadc5634c89500e7e0a8757445e7681974cb4d553b995e9c783`.

### Local commits

All 185 changed/new files were reviewed as belonging to this local work, with
no generated/build/cache outputs or unrelated canonical WIP included:

| Commit | Scope |
|---|---|
| `fc3ab4f8f4508cafb4be97923cddf96753e63a69` | 108 backend, API-contract and stand-ignore files |
| `d1ad5acbc879cf3359bd57a9c93398c907aa6e22` | 69 mobile runtime, fixture and test files |
| Documentation commit containing this review | 8 specification/status/report files |

Branch: `codex/recharge-integration`; parent before closure: `42f8850`.
The final read-only Desktop merge probe retained the same seven conflicting
files and 20 regions after the source commits and status amendments.
Desktop `be17822` and its untracked `.claude/skills/` remain unchanged.
B1-device is open and none of these PC/Emulator results grants cloud, push,
merge or production authority.

### Process closure evidence

The successful stand stops retain the original PID, parent, start time and
executable in `process-stop-audit.jsonl`; the rows below list checked stop
candidates, including a process that may have exited before its stop action.
PID alone is never the identity. A read-only full-suite tree observation is
separate from the stand stop audit; after the suite, all 15 observed identities
were gone and the eight checked loopback Emulator ports had no listeners.
No foreign-process ownership check was weakened.

Local review copies, outside Git:
[verified stand stop identities](C:/Users/User/.codex/visualizations/2026/10/07/01a117e9-e4e4-72a3-b0dd-3729b697b2ec/C1-E2-closure/process-stop-audit.jsonl)
and [full-suite process observation](C:/Users/User/.codex/visualizations/2026/10/07/01a117e9-e4e4-72a3-b0dd-3729b697b2ec/C1-E2-closure/full-emulator-process-observations.jsonl).
Command lines and credentials are omitted.

| Stop completed, 2026-10-08 UTC | Checked PID candidates |
|---|---|
| 07:45:56 | 34360, 15028 |
| 07:49:44 | 3020, 4384, 19492, 3928, 21788, 26520, 33644 |
| 07:56:52 | 29488, 29204, 15276, 24088, 23732, 19600, 13936, 32696, 35376, 6976, 33096, 28932, 5372, 18512, 25260, 35712, 25760, 9392, 9712, 25492, 10220, 22244, 6912, 14396, 30624, 22460, 33288, 14320, 14088 |
| 08:02:31 | 7864, 33940, 27828, 31936, 14412, 36204, 12392, 22608, 32104, 21408, 14196, 17172, 23132, 18816, 34372, 26356, 36892, 37468 |
| 08:08:22 | 35800, 30692, 16300, 29120, 20252, 22168, 36896, 31652, 17440, 32780, 10972, 26236, 32224 |
| 08:10:00 | 6172, 18312, 1400, 20932, 29724, 19124, 14808, 33644, 28332, 37848, 32720, 29684, 14396 |
| 08:14:19 | 19420, 15656, 2316, 17444, 24228, 23900, 6272, 29496, 19516, 13892, 24936, 4784, 30216, 12756, 31940, 23236, 28068 |
| 08:19:47 | 31212, 10884, 16496, 19324, 628, 28968, 16748, 29388, 37804, 31416, 21536, 13052, 33420 |
| 08:22:02 | 3052, 8988, 30168, 12020, 7400, 23952, 27348, 12660, 19968, 6456, 2912, 32228, 6800, 20236, 11768 |
| 08:24:42 | 35040, 35760, 29104, 21188, 15128, 22920, 16192, 25248, 21468, 33764, 18056, 18680, 29724, 2756, 14084 |
| 08:29:01 | 36040, 20156, 32932, 29868, 12308, 20288, 15028, 23492, 34172, 12184, 27224, 36284, 22364, 11932 |
| 08:33:14 | 8676, 18348, 1520, 22136, 22224, 34872, 1228, 13504, 18612, 16588, 9936, 31448, 20004, 21528 |
| 08:37:33 | 6456, 13440, 36956, 19340, 32888, 8316, 7180, 10772, 28620, 35352, 37616, 18248, 32808, 28928 |
| 08:39:17 | 14764, 27272, 2316, 35924, 17112, 28824, 25908, 31536, 22524, 27816, 16192, 12764, 17372 |
| 08:40:28 | 6804, 24944, 35472, 37376, 8888, 18520, 29216 |
| 08:42:19 | 25220, 8532, 20704, 20196, 18264, 4468, 10568, 35152, 35140, 12736, 16668, 6480, 23724 |

The separate full-suite runner had PID 11420; observed descendants were
14384, 25160, 36324, 25188, 29848, 14480, 3700, 16528, 14964, 18444, 26828,
5132, 10204 and 34256. This is an observation of that run, not a reusable stop
allowlist or permission for a later PID reuse.

## Visible security-test reconciliation (owner-authorized 2026-10-07)

Files: `apps/backend/functions/test/integration/content_publication_security.test.ts`
and `apps/backend/functions/test/integration/media_security.test.ts`.

Before: blanket no-consumer/no-Content-export/no-Media-export checks and
fake-only Media infrastructure rejected the already implemented C1–E2 scope.
After:

- Content checks exactly 13 reviewed consumer paths plus approved imported
  symbols; the separate persistence gate keeps its stricter nine-consumer
  path/symbol rules. Unknown consumers and extra repository symbols are denied.
- Content SDK imports remain restricted to exactly four Emulator files;
  domain/application remain framework-neutral. The handoff adapter alone may
  import the two exact Booking collection constants; other Booking imports
  remain forbidden. Runtime Content exports are exactly three named endpoints.
- Media SDK imports are restricted to its two named Emulator adapters; only
  those and the Storage Emulator adapter may use `process.env`. Read URL,
  signer, delivery and network/process APIs remain forbidden even there.
- Media runtime consumers are exactly Content entry and Media entry; runtime
  exports are exactly `mediaCommandV1`, `mediaQueryV1`, `uploadMediaBytesV1`.
  The eight-file infrastructure inventory is exact; fake adapters retain their
  FAKE labels and fake scanner/processor are not real safety evidence.
- Negative controls reject unknown path/SDK imports, unauthorized symbols and
  a read-URL API even in an approved Media adapter. Tests are not skipped or
  reclassified as passes; the full integration suite now passes.

The original test titles remain for existing acceptance-matrix traceability;
this section records the accepted later-slice semantics. No runtime source was
changed by this security-test reconciliation.
