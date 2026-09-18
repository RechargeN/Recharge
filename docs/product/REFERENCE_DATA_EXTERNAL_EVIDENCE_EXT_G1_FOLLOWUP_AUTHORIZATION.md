# BCK-20 — EXT-G1 Batch EXT-A Follow-up P1 Authorization Request

- ID: `BCK20-OD02-EXT-EV-G1-FU-AUTH-01`
- Version: `0.1`
- Date: `2026-09-18`
- Status: **Proposed — no network authority until exact owner decision**
- Authorization instance: `3d66a7bd-cc68-4245-9a26-bdcd1bda767c`
- Requested scope: **EXT-G1 / EXT-A / follow-up P1 endpoint metadata only**
- Parent execution decision: `BCK20-OD02-EXT-EV-G1-EXEC-DEC-01` v0.1
- Runtime effect: **none**

## 1. Purpose and safety choice

The accepted P1 review identified a replacement language-registry candidate
and a TZDB release candidate but did not establish their endpoint types, final
same-origin URIs or artifact disposition.

This request proposes `HEAD` only. `GET` is deliberately excluded because
either candidate may resolve directly to registry or release bytes. The run may
observe response metadata and same-origin redirects, but it may not read or
save response bodies, follow links embedded in content, capture terms or
acquire an artifact.

## 2. Exact authorization envelope

```text
ExternalEvidenceExecutionAuthorization {
  authorizationId: 3d66a7bd-cc68-4245-9a26-bdcd1bda767c
  planId: BCK20-OD02-EXT-EV-PLAN-01
  exactPlanVersion: 0.1
  exactPlanNormalizedHash: f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac
  parentExecutionReviewId: BCK20-OD02-EXT-EV-G1-EXEC-REV-01
  parentExecutionReviewHash: ec9acd16b3b1695d20fc891d49f4a2cb7287e6c15f285010e08d18422e5b15fd
  allowedSourceIds:
    - SRC-IANA-LANG
    - SRC-IANA-TZDB
  allowedOfficialOrigins:
    - https://www.iana.org:443
  allowedInitialUris:
    - https://www.iana.org/assignments/language-subtag-registry
    - https://www.iana.org/time-zones/releases/2026d
  allowedRequestMethods:
    - HEAD
  responseBodyReadAllowed: false
  responseBodyStorageAllowed: false
  redirectPolicy:
    sameOriginOnly: true
    maximumRedirectsPerInitialRequest: 1
    preserveMethod: HEAD
    crossOrigin: deny
    nonTls: deny
  requestPolicy:
    sequentialOnly: true
    maximumTotalRequestsIncludingRedirects: 4
    minimumDelayBetweenRequestsMs: 1000
    automaticRetries: 0
    getFallbackAllowed: false
    credentialsAllowed: false
    cookiesAllowed: false
    requestBodyAllowed: false
  selectedResponseHeaders:
    - status
    - content-type
    - content-length
    - content-disposition
    - location
    - etag
    - last-modified
    - cache-control
    - date
  maximumSerializedMetadataBytes: 524288
  validFrom: exact owner-decision recordedAt
  runExpiresAtUtc: 2026-09-20T18:00:00Z
  temporaryStorageRoot: C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-a-p1b-3d66a7bd-cc68-4245-9a26-bdcd1bda767c
  repositoryWriteAllowed: false
  termsCaptureAllowed: false
  artifactAcquisitionAllowed: false
  parserExecutionAllowed: false
  archiveInspectionAllowed: false
  priorTemporaryEvidenceDeletionAllowed: false
  approvedBy: pending exact owner decision
}
```

Omitted capability is denied. Any changed source, URI, origin, method, limit,
expiry, temporary path or parent hash invalidates this request.

## 3. Permitted sequence

| Order | Source | Exact initial URI | Permitted observation |
|---:|---|---|---|
| 1 | `SRC-IANA-LANG` | `https://www.iana.org/assignments/language-subtag-registry` | HEAD status, selected headers, exact same-origin redirect/final URI |
| 2 | `SRC-IANA-TZDB` | `https://www.iana.org/time-zones/releases/2026d` | HEAD status, selected headers, exact same-origin redirect/final URI |

Requests are sequential. One same-origin TLS redirect per initial request may
be followed with `HEAD` preserved. A second redirect, another origin, non-TLS
scheme, authentication requirement or unsupported method stops that source.
No retry and no `GET` fallback are permitted.

