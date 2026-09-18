# BCK-20 — EXT-G1 Batch EXT-A Follow-up P1 Owner Review

- ID: `BCK20-OD02-EXT-EV-G1-FU-REV-01`
- Version: `0.1`
- Status: **Review — owner decision required**
- Reviewed request: `BCK20-OD02-EXT-EV-G1-FU-AUTH-01` v0.1
- Exact request normalized-LF SHA-256:
  `46e25cb53bf8b6a5c34c460ed698ee164c8e8e605ed74c4a6c63dd29f87b55ec`
- Authorization instance: `3d66a7bd-cc68-4245-9a26-bdcd1bda767c`
- Review boundary: RechargeN / Product owner combined technical review;
  no independent or qualified Security/Privacy/Legal claim

## 1. Review question

Should the owner authorize one metadata-only `HEAD` run against the two exact
candidate endpoints found in the accepted EXT-A P1 evidence?

Recommended verdict:

> **Authorize EXT-G1 Batch EXT-A follow-up P1 endpoint metadata with exact
> HEAD-only controls.**

This review grants no network authority by itself.

## 2. Preconditions

| Precondition | Evidence | Result |
|---|---|---|
| Accepted collection plan | `BCK20-OD02-EXT-EV-PLAN-DEC-01` | Met |
| Accepted initial P1 execution | `BCK20-OD02-EXT-EV-G1-EXEC-DEC-01` | Met |
| Exact reviewed P1 hash | `ec9acd16...e5b15fd` | Met |
| Exact two candidate URIs | section 7 of the accepted execution review | Met |
| New authorization-specific temp root | request section 2 | Met |
| Network remains closed pending decision | request status and AC-12 | Met |

## 3. Why HEAD-only is proportionate

The candidate language URI may directly return registry data, and the TZDB URI
may be a release page, redirect or artifact endpoint. A `GET` would risk
crossing from metadata discovery into artifact acquisition. `HEAD` provides the
minimum useful evidence: status, content type/length/disposition, redirect and
final endpoint, without requesting or retaining a response body.

If either server does not support `HEAD`, the run stops with
`head_not_supported`. It may not fall back to `GET`. This preserves the
P1/P3 boundary.

## 4. Exact control review

| Control | Requested rule | Review |
|---|---|---|
| Sources | `SRC-IANA-LANG`, `SRC-IANA-TZDB` only | exact |
| Origin | `https://www.iana.org:443` only | exact |
| Initial URIs | two exact candidate URIs | exact |
| Method | `HEAD` only | least privilege |
| Body handling | no read and no storage | fail-closed |
| Redirects | one same-origin TLS redirect per source; preserve HEAD | bounded |
| Request count | maximum four including redirects | bounded |
| Ordering/rate | sequential; at least 1 second between requests | bounded |
| Retries/fallback | zero retries; no GET fallback | fail-closed |
| Identity state | no credentials, cookies or request body | safe |
| Metadata | selected headers only; maximum 512 KiB serialized | bounded |
| Expiry | `2026-09-20T18:00:00Z` | exact |
| Storage | new exact OS-temp root | isolated |
| Prior evidence | retain unchanged | exact |
| Repository/cloud/runtime | denied | retained |

## 5. Risk and stop-condition review

| Risk | Control | Residual disposition |
|---|---|---|
| Candidate resolves directly to an artifact | HEAD only; no body read | endpoint metadata only |
| Candidate redirects to another origin | record permitted Location metadata and stop | new decision required |
| Server rejects HEAD | no GET fallback | retain Pending |
| Multiple redirect hops | stop after one | retain Pending |
| Response metadata is ambiguous | typed `endpoint_ambiguous` | retain Pending |
| Authentication/click-through appears | stop | no workaround permitted |
| External content reaches repository | only selected metadata in exact temp root | raw/external content remains untracked |
| Previous evidence is lost | deletion explicitly denied | retain pending later disposition |
| Transport success is over-read as source approval | pass definition is endpoint metadata only | all source/gates remain Pending/closed |

## 6. Retained non-authority

Approval would not authorize:

- any `GET`, response body, terms capture or artifact acquisition;
- checksum/signature retrieval, archive inspection or parser work;
- repository/CI data, fixture, schema or ingestion changes;
- source approval, provider selection or market activation;
- EXT-G2–G6;
- IAM/runtime, Firebase, cloud, deployment or activation;
- push or merge;
- an independent or qualified Security/Privacy/Legal conclusion.

## 7. Proposed exact owner wording

```text
Одобряю BCK20-OD02-EXT-EV-G1-FU-REV-01 v0.1:
Authorize EXT-G1 Batch EXT-A follow-up P1 endpoint metadata with exact HEAD-only
controls для BCK20-OD02-EXT-EV-G1-FU-AUTH-01 v0.1 / SHA-256
46e25cb53bf8b6a5c34c460ed698ee164c8e8e605ed74c4a6c63dd29f87b55ec,
authorization instance 3d66a7bd-cc68-4245-9a26-bdcd1bda767c.

Разрешаю только sequential HEAD к двум exact URI, один same-origin TLS redirect
на source, максимум 4 requests including redirects, zero response-body
read/storage, selected metadata до 512 KiB, без credentials/cookies/request
body/retry/GET fallback, до 2026-09-20T18:00:00Z, с evidence только в exact
temporary root из документа. Предыдущие temporary evidence сохранить.

GET, response bodies, terms capture/acceptance, artifact/checksum/signature
acquisition, archives, parser/fixtures, repository/CI/Firebase/cloud writes,
ingestion, deployment, activation, push и merge не разрешаю. EXT-G2–G6 и все
markets остаются closed/disabled; source/BCK/OD статусы не повышаются.
```

## 8. Acceptance criteria

1. **BCK20-OD02-EXT-EV-G1-FU-REV-AC-01:** the review binds to the exact authorization-request hash and instance.
2. **BCK20-OD02-EXT-EV-G1-FU-REV-AC-02:** prerequisites include the accepted initial P1 execution and its exact review hash.
3. **BCK20-OD02-EXT-EV-G1-FU-REV-AC-03:** HEAD-only is justified as the least-privilege method for endpoint classification.
4. **BCK20-OD02-EXT-EV-G1-FU-REV-AC-04:** exact sources, origin, URIs, redirect count, request count, expiry and temporary root are reviewed.
5. **BCK20-OD02-EXT-EV-G1-FU-REV-AC-05:** response-body access and GET fallback are explicitly denied.
6. **BCK20-OD02-EXT-EV-G1-FU-REV-AC-06:** unsupported HEAD, disallowed redirects and ambiguous metadata retain Pending state.
7. **BCK20-OD02-EXT-EV-G1-FU-REV-AC-07:** prior temporary evidence remains retained unchanged.
8. **BCK20-OD02-EXT-EV-G1-FU-REV-AC-08:** successful transport proves only endpoint metadata.
9. **BCK20-OD02-EXT-EV-G1-FU-REV-AC-09:** EXT-G2–G6, source/market/BCK/OD/runtime and deployment gates remain closed.
10. **BCK20-OD02-EXT-EV-G1-FU-REV-AC-10:** the review itself grants no network, repository, cloud, push or merge authority.

