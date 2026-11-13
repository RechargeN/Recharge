# I2 — Scenario persistence and collaboration

Date: 2026-10-18. Status: **Done — bounded local/Emulator scope**. Owner accepted
the declared local/Emulator scope on 2026-10-19; integrated as `51d3f29` on
`codex/recharge-integration` and verified there on the exact toolchain. Evidence:
`docs/verification/SCENARIO_I2_VERIFICATION.md`.
Task authorization covers bounded local/Emulator implementation, not deployment.

Hardening update 2026-10-18 (verified on the final snapshot): ordinary Create save
uses a payload fingerprint, so competing edits of one revision have distinct
intents and receive revision conflicts. Shared save restores the known
generation or obtains current server access before enqueue; it never guesses
generation zero for an existing Scenario. Temporary authentication/flag failures
retain the immutable queue. Historical receipts do not replace newer cache data.

The encrypted journal is limited to 2 MiB per account/installation. Only
re-fetchable cache can be evicted; pending payloads, rejected edits and intent
receipts are preserved. Capacity exhaustion fails before dispatch. A successful
Expand replaces its full local command with a compact receipt carrying the
original command hash and source binding; replay uses the same Expand command
and rechecks target/source authority. A missing receipt never rematerializes
the conversion. Unknown outcomes retain the full pending command until an
acknowledgement is durably stored. Rejected intents require a new explicit intent.

Scenario list queries paginate owner and member records independently in
stable document-ID order. Every page rechecks the server session and each shared
membership; caller-supplied cursors do not grant authority. Conditional saves
validate unique child IDs, finite coordinates and day/item/location/leg references.
Persistence accepts the canonical 30-day/250-item capacity. Locations and legs
have a 500-record resource ceiling each; the complete draft is bounded to 240 KiB,
leaving envelope headroom below the existing 256 KiB callable response budget.
These are persistence resource limits, not publication-readiness validation.
The real Flutter adapter saves and reads 200 scheduled plus 50 unscheduled items;
oversized requests fail before any write.

R0 CI reuses the integration's pinned Flutter 3.44.9 setup (the locked
`subosito/flutter-action`) and executes I1/I2/Library Flutter adapters without
skips; I2's separate SDK checkout was dropped during integration. The job
timeout covers the complete bounded Emulator suite plus prerequisite gates. The
workflow is prepared locally; its first hosted Linux/Windows run remains external evidence.

## Verified starting point

- Initial worktree: `721e/Recharge`, detached `06dae49`, initially clean and
  without backend/I1. After explicit continuation, the isolated checkout was
  moved to I1 `f32b97f`; the I2 specification was preserved. No commit or merge.
- Accepted product contract: `SCENARIO_BUILDER_SPEC.md` v1.7. Scenario, Quick
  Plan and Route remain separate aggregates.
- Git contains I1 commit `f32b97f`, parent `bde8b79`. Its server module is
  `apps/backend/functions/src/modules/quick_plan/firestore_quick_plan_service.ts`.
  It implements owner-only commands/queries, not invited authority or Scenario
  creation. Its verification report records two Flutter clients against Emulator;
  this session has not reproduced that evidence.
- Existing Expand: `PlanningConversionFacade.expand` →
  `QuickPlanConversionCoordinator.expand` → `ExpandQuickPlanToScenarioUseCase`;
  `ScenarioConversionHandoffStore` transfers the draft into existing Create
  runtime. Draft persistence uses `CreateController.saveDraft` and
  `CreateRepositoryImpl.saveDraft`. The handoff is memory-only and current
  conversion allocates new IDs on each invocation.
- I1's backend tree contains no Scenario/Planning command implementation.
  `CreateScenario` in BCK-10 is a specified command, not executable code.

## Authority and permissions

Server-verified current session identifies the actor; client IDs, role fields,
email assertions and possession of plan/invite IDs confer no authority.

| Actor | Permissions |
|---|---|
| Owner | Read, edit, delete own Scenario; invite editor/viewer; change participant role; cancel invite; revoke membership |
| Editor | Read and edit Scenario content; no delete, invites, role changes, ownership transfer or publication |
| Viewer | Read Scenario content only |
| Pending invitee / stranger / expired session | No Scenario content access |

Owner identity is immutable in this slice. Unlisted access and publication are
disabled. Quick Plan keeps its own authority model; I1 sources may be expanded only by their server-verified owner. The owner-accepted
I1 invited viewer amendment grants read and Leave, not copy/Expand authority. Scenario membership never grants Quick Plan access.

