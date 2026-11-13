# I2 после I1 — общая локальная проверка

Date: 2026-10-20. Status: Done — bounded local/Emulator revalidation; accepted I2 scope preserved.
Baseline: integration 9881c48deb4569b3096b14d4d9ed194e498cdd9e + accepted I1 invited
viewer implementation, preserved unchanged in the same isolated worktree:
C:/Users/User/Documents/Codex/2026-10-20/new-chat-2/work/recharge-i1.
No commit, push, merge/consolidation, CI activation, deployment or production access.

## Принятые границы и единый writer

I2 local/Emulator scope already accepted on 2026-10-19. Task 27 explicitly authorizes
revalidation and fixes after I1. I1 viewer-only contract grants read/Leave, no copy.
The existing FirestoreScenarioService and its one `saveInTransaction` call site remain
byte-for-byte unchanged from HEAD. Ordinary save and Expand still invoke that writer;
its spy test proves both paths and transaction rollback before the receipt. The existing
PlanningConversionFacade -> QuickPlanConversionCoordinator ->
ExpandQuickPlanToScenarioUseCase converter is reused; no second converter/store.

| Actor relation | Expand into a NEW owned Scenario |
|---|---|
| Quick Plan owner; owner/editor/viewer in a separate Scenario | Allowed; Scenario role does not restrict own-source personal creation |
| Owner/editor/viewer of a Scenario, but I1 invited viewer of the source Quick Plan | Denied, even though invited read succeeds |
| Quick Plan pending/revoked invitee or stranger | Denied |
| Existing Scenario target | Cannot be overwritten by Expand |

Roles are per resource. Scenario membership grants no Quick Plan copy access. Expand
checks owner source authority transactionally, source revision and canonical hash,
immutable intent/receipt binding, new ULID and fresh mutable children. One intent,
lost reply and restart return one target; a new explicit intent creates a different
Scenario. Compact receipt replay cannot create when its durable server receipt is
missing. Source changes produce a new-intent revision conflict, not silent refresh.
Historical acknowledged replay preserves the original result while source authority
is valid; deleting source refuses further Expand replay without deleting its independent
target. Provenance is an inert private snapshot, not a live relationship.
No Route fields, implicit publication or Content/Catalog effects; explicit I3 publication
is separate and its pre-existing scope is unchanged.

## Найденные и исправленные гонки клиента

Three deterministic regression tests were red before the fix:

1. Revoke during read's secure journal write could let the already received result
   return to its caller after revoke had been observed.
2. The same gap existed while persisting a successful shared save response.
3. Expand waiting behind another request could materialize old-account input under
   a changed actor.

ScenarioSyncClient now checks revoke/visibility epochs after journal writes as well as
after HTTP. Serialized operations capture the initiating actor/visibility epoch; IO,
materialization and save boundaries recheck actor before persisting/dispatching.
All three new cases and eight existing sync cases pass. No server writer changes.
Durable pending/conflict/receipt retention and existing capacity limits remain.

## Серверный revoke и offline-ограничение

Server authorization reads current session, Scenario, membership and generation in the
transaction. After revoke commit, operations serialized later cannot read/edit/replay
or use old queued authority. Role downgrade/re-invite advance generation; an old
successful save/accept receipt never reactivates membership or authorizes a stale queue.
Revoke racing requests is tested both by transaction races and real Flutter HTTP.

On receiving an authoritative revoke through `receiveRevoke`, the local client
synchronously hides shared cache/conflicts. Late HTTP and late journal completions
cannot republish it. Re-fetch after a new grant validates the new generation online.
The test deliberately holds a real authorized Emulator response, commits revoke,
notifies the client, then delivers that old response: it is rejected and cache stays
hidden. Native notification delivery/push subscription is not introduced here.

An operation authorized before revoke may deliver later. The server stops subsequent
access immediately at the commit ordering boundary; it cannot erase already delivered
offline data, screenshots, exports or physical storage remnants. A disconnected client
cannot promise instantaneous notification or remote erasure. Cache API closure after
receiving revoke is a separate guarantee from erasing existing offline copies.

