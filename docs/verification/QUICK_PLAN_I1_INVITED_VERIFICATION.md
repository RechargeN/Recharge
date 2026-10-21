# I1 invited viewer — local verification

Date: 2026-10-20. Status: Review — agreed local implementation and required gates verified.
Base: 9881c48deb4569b3096b14d4d9ed194e498cdd9e (clean integration at start).
Worktree: C:/Users/User/Documents/Codex/2026-10-20/new-chat-2/work/recharge-i1
No commit, push, merge, deployment, production activation or cloud processing.

## Contract and changes

Owner accepted the concrete viewer-only proposal with «выполняй» on 2026-10-20.
Owning contract: QUICK_PLAN_I1_SLICE_SPEC.md, I1 invited viewer extension;
BCK-10 §34 is a bounded amendment, not acceptance of all BCK-10.

Same Quick Plan aggregate, plans/receipts collections and command/query endpoints.
Invitation metadata on existing plans; owner payload CAS preserves metadata during
concurrent updates. Auth/session, owner-account state and invitation ID/generation/
status are rechecked transactionally before grant operations and receipt replay.
Re-invite uses a new invitation ID and generation. Invite intent pins the previous
status, preventing an old active duplicate from turning into a re-invite after revoke.
Only owner edits/imports/deletes/Expands/manages grants. Invited user reads online
and Leaves. Independent personal import does not copy sharing authority.

Mobile extends the existing repository, sync client, controller and Quick Plan page.
Access intents share the actor/installation encrypted journal, persist before send,
and replay immutable request/key after restart or lost response. Terminal rejection
removes pending and retains a durable metadata conflict. Changed users cannot drain
the previous user's journal; in-flight content is discarded on actor/visibility epoch
change. Invited content never enters persistent cache/pending/conflict payloads.
Read-only refresh also drains queued accept/Leave intents before reading.

Invited page hides content before revalidation, after failed validation, on background
and on exit. While current/foreground it revalidates every five seconds. Revoke fences
server access by transaction ordering; this is not instantaneous push revocation or
remote erasure of already delivered/copied data. No offline invited-content browser.

## Evidence

Toolchain verified live: Node v22.23.2; Temurin 21.0.12+8 (system Java is a different
patch, so the exact local JDK is selected explicitly); Flutter C:/src/flutter.

| Gate | Result |
|---|---|
| Flutter analyze, full | No issues, exit 0 |
| Flutter test, full | 1706 passed, 74 explicit environment-gated skips, exit 0 |
| Flutter focused UI/queue/recovery | 23 passed, exit 0; full suite includes final code |
| Backend TypeScript compile/typecheck | Passed, exit 0 |
| Backend affected ESLint | Passed, exit 0 |
| Backend unit + contract | 815 passed, 0 failed/skipped, exit 0 |
| Backend integration | 257 passed, 0 failed/skipped, exit 0 |
| Execution manifest | Passed: 77 collections, 16 flags |
| Emulator runner self-tests | 7 passed, exit 0 |
| Boundary | 0 violations; 71 existing suppressions; exit 0 |
| Diff whitespace | Passed |
| I1 focused Emulator | Final repeat 7/7, 0 failed/skipped, outer exit 0 |

The full Flutter default run skips stand-only backend tests explicitly. I1's real
callable test is executed separately by the I1 Emulator group, with its required
compile flag and live Auth/Functions/Firestore Emulator transport.

Two independent Flutter callable adapters represent the owner and invitee identities,
with a second owner installation for CAS. They test invite/pre-accept denial, accept,
viewer mutation/import/delete denial, owner updates, revoke/re-invite, stale accept
receipts, offline queue, lost accept response followed by revoke, serialized journal
restore, user switch, offline Leave, cancel and decline, delete, and absent invited
payload in secure journal. Backend cases add concurrent cancel/accept and delete/
accept ordering, inactive owner account, terminal deletion and stale duplicate invite.
UI/unit cases prove read-only controls and failed-validation/late-response clearing.
Catalog/Content/Scenario before/after digest is unchanged; fixtures are cleaned.

Evidence uses host Flutter adapters with the real Emulator transport and host secure
storage test backing. Restart means client reconstruction over the preserved serialized
journal. This run does not claim two installed Android/iOS apps, native process-death
verification, physical devices or production auth/network evidence. Prior owner-only
native evidence is historical and not relabelled as invited-device evidence.

## Runs and retained logs

Initial Emulator run: 6 passed / 1 failed while the mobile invitation wire contract
and compiled backend were out of sync during development (request_invalid). Not green.
Second synchronized run: 7/7, one real Flutter test covering the scenarios above; outer
runner exit 0, cleanup and protected digest verified. Final repeat after adding
pending-intent drain to read-only refresh: 7/7, 0 failed/skipped, outer exit 0;
real Flutter test passed, protected digest and cleanup verified. The final group
ran in 50102 ms, logs recharge-emulator-tests-cmyM4z.

Logs are retained in the parent work directory (i1-emulator-attempt1.log,
i1-emulator-attempt2.log, i1-emulator.log, i1-backend-tests.log,
i1-backend-integration.log, i1-boundary.log) and i1-analyze.log, i1-flutter-full.log, i1-flutter-focused.log.
The final deliverable report includes exact final outcomes and reproduction commands.
Original integration remains clean at 9881c48 after all checks. No consolidation performed.

## Scope and rollback

Existing production provider remains null/default-off and requires explicit local
repository injection. No publication or Catalog path, new aggregate, parallel plan
storage, unlisted links, external invitation messages, editor role or production
activation. Physical retention/DSR cleanup and wider product sharing remain outside
this accepted local slice. Roll back by disabling quick_plan.owner_sync or removing
repository injection; retain invitation generations, receipts, tombstones and journals.

## Changed files

- Backend: existing quick_plan_contract.ts and firestore_quick_plan_service.ts.
- Flutter: existing quick_plan_repository.dart, quick_plan_sync_client.dart,
  scenario_builder_controller.dart, scenario_builder_page.dart.
- Tests: existing Emulator/Flutter client/widget tests and one invited visibility unit test.
- Docs: I1 contract, bounded BCK-10/profile clarification, this evidence and LAUNCH_STATUS.
