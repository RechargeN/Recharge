# BCK-20 — EXT-G1 Batch EXT-A Authorization Decision

- ID: **BCK20-OD02-EXT-EV-G1-DEC-01**
- Version: **0.1**
- Date: **2026-09-18**
- Recorded at: **2026-09-18T20:39:38+03:00**
- Status: **Authorized — EXT-A P1 metadata discovery with exact controls**
- Owner/signatory: **RechargeN / Product owner**
- Combined roles: **Reference Data + Product/Market + Platform Operations + technical Security/Privacy**
- Independence: **None — all four roles are held by the same owner**
- Qualified Security/Privacy/Legal claim: **None**
- Frozen authorization: [BCK20-OD02-EXT-EV-G1-AUTH-01 v0.1](REFERENCE_DATA_EXTERNAL_EVIDENCE_EXT_G1_AUTHORIZATION.md)
- Frozen review: [BCK20-OD02-EXT-EV-G1-REV-01 v0.1](REFERENCE_DATA_EXTERNAL_EVIDENCE_EXT_G1_OWNER_REVIEW.md)
- Authorization instance: **aba31978-ab80-4ca5-9d57-c976e54ebcb2**
- Expires: **2026-09-19T18:00:00Z**
- Runtime authority: **None**

---

## 1. Decision

The owner authorizes EXT-G1 Batch EXT-A P1 metadata discovery under the exact
frozen envelope. The authorization permits sequential GET requests to the two
named IANA landing URIs and bounded same-origin TLS redirects only.

It does not authorize artifact, checksum/signature or terms links; downloads,
terms capture/acceptance, archive inspection, parser/fixture work, repository
or cloud writes, ingestion, schema or runtime.

## 2. Frozen evidence

Hashes are SHA-256 over UTF-8 bytes after CRLF-to-LF normalization.

| Artifact | Frozen version | SHA-256 |
|---|---|---|
| Authorization request | `BCK20-OD02-EXT-EV-G1-AUTH-01 v0.1` | `a1c8f27c97ca02dd514097943431ff504d0826066b9f75288088e087b40de1f6` |
| Owner review | `BCK20-OD02-EXT-EV-G1-REV-01 v0.1` | `15bd131a2ca88865183785f199613474999e00786034acec2cd5da2a04ccd28d` |

Any content, version, normalized-hash or authorization-envelope change
requires a new review and decision.

## 3. Exact authorized envelope

- instance: `aba31978-ab80-4ca5-9d57-c976e54ebcb2`;
- scope: EXT-G1 / EXT-A / P1 metadata discovery only;
- sources: `SRC-IANA-LANG`, `SRC-IANA-TZDB`;
- initial URIs: the two exact `https://www.iana.org` landing URIs in the frozen
  authorization;
- method: sequential GET only;
- redirects: same-origin TLS only, maximum 3 per request;
- maximum: 4 total requests, 2 MiB per response, 4 MiB total;
- no credentials, cookies, request body or automatic retries;
- evidence: exact authorization-specific temporary root only;
- expiry: `2026-09-19T18:00:00Z`.

## 4. Retained gates

- artifact/terms/checksum/signature links may be recorded but not followed;
- EXT-G2–G6 remain closed;
- all external sources remain artifact/terms/validation Pending;
- all markets remain disabled;
- BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and
  BCK20-OD-03 Deferred;
- provider selection, schema, IAM/runtime, Firebase, deployment and activation
  remain unauthorized;
- push and merge are outside this decision.

## 5. Verbatim owner instruction

> Одобряю BCK20-OD02-EXT-EV-G1-REV-01 v0.1 и разрешаю bounded network access:
> Authorize EXT-G1 Batch EXT-A P1 metadata discovery with exact controls для
> BCK20-OD02-EXT-EV-G1-AUTH-01 v0.1 / SHA-256
> a1c8f27c97ca02dd514097943431ff504d0826066b9f75288088e087b40de1f6,
> authorization instance aba31978-ab80-4ca5-9d57-c976e54ebcb2.
> Разрешаю только sequential GET к двум exact
> [https://www.iana.org](https://www.iana.org) landing URI,
> same-origin TLS redirects до 3, максимум 4 requests, 2 MiB per response и
> 4 MiB total, без credentials/cookies/request body, до
> 2026-09-19T18:00:00Z, с evidence только в exact temporary root из документа.
> Artifact/terms/checksum/signature links разрешено только записать, но не
> переходить по ним. Downloads, terms capture/acceptance, archives,
> parser/fixtures, repository/CI/Firebase/cloud writes и ingestion не разрешаю.
> Подтверждаю совмещение ролей RechargeN / Product owner, отсутствие independent
> review и отсутствие qualified Security/Privacy/Legal claim.
> EXT-G2–G6 и все markets остаются closed/disabled; BCK20-OD-02/05 Open,
> OD-10 Proposed, BCK-20 Draft, BCK20-OD-03 Deferred. Provider, schema,
> IAM/runtime, deployment, activation, push и merge не разрешаю.

## 6. Effect and rollback

Effective immediately and until expiry:

1. P0 may create the exact temporary evidence root;
2. P1 may issue only the requests in the frozen envelope;
3. execution must stop after candidate-link inventory and typed result;
4. evidence remains temporary and untracked pending owner disposition;
5. no canonical status is promoted merely because the run executes.

Cancellation stops further requests. Temporary cleanup is limited to the
verified authorization-specific root. No cloud or production rollback exists.

## 7. Acceptance criteria

1. **BCK20-OD02-EXT-EV-G1-DEC-AC-01:** authorization request and review are frozen by exact version and normalized hash.
2. **BCK20-OD02-EXT-EV-G1-DEC-AC-02:** the exact authorization instance and expiry are recorded.
3. **BCK20-OD02-EXT-EV-G1-DEC-AC-03:** authorization is limited to EXT-G1/EXT-A/P1.
4. **BCK20-OD02-EXT-EV-G1-DEC-AC-04:** exactly two IANA landing URIs and sequential GET are authorized.
5. **BCK20-OD02-EXT-EV-G1-DEC-AC-05:** redirect, request-count, media-type and byte controls remain exact.
6. **BCK20-OD02-EXT-EV-G1-DEC-AC-06:** credentials, cookies, request bodies and automatic retries remain prohibited.
7. **BCK20-OD02-EXT-EV-G1-DEC-AC-07:** artifact/terms/checksum/signature links may be recorded only and never followed.
8. **BCK20-OD02-EXT-EV-G1-DEC-AC-08:** run evidence is temporary and repository/cloud writes remain prohibited.
9. **BCK20-OD02-EXT-EV-G1-DEC-AC-09:** pass can prove only P1 metadata discovery.
10. **BCK20-OD02-EXT-EV-G1-DEC-AC-10:** shared ownership and zero independence remain explicit.
11. **BCK20-OD02-EXT-EV-G1-DEC-AC-11:** no independent or qualified Security/Privacy/Legal claim is created.
12. **BCK20-OD02-EXT-EV-G1-DEC-AC-12:** EXT-G2–G6 and all market/BCK/OD/runtime gates remain closed.
13. **BCK20-OD02-EXT-EV-G1-DEC-AC-13:** no push or merge is authorized.
14. **BCK20-OD02-EXT-EV-G1-DEC-AC-14:** envelope change or expiry requires a new authorization decision.
