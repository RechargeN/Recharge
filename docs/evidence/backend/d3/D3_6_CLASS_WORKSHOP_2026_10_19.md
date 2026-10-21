# T2 / D3.6 Class / Workshop — local evidence, 2026-10-19

Status: Review; bounded local implementation and the required gates listed
below passed. PC-host Emulator evidence only. Locally committed; no push, merge,
deployment or production enablement.

## Provenance and prerequisites

- Worktree: `C:/Users/User/.claude/worktrees/recharge-t2-class-docs`.
- Base: `0b131ab` (equal to `codex/recharge-integration` when the slice started).
- Local branch: `claude/t2-class-workshop`, no upstream.
- Implementation commits: `f083d7c` (docs, 6 files), `ef1356c` (backend, 24),
  `0f80e12` (mobile, 28), `32cc0d3` (stand/evidence, 14): 72 files total.
  This documentation follow-up records the completed local commit checkpoint.
- Entry gate (2026-10-19): stopped after read-only check — no owner decision,
  no accepted backend contract, no accepted typed Create contract.
- Owner decisions: [D3.6 §1](../../../product/D3_6_CLASS_WORKSHOP_PUBLICATION_AMENDMENT.md)
  — explicit chat answer accepting CLS-OD-01…10 (option A and the proposed OD
  values); then «все принимаю, реалищзовывай», accepting the D3.6 §6 file plan
  and Event Classification 2.2.4 (D3.6 §1.1).
- Type contract: [Class/Workshop v1.2 §2.6, §34 CW-V1](../../../product/create/CLASS_WORKSHOP_EXPERIENCE_CREATE_SPEC.md)
  Approved slice spec; full product §1–§33 stay Ready for approval.
- Boundary with Event: [Event Classification 2.2.4](../../../product/EVENT_CLASSIFICATION_SPEC.md)
  §1.1, §1.2, §6.2 (owner-accepted); archetypes and invariants unchanged.
- Parent [BCK-07 v0.16 §47](../../../product/CONTENT_PUBLICATION_BACKEND_SPEC.md)
  and D3.6 stay Review; they confer no production authority.
- Canonical type: `class_workshop` (wire/Content/deep link) =
  `CreateObjectType.classWorkshop` = Category System `classWorkshop`; no second
  aggregate for the Event archetypes `workshop`/`class_session`.

## Reproduction

Pinned Node 22.23.2 and Temurin 21 (`JAVA_HOME/bin` first on PATH), Flutter
SDK. From `apps/backend`, with `RECHARGE_DART`, `RECHARGE_FLUTTER_TOOL` and
`RECHARGE_G_MOBILE=1` set as in the D3.5 evidence:

```text
node --test scripts/stand-d3-6-gate.test.mjs scripts/stand-d3-5-gate.test.mjs scripts/run-emulator-test-groups.test.mjs
node scripts/run-emulator-tests.mjs --group class-workshop
node scripts/run-emulator-tests.mjs
node scripts/stand-d3-6-gate.mjs --yes
```

Run the Emulator suite and the stand gate sequentially (same ports). The stand
resets only its own root `<OS temp>/recharge-t2-stand-<sha256(repoRoot)[0:16]>`
and never another worktree's stand. From `apps/backend/functions`: eslint,
`tsc`, `node --test --experimental-test-isolation=none` over unit, integration
and contract tests, prettier `format:check`, the verify scripts below. From
`apps/mobile`: `flutter analyze --no-pub`, `flutter test --no-pub`. From the
repository root: boundary gate and `git diff --check`; `packages/api_contracts`:
`dart analyze`, `dart test`.

## Original implementation gate ledger

| Gate | Result |
|---|---|
| Backend lint (eslint src test) | PASS, exit 0 |
| TypeScript build/typecheck | PASS |
| Prettier format:check | PASS (all matched files) |
| Backend unit/integration/contract | PASS: 1078 passed, 0 failed/skipped/cancelled |
| Changed runner self-tests | PASS: 12 (D3.6 gate 3, D3.5 gate 3, group runner 6), incl. failure cleanup |
| R1 layout/config/exports, content-persistence layout, execution manifest, reference-data layout, taxonomy, cloud context | PASS |
| API contracts | PASS: analyzer clean, 25 tests |
| Focused Class Emulator group | PASS: 7/7 (callable 2, flow 5) |
| Full shared Emulator, one session | PASS: 16/16 groups, 314 tests, 0 failed/skipped; `summary.json` complete=true, code=0; outer exit 0; logs `C:/Users/User/AppData/Local/Temp/recharge-emulator-tests-ny4USn` |
| Boundary | PASS: 0 violations, 71 existing suppressions, 0 stale/expired |
| Flutter analyze | PASS: no issues |
| Full Flutter test | PASS: 1689 passed, 0 failed, 73 env-dependent skips (incl. the two Class stand tests, run in the stand gate) |
| Stand gate (frozen set) | PASS: clean = interrupted-after-bind/resumed = repeated digests; real controller 1/1 and UI (Create block + publication page) 1/1; base/Class invariants; verified stop and reset of its own root |
| Diff check / doc links | PASS: `git diff --check` (new files as intent-to-add), 0 broken relative links |

