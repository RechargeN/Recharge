# BCK-20 — External Evidence Collection Plan Owner Review

- ID: **BCK20-OD02-EXT-EV-PLAN-REV-01**
- Version: **0.2**
- Date: **2026-09-18**
- Status: **Owner decision recorded — EXT-G0 accepted with retained gates**
- Frozen target: [BCK20-OD02-EXT-EV-PLAN-01 v0.1](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_PLAN.md)
- Target normalized-LF SHA-256: `f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac`
- Parent register: [BCK20-OD02-EXT-EV-01 v0.2](REFERENCE_DATA_EXTERNAL_SOURCE_EVIDENCE_REGISTER.md)
- Decision record: [BCK20-OD02-EXT-EV-PLAN-DEC-01 v0.1](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_OWNER_DECISION.md)
- Recorded owner/signatory: **RechargeN / Product owner**
- Combined roles: **Reference Data + Product/Market + Product Localization/Content + Platform Operations + technical Security/Privacy**
- Independence: **none; combined-owner review**
- Qualified Security/Privacy/Legal claim: **none**
- Network authority: **none**
- Runtime effect: **none**

---

## 1. Purpose and recorded verdict

This package reviews the exact docs-only collection plan. It does not review a
live source, current license, downloaded artifact, parser, validation result or
execution authorization.

Recorded verdict:

> **Accept docs-only external evidence collection plan with retained gates**
> for the exact target revision and hash.

Acceptance makes the plan the required procedure for any later external
evidence work. It opens only `EXT-G0`; all network and execution gates remain
closed.

## 2. Frozen-input verification

| Check | Observed | Result |
|---|---|---|
| Target identity | `BCK20-OD02-EXT-EV-PLAN-01 v0.1` | Match |
| Normalized-LF SHA-256 | `f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac` | Match |
| Candidate sources | 8 | Match |
| Independent batches | 4 | Match |
| Execution phases | P0–P6 sequential | Match |
| Gates | EXT-G0–G6 sequential | Match |
| Acceptance criteria | AC-01–20 sequential | Match |
| Network/download/parser/runtime effect | none | Pass |

Any target content, version or normalized hash change invalidates this review.

## 3. Perspective reviews

### 3.1 Reference Data

- all eight accepted work-queue sources are covered;
- source identity, artifact identity, allowed use, validation and semantic
  field scope remain separate evidence dimensions;
- advancement stops at `eligible_for_slice_review` without ingestion.

Recommendation: **Accept procedure boundary**.

### 3.2 Product/Market and Localization/Content

- external sources cannot create Recharge market, locale, fallback, currency
  assignment, copy or activation policy;
- current internal documentation inputs remain unchanged;
- all markets remain disabled and no translation is produced.

Recommendation: **Accept with product/source gates retained**.

### 3.3 Platform Operations

- each run is bounded by exact source/origin/method/bytes/expiry and a temporary
  cleanup root;
- discovery, terms capture, download, inspection, parser design and disposition
  are separate phases;
- raw third-party content is not tracked by default.

Recommendation: **Accept operational plan only; no execution authority**.

### 3.4 Technical Security/Privacy

- credentials, authentication, paid access, click-through acceptance and
  control bypass are prohibited;
- redirect, TLS, content type, archive traversal, escaping link, nested archive
  and unexpected binary risks fail closed;
- no personal data, secrets, repository metadata or authenticated cookies are
  sent;
- this combined-owner review is not independent or qualified evidence.

Recommendation: **Accept technical boundary with retained gates**.

## 4. Findings and retained observations

| ID | Finding | Disposition |
|---|---|---|
| `EXT-PLAN-O-01` | The plan intentionally contains no live endpoints beyond inherited domain candidates | exact origins are discovered and separately authorized later |
| `EXT-PLAN-O-02` | No numeric byte caps are hardcoded before artifact discovery | every authorization must set exact per-artifact and total limits; omission denies |
| `EXT-PLAN-O-03` | Terms capture is itself a network operation | requires its named gate and does not imply terms acceptance |
| `EXT-PLAN-O-04` | ISO/SIX evidence may require restrictive terms, authentication or payment | stop; no bypass or account creation; source remains Pending |
| `EXT-PLAN-O-05` | Raw external content may be copyrighted or redistribution-limited | temporary quarantine only; repository storage requires a later exact decision |
| `EXT-PLAN-O-06` | Hash/signature validates identity/integrity, not semantic or legal fitness | dimensions remain separately reviewed |
| `EXT-PLAN-O-07` | Parser/fixture work could become executable implementation | explicitly deferred to a separate Approved exact-file slice |
| `EXT-PLAN-O-08` | One owner holds all five review perspectives | zero independence and absent qualified claim remain explicit |

No finding requires a plan amendment before documentation acceptance.

## 5. Effect of acceptance

If §8 is accepted exactly:

- the plan becomes the documentation authority for later evidence collection;
- `EXT-G0` is satisfied for the frozen plan only;
- `EXT-G1–G6` remain closed;
- a future owner may separately authorize one named batch for P1 discovery;
- no source state advances and no evidence is described as current;
- no network call, download, terms acceptance, parser, repository data, schema,
  Firebase or runtime is authorized.