Invites bind immutable recipient user ID to a server-confirmed recipient
identity. Unknown/unconfirmed recipient fails closed; no email-only bearer link.
States: pending → accepted, cancelled or expired. Accepted/cancelled/expired
are terminal. Only the bound current recipient may accept a pending invite
before server-time expiry, using the stored role. Caller-supplied role is
rejected. Pending invite conveys no content access. Owner cancellation/revoke
invalidates pending invites for that recipient; a later re-invitation uses a
new invite ID and membership generation.

## Transactions, concurrency and revoke

Every content read and mutation checks current session and current membership
inside a server transaction. Replay performs these checks before returning a
historical receipt, including a receipt containing content or identifiers.
Revoke and access transactions read/write the same membership generation;
transaction conflicts force retry and fresh authorization. A read authorized
before revoke may have its response delivered later; the guarantee concerns
operations serialized after revoke commit, not recall of an in-flight response.

After revoke commit, newly authorized reads, writes, replay and queued commands
from the removed member fail without content or domain effects. Commands bind
the membership generation under which they were queued, so re-invitation never
revives an old queue. Role downgrade also advances generation. Session expiry
rejects replay. Owner operations recheck current owner authority too.

Content updates use expected revision compare-and-set: the first transaction
wins, the second returns a conflict without overwriting or automatic merge.
Both delivery orders retain the rejected client's pending payload for explicit
review. Membership changes use a separate expected membership revision;
accept/cancel/revoke races serialize on the same records. Accept then revoke
ends revoked; revoke then accept rejects. Repeated accept by the bound recipient
is idempotent only while its resulting membership generation remains active.
No stale accept receipt reactivates membership.

Encrypted local state is scoped by account and Scenario. Persist immutable
command intent before dispatch; isolate queue/cache on account changes and
discard stale in-flight results. On revoke notification or authoritative denial,
close visible shared content immediately, invalidate cached content and stop
dispatching that generation's queue. Never reinterpret a rejected shared command
as an owner create. Already delivered data cannot be reliably recalled from an
offline device; disconnected clients cannot promise immediate cache removal.

## Expand and the single creation path

Reuse the existing conversion facade/use case and canonical Create save path.
Its authoritative owner creation implementation must be shared by ordinary
Scenario creation and Expand; no conversion-specific direct Scenario writer.
A runtime spy/integration test must demonstrate that shared command invocation.

Before dispatch, durably record one expansion intent: actor, source ID,
expected committed Quick Plan revision, selected ordered stop IDs, explicit
note consent, title, new target ULID and all mutable child ULIDs. Hash the
immutable command; changed arguments under the same intent reject. Conversion
uses exactly the server-committed expected source revision, never an unsynced
local edit or silently refreshed snapshot. A mismatch returns conflict and
requires user refresh and a new explicit intent.

Server checks source read+copy authority on every attempt, including replay.
Create and result receipt should commit atomically through the shared owner
creation command. If composition requires two transactions, the creation command
must itself durably bind the same intent/hash/target; recovery queries/replays
that command and completes the expansion receipt. A new target is never allocated
to recover a missing response or a crash between creation and result recording.
Source revision and access must be validated in the creation transaction, so a
concurrent source edit either serializes after the snapshot or causes conflict.

One intent and restart/retries return one target. A new explicit conversion uses
a new intent and independent ULID. Days/items/locations/legs and other mutable
children receive new IDs; catalog references may remain shared immutable IDs.
Do not copy invitations, grants, participant identities or others' private notes.
Provenance is an inert snapshot only. Source and target edits/deletes are
independent. No Route fields, live links, Catalog writes or publication effects.

## Required evidence before Done

1. Owner/editor/viewer/stranger/wrong recipient/role injection/expired session.
2. Duplicate accept; cancelled/expired invite; accept/revoke both orders;
   concurrent membership revisions; re-invite cannot revive old commands.
3. Revoke racing read/write/replay/offline dispatch, proving transaction order
   and absence of post-revoke effects and disclosures.
4. Two real Flutter clients editing one revision in both delivery orders;
   durable conflict payload and no silent loss.
5. Allowlisted public responses; no foreign content, invites, authority fields
   or unnecessary participant data, including error and replay responses.
6. Lost Expand response, client restart and injected crash after creation
   before result recording: same intent reaches the same target exactly once.
7. Source edit racing Expand: pinned snapshot or explicit conflict, no source
   mutation; independent edits/deletes after conversion.
8. Runtime assertion of canonical creation invocation; static boundary check
   excludes second writer, Route fields and publication effects.
9. Two actual Flutter adapters against Emulator: invitation, shared read/edit,
   revoke and Expand. In-memory tests alone do not satisfy this requirement.