Changed source/test/fixture set at the full Emulator session: 62 files, SHA-256
over sorted path + NUL + bytes + NUL
`61c53b280a59164ec40856295c5f41d6caab09905d6158828b142ff9cd8dc082` (equal before
and after the session). The full Flutter run then exposed two existing
`create_page_test` cases that used Class as the generic form; the Class block
now shows the shared cover error on its cover field and those two tests assert
the same behaviour on the Class path (no assertion removed in substance). Final
frozen set: 63 files,
`3b587acd18c70ca2551116402655e3358857885a4715c37901d2326a5ceba718`; analyze, full
Flutter test and the stand gate ran on it and it was unchanged at close. Backend
files did not change after the Emulator session. Docs, README and logs excluded.

## Lifecycle and refusal matrix

| Path | Exercised invariant / source |
|---|---|
| flag absent/off/other environment, page publisher, unknown type | HTTP callable: `type_disabled` or refusal before any write; the Class flag opens only Class; other type flags unchanged (callable test, integration) |
| draft → update → media | real owner commands, server author, ready cover + two gallery photos through C1 Media (flow) |
| submit → review → publish | publication before C2 approval refused; immutable body equals the bound body; three media attachments (flow) |
| owner hide → activate | withdrawn, stale CAS `revision_conflict`, activate with expected pointer; revision untouched (flow, integration) |
| moderation restrict → restore | C2 decision and `restoresDecisionId`; pointer restricted → visible (flow) |
| new authored revision → rollback | v2 published, rollback activates v1 immutable body under CAS; no new revision, no duplicate draft (flow, integration) |
| lost responses | lost submit/publish/activate answers replay the stored result; lost mobile create/update resume with one draft (integration, mobile controller) |
| three-path refusal | the same body refused on submit, publish of the earlier approved submission and activate of the immutable revision, with the full in-memory snapshot (drafts, submissions, revisions, pointers, audit, effects) unchanged: (a) newly required criterion; (b) all classes passed (integration) |
| time rules | submit/publish need all classes ahead; activate accepts a series with one class left (integration, unit) |
| DST / timezone | Europe/Riga 2027-03-28 gap refused; 2027-10-31 overlap needs fold; unexpected fold refused; UTC mismatch refused; 24:00 end; 60 vs 61 classes (fixture, unit, mobile mapper) |
| unknown / legacy / claims | unknown top-level/nested, `eventSlots`, `spotsLeft`, `verified`, `capacity`, `confirmed`, `hold`, `availability`, `archetype` refused; never trimmed (fixture, flow, integration, mobile) |
| mobile → backend | real mapper output equals `valid`, `valid_full_series_price`, `valid_dst_overlap_fold` byte for byte; persistence mirror lossless; newer schema read-only |
| privacy | Collection exact-ID evaluator returns allowlisted facts only; area-only address, coordinates, rights flag, enrollment URL, author absent; hidden → `withheld`, unknown id → `unknown` (flow) |
| Discover / Booking | Discover refuses `type_disabled:class_workshop`; Catalog versions excluded/type_disabled; Booking handoff receipts `ignored` with empty outbox, no Booking state (flow, stand verify) |
| real mobile | controller against the stand 1/1; UI: the user completes the draft in the config-driven Create block (real CreateController and repository), then publishes from the guarded page 1/1 |
| regression | other Create types keep their enablement (integration, callable); all 15 earlier Emulator groups pass in the same session |

## Cleanup and isolation

Class worlds reuse the D3.5 world: only UUID-bound fixtures, owned source and
variant objects and Auth fixtures are removed after two quiet passes; shared
Catalog/handoff/notification checkpoints are retained and asserted to survive;
test flag documents are restored. Its log line reads "Session fixture
cleanup" because the shared world prints it: Class callable world 160 and flow
world 505 owned documents. The stand gate verified stop and reset only its
isolated root; Emulator ports were free afterwards.

## Original implementation remaining limits

Default off and Emulator only; personal publisher; external enrollment link or
information-only; no inventory, holds, Booking, waitlist, Payments, providers,
Catalog/Discover, multi-cohort, recurrence, on-demand, materials add-ons,
waivers, structured age, learning resources or certificates. Mobile follows Q4:
no Activate and no edit after publication. Numeric pin entry; no map picker,
templates or l10n. Modules and take-home result are stored but not shown by
DTL-CLS-01 v0.2. Scanner/processor are stand fakes; staff grants test-only.
Rights confirmation is a declaration, not legal proof. No device, Linux,
staging or production claim.

## Contract-alignment closeout — 2026-10-19

The original implementation gates above are historical. At owner request, the
remaining schema refusal mismatch is corrected in C3 without changing CW-V1:
submit, approved publish and immutable activate map the source validator issue
`class_workshop.schema_unsupported` to `content_type_unsupported` (§34.5).
One integration regression test seeds unsupported persisted data separately for
each path, verifies the public refusal code and compares the complete stored
snapshot before and after refusal. Other source issues keep their existing
`validation_failed` behavior. No new engine, flag or type is introduced.

