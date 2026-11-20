# IDP/M2 integration — CP3, 2026-11-20

Status: verified local checkpoint; owner acceptance pending.
Dependency: CP2 `8ccc9097`, on combined main `78d6a386` (includes PR12/13).
Exact file plans and reviewable protected patch are in
`outputs/IDP-M2-ONMAIN-2026-11-20/CP3-file-plan.json` and
`CP3-protected-utc-proposal.patch`.

## Boundary decisions

All production UTC text readers now use shared `UtcInstant`: persisted Rental,
Place, Find People, Route/recording, Collection, Scenario intake, publications,
Library, Discover, Identity, Notifications, Auth session metadata and Booking
persistence. Optional malformed record readers retain their existing refusal /
record-isolation contract; required draft timestamps raise a format refusal.
No zone-less string is interpreted through the device timezone as UTC.
`UtcInstant.tryParse` is only the non-throwing form of the same strict parser.

- GPX is an explicit external format: Z and numeric offsets are accepted;
  calendar/time/fraction validation uses UtcInstant before offset arithmetic.
  Invalid/zone-less metadata is flagged without dropping safe geometry.
- Local calendar readers (Place exceptions, Class occurrences, Visit API day)
  use LocalDate. Class 24:00 resolves on the next local calendar day; DST fold
  selection remains feature policy. GTFS after-24:00 remains feature-owned.
- Create restore preserves recorded market, timezone and currency. The old
  v1 city-name/Moscow-to-Riga guess was removed. Absent values stay incomplete;
  missing currency with monetary data is refused. New draft defaults remain
  separate in runtime composition. Existing draft identity is never recalculated.
- Nested currency uses the same explicit recorded envelope context only if the
  key is absent. Present null/invalid data cannot be replaced with EUR. Scenario
  currency subtotals use the strict Money reader and never truncate fractions.
- Place/Rental location/availability identities distinguish absent from present
  unknown/malformed metadata; no active market lookup occurs while restoring.
- Event and Class compatibility adapters may inherit an absent legacy override
  from the same stored envelope. Event scalar text remains subject to feature
  validation; Class unrecognized typed fields are preserved in unknownFields
  and refuse the server body. These are retained data readers, not forwarding
  wrappers. Session/Scenario stored clocks and snapshots are not recomputed.
- Discover v1/v2 monetary preference records retain their historical LV/EUR
  context explicitly; schema 3 requires its own currency. The known v1 automatic
  Rezekne search-area correction remains a versioned preference read and does
  not mutate storage or manual areas. Current draft market IDs are not inferred.
- Catalog v1's LV namespace is explicitly bound from known MarketRef entries;
  country display metadata, locale, currency and timezone cannot choose it.
  Unknown market binding raises FormatException; this grants no server access.
- Unknown display zones use the existing visibly labelled UTC presentation;
  they are not persisted as a guessed object timezone. New/edit commands may
  choose the explicit owning draft zone; restore paths do not call them.

Reproducible inventory: `python tools/scripts/audit_m2_temporal_boundaries.py
--output outputs/IDP-M2-ONMAIN-2026-11-20/CP3-temporal-inventory.json`.
The JSON contains every matched file:line, code/context and decision; remaining
permissive DateTime text readers: zero. Final source scan and hashes are attached.

## Owner-approved protected diff

Only UtcInstant import and three parsers changed in Booking transport and debug
Event fixture, after 7 isolated candidate tests passed. Durable production tests
cover .000Z establish, readCurrent restore and refresh; +00:00, zone-less and
impossible dates intentionally fail closed. The debug GoRouter entry is exercised
with start/end produced by UTC toIso8601String. Existing request correlation,
installation, App Check, session expiry, route guard and v1 Content wire keys
are preserved. The example 2026-11-20T10:00:00.000Z was already expired at test
time: its exact syntax is tested separately and via Emulator transport; the dev
success test uses a future instant in the identical .000Z shape. Expired dev
sessions remain refused. AuthController production logic is unchanged.

**Before main merge:** Claude must verify signin on shared A34 per owner request.
This session did not install on, clear, sign out from, or access the phone/cloud.

## Gates and failure inventory

- Initial complete CP3: 2695 passed / 83 skipped / 2 failed, exit 1.
  Both failures exposed Collection's real default clock writing local review
  time without Z; capture now converts that real clock instant to UTC.
  Existing default-composition publish tests now also assert UTC review time.
- Corrected complete run: 2701 passed / 83 skipped / zero failed, exit 0
  (`CP3-flutter-full2.log/.exit`).
- Protected candidate: 7 passed, exit 0; production guards/router/Money focused:
  45 passed, exit 0 (`CP3-protected-candidate`, `CP3-focused4`).
- Complete run after protected diff: 2712 passed / 83 skipped, exit 0
  (`CP3-flutter-full-final.log/.exit`).
- Final metadata-focused: 21 passed, exit 0; analyze no issues, exit 0;
  full suite 2713 passed / 83 skipped / zero failed, exit 0
  (`CP3-metadata-focused`, `CP3-analyze-last`, `CP3-flutter-full-last`).
- Read-only boundary scan: 712 Dart files, 69/71 exceptions, zero violations /
  stale / expired, exit 0 (`CP3-boundary.log/.exit`); generated inventory untouched.
- Final temporal inventory: 261 classified entries, zero permissive UTC readers.
- `git diff --check`: exit 0.
- Only changed Dart files formatted; diff check required before checkpoint.

No test skips/timeouts/golden expectations were widened. The existing 83 skips
remain stand/platform prerequisites, not proof of Emulator/device/cloud readiness.
Failure inventory and all exit files are retained; the GPX focused test initially
asserted the wrong issue-code collection and was corrected to the global metadata
issue collection; production invalid-input handling was already correct.

## Rollback and retained compatibility

Revert the CP3 checkpoint commit to restore this bounded change. No data migration
or read-triggered storage rewrite ran. MoneyLegacyAdapter (legacy decimal and
integer-object reads), versioned preferences, legacy schedule reads, owner-scoped
Visit v2 reads and feature unknown-field preservation remain. No compatibility
class/forwarding file was deleted; CP4 requires the combined-tree zero-reference
snapshot first. This is architecture M2, not R1 M2 acceptance or production grants.
