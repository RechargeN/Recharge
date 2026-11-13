# 28–29 — Session and Class / Workshop on the common local build

Status: **Review — technical result ready for bounded owner acceptance**, 2026-10-20. This document does not
accept the result for the owner or enable device/cloud/staging/production.

## Basis and preserved work

The isolated checkout is `C:/Users/User/Documents/Codex/2026-10-20/new-chat-3/work/recharge-t1-t2`.
Base: `9881c48deb4569b3096b14d4d9ed194e498cdd9e` plus the complete I1/I2 result
from task 27, T2 checkpoint `bed7b05` with all six final uncommitted corrections,
and the existing T3 Find People WIP for common-build compatibility verification.
The original integration, T2, T3 and I1/I2 checkouts are untouched. No commit,
push, Git merge, deployment, provisioning or CI activation was performed.

The I1/I2 changed runtime and tests (14 changed runtime/test files) are identical after LF
normalization; the existing Scenario creation writer was not changed. The six
T2 corrections are preserved in a separate patch before integration. Patches
and source fingerprints are recorded in the user-facing result manifest.

## Owner and contract gate

- T1: [Session v1.2](../product/create/BOOKABLE_SESSION_CREATE_BLOCK_SPEC.md),
  Approved slice spec; explicit owner decisions and accepted implementation plan
  in [D3.5 §1](../product/D3_5_SESSION_PUBLICATION_AMENDMENT.md); BCK-07 §46.
  This is sufficient for the bounded local/LV Emulator work; parent Review does
  not revoke the explicit slice authorization or constitute production approval.
- T2: [Class v1.2 §2.6/§34](../product/create/CLASS_WORKSHOP_EXPERIENCE_CREATE_SPEC.md)
  CW-V1 Approved; CLS-OD-01…10, accepted plan §6 and accepted Event Classification
  2.2.4 in [D3.6 §1/§1.1](../product/D3_6_CLASS_WORKSHOP_PUBLICATION_AMENDMENT.md);
  BCK-07 §47/§47.1. Full Class product §1–§33 remains outside CW-V1 approval.
- Compatibility T3: [D3.7 §1.2](../product/D3_7_FIND_PEOPLE_PUBLICATION_AMENDMENT.md)
  records FP-OD-01…04 local owner policy, synthetic 18+, consent, private source
  and public cell. No production OD-11 or Legal/Privacy acceptance is inferred.

## Integration decisions

- One Content aggregate/C3, common Media/moderation, existing config-driven Create
  form engine and type section are retained. The publication test panels do not
  replace the form engine. Class UI tests complete the real Create block.
- C3 immutable activation revalidates Session, Class and Scenario targets. The
  strict current-reference snapshot equality for Session and Scenario is kept;
  Class uses its accepted current-policy validation and occurrence rules.
- Class source schema refusal remains `content_type_unsupported` on submit,
  approved publish and immutable activate, with the complete stored snapshot
  unchanged. No translation of the diagnostic issue into another public code.
- Registry becomes v9 for the combined availability change. All type flags stay
  independent and default off. Unavailable Route Content remains fail-closed;
  J1 owner Route storage does not grant Content publication.
- Catalog keeps separate Scenario and Find People switches; a regression checks
  each alone, both together and refusal of one when only the other is enabled.
- Both Session and Class use external HTTPS handoff, without internal Booking,
  inventory, holds, availability persistence or materialization. Existing Booking
  tests are regressions of the pre-existing Event authority, not new type grants.
- Shared entry points, manifests, deny rules, export/layout allowlists, stand
  commands, fixture digests, DI, router and callable transport retain all owners.
  T2 and T3 both used BCK-07 §47; Class keeps §47 and Find People moves to §48.
- The common runner has 20 groups / 60 tasks. Its 92.5-minute worst-case bound
  requires more than 102.5 minutes including prerequisites; the local workflow
  timeout is 110 minutes. No workflow was activated or run remotely.

## Required matrix

| Area | Evidence on the common build |
|---|---|
| Session typed body / validator / schedule bounds / exceptions / timezone | shared compatibility fixtures and Session rules suite |
| Session reference revisions, old immutable revision, CAS, retries | `content_session_enablement.test.ts`, Session Emulator group |
| Class typed form / mapper / references / DST / Media | Class compatibility fixtures, typed Create tests, Class Emulator group |
| Full C3, lost response, rollback, future schema refusal | Class integration tests and Class callable/flow group |
| I1/I2 collaboration and single independent Expand | Quick Plan and Scenario I2 groups, including real Flutter adapters |
| Scenario publication / privacy / shares / Catalog | Scenario I3 group |
| Find People private source / public cell / consent / age / retention | Find People group and existing typed Flutter tests |
| Real controller/UI, clean/resumed/repeated, verified cleanup | dedicated D3.5 and D3.6 stand gates |

## Final gate ledger — after Session privacy repair

