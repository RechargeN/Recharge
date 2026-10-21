# D3.7 / T3 — Find People local acceptance, 2026-10-19

Scope: `claude/t3-find-people`, base `0b131ab69e176c23cc69ee65b032b285e35ff179`.
Changes remain uncommitted. This evidence covers local/LV Emulator and PC-host
Flutter only. It does not approve device, cloud, staging, production, Legal or
Privacy readiness. The implementation contract is
[D3.7 amendment](../../../product/D3_7_FIND_PEOPLE_PUBLICATION_AMENDMENT.md).

Status: **Review — bounded local implementation and verification complete**.
Owner acceptance and the explicitly listed external gates remain open.
Final Emulator logs: `C:\Users\User\AppData\Local\Temp\recharge-emulator-tests-7azjnb`.
Its `summary.json` reports `complete=true`, `code=0`; all task exit codes are 0.

## Implemented boundaries

- Author-only private Content source; immutable published revisions contain a
  server-built public allowlist and a deterministic ~1 km cell centre.
- Identity-owned explicit grant/revoke/query with CAS, idempotency receipts and
  transactional session checks; synthetic server-issued 18+ attestation only.
- Fresh public visibility on Catalog Feed/Search/Map/Details, old snapshots and
  cursors, and Content exact-ID reads: consent, host/viewer age, meeting end,
  Content pointer, K2 block/mute and T&S. The author uses the same public gate;
  their private `getDraft` remains available after public refusal.
- Content-owned retention erases exact meeting data and stored create/update
  command answers after the accepted local retention interval.
- Default-off mobile publication section/test route, persistent write journal,
  explicit consent, loss/restart recovery, strict public Catalog/Map adapter.
- No participation, waitlist, accepted-member exact-location disclosure,
  production age authority, production consent UX or public production entry.

## Verification

| Gate | Result |
|---|---|
| Backend unit/integration/contract, final source | PASS: 1075/1075, zero failure/skip |
| Identity, Reference Data, Security/Privacy contract wrappers | PASS via intact pinned npm 10.9.8 / Node 22.23.2 |
| Backend lint, typecheck and format | PASS |
| R1 layout/config/exports, Content/Identity/Reference/Security layouts, execution manifest, generated output | PASS |
| Runner/stand/layout self-tests | PASS: 10/10 |
| D3.7 stand | PASS: clean = interrupted/resumed = repeated digests; real controller/Catalog/Map and real UI test; verified stop and fixture cleanup |
| Flutter analyze | PASS: no issues |
| Full Flutter test | PASS: 1683 passed, 73 explicit environment skips, zero failure |
| Boundary | PASS: zero violations/stale/expired exceptions; existing budget 71/71 |
| git diff --check | PASS |
| Full single-session Emulator | PASS: complete=true, code=0, 16/16 groups, 315 passed, 0 failed/skipped; verified shutdown and ports released |

The dedicated stand runs the two new environment-gated mobile scenarios
explicitly. The full Flutter run's skips are not counted as executed tests.
The stand emitted the existing integration_test PC-host plugin warning; both
explicit tests exited 0. This supplies no Android/iOS instrumentation evidence.
The stand finished before the public-author exception was removed; its exercised
controller/UI paths are unchanged. The final integration and single-session
Emulator tests exercise the corrected public read behavior.

## Interrupted and corrected attempts

The initial resumed stand attempts stopped before tests because JAVA_HOME did
not provide the pinned `21.0.12+8`. They are not successful acceptance evidence.
The available installed JDK is `21.0.12.1+1`; stale temporary extraction folders
had no executable. The successful runtime uses the existing pinned JDK under
`721e/Recharge/apps/backend/.r0-tools/java/jdk-21.0.12+8` read-only and Node
`22.23.2`; no toolchain gate was weakened.

Direct invocation of three contract gate wrappers without npm context stopped
with `requires npm_execpath`; these attempts are not green. Their normal npm
invocations are recorded with the final results. The first temporary Node folder also had an incomplete npm tree (`run-script.js` absent); the intact pinned toolchain under `721e` was used instead, without changing package versions.

Review found and removed an author exception in `getPublishedRevision`, which
contradicted amendment §6. Integration and Emulator tests now also require the
author to fail the public gate after revoke while retaining private draft access.
Layout gates register exact new files/symbols without wildcard permissions.

The first full Emulator attempt (`recharge-emulator-tests-Z5FK2e`) failed the
Quick Plan real-adapter prerequisite because `RECHARGE_DART` and
`RECHARGE_FLUTTER_TOOL` were absent. Its runner process tree was explicitly
stopped and the complete suite restarted with both paths. The failed/aborted
attempt is retained as such and is not counted as successful evidence.

The second attempt (`recharge-emulator-tests-CeM3j3`) passed Quick Plan,
Library, Platform and Booking, but Library's real-mobile test was skipped
without `RECHARGE_G_MOBILE=1`. That attempt was explicitly stopped, preserved
as incomplete, and replaced by the full run with both real-mobile gates enabled.
Neither interrupted attempt is aggregated into the final single-session result.

## Reproduction

Run from the T3 checkout, with the pinned Node 22.23.2/npm 10.9.8 and
Java 21.0.12+8 first on PATH. Do not run full Flutter and Emulator suites
concurrently. Full Emulator acceptance requires both real-mobile gates:

```powershell
$env:RECHARGE_DART = 'C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe'
$env:RECHARGE_FLUTTER_TOOL = 'C:\src\flutter\bin\cache\flutter_tools.snapshot'
$env:RECHARGE_G_MOBILE = '1'
node apps/backend/scripts/run-emulator-tests.mjs
```

The bounded stand command is
`node apps/backend/scripts/stand-d3-7-gate.mjs --yes`. Its reset is restricted
to the T3 checkout's hashed temporary LOCALAPPDATA root. It tests seeded
idempotency parity, both real mobile scenarios and verified stop/cleanup.
## Remaining gates

Production age and consent authority, qualified market Legal/Privacy/DPIA,
production retention scheduler, device/staging/production evidence and owner
acceptance remain open. K2 per-content `contentHide` does not yet support
`find_people`; user sanctions and C2 moderation restrictions are supported.
See amendment §11 for product limitations and owner interpretations.
No commit, push, merge, deployment or market activation was performed.

## 2026-10-21 common closure

Task30–32 shared validation and privacy repairs: [common evidence](../../../verification/T3_I3_J1_COMMON_VERIFICATION.md).
Bounded Review/owner acceptance boundary retained; historical results above
are not substituted for the final common-version run.
