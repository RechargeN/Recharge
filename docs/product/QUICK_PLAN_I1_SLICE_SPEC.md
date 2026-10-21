# Quick Plan I1 — owner persistence, sync and import

Date: 2026-10-16. Scope authorized by the I1 task; Emulator-local only.
Verification updated: 2026-10-17.
Status: Review — owner scope retained; accepted invited viewer extension implemented in bounded local/Emulator scope. DEF-05 approval/CI/publication and production gates remain open. BCK-10 remains Draft.

## Boundary and implementation

Extend the existing `features/scenarios` Quick Plan `ScenarioDraftEntity`, not
the canonical Scenario aggregate. Reuse session authority, callable transport,
Firestore transactions, secure storage and the existing Emulator group runner.
No Catalog writer, PublisherRef, Scenario creation or Expand changes.
Invited viewer authority is authorized by the owner on 2026-10-20 as specified below. Unlisted access remains fail closed.
Client owner fields are assertions checked against verified session identity.

## Identity and conflicts

Client-generated permanent UUID plan/stop IDs survive save/restart/import.
Server revisions are monotonic per plan; local editing revisions are distinct.
Commands carry UUID request/idempotency IDs, ownerContext, planId,
expectedRevision and schemaVersion=1. Receipts bind owner + key to canonical
command hash; retries return the recorded result, changed payload rejects.
No receipt/tombstone expiry in I1: old commands cannot regain create authority.

Edit/edit uses compare-and-set: first committed edit wins in either delivery
order, the other returns revision_conflict. Its full payload remains in durable
owner conflict storage; no automatic rebase, replacement or hidden merge.
Delete wins over concurrent edit: stale delete of an existing plan is accepted,
revision advances, payload is erased and a terminal tombstone remains. An edit
arriving after delete rejects deleted. A delete of a missing ID creates a
tombstone too. A replay of an older successful edit may return its historical
receipt but never changes current state. Explicit new ID is required for a copy.

## Durable client state

One encrypted secure-storage document per owner and installation contains cache,
pending commands and conflict payloads. Persist before dispatch. Serial writes
avoid interleaving; failed writes prevent dispatch. Pending contains immutable
request IDs/payloads; network, unknown response and unauthenticated outcomes keep
it unchanged. Refresh retries without another edit after authenticating owner.
Restart reloads the same journal. Logout clears visible memory, not the journal;
another owner reads a different key and never sends the previous owner's queue.
Account changes invalidate in-flight results before publishing or another send.
Server ownerContext check closes token/account races. No local claim grants read.
Terminal rejection moves payload to conflict storage atomically with queue removal.

## Import

Explicit single-plan JSON: `{format:"recharge.quickPlan",schemaVersion:1,plan}`.
Plan is the same bounded draft DTO as save, with UUID plan/stop IDs, integer
minor-unit Money, no owner/grants/publisher fields. Unknown versions/fields,
invalid values, duplicate stop IDs and oversized input fail before enqueue.
Import is create-only via the same owner command transaction, revision zero.
Stable import key derives from canonical source content; retries after interruption
reuse that key. Existing ID returns id_collision, never overwrites. Tombstone
rejects even with a different import key. Changed content with the same ID is a
collision. No bulk partial commits or automatic local upload.

## Required evidence and rollback

Both edit delivery orders; edit/delete both orders; duplicate/lost-response
commands; import malformed/version/collision/interruption/replay; offline and
restart/refresh; expired session and logout/same/different owner; private query
and response allowlist; independent Flutter adapters against real Emulator.
Register I1 in the full single-session Emulator suite; cleanup own fixtures and
verify runner self-tests, backend gates, full Flutter analyze/test, boundary and
diff. Incomplete execution is not green.
Rollback disables the default-off quick_plan.owner_sync flag and mobile test
entry; retain journals, receipts and tombstones. Production activation, wider invited/editor/unlisted
authority, retention/DSR integration and user conflict-resolution UI are outside
this local slice and must be reported as limitations.

## Implementation and verification record (historical source worktree)

Base: `a1fcde5cb53fa99fe034611cbfdc1063e7b96ae8`, branch
`codex/i1-quick-plan`; no commit/push/deploy authorized or performed.

- Backend: `modules/quick_plan/{quick_plan_contract,firestore_quick_plan_service}.ts`
  and the existing index expose only `quickPlanCommandV1`/`quickPlanQueryV1`.
- Mobile: the existing entity is serialized by `quick_plan_codec.dart`; the
  data client implements one domain repository port. Existing controller/page
  support save, refresh, owner-clear and restoration by route ID when injected.
