# BCK-20 — EXT-D All-in-One Evidence Authorization Request

- ID: **BCK20-OD02-EXT-D-ALL-AUTH-01**
- Version: **0.1**
- Date: **2026-09-19**
- Status: **Proposed — no network authority until exact owner decision**
- Authorization instance: **1c4ba623-e0cb-47db-82b8-ce297f954d56**
- Accepted plan: [BCK20-OD02-EXT-EV-PLAN-01 v0.2](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_PLAN.md)
- Frozen plan normalized-LF SHA-256:
  `f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac`
- Requested batch: **EXT-D — `SRC-ISO-3166`, `SRC-ISO-4217`, `SRC-SIX-4217`**
- Requested work: **one bounded P1–P6 technical-evidence run**
- Runtime effect: **none**

## 1. Purpose and explicit variance

This request packages EXT-D discovery, terms capture, exact public-artifact
acquisition, structural inspection, bounded validation and evidence disposition
into one owner-approved execution. It exists to avoid multiple approval cycles
while retaining fail-closed boundaries for standards with potentially
restrictive access or use terms.

The accepted collection plan normally requires review between P1/P2 and P3.
This request proposes an explicit bounded variance only for the exact eight
public URIs listed below. No discovered or redirected artifact URI outside that
list may be followed. Failure of one source does not authorize a workaround;
its dimensions are recorded `Pending` or `Blocked` in the single P6 record.

The run may finish with mixed per-source results. A P6 evidence record is still
permitted when it truthfully records technical Pass, Pending and Blocked
dimensions without advancing any source to `eligible_for_slice_review`.

## 2. Exact authorization envelope

```text
ExternalEvidenceExecutionAuthorization {
  authorizationId: 1c4ba623-e0cb-47db-82b8-ce297f954d56
  planId: BCK20-OD02-EXT-EV-PLAN-01
  exactPlanVersion: 0.1
  exactPlanNormalizedHash: f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac
  allowedSourceIds:
    - SRC-ISO-3166
    - SRC-ISO-4217
    - SRC-SIX-4217
  allowedOfficialOrigins:
    - https://www.iso.org:443
    - https://www.six-group.com:443
  allowedExactUris:
    - https://www.iso.org/iso-3166-country-codes.html
    - https://www.iso.org/standard/64758.html
    - https://www.iso.org/privacy-and-copyright.html
    - https://www.six-group.com/en/products-services/financial-information/market-reference-data/data-standards.html
    - https://www.six-group.com/en/site/disclaimer.html
    - https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-one.xml
    - https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-two.xml
    - https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-three.xml
  allowedRequestMethods:
    - GET
  allowedResponseTypes:
    - text/html
    - application/xhtml+xml
    - text/plain
    - application/xml
    - text/xml
    - application/octet-stream
  redirectPolicy:
    sameOriginTlsOnly: true
    maximumRedirectsPerExactUri: 1
    crossOrigin: deny
    nonTls: deny
  requestPolicy:
    sequentialOnly: true
    maximumInitialRequests: 8
    maximumTotalRequestsIncludingRedirects: 16
    minimumDelayBetweenInitialRequestsMs: 750
    automaticRetries: 0
    credentialsAllowed: false
    cookiesAllowed: false
    requestBodyAllowed: false
  perPageByteLimit: 5242880
  perXmlArtifactByteLimit: 10485760
  totalRunByteLimit: 31457280
  runExpiresAtUtc: 2026-09-22T18:00:00Z
  temporaryStorageRoot: C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-d-all-1c4ba623-e0cb-47db-82b8-ce297f954d56
  discoveredLinkFollowAllowed: false
  termsAcceptanceAllowed: false
  authenticatedOrPaidAccessAllowed: false
  browserScriptExecutionAllowed: false
  generalExtractionAllowed: false
  safeXmlValidationAllowed: true
  runtimeParserAllowed: false
  repositoryWriteAllowed:
    - docs/product/REFERENCE_DATA_EXT_D_P6_EVIDENCE_RECORD.md
  localCommitAllowed: true
  pushAllowed: false
  approvedBy: pending exact owner decision
}
```

Omitted capability is denied. Any changed source, exact URI, origin, method,
limit, expiry, path or frozen plan hash invalidates this request.

## 3. Exact request sequence

