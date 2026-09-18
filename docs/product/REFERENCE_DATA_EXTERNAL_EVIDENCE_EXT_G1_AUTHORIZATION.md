# BCK-20 — EXT-G1 Batch EXT-A Authorization Request

- ID: **BCK20-OD02-EXT-EV-G1-AUTH-01**
- Version: **0.1**
- Date: **2026-09-18**
- Status: **Proposed — no network authority until exact owner decision**
- Authorization instance: **aba31978-ab80-4ca5-9d57-c976e54ebcb2**
- Accepted plan: [BCK20-OD02-EXT-EV-PLAN-01 v0.2](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_PLAN.md)
- Frozen plan decision: [BCK20-OD02-EXT-EV-PLAN-DEC-01 v0.1](REFERENCE_DATA_EXTERNAL_EVIDENCE_COLLECTION_OWNER_DECISION.md)
- Requested gate: **EXT-G1 — P1 metadata discovery only**
- Requested batch: **EXT-A — `SRC-IANA-LANG`, `SRC-IANA-TZDB`**
- Network authority: **none until exact approval; expires as specified below**
- Runtime effect: **none**

---

## 1. Purpose and exact boundary

This request asks for one bounded network authorization to perform P1 metadata
discovery against two official IANA landing pages. The run may capture response
metadata and temporary raw landing-page bytes only to identify candidate
artifact and terms URIs for later review.

It does not authorize following artifact or terms links, downloading registry
files or release archives, accepting terms, validating licenses, unpacking
content, running a parser, writing repository files, advancing a source state,
or performing any Firebase/runtime action.

## 2. Exact authorization envelope

```text
ExternalEvidenceExecutionAuthorization {
  authorizationId: aba31978-ab80-4ca5-9d57-c976e54ebcb2
  planId: BCK20-OD02-EXT-EV-PLAN-01
  exactPlanVersion: 0.1
  exactPlanNormalizedHash: f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac
  allowedSourceIds:
    - SRC-IANA-LANG
    - SRC-IANA-TZDB
  allowedOfficialOrigins:
    - https://www.iana.org:443
  allowedLandingUris:
    - https://www.iana.org/assignments/language-subtags-tags-extensions
    - https://www.iana.org/time-zones
  allowedRequestMethods:
    - GET
  allowedResponseTypes:
    - text/html
    - application/xhtml+xml
    - text/plain
  redirectPolicy:
    sameOriginOnly: true
    maximumRedirectsPerRequest: 3
    crossOrigin: deny
    nonTls: deny
  requestPolicy:
    sequentialOnly: true
    maximumTotalRequests: 4
    minimumDelayBetweenRequestsMs: 1000
    automaticRetries: 0
    credentialsAllowed: false
    cookiesAllowed: false
    requestBodyAllowed: false
  perResponseByteLimit: 2097152
  totalRunByteLimit: 4194304
  validFrom: exact owner-decision recordedAt
  runExpiresAtUtc: 2026-09-19T18:00:00Z
  temporaryStorageRoot: C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-a-p1-aba31978-ab80-4ca5-9d57-c976e54ebcb2
  repositoryWriteAllowed: false
  termsLinkFollowAllowed: false
  artifactLinkFollowAllowed: false
  parserExecutionAllowed: false
  archiveInspectionAllowed: false
  approvedBy: pending exact owner decision
}
```

Omitted capability is denied. The authorization is invalid if the decision is
recorded after expiry or if any target, origin, method, limit, path or plan hash
changes.

## 3. Permitted request sequence

| Order | Source | Exact initial URI | Permitted result |
|---:|---|---|---|
| 1 | `SRC-IANA-LANG` | `https://www.iana.org/assignments/language-subtags-tags-extensions` | landing-page metadata/body within limits; candidate artifact/terms URI strings only |
| 2 | `SRC-IANA-TZDB` | `https://www.iana.org/time-zones` | landing-page metadata/body within limits; candidate release/checksum/terms URI strings only |

Requests are sequential. The remaining two-request allowance exists only for
an owner-directed manual retry after a transport-level incomplete result while
the same authorization remains valid. No retry occurs automatically.

Same-origin redirects may be followed only when the client exposes and records
the complete chain. A redirect to any other origin or non-TLS scheme ends the
affected request with a typed failure.

## 4. Permitted temporary evidence

The run may create only inside the exact temporary root:

```text
run-manifest.json
requests/<attempt-id>/response-body.raw
requests/<attempt-id>/response-metadata.json
requests/<attempt-id>/sha256.txt
candidate-links.json
run-result.json
```

Required metadata:

- authorization ID, plan ID/version/hash and run ID;
- source ID and attempt ID;
- exact request time in UTC;
- initial URI, redirect chain and final URI;
- HTTP status, selected response headers, media type and byte count;
- TLS HTTPS origin observed by the client;
- raw response-body SHA-256;
- candidate link strings classified as artifact, checksum/signature, terms or
  informational;
- typed outcome and limitations.

Candidate links are discovery outputs only. They are not requested during this
run and do not become trusted, allowed or current evidence.

## 5. Prohibited actions

- no URI outside the two initial landing URIs and permitted same-origin
  redirects;
- no cross-origin redirect, artifact, checksum, signature or terms-page GET;
- no HEAD/POST/PUT/PATCH/DELETE or request body;
- no credentials, cookies, authenticated browser context, account or payment;
- no acceptance of click-through or other terms;
- no JavaScript execution, browser automation, downloaded executable or macro;
- no archive download, unpacking, parser or fixture execution;
- no repository, CI, Firebase, cloud or application write;
- no source-state, BCK/OD/gate or market-activation promotion;
- no push or merge.