- The default repository provider remains null. A test composition must inject
  a repository tied to its actual session owner and installation; the compile
  flag alone does not activate application persistence. There is no production
  Auth migration or owner-wide library/list endpoint in I1.
- The default-off `RECHARGE_TEST_QUICK_PLAN=true` composition checks non-release,
  loopback demo-recharge binding and its callable allowlist on every invocation.
- Emulator runner uses its own Node directory for Functions subprocesses;
  this avoids accidentally discovering Functions with the system Node 20.

Reproduction (working directory: `apps/backend/functions`): Node 22.23.2,
`RECHARGE_DART=C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe`,
`RECHARGE_FLUTTER_TOOL=C:\src\flutter\bin\cache\flutter_tools.snapshot`,
then `npm run test:emulator` (all 14 groups in one session), or
`--group quick-plan` for the focused group. Both Flutter executable paths are
required; the I1 mobile probe fails rather than silently skipping them.
For Flutter analyze/test use `apps/mobile` and `FLUTTER_ROOT=C:\src\flutter`
so existing golden tests load their pinned fonts.

Evidence so far:

| Check | Result |
|---|---|
| Runner self-tests | 6 passed |
| Focused I1 Emulator | final serial repeat 5 passed, including independent real Flutter callable adapters; exit 0 |
| I1 fixture cleanup | plans/receipts empty; own Auth users deleted; Identity/flags cleared |
| Catalog/Content/Scenario writes | before/after digest unchanged in I1 Emulator test |
| Focused Flutter queue/recovery + Expand | 11 passed |
| Full Flutter analyze | no issues |
| Full Flutter test | final run 1652 passed, 69 environment-gated skipped; all tests completed |
| Native Android journal restart | both phases passed on read-only API 36 AVD, real secure-storage plugin, force-stop between app launches, fixture keys deleted |
| Backend typecheck / affected lint / exports | passed |
| Backend unit + contract | 789 passed, 1 failed: existing execution-manifest/index inventory mismatch |
| Full single-session Emulator | all 13 groups passed; outer runner exit 0; final I1 repeat also passed |
| Boundary / diff | 0 violations, 71 existing suppressions; diff check passed |

Closing verification on 2026-10-17 repeated full analyze (no issues) and the
full Flutter suite after the final Save-busy guard: 1652 passed, 69 skipped,
exit 0. Final serial I1 Emulator repeat: 5/5, exit 0, cleanup verified.
Raw local evidence is retained in `apps/mobile/i1-{analyze,flutter}-closed.log`,
`apps/mobile/i1-native-phase{1,2}.log`, `apps/mobile/i1-native-restart.log`,
`apps/backend/i1-emulator-{full,final}.log` and
`apps/backend/i1-backend-final.log` (ignored runtime logs, not committed files).

The manifest, indexes and manifest validator are unchanged against the base;
the failing inventory names Library/moderation/safety collections and old
Booking/Content index differences. It is a retained blocking gate, not green.
Update 2026-10-17: superseded on base `bde8b79` (baseline gates fixed); I1 now adds
explicit Rules deny and manifest entries for `quickPlans` and
`quickPlanCommandReceipts` and exact Content-dependent entries. Rebase check:
[I1_REBASE_CHECK_2026_10_17.md](../verification/I1_REBASE_CHECK_2026_10_17.md).
The first Flutter run lacked FLUTTER_ROOT (1640 passed, 69 skipped, eight
font/golden failures); the corrected run passed without updating golden assets.
An additional I1 repeat during Android compilation failed to cold-load the
Session function (`deadline-exceeded`); it was not green. The final serial
repeat after native testing passed all five I1 tests and its cleanup assertions.

Host Flutter tests recreate data clients over preserved VM storage and use
actual Auth/Functions/Firestore Emulator transport. In addition,
`integration_test/quick_plan_native_journal_test.dart` passed both native
Android phases with the real secure-storage plugin: queue offline, retain the
installation, force-stop, relaunch, restore pending, isolate another owner,
return to the same owner and delete the fixture keys. The read-only AVD and
its helper processes were stopped after verification; the source AVD was not
modified. This is Android AVD evidence, not physical-device or iOS evidence.

Native reproduction: run that integration test on a disposable Android device
with `--no-uninstall --dart-define=RECHARGE_I1_NATIVE_PHASE=1`, force-stop
`com.recharge.app.recharge`, then run with
`--no-uninstall --dart-define=RECHARGE_I1_NATIVE_PHASE=2`. Flutter's default
post-test uninstall erased the first experimental fixture, so that failed
attempt was not durability evidence. Both corrected phases completed with exit 0.
The existing NDK 27/28 warning did not prevent either build; build config and
goldens were left unchanged.

