# D3.4 — Collection / Guide through Content (Emulator only): evidence

Date 2026-10-12. Status **Review**; Windows-local Emulator evidence; not Done, not
committed, no push or merge. Normative text:
[COLLECTION_D3_4_PUBLICATION_AMENDMENT.md](../../../product/COLLECTION_D3_4_PUBLICATION_AMENDMENT.md).

## Checked state

Worktree `C:/Users/User/.claude/worktrees/recharge-d3-4`, branch
`claude/d3-4-collection`, base `e87883f` (integration). Source fingerprint
**`e87883f+wt:20b0433c8ab1`**: every path that differs from HEAD plus untracked
files, as `path TAB SHA-256 (content without CR)`, sorted; first 12 hex of
SHA-256 of that list. Excluded: the amendment, `LAUNCH_STATUS.md` and this file
(written after the run). 64 files; identical before the first gate and after the
last one.

Toolchain: Node 22.23.2 / npm 10.9.8 (portable), Temurin 21.0.12+8, Flutter from
`C:/src/flutter`. Backend `node_modules` copied from the D3.2 worktree with the
same `package-lock.json` (no download). Mobile `flutter pub get --offline`; no
lockfile changed.

## Results

| Check | Result |
|---|---|
| `git diff --check` (with untracked files) | clean |
| boundary (`check_boundaries.dart`) | 0 violations, 71/71 suppressions, 597 Dart files |
| build, typecheck, lint, `format:check` | pass |
| unit / contract / integration (`lib/test/{unit,contract,integration}`) | 720/720 / 55/55 / 229/229 |
| stand tests / Emulator runner tests | 42/42 / 6/6 |
| `verify-*`: r1 layout/config/exports, content-persistence, reference-data, security-privacy, identity-publisher, generated, taxonomy, execution-manifest, cloud-context | pass |
| `test:emulator` (7 groups, sequential) | 225/225, exit 0; `collection` group 13/13 in 189 s (limit 390 s) |
| gate D3.4 (`stand-d3-4-gate.mjs --yes`) | pass: clean = interrupted (`member-2`) and resumed = repeated seed (digest), controller 4/4, UI 1/1, invariants, verified stop |
| gate D3.8 `--linked-place` (PlaceLinkService changed) | pass: real Catalog picker → Activity publish/Activate, Place restriction/restore, verified stop |
| gate D3.1 | pass: real Place photo delivery with D1 tools (L1) 4/4, seed/digest cycle, controller 4/4, UI 1/1, verified stop |
| gate C3 | pass: Event seed/digest cycle, controller 3/3, UI 1/1, verified stop |
| `api_contracts` (`dart test`) | 25/25 |
| `flutter analyze` / `flutter test` | 0 issues / 1517 passed, 37 skipped |

Flutter skips: 32 at the base plus 5 new — `collection_publication_stand_test.dart`
(4) and `collection_publication_ui_stand_test.dart` (1). Every skip is a
`backend_local` stand test that runs only against the stand; the 5 new ones ran
and passed in the D3.4 gate. The shared stand was stopped before each gate and is
stopped now.

## Found and fixed during the pass

- `content_publication_security.test.ts` failed at the base `e87883f`
  (`modules/catalog/infrastructure/content_catalog_source.ts: canonicalJson`):
  D9 imported `canonicalJson`/`sha256Hex` from Content without registering them.
  Reproduced against the archived base sources; D3.4 registers both symbols with
  a reason (integrity check of the owner's immutable revision). The guard is not
  weakened.
- The first integration run of the oversized-list case showed that a body over
  `maxItems` never reaches storage (64 KiB `assertBoundedBody`); the test now
  asserts that refusal and that no membership question was asked.

## Not covered

Removal-only/archive (CLG §3.11), Catalog/Discover/Details for Collection
(OD-04), the BCK-20 applicability rule for Collection, validator codes on the
client, batched membership reads, Activate/edit after publication on mobile,
physical devices, Linux, cloud and production. D2 residual windows W1–W6 and F2a
apply to Collection media as to Place.
