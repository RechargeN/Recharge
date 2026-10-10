# PVR-01 / 07 — retirement and selective restore

STAGE: 07; RESULT: **ready** (bounded documentation/archive scope only).
DATE: 2026-10-10 (Europe/Moscow).
TARGET_ROOT: C:/Users/User/.codex/worktrees/7275/Recharge.
HEAD input: 8c69715bba03eb1cef7309d4496ebfddd6d11a1e.
HEAD output: 8a6c2dea336b2705bab3e1d4ffd5eb81708c9c25.
BRANCH input/output: codex/recharge-integration.

User explicitly dispatched stage 07. This authorizes its independent docs /
archive work despite the previous 06 handoff saying not to advance automatically.
**06 remains not_ready**; this report neither waives its blockers nor declares
PVR-01 Done. 08 was not started. No commit/push/merge/deploy/cloud by this agent, other agents
or cross-chat messages.

## Inputs and authority

Target root follows actual [00](00-baseline.md); all actual handoffs
[01](01-archive.md), [02](02-decision.md), [03](03-spec-migration.md),
[04](04-presentation-access.md), [05](05-unified-ui.md), [06](06-regression.md)
and report index exist and retain their recorded hashes. Prepared tasks are
not execution proof. Prior context, actual 06 result, transfer map/current
owners, master plan §§11/15 and archive MANIFEST/README/SYMBOLS/RESTORE were
checked. Target AGENTS v2026-10-10 and supplied user instructions applied;
`rg --files -g AGENTS.md -g '!node_modules' -g '!build' -g '!.dart_tool'`
found only root instructions.
[ADR 0021](../../adr/0021-unified-personal-profile.md) remains Accepted,
authorized by direct user acceptance of its concrete text and plan §6.1/§13.
SHA: 5CEEF9575528B71DE454952D5DB82D9073C9ADE3F81B549471FC0526E5B88184.

Prior report hashes, verified unchanged:
- `docs\verification\pvr-01\00-baseline.md`: `4759C8671AD6BE8BA91FAE5D1915B931EC0770E36933810894ACCCA0078262BE`
- `docs\verification\pvr-01\01-archive.md`: `665385299924F5BDC273812FE2C8AA0375DF477A0793152C568D1B924F1984F0`
- `docs\verification\pvr-01\02-decision.md`: `E2398DD24C2FC7964169078D460356C54ECB4DC4B09992AD7CA0B4BCAEA5BF57`
- `docs\verification\pvr-01\03-spec-migration.md`: `9D2F0E47B0E5FA584953A46AF96223EA98E5D9B67761775D2E3DA826D1953E00`
- `docs\verification\pvr-01\04-presentation-access.md`: `2FE5F84A9B77A8D837B4A28499DC176C020FD7896D4E8281BFEFFDA6DE63447D`
- `docs\verification\pvr-01\05-unified-ui.md`: `143D6F04F91D156207683D7024E3EB4A88D51420D46FFADA1A697EFBC0A05789`
- `docs\verification\pvr-01\06-regression.md`: `AE4672735212625DDEE23EA11EFF2B12763F3CD5C3A838EFE7E6CBA43C496E52`

## Own bounded delta

Nine documentation paths below, plus this report and append-only index entry.
- Viewer v1.17 / Public Viewer v1.0 originals replaced on old paths with short
  retired pointers v1.18/v1.1, exact archive raw links, current personal/public
  owner anchors and exhaustive migration map. Original bookmark paths remain.
- Retirement map v1.1 / profile index v2.0 identify completed retirement;
  full-release rules remain Draft and all Open decisions retain maturity.
- Creator/Public Creator current index pin changes only v1.9 → v2.0.
  Their entire remaining text is equal to entry copies. Professional Page /
  Public Page had no matching current index pin and were not edited.
- Archive README distinguishes stage01 history from current retirement;
  SYMBOLS records actual replacements/retained access helpers; RESTORE records
  verified selective drill, current owner anchors and rollback limits.

No Dart, tests, assets, dependencies, Accepted ADR, raw .txt or MANIFEST edit.
No routes/domain/access/data changes. In particular Scenario viewer/unlistedViewer
and PublicPageViewerContext are preserved. `profileRoleSummaryForPresentation`
has regression-test consumers; no unproven helper deletion. ProfileRoleTier.user
is an internal access input, not a separate personal composition.

