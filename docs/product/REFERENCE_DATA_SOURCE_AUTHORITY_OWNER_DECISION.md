# BCK-20 — Source-Authority Combined-Owner Decision Record

- ID: **BCK20-OD02-SRC-AUTH-DEC-01**
- Version: **0.1**
- Date: **2026-09-17**
- Recorded at: **2026-09-17T18:44:17+03:00**
- Status: **Accepted source-authority design boundary with retained gates**
- Owner/signatory: **RechargeN / Product owner**
- Combined roles: **Reference Data + Product/Market + Product Localization + Content/source governance + Mobile + technical Security/Privacy**
- Independence: **None — all six roles are held by the same owner**
- Qualified Security/Privacy/Legal claim: **None**
- Frozen matrix: [BCK20-OD02-SRC-AUTH-01 v0.1](REFERENCE_DATA_SOURCE_AUTHORITY_MATRIX.md)
- Frozen review: [BCK20-OD02-SRC-AUTH-REV-01 v0.1](REFERENCE_DATA_SOURCE_AUTHORITY_OWNER_REVIEW.md)
- Exact workflow: [BCK20-OD02-L10N-01 v0.4](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Runtime authority: **None**

---

## 1. Decision

The owner accepts the frozen source-authority matrix as a documentation design
boundary with retained gates. The six review perspectives remain separately
attributable even though one disclosed owner holds every role. This is
zero-independence combined-owner evidence, not independent or qualified
professional review.

Acceptance establishes the vocabulary, field-level authority assignments,
ownership, conflicts and fail-closed behavior for future source records. It
does not approve an actual source record, translation, license, ingestion,
provider, schema or executable use.

## 2. Frozen evidence

Hashes are SHA-256 over UTF-8 bytes after CRLF-to-LF normalization.

| Artifact | Frozen version | SHA-256 |
|---|---|---|
| Source-authority matrix | `BCK20-OD02-SRC-AUTH-01 v0.1` | `3b4701e0d285c4de076e7ae4f526b4f47942cd30f7f4383e3ef5de49c3a6eff6` |
| Combined-owner review | `BCK20-OD02-SRC-AUTH-REV-01 v0.1` | `0328af26c4d0ca9fdd2a5fd9a5b64a75b10c4daec03b696c593f518683561f6f` |
| Translation workflow | `BCK20-OD02-L10N-01 v0.4` | `d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975` |

Any content, version or normalized-hash change requires a new review and
decision. Later status annotations do not alter the frozen v0.1 evidence.

## 3. Authority disposition

- Recharge-owned policy and semantic records require explicit internal source
  records owned by the named product or governance owner.
- An official external registry is only a candidate authority for the bounded
  fields named in the matrix; it is not general product authority.
- License/terms evaluation, pinned ingestion evidence and executable use of an
  external source remain **Pending**.
- Any unresolved source record stays **Pending**, **Blocked** or **Deferred**
  and must fail closed according to the matrix.
- Cached, translated, indexed, provider-returned or distributed values do not
  become semantic authority.

## 4. Retained gates

The following remain unchanged:

- `BCK20-OD-02` and `BCK20-OD-05` are **Open**;
- `OD-10` is **Proposed** and `BCK-20` is **Draft**;
- `BCK20-OD-03` is **Deferred**;
- unresolved source records and independent Security/Privacy evidence remain
  **Pending/Blocked/Deferred** as applicable;
- applicable qualified Legal evidence remains **Pending**;
- provider selection, schema, IAM/runtime, Firebase, deployment and activation
  remain unauthorized;
- push and merge are outside this decision.

## 5. Verbatim owner instruction

> Одобряю BCK20-OD02-SRC-AUTH-REV-01 v0.1:
> Accept source-authority design boundary with retained gates для точного
> BCK20-OD02-SRC-AUTH-01 v0.1 / SHA-256
> 3b4701e0d285c4de076e7ae4f526b4f47942cd30f7f4383e3ef5de49c3a6eff6.
> Подтверждаю совмещение ролей RechargeN / Product owner для Reference Data,
> Product/Market, Product Localization, Content/source governance, Mobile и
> technical Security/Privacy, отсутствие independent review и отсутствие
> qualified Security/Privacy/Legal claim.
> Внешние registry остаются candidate authority только в указанном field scope;
> license/terms, pinned ingestion evidence и executable use остаются Pending.
> BCK20-OD-02 и BCK20-OD-05 остаются Open; OD-10 остаётся Proposed; BCK-20
> остаётся Draft; BCK20-OD-03 остаётся Deferred. Unresolved source records,
> independent Security/Privacy и applicable qualified Legal evidence остаются
> Pending/Blocked/Deferred. Provider selection, schema, IAM/runtime, Firebase,
> deployment, activation, push и merge не разрешаю.

## 6. Effect and rollback

Effective immediately for documentation reconciliation:

1. the frozen matrix may be cited as an accepted source-authority design
   boundary;
2. each of the six combined-owner perspectives remains separately
   attributable with zero independence disclosed;
3. canonical BCK-20 and D1 records may record this bounded disposition while
   preserving every retained gate;
4. no executable artifact or external system changes.

Rollback requires a superseding owner decision and atomic documentation
reconciliation. Deleting this record or silently restoring a prior status is
not rollback.

## 7. Acceptance criteria

1. **BCK20-OD02-SRC-AUTH-DEC-AC-01:** the decision freezes the exact matrix v0.1 identity and normalized hash.
2. **BCK20-OD02-SRC-AUTH-DEC-AC-02:** the review v0.1 and workflow v0.4 are frozen by identity and normalized hash.
3. **BCK20-OD02-SRC-AUTH-DEC-AC-03:** all six perspectives remain separately attributable.
4. **BCK20-OD02-SRC-AUTH-DEC-AC-04:** shared ownership and zero independence are explicit.
5. **BCK20-OD02-SRC-AUTH-DEC-AC-05:** no independent or qualified Security/Privacy/Legal claim is created.
6. **BCK20-OD02-SRC-AUTH-DEC-AC-06:** official external sources remain candidate authorities only for their bounded field scope.
7. **BCK20-OD02-SRC-AUTH-DEC-AC-07:** license/terms, pinned ingestion evidence and executable use remain Pending.
8. **BCK20-OD02-SRC-AUTH-DEC-AC-08:** unresolved source records retain their Pending, Blocked or Deferred state and fail closed.
9. **BCK20-OD02-SRC-AUTH-DEC-AC-09:** BCK20-OD-02 and BCK20-OD-05 remain Open.
10. **BCK20-OD02-SRC-AUTH-DEC-AC-10:** OD-10 remains Proposed, BCK-20 remains Draft and BCK20-OD-03 remains Deferred.
11. **BCK20-OD02-SRC-AUTH-DEC-AC-11:** provider selection, schema, IAM/runtime, Firebase, deployment and activation remain unauthorized.
12. **BCK20-OD02-SRC-AUTH-DEC-AC-12:** this record authorizes no push or merge.
13. **BCK20-OD02-SRC-AUTH-DEC-AC-13:** any frozen artifact or hash change requires a new review and decision.
14. **BCK20-OD02-SRC-AUTH-DEC-AC-14:** no source record, translation, dataset or ingestion is approved by implication.
15. **BCK20-OD02-SRC-AUTH-DEC-AC-15:** rollback requires an explicit superseding decision and atomic documentation reconciliation.