10. Changed launcher self-tests; cleanup every owned fixture collection; full
    Emulator suite in one session; affected backend gates; full Flutter analyze
    and test; boundary and diff checks. Record exact failures/skips/timeouts.

## File plan, rollback and unresolved dependencies

Implementation extends existing Quick Plan authority,
the existing Create repository/command and conversion facade/use case, and
existing session/callable transport and encrypted journal mechanisms. Add only
Scenario persistence/membership records and their bounded tests to the established
backend modules and Emulator runner. Register explicit client-deny collections
and default-off slice flags in the existing execution manifest. The server implementation is `modules/quick_plan/firestore_scenario_service.ts`;
`CreateRepositoryImpl` accepts the existing conditional-save port implemented by
`ScenarioSyncClient`. Ordinary Scenario save and Expand invoke the same server
`saveInTransaction` command. Expand materializes through the existing facade,
coordinator and use case; no second converter. The Emulator-only composition
uses the existing session transport, with an exact-path exception for product
capability booleans rather than client authority claims.

Rollback disables new sync/collaboration/Expand dispatch, closes shared cache,
preserves owner journals, intent receipts, terminal invite states and revoked
membership generations. No automatic import/upload or deletion on rollback.

## Execution boundary and evidence

Baseline dependency resolved locally at `f32b97f`. Default-off Emulator entry
`RECHARGE_TEST_SCENARIO_I2` is separate from production; no cloud activation,
provider integration, publication, Route fields, migrations or automatic upload.
I1 Quick Plan invited viewer authority now exists in the accepted local amendment;
source expansion remains owner-only, because invited read is not copy authority.
Scenario collaboration supports owner/editor/viewer through current server
Identity sessions. The recipient is an existing active server account and accept
must use that account's current authenticated session; no email bearer invite.

Creation and its result receipt are atomic in one Firestore transaction. There
is no committed gap between creating Scenario and recording the result. A
fault injected after staging creation but before receipt must roll back both;
the same durable intent then retries. A lost response after commit replays the
same receipt. Private source provenance is owner-only in shared responses.

Changed launchers: the existing group registry and outer callable allowlist;
I2 is a serial group in the full suite. Existing runner self-tests preserve the
original invocation ordering. Evidence, the initial failed runs and open items
are recorded in `docs/verification/SCENARIO_I2_VERIFICATION.md`.


## Task 27 — common I1/I2 revalidation (2026-10-20)

Authorized by the owner to finalize I2 after I1 on the same runtime. Preserve the
single existing `saveInTransaction` writer; no backend creation writer or converter
change is needed. Detailed current evidence is in
`docs/verification/SCENARIO_I2_COMMON_I1_VERIFICATION.md`.

Expand permission is resource-specific: a Scenario owner/editor/viewer may expand
an independently owned Quick Plan into a NEW owned Scenario. None of these Scenario
roles grants read/copy authority on somebody else's Quick Plan. I1 invited viewer,
pending invitee, revoked invitee and stranger cannot Expand that source. An invited
viewer is not a new Quick Plan editor/copier. Existing targets cannot be overwritten
by Expand. Source revision/hash, immutable intent/receipt binding, independent target
ULID/child IDs, no live relation and no implicit publication remain unchanged.

Client hardening adds post-journal-write visibility/revoke checks, so an authorized
HTTP result received before revoke is not returned to its caller after that client
has received revoke while persisting the result. Queued operations capture initiating
actor/visibility epoch; Expand cannot materialize old-account content as a new actor.
Account checks also cover materialization and journal IO. These checks complement
server transaction ordering and existing generation fencing; they are not new authority.

An authoritative revoke event immediately hides the client's shared cache/conflicts
and prevents late results from making it visible again. Newly authorized reads,
writes and replays serialized after server revoke commit fail. A response authorized
before revoke can arrive later. Already delivered offline data cannot be remotely
erased or reliably recalled; an offline client cannot promise instant notification
or physical deletion. Re-invite requires fresh online access/new generation; old
queued commands and receipts remain fenced.

Scenario edit/delete retains the accepted revision CAS (not I1's Quick Plan delete-
wins semantics): an edit winning first conflicts a stale delete; a fresh owner delete
can follow. Once deleted, subsequent shared edits and historical command replay cannot
resurrect the Scenario. Local visibility closure and durable journal retention are
verified separately from physical device/process-death evidence.

File plan: existing ScenarioSyncClient, existing backend and real Flutter I2 tests,
one new deterministic revoke/persist regression test; I2 contract/evidence/status
updates only. No I1 runtime changes, new aggregates, Route fields, CI activation or
production/deployment authorization. Rollback preserves journals/receipts/generations
and disables the existing default-off Scenario composition.
