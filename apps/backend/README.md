# Recharge backend — local platform and bounded domain foundations

Status: **local R1 platform, Reference Data, Security/Privacy,
Identity/Publisher and complete bounded local Booking vertical; all cloud and
market activation disabled**.

R1 adds a provider-neutral local platform skeleton on top of the retained R0
and disabled RAW-C compatibility evidence. It contains typed logical
environments, immutable release/config revisions, optimistic activation
pointers, default-deny security ports, bounded telemetry and in-memory
adapters. Product domains remain separately gated.

The BCK-20 foundation adds immutable, schema-validated LV/EE/LT market
configuration, explicit locale fallback outcomes, currency and IANA-timezone
contracts, mandatory-copy and source-eligibility gates, and compatible
activation-pointer rollback. Its data is synthetic, each market is isolated,
and every capability remains disabled. No external dataset is imported.

The BCK-04 local foundation adds server-resolved actor/session/market/workspace
checks, default-deny authentication and capability decisions, App Check and
rate-limit ports, privacy-safe audit/redaction controls, data-class/access/
retention registries, unavailable-by-default age policy, emergency-disable
flags and both in-memory and Emulator-only Firestore DSR repositories. Booking
DSR tasks run through the domain handler with bounded attempts and atomic
pseudonymization. It stores no secret values, chooses no numeric age and
exposes no client or cloud handler.

The BCK-06 local slice adds provider-neutral Google/Apple assertion ports,
hashed provider-subject linking, Account and Session authority with revocation
fences, Creator and ManagedPage verification lifecycles, exact-page membership,
fresh AccessSnapshot evaluation and ID-based PublisherRef eligibility. It has
in-memory and disposable-Emulator Firestore adapters, including opaque Session
handles and revision-fenced AccessSnapshots. One disabled Emulator-only
Session callable maps Firebase transport UID to a distinct domain User ID. It
remains local/test-only: no OAuth credential, production Firebase Auth adapter
or production grant exists.

The BCK-09 local slice contains six disabled Emulator-only Booking callables,
three bounded Identity Session callables, one Event trigger and two schedules,
typed command/query results, finite and unlimited inventory transactions,
idempotency, cancellation, access-revocation, retention and reconciliation
evidence. Booking mutations resolve Account, Session, AccessSnapshot and the
common R1 feature flag inside the same Firestore transaction; query authority
is separately revision-aware. A provider-neutral mobile adapter is present but
bound only to an explicitly loopback dev Emulator; production binding remains
disabled. Immutable Event outbox records feed the sole Booking projection
consumer; delivery checkpoints, cancellation/reschedule effects and all
Booking/support collections remain direct-client default-deny. It is not
deployed. `BCK09-ABUSE-DEC-01 v1.0` adds separate transaction-atomic finite
`5` and unlimited `50` active caps per User+market, layered rolling
actor/account/installation limits, request dedupe, typed retry-after, a
three-active-Session ceiling, atomic opaque-handle rotation and exact-local
App Check bypass. Network identity is a day-rotated secondary hash and never
the sole authenticated-cancel authority. Scoped incident switches and
minimized audit are server-owned; no global security bypass exists. A local
single-ledger load probe preserved the zero-oversell invariant but failed the
accepted popular and mass latency/success targets. A fixed-capacity escrow
model is therefore selected for the later scalability migration: 16 shards
for popular pools and 64 for mass pools. The model, migration planner and
reconciliation tests are pure/default-off code; no Firestore schema, runtime
switch or activation was added.

Materially rescheduled Bookings retain allocation and can be reconfirmed only
for the exact Booking and Event material revisions. The default-off deadline
worker cancels expired unconfirmed Bookings transactionally, releases active
key and finite/unlimited usage exactly once, and uses bounded discovery,
stable pagination, fenced leases, durable checkpoints, retry/backoff,
dead-letter and audited replay. Notification effects remain suppressed until
BCK-13 is separately implemented and enabled.

## Readiness matrix

| Level | Current verdict |
|---|---|
| Local implementation | `Local Booking vertical complete`, with controls, for the bounded free-Booking scope. This verdict covers R1, Identity, Event projection, disabled Booking, exact-revision reconfirmation/deadline release, mobile transport seam and Privacy/retention; it does not authorize project creation or deployment |
| Emulator evidence | Present on Node 22.23.2, npm 10.9.8 and Temurin 21.0.12+8: 93 unit, 28 contract, 16 integration and 84 Emulator/Rules tests pass. Evidence covers Auth UID → opaque Session → Event projection → callable Booking → reconfirmation/deadline release → Privacy/DSR, plus missed-trigger discovery, fenced delivery, audited replay and legal-hold-safe follow-up |
| Dev cloud | Not Ready; no project, billing, credentials, deployment or measured cloud load evidence |
| Staging | Not Ready; no independent Security/Privacy review, restore/incident drill or staged rollout evidence |
| Production | Not Ready; no qualified Legal/Privacy, SLO/cost/DR or escrow runtime evidence |
| Enabled markets | None; LV, EE and LT remain independently disabled |

## Safety boundary

- project identity is always `demo-recharge`;
- no `.firebaserc`, cloud credential, OIDC, service-account key or secret;
- no Firebase/Google project creation, API enablement, billing or deployment;
- no Terraform backend, stateful resource, plan or apply;
- Firestore and Storage client access deny all;
- the exact export allowlist is R0 plus six disabled Booking callables, three
  disabled Identity Session callables, one Event trigger and two schedules;
  all refuse non-emulator use;
- all `local/dev/stage/prod` identities are logical and `unbound`;
- every market, capability, feature flag and release is `disabled`;
- Terraform has no resources, backend, real project or credential input;
- `apps/mobile` does not depend on this package.

Any command requesting login, a real project, credentials, billing or deploy
is a boundary failure and must stop.

## Exact toolchain

The authoritative pins live in `toolchain.lock.json`. Required hosts:

- Node.js 22.23.2 / npm 10.9.8;
- Eclipse Temurin 21.0.12+8;
- Terraform 1.15.9;
- Windows x64 or Linux x64.

Do not substitute a global Firebase CLI or floating tool version.

## Local verification

From `apps/backend/functions`:

```text
npm ci --ignore-scripts
npm run verify:cloud-context
npm run verify:toolchain
npm run format:check
npm run lint
npm run typecheck
npm run test:unit
npm run test:contract
npm run test:emulator
npm run verify:generated
npm run verify:reproducibility
npm run verify:r1:layout
npm run verify:r1:config
npm run verify:r1:exports
npm run test:r1
npm run test:r1:emulator
npm run test:reference-data
npm run test:security-privacy
npm run test:identity-publisher
npm run test:booking:load:local
```

