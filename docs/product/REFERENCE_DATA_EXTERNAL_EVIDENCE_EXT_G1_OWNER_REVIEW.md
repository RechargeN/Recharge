# BCK-20 — EXT-G1 Batch EXT-A Authorization Owner Review

- ID: **BCK20-OD02-EXT-EV-G1-REV-01**
- Version: **0.1**
- Date: **2026-09-18**
- Status: **Proposed — exact owner decision and network authorization required**
- Frozen target: [BCK20-OD02-EXT-EV-G1-AUTH-01 v0.1](REFERENCE_DATA_EXTERNAL_EVIDENCE_EXT_G1_AUTHORIZATION.md)
- Target normalized-LF SHA-256: `a1c8f27c97ca02dd514097943431ff504d0826066b9f75288088e087b40de1f6`
- Accepted plan: [BCK20-OD02-EXT-EV-PLAN-01 v0.2](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_PLAN.md)
- Plan decision: [BCK20-OD02-EXT-EV-PLAN-DEC-01 v0.1](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_OWNER_DECISION.md)
- Proposed owner/signatory: **RechargeN / Product owner**
- Combined roles: **Reference Data + Product/Market + Platform Operations + technical Security/Privacy**
- Independence: **none; combined-owner review**
- Qualified Security/Privacy/Legal claim: **none**
- Current network authority: **none**
- Runtime effect: **none**

---

## 1. Purpose and recommended verdict

This package reviews one exact authorization request for P1 metadata discovery
on two IANA landing pages. It does not review live content or evidence results.

Recommended verdict:

> **Authorize EXT-G1 Batch EXT-A P1 metadata discovery with exact controls**
> for the frozen request and authorization instance.

The verdict would authorize only the bounded network requests described in the
target and only until `2026-09-19T18:00:00Z`. It would not authorize artifact
or terms links, downloads, terms acceptance, parser work, repository writes,
ingestion, schema, Firebase or runtime.

## 2. Frozen-input verification

| Check | Observed | Result |
|---|---|---|
| Target identity | `BCK20-OD02-EXT-EV-G1-AUTH-01 v0.1` | Match |
| Normalized-LF SHA-256 | `a1c8f27c97ca02dd514097943431ff504d0826066b9f75288088e087b40de1f6` | Match |
| Authorization instance | `aba31978-ab80-4ca5-9d57-c976e54ebcb2` | Match |
| Gate/batch | EXT-G1 / EXT-A / P1 only | Match |
| Sources | `SRC-IANA-LANG`, `SRC-IANA-TZDB` | Match |
| Initial URIs | two exact `https://www.iana.org` landing URIs | Match |
| Methods | GET only | Match |
| Limits | 2 MiB/response, 4 MiB/run, 4 requests max | Match |
| Redirects | same-origin TLS only, maximum 3 | Match |
| Expiry | `2026-09-19T18:00:00Z` | Match |
| Acceptance criteria | AC-01–18 sequential | Match |

Any target content/version/hash or authorization-envelope change invalidates
this review. A decision recorded after expiry authorizes nothing.

## 3. Review perspectives

### 3.1 Reference Data

- P1 can discover candidate registry/release/checksum/terms links without
  asserting source fitness;
- candidate links remain strings only and are not followed;
- evidence can close only EXT-G1 metadata discovery, not source approval.

Recommendation: **Authorize exact P1 scope**.

### 3.2 Platform Operations

- request count, sequencing, delay, redirect count, media types, byte limits,
  expiry and temporary root are exact;
- there are no automatic retries; unused request allowance does not broaden
  scope;
- cleanup and rollback target one authorization-specific temporary directory.

Recommendation: **Authorize with exact operational controls**.

### 3.3 Technical Security/Privacy

- one HTTPS origin and two initial URIs are allowed;
- cross-origin/non-TLS redirects, credentials, cookies and request bodies are
  denied;
- no personal data, repository metadata, authenticated session or secret is
  transmitted;
- unexpected content, size or authorization ambiguity fails closed;
- this combined-owner review is not independent Security/Privacy evidence.

Recommendation: **Authorize bounded discovery; retain every later gate**.

### 3.4 Product/Market

- discovery cannot change supported markets, locales, currencies, zones or
  activation;
- all markets remain disabled;
- external source observations cannot create Recharge product policy.

Recommendation: **No product objection within frozen scope**.

## 4. Findings and retained observations

| ID | Finding | Disposition |
|---|---|---|
| `EXT-G1-O-01` | Landing pages may redirect to a different IANA path | same-origin TLS redirects allowed and fully recorded; other redirects denied |
| `EXT-G1-O-02` | Candidate data/terms links may use another origin | record string only; do not follow; later authorization required |
| `EXT-G1-O-03` | GET response may exceed expected landing-page size | abort at exact per-response/aggregate limits |
| `EXT-G1-O-04` | A transport interruption could consume a request | no automatic retry; owner-directed retry only within remaining count/validity |
| `EXT-G1-O-05` | Temporary landing-page bytes are external content | keep only in exact temp root pending retention/delete disposition |
| `EXT-G1-O-06` | Expiry is deliberately short | decision/run after expiry is invalid and requires a new authorization artifact |
| `EXT-G1-O-07` | Same owner holds four perspectives | zero independence and absent qualified claim remain explicit |

No finding broadens the request or permits execution before exact approval.

## 5. Effect of acceptance

If §8 is accepted exactly and before expiry:

- network access is authorized only for the two exact initial GET requests and
  permitted same-origin redirects;
