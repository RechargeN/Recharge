# D10 — real Activity Media/D2 evidence

Date 2026-10-12. Status Review; Windows-local L1, no owner acceptance/production claim. No runtime defect was found and no runtime Media/D2 code was changed. Parent verified baseline 901bf0d25d9b7448d1fc0b456b2d1ee4a920b462; test/gate fingerprint b8436179b716aa053a1e3b101db7552ac485831fde8313e2e67702e822f5193d, exact files in D10_ACTIVITY_MEDIA_SOURCE_2026-10-12.json.

## Observed Activity chain

Existing content_place_media_delivery.test.ts is reused with explicit Activity selector, four sequential cases, strict 4 passed / 0 failed / 0 skipped / child exit 0. No second general Media suite. Only test-world Media/image injection and the existing runner's bounded Activity-only option were added.

1. Both Activity gallery photos are delivered through handleMediaDelivery/D2 from Storage Emulator as nonempty actual sharp WebP bytes; SHA256 of delivered bytes equals both the response and the asset display-variant manifest. EXIF/GPS markers are absent. One source JPEG deliberately has GPS metadata.
2. Staff restrict_media immediately refuses the chosen photo (not_found) while Content has no suppression yet; the other photo still delivers actual bytes. This demonstrates refusal before owner-source convergence.
3. Staff restore_media alone leaves the chosen photo refused because the publication confirmed the previous epoch. Refusal persists both before and after explicit Content reconciliation; Content then records that photo's suppression.
4. Existing publisher Activate of the exact published Activity revision confirms current permitted Media and clears suppression; the same photo delivers actual WebP/hash-verified bytes again.

Tools: existing verified ClamAV 1.5.4/sharp 0.35.5/Node22 installation in Claude LocalCache. L1 stand-signatures-only mode, no official database/antivirus-production claim. No download/reinstall was performed. Gateway invoked directly against real Auth/Firestore/Storage Emulators, as existing Place P15; this is not new positive Functions HTTP/device/UI byte-delivery evidence. Existing shared callable guards remain covered by media_delivery_callable.test.ts.

## Required shared-stand preflight

Before any live D10 process: standard shared state C:/Users/User/AppData/Local/Recharge/emulator-stand/demo-recharge/state.json had phase stopped, runId a7362c1d-b61a-4e66-b354-da1797fd9bd9. Claude cached state also had phase stopped. CIM search found zero matching live Firebase/Firestore/PubSub/D1 processes. Exact loopback bind/close probes passed for 5001,8080,8085,9099,9199,4400,4500,9150. The gate additionally used the existing verified stop, built before starting tools/Emulators, enforced all four tests and verified owned tools stop. Stand/tool roots were deliberately separate through RECHARGE_D10_STAND_LOCALAPPDATA; the previous failed attempt tried the old cached state and correctly refused Invalid/stale state before any live process. That diagnostic is not passing evidence.

## W1–W6 / F2a applicability

Definitions remain MEDIA_D2_LATE_RESTRICTION_AMENDMENT.md §10, not new zero-window guarantees.

| Item | Existing evidence / D10 relevance | Still open |
|---|---|---|
| W1 in-flight response | media_delivery_gate T12/W1 covers restriction during byte read and the already-final-checked response; D10 proves next request refusal with real Activity bytes | Bytes already returned cannot be revoked; no atomic/time guarantee; client cache belongs to F2a |
| W2 publication change | Existing T12/W2 pointerRevision recheck; no owning gateway/publication code changed | Change after the last publication check can affect one response |
| W3 Content/Catalog lag | D10 real Activity refusal with no Content suppression yet; D9 Activity Catalog/D2 old-snapshot/rebuild evidence remains valid for unchanged runtime | Identifier visibility may lag until convergence; no delivery-time guarantee |
| W4 epoch/activation race | Existing content_media_availability T7 and gateway T2/T3; D10 restore-before/after-reconcile refuses until publisher confirms current epoch | No cross-module transaction or zero residual window claim |
| W5 missed feed | Existing R1 missing-effect sweep and late/out-of-order/worker-repeat integration evidence | R1 scheduling delay remains; do not invent a new Activity-specific checkpoint mechanism |
| W6 deletion hold | Existing media_delivery_gate hold/deletion and content_media_availability hold/deleted cases | Hold alone does not imply suppression; legal/security hold authority OD-07 remains separate |
| F2a signed URL/CDN/client cache | These are absent from this Emulator byte gateway; no signer/CDN/client cache environment was introduced | Deferred, untested here; no inference about cached delivered bytes or URL revocation |

Existing D2 Review evidence is recorded at 8c69715+wt:3c31bd0c7065 (934/934, D2 72+5/5, callable T15 4/4); subsequent full Content/Media and Activity gates are in the D3 reports. Relevant Media owner implementations are unchanged. Only missing real Activity variant-byte chain was repeated, with actual tools. Generic W tests are not relabelled as newly executed Activity-specific cases. Linux, official scanner databases/EICAR, physical devices, cloud and production stay open.

## Files, commits and rollback

Baseline was frozen by thematic local commits, recorded in D10_BASELINE_COMMITS_2026-10-12.json. Original 134 status entries expanded to 156 files; 15 were already identical to HEAD after CRLF normalization and needed no artificial content commit. Mixed files accumulated passes and were assigned to their last owning slice; intermediate commits are not claimed as historical independently checked revisions. Final baseline normalized content still equals D3.9 fingerprint a10b8df9a266a68a4fd7b7759cfb47a4d3620fac0eeea0dee1357af1f2eb8b04.

Command: stand-d3-1-gate.mjs --yes --activity-delivery-only, with cached-tools LOCALAPPDATA, standard RECHARGE_D10_STAND_LOCALAPPDATA, Node22 in PATH and pinned Java21. Evidence logs retained in d10-logs. Rollback is the D10 test-selector/world-injection/runner addition only; immutable Activity and Media state, contracts, guards and lifecycle are unchanged. D11 must be a separate reversible commit and repeat C3/D3.1/D3.2 Emulator regression by owner condition. No push/merge.
