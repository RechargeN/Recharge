# Recharge Backend — API Mobile Boundary Review

- ID: **BCK03-MOB-REV-01**
- Version: **0.2**
- Date: **2026-09-09**
- Status: **Owner verdict recorded — independent evidence pending**
- Review result: **Accept with required amendments**
- Reviewer independence: **not evidenced**
- Target: [BCK-03 v0.3.12](BACKEND_API_CONTRACT_STANDARD.md)
- Mobile architecture baseline:
  [Recharge Mobile Architecture v3.1.1](../architecture/RECHARGE_MOBILE_ARCHITECTURE_V3.md)
- Integration evidence:
  [BCK-18 v0.3](MOBILE_BACKEND_INTEGRATION_STANDARD.md)
- Coverage evidence:
  [BCK-18-PRE v0.3](BACKEND_MOBILE_INTEGRATION_COVERAGE_MATRIX.md)
- Mobile owner decision:
  [BCK03-MOB-DEC-01 v0.1](BACKEND_API_MOBILE_OWNER_DECISION.md)
- Runtime effect: **none**

## 1. Scope

This review checks only whether a future Recharge mobile client can consume the
BCK-03 API boundary without transport concerns leaking into presentation or
domain layers, without false mutation outcomes and without unsafe cache or
compatibility assumptions.

It does not approve BCK-03, BCK-18, BCK-20, API-DEC-04, any generated client,
mobile/backend runtime, Firebase, deployment, push or merge. BCK-18 is useful
review evidence even though its Approval and executable slices remain separate
from D1.

## 2. Current-state evidence

- Recharge mobile product repositories remain local/mock.
- Booking v1 is the only implemented cross-language schema/DTO family.
- No production Recharge backend transport, Firebase Auth, Firestore, Storage
  or App Check binding is present in the mobile application.
- Mobile Architecture v3.1.1 fixes presentation/application/domain/data
  ownership and requires typed stale, unsupported, cancelled and unknown
  outcome states.
- BCK-18 v0.3 defines the target adapter/cache/cutover contract but remains
  Review and grants no runtime authority.
- Mobile Money normalization remains a prerequisite for remote writes.

## 3. Boundary matrix

| Area | Result | Evidence / preserved gate |
|---|---|---|
| Layer ownership | Pass | DTO/transport/cache remain in data; application owns lifecycle; domain and presentation do not know Firebase/HTTP |
| Contract source | Pass with gate | `packages/api_contracts` is canonical; non-Booking schemas remain blocked by API-DEC-05 |
| Command attempt/idempotency identity | Pass | Fresh request ID and stable idempotency key match the Accepted split-key decision |
| Query attempt identity | Gap — amendment required | §12 requires a fresh request ID per attempt, while §21.1 can be read as preserving the request ID across query retries |
| Cancellation | Gap — amendment required | Server `cancelled`, local cancellation before send and transport cancellation after possible send need an explicit non-overlapping mapping |
| Unknown mutation outcome | Pass with amendment | Same-key retry is safe, but every command must declare its client reconciliation mechanism and receipt window |
| Stale response ordering | Pass with amendment | Echoed request ID and revisions exist; the contract must state that arrival order is not authority and older responses cannot overwrite newer state |
| Pagination | Pass with amendment | Opaque query-bound cursors exist; page completion, cursor invalidation and safe merge semantics need to be explicit |
| Freshness and clock | Pass with amendment | Server time/revisions exist; client clock skew and offline cache must never extend server freshness |
| Typed errors/localization | Pass with amendment | Stable codes and optional message keys exist; unknown keys/paths need a safe bundled fallback and no raw server text |
| Minimum client | Gated | API-DEC-04 remains Deferred; no production hard-block/bootstrap behavior is approved |
| Auth/access revocation | Pass | Client grants are untrusted and backend reauthorizes mutation and protected replay disclosure |
| Market/reference compatibility | Gated | BCK-20/OD-10 remain unaccepted; unsupported critical revisions fail closed |
| Production readiness | Not evaluated | G1, R1, bindings, generated clients, deployment and runtime remain blocked/Absent |

## 4. Findings and required amendments

No contradiction requires rejecting the BCK-03 direction. Before BCK-03 can
leave Draft, the following amendments remain mandatory:

1. **Separate query attempt from logical query identity.** Every physical query
   attempt uses a fresh `requestId`, including automatic retry. Stable filters,
   cursor and an optional registered logical query/generation reference may
   correlate the operation, but reusing `requestId` must not be required.
2. **Disambiguate cancellation.** User cancellation proven before send is a
   local neutral outcome and creates no server result. Cancellation after a
   possible send is `unknownOutcome` until reconciled. Backend `cancelled` is
   only an authoritative terminal product outcome returned by the operation;
   transport abort must never fabricate it.
3. **Declare unknown-outcome recovery per command.** Each idempotent command
   profile states whether recovery uses same-command replay, a status query or
   another typed mechanism; it also declares the safe result/retry window and
   terminal behavior after expiry. Missing recovery semantics keep the future
   mutation disabled.