| Changed path | Final SHA-256 |
|---|---|
| `docs/product/identity/VIEWER_PROFILE_FUNCTIONAL_SPEC.md` | `C9F0E700969E7D6E48F1D40FC8A924558B7FA4D631883FA6EEE77B077E719CF0` |
| `docs/product/identity/PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC.md` | `1FCAB2C270C07174A44287B59FE91D38CD41059D9A9EA963165CA6D6F1FF08E2` |
| `docs/product/identity/VIEWER_PROFILE_RETIREMENT_MAP.md` | `5D423F9E9FC5A2C6BC7418788495378AFEC0A58EBEC5F33ED65B1F7905B85262` |
| `docs/product/identity/PROFILE_DOCUMENTS_INDEX.md` | `FDB2F571D5D2B864DE90EA786BB9E3B0375A1F189B8E04B45FF9EE7EBEDF674E` |
| `docs/archive/viewer-profile/2026-10-10/RESTORE.md` | `B07A28CFB913E07AA8E1086D233A971737555457D229FB7F5BB4C1CCF7ED3E59` |
| `docs/archive/viewer-profile/2026-10-10/SYMBOLS.md` | `37D58960FC94315B93878CAA602B9BC46362EB62FE520F38F885870E00F54500` |
| `docs/product/identity/CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | `135242BCBFF9AA787DE9C1BAC445905EB49EA118A52F36B21D7B72B3DF4E33E0` |
| `docs/product/identity/PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md` | `40EE8EB4B65E0D71168CB794EC7C52E5616B4B5AABECA929527CB2562284BD11` |
| `docs/archive/viewer-profile/2026-10-10/README.md` | `E4CF5E18E78E55A8CEDF9C57FA862F705603315DC395B4F387AA670256C1A3EE` |

## References, owners and privacy

Full repo reference scan retained 60 text matches outside archive. Relevant
active surface owners already use exact `#vp-*` / `#pvp-*` destinations from
03. Creator/Public Creator remaining old filenames occur in dated §0 revision
history; Page/Public Page in revision tables; decision package is explicitly
historical non-normative. Index previous audit is explicitly historical under
its current §0–§1 routing. Prepared tasks, prior verification reports and master
plan source paths remain provenance/instructions and were not rewritten.
There were no live Markdown old-spec section-anchor links needing conversion.
No mass Viewer string replacement was performed.

All **198 links and destination anchors** in the changed pointer/map/index/
consumer/restore documents were validated (README local links checked also).
Creator has **16 unique VP-D declarations and 43 unique VP-AC anchors**;
Creator/common and Public Creator baseline contents are unchanged except index
metadata pins. Rules about non-searchable baseline, fields, Block/Mute, account
state, verification, publication and Follow therefore receive no new policy.
The unchanged transfer map still routes individual source sections and IDs to
exact owner anchors. Retirement creates no account-state engine or Follow.

## Archive and restore drill

Archive: `docs/archive/viewer-profile/2026-10-10/`.
Manifest SHA: CE309F4E5BD8952A7AF4F0C4CADD4865396BCA6DDC12376AE2EC5C32C0DFF214.
PowerShell parsed 65 rows (9 pipe cells, numeric byte-size column), joined each
archive-relative path against the archive root, used `Get-Item.Length` and
`Get-FileHash -Algorithm SHA256`: **65/65 present and exact bytes/hashes**.
65 immutable raw snapshots + four Markdown guides remain; .dart.txt/.md.txt
are reference snapshots, not discovered source/tests. Guide hashes change
only as documented here; MANIFEST/raw hashes remain unchanged.

One selected source, manifest original path
`apps/mobile/lib/features/explore/presentation/pages/profile_page.dart`, was
copied from its `.dart.txt` snapshot to original filename outside runtime:
`C:/Users/User/AppData/Local/Temp/pvr07-8qmm9kv_/restore-drill/profile_page.dart`.
Restored size: **120053 bytes**; SHA-256: **8D48FF364044CCB17702C03A46A9A7AAC3143966F6B68B88EB7ABED73953DB64**.
Restored bytes == raw snapshot bytes == manifest size/hash. The file was reread;
all **27 import declarations** remain exact, all relative targets exist in the
current target tree. Package imports identify design_system/Flutter/Riverpod/
GoRouter; this is an inventory, not a transitive historical dependency closure.
No old file was copied over current profile_page.dart. No historical checkout,
SDK/dependency reinstall or historical app compilation performed/claimed.
RESTORE explicitly defaults to selective adaptation under current ADR/guards.

## Checks / evidence

Working directory for all commands: `C:/Users/User/.codex/worktrees/7275/Recharge`.
Evidence and entry copies: `C:/Users/User/AppData/Local/Temp/pvr07-8qmm9kv_`:
`docs-validation.json`, `restore-inventory.json`, `scans.json`, scan text files,
`protected.json`, `prior-hashes.json`, `own-doc-delta.patch`, status input/output.
Temporary evidence is local; authoritative summary and final hashes are here.