| Order | Source / class | Exact URI | Purpose |
|---:|---|---|---|
| 1 | `SRC-ISO-3166` P1 | `https://www.iso.org/iso-3166-country-codes.html` | standard identity, edition/status and public-access route discovery |
| 2 | `SRC-ISO-4217` P1 | `https://www.iso.org/standard/64758.html` | exact standard identity, edition and status evidence |
| 3 | ISO P2 | `https://www.iso.org/privacy-and-copyright.html` | copyright/reuse evidence only |
| 4 | `SRC-SIX-4217` P1 | `https://www.six-group.com/en/products-services/financial-information/market-reference-data/data-standards.html` | maintenance role and official artifact-link evidence |
| 5 | SIX P2 | `https://www.six-group.com/en/site/disclaimer.html` | disclaimer/terms evidence only |
| 6 | SIX P3 | `https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-one.xml` | active ISO 4217 currency list candidate |
| 7 | SIX P3 | `https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-two.xml` | funds code-list candidate |
| 8 | SIX P3 | `https://www.six-group.com/dam/download/financial-information/data-center/iso-currrency/lists/list-three.xml` | historic currency-list candidate |

Requests are sequential. A response failure is recorded and the runner may
continue to later exact URIs only when doing so does not require credentials,
terms acceptance, control bypass or reliance on the failed response.

## 4. P1/P2 evidence rules

For every page response, record:

- initial/final URI and complete permitted redirect chain;
- status, media type, declared/actual size and selected headers;
- retrieval timestamp and raw SHA-256;
- explicit standard number, title, edition/version, publication/status and
  maintenance role when present;
- exact public artifact, terms, purchase, authentication and update-link
  strings without following discovered links;
- whether access is public, paywalled, browser-script-only, authenticated or
  ambiguous.

Terms pages are captured as evidence only. No automated conclusion may be made
about storage, parsing, derivative datasets, notices, redistribution,
commercial/mobile use or update automation.

## 5. P3 artifact acquisition

Only the three exact SIX XML URIs are approved artifacts. For each successful
response:

- stream raw bytes into the exact OS-temp root;
- enforce media-type and byte limits before and during transfer;
- compute SHA-256 over the exact response;
- record provider version/date/checksum/signature when explicitly supplied;
- do not execute, transform or copy raw bytes into the repository.

HTTP 404/410, authentication, payment, click-through, disallowed redirect or
unexpected content does not authorize URI guessing or fallback discovery.

No ISO 3166 data artifact is pre-authorized. If the ISO page exposes only an
OBP/browser, purchase route, click-through, authenticated API or another
artifact URI, record it and stop that artifact dimension as
`lawful_artifact_not_found` or `access_terms_blocked`.

## 6. P4 structural inspection

For each captured XML artifact:

- parse only in memory with DTD prohibited and external entity resolution
  disabled;
- reject malformed XML, duplicate critical nodes, unexpected root/schema
  shape, excessive depth/size or unknown critical fields;
- record root element, publication/list date, entry count and relevant field
  inventory;
- do not write extracted rows, fixtures or normalized datasets;
- do not execute XSLT, schemas, embedded links or processing instructions.

HTML and browser content is treated as page evidence only. JavaScript is never
executed.

## 7. P5 bounded semantic validation

### 7.1 ISO 3166

Validate only evidence directly present in the exact ISO page:

- ISO 3166 scope and maintenance authority;
- published standard/edition/status information;
- availability or access limitations;
- explicit public route for code-list data, if any.

Do not reconstruct or import the full code list from UN, CLDR or memory and do
not report ISO 3166 artifact validation as Pass without an exact authorized ISO
artifact.

### 7.2 ISO 4217 / SIX

When exact SIX XML is available, validate:

- document/list identity and publication date when supplied;
- deterministic entry count and unique entry identity;
- alphabetic currency code: exactly three uppercase ASCII letters;
- numeric currency code: exactly three digits when present;
- minor unit: bounded integer or an explicitly recognized provider marker;
- active, fund and historic lists remain distinct;
- duplicate/conflicting code semantics fail closed;
- `EUR` is present in the active list with numeric code `978` and minor unit
  `2`;
- Estonia, Latvia and Lithuania references, when present, resolve only to
  `EUR` and do not create Recharge market policy;
- withdrawn/historic entries are never silently promoted to active.

ISO/SIX evidence does not authorize exchange rates, prices, taxes, payments or
money calculations.

## 8. P6 evidence disposition

After all eight exact requests and bounded local checks finish, create exactly
one tracked file:

```text
docs/product/REFERENCE_DATA_EXT_D_P6_EVIDENCE_RECORD.md
```

The record must report each source and dimension independently as `Pass`,
`Pending`, `Blocked`, `Absent` or `Unauthorized`. Mixed results are expected
and must not be collapsed into a batch-wide success.

The file may contain only:

- exact URIs, timestamps, metadata, sizes and hashes;
- standard/list identities, counts and validation summaries;
- bounded Baltic/EUR facts required by Recharge;
- access, paywall, browser, licensing and terms limitations;
- retained gates and OS-temp evidence locations.

It must not contain full ISO/SIX lists, raw pages/XML, reusable fixtures,
normalized third-party datasets or runtime code. One local docs-only commit is
permitted after evidence-hash and diff checks.