4. **Make page completion and invalidation explicit.** The cursor-page contract
   defines how end-of-list is represented, when a cursor becomes invalid or
   stale, and the typed response for a changed query/snapshot. Page merge uses
   stable ID plus disclosed revision; an older page cannot overwrite a newer
   item or silently mix snapshots.
5. **Bind freshness to server evidence.** Material read projections declare
   server-generated revision/time/freshness metadata. Device time is not
   freshness authority, clock skew is handled conservatively, and offline or
   background resume never extends `freshUntilUtc`.
6. **Reject response-arrival authority.** A client matches the current attempt
   by echoed request ID and applies resource/projection revisions according to
   the owning contract. A late response from an older controller generation is
   ignored or reconciled, not applied merely because it arrived last.
7. **Define safe localized failure fallback.** `messageKey` and field paths are
   bounded hints, not executable or display authority. Known codes map to
   bundled localized copy; unknown keys use a safe generic message. Raw server,
   provider or SDK text is never displayed.
8. **Preserve the minimum-client gate.** API-DEC-04 must be Accepted before a
   production client gate exists. Its decision must cover bootstrap unavailable
   and cached-policy behavior, mutation fail-closed rules, safe read/export/
   logout paths, approved update targets and rollback.
9. **Keep downstream mobile integration gated.** BCK-18 decisions, BCK-20/
   OD-10, Money migration, generated clients, binding manifests and per-domain
   cutover evidence remain separate prerequisites; this review does not close
   them.
10. Obtain independent Mobile Platform evidence separately from this combined
    Product-owner review before claiming independent acceptance.

## 5. Preserved decisions and non-decisions

- BCK-03 remains **Draft**.
- BCK-18 remains **Review — documentation only**.
- BCK-20 and its coverage remain **Draft**.
- API-DEC-04 and API-DEC-05 remain **Deferred**.
- OD-09 and OD-10 remain **Proposed**.
- D1-SIG-API and bounded D1-SIG-OPS/SEC retain their recorded verdicts.
- D1-SIG-MOBILE is **Accept with required amendments — BCK-03 boundary only**.
- Independent Mobile evidence remains absent.
- No schema, generated file, mobile/backend runtime, Firebase, deployment,
  push or merge is authorized.

## 6. Recommended owner verdict

```text
Approve D1-SIG-MOBILE for the BCK-03 boundary as Accept with required
amendments. This is a combined-owner documentation verdict; independent Mobile
Platform evidence remains absent. BCK-03 remains Draft. BCK-18 remains Review.
API-DEC-04/05 remain Deferred and OD-09/10 remain Proposed. Runtime, Firebase,
deployment, push and merge are not authorized.
```

The Product owner explicitly accepted this recommendation on 2026-09-09.
`D1-SIG-MOBILE` is therefore recorded as Accept with required amendments for
the BCK-03 boundary only. Independent Mobile evidence and all downstream
integration/runtime gates remain open.

## 7. Acceptance criteria

1. **BCK03-MOB-AC-01:** mobile layers preserve the accepted dependency direction.
2. **BCK03-MOB-AC-02:** DTO/cache/transport types do not cross into domain or presentation.
3. **BCK03-MOB-AC-03:** every physical query or command attempt has a fresh request ID.
4. **BCK03-MOB-AC-04:** logical command retry preserves idempotency key and semantic payload.
5. **BCK03-MOB-AC-05:** local pre-send cancellation, post-send ambiguity and authoritative server cancellation remain distinct.
6. **BCK03-MOB-AC-06:** every enabled mutation has a declared unknown-outcome recovery path.
7. **BCK03-MOB-AC-07:** late responses cannot overwrite newer client state by arrival order.
8. **BCK03-MOB-AC-08:** pagination exposes unambiguous completion and typed cursor invalidation.
9. **BCK03-MOB-AC-09:** page merge cannot silently mix snapshots or overwrite a newer revision.
10. **BCK03-MOB-AC-10:** device time, offline state and background resume cannot extend server freshness.
11. **BCK03-MOB-AC-11:** unknown message keys and field paths use a safe bundled fallback.
12. **BCK03-MOB-AC-12:** raw server/provider/SDK text is never user-visible.
13. **BCK03-MOB-AC-13:** API-DEC-04/05 remain fail-closed until separately Accepted.
14. **BCK03-MOB-AC-14:** BCK-18/BCK-20 and Money/cutover prerequisites are not inferred complete.
15. **BCK03-MOB-AC-15:** combined review is not called independent Mobile evidence.
16. **BCK03-MOB-AC-16:** no runtime, Firebase, deployment, push or merge authority is created.

AC numbers are stable. New criteria append; semantic removal or change requires
an explicit revision and reconciliation note.

## 8. Next action

Continue the remaining D1 owner/signature reviews. Do not advance an executable
stage until its complete approval and evidence gates pass.