`test:booking:load:local` is a deliberately long disposable-Emulator probe. It
checks the agreed normal/popular/mass profiles and records latency, outcomes
and oversell. It is evidence for architecture selection, not a release gate or
production benchmark.

From `apps/backend/infra/terraform`, after the verified R0 Terraform installer:

```text
terraform fmt -check -recursive
terraform init -backend=false -input=false -lockfile=readonly
terraform validate -no-color
```

The exact R1 collection families are `platformReleaseManifests`,
`platformActiveReleasePointers`, `platformFeatureFlagRevisions`,
`platformActiveFeatureFlagPointers`, `referenceMarketConfigRevisions` and
`referenceActivationPointers`. Identity uses the explicitly deny-all
`identityAccounts`, `identityProviderLinks`, `identitySessions`,
`identityAccessSnapshots`, `identityCreatorVerifications`,
`identityManagedPages` and `identityPageMemberships` families. Direct client
access is denied. Only the local Emulator/Admin test context may write
synthetic records, and every test removes them.

A missing exact tool, network outage or command that did not execute is
`Inconclusive`, never Pass. Current hosted parity and Moderate transitive
advisory disposition remain open. See
`docs/evidence/backend/r0/BCK-R0-TCH-01_RESULT.md`.

## A1 managed local Emulator stand (Windows)

Requires the pinned Node 22.23.2 and JAVA_HOME pointing to Temurin
21.0.12+8, with `%JAVA_HOME%in` first in PATH: the Firestore and Storage
emulators start `java` from PATH, and another JDK there is refused as a foreign
executable at stop. Build once (`npm run build`) so Functions can load.
Run from apps/backend/functions:

```powershell
npm run stand:start
npm run stand:status
npm run stand:stop
npm run stand:reset -- --yes
npm run test:stand
```

Only demo-recharge is allowed. Auth (9099), Firestore (8080), Functions
(5001), Storage (9199), Pub/Sub (8085), Hub (4400) and logging (4500)
bind to 127.0.0.1. UI is disabled. No phones, LAN, cloud
credentials, provisioning or domain-function changes are included in A1.
Existing default-off function exports remain disabled.

State, generated config, data and per-run logs are outside Git under
%LOCALAPPDATA%\\Recharge\\emulator-stand\\demo-recharge\\.
Every command rejects credential environment variables, ADC and cached
Firebase login and Functions .env/.env.* files. Existing ports, stale state and foreign processes are
never adopted or killed. Process ownership requires PID, creation time,
executable and supervisor run ID; children must descend from that verified
supervisor. Project identity additionally requires CLI argv, the
demo-recharge locator PID, hub PID and the five emulator endpoints.

Stop exports Auth/Firestore/Storage data before stopping verified child
processes. Pub/Sub is ephemeral. Start imports a previous export when present.
Reset warns and requires --yes; it removes only the exact marked data folder
and the recorded state/config, rejects junctions (including nested ones),
live/reused PIDs and occupied ports, and preserves logs.
For stale state with a remaining locator or process, reset refuses: inspect
the log and resolve the orphan manually; do not kill an unverified PID.
A leftover command.lock after interruption also requires manual inspection.

test:emulator keeps its existing independent lifecycle. Stop the stand
before running it; it does not reuse stand state.

## A2 deterministic seed, export/import and bootstrap (Emulator only)

With the stand running (see A1), from apps/backend/functions:

```powershell
npm run stand:seed      # 3 users, 2 pages, Content Event, Booking fixture, 3 bookings
npm run stand:verify    # seed invariants (authority, pages, inventory, flags)
npm run stand:digest    # normalized state digest; add -- --out <new file>
npm run stand:export    # export Auth/Firestore/Storage to the stand data folder
npm run stand:acceptance -- --yes
```

Everything is created through owner paths: Firebase Auth Emulator users and the
`establishIdentitySessionV1` / `recoverIdentitySessionsV1` callables for
Sessions, the Identity owner services for the Creator verification and two
Professional Pages, the Booking callables for bookings, and the Booking
projection delivery for inventory. Since C3 the stand's Event is created through
the Content path (see C3); the explicit Event-outbox fixture
(`stand-event-outbox-riga-open-air-1`) remains only as the Booking-test fixture
and is not evidence of Content publication. The writes made by the stand tooling
itself are the local flag bootstrap (identity session, Media upload, Event
authoring and booking create/cancel/read/projection delivery; reconfirmation
stays off), because no Firestore flag repository exists yet, and the stand
manifest (stand metadata, see C3). Owner-confirmed on 2026-10-06.

The staff Account is the reviewer for the bootstrap decisions inside the seed
process and, since C2, the one entry of the test-only staff registry (see C2).
Ordinary sign-in never grants Creator or staff authority. A repeated seed on a
complete stand reuses it (`reused ...`, owner-confirmed on 2026-10-06); a
partial base seed is refused and needs a reset. The bootstrap is bounded to
`demo-recharge`: the seed process rejects any other project, a non-loopback
host or credential environment variables.

Stop exports the data and start imports it, so a stopped stand is restored
without manual database edits. A partial base seed is recovered with
`stand:stop`, `stand:reset -- --yes` and `stand:seed`; an interrupted Content
Event phase is resumed by running `stand:seed` again. The digest replaces
server-generated ids with labels and removes timestamps and per-run hashes, so
seed, reset, seed gives the same normalized state; `stand:acceptance` proves
that and export/import equality on the local Emulator only. It makes no cloud,
device or LAN claim. Session handles and the Emulator-only password are never
printed.

## B1/B2 local mobile gates (Emulator stand, PC host only)

From apps/backend/functions, with the pinned toolchain and Flutter on PATH.
Both gates reset the stand data and so need an explicit `--yes`:

```powershell
node ../scripts/stand-mobile-gate.mjs --yes   # B1-local: Auth Emulator, Session lifecycle
node ../scripts/stand-b2-gate.mjs --yes       # B2-local: Event Booking UI, three fresh runs
```