- P0 and P1 may run within the frozen envelope;
- run evidence may be written only to the exact temporary root;
- the run stops after candidate-link inventory and typed result;
- EXT-G2–G6 remain closed;
- canonical statuses do not change until execution evidence is reviewed;
- no push or merge is authorized.

## 6. Retained gates

- terms/artifact/checksum/signature candidate links may not be followed;
- downloads, terms acceptance, archive inspection, parser/fixture execution,
  repository writes and ingestion remain unauthorized;
- every source remains artifact/terms/validation Pending;
- all markets remain disabled;
- BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and
  BCK20-OD-03 Deferred;
- provider selection, schema, IAM/runtime, Firebase, deployment, activation,
  push and merge remain unauthorized.

## 7. Proposed authorization record

```text
Decision input: BCK20-OD02-EXT-EV-G1-REV-01 v0.1
Target: BCK20-OD02-EXT-EV-G1-AUTH-01 v0.1
Target normalized-LF SHA-256: a1c8f27c97ca02dd514097943431ff504d0826066b9f75288088e087b40de1f6
Authorization instance: aba31978-ab80-4ca5-9d57-c976e54ebcb2
Gate/batch: EXT-G1 / EXT-A / P1 metadata discovery only
Initial URIs: exact two www.iana.org HTTPS landing URIs in target
Expiry: 2026-09-19T18:00:00Z
Named owner: RechargeN / Product owner
Combined roles: Reference Data; Product/Market; Platform Operations; technical Security/Privacy
Independence: none
Qualified Security/Privacy/Legal claim: none
Proposed verdict: Authorize EXT-G1 Batch EXT-A P1 metadata discovery with exact controls
Runtime authority: none
```

## 8. Exact owner decision and network authorization requested

```text
Одобряю BCK20-OD02-EXT-EV-G1-REV-01 v0.1 и разрешаю bounded network access:
Authorize EXT-G1 Batch EXT-A P1 metadata discovery with exact controls для
BCK20-OD02-EXT-EV-G1-AUTH-01 v0.1 / SHA-256
a1c8f27c97ca02dd514097943431ff504d0826066b9f75288088e087b40de1f6,
authorization instance aba31978-ab80-4ca5-9d57-c976e54ebcb2.
Разрешаю только sequential GET к двум exact https://www.iana.org landing URI,
same-origin TLS redirects до 3, максимум 4 requests, 2 MiB per response и
4 MiB total, без credentials/cookies/request body, до
2026-09-19T18:00:00Z, с evidence только в exact temporary root из документа.
Artifact/terms/checksum/signature links разрешено только записать, но не
переходить по ним. Downloads, terms capture/acceptance, archives,
parser/fixtures, repository/CI/Firebase/cloud writes и ingestion не разрешаю.
Подтверждаю совмещение ролей RechargeN / Product owner, отсутствие independent
review и отсутствие qualified Security/Privacy/Legal claim.
EXT-G2–G6 и все markets остаются closed/disabled; BCK20-OD-02/05 Open,
OD-10 Proposed, BCK-20 Draft, BCK20-OD-03 Deferred. Provider, schema,
IAM/runtime, deployment, activation, push и merge не разрешаю.
```

## 9. Acceptance criteria

1. **BCK20-OD02-EXT-EV-G1-REV-AC-01:** exact target, hash and authorization instance are frozen.
2. **BCK20-OD02-EXT-EV-G1-REV-AC-02:** authorization is limited to EXT-G1/EXT-A/P1.
3. **BCK20-OD02-EXT-EV-G1-REV-AC-03:** exactly two IANA sources and two initial HTTPS landing URIs are allowed.
4. **BCK20-OD02-EXT-EV-G1-REV-AC-04:** method, redirects, request count, delay, media types and byte limits are exact.
5. **BCK20-OD02-EXT-EV-G1-REV-AC-05:** credentials, cookies, request bodies and automatic retries are prohibited.
6. **BCK20-OD02-EXT-EV-G1-REV-AC-06:** authorization expires exactly and cannot be inferred after expiry.
7. **BCK20-OD02-EXT-EV-G1-REV-AC-07:** artifact/terms/checksum/signature links are recorded only and never followed.
8. **BCK20-OD02-EXT-EV-G1-REV-AC-08:** run evidence stays in the exact temporary root and remains untracked.
9. **BCK20-OD02-EXT-EV-G1-REV-AC-09:** typed failure/incomplete outcomes fail closed.
10. **BCK20-OD02-EXT-EV-G1-REV-AC-10:** pass proves only P1 metadata discovery.
11. **BCK20-OD02-EXT-EV-G1-REV-AC-11:** combined ownership and zero independence remain explicit.
12. **BCK20-OD02-EXT-EV-G1-REV-AC-12:** no independent or qualified Security/Privacy/Legal claim is created.
13. **BCK20-OD02-EXT-EV-G1-REV-AC-13:** EXT-G2–G6 and every source/market/BCK/OD/runtime gate remain closed.
14. **BCK20-OD02-EXT-EV-G1-REV-AC-14:** repository, CI, Firebase, cloud, parser and ingestion writes are unauthorized.
15. **BCK20-OD02-EXT-EV-G1-REV-AC-15:** no push or merge is authorized.
16. **BCK20-OD02-EXT-EV-G1-REV-AC-16:** any target/hash/envelope change or expiry requires a new review and decision.

## 10. Next action

Obtain the exact owner decision in §8 before expiry. Until it is recorded, no
P0 setup, temporary directory creation or network request is authorized.
