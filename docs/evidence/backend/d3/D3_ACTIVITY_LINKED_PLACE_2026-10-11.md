# D3.9 Activity linked Place — verified local bounded slice

Date: 2026-10-11. Implementation status: **Review**. Recommendation: accept only this bounded local/Emulator slice. The owner approved policy A and the file plan; finished implementation acceptance remains with the owner. No commit, push, merge, cloud or production action was performed.

## Exact checked revision

Worktree: C:/Users/User/.claude/worktrees/recharge-d3-2; detached HEAD `b1e678a23a4db584e496a9d44593fbcf86c45dc0` plus working-tree source fingerprint `a10b8df9a266a68a4fd7b7759cfb47a4d3620fac0eeea0dee1357af1f2eb8b04`. The [source manifest](D3_ACTIVITY_LINKED_PLACE_SOURCE_2026-10-11.json) records 123 source files and 44 D3.9 incremental changes. Source normalization and fingerprint algorithm are explicit in the manifest. Evidence files are excluded to avoid self-reference. Earlier WIP is retained; HEAD alone is not the verified implementation.

Accepted D3.8 input: `51a55dd34b12027e15f1ec22de76d85bf94da05d629d7eb750e09e18e8e2e0ce` at the same HEAD. All 100 baseline source files were rehashed before D3.9 work and showed no drift. Approval: owner selected “A — Activity видима, связь скрыта; подтверждаю bounded lookup/picker и план”. This does not accept D3.1/D3.2 or authorize production.

## Result and acceptance evidence

| Requirement | Implementation | Evidence |
|---|---|---|
| Current eligible published Place | One Catalog-owned PlaceLinkService over the existing ContentPublicationFeed; exact pointer/current immutable revision/type/market/public policy/body integrity; pointer re-read fences a torn lookup | place_link unit, Content/Catalog integration and real Emulator/stand |
| submit/publish/activate target validation | Consumer port returns safe status only; checks fresh exact submitted/published/immutable target body; existing activation validation preserved | Existing old/superseded/hidden revision negatives plus D3.9 integration; missing Catalog port explicitly refuses all three stages with unchanged pointer/revisions/effects |
| Unknown/unpublished/private/unlisted/hidden/restricted/wrong type or market/outage | Explicit unknown/forbidden/unavailable; stable violation code and /body/location/linkedPlaceId; no internal values/reasons | Unit negative cases, safe JSON schema contract, integration, live hidden/restricted Place |
| Policy A after hide/restrict/restore | Activity retains own point/access notes; public DTO omits raw internal link ID and unavailable relation; fresh eligible source restores relation without Activity writes | Existing snapshot plus new Details/Feed checks; rebuild/activation/rollback; real stand restrict/restore and Activate refusal |
| Existing form and lifecycle | Existing Activity location step, controller and repository; bounded search/select/current resolve/explicit clear; guarded existing Catalog gateway; existing publication controller/gateway/journal | Widget picker select/clear retains draft fields; stale-response/dispose/controller and wire failure tests; real Catalog picker → save/media/submit/review/publish/hide/Activate |
| Flags/absence/compatibility | Backend and mobile linked Place default off; previous Emulator deny retained; missing DI is unavailable, no mock authority; mapper transmits only explicit enabled ID | Existing default-deny Emulator negatives, mapper on/off, missing dependency negatives, full mobile regression |

The relation stores only the Content draft/source ID. Catalog owns eligibility and public title/revision; no Place visibility authority or parallel Place directory is copied into Content. Old drafts and immutable revisions are not rewritten. The bounded source scan returns one owner cursor page (at most 50 pointers; mobile requests 20); an empty candidate page is not an unknown exact ID.

## Completed gates

| Gate | Result / duration | Log |
|---|---|---|
| Backend build | PASS; completed before every live run, final test-only build after shutdown | runner/stand logs |
| Affected Content/Catalog unit + contracts + Activity integration | **501/501**, 1.645 s final | recharge-d3-9-backend-final.log |
| Full backend ESLint + later changed tests | PASS, 0 errors/warnings | recharge-d3-9-lint-final.log; recharge-d3-9-lint-additional.log |
| Content/Media Emulator | **65/65**, 13 invocations, **193.089 s**, timeout **330 s** | recharge-emulator-tests-wCWnH7-summary.json and content-media.log |
| Place/Activity Emulator | **29/29**, 5 invocations, **168.976 s**, timeout **300 s** | recharge-emulator-tests-YEWzjr-summary.json and place-activity.log |
| Full Flutter suite | **1432 passed / 32 skipped**, **3:34** | recharge-d3-9-mobile-full-2.log |
| Focused existing form/mapper/feedback | **47/47**, 4 s; picker controller additionally covered by full suite | recharge-d3-9-mobile-focused-2.log |
| Full flutter analyze | **0 issues**, 8.6 s | recharge-d3-9-flutter-analyze-final.log |
| Boundary | **0 violations**, 71 existing suppressed findings, no stale/expired exceptions | recharge-d3-9-boundary.log |
| git diff --check | PASS, exit 0 with repository CRLF normalization | recharge-d3-9-diff.log |
| Real D3.9 stand | **1/1**, **98 s** including 25 s setup; scenario timeout **180 s**, command bound **240 s**; seed verified, owned stand stopped | recharge-d3-9-stand.log; runId a7362c1d-b61a-4e66-b354-da1797fd9bd9 |