Both start a fresh seeded stand, run Flutter tests on the PC against it
(loopback only, no `adb`, no device, no LAN, no cloud) and always stop it.
B1-local covers sign-in through the Auth Emulator, a server-issued Session and
its recovery after a restart, owner-service revoke and expiry, and the
reversible `localOnly` / `testBackend` Booking binding. B2-local covers the
Event Booking screen on the seeded Event: create, my booking, cancel,
loading/error/offline/unknown-outcome, the idempotency journal, double tap, a
lost response and recovery after a restart. After every run the backend itself
is asked for the staff user's booking counts: any duplicate fails the gate.

The Booking test entry is default-off. It needs all of:
`--dart-define=RECHARGE_TEST_BOOKING_ENTRY=true` (`bool.fromEnvironment` does
not accept `1`), a non-release build, the `testBackend` binding and the
loopback `demo-recharge/europe-west1` endpoint. The same check guards the
`/test/event-booking/:eventId` route and every Booking read and command in the
gateway, not just the button.

Limits: the `firebase_auth` and secure-storage plugins do not run in a host
test, so they are covered in B1-device; Sessions are rate limited per Account
(5 issues per 15 minutes), so each gate starts from a reset stand; the
`stand:*` npm scripts need a working npm (the portable one in Temp can be
damaged), the gates can be run directly with `node` as shown.

## C1 minimal Media (Emulator only)

`node ../scripts/stand-c1-gate.mjs --yes` (from apps/backend/functions) starts a
fresh seeded stand and runs the mobile Media adapter against it on the PC.

What exists: a Firestore Media repository (compare-and-set, immutable
receipts), a Storage Emulator object store (provider facts measured from the
stored bytes; the media type comes from the file signature, never from what the
client declared), Identity-backed upload authority (Session, verified Creator,
exact Page membership) and Content-backed entity scope, plus three default-off
Emulator-only callables behind the `media.upload` flag: `mediaCommandV1`
(createUploadSession, confirmUpload, finalizeAsset), `mediaQueryV1` and
`uploadMediaBytesV1`. The last is the byte channel: the contract hides the
upload target and the Emulator cannot sign URLs, so the owner of an open session
sends the bytes and the backend writes them. It is not the production upload
mechanism. Content checks the exact Media revision through the existing
readiness adapter, and a mandatory Event cover is unchanged.

Evidence limits: the scanner and processor are the existing FAKES
(`fake-scan-1`, `fake-proc-1`) with a synthetic `test-only` policy. They prove
orchestration, not malware detection or transformation. Not covered: real
scanner or processor, cloud Storage, a late restriction of Media, gallery
selection and permissions (B1-device).

## C2 minimal moderation (Emulator only)

`node ../scripts/stand-c2-gate.mjs --yes` (from apps/backend/functions) starts a
fresh seeded stand and drives the operator path end to end.

The staff interface is a script, not a callable and not a screen:
`node ../scripts/stand-moderate.mjs <command>` (also `npm run stand:moderate --`).
No Functions export was added.

```text
queue
approve|reject <submissionId> --reason "..."
restrict|withdraw <contentId> --reason "..."
restore <contentId> --decision <decisionId> --reason "..."
receipt <decisionId>
[--as <stand user>] [--key <idempotency key>]
```

The script holds no authority. It runs as a stand user (default `staff`) and the
moderation service decides on every call: a current Session plus an entry in the
staff registry. A Creator or ordinary user (`--as creator`) is refused with
`staff_denied`; an unknown Session is `unauthenticated`. A reason of 3-500
single-line characters is mandatory.