## 4. Permitted temporary evidence

Only the following files may be created inside the new exact temporary root:

```text
run-manifest.json
requests/<attempt-id>/response-metadata.json
endpoint-observations.json
run-result.json
```

The metadata may contain only the authorization/run identity, source and
attempt IDs, request timestamps, exact request/redirect/final URIs, status,
selected response headers, typed outcome and limitations. Response bodies,
cookies, unselected headers and third-party content are not retained.

## 5. Prohibited actions

- no `GET`, body read, body storage or embedded-link parsing;
- no URI outside the two exact initial URIs and one permitted same-origin TLS
  redirect for each;
- no cross-origin redirect or downgrade;
- no credentials, cookies, authenticated browser session, account, payment or
  click-through acceptance;
- no terms-page request, terms conclusion or qualified Legal claim;
- no artifact, checksum, signature, archive or executable acquisition;
- no parser, fixture, structural inspection or ingestion;
- no modification or deletion of the prior authorization evidence directory;
- no repository, CI, Firebase, cloud, application or market write;
- no source/gate/BCK/OD status promotion;
- no deployment, activation, push or merge.

## 6. Typed outcomes

| Outcome | Trigger | Required action |
|---|---|---|
| `p1b_endpoint_metadata_pass` | both HEAD sequences finish within the exact envelope | stop; prepare endpoint-metadata review only |
| `authorization_expired` | start or continuation after expiry | stop before the next request |
| `head_not_supported` | 405/501 or endpoint otherwise rejects HEAD | record and stop; no GET fallback |
| `origin_unverified` | exact allowed HTTPS origin cannot be established | stop source |
| `redirect_disallowed` | cross-origin, non-TLS or more than one redirect | record Location when permitted; do not follow |
| `request_budget_exhausted` | next request would exceed four total attempts | stop run |
| `authentication_required` | authentication, cookie, account, payment or click-through required | stop; new decision required |
| `transport_incomplete` | timeout/interruption | record incomplete; no automatic retry |
| `metadata_too_large` | serialized selected metadata would exceed 512 KiB | stop without saving excess metadata |
| `endpoint_ambiguous` | headers do not establish whether endpoint is a page or artifact | retain Pending; require a new decision |

Any unlisted result is fail-closed. A pass proves endpoint metadata only and
does not establish artifact identity, terms, integrity or source fitness.

## 7. Review, cleanup and rollback

After execution, if separately authorized:

1. report the typed result and exact new temporary path;
2. independently reconcile request count, methods, origins, redirects and
   selected metadata;
3. retain both authorization-specific temporary roots until an explicit owner
   disposition;
4. prepare no P2/P3 request until the follow-up result is reviewed;
5. make no canonical status change from transport success alone.

Cancellation is evidence-only rollback. No cloud or runtime rollback exists.

## 8. Requested owner decision

The owner is asked to authorize only the exact `HEAD` envelope above. Approval
must reference this document's exact normalized-LF SHA-256 and authorization
instance. Approval opens only the follow-up P1 endpoint-metadata run; it does
not open EXT-G2.

## 9. Acceptance criteria

1. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-01:** the request binds to the accepted plan, parent execution review and exact authorization instance.
2. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-02:** exactly two source IDs, one origin and two candidate URIs are allowed.
3. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-03:** `HEAD` is the only permitted method; GET fallback and response-body access are denied.
4. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-04:** requests are sequential with at most one same-origin TLS redirect per source and four total requests.
5. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-05:** credentials, cookies, request bodies, retries and authenticated browser state are prohibited.
6. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-06:** temporary evidence is metadata-only and bounded to 512 KiB.
7. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-07:** the prior evidence directory is retained unchanged.
8. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-08:** unsupported HEAD, ambiguous endpoints and disallowed redirects fail closed without GET.
9. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-09:** no terms, artifact, checksum/signature, parser, fixture or ingestion work is authorized.
10. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-10:** pass proves only endpoint metadata and requires a new evidence review.
11. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-11:** EXT-G2–G6, source approval, markets, BCK/OD/runtime and deployment gates remain closed.
12. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-12:** no network call occurs before an exact owner decision referencing this request hash.
13. **BCK20-OD02-EXT-EV-G1-FU-AUTH-AC-13:** repository, CI, Firebase, cloud, deployment, activation, push and merge remain unauthorized.