## 6. Retained gates

- network access, redirects, artifact retrieval and terms capture remain
  unauthorized;
- every external source remains artifact/terms/validation Pending;
- qualified license/Legal and independent Security/Privacy evidence remain
  Pending;
- every market remains disabled;
- BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and
  BCK20-OD-03 Deferred;
- provider selection, schema, IAM/runtime, Firebase, deployment, activation,
  push and merge remain unauthorized.

## 7. Recorded signature record

```text
Decision input: BCK20-OD02-EXT-EV-PLAN-REV-01 v0.1
Target: BCK20-OD02-EXT-EV-PLAN-01 v0.1
Target normalized-LF SHA-256: f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac
Named reviewer identity: RechargeN / Product owner
Combined roles: Reference Data; Product/Market; Product Localization/Content; Platform Operations; technical Security/Privacy
Independence: none; combined-owner review
Qualified Security/Privacy/Legal claim: none
Recorded verdict: Accept docs-only external evidence collection plan with retained gates
Network authority: none
Runtime authority: none
```

## 8. Recorded exact owner decision

```text
Одобряю BCK20-OD02-EXT-EV-PLAN-REV-01 v0.1:
Accept docs-only external evidence collection plan with retained gates для
точного BCK20-OD02-EXT-EV-PLAN-01 v0.1 / SHA-256
f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac.
Подтверждаю совмещение ролей RechargeN / Product owner для Reference Data,
Product/Market, Product Localization/Content, Platform Operations и technical
Security/Privacy, отсутствие independent review и отсутствие qualified
Security/Privacy/Legal claim.
Принятие открывает только EXT-G0 documentation baseline. EXT-G1–G6, network
access, redirects, terms capture/acceptance, downloads, external artifacts,
parser/fixture work, repository data и ingestion остаются unauthorized.
Все markets остаются disabled; BCK20-OD-02/05 Open, OD-10 Proposed, BCK-20
Draft, BCK20-OD-03 Deferred. Provider selection, schema, IAM/runtime, Firebase,
deployment, activation, push и merge не разрешаю.
```

## 9. Acceptance criteria

1. **BCK20-OD02-EXT-EV-PLAN-REV-AC-01:** the exact target version and normalized hash are frozen.
2. **BCK20-OD02-EXT-EV-PLAN-REV-AC-02:** all eight sources, four batches, seven phases and seven gates are reviewed.
3. **BCK20-OD02-EXT-EV-PLAN-REV-AC-03:** acceptance opens EXT-G0 only.
4. **BCK20-OD02-EXT-EV-PLAN-REV-AC-04:** EXT-G1–G6 remain closed pending their exact evidence and authorization.
5. **BCK20-OD02-EXT-EV-PLAN-REV-AC-05:** no network request, redirect or download is authorized.
6. **BCK20-OD02-EXT-EV-PLAN-REV-AC-06:** no terms/license capture, acceptance or qualified conclusion is inferred.
7. **BCK20-OD02-EXT-EV-PLAN-REV-AC-07:** authentication, payment, click-through and control bypass remain prohibited.
8. **BCK20-OD02-EXT-EV-PLAN-REV-AC-08:** raw external content remains temporary and untracked by default.
9. **BCK20-OD02-EXT-EV-PLAN-REV-AC-09:** artifact identity, allowed use, validation and semantic scope remain separate.
10. **BCK20-OD02-EXT-EV-PLAN-REV-AC-10:** parser and fixture work require a separate Approved exact-file slice.
11. **BCK20-OD02-EXT-EV-PLAN-REV-AC-11:** five combined roles remain attributable with zero independence.
12. **BCK20-OD02-EXT-EV-PLAN-REV-AC-12:** no independent or qualified Security/Privacy/Legal claim is created.
13. **BCK20-OD02-EXT-EV-PLAN-REV-AC-13:** all sources and markets retain their current fail-closed state.
14. **BCK20-OD02-EXT-EV-PLAN-REV-AC-14:** BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and BCK20-OD-03 Deferred.
15. **BCK20-OD02-EXT-EV-PLAN-REV-AC-15:** provider, schema, IAM/runtime, Firebase, deployment and activation remain unauthorized.
16. **BCK20-OD02-EXT-EV-PLAN-REV-AC-16:** no push or merge is authorized.
17. **BCK20-OD02-EXT-EV-PLAN-REV-AC-17:** any target content/version/hash change requires a new review and owner decision.
18. **BCK20-OD02-EXT-EV-PLAN-REV-AC-18:** canonical status reconciliation waits for the exact owner decision.

## 10. Recorded disposition and next action

BCK20-OD02-EXT-EV-PLAN-DEC-01 accepts this review's frozen v0.1 target and the
review itself at normalized-LF SHA-256
`f23fcf6052fd02901319c072b29f1b4a263fbef0729c741d7cab3aed3664762b`.
Only EXT-G0 is satisfied. EXT-G1–G6, network, terms capture, artifacts,
parser/fixture work, repository data, ingestion and runtime remain outside the
accepted scope.
