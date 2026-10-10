# Restore and research instructions

This archive is historical/reference and not a runnable Flutter package.
Verify [MANIFEST](MANIFEST.md) before reading/restoring raw snapshots. Never
copy the whole old common profile over newer code without comparing it.

## Selective adaptation to the current app

1. Read active Accepted ADR and the currently approved slice. Old snapshot
   headers do not authorize current implementation.
2. Locate the required source relative path in MANIFEST and check the raw
   snapshot size/SHA-256 with Get-FileHash -Algorithm SHA256.
3. Inspect the full common file, [SYMBOLS](SYMBOLS.md) and current dependencies.
   Extract/adapt only a bounded UI idea or rule. Save to a reviewed location;
   remove only the final .txt suffix if using raw bytes as a research source.
4. Preserve current roles, capabilities, WorkspaceRef/PublisherRef, exact page
   membership, owner scope, private libraries and mutation guards. Do not
   resurrect Viewer selection or old 012d switcher as an accidental restore.
5. Review the diff and run focused behavior checks and the required final
   gates for that new slice. Restoration itself is not a permission grant.

## Historical research at the recorded baseline

Use a separate user-approved research checkout at
8c69715bba03eb1cef7309d4496ebfddd6d11a1e with the repository Git history.
This stage did not create such a checkout. New worktree creation does not
copy uncommitted files. MANIFEST marks each actual source's dirty state;
related untracked PVR-00 plan/handoff must be restored explicitly if needed.
The unrelated backend/media WIP is intentionally absent. HEAD + this archive
does not reconstruct the entire dirty workspace.

Required environment: Flutter 3.44.9/Dart 3.12.2 or an explicitly validated
compatible toolchain; whole monorepo packages/design_system and api_contracts;
root pubspec.yaml/pubspec.lock and mobile pubspec; original adapters/assets/
repository dependency code not included transitively here. Dart workspace
resolution uses the root lock, not a fabricated mobile lockfile.
Use flutter pub get/test/analyze from apps/mobile in the research checkout,
and boundary checks from its root, after ensuring applicable local instructions.
No SDK, platform installation, credentials, runtime assets or user data are
provided by this archive. Dependencies may no longer resolve identically in
future; reproducible compilation is not claimed.

## Immutable snapshots and rollback

Source byte hash must equal manifest snapshot hash. The original copy added
only .txt and did not normalize encoding/line endings. Later source changes
are allowed only through a new task/handoff; never overwrite this snapshot.
A rollback of stage 01 removes only the new 2026-10-10 archive and 01 report
and reverses only the appended 01 index entry/section after inspecting later
changes. Stage 00 evidence and unrelated WIP must remain. Leaving the verified
archive is safe; no app change is required to undo it. No restore drill or
runtime build was performed in stage 01; stage 07 owns the restore exercise.

## Stage 07 verified drill and current replacements (2026-10-10)

A single `profile_page.dart.txt` snapshot was copied outside the repository to
its original `profile_page.dart` filename, reread, and SHA-256/size compared
with MANIFEST. Import declarations were preserved byte-for-byte and relative
import targets inventoried against the current target tree. This proves file
integrity and the selective-restore instruction, **not** a historical app build.
The exact temporary path, hash and inventory are in the stage 07 handoff.

Current replacement owners:
- Personal screen: current profile_page.dart, shared Creator layout (05).
- Personal rules/VP IDs: Creator spec #common-personal / #vp-* anchors.
- Public baseline: Public Creator spec #baseline-context-projection / #pvp-*.
- Page selection/preview: current WorkspaceSection and personal/page experience;
  exact membership guards and real access snapshots remain authoritative.
- Verification/publishing: existing capability guards and PublisherRef contract.

Old Viewer/Profile files are research material. Never overwrite the current
whole shared profile with a restored file; adapt a selected rule/component in a
new approved bounded slice. Stage 06 not_ready and its data-isolation gaps stay
open; restoration does not claim they passed or restore user storage.