## 6. Typed outcomes

| Outcome | Trigger | Required action |
|---|---|---|
| `ext_g1_pass` | both landing requests complete within exact envelope and candidate links/limits are recorded | stop; prepare P1 evidence review only |
| `authorization_expired` | run starts or continues after expiry | stop before next request |
| `origin_unverified` | initial/final origin cannot be established as allowed HTTPS origin | stop affected source |
| `redirect_disallowed` | cross-origin, non-TLS or redirect count exceeds 3 | stop; do not follow |
| `content_type_unexpected` | media type outside allowlist | stop before retaining body beyond security evidence |
| `response_too_large` | declared or streamed bytes exceed 2 MiB | abort transfer and stop source |
| `run_byte_limit_exceeded` | aggregate bytes would exceed 4 MiB | stop run |
| `authentication_required` | login, cookies, payment or click-through required | stop; new decision required |
| `transport_incomplete` | timeout/interruption/partial response | record incomplete; no automatic retry |
| `candidate_not_found` | landing page yields no exact artifact or terms candidate | retain finding; source stays Pending |
| `cleanup_failed` | temporary evidence cannot be removed after review disposition | block further execution and report exact paths |

Any unlisted or ambiguous outcome is fail-closed. `ext_g1_pass` does not prove
artifact identity, terms, license, semantic correctness or ingestion fitness.

## 7. Review, cleanup and rollback

After the run:

1. report the run result and exact temporary path without copying content into
   the repository;
2. review candidate links and metadata for a later P2/P3 proposal;
3. preserve temporary evidence only until the owner chooses `retain for
   bounded review` or `delete`;
4. deletion must target only the resolved authorization-specific temporary
   root after verifying it is inside the OS temp directory;
5. no canonical document status changes merely because P1 passed;
6. cancellation or cleanup is rollback; no cloud/data rollback exists.

## 8. Evidence required to close EXT-G1

- exact decision record for this authorization instance;
- start/end timestamps and tool/runtime version;
- all request attempts and typed outcomes;
- response byte counts and raw hashes;
- complete redirect chains;
- candidate link inventory without following those links;
- confirmation that repository, parser, terms and artifact gates were not used;
- cleanup/retention disposition and limitations.

EXT-G1 may be reported `Pass` only for P1 metadata discovery. It does not open
EXT-G2 automatically; a separate exact authorization is required.

## 9. Retained project gates

- EXT-G0 remains Accepted; EXT-G1 is Proposed until an exact owner decision and
  remains unexecuted until a run completes;
- EXT-G2–G6 remain closed;
- all external source records remain artifact/terms/validation Pending;
- all markets remain disabled;
- BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and
  BCK20-OD-03 Deferred;
- provider selection, schema, IAM/runtime, Firebase, deployment, activation,
  push and merge remain unauthorized.

## 10. Acceptance criteria

1. **BCK20-OD02-EXT-EV-G1-AUTH-AC-01:** authorization applies only to EXT-A P1 metadata discovery.
2. **BCK20-OD02-EXT-EV-G1-AUTH-AC-02:** exactly two source IDs, one official origin and two initial URIs are allowed.
3. **BCK20-OD02-EXT-EV-G1-AUTH-AC-03:** only sequential GET requests without body, credentials or cookies are allowed.
4. **BCK20-OD02-EXT-EV-G1-AUTH-AC-04:** same-origin TLS redirects are bounded and cross-origin/non-TLS redirects fail closed.
5. **BCK20-OD02-EXT-EV-G1-AUTH-AC-05:** per-response and total byte limits are exact.
6. **BCK20-OD02-EXT-EV-G1-AUTH-AC-06:** authorization has an exact expiry and authorization-specific temporary root.
7. **BCK20-OD02-EXT-EV-G1-AUTH-AC-07:** landing-page bodies and metadata remain temporary and untracked.
8. **BCK20-OD02-EXT-EV-G1-AUTH-AC-08:** artifact, checksum/signature and terms links may be recorded but not followed.
9. **BCK20-OD02-EXT-EV-G1-AUTH-AC-09:** no terms acceptance, download, archive, parser, fixture or ingestion work is authorized.
10. **BCK20-OD02-EXT-EV-G1-AUTH-AC-10:** unexpected or ambiguous outcomes fail closed with typed evidence.
11. **BCK20-OD02-EXT-EV-G1-AUTH-AC-11:** pass proves only P1 metadata discovery and never source fitness.
12. **BCK20-OD02-EXT-EV-G1-AUTH-AC-12:** repository, CI, Firebase, cloud and application writes are prohibited.
13. **BCK20-OD02-EXT-EV-G1-AUTH-AC-13:** cleanup targets only the verified authorization-specific OS-temp root.
14. **BCK20-OD02-EXT-EV-G1-AUTH-AC-14:** EXT-G2–G6 and every BCK/OD/market/runtime gate remain closed.
15. **BCK20-OD02-EXT-EV-G1-AUTH-AC-15:** no push or merge is authorized.
16. **BCK20-OD02-EXT-EV-G1-AUTH-AC-16:** any plan, source, URI, origin, method, limit, expiry or path change invalidates this authorization.
17. **BCK20-OD02-EXT-EV-G1-AUTH-AC-17:** no network request occurs before an exact owner decision is recorded.
18. **BCK20-OD02-EXT-EV-G1-AUTH-AC-18:** EXT-G1 completion requires run evidence and does not automatically open EXT-G2.

## 11. Next action

Freeze this v0.1 request by normalized-LF SHA-256 in a bounded owner-review
package. Do not perform P0 or any network action before the exact decision.
