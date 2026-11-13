# D4 — safe local → server import (Emulator only): evidence

Date 2026-10-13. Status **Review**; Windows-local Emulator evidence; not Done, not
committed, no push or merge. Normative text:
[LOCAL_IMPORT_D4_AMENDMENT.md](../../../product/LOCAL_IMPORT_D4_AMENDMENT.md).

## Checked state

Worktree `C:/Users/User/.claude/worktrees/recharge-d4`, branch
`claude/d4-local-import`, base `e50f9a6` (D3.4, local commit). Source fingerprint
**`e50f9a6+wt:e0687ee4acca`**: every path that differs from HEAD plus untracked
files, as `path TAB SHA-256 (content without CR)`, sorted; first 12 hex of
SHA-256 of that list. Excluded: the amendment, `LAUNCH_STATUS.md` and this file
(written after the run). 36 files; identical before the D4 gate and after the
last check.

The backend checks and `test:emulator` ran on an earlier state of the same
worktree whose backend files (code, tests, scripts) are byte-identical to the
fingerprinted ones; only mobile files changed after them (the Media replay fix
below). `format:check`, `lint` and `verify:r1:layout` were repeated on the final
source.

Toolchain: Node 22.23.2 / npm 10.9.8 (portable), Temurin 21.0.12+8, Flutter from
`C:/src/flutter`. Backend `node_modules` copied from another worktree with the
same `package-lock.json` (no download). Mobile dependencies from the local pub
cache; no lockfile changed.

## Results

| Check | Result |
|---|---|
| `git diff --check` (with untracked files) | clean |
| boundary (`check_boundaries.dart`) | 0 violations, 71/71 suppressions, 608 Dart files |
| build, typecheck, lint, `format:check` | pass |
| unit / contract / integration (`lib/test/{unit,contract,integration}`) | 720/720 / 55/55 / 236/236 |
| stand tests / Emulator runner tests | 42/42 / 6/6 |
| `verify-*`: r1 layout/config/exports, content-persistence, reference-data, security-privacy, identity-publisher, generated, taxonomy, execution-manifest, cloud-context | pass |
| `test:emulator` (7 groups, sequential) | 228/228, exit 0; `content-media` 197 s, `collection` 189 s (limit 390 s) |
| gate D4 (`stand-d4-gate.mjs --yes`) | pass: lost `createDraft` answer → `paused` → restart resumes into the same server draft; another install directory (receipts lost) → same contentId/draftId, verified; repeat → `nothing_to_import`; original removal refused before confirmation and before the period, removed after +31 days, server copy kept; controller on the stand 2/2; base and Place invariants; verified stop |
| gate C1 (Media upload; shared gateway changed) | pass 4/4, verified stop |
| gate C3 | pass: Event seed/digest cycle, controller 3/3, UI 1/1, verified stop |
| gate D3.1 (real Place photo upload and delivery, D1 tools L1) | pass: controller 4/4, UI 1/1, invariants, verified stop |
| `flutter analyze` / `flutter test` | 0 issues / 1543 passed, 39 skipped, 0 failed |

Flutter skips: 37 at the base `e50f9a6` plus 2 new in
`local_import_stand_test.dart`. Every skip is a `backend_local` stand test that
runs only against the stand; the 2 new ones ran and passed in the D4 gate. The
shared stand was stopped with verification after every gate and is stopped now.
`api_contracts` is unchanged by D4 and was not rerun (25/25 at D3.4).

## Found and fixed during the pass

- **Media replay after lost receipts (G1).** The first D4 gate run failed: on a
  second install (receipts lost) the import repeated the same upload intent;
  Media replayed the earlier, already completed, upload session and refused the
  byte transfer with `session_expired`, so the receipt went to `failed`. The
  server draft deduplication itself held (same contentId/draftId). The shared
  `FunctionsMediaUploadGateway` now asks `getAssetStatus` when a replayed
  transfer is refused with `session_expired`/`invalid_state`: if the server
  already accepted exactly these bytes (SHA-256 and length) for the same Content
  entity, a `ready` asset is returned without a second transfer, and an accepted
  but unfinished one is finished through the same `:confirm`/`:finalize` keys;
  otherwise the refusal stands. The normal upload path is unchanged (no status
  query); unit `media_upload_gateway_replay_test.dart` 4/4, gates C1 and D3.1
  pass.
- A previous stand had died with an earlier session and left a stale stand
  state and the Firebase hub locator of its dead CLI process (no process alive,
  ports free). The stand was reset through `emulator-stand.mjs reset --yes`; the
  locator file was moved to the review folder, not deleted.

## Follow-up: expired upload session (after the D4 commit)

Found by review after `3d77018`, not by a test: an upload interrupted between
`createUploadSession` and the accepted bytes, retried after the session TTL
(900 s on the stand), replayed the same intent forever and kept the item at
`failed: session_expired`. The controller now moves such a medium to the next
upload attempt (a new UUIDv5 intent; attempt 0 is the earlier one), saves the
attempt in the receipt (`uploadAttempts`) before using it, spends at most 4
attempts per medium in one run and goes on from the saved attempt in the next
one. With lost receipts the walk starts at 0 again and an attempt that worked
returns the same asset. No duplicate draft or asset, the local original stays.

Checked state `3d77018+wt:585dab2a6852` (5 files, same rule; identical before
the gate and after the last check):

| Check | Result |
|---|---|
| D4 unit tests (controller, hash/journal, store/guard, Media replay) | 28/28; 2 new controller tests (new intent saved before use; per-run bound, restart and lost receipts without a dead intent) |
| gate D4 (`stand-d4-gate.mjs --yes`) | pass: stand test 2/2, invariants, verified stop |
| `flutter analyze` / `flutter test` | 0 issues / 1545 passed, 39 skipped (all `backend_local`), 0 failed |
| `git diff --check` | clean |

The first gate attempt on this state stopped at the base seed: the Functions
worker needed 26 s to load while a new worktree was being checked out on the
same disk, and the seed request has no timeout. That run was stopped and the
stand stopped with verification; the repeated gate passed on an idle disk.
The expiry itself is not reproduced on the stand (it needs 15 minutes); the
unit tests drive it through the uploader port.

## Not covered

Scenario/Route library import (listed only; BCK-10/BCK-11), favorites, visits
and other data families, OD-08 identity mapping, a server-side record of the
recovery period (device clock only), drafts already sent by a D3.x test path
whose journal was lost (imported as a separate draft), physical devices, Linux,
cloud and production. D2 residual windows W1–W6 and F2a apply to imported media
as to Place.
