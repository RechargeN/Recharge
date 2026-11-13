# BCK-20 — Source Records Combined-Owner Decision Record

- ID: **BCK20-OD02-SRC-REC-DEC-01**
- Version: **0.1**
- Date: **2026-09-18**
- Recorded at: **2026-09-18T19:26:36+03:00**
- Status: **Accepted documentation baseline and evidence work queue with retained gates**
- Owner/signatory: **RechargeN / Product owner**
- Combined roles: **Product/Market + Reference Data + Product Localization + Content/source governance + Mobile + technical Security/Privacy**
- Independence: **None — all six roles are held by the same owner**
- Qualified Security/Privacy/Legal claim: **None**
- Frozen internal records: [BCK20-OD02-SRC-REC-01 v0.1](REFERENCE_DATA_INTERNAL_SOURCE_RECORDS.md)
- Frozen external register: [BCK20-OD02-EXT-EV-01 v0.1](REFERENCE_DATA_EXTERNAL_SOURCE_EVIDENCE_REGISTER.md)
- Frozen review: [BCK20-OD02-SRC-REC-REV-01 v0.1](REFERENCE_DATA_SOURCE_RECORDS_OWNER_REVIEW.md)
- Runtime authority: **None**

---

## 1. Decision

The owner accepts the frozen internal source records as a documentation source
baseline and the frozen external register as an evidence work queue. The six
review perspectives remain separately attributable under one disclosed owner
with zero independence.

The decision fixes documentation meaning for 23 internal records and preserves
the blocking state of six unresolved families. It does not approve an external
artifact, license, terms, ingestion, translation, service area, mandatory
policy copy, schema, market activation or runtime.

## 2. Frozen evidence

Hashes are SHA-256 over UTF-8 bytes after CRLF-to-LF normalization.

| Artifact | Frozen version | SHA-256 |
|---|---|---|
| Internal source records | `BCK20-OD02-SRC-REC-01 v0.1` | `c4b0bcda3c55524354547b0b7596e96488086abf166cae76526ecfe7ba4a8555` |
| External evidence register | `BCK20-OD02-EXT-EV-01 v0.1` | `faee6caaa2a65380c2e631c745669f32da20926502792560c657184bd3bf750d` |
| Combined-owner review | `BCK20-OD02-SRC-REC-REV-01 v0.1` | `e0e41910be23b7848e6fb2a1b87701f877fa341d8e1b96babbed660bb9eaefe0` |

Any content, version or normalized-hash change requires a new review and
decision. Later status annotations do not alter the frozen v0.1 evidence.

## 3. Accepted documentation scope

- `lv`, `ee` and `lt` are accepted as distinct Recharge market identities
  bound to LV, EE and LT respectively.
- Latvia is the first-launch candidate, while all three markets remain
  `disabled`.
- The proposed primary/supported locales and general non-Legal fallback order
  are accepted as revision-1 product documentation inputs.
- EUR assignments and the three IANA timezone policies are accepted as
  documentation inputs subject to pinned external evidence before executable
  use.
- Category System v1.4.3 remains bound by exact normalized hash.
- Missing policy references remain explicit blocking records; there is no
  null-to-latest resolution.
- The external register is an accepted work queue only. Every row remains
  artifact/terms/validation Pending.

## 4. Retained gates

- all markets remain **disabled**;
- external artifacts, license/terms and pinned ingestion evidence remain
  **Pending**;
- translations, service-area data and mandatory policy copy remain
  **Pending/Blocked**;
- independent Security/Privacy and applicable qualified Legal evidence remain
  **Pending**;
- `BCK20-OD-02` and `BCK20-OD-05` remain **Open**;
- `OD-10` remains **Proposed**, `BCK-20` remains **Draft** and
  `BCK20-OD-03` remains **Deferred**;
- network retrieval, provider selection, schema, IAM/runtime, Firebase,
  deployment and activation remain unauthorized;