| Gate | Final result |
|---|---|
| Backend unit/contract/integration/stand | **1132 passed, 0 failed/skipped** |
| Full Emulator, one complete session | **20/20 groups, 364 passed, 0 failed/skipped, complete=true, code=0, outer exit=0** |
| Session / Class / Find People / Scenario I3 | **9 / 7 / 8 / 11 passed** |
| Scenario I2 / Quick Plan | **17 / 7 passed**, real Flutter adapters |
| Dedicated D3.5 and D3.6 stands | **Both passed**: each clean=interrupted/resumed=repeated, controller1/1, UI1/1, invariants, verified stop/reset |
| Flutter analyze / full Flutter test | **0 issues / 1751 passed, 78 environment-gated skips** |
| API contracts / boundary | **25 passed / 0 violations, 71/71 valid suppressions** |
| ESLint / full Prettier | **Passed**; affected lint repeated after privacy repair |
| Layout/config/exports/manifest/persistence | **Passed** |
| Runner and stand launcher self-tests | **19/19 passed** |
| Local links / diff / patch checks | **Passed** |

Node22.23.2, Temurin21.0.12+8, Flutter3.44.9, Dart3.12.2. All mandatory
stand/Emulator tests ran on the same frozen source set, 2,186 files:
`d402ebd14bd50df10f2ca78e223b248deca75d22b42060f064ac3618dd36ea01`. Ledger: `C:/Users/User/AppData/Local/Temp/recharge-emulator-tests-wXVtsP/summary.json`.
No source changed during the final full run or either final stand. Flutter
code/config, API contracts and boundary inputs were unchanged by the backend-only
privacy repair; their full gates above remain applicable, and the final real
controller/UI stands exercise the repaired backend. No incomplete run is green.

## Session immutable source privacy repair

An additional audit found that `getPublishedRevision` returned the raw Session
immutable source to a foreign actor, including private_note and exception audit
fields. The new integration test was RED before repair (3 pass/1 fail) and GREEN
4/4 after. BCK-07§10 calls this an authorized immutable source snapshot;
D3.5§3 Privacy requires separate owner-read authorization, and Session§11.3/§18
forbid public private exception/audit data. These are existing accepted boundaries.

Session raw reads now require the exact personal Publisher and fresh Identity
owner-service `read` authorization. Foreign actors receive not_found without
source data. The owner still receives the exact body/hash; reads never rewrite
immutable revisions or pointers. The existing public Collection evaluator remains
allowlist-only; no new public DTO, projection, aggregate or visibility policy is
introduced. A real Functions HTTP regression checks owner success and foreign
staff refusal with no private_note/audit disclosure. Focused Session Emulator
QifBTn passed9/9; the complete final suite and both stands were repeated after
this fix. The earlier363-test run and first stand pair are historical evidence,
not final privacy acceptance evidence.

## Dedicated Create/UI and lifecycle coverage

Both final stands use actual Flutter repositories/controllers and typed Create
widgets against Auth/Functions/Firestore/Storage Emulators. Each verifies clean,
interrupted/resumed and repeated seed digest equality, then controller1/1 and
UI1/1, final base/type invariants and verified stop/reset of its own isolated root.
Class uses the existing config-driven form engine; Session keeps its accepted
Create block. Mobile follows the accepted Q4 subset: backend-only C3 activation
and rollback do not imply a new mobile Activate/post-publication edit UI.

## Preservation and transfer

Original T2 six-file diff and T3 WIP remain byte-identical to pre-integration
snapshots. All14 changed I1/I2 runtime/test files are identical after EOL
normalization; the existing canonical Scenario writer was not modified.
The full common patch from9881c48 and the delta after exact26/27 are alternatives,
not cumulative. Both pass forward cached checks on their exact base trees and
reverse checks on the result. T2 six-file backup is againstbed7b05 and is already
included. Original integration and source worktrees are untouched.

## Historical non-green attempts

The initial conflict resolution had a duplicated callable helper; the first
backend run had four stale availability/flag-position expectations; the runner
refused an insufficient aggregate workflow budget; an API-contract invocation
outside a package ran no tests. Two test files needed formatting (syntax trees
were identical). Those issues were corrected. The first green full suite and
stand pair were then superseded by the explicit Session privacy repair above.
Old logs are labeled historical in the evidence bundle. The final ledger never
counts an interrupted, failed or superseded attempt as current green evidence.

## Limits and owner acceptance

Technical work and required local gates for28/29 are complete, ready for bounded
owner acceptance; statuses remain Review. This is host Flutter/PC Emulator
only, with test Media scanner/processor, synthetic Identity/age and test-only
staff fixtures. No device/native process-death, cloud, staging, production,
production Identity/Publisher/Media, Legal/Privacy or market activation claim.
No new Booking/inventory/holds/materializer. Find People compatibility does not
accept its separate owner result. No commit/push/Git merge/deploy/provisioning
or CI activation; the local workflow timeout change was not run remotely.