What happens on a decision: the service validates the exact target (a
submission still `under_review`, or the published revision and pointer revision
now current), records an immutable decision (who, Session, target and revision,
action, reason, policy revision) and an audit entry, then asks Content to apply
it through Content's own verified `applyModerationDisposition`. Content verifies
the instruction against the recorded decision and writes the pointer or
submission; moderation never edits Content documents. The result is an
immutable enforcement receipt (`applied`, `already_applied` or `refused` with
Content's code) plus an audit entry. A retry with the same key resumes whatever
step did not finish; the same key with other content is `idempotency_conflict`.

Hold semantics are Content's, unchanged: `restrict` limits visibility,
moderation `withdraw` takes the publication down by decision, the owner's own
`withdrawPublication` is a separate hold, and `restore` lifts only the
moderation hold named by `--decision`. It is not an unconditional republish: an
owner hold stays, and a restore of a decision that a newer one replaced is
refused as stale and changes nothing.

Staff authority source (TEST-ONLY): the collection `moderationStaffAuthority`,
keyed by the real Identity `userId`, written only by the stand seed
(`grantStandStaff`), never by a command or a mobile client. It is read only
inside the verified `demo-recharge` loopback Emulator context (the constructor
refuses any other); a missing entry is a refusal; a user label or Firebase UID
is never consulted. It is not production IAM and not a general Admin. The seed
invariants require exactly one entry, for the staff Account.

A2 digest change (intentional): `moderationStaffAuthority` joined the digest
collections, so the normalized digest differs from the pre-C2 one by exactly
that registry document (and the C1 `media.upload` flag change before it). The
determinism rule is unchanged: seed -> reset -> seed gives the same digest
(`stand:acceptance` passes). The old digest was not kept: it must not dictate
the authorization model.

While moderation is composed into Content, submissions need review before
publication (profile `emulator.operator-review`, policy
`test-only-emulator-moderation-policy-1`). The C1 Media checks still use the
synthetic no-review profile.

Evidence limits: this proves the operator path on the local Emulator. It is not
an Admin UI, not production IAM and not product moderation policy; no reports,
sanctions, appeals or AI review exist. The attestation that binds a decision to
Content's verification is a hash, not a signature. Media is the existing fakes
(orchestration only).

## C3 Event through Content, Media and moderation (Emulator only)

`node ../scripts/stand-c3-gate.mjs --yes` (from apps/backend/functions) proves
the path end to end on the local stand and this PC.

Backend. Two default-off, Emulator-only callables behind the local flag
`content.event.authoring`: `contentCommandV1` (owner commands: createDraft,
updateDraft, submitForPublication, publishApprovedRevision, withdrawPublication,
activatePublishedRevision) and `contentQueryV1` (getDraft,
getPublicationStatus, getPublishedRevision). Moderation dispositions and
delegated-import inputs are refused there. The composition (`content_entry.ts`)
binds Content to Identity eligibility (Session, verified Creator, exact Page),
Media readiness of the exact revision and the C2 moderation verifier, so review
before publication is mandatory. Only `event` is enabled, only in this
composition. Reference data is `EmulatorSyntheticReferenceData`: TEST-ONLY
constants for LV, not accepted MarketConfig or taxonomy. The stand helpers use
the same composition; the former stand-only "no review" policy is gone.

Server checks shown by `content_event_emulator_flow.test.ts` (in
`test:emulator`): the callables are closed until the flag is on; a user who is
not a verified Creator member of the Page cannot author for it; publication
needs the staff approval; a published revision never changes and the pointer
rolls back to an earlier immutable revision (`previousPublishedRevisionId`);
the owner's hide and a moderation restriction are separate holds and the owner
cannot lift a restriction; publishing an Event creates no Booking projection.

Seeded Event. The stand's Event is created through the Content path only:
Creator draft on the studio Page, a Media cover (existing fake
scanner/processor), cover binding, submit, staff approval through the C2
service, owner publish. The ids the owner services returned are kept in the
stand manifest (`standManifest/seed`, stand metadata written only by the stand
tooling, like the flag bootstrap); `npm run stand:manifest` prints it and tests
read it. Every seed command has a fixed payload and idempotency key, so a
repeated seed reuses the result (`reused ...`) and an interrupted seed resumes
without duplicates (`STAND_SEED_INTERRUPT_AFTER=<step>` is the test hook the
gate uses; the resumed digest equals a clean one). A partial base seed is still
refused: reset the stand. The Booking-test Event is a separate, explicitly
synthetic Event-outbox fixture: Content publication never makes an Event
bookable, and no Content-to-Booking bridge exists (that needs a targeted
Event/Content contract extension, not automatic values).

A2 digest change (intentional): the digest now includes the Content, Media and
moderation records of the seeded Event and the manifest; server-generated ids
are labelled from the manifest, and Storage Emulator generations are volatile.

Owner decisions (confirmed 2026-10-06): the manifest is kept in Firestore as
stand metadata written only by the stand tooling; a repeated seed on a complete
stand reuses it instead of refusing; and the A2 digest changes explicitly with
C2 and C3, without keeping the old value.

Mobile. A default-off test page (`/test/event-publication`, define
`RECHARGE_TEST_EVENT_PUBLICATION=true`, not release, `testBackend`, loopback
`demo-recharge` endpoint; the same guard gates the route, every Content call
and the cover upload). It takes the signed-in user's own Create Event draft
from the Create repository and maps it to the Content body (local occurrence
ids become stable UUIDs; the cover is a local reference until the C1 Media
upload returns the asset id; admission, inventory and occurrence overrides are
reported and never sent). The application controller saves, uploads the cover,
submits, shows the publication status, publishes after approval and hides; "my
objects" is a local journal of ids from this install with statuses read from
the server. Tests: `event_publication_stand_test.dart` (controller, real stand)
and `event_publication_ui_stand_test.dart` (UI).

Evidence limits: PC host and local Emulator only; the Create UI steps are not
driven (the draft is a Create domain draft stored by the Create repository);
synthetic reference data; fake scanner/processor; test-only staff registry; no
Booking bridge, other types, Catalog, Discover, AI or full moderation; no
physical device, gallery or permissions (B1-device).

## E1 local Catalog (Emulator only)

`node ../scripts/stand-e1-gate.mjs --yes` (from apps/backend/functions) proves
the path on the local stand. The module is `src/modules/catalog` (BCK-08 v0.3
is Review; this is a local implementation of its read-side model, not an
approval). No Functions export, no trigger, no client callable and no cloud
index were added.

Delivery is manual: `node ../scripts/stand-seed.mjs catalog deliver` runs the
projector over the committed Content facts (read through Content's own
`ContentPublicationFeed`); automatic synchronization is not implemented, and
the delivery mechanism for Discover is a separate decision. The stand command
only calls the Catalog application layer:
`catalog deliver | reconcile | status | rebuild | activate <set> <expected|none> | rollback <expected> | feed [<query json>] | details <contentId>`.

Projection rules. `consumeContentFact` dedupes by fact id (same id with other
content is a conflict and changes nothing), applies facts per object in
`pointerRevision` order (an older revision, including a replay after a hide or
withdrawal, is `stale`), and writes the item version, receipt, source state and
set revision in one transaction. Withdrawn, restricted and archived Content,
unlisted or private bodies, disabled types and consent-limited types are never
listed. Only Event has a projection (an allowlist: no full description, contact
or booking URL); every other type is `type_disabled` (BCK08-OD-04 stays open).
The delivery checkpoint moves only inside the transaction that processed a
fact. Reconciliation compares every Content pointer with the set, replays the
facts Content stored for a gap, reports a fact Content lost as
`source_effect_missing` (never invented), and only a complete run refreshes the
sync time. A rebuild replays every object's fact history into a new set that is
not queryable; activation catches it up, requires full parity and moves the
active pointer atomically against the expected one; rollback re-activates the
previous set after the same catch-up, so tombstones are kept.

Query rules. Feed, Search, Map and Details of one applied query share one
snapshot token (query fingerprint, projection set and revision, visibility,
reference, ranking and availability revisions, and the pinned server time).
Pages are ordered by a total key and never repeat or skip within a snapshot;
an object hidden later is still removed (tombstone wins) and a newer listed
revision is flagged `changedSinceSnapshot`. Ranking is the TEST-ONLY baseline:
default order is the nearest start of the earliest not-ended occurrence,
running occurrences first (`max(start, now)`), ties by content id; distance
only with an explicit valid centre, Events without a point after the others;
literal text filters only. `onlyAvailable=true` is refused with
`booking_availability_source_not_connected_in_e1`; cards carry availability
`not_connected`, never available. Freshness is component-wise and the strictest
wins: projection age against the last successful sync (older is `stale`, never
synced or a future sync time is `unknown`) and reference revisions.

All numeric limits are in `catalogTestOnlyConfig` (owner-approved TEST-ONLY
values, not production defaults, and they do not close BCK08-OD-08/OD-10): page
20/50, candidates 2000, delivery batch 100 x 50, reconcile and rebuild batch
200, projection age 900 s, snapshot and cursor TTL 600 s, radius 100 km within
the LV service area, text 100 characters / 8 tokens / 2 characters, time window
366 days.

Catalog collections are derived and rebuildable; the seed does not write them
and they are outside the A2 digest (the gate checks the digest is unchanged by a
delivery).

Evidence limits: local Emulator only; manual delivery; Event only; synthetic
reference data; test-only ranking and limits; Booking availability not
connected; no UI, ranking experiments, personalization, AI, reviews, provider
data or cloud indexes.

## E2 Discover over the Catalog and Event Booking (Emulator only)

Scope and contract: `docs/product/EVENT_INTERNAL_REGISTRATION_E2_0_AMENDMENT.md`
(owner-accepted 2026-10-06). Order E2a (read path) → E2.0 (internal
registration and the Event → Booking handoff) → E2b (Details → Booking →
cancel, two independent clients).

E2a read path:

- `discoverQueryV1` (callable): `feed | search | map | details` over the E1
  query service, Session required, flag `catalog.discover.read` (default off,
  stand bootstrap only). Read-only; cards never carry the full description,
  Details carries projection v2 (`fullDescription`, `scheduleMode`,
  `publishedAtUtc`); excluded or absent content never carries an item.
- `consumeContentEffectV1` (`contentEffects/{effectId}` created, `retry:
  false`): runs every enabled consumer from its own checkpoint (Catalog under
  `catalog.delivery`). A failing consumer is reported and never marks or blocks
  another; it resumes on the next effect or the stand command, even without a
  new effect. Manual `stand-seed catalog deliver` stays available and
  idempotent next to it.
- Exactly these two exports were added; `verify-r1-exports.mjs` also pins the
  Firestore trigger list. `verify-content-persistence-layout.mjs` now lists
  the approved users of Content persistence (C1 Media, C2 Moderation, C3
  entry, E1 Catalog) and the exact symbols each imports, instead of a blanket
  ban that the owner-approved slices had outgrown.
- Mobile: `discover.catalog` in the binding manifest is `testBackend` only
  with `--dart-define=RECHARGE_TEST_DISCOVER_CATALOG=true`, a non-release build
  and the loopback `demo-recharge` binding; otherwise the existing local
  Discover data (`localOnly`). Adapters live in the Discover data layer behind
  `CatalogQueryPort`; the Functions transport is wired in `app/di`. Feed,
  Search and the Map page share one listing snapshot, Details reads against it
  and marks a different or unconfirmable revision; Catalog filters it cannot
  apply are refused by name.

Gate: `node scripts/stand-e2a-gate.mjs --yes` (builds the Functions the stand
loads, resets the stand, seeds, waits for the trigger to project the seeded
Event, runs `test/backend_local/discover_catalog_stand_test.dart`, checks
reconciliation and stops the stand).

Evidence limits: local Emulator and PC host only; Event only; synthetic
reference data; test-only ranking and limits; Booking availability not
connected in the Catalog; no cover images in Discover (no Media read URL);
no physical device, LAN or cloud claim.

E2.0 internal registration and the Event → Booking handoff:

- Content accepts `registration.mode = 'internal'` only as free, instant,
  offline registration with explicit `maxPartySize` (includes the booker),
  relative registration window and cancellation deadline; bounds in
  `eventInternalRegistrationConfig` (test-only). A published internal Event
  may not leave internal registration, switch capacity mode, change format or
  venue: checked in the transaction that switches the pointer (publish and
  rollback), submit is early feedback.
- `consumeContentEffectV1` also runs the Content-owned handoff (flag
  `content.event.bookingHandoff`): per object in `pointerRevision` order,
  gaps filled from stored history, a checkpoint that never skips, terminal
  markers, "removed before start" decided by the Content change time. It writes
  `eventBookingOutbox` create-only; Booking delivers with its own records.
  Hide is eventually consistent (refused once applied in Booking).
- Stand: `stand-seed.mjs handoff deliver|reconcile|status|state|repair <id>`,
  `booking-deliver` (the Emulator does not run the retry schedule) and
  `creator-fixture` (a second verified Creator for the two-client gate, outside
  the A2 seed and digest). New stores have explicit Rules denies and execution
  manifest entries; no new composite index.
- `getEventAvailability` carries `terms` (pool, channel, party limit, window,
  cancellation deadline) in its authoritative shapes; schema, fixtures and the
  Dart DTO `BookingAvailabilityTermsDto` are updated.

E2b gate: `node scripts/stand-e2-gate.mjs --yes` runs two independent
`flutter test` processes (`test/backend_local/e2_client_test.dart`, roles A
and B) with their own users, Sessions, installation ids and journals on one
stand, synchronized by file rendezvous points with deadlines (no fixed
delays): Create → moderation → Catalog → Details → Booking → cancel with a
repeated command, then A hides its Event while B books it. Do not start other
heavy work while a gate starts the stand: the Functions emulator gives the
code 10 s to load by default and can fail the start under CPU contention.
For a cold local closure run, set `$env:FUNCTIONS_DISCOVERY_TIMEOUT = '60'`
before invoking the gate. This is Firebase CLI's discovery timeout in seconds,
not a deployed function timeout. The stand still requires loaded triggers,
loopback ownership and its original startup deadline; a timeout is a failed
gate. Keep starts separate from heavy verification work.

Verified stop diagnostics retain PID, parent PID, executable and start time in
`%LOCALAPPDATA%/Recharge/emulator-stand/demo-recharge/process-stop-audit.jsonl`
after the existing identity checks and stop action succeed. This file stays
outside Git and is retained across stand reset; it does not grant permission
to stop a process or relax the ownership checks.

## F1 Notifications inbox without push (Emulator only)

Scope and contract: `docs/product/NOTIFICATIONS_F1_INBOX_AMENDMENT.md`
(owner-accepted 2026-10-08). Booking is the only producer; no FCM/APNs, email,
SMS, device registration, scheduler or cloud.

- Producer: with the local flag `booking.notification.effects` (its own
  registry `bookingNotificationFlagIds`, so enabling the Booking commands never
  changes the outbox) the five Booking write paths store the v2 OD-09 envelope
  in `bookingOutbox` in the same transaction; off, the v1
  `suppressedPreActivation` record is unchanged. v1 records are never consumed.
- `consumeNotificationEffectV1` (`bookingOutbox/{outboxId}` created, `retry:
  false`, flag `notifications.consume.booking`): trusted backend context with
  source, producer, schema and Emulator checks, no Session. Claim (Tx1) persists
  a lease and a started attempt; completion (Tx2) writes the inbox record,
  terminal receipt and attempt atomically or nothing; failure (Tx3) schedules a
  retry or a dead letter; an expired lease marks a lost attempt `abandoned`.
- `notificationsQueryV1` / `notificationsCommandV1` (Session, flags
  `notifications.inbox` and `notifications.preferences`): list, unread summary,
  preferences; mark read, mark all read (bounded), archive, update preferences
  (idempotency key per command). `booking.receipts` can be switched off;
  `booking.changes` is locked by the local category policy.
- Stand: `stand-seed.mjs notifications flags on|off <group> | reconcile |
  replay <receiptId> --reason <text> | status | inbox <label> | receipt
  <eventId> | prefs-corrupt|prefs-repair <label> | privacy-erase <label>
  <requestId>`. The stand seed keeps every F1 flag off.
- Privacy: domain `notifications` in `PrivacyDomainTaskRunner`
  (`runNotificationsTask`); erasure restricts the account first, deletes
  records, attempts, command receipts and preferences and turns receipts into
  tombstones without personal data.
- Gates: `verify-notifications-layout.mjs` (exact module files, no inbox
  dependency from Booking/Identity/Privacy, no push/email/SMS SDK, explicit
  Rules denies) and `node scripts/stand-f1-gate.mjs --yes` (switches the F1
  flags on, runs `test/backend_local/notifications_inbox_client_test.dart`,
  reconciles to complete with no dead letter and runs an erasure DSR).

Evidence limits: local Emulator and PC host only; template wording is
unreviewed fixture text; numbers are test-only; no physical device, LAN or
cloud claim.

## F2 user Booking actions (Emulator only)

Scope and contract: `docs/product/BOOKING_ACTIONS_F2_AMENDMENT.md`
(owner-accepted 2026-10-08). Booking `src/` is unchanged.

- Mobile test entry: reconfirmation (journaled, exact Booking and material
  revisions), typed refusal reasons, rate limit with retry-after, seats within
  Booking terms, explicit Refresh; Create keeps a one-time occurrence id when
  the Event is moved.
- Stand: `stand-seed.mjs booking-actions flags on|off reconfirm|deadline-worker
  | deadline | invariants`. The seed keeps reconfirmation and the deadline
  worker off; the Emulator never runs schedules, `deadline` runs the worker
  once with the real stand time.
- Tests: `booking_reconfirmation_deadline_clock` (before/at/after the deadline
  with one shared server clock) and `booking_action_races` (final invariants).
- Gate: `node scripts/stand-f2-gate.mjs --yes` (organizer and participant
  `flutter test` clients, `test/backend_local/f2_client_test.dart`, staff
  approval at rendezvous points, reconciliation and invariants).

Limits: local 2A/2B only; D05/D07 deadline window, under-24 h rule, urgent and
non-material notices stay open; no mobile path to cancel a one-time occurrence
or a whole Event; no device, LAN or cloud claim.

## D1 real local Media tools (Emulator only, Windows-local)

Scope and contract: `docs/product/MEDIA_D1_REAL_TOOLS_AMENDMENT.md`
(owner-accepted 2026-10-09, variant L1, download budget 300 MB). Status:
**Windows-local verified / Linux gate open.**

- Tools live outside the repository in `%LOCALAPPDATA%\Recharge\tools`:
  `node scripts/media-tools.mjs fetch --yes` downloads exactly the artifacts
  of `media-tools.lock.json` within the budget (SHA-256, GPG for ClamAV, SRI
  via an offline npm install) and restores the pinned npm 10.9.8.
- `media-tools.mjs selftest --yes` checks the Windows Job Objects (J1–J6:
  limits, the worker capped at 768 MiB, a hung worker ended at 15 s with
  its memory released, fail-closed start, verified stop).
- `media-tools.mjs start [--stand-signatures-only] | stop | status
  [--instance=<name>]`: clamd and the local tools service, each in its own
  job; `--stand-signatures-only` is the L1 test mode (clean without an
  official database); without it a missing database keeps files in
  quarantine.
- The Emulator composition uses the real tools only with
  `RECHARGE_MEDIA_TOOLS=local-real` (plus port and token); otherwise the
  fakes stay, so C1 and `test:emulator` are unchanged.
- Tests: `npm run test:media-tools` (real sharp and ClamAV); the gate
  `npm run stand:d1-gate -- --yes` (self-check, tool tests, Storage path).

Limits: ClamAV runs with the stand test signature only; EICAR, official
databases and their freshness, the native Linux build and cgroup memory
limits are the open Linux gate; BCK14-OD-03/04/05 stay open; no cloud.

## D3.1 Place through Content, Media and moderation (Emulator only)

`node ../scripts/stand-d3-1-gate.mjs --yes` (from apps/backend/functions) proves
the path end to end on the local stand and this PC
([amendment](../../docs/product/PLACE_D3_1_PUBLICATION_AMENDMENT.md)).

Backend. Place uses the same Emulator-only `contentCommandV1` and
`contentQueryV1` behind its own default-off local flag `content.place.authoring`.
The callables stay closed while neither `content.event.authoring` nor
`content.place.authoring` is on; each type's flag gates createDraft, updateDraft,
submitForPublication, publishApprovedRevision and activatePublishedRevision
(`type_disabled`), while the owner's withdrawPublication and reads stay
available. The composition accepts only `event` and `place`, and only with an
available validator: Activity, Rental, Collection and every type without a
validator stay off. The accepted Place validator is unchanged. Reference data
for Place is a TEST-ONLY subset of the mobile taxonomy
(`emulator_place_taxonomy.ts`, equal to
`packages/api_contracts/schema/content/v1/fixtures/place_reference_taxonomy.json`):
an inapplicable subcategory and a missing required criterion are refused.
Catalog keeps Place excluded (`type_disabled`, BCK08-OD-04), Discover refuses it
and the Booking handoff ignores it; D2 applies to Place media.

Stand. `stand-seed.mjs place seed | verify | manifest | status`: only `place
seed` enables the Place flag on the stand, so the other gates keep their state.
The seeded Place starts as an empty draft, gets a cover and two gallery photos
through Media, then the body with the author the server recorded, submit,
staff approval and owner publish (`STAND_SEED_INTERRUPT_AFTER=gallery-1` is the
gate's resume hook).

Limits: Create-form compatibility is a verified subset (the adaptive Create
rules and the strict v1.0 server rules differ); validator codes are not sent to
the client; no Catalog/Discover for Place; fake scanner/processor; no device,
Linux or cloud claim.

## D3.2 Recharge Activity through Content, Media and moderation (Emulator only)

`node ../scripts/stand-d3-2-gate.mjs --yes` (from apps/backend/functions) proves
the path end to end on the local stand and this PC
([amendment](../../docs/product/ACTIVITY_D3_2_PUBLICATION_AMENDMENT.md)).

Backend. Activity uses the same Emulator-only `contentCommandV1` and
`contentQueryV1` behind its own default-off local flag
`content.activity.authoring`; the per-type gating is the D3.1 rule. The
composition accepts `event`, `place` and `activity`, each only with an available
validator; Rental, Collection and every type without a validator stay off. The
accepted Activity validator is unchanged. What the Emulator cannot resolve fails
closed: Activity reference data is a TEST-ONLY subset of the mobile taxonomy
(`emulator_activity_taxonomy.ts`, equal to
`packages/api_contracts/schema/content/v1/fixtures/activity_reference_taxonomy.json`)
where an unknown pair does not apply, and the composition rule
(`emulator_activity_dependencies.ts`) refuses any `location.linkedPlaceId`.
Catalog keeps Activity excluded (`type_disabled`, BCK08-OD-04), Discover refuses
it and the Booking handoff ignores it; D2 applies to Activity media.

Stand. `stand-seed.mjs activity seed | verify | manifest | status`: only
`activity seed` enables the Activity flag on the stand. The seeded Activity
starts as an empty draft, gets a cover and two gallery photos through Media,
then the full body, submit, staff approval and owner publish
(`STAND_SEED_INTERRUPT_AFTER=gallery-1` is the gate's resume hook).

Limits: Create-form compatibility is a verified subset; validator codes are not
sent to the client; no linked Place, no Catalog/Discover for Activity; fake
scanner/processor; no device, Linux or cloud claim.

## D3.3 Rental / Equipment through Content, Media and moderation (Emulator only)

`node ../scripts/stand-d3-3-gate.mjs --yes` (from apps/backend/functions) proves
the path end to end on the local stand and this PC
([amendment](../../docs/product/RENTAL_D3_3_PUBLICATION_AMENDMENT.md)).

Backend. Rental uses the same Emulator-only `contentCommandV1` and
`contentQueryV1` behind its own default-off local flag `content.rental.authoring`.
The accepted Rental validator is unchanged (the cover stays required). Emulator
reference data answers a TEST-ONLY Rental policy (`emulator_rental_policy.ts`,
equal to `packages/api_contracts/schema/content/v1/fixtures/rental_reference_policy.json`)
for an explicit list of pairs checked against the pinned BCK-20 taxonomy
revision; it is not an accepted policy. Re-activating a Rental revision is
closed (`activationClosedTypes`). Catalog keeps Rental excluded, Discover
refuses it and the Booking handoff ignores it; D2 applies to Rental media.
Emulator tests run in their own group: `npm run test:emulator:rental`.

Stand. `stand-seed.mjs rental seed | verify | manifest | status`: only `rental
seed` enables the Rental flag on the stand; the body is confirmed and attested
by the Creator at the start of the current UTC day
(`STAND_SEED_INTERRUPT_AFTER=gallery-1` is the gate's resume hook).

Limits: TEST-ONLY policy; Create-form compatibility is a verified subset;
validator codes are not sent to the client; no Rental activation, no
Catalog/Discover for Rental; fake scanner/processor; no device, Linux or cloud
claim.

## D3.4 Collection / Guide through Content, Media and moderation (Emulator only)

`node ../scripts/stand-d3-4-gate.mjs --yes` (from apps/backend/functions) proves
the path end to end on the local stand and this PC
([amendment](../../docs/product/COLLECTION_D3_4_PUBLICATION_AMENDMENT.md)).

Backend. Collection uses the same Emulator-only `contentCommandV1` and
`contentQueryV1` behind its own default-off local flag
`content.collection.authoring`; the per-type gating is the D3.1 rule. The
accepted Collection validator is unchanged. Items may only reference allowed
published objects by exact id: Content asks the Catalog-owned evaluator
(`published_object_link_service.ts`, the same one the D3.9 Place relation now
delegates to) about every item at submit, publish and activation. A hidden or
restricted listing needs the author's acknowledgement; an unknown id, another
type or market, and an unanswered question are refused. The evaluator, and the
additive Discover queries `publishedObject` / `publishedObjectCandidates`, are
on only with `RECHARGE_TEST_COLLECTION_MEMBERSHIP=true`; without it Collection
fails closed. Collection reference data is the pinned BCK-20 artifact (any
existing pair applies). Catalog keeps Collection excluded (`type_disabled`,
BCK08-OD-04, no Collection model), Discover refuses it and the Booking handoff
ignores it; D2 applies to Collection media.

Stand. `stand-seed.mjs collection seed | verify | manifest | status`: only
`collection seed` enables the Place and Collection flags on the stand. It
publishes three member Places and the Collection that references them, each
from an empty draft through a cover, the full body, submit, staff approval and
owner publish (`STAND_SEED_INTERRUPT_AFTER=member-2` is the gate's resume
hook). The stand must run with `RECHARGE_TEST_COLLECTION_MEMBERSHIP=true` (the
gate sets it).

Limits: Create-form compatibility is a verified subset; validator codes are not
sent to the client; no removal-only/archive, no Catalog/Discover for
Collection; fake scanner/processor; no device, Linux or cloud claim.

## D4 safe local → server import (Emulator only)

`node ../scripts/stand-d4-gate.mjs --yes` (from apps/backend/functions) proves
the mobile import end to end on the local stand and this PC
([amendment](../../docs/product/LOCAL_IMPORT_D4_AMENDMENT.md)).

Backend. A Session `createDraft` with `importSourceKey` (`loc_*`) now maps one
author's local source to exactly one Content draft: the binding
`local-import:v1:<user>:<key>` is stored with the delegated import bindings
(`contentExternalBindings`) and the same commit-time uniqueness check. Creating
again under any idempotency key returns that draft; the same key for another
type, market or PublisherRef is `idempotency_conflict`; a race leaves one draft.

Mobile. The default-off test entry (`RECHARGE_TEST_LOCAL_IMPORT=true`, plus
`testBackend` and the loopback Emulator) runs dry run, approval, the import
session with durable receipts and resume, and the guarded removal of the local
original (verification, explicit confirmation, 30 days). It never submits or
publishes. The gate seeds the D3.1 Place first (Place authoring flag and Page).

### D4.1 import rollback and fenced cleanup

([amendment](../../docs/product/LOCAL_IMPORT_D4_1_ROLLBACK_AMENDMENT.md)) The
same `stand-d4-gate.mjs --yes` also runs the D4.1 stand scenarios.

Backend. The local import binding now has a `generation`, a `state`
(`active` | `rolledBack`), an optional `cleanup` reservation and a
`bindingRevision` compare-and-set; a D4 binding without these fields reads as
generation 1, active, revision 0. Drafts no longer write the binding: only the
Content service does, in the transaction that creates the draft or changes the
lifecycle. Four Session commands through the existing `contentCommandV1`:
`rollbackImportedDraft` (own draft of the current generation, never submitted
or published, exact revision; draft and generation become tombstones,
`content.draft.import_rolled_back`), `reserveImportCleanup` (fencing token,
installation id, a 900 s lease that is a stand constant and never taken over),
`completeImportCleanup` and `releaseImportCleanup` (only with the reserving
token; release is refused once the original is gone). Query `getImportBinding`
returns the author's view without the token. After a rollback the next import
opens `generation + 1`; an old retry replays its stored result. The body of a
rolled-back draft is no Media reference, so its asset is left to the orphan
reconcile; a tombstone accepts no new Media binding.

Mobile. The receipt gains `generation`, the `rollbackPending`, `rolledBack`
and `cleanupReserved` states and the journaled rollback and cleanup intents;
keys of generation 2+ carry `:g<N>`. Cleanup runs intent → reservation →
deletion → completion; an unknown outcome keeps the intent and is repeated with
the same key (`finishCleanups` after a restart). The import no longer writes
over a newer server revision: the item fails with `revision_conflict`.

Tests: `test/integration/content_local_import_rollback.test.ts` and the shared
scenarios in `test/support/content_repository_scenarios.ts` (in-memory), the
Emulator group `import` (`test/emulator/content_local_import_rollback.test.ts`:
the same scenarios on Firestore plus rollback/submit, rollback/reservation and
reservation/reservation races and a D4 binding without generation fields).

## M1 stage 2: Page access and publication reliability (Emulator only)

Client evidence for the M1 checklist
([S1–S7](../../docs/verification/M1_LOCAL_CONTOUR_CHECKLIST.md)); no new
authority path, no runtime change on the backend.

- `stand-seed.mjs page-access` (test-only, `functions/test/stand/stand_page_access_fixture.ts`)
  withdraws and restores Page access only through the Identity owner services:
  `withdraw-publish <label> <pageId>` (`setCapabilities`: the owner keeps
  `manage_page` and loses `content.create|submit|publish`; it prints the saved
  set), `restore-publish <label> <pageId> <saved,set>`, `suspend <pageId>` and
  `reverify <pageId>` (`decidePage` by the stand staff), `status <label> <pageId>`.
  The terminal `revokeMembership` has no admissible fixture (no owner path adds a
  second member) and stays backend-only evidence.
- `stand verify` also checks that every owner membership is active with the
  seeded capabilities, so a withdrawal that was not restored fails the gate.
- The C3 and D3.1–D3.4 stand tests sever or lose the answer of `submit` and
  `publish` through `test/backend_local/support/content_fault_client.dart` and
  retry from a new controller over the same journal.
- `stand-d3-1-gate.mjs` then runs, each on its own fresh stand (the Session
  issue budget is 5 per Account in 15 minutes), the Page access tests
  (controller and UI, Event and Place) and the two-installation conflict test.

Mobile fixes found by these tests: publish journals its exact payload before
the call so a retry after a lost answer replays it (no `idempotency_conflict`),
and a body save never writes over a newer revision of another install by
itself: the client reports `revision_conflict` and saves over it only on the
user's explicit "Save my version".

## Sequential Emulator test groups (2026-10-11)

From `apps/backend/functions`, `npm run test:emulator` builds once before
starting the Emulator and executes every group in the original order. Use
`npm run test:emulator:<group>` for an isolated named group. All use the same
local `demo-recharge` configuration; groups never run in parallel.

The baseline is the complete 210-test suite on `b1e678a`, measured through
a temporary direct-Node harness in the original order with the build completed
before the live run. The archived Node distribution's incomplete npm prevented
the unmodified command from reaching tests; that attempt is not passing evidence.
All 40 original Node invocations (including the final three globs) are retained.

| Group | Measured baseline | Timeout |
|---|---:|---:|
| `platform` | 10.7 s | 120 s |
| `booking` | 105.9 s | 240 s |
| `content-media` | 158.5 s | 330 s |
| `handoff-notifications` | 233.8 s | 450 s |
| `place-activity` | 148.2 s | 300 s |
| `collection` (D3.4) | 192.2 s | 390 s |
| `import` (D4.1) | 54.2 s | 150 s |
| `rules-reference` | 6.7 s | 120 s |

The `rental` group (D3.3) is bounded the same way (88.2 s, 210 s); see
`scripts/run-emulator-test-groups.mjs`.

Each limit is rounded up to 30 s from `1.75 × measured duration + 30 s`, with
a 120 s floor. The outer full-run limit is 2550 s: the sum of group limits plus
180 s for startup and 60 s for shutdown. These are local hang bounds, not an SLO.
A group's deadline includes all of its invocations; timeout or any nonzero exit
makes the full run fail. Later groups still report their results sequentially.
The Booking load-evidence mode retains its separate 900 s bound.

The runner prints a unique directory under the OS temp directory. It preserves
`emulator.log`, one log per group, and `summary.json` with durations, TAP counts,
invocation exit codes and timeout/not-run status. Inner scripts never rebuild
artifacts. `npm run test:emulator:runner` tests the original sequence, explicit
selection, failure aggregation, separate logs and termination of a hung child.

Rollback: restore `scripts/run-emulator-tests.mjs`,
`functions/package.json` and this README from `b1e678a`, and remove
`scripts/run-emulator-test-groups.mjs` and its test. Keep the evidence logs.

### D3.8 standalone Activity Catalog (local Emulator only)

`RECHARGE_TEST_ACTIVITY_CATALOG=true` enables the backend Activity projection/query family. Mobile requires `--dart-define=RECHARGE_TEST_DISCOVER_CATALOG=true` and `--dart-define=RECHARGE_TEST_ACTIVITY_CATALOG=true` plus existing testBackend/non-release/loopback guards. Both Activity switches default off. `node scripts/build-taxonomy-dataset.mjs --check` verifies canonical artifact, bundled mirror and manifest; `node scripts/stand-d3-8-gate.mjs --yes` builds before starting the verified demo stand, resets only its owned data, tests real mobile Feed/Search/Map/Details and stops it. Use the existing pinned Node/Java/Flutter toolchain. The stand gate is a Windows host test, not device or production evidence. No dynamic criteria or dedicated duration/bestTime facets in this first projection. Rollback: disable both Activity switches. Re-enable with reconcile/rebuild and atomic activation if an earlier set recorded `type_disabled`.
