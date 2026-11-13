# D11 — stable Place/Activity extraction

Date 2026-10-12. Status Review; bounded local extraction complete, recommendation accept. Owner approved the exact plan and local commits, requiring the prior baseline be committed first, D10 stand-stop preflight and C3/D3.1/D3.2 Emulator regressions. No push/merge/production or owner acceptance of publication slices was inferred.

## Exact checked state and rollback boundary

Branch codex/activity-d10-d11, worktree C:/Users/User/.claude/worktrees/recharge-d3-2. Parent D10 commit 51778a79754bd61679b9dec6a1a53771c1e33219; D11 code/test fingerprint 690643e2af655d0e3f73889351e44b01f4e0b589443dc5673c1ea64c663c19d4, 11 exact paths in D11_PLACE_ACTIVITY_SOURCE_2026-10-12.json. Those hashes were checked before and after live gates with no drift. Documentation/evidence do not participate in the runtime fingerprint. This change is committed separately; reverting only the D11 extraction commit restores D10/baseline without rewriting Content revisions or journal files. Prior baseline thematic commit ledger is D10_BASELINE_COMMITS_2026-10-12.json.

## Comparison and actual extraction

| Surface | Stable overlap | Result |
|---|---|---|
| Journal | JSON-list read, absent/malformed/non-list fallback, cap 100, flush/temp rename | One PublicationJournalFile IO helper; existing typed wrappers retain their classes/interfaces/codecs, exact account/publisher matching, keys, file paths, newest-first ordering and DTO differences |
| Controller | Filename-to-declared-MIME claim | One pure helper; byte hashing, attachments, UUID namespaces, commands, recovery, revision conflict, support/readiness checks and each lifecycle remain separate |
| Gateway | Already shared FunctionsEventPublicationGateway with explicit typeId | No additional abstraction or contract change |
| Panel / UI | Superficial load/hosting overlap, but Activity has feedback/edit/Activate differences | Panels and specialized sections unchanged; no generic form/panel/lifecycle framework |
| Stand world | Identical creator/staff Auth token + Session registration | createSignedPublishingActors reuses existing identity factory; Place/Activity retain enabled types, body factories, commands and explicit Media/images options; existing Event factory unchanged |

Source LOC across affected files excluding new tests: 2175 → 2151, net 24 fewer lines including new helpers. More importantly, each duplicated disk IO/MIME/Auth setup now has one implementation. No future-ten-type registry, shared publication entity, new mapper or decision engine was introduced.

Small steps: journal extraction first, 27/27 focused tests; MIME helper and unchanged controller/gateway/guards then 40/40. Only two new test files target new common logic: storage fallback/bounded roundtrip/temp-file cleanup/file-system failure and filename claim behavior. Existing controller tests keep account/publisher/foreign-author isolation, stable keys, lost command responses, Activation conflict/restart, draft editing, unsaved-body refusal and server feedback coverage.

## Mandatory checks on this source

| Gate | Result | Duration / scope |
|---|---|---|
| Backend TypeScript build + changed support ESLint | PASS | Completed before live processes, no runtime build during a live run |
| Existing stand unit/digest tests | 21/21 | 3.624 s |
| Journal focused | 27/27 | existing Place/Activity controllers plus new IO cases |
| Controller/gateway/guard focused | 40/40 | both types and new MIME contract |
| Full Flutter suite | 1436 passed / 32 skipped | 4:55; PC-host stand skips separately run below |
| Full flutter analyze | 0 issues | 99.7 s |
| Boundary | 0 violations | 588 Dart files, same 71/71 suppressions, no stale/expired entries |
| Content/Media Emulator | 65/65, exit 0 | 231.290 s / 330 s timeout; 13 sequential invocations |
| Place/Activity Emulator | 29/29, exit 0 | 170.685 s / 300 s timeout; 5 sequential invocations |
| git diff --check | PASS | Existing repository CRLF normalization |

Additional owner-required full stand gates ran sequentially (all child steps checked, complete summary true):

| Gate | Result | Whole gate duration | Log |
|---|---|---|---|
| stand-c3 | exit 0 | 334.267 s | recharge-d11-stand-c3.log |
| stand-d3-1 | exit 0 | 458.726 s | recharge-d11-stand-d3-1.log |
| stand-d3-2 | exit 0 | 452.719 s | recharge-d11-stand-d3-2.log |
| activity-media-after-extraction | exit 0 | 75.938 s | recharge-d11-activity-media-after-extraction.log |

C3 asserts clean/interrupted/resumed/repeated Event seed/digest, controller 3/3 and UI 1/1, invariant verification and owned stop. D3.1 adds real Place photos 4/4 with D1 L1 tools, seed/digest cycles, controller 4/4 and UI 1/1 and verified stop. D3.2 repeats Activity seed/digest cycles, controller 4/4 including Activate/edit/recovery and UI 1/1, then invariants and stop. Existing D3.2 banner's fixture wording is historical: current runtime taxonomy is canonical as recorded in prior accepted D8, while Activity Catalog/linked Place remain off in this authoring gate. No behavior change was made just to update that banner.

Because the Activity test-world setup changed, the same D10 real-byte chain was repeated after extraction: strict 4/4, real WebP/hash/no EXIF before restriction; immediate refusal; lift alone refuses before/after reconciliation; publisher Activate restores bytes. Both real-tool instances were stopped and verified. A temporary external sequential orchestrator was used, not a new repository framework. It preloaded the existing tools module from Claude's installed LocalCache and kept the standard shared-stand/Flutter LOCALAPPDATA; no download or stale-state override. Final CIM audit found zero matching live Emulator/D1 processes; bind/close probes confirmed all eight common Emulator ports free. The common state is stopped.

Logs under d11-logs; their hash/size index is D11_PLACE_ACTIVITY_LOGS_2026-10-12.json. Emulator summaries and live-summary.json record complete/code/pass counters; ignored .log files remain locally. Direct diff inspection confirms helper delegation only: no server runtime, schemas, flags/guards, mapper/record codec, gateway or panel changes. Mandatory C3/D3.1/D3.2 coverage was repeated rather than claiming old evidence for a changed helper.

## Open items

D10/D2 W1–W6 residual windows, F2a signed URLs/CDN/client-cache and Linux/official scanner databases/device/cloud/production remain open exactly as reported in D10. Existing D3.8/D3.9 product debt and owner publication acceptance remain separate. This refactor has no data migration and does not accept those stages. No runtime Media defect was found; no additional fix or broad Media suite was added.

Rollback: revert the standalone D11 extraction commit. Existing typed journal files and their data remain in place. No merge or push was performed.