## 9. Typed outcomes

| Outcome | Trigger | Required disposition |
|---|---|---|
| `technical_evidence_pass` | exact public response and bounded validation pass for that dimension | record Pass; source acceptance remains Pending |
| `lawful_artifact_not_found` | official page exposes no exact public artifact route | artifact dimension Pending/Blocked; no inference |
| `access_terms_blocked` | purchase, account, click-through, restrictive control or unclear permission is required | stop affected source; no bypass |
| `artifact_not_found` | exact approved XML returns 404/410 | record; do not guess replacement URI |
| `redirect_disallowed` | redirect violates exact policy | stop affected request |
| `content_type_unexpected` | response type is outside the allowlist | quarantine metadata; no parsing |
| `response_too_large` | response exceeds its exact limit | abort affected transfer |
| `integrity_inconclusive` | no provider hash/signature/version is available | local hash retained; integrity dimension Pending |
| `structure_unsafe` | XML or page structure violates controls | block affected artifact |
| `validation_inconclusive` | required identity, uniqueness or EUR facts cannot be proved | record Pending; no source advancement |
| `terms_inconclusive` | terms captured without qualified disposition | source remains Pending |
| `transport_incomplete` | timeout or partial response | no automatic retry; record incomplete |

Any ambiguous or unlisted condition fails closed.

## 10. Temporary evidence boundary

All raw and derived execution evidence remains under:

```text
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-d-all-1c4ba623-e0cb-47db-82b8-ce297f954d56
```

Permitted contents:

```text
run-manifest.json
requests/<attempt-id>/response-body.raw
requests/<attempt-id>/response-metadata.json
candidate-links.json
p4-p5-validation.json
run-result.json
```

This authorization does not authorize cleanup or deletion.

## 11. Retained gates

- technical evidence cannot become source acceptance or license approval;
- qualified terms/use disposition remains required for every applicable
  source;
- source status remains Pending or Blocked and not
  `eligible_for_slice_review`;
- no independent Security/Privacy or qualified Legal claim is created;
- `BCK20-OD-02` and `BCK20-OD-05` remain Open;
- `OD-10` remains Proposed, `BCK-20` Draft and `BCK20-OD-03` Deferred;
- all markets remain disabled;
- parser, fixtures, repository data, provider selection, schema, IAM/runtime,
  Firebase, ingestion, deployment, activation, push and merge remain
  unauthorized.

## 12. Acceptance criteria

1. **BCK20-OD02-EXT-D-ALL-AUTH-AC-01:** exactly three source IDs, two origins and eight exact URIs are authorized.
2. **BCK20-OD02-EXT-D-ALL-AUTH-AC-02:** all-in-one execution is an explicit bounded variance and not implicit gate collapse.
3. **BCK20-OD02-EXT-D-ALL-AUTH-AC-03:** only sequential unauthenticated GET requests are allowed.
4. **BCK20-OD02-EXT-D-ALL-AUTH-AC-04:** redirect, request-count, response and aggregate byte limits are exact.
5. **BCK20-OD02-EXT-D-ALL-AUTH-AC-05:** only three exact SIX XML URIs are approved artifacts.
6. **BCK20-OD02-EXT-D-ALL-AUTH-AC-06:** no discovered link, guessed URI, paywall, account, click-through or browser control is bypassed.
7. **BCK20-OD02-EXT-D-ALL-AUTH-AC-07:** safe XML parsing prohibits DTDs, external entities, XSLT and active content.
8. **BCK20-OD02-EXT-D-ALL-AUTH-AC-08:** active, fund and historic currency evidence remains distinct.
9. **BCK20-OD02-EXT-D-ALL-AUTH-AC-09:** absence of an ISO 3166 artifact is recorded honestly and never reconstructed from another source.
10. **BCK20-OD02-EXT-D-ALL-AUTH-AC-10:** terms capture is not presented as allowed-use or Legal approval.
11. **BCK20-OD02-EXT-D-ALL-AUTH-AC-11:** P6 records mixed dimension outcomes without batch-wide overstatement.
12. **BCK20-OD02-EXT-D-ALL-AUTH-AC-12:** at most one docs-only P6 record and one local commit are permitted.
13. **BCK20-OD02-EXT-D-ALL-AUTH-AC-13:** raw third-party content remains temporary and untracked.
14. **BCK20-OD02-EXT-D-ALL-AUTH-AC-14:** runtime, Firebase, ingestion, deployment, activation, push and merge remain unauthorized.

## 13. Next action

Freeze this v0.1 request by normalized-LF SHA-256. After one exact owner
decision naming the hash and authorization instance, execute EXT-D through its
single P6 disposition without intermediate approval requests. Stop only where
the exact controls require fail-closed handling.