- Python entry backup/restore scripts: exit0; reread bytes/hash exact.
- Python link/anchor/ID validation: exit0; 198 destinations, 0 missing links/
  anchors; 16 VP-D, 43 VP-AC unique. No whitespace errors.
- `rg -n '_ViewerProfileBody|_ViewerUpgradeRow|_RoleTrack|PROFILE MODE|AccountExperience.viewer|AdminExperiencePreview.viewer|admin-preview-viewer' apps/mobile/lib`: exit1, **0 matches**, expected no-match success.
- `rg -n 'docs/archive|archive/viewer-profile' apps packages tools .github pubspec.yaml melos.yaml apps/mobile/pubspec.yaml`: exit1, **0 matches**. App/test sources, manifests/assets declarations and build scripts do not reference/package this archive. No broad analyzer excludes were added.
- `rg -n 'VIEWER_PROFILE_FUNCTIONAL_SPEC|PUBLIC_VIEWER_PROFILE_FUNCTIONAL_SPEC' --glob '*.md' --glob '!docs/archive/**' .`: exit0, **60 matches** (inventory classified above).
- `rg -n 'unlistedViewer|PublicPageViewerContext' apps/mobile/lib`: exit0, **6 matches**, legitimate contexts retained.
- Root `git diff --check`: exit0, existing LF/CRLF advisory warnings only.
- Root `git status --short`, HEAD and branch rechecked; entry/output retained.
- All **2172 protected files** were hash-compared excluding explicitly added
  header-pin/README paths: **0 outside own delta changes**. Raw archive,
  runtime, previous reports, ADR/master plan and unrelated backend WIP preserved.
- New report/local links/append-only byte-prefix separately validated.

Flutter analyze/test/boundary **not rerun in 07**: no Dart/runtime/test changes;
this task explicitly permits docs/diff checks for docs-only work. Historical
06 gates (1322 passed/20 skipped, analyzer0, boundary0) remain 06 evidence,
not newly reported 07 execution or proof its regression gaps disappeared.

## Acceptance and limits

| Criterion | 07 evidence / verdict |
|---|---|
| PVR-AC-05 | Current four surface owners and common personal destinations resolve; confirmed docs-only |
| PVR-AC-06 | 16 VP-D / 43 VP-AC unchanged, unique owner declarations/anchors and map resolves; confirmed docs-only |
| PVR-AC-13 | No retired Viewer runtime composition/experience/selector symbols; scan confirmed; U01/U02 runtime results remain 06 |
| PVR-AC-14 | No Viewer Admin preview symbol/label in runtime; scan confirmed; A07/A08/U15 behavioral scope remains 06 |
| PVR-AC-22 | Only metadata/pointers/guides changed; baseline/overlay/privacy text unchanged, no public fields/searchability widened; confirmed docs-only |
| PVR-AC-23 | 65 raw files exact, no runtime/asset/script archive references, selective original-name restore/read/hash/import inventory passed; confirmed local |

A01–A12/U01–U16 are not rerun here. Their exact confirmed/partial/not-closed
verdicts stay in 06. A12 global Favorites key/API, actual auth-return A01,
actual workspace+existing publisher draft U14, combined two-account storage
fixture, UI reopen/error/back gaps remain unresolved. Future AccountStatus is
still Draft/docs-only, not mislabeled a shipped runtime engine. **Ready07 means
retirement/restore complete, not ready06 or whole-plan acceptance.**

## Rollback and next handoff

Entry copies and own-doc-delta.patch are in the exact temporary root above.
Restore only the nine listed document paths (or reverse bounded patch after
checking later edits), delete this new 07 report and remove only appended07
index block using preserved entry index. Never reset/clean unrelated WIP,
restore old whole shared Dart over current runtime, or reset user storage.
Runtime cutover rollback remains the coordinated05 set plus separate06 fixes.
Raw archive remains immutable and usable; selective restore is the default.

Next agent must be separately dispatched. 08 must not assume 06 gates closed
or declare whole PVR Done merely because old spec paths are now retired.
Resolving Favorites ownership/isolation needs separately agreed bounded scope
and migration policy; other 06 coverage gaps remain explicitly open.


## Concurrent Git movement at final check

The output HEAD changed during 07 without file-content drift: external commit
8a6c2dea336b2705bab3e1d4ffd5eb81708c9c25, subject `feat(media): add D2 late
restriction of published Media (Emulator only)`, parent
0e0cbefefcc3ef90d20f112ac0622a26932eaf3f, author RechargeN.
This agent executed no commit and did not revert the external Git movement.
The protected content hashes and prior report hashes remain unchanged.
Output status is refreshed in the entry backup; next agent must use actual
current HEAD rather than assuming stage00 HEAD is still the checkout tip.