D3.6 and BCK-07 now distinguish the initial docs-only checkpoint from subsequent
owner acceptance and implementation. LAUNCH_STATUS separates completed bounded
local scope from production/product extensions outside T2. Review remains
unchanged; no new commit, push, merge or deploy is performed for this correction.

During closeout, the first focused build found a missing CAS argument in the new
test. That build failed; tests subsequently printed from stale `lib/` are not
accepted as evidence. The test was corrected and rebuilt before the 9/9 focused
integration pass, including the new three-path schema test.

The first full repeat used bundled Node 24.19.0 inadvertently and lacked Windows
PowerShell in PATH. All 16 groups returned code 0 and inner summary was complete,
but counters were zero under that runtime and outer cleanup exited 1. This run
is not accepted as the final gate. Logs:
`C:/Users/User/Documents/Codex/2026-10-19/new-chat/work/t2-final-gates/`;
inner logs: `C:/Users/User/AppData/Local/Temp/recharge-emulator-tests-gckZzK`.
The remaining owned Pub/Sub process was identified by binary, command line,
parent PID and creation time and stopped. Final gates are repeated with verified
Node 22.23.2, Temurin 21 and Windows PowerShell in PATH; their ledger follows.
The Node 22 repeat completed the full Emulator suite: 16/16 groups, 314 passed,
0 failed/skipped, complete=true, code=0, outer exit 0; logs:
`C:/Users/User/AppData/Local/Temp/recharge-emulator-tests-lrqFYB`.
That run used Temurin 21.0.12.1+1. Stand preflight subsequently refused that
system JDK before starting, because the stand pins exactly 21.0.12+8. The failed
preflight is preserved in `results-before-stand-retry.json`; no stand runtime
ran under it. The stand retry uses verified Temurin 21.0.12+8 from
`<OS temp>/recharge-stage1-temurin-21.0.12-8/jdk-21.0.12+8`.
The first stand runtime attempt completed clean/resumed/repeated but failed to
launch its Flutter child: the temporary closeout runner had lost Windows system
paths when merging `Path`/`PATH`. No Flutter result from that attempt is counted.
Verified stop and cleanup ran. Its log is preserved as
`stand-d3-6-flutter-launch-failed.log`, with exit history in
`results-before-flutter-launch-retry.json`. After fixing only the temporary
runner environment, the complete stand gate was repeated and passed, including
both real mobile tests. Repository source files did not change between attempts.

### Final accepted closeout ledger

All 21 final command stages exited 0. Machine-readable ledger and per-stage logs:
`C:/Users/User/Documents/Codex/2026-10-19/new-chat/work/t2-final-gates-node22/`.
`results.json` contains the accepted sequence; failed attempts remain in the
separate history files described above. Reproduction uses the original commands
with Node 22.23.2 and the exact stand JDK 21.0.12+8; PATH must include the Windows
system directory, Windows PowerShell, Flutter and the pinned runtime binaries.

| Gate | Final result |
|---|---|
| Backend lint, Prettier, build | PASS, exit 0 each |
| Backend unit/integration/contract | 1079 passed, 0 failed/skipped/cancelled |
| Class integration regression | 9/9, including future-schema three-path refusal with unchanged state |
| Runner self-tests | 12/12 |
| Eight backend layout/config/exports/manifest/reference/taxonomy/cloud-context checks | PASS |
| Full shared Emulator, one session | 16/16 groups, 314 passed, 0 failed/skipped; complete=true, code=0, outer exit 0 |
| D3.6 isolated stand | PASS: clean = interrupted/resumed = repeated; controller 1/1, config-driven UI 1/1, base/Class invariants, verified stop and cleanup |
| Flutter analyze | PASS, no issues |
| Full Flutter test | 1689 passed, 0 failed, 73 env-dependent skips; the two Class stand tests passed separately above |
| Boundary | 0 violations, 71/71 valid existing exceptions, 0 stale/expired |
| API contracts | analyzer clean, 25/25 tests |
| Diff and relative document links | PASS |

Final source/test/fixture set: 63 files; hash before the accepted sequence equals
the hash after it (same sorted path + NUL + bytes + NUL algorithm):
`ad56c7ee743beecc6b1d8b55f98d98363ef0e294749de435e68005dc0afa02cf`.
Source files remained unchanged during all final runtime gates. Documentation is
excluded from that hash and was finalized after the gates. Emulator fixtures
were cleaned by the group worlds; the stand verified stop and reset of its own
isolated root. Emulator ports were free after closure.

**Bounded T2 local/Emulator scope is complete.** No remaining implementation or
gate item is open within CW-V1. D3.6 and BCK-07 remain Review; this does not assert
owner acceptance of the whole parent or readiness of the full Class product.
The out-of-scope production/device/commerce/recurrence limits above remain.
The closeout changes two source/test files and four documents, uncommitted on
`claude/t2-class-workshop` at `bed7b05`; no new commit, push, merge or deploy.