## Collaboration и edit/delete

Owner/editor/viewer, pending/wrong-recipient/stranger, active sessions, invitations,
accept/cancel/revoke, membership revision CAS, role downgrade, expired invites and
new-generation re-invite are checked against Emulator. Real Flutter adapters exercise
owner/editor edits in both delivery orders, durable conflict recovery, a re-invited
viewer denied save, old save replay after re-invite and revoke during an in-flight read.

Scenario edit/delete retains accepted Scenario revision CAS, independently of I1
Quick Plan delete-wins: an edit winning first conflicts a stale owner delete; a fresh
owner delete then succeeds. Delete winning first denies the edit. Terminal deleted
Scenario cannot be resurrected by edit or replay. Tests cover both orders, concurrent
server transactions and actual owner/editor Flutter adapters.

## Current gates

| Gate | Result |
|---|---|
| Initial common I1/I2 Emulator | 15/15, outer exit 0 |
| New regression tests before fix | 3 failed, retained as red evidence |
| New + existing Scenario sync focused unit tests | 11 passed, exit 0 |
| Extended focused I2 Emulator | 17/17, no fail/skip, outer exit 0 |
| I2 in full common Emulator | 17/17, no fail/skip; full suite passed |
| Full common Emulator, one session | 18/18 groups; 348 passed, 0 skipped; complete true, outer exit 0 |
| Full Flutter analyze | No issues, exit 0 |
| Full Flutter test after common Emulator | 1709 passed, 74 environment-gated skips; exit 0 |
| Backend compile/typecheck / affected ESLint | Passed |
| Backend unit + contract | 815 passed, no fail/skip |
| Backend integration | 257 passed, no fail/skip |
| Execution manifest / runner self-tests | Passed / 7 passed |
| Boundary | 0 violations, 71 existing suppressions |
| Diff / unchanged common runtime fingerprint | Passed / all 14 changed source/test files unchanged; I1 runtime and server writer unchanged |

Toolchain: exact Node 22.23.2, Temurin 21.0.12+8, Flutter C:/src/flutter. SDK/Functions
Emulator work is local-only. Environment-gated Flutter stand cases are run explicitly
by the relevant Emulator groups; ordinary full Flutter skips are reported separately.
Source/test fingerprint is recorded before full Emulator and checked after all gates.
The original I1 runtime files are checked against the prior deliverable manifest.

The two actual host Flutter callable adapters use real Auth/Functions/Firestore
Emulator transport. Host secure-storage test backing and client reconstruction over
preserved serialized journal prove adapter recovery; they are not two native installed
apps or native process-death/device evidence. No physical-device, staging or production
readiness claim is made.

## Changed files and reproduction

Runtime: only existing mobile ScenarioSyncClient. Backend Scenario writer unchanged.
Tests: existing scenario_i2 Emulator/real-adapter tests plus one new persist-race test.
Docs: I2 spec/history/current evidence and one bounded LAUNCH_STATUS row update.
I1 runtime, canonical creation/conversion, aggregates, schema limits and flags preserved.

From apps/backend/functions, exact toolchain/loopback context:
`node ../scripts/run-emulator-tests.mjs --group scenario-i2` (focused) or
`node ../scripts/run-emulator-tests.mjs` (all groups, one session).
Set RECHARGE_DART, RECHARGE_FLUTTER_TOOL, FLUTTER_ROOT and RECHARGE_G_MOBILE=1
as documented in I1/I2 specs. Then run full Flutter analyze/test from apps/mobile,
backend gates and boundary/diff. Serialize heavyweight Flutter and Emulator suites.
Rollback uses existing default-off composition; preserve journals, receipts,
terminal invite states and membership generations. Offline cache cannot be remotely
recalled on rollback either.

Final summary: `C:\Users\User\AppData\Local\Temp\recharge-emulator-tests-OZAdLj/summary.json`, complete=true/code=0.
The full suite was followed serially by full Flutter tests; no source/test edits
occurred between the recorded fingerprint and final verification.
