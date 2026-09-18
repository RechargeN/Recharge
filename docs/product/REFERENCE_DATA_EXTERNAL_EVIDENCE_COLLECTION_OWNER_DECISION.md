# BCK-20 — External Evidence Collection Plan Decision Record

- ID: **BCK20-OD02-EXT-EV-PLAN-DEC-01**
- Version: **0.1**
- Date: **2026-09-18**
- Recorded at: **2026-09-18T19:48:14+03:00**
- Status: **Accepted docs-only plan with retained gates**
- Owner/signatory: **RechargeN / Product owner**
- Combined roles: **Reference Data + Product/Market + Product Localization/Content + Platform Operations + technical Security/Privacy**
- Independence: **None — all five roles are held by the same owner**
- Qualified Security/Privacy/Legal claim: **None**
- Frozen plan: [BCK20-OD02-EXT-EV-PLAN-01 v0.1](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_PLAN.md)
- Frozen review: [BCK20-OD02-EXT-EV-PLAN-REV-01 v0.1](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_OWNER_REVIEW.md)
- Network authority: **None**
- Runtime authority: **None**

---

## 1. Decision

The owner accepts the frozen external-evidence collection plan as the required
documentation procedure for later evidence work. The decision satisfies only
`EXT-G0` for the exact frozen plan.

It does not authorize `EXT-G1–G6`, network access, redirect following, terms
capture or acceptance, downloads, external artifacts, parser/fixture work,
repository data, ingestion, schema, cloud resources or runtime.

## 2. Frozen evidence

Hashes are SHA-256 over UTF-8 bytes after CRLF-to-LF normalization.

| Artifact | Frozen version | SHA-256 |
|---|---|---|
| Collection plan | `BCK20-OD02-EXT-EV-PLAN-01 v0.1` | `f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac` |
| Combined-owner review | `BCK20-OD02-EXT-EV-PLAN-REV-01 v0.1` | `f23fcf6052fd02901319c072b29f1b4a263fbef0729c741d7cab3aed3664762b` |

Any content, version or normalized-hash change requires a new review and
decision. Later status annotations do not alter the frozen v0.1 evidence.

## 3. Accepted scope

- eight candidate sources remain partitioned into four independently
  authorized batches;
- P0–P6 remain the mandatory sequential procedure;
- EXT-G0–G6 remain the mandatory evidence gates;
- every future run requires a separate exact authorization containing source
  IDs, origins, methods, redirect policy, byte limits, expiry and temporary
  storage root;
- raw artifacts remain temporary and untracked by default;
- `eligible_for_slice_review` remains the maximum result before a separately
  Approved executable slice.

## 4. Retained gates

- only `EXT-G0` is satisfied;
- `EXT-G1–G6` remain closed;
- all external sources remain artifact/terms/validation Pending;
- no license/terms or qualified Legal conclusion exists;
- all markets remain disabled;
- `BCK20-OD-02` and `BCK20-OD-05` remain Open;
- `OD-10` remains Proposed, `BCK-20` Draft and `BCK20-OD-03` Deferred;
- provider selection, schema, IAM/runtime, Firebase, deployment and activation
  remain unauthorized;
- push and merge are outside this decision.

## 5. Verbatim owner instruction

> Одобряю BCK20-OD02-EXT-EV-PLAN-REV-01 v0.1:
> Accept docs-only external evidence collection plan with retained gates для
> точного BCK20-OD02-EXT-EV-PLAN-01 v0.1 / SHA-256
> f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac.
>
> Подтверждаю совмещение ролей RechargeN / Product owner, отсутствие independent
> review и отсутствие qualified Security/Privacy/Legal claim.
>
> Принятие открывает только EXT-G0 documentation baseline. EXT-G1–G6, network
> access, redirects, terms capture/acceptance, downloads, external artifacts,
> parser/fixture work, repository data и ingestion остаются unauthorized.
>
> Все markets остаются disabled; BCK20-OD-02/05 Open, OD-10 Proposed,
> BCK-20 Draft, BCK20-OD-03 Deferred. Provider selection, schema, IAM/runtime,
> Firebase, deployment, activation, push и merge не разрешаю.

## 6. Effect and rollback

Effective immediately for documentation reconciliation:

1. the frozen plan may be cited as the accepted EXT-G0 procedure;
2. a future owner may separately consider an exact EXT-G1 authorization for
   one named batch, but no such authorization exists now;
3. canonical BCK-20 and D1 records may record EXT-G0 as satisfied while keeping
   every later gate closed;
4. no executable artifact or external system changes.

Rollback requires a superseding owner decision and atomic documentation
reconciliation. Deleting this record or silently restoring a prior status is
not rollback.

## 7. Acceptance criteria

1. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-01:** the exact plan and review are frozen by version and normalized hash.
2. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-02:** acceptance satisfies EXT-G0 only.
3. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-03:** EXT-G1–G6 remain closed.
4. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-04:** no network access, redirect following or terms capture is authorized.
5. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-05:** no download, artifact, parser, fixture, repository data or ingestion is authorized.
6. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-06:** all eight sources retain artifact/terms/validation Pending state.
7. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-07:** every future run requires a separate exact bounded authorization.
8. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-08:** shared ownership and zero independence remain explicit.
9. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-09:** no independent or qualified Security/Privacy/Legal claim is created.
10. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-10:** all markets remain disabled.
11. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-11:** BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and BCK20-OD-03 Deferred.
12. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-12:** provider, schema, IAM/runtime, Firebase, deployment and activation remain unauthorized.
13. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-13:** this decision authorizes no push or merge.
14. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-14:** any frozen target content/version/hash change requires a new review and decision.
15. **BCK20-OD02-EXT-EV-PLAN-DEC-AC-15:** rollback requires an explicit superseding decision and atomic documentation reconciliation.
