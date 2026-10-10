# Recharge integration consolidation — 2026-10-11

Target: `codex/recharge-integration`, `C:/Users/User/.codex/worktrees/7275/Recharge`.
Starting HEAD: `8a6c2dea336b2705bab3e1d4ffd5eb81708c9c25`.
User authorized consolidation and local commits after Claude finished D3.2.

## Integrated work

- `9de403d`: PVR-01 runtime, accepted ADR 0021, specification retirement, archive and verification evidence (119 paths). PVR remains In progress; account isolation, auth-return and outstanding UI regression gates remain open.
- `2944c79`: merge of `claude/d3-2-activity`; retains original D3.1 `fd56758` and D3.2 `b1e678a` commits. Automatic merge preserved the PVR row in LAUNCH_STATUS. No source branch was reset or modified.
- `941f618`: port of Desktop IDP snapshot `be17822`: publisher defaults, fail-closed publisher guard, duplicate-submit/failure handling, workspace revalidation and tests. Current PVR presentation/docs and corrected Details/Create/Profile fixtures won conflicts; obsolete fixture adjustments were excluded. Nineteen paths changed.
- `1e0517e`: `.gitattributes` preserves the immutable Viewer archive as raw bytes (`-text -diff`). All 65 indexed snapshot sizes and SHA-256 values matched MANIFEST. The initial archive commit normalized some CRLF files; this follow-up corrects committed blob bytes rather than changing the historical snapshots.

## Other sources

The per-file list and source hashes are in [source disposition](INTEGRATION_2026_10_11_SOURCE_DISPOSITION.json), 68 entries, no unexplained absent paths.

- `012d`: all ten PVR handoff files compare equal to integration; current execution plan/evidence is newer. Retained the executed plan in 7275.
- `185d` / `2942dc2`: only root/package lockfile changes. Retained the evolved Dart workspace root lock and absent child locks; no dependency rollback.
- `f294` / `6d58b91`: current backend specs already exist in later revisions (e.g. AI v0.3 versus snapshot v0.1). Retained current roadmap/status/specs and workspace locks.
- Details `bb63f53` and `4ae375a`: documents exist under `docs/product/discover/`; shared visual primitives and design tokens are already byte-identical for the checked files. Current renderer uses typed FindPeople/ClassWorkshop/BookableSession projections instead of the old preview-only input file. Retained the evolved implementation and current fixture corrections.
- Historical `agent/mobile-architecture-m2b`: four alternate Money reconciliation commits remain on the original branch. The previous consolidation explicitly retained this alternate by owner decision; it is not replayed over the current Money baseline. This is a deliberately excluded historical variant, not a completed merge of every branch tip.
- `claude/sweet-lumiere-4a3174` is an ancestor of integration. Other clean detached worktrees contain no new commits relative to integration.
- Desktop `.claude/skills/` is untracked tooling; excluded from product commits. The audit checkout's report/patch/inventory are local audit artifacts, not application changes.

Source worktrees and historical branch refs are preserved. A differing blob is not automatically proof of semantic equivalence: the source-disposition list records retention decisions and is not a claim that all historical changes were replayed.

## Checks on integrated runtime

- Mobile analyzer: 0 issues after IDP port.
- Full mobile suite: 1456 passed, 30 skipped, 0 failed (3:32). Stand tests remain separately gated.
- Focused IDP guard/default/workspace/small-screen suite: 35 passed.
- Boundary: 581 Dart files, 71 existing suppressions, 0 violations, no stale/expired exceptions.
- Backend Node 22.23.2: typecheck and lint passed; unit 692/692; contract 50/50; Place/Activity enablement + publication security 31/31; format check passed.
- Raw Viewer archive: 65/65 committed-index bytes verified against manifest.
- Diff check: passed after raw snapshots were marked binary diffs.
- Full Emulator suite: running; final outcome will be recorded below.

The first mobile suite crossed an IDP conflict-resolution window and was discarded. A complete repeat on the stable tree passed. The initial backend tests used PATH Node 20 and could not start because of an unsupported flag; their Node 22 repeats passed.

No push, remote merge, deployment, provisioning or production verification performed. D3 slices remain Review, PVR remains In progress, and device/Linux/cloud/production gates are not closed by this consolidation.

## Continuation point — user asked to continue tomorrow

Runtime integration is committed through `1e0517e`; report and IDP status updates are saved in the following documentation commit. Full Emulator run is still in progress (session 38793); read `apps/backend/functions/integration-emulator.log` for its terminal outcome before reporting it green. It was launched through Node 22.23.2 and the local no-cloud wrapper. Latest completed groups include Event→Booking and reconfirmation boundary-clock checks, all passing so far.

Resume in `C:/Users/User/.codex/worktrees/7275/Recharge`, `codex/recharge-integration`. Recheck HEAD/status and the two Claude source heads before any edit. Do not repeat already green mobile/unit/contract suites without a new change or failure. Finish Emulator outcome, investigate any failure, update this report and verify clean tree. Mobile stand D3.1/D3.2 gates were not rerun in this consolidation and remain separate evidence. Historical M2-B and tooling exclusions remain explicit. No push authorized.
