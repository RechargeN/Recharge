# BCK-20 — EXT-C Conditional P3–P6 Authorization Request

- ID: **BCK20-OD02-EXT-C-P3P6-AUTH-01**
- Version: **0.1**
- Date: **2026-09-19**
- Status: **Proposed — no network or P3–P6 authority until exact owner decision**
- Authorization instance: **a0508d27-3b56-4fd1-9953-abf7b430e1de**
- Parent execution review: [BCK20-OD02-EXT-C-P1P2-EXEC-REV-01 v0.1](REFERENCE_DATA_EXT_C_P1_P2_EXECUTION_REVIEW.md)
- Accepted plan: [BCK20-OD02-EXT-EV-PLAN-01 v0.2](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_PLAN.md)
- Frozen plan normalized-LF SHA-256:
  `f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac`
- Requested batch: **EXT-C — `SRC-UN-M49`, `SRC-EU-EURO`**
- Runtime effect: **none**

## 1. Purpose and conditional outcome

This request permits one exact official UN M49 full-view GET and bounded local
validation using that response plus the already captured Commission euro-area
page.

There are two allowed terminal paths:

1. if the M49 full-view response directly contains a complete primary
   country/code table, validate the exact response in memory and create one
   docs-only EXT-C P6 evidence record;
2. if it only exposes another artifact/download URI or the table is incomplete,
   record the exact candidate and stop. Following that URI requires another
   authorization.

No candidate discovered during this run may be followed automatically.

## 2. Exact authorization envelope

```text
ExternalEvidenceExecutionAuthorization {
  authorizationId: a0508d27-3b56-4fd1-9953-abf7b430e1de
  planId: BCK20-OD02-EXT-EV-PLAN-01
  exactPlanVersion: 0.1
  exactPlanNormalizedHash: f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac
  allowedSourceIds:
    - SRC-UN-M49
    - SRC-EU-EURO
  allowedOfficialOrigins:
    - https://unstats.un.org:443
  allowedExactUris:
    - https://unstats.un.org/unsd/methodology/m49/overview/
  allowedRequestMethods:
    - GET
  allowedResponseTypes:
    - text/html
    - application/xhtml+xml
    - text/plain
  redirectPolicy:
    sameOriginTlsOnly: true
    maximumRedirects: 1
    crossOrigin: deny
    nonTls: deny
  requestPolicy:
    sequentialOnly: true
    maximumTotalRequestsIncludingRedirect: 2
    automaticRetries: 0
    credentialsAllowed: false
    cookiesAllowed: false
    requestBodyAllowed: false
  perResponseByteLimit: 5242880
  totalRunByteLimit: 5242880
  runExpiresAtUtc: 2026-09-21T18:00:00Z
  temporaryStorageRoot: C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-c-p3p6-a0508d27-3b56-4fd1-9953-abf7b430e1de
  priorEvidenceRootReadAllowed: C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-c-p1p2-bb28a9bf-c907-489b-b321-c58983aecdca
  candidateLinkFollowAllowed: false
  termsAcceptanceAllowed: false
  generalExtractionAllowed: false
  runtimeParserAllowed: false
  repositoryWriteAllowed:
    - docs/product/REFERENCE_DATA_EXT_C_P6_EVIDENCE_RECORD.md
  localCommitAllowed: true
  pushAllowed: false
  approvedBy: pending exact owner decision
}
```

Omitted capability is denied. Any changed URI, source, origin, method, limit,
expiry, path or frozen plan hash invalidates this request.

## 3. P3 acquisition

- issue one unauthenticated GET to the exact M49 `overview/` URI;
- record response metadata, complete permitted redirect chain, raw byte count,
  SHA-256 and retrieval time;
- retain the raw response only in the exact OS-temp root;
- record but do not follow any CSV, spreadsheet, download, API, print or data
  endpoint URI found in the response;
- do not execute HTML, JavaScript, macros or embedded content.

## 4. P4 structural inspection

For direct HTML/text table evidence:

- scripts, styles and active content are never executed;
- reject malformed table structure that prevents deterministic row identity;
- reject duplicate field names or ambiguous country/code columns;
- bound response size, row count, column count and text field length;
- retain only metadata, hashes and validation results outside raw temp evidence.

If the response is an index, client shell or download launcher without the
complete table, the outcome is `artifact_link_requires_authorization` and P5/P6
stop.

## 5. P5 bounded validation

When the complete primary table is directly present, validate in memory:

- numeric M49 is exactly three decimal digits;
- alpha-2, when present, is two uppercase ASCII letters;
- alpha-3, when present, is three uppercase ASCII letters;
- relevant identifiers are unique within their applicable row class;
- country/area names and mappings retain source provenance;
- Estonia maps to M49 `233` / alpha-3 `EST`;
- Latvia maps to M49 `428` / alpha-3 `LVA`;
- Lithuania maps to M49 `440` / alpha-3 `LTU`;
- statistical groupings remain excluded from Recharge market policy;
- unknown or structurally ambiguous rows fail closed.