Logs are under d3-9-logs; [hash/size index](D3_ACTIVITY_LINKED_PLACE_LOGS_2026-10-11.json) identifies them. Ignored .log files are retained locally. Full-suite skipped stand tests are separately exercised by the enabled real D3.9 gate. This is PC-host local Emulator evidence, not device or production evidence.

The initial Content/Media attempt selected system Node for the Functions child and failed ERR_REQUIRE_ESM; repeat used Node 22.23.2 in PATH. Early new test assertions expected the wrong wire refusal kind and incorrectly expected a superseded projection-set snapshot to remain valid. Those diagnostic attempts are retained and are not green evidence. Final gate asserts snapshot_superseded, then checks the relation against fresh snapshots and after rollback. The first full Flutter run exposed missing picker DI in CreatePage tests; fixed to explicit unavailable and repeated full suite. Later changes after live success were erased test type assertions/extra missing-port tests, formatting and the stand success banner; final unit/build/lint/syntax checks cover them. The historical stand log retains its old D3.8 banner, while the executed test name and 1/1 result identify the D3.9 scenario. No live runtime rebuild occurred.

## Mandatory versus unrepeated gates

Content shared submit/publish/activate and Catalog public reads/source changed: affected Content/Catalog tests, both Content/Media and Place/Activity Emulator groups, contract validation, full mobile analyzer/tests, boundary/diff and live stand were mandatory and passed. Existing Event/Catalog, immutable publication/recovery, revision conflicts and D2 regressions are included in these groups. D3.9 fresh relation filtering is independent of stored projection eligibility/title, so replay cannot restore old Place authority; existing replay tests remain green, and the linked scenario separately checks old snapshots/rebuild/rollback.

Booking ledger/admission, Identity/Session contracts, Firestore/Storage rules and reference-data persistence/dataset did not change. Platform, Booking, handoff-notifications and rules-reference Emulator groups and unrelated stand gates are not repeated. No claim is made that all 41 Emulator invocations ran in this pass. No full Place Catalog family, taxonomy integration change, dynamic criteria or mobile lifecycle redesign was added.

## Remaining debt and rollback

- Eligibility is a current owner-source read, not a distributed atomic lease across Place and Activity. Changes after that read are reflected on the next public read; stronger guarantees require a separate owner contract.
- Full Place Discover/Details remains outside the accepted relation-only capability. Picker pages can contain no eligible match and still have a continuation cursor.
- D3.8 debt remains: public dynamic-criteria allowlist, dedicated duration/best-time filters, BCK-22 informal-access threshold, remaining Catalog families/limits, explicit legacy draft/revision workflows and production BCK-20 delivery.
- D3.1/D3.2 publication acceptance, device/Linux/cloud/production gates remain separate. This pass does not close them.

Rollback: set backend RECHARGE_TEST_ACTIVITY_LINKED_PLACE=false and omit/disable the mobile dart-define. New linked commands use the previous deny; public Activity remains available while its relation is omitted. Keep drafts/revisions unchanged. Existing Activity/Discover flags and guarded testBackend/non-release/loopback entry remain required for their respective surfaces.

The exact changed-file list is in the source manifest. Main changes are the Catalog evaluator/source/query/projection, Content consumer validation and safe error allowlist, existing DI/mapper/Create picker/Details renderer, additive public schema, focused tests and the existing stand runner option.

## Finalization audit — 2026-10-12

At the owner's request to complete the necessary work, the final state was refreshed read-only. HEAD remains b1e678a23a4db584e496a9d44593fbcf86c45dc0; all 123 source hashes match fingerprint a10b8df9a266a68a4fd7b7759cfb47a4d3620fac0eeea0dee1357af1f2eb8b04. The complete current changed/untracked source path set matches the manifest: no added or missing source files. All 30 retained log/index entries match their recorded byte sizes and SHA256 hashes. git diff --check returned 0. The owned local stand remains stopped.

No source changes, missing evidence or newly affected mechanisms were found, so the previously completed gates were not repeated. No required implementation work remains inside the approved bounded D3.9 scope. Recommendation remains acceptance of this exact local/Emulator revision; implementation status remains Review until an explicit owner acceptance. Remaining debt above requires its own scope/decisions and is not silently added to D3.9. This evidence-only finalization does not alter the source fingerprint or authorize commit/merge/production.
