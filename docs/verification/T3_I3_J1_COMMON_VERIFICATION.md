# 30–32 — common local closure, 2026-10-21

Status: **Review — ready for bounded owner acceptance**. Existing Accepted
FP-OD and SP-01…SP-14 are preserved. No new production authority or status
promotion. Bounded J1 storage/sync/provenance/limits work was explicitly
authorized in task32. Final owner acceptance remains separate.

## T3 Find People

Retention now reads all stored create/update answers even when the current draft
contains no exact location. All relevant reads and erasures run in a single
Firestore transaction, including concurrent draft/pointer/consent changes.
Deadlines use the earliest immutable owner terminal audit and consent receipt
history, meeting end or current consent termination; mutable pointer.updatedAtUtc
never shifts the deadline. Re-activation cannot reset an established deadline.
Legacy hidden records with no surviving terminal event use original creation;
no timestamp means overdue. No repair-time grace period is introduced. The
unpublished fallback retains the accepted 30+30 day bound from creation, not
subsequent changes. Only a changed current body bumps draft revision; history-only
redaction leaves it intact. Purge audit contains no private values.

Two new real Firestore cases prove stored records, old command replay, boundary
minus1ms/exactly deadline, concurrent purgers and draft/pointer writes, repeat
purge and legacy no-extension. Whole Find People group: **10/10**. Private source
stays author-only; publicGeo server-built coarse cell, consent/18+, fresh
Catalog/MapObject/Content visibility checks are retained. Dedicated D3.7 stand:
clean=interrupted/resumed=repeated, real Flutter controller1/1 and UI1/1,
Catalog/Map, verified stop/reset. Synthetic attestation and Media tools remain
local fixtures.

## I3 Scenario

All Accepted SP decisions unchanged. Personal/unlisted/public, pinned Planning
revision/hash, Media/C3 moderation, review/dependencies/withdraw/activate,
stale snapshots/cursors and share TTL/rotation/revoke/restrictions pass on the
common version. New test12 performs real QuickPlan save -> Expand -> independent
Scenario edit -> Content/publication -> further QuickPlan edits; neither saved
Scenario nor immutable publication changes with the source. It deliberately
uses an empty expansion followed by normal Scenario authoring, while existing
I2 tests cover selected-stop conversion. Participants/private source/provenance
are excluded; no Route lifecycle or fields enter the publication. Dedicated I3
real Create/UI stand passes clean/resumed/repeated + verified stop/reset.
Whole Scenario I3 group: **12/12**, I2 **17/17**, invited QuickPlan **7/7**.

## J1 Route

The single streaming parser accepts SYSTEM/PUBLIC in ordinary text, CDATA and
attributes. DTD/entities/XInclude and byte/point/depth/event/attribute/text limits
remain enforced; hostile XML tests include no filesystem/network IO tripwires
and exact-boundary/next-value checks. Route sync imports no Scenario mapper:
RouteCanonicalCodec carries the same legacy canonical encoding algorithm;
byte/hash comparison vectors and existing restart/lost-answer journal tests
preserve key semantics and stored journals. No journal version migration.

Policy remains endpoint-radius-v1: only start/end prefixes/suffixes are removed;
later re-entry remains. No popup or additional confirmation introduced. Actual
trimmed geometry is previewed; full owner geometry is never a fallback when a
trimmed view is empty/refused. Provenance, two clients, conflicts, delete,
offline/restart, lost answer and preview->apply->sync->trimmed export->import
pass through real Flutter adapters against Emulator. Route group **9/9**.
No Scenario fields or external routing provider added.

## Final evidence

| Gate | Result |
|---|---|
| Backend unit/contract/integration/stand |1132 passed,0failed/skipped|
| Full Emulator, one sequential final session |20/20 groups,367passed,0failed/skipped,complete=true,code=0,outer0|
| Flutter analyze/full tests |0issues;1753passed,78environment skips,0fail|
| Dedicated T3 / I3 |Both PASS, real host Flutter, repeat/recovery, verified stop/reset|
| API / boundary |25passed;0violations,71/71valid suppressions|
| ESLint / full Prettier |PASS (one erased type assertion repaired; emitted T3 runtime byte-identical)|
| Layout/config/exports/manifest/persistence |PASS|
| Runner/stand self-tests |19/19|

Frozen final source:2187files, SHA256 `526b6a64e065a0f862e949abe885e342b7a18c9837a7bca1e81a52039a48202e`. No file changed during final
Emulator. Stand runs precede final test-only formatting and an erased type-cast
cleanup; emitted T3 runtime equivalence is archived. No product runtime changes
after stands. All final source included in final full Emulator run. Ledger:
`C:/Users/User/AppData/Local/Temp/recharge-emulator-tests-huTDxG/summary.json`.

Node22.23.2,Temurin21.0.12+8,Flutter3.44.9,Dart3.12.2. Initial failed attempts
are archived and excluded from green evidence. Original T2 six changes and T3
WIP preserved byte-for-byte; I1/I2 runtime/tests14/14 normalizedLF unchanged;
one canonical Scenario creation writer preserved. Work done in isolated common
copy based on9881c48 plus completed26–29; shared source checkouts unchanged.

Limits: local/LV Emulator + PC-host Flutter only. No device/native process-death,
production Identity/Media/Legal/Privacy/cloud/staging/production claims. No
commit,push,Git merge,deploy,provisioning or CI activation. Prior I3 owner
acceptance is preserved; this common closure does not accept T3/J1 on their behalf.