Reuse the exact captured EU page by hash and validate only:

- Estonia joined the euro area in 2011;
- Latvia joined the euro area in 2014;
- Lithuania joined the euro area in 2015;
- no inference is made for Recharge market activation, prices, tax, payment or
  availability policy.

This is evidence-only parsing. It creates no reusable runtime parser, fixture,
repository dataset or generated application asset.

## 6. P6 evidence disposition

If all authorized technical checks pass, create exactly one tracked file:

```text
docs/product/REFERENCE_DATA_EXT_C_P6_EVIDENCE_RECORD.md
```

It may contain only:

- exact URIs, timestamps, response metadata, sizes and hashes;
- bounded table counts and validation results;
- the selected Baltic M49 mappings and euro-adoption years;
- terms evidence hashes and unresolved qualified questions;
- provenance, limitations, source states and retained gates;
- temporary evidence paths and cleanup status.

It must not contain raw pages, a full UN table, third-party datasets, reusable
fixtures or source code. A local docs-only commit is permitted only after diff
and evidence-hash checks. Push and merge remain prohibited.

## 7. Typed outcomes

| Outcome | Meaning / action |
|---|---|
| `ext_c_p3p6_technical_pass` | complete table present and all bounded checks pass; create one P6 evidence record |
| `artifact_link_requires_authorization` | full-view page points to a separate artifact; record exact URI and stop without P6 |
| `mutable_undated_source` | response lacks adequate reproducibility/version evidence; source remains Pending |
| `redirect_disallowed` | redirect violates exact policy; stop |
| `content_type_unexpected` | response type is outside allowlist; stop |
| `response_too_large` | response exceeds 5 MiB; abort |
| `structure_unsafe` | active/ambiguous/malformed structure prevents safe deterministic validation; stop |
| `validation_inconclusive` | required columns, uniqueness or Baltic mappings cannot be proven; stop |
| `terms_inconclusive` | technical evidence may be recorded, but source remains terms/use Pending |
| `transport_incomplete` | timeout or partial response; no retry |

Any unlisted or ambiguous state fails closed.

## 8. Retained gates

- successful technical evidence does not accept either source for ingestion;
- UN and Commission allowed-use disposition remains Pending;
- no qualified Legal or independent Security/Privacy claim is created;
- source status remains Pending and not `eligible_for_slice_review` unless a
  later owner decision explicitly advances it;
- `BCK20-OD-02` and `BCK20-OD-05` remain Open;
- `OD-10` remains Proposed, `BCK-20` Draft and `BCK20-OD-03` Deferred;
- all markets remain disabled;
- production parser, fixtures, repository data, schema, IAM/runtime, Firebase,
  ingestion, deployment, activation, push and merge remain unauthorized.

## 9. Acceptance criteria

1. **BCK20-OD02-EXT-C-P3P6-AUTH-AC-01:** exactly one initial M49 URI is authorized.
2. **BCK20-OD02-EXT-C-P3P6-AUTH-AC-02:** redirects, requests and bytes are exactly bounded.
3. **BCK20-OD02-EXT-C-P3P6-AUTH-AC-03:** discovered artifact links are recorded but never followed.
4. **BCK20-OD02-EXT-C-P3P6-AUTH-AC-04:** only a directly present complete table may enter P5 validation.
5. **BCK20-OD02-EXT-C-P3P6-AUTH-AC-05:** active content is not executed.
6. **BCK20-OD02-EXT-C-P3P6-AUTH-AC-06:** code widths, uniqueness and Baltic mappings are validated deterministically.
7. **BCK20-OD02-EXT-C-P3P6-AUTH-AC-07:** EU validation reuses the exact previously captured page hash without a new EU request.
8. **BCK20-OD02-EXT-C-P3P6-AUTH-AC-08:** evidence parsing creates no runtime parser, fixture or dataset.
9. **BCK20-OD02-EXT-C-P3P6-AUTH-AC-09:** at most one docs-only P6 record and one local commit are permitted.
10. **BCK20-OD02-EXT-C-P3P6-AUTH-AC-10:** raw third-party data remains temporary and untracked.
11. **BCK20-OD02-EXT-C-P3P6-AUTH-AC-11:** terms/use, source acceptance and executable gates remain Pending or closed.
12. **BCK20-OD02-EXT-C-P3P6-AUTH-AC-12:** Firebase, deployment, activation, push and merge remain unauthorized.

## 10. Next action

Freeze this v0.1 request by normalized-LF SHA-256. No network or P3–P6 work
may begin before the exact owner decision naming that hash and authorization
instance.