- push and merge are outside this decision.

## 5. Verbatim owner instruction

> Одобряю BCK20-OD02-SRC-REC-REV-01 v0.1:
> Accept internal source-record documentation baseline and external evidence
> work queue with retained gates для точных BCK20-OD02-SRC-REC-01 v0.1 /
> SHA-256 c4b0bcda3c55524354547b0b7596e96488086abf166cae76526ecfe7ba4a8555
> и BCK20-OD02-EXT-EV-01 v0.1 / SHA-256
> faee6caaa2a65380c2e631c745669f32da20926502792560c657184bd3bf750d.
>
> Подтверждаю совмещение ролей RechargeN / Product owner и отсутствие
> independent или qualified Security/Privacy/Legal review.
>
> Все рынки остаются disabled. External artifacts, license/terms, pinned
> ingestion evidence, translations, service-area data и mandatory policy copy
> остаются Pending/Blocked/Deferred.
>
> BCK20-OD-02/05 остаются Open, OD-10 Proposed, BCK-20 Draft,
> BCK20-OD-03 Deferred. Network retrieval, provider selection, schema,
> IAM/runtime, Firebase, deployment, activation, push и merge не разрешаю.

## 6. Effect and rollback

Effective immediately for documentation reconciliation:

1. the 23 frozen internal records may be cited as accepted documentation
   source inputs at revision 1;
2. the six unresolved families retain their exact blocking state;
3. the eight external candidates may be cited only as an accepted evidence
   work queue, never as approved sources;
4. canonical BCK-20 and D1 records may record this bounded disposition;
5. no executable artifact or external system changes.

Rollback requires a superseding owner decision and atomic documentation
reconciliation. Deleting this record or silently restoring a prior status is
not rollback.

## 7. Acceptance criteria

1. **BCK20-OD02-SRC-REC-DEC-AC-01:** all three frozen inputs are identified by exact version and normalized hash.
2. **BCK20-OD02-SRC-REC-DEC-AC-02:** 23 internal records are accepted only as documentation source inputs.
3. **BCK20-OD02-SRC-REC-DEC-AC-03:** six unresolved families retain explicit Pending, Blocked or Deferred states.
4. **BCK20-OD02-SRC-REC-DEC-AC-04:** eight external candidates remain an evidence work queue with no ingestion authority.
5. **BCK20-OD02-SRC-REC-DEC-AC-05:** Latvia remains first-launch candidate without activation.
6. **BCK20-OD02-SRC-REC-DEC-AC-06:** Latvia, Estonia and Lithuania all remain disabled.
7. **BCK20-OD02-SRC-REC-DEC-AC-07:** locale/fallback acceptance creates no translation or mandatory-copy acceptance.
8. **BCK20-OD02-SRC-REC-DEC-AC-08:** currency/timezone inputs require pinned external evidence before executable use.
9. **BCK20-OD02-SRC-REC-DEC-AC-09:** missing policy references remain blocking records without latest/null fallback.
10. **BCK20-OD02-SRC-REC-DEC-AC-10:** shared ownership, zero independence and absent qualified claims remain explicit.
11. **BCK20-OD02-SRC-REC-DEC-AC-11:** BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and BCK20-OD-03 Deferred.
12. **BCK20-OD02-SRC-REC-DEC-AC-12:** network retrieval, provider, schema, IAM/runtime, Firebase, deployment and activation remain unauthorized.
13. **BCK20-OD02-SRC-REC-DEC-AC-13:** this decision authorizes no push or merge.
14. **BCK20-OD02-SRC-REC-DEC-AC-14:** any frozen target content/version/hash change requires a new review and decision.
15. **BCK20-OD02-SRC-REC-DEC-AC-15:** no external license, terms, artifact, parser or validation result is inferred.
16. **BCK20-OD02-SRC-REC-DEC-AC-16:** rollback requires an explicit superseding decision and atomic documentation reconciliation.