Physical devices/iOS, production auth/session lifecycle, invited grants, bulk
import, conflict-resolution UI and receipt/tombstone retention/DSR remain
separate gates. Historical success receipts retain their original response;
replay never mutates current state and the client queries current state before
publishing a receipt result, so a deleted plan stays deleted.

## Общая приёмка 21–26 (2026-10-17)

Предыдущие implementation/rebase records выше — история отдельных прогонов.
Текущая общая ревизия `9db93bb`, [acceptance](../verification/LOCAL_21_26_ACCEPTANCE_2026_10_17.md).
I1 включён вместе с K3; default-off и owner-only boundaries сохранены.


## I1 invited viewer extension — owner accepted 2026-10-20

Owner approval: user accepted the concrete I1_INVITED_CONTRACT_PROPOSAL.md with
«выполняй». This accepts only this bounded local/Emulator extension and its file
plan; BCK-10 remains Draft overall. No commit/push/deploy/production activation.
Baseline: clean integration 9881c48, isolated worktree work/recharge-i1.

### Authority and lifecycle

Owner retains edit/import/delete/Expand/invite/cancel/revoke. Invited viewer can
read and Leave; no shared mutation, import, delete, Expand or onward invitation.
Independent personal create-only import remains permitted without grant copying.
Known authenticated user IDs only; no identity search, external messages, links,
unlisted access, new aggregate, parallel plan store, publisher or Catalog writer.
Invitation metadata belongs to the existing quickPlans record, max 32 distinct
invitees per plan; same command/query endpoints and encrypted actor journal.

pending -> accepted/declined/cancelled; accepted -> revoked/left. Owner performs
invite/cancel/revoke; only target performs accept/decline/leave. Duplicate delivery
is idempotent. Re-invite after a terminal state requires a new invitation ID and
increments generation; old generations never gain authority. Invite intents also
bind the previous status observed by the owner so a queued active duplicate cannot
become a new grant after revoke. Concurrent transitions are transactional.

Every invited read and access receipt replay checks the active plan, active owner
account, authenticated actor/session and current invitation ID/generation/status
in the transaction. Only the same terminal leave/revoke/cancel/decline may return
safe acknowledgement; no plan payload in invitation receipts. Old owner personal
receipts preserve historical semantics; they cannot modify current state. Existing
owner CAS, create-only import, durable conflicts and terminal delete-wins remain.
Deleted/inactive owner accounts close remote reads and replay; no ownership transfer
or new retention/DSR completion claim.

### Projection and offline behavior

Before accept, invitation query returns IDs/status/generation only, no title or
content. Owner can see its invitations, invitee sees own invitation and owner only,
not a participant roster. Invited content is online-only and volatile: never in
persistent cache, pending payload or conflict journal. The read-only page clears
content before revalidation, every 5 seconds while foreground/current, and on
background/account changes; late results after clearing are discarded. Revocation
closes server access immediately at transaction ordering, but cannot recall already
returned/copied content or guarantee instantaneous client notification. Offline or
failed revalidation hides content; no offline invited-content browsing.

Accept/decline/Leave and owner access intents use the existing journal, actor,
installation, immutable request/key, invitation ID and generation. Pending action
is not a new permission or a confirmed revoke. Persist-before-dispatch, lost response,
restart and user isolation apply; a terminal rejection moves metadata-only request
to durable conflicts and removes it from pending. A changed user never drains the
previous actor queue. Refresh retries pending without another user action.

### Existing flow and rollback

Existing Quick Plan page has Invitations and access, accept/decline/cancel/revoke/
re-invite/Leave, online read-only open, personal import/delete and refresh/retry.
Existing controller/repository/sync client implement operations; production provider
remains explicitly injected/default-off. Disable quick_plan.owner_sync or injection
to roll back. Preserve receipts, invitation generations, tombstones and journals.

### Verification required before Done

Two real Flutter callable adapters against Auth/Functions/Firestore Emulator,
owner and invitee identities/installations, plus same-owner second adapter for CAS.
Verify pre/post accept; denied mutations/import/delete/Expand; cancel/accept and
delete/accept races; revoke/query/replay and re-invite; old duplicate invite;
offline queue, lost response, restart and account switch; personal regressions,
Catalog/Content/Scenario digest invariant, cleanup, Flutter analyze/full tests,
backend affected/unit/contract gates, boundary/diff. Incomplete runs are not green.
Evidence and current outcome are recorded in the extension verification document.
