# BCK-20 — EXT-C P1/P2 Authorization Request

- ID: **BCK20-OD02-EXT-C-P1P2-AUTH-01**
- Version: **0.1**
- Date: **2026-09-19**
- Status: **Proposed — no network authority until exact owner decision**
- Authorization instance: **bb28a9bf-c907-489b-b321-c58983aecdca**
- Accepted plan: [BCK20-OD02-EXT-EV-PLAN-01 v0.2](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_PLAN.md)
- Frozen plan normalized-LF SHA-256:
  `f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac`
- Requested batch: **EXT-C — `SRC-UN-M49`, `SRC-EU-EURO`**
- Requested work: **combined bounded P1 metadata discovery and P2 terms capture**
- Runtime effect: **none**

## 1. Purpose and bounded variance

This request covers one sequential discovery run for the two official
public-institution sources in EXT-C. It may capture four exact public pages:
the UN M49 landing page, UN terms of use, the European Commission euro-area
record and the Commission legal notice.

The accepted collection plan normally separates P1 review and P2 terms
capture. This request proposes one explicit owner-approved variance because
the two exact terms pages are already known, public, read-only and bounded.
P1 and P2 results remain distinct in evidence. The variance does not open P3,
does not authorize an artifact download and does not produce a terms/use or
Legal conclusion.

The run may record candidate CSV, spreadsheet, PDF, download, update,
methodology and attribution URI strings found in the four responses. It may
not follow those candidates.

## 2. Exact authorization envelope

```text
ExternalEvidenceExecutionAuthorization {
  authorizationId: bb28a9bf-c907-489b-b321-c58983aecdca
  planId: BCK20-OD02-EXT-EV-PLAN-01
  exactPlanVersion: 0.1
  exactPlanNormalizedHash: f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac
  allowedSourceIds:
    - SRC-UN-M49
    - SRC-EU-EURO
  allowedOfficialOrigins:
    - https://unstats.un.org:443
    - https://www.un.org:443
    - https://economy-finance.ec.europa.eu:443
    - https://commission.europa.eu:443
  allowedExactUris:
    - https://unstats.un.org/unsd/methodology/m49/
    - https://www.un.org/en/about-us/terms-of-use
    - https://economy-finance.ec.europa.eu/euro/what-euro-area_en
    - https://commission.europa.eu/legal-notice_en
  allowedRequestMethods:
    - GET
  allowedResponseTypes:
    - text/html
    - application/xhtml+xml
    - text/plain
  redirectPolicy:
    sameOriginTlsOnly: true
    maximumRedirectsPerExactUri: 1
    crossOrigin: deny
    nonTls: deny
  requestPolicy:
    sequentialOnly: true
    maximumTotalRequestsIncludingRedirects: 8
    minimumDelayBetweenInitialRequestsMs: 750
    automaticRetries: 0
    credentialsAllowed: false
    cookiesAllowed: false
    requestBodyAllowed: false
  perResponseByteLimit: 5242880
  totalRunByteLimit: 12582912
  runExpiresAtUtc: 2026-09-20T18:00:00Z
  temporaryStorageRoot: C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-c-p1p2-bb28a9bf-c907-489b-b321-c58983aecdca
  repositoryWriteAllowed: false
  candidateLinkFollowAllowed: false
  termsAcceptanceAllowed: false
  artifactDownloadAllowed: false
  parserExecutionAllowed: false
  archiveInspectionAllowed: false
  approvedBy: pending exact owner decision
}
```

Omitted capability is denied. Any changed source, initial URI, origin, method,
limit, expiry, path or frozen plan hash invalidates this request.

## 3. Permitted request sequence

| Order | Evidence class | Exact initial URI | Permitted output |
|---:|---|---|---|
| 1 | `SRC-UN-M49` P1 | `https://unstats.un.org/unsd/methodology/m49/` | landing metadata/body hash; candidate dated table, download and methodology URI strings |
| 2 | UN P2 | `https://www.un.org/en/about-us/terms-of-use` | exact terms metadata/body hash; questions only, no conclusion |
| 3 | `SRC-EU-EURO` P1 | `https://economy-finance.ec.europa.eu/euro/what-euro-area_en` | page metadata/body hash; explicit published LV/EE/LT statements and candidate document URI strings |
| 4 | Commission P2 | `https://commission.europa.eu/legal-notice_en` | exact legal-notice metadata/body hash; questions only, no conclusion |

No fallback GET is permitted. A same-origin TLS redirect consumes one request
and its complete chain must be recorded. Cross-origin redirects are recorded
as blocked and are not followed.

## 4. Required discovery evidence

For every response, capture:

- source ID, operation ID and UTC timestamp;
- initial URI, complete redirect chain and final URI;
- status, media type, declared and actual byte count;
- selected non-sensitive response headers;
- raw-body SHA-256;
- page title, publication/update date when explicitly present;
- candidate artifact, methodology, version, update and attribution links;
- typed outcome and limitations.

For UN M49, discovery must distinguish:

- the human-readable methodology page;
- a dated or reproducible country/area table candidate;
- numeric M49 and ISO alpha mapping scope;
- UN short-name provenance;
- statistical groupings that are outside Recharge market policy.

For EU euro evidence, discovery must retain only explicit published statements
about euro-area membership or adoption for Latvia, Estonia and Lithuania. It
must not infer launch markets, pricing, tax, territorial scope or effective
policy for Recharge.

## 5. Required terms questions

Terms capture is evidence only. The later disposition must separately answer:

1. may Recharge store the exact source snapshot outside and/or inside the
   repository;
2. may Recharge parse it and store normalized derived facts;
3. which attribution, source-link, copyright and change notices are required;
4. whether redistribution inside a commercial mobile application is allowed;
5. whether modification, localization or translated display names are
   permitted;
6. whether automated periodic retrieval is allowed and under which limits;
7. whether source withdrawal or terms change requires deletion or replacement;
8. whether qualified Legal review is required before any executable slice.

No answer is produced automatically from page text.

## 6. Temporary evidence boundary

The run may write only inside the exact authorization-specific OS-temp root:

```text
run-manifest.json
requests/<attempt-id>/response-body.raw
requests/<attempt-id>/response-metadata.json
candidate-links.json
explicit-statements.json
terms-question-map.json
run-result.json
```

Raw HTML/text remains temporary and untracked. The repository may later
receive only a separately approved evidence record containing permitted
metadata, hashes, provenance, explicit statements and limitations.

## 7. Stop conditions and typed outcomes

| Outcome | Trigger | Required action |
|---|---|---|
| `ext_c_p1p2_pass` | all four exact pages complete within the envelope and evidence classes remain distinct | stop; prepare one execution review and exact P3–P6 proposal |
| `authorization_expired` | run starts or continues after expiry | stop before the next request |
| `origin_unverified` | allowed HTTPS origin cannot be established | stop affected source |
| `redirect_disallowed` | redirect is cross-origin, non-TLS or exceeds one hop | record and do not follow |
| `content_type_unexpected` | media type is outside the allowlist | stop affected response |
| `response_too_large` | declared or streamed body exceeds 5 MiB | abort affected response |
| `run_byte_limit_exceeded` | aggregate body bytes would exceed 12 MiB | stop the run |
| `authentication_required` | cookies, login, payment or click-through is required | stop; no bypass |
| `candidate_not_found` | no reproducible table/document candidate is present | retain finding; source remains Pending |
| `date_or_provenance_missing` | a mutable page has no usable date or source identity | retain Pending; no P3 proposal for that evidence |
| `terms_inconclusive` | exact terms are captured but allowed use cannot be determined technically | require qualified disposition; source remains Pending |
| `transport_incomplete` | timeout, interruption or partial response | record incomplete; no retry |

Any ambiguous or unlisted outcome fails closed.

## 8. Prohibited actions

- no URI other than the four exact initial URIs and permitted same-origin TLS
  redirects;
- no candidate artifact, CSV, spreadsheet, PDF, API, download, update or
  methodology link may be followed;
- no terms acceptance, click-through, account, credential, cookie or payment;
- no browser script execution or authenticated browser state;
- no archive, artifact, parser, fixture or derived dataset;
- no repository data, application code, schema, CI, Firebase or cloud write;
- no source-state, BCK/OD/gate or market promotion;
- no deployment, activation, push or merge.

## 9. Retained gates

- this request opens nothing until its exact owner approval;
- a successful run completes only bounded EXT-C P1/P2 evidence;
- P3–P6 require a new exact authorization after discovered artifact/document
  URIs, types, sizes and terms evidence are reviewed;
- `SRC-UN-M49` and `SRC-EU-EURO` remain Pending;
- `BCK20-OD-02` and `BCK20-OD-05` remain Open;
- `OD-10` remains Proposed, `BCK-20` Draft and `BCK20-OD-03` Deferred;
- all markets remain disabled;
- provider selection, schema, IAM/runtime, Firebase, ingestion, deployment,
  activation, push and merge remain unauthorized.

## 10. Acceptance criteria

1. **BCK20-OD02-EXT-C-P1P2-AUTH-AC-01:** exactly two source IDs and four exact public URIs are in scope.
2. **BCK20-OD02-EXT-C-P1P2-AUTH-AC-02:** combined P1/P2 is an explicit bounded variance, not an implicit gate collapse.
3. **BCK20-OD02-EXT-C-P1P2-AUTH-AC-03:** only sequential unauthenticated GET requests are allowed.
4. **BCK20-OD02-EXT-C-P1P2-AUTH-AC-04:** redirect, request-count and byte limits are exact and fail closed.
5. **BCK20-OD02-EXT-C-P1P2-AUTH-AC-05:** candidate links may be recorded but never followed.
6. **BCK20-OD02-EXT-C-P1P2-AUTH-AC-06:** terms capture is separated from allowed-use or Legal disposition.
7. **BCK20-OD02-EXT-C-P1P2-AUTH-AC-07:** only explicit EU statements are evidence; product/market inference is prohibited.
8. **BCK20-OD02-EXT-C-P1P2-AUTH-AC-08:** UN statistical groupings cannot create Recharge market policy.
9. **BCK20-OD02-EXT-C-P1P2-AUTH-AC-09:** raw responses remain in the exact OS-temp root and untracked.
10. **BCK20-OD02-EXT-C-P1P2-AUTH-AC-10:** P3 artifact/document acquisition remains unauthorized.
11. **BCK20-OD02-EXT-C-P1P2-AUTH-AC-11:** runtime, Firebase, ingestion, deployment, activation, push and merge remain unauthorized.
12. **BCK20-OD02-EXT-C-P1P2-AUTH-AC-12:** execution requires an exact owner decision naming this authorization instance and exact normalized-LF hash.

## 11. Next action

Freeze this v0.1 request by normalized-LF SHA-256. After exact owner approval,
execute the four-request bounded run and prepare one combined execution result.
Do not start P3–P6 from this document.
