# IDP/M2 integration — CP1, 2026-11-20

Status: verified local checkpoint; owner acceptance and publication pending.

Base: `78d6a38672927c6fa9872e7f3041bd11bc63db44` (PR #13 merged),
including PR #12 `5d2fd49a22434f11bc21cf2769c9111b370d4a8c`.
Integration branch: `codex/idp-m2-on-main-20261120`.
The 23-commit source stack plus safety WIP `86218542` were transferred
individually. Source-to-target mapping and conflict decisions are recorded in
`outputs/IDP-M2-ONMAIN-2026-11-20/CP1-commit-map.json` and
`CP1-conflict-journal.json`; safety tags preserve PR #10, PR #11 and input WIP.

## Preserved main behavior

MEDIA-PICK-02, AUTH-ROT-02, debug Booking/Place entries, current Page padding,
owner-scoped Library and serialized Visit commands were retained. Protected
Event changes and router changes were applied only after the owner's concrete
conditional approvals and isolated candidate tests (20 Event, 13 router).
Event payload bytes are compared with main serializer baselines for paid/free
fixtures; old EventMoneyDraft price data remains readable as shared Money.
PR #13 text bounds 3–100 / 20–240 / 50–20000 remain unchanged. Year 0000 is
intentionally rejected by LocalDate. Recoverable guest state during Auth refresh
keeps workspace/navigation while active access providers expose no authority.
Capabilities rebuild destination Consumers without recreating GoRouter.

## Gates and failure reconciliation

- `flutter analyze --no-pub`: no issues, exit 0 (`CP1-analyze-final.log/.exit`).
- `flutter test --no-pub --reporter expanded`: 2684 passed, 83 skipped,
  0 failed, exit 0 (`CP1-flutter-full2.log/.exit`).
- `git diff --check`: exit 0.
- Only changed Dart files formatted. Localization baseline was not expanded.

The first complete run failed (2669 passed / 83 skipped / 14 failed / exit 1).
`CP1-failure-inventory.json` records each case. The corrected failures passed
33 focused checks and the complete second run. Real integration defects were
a timestamp-only fresh-draft id collision and Admin-preview revalidation while
a different account snapshot was loading. Other repairs migrated exact Money
expectations, bound the mandatory test access port and localized newly
introduced messages. No timeout increases or test removals were used.

No backend, infra, contracts, cloud or device work; AGENTS.md unchanged.
No push or deployment. Compatibility declarations/forwarding exports are
retained for CP4. CP2–CP5 and exact-HEAD Linux CI remain outstanding.
The generated inventory is untouched: main currently records 69 active
exceptions under budget 71, pending the single final regeneration.

## Rollback

The CP1 repair commit can be reverted independently of the transferred stack.
The branch can be reconstructed from main and the recorded commit map; original
PR heads and input WIP remain protected by the three local safety tags.
No persisted data migration was executed by these verification commands.
