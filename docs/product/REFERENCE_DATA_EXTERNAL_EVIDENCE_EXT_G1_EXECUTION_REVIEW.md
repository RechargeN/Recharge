# BCK-20 — EXT-G1 Batch EXT-A P1 Execution Review

- ID: `BCK20-OD02-EXT-EV-G1-EXEC-REV-01`
- Version: `0.1`
- Status: **Review — owner disposition pending**
- Scope: documentation-only review of completed EXT-A P1 metadata discovery
- Parent plan: `BCK20-OD02-EXT-EV-PLAN-01` v0.1
- Parent plan normalized-LF SHA-256:
  `f06d42f16fafbfe16dae0e0c546c71528fb4728c9045a5b54879c1767e4dd4ac`
- Authorization request: `BCK20-OD02-EXT-EV-G1-AUTH-01` v0.1
- Authorization request normalized-LF SHA-256:
  `a1c8f27c97ca02dd514097943431ff504d0826066b9f75288088e087b40de1f6`
- Authorization instance: `aba31978-ab80-4ca5-9d57-c976e54ebcb2`
- Owner decision: `BCK20-OD02-EXT-EV-G1-DEC-01`
- Review boundary: RechargeN / Product owner combined technical review;
  no independent or qualified Security/Privacy/Legal claim

## 1. Purpose

This document reviews the completed, bounded EXT-G1 execution without copying
third-party response bodies into the repository. It records permitted metadata,
hashes, candidate URIs, control results and retained limitations. It does not
approve a source, terms, artifact acquisition, parsing, repository ingestion or
market activation.

## 2. Exact execution identity

| Field | Recorded value |
|---|---|
| Gate / batch / phase | `EXT-G1` / `EXT-A` / `P1` |
| Started | `2026-09-18T17:42:39.8110570Z` |
| Ended | `2026-09-18T17:42:42.1875489Z` |
| Authorization expiry | `2026-09-19T18:00:00Z` |
| Requests | 2 of 4 permitted |
| Redirects | 0 |
| Aggregate response bytes | 15,033 of 4,194,304 permitted |
| Candidate links recorded | 68 |
| Candidate links followed | 0 |
| Runner outcome | `ext_g1_pass` |
| Independent local evidence verification | `pass` |
| Temporary evidence disposition | `pending_owner_review` |

The temporary evidence remains untracked at:

```text
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-a-p1-aba31978-ab80-4ca5-9d57-c976e54ebcb2
```

Deletion is not authorized by this review package.

## 3. Source results

| Source | Exact requested/final URI | HTTP | Type | Bytes | Raw response SHA-256 | Redirects | Candidates | Result |
|---|---|---:|---|---:|---|---:|---:|---|
| `SRC-IANA-LANG` | `https://www.iana.org/assignments/language-subtags-tags-extensions` | 200 | `text/html` | 6,866 | `a35082b840737a0a14b97b76c390d0983a3f73f7febb61c4b72f83229fb1056d` | 0 | 37 | `ext_g1_pass` |
| `SRC-IANA-TZDB` | `https://www.iana.org/time-zones` | 200 | `text/html` | 8,167 | `e47fb8ba6a90efe1a96cc207c31ee24a5a7e24b702a3155d7b9d197bd21450c4` | 0 | 31 | `ext_g1_pass` |

The independent local check recomputed both response hashes, reconciled the
attempt count with the directory inventory, confirmed all request/final URIs
as `https://www.iana.org:443`, and found no missing or unexpected evidence
files.

## 4. Control reconciliation

| Control | Evidence | Verdict |
|---|---|---|
| Exact two initial URIs | request metadata matches the authorization | Pass |
| Sequential `GET` only | two recorded attempts, both `GET` | Pass |
| Same-origin TLS only | both initial and final origins are `https://www.iana.org:443` | Pass |
| Redirect ceiling | zero redirects | Pass |
| Request ceiling | 2 / 4 | Pass |
| Per-response ceiling | 6,866 and 8,167 bytes / 2 MiB each | Pass |
| Aggregate ceiling | 15,033 bytes / 4 MiB | Pass |
| Candidate links not followed | 68 recorded, zero followed | Pass |
| No artifact/terms download | recorded counters are zero | Pass |
| No parser/ingestion | recorded counters are zero | Pass |
| No repository write by runner | recorded counter is zero; post-run tree was clean | Pass |
| Evidence integrity | both recorded SHA-256 values independently reproduced | Pass |

## 5. Reviewed candidate inventory

Only the following URI strings are relevant to the next decision. They were
recorded from the authorized landing responses and were not requested.

### 5.1 `SRC-IANA-LANG`

| Candidate URI | P1 observation | Proposed disposition |
|---|---|---|
| `https://www.iana.org/assignments/language-subtag-registry` | named by the landing page as the replacement registry | preferred canonical metadata candidate; requires a new exact authorization before access |
| `https://www.iana.org/assignments/language-subtags-tags-extensions/language-subtags-tags-extensions.xml` | alternate representation of the queried registry | do not acquire as the primary source; the queried registry is marked obsolete |
| `https://www.iana.org/assignments/language-subtags-tags-extensions/language-subtags-tags-extensions.txt` | alternate representation of the queried registry | do not acquire as the primary source; the queried registry is marked obsolete |
| `https://www.iana.org/help/licensing-terms` | site licensing-terms candidate | eligible only for a later, separately authorized P2 terms capture |

The obsolete-registry observation changes no authority by itself. It means the
existing external-source record must not treat the queried XML/TXT variants as
the canonical BCP 47 source without further review.

### 5.2 `SRC-IANA-TZDB`

| Candidate URI | P1 observation | Proposed disposition |
|---|---|---|
| `https://www.iana.org/time-zones/releases/2026d` | current release candidate exposed by the landing page | preferred release-metadata candidate; requires a new exact authorization before access |
| `https://www.iana.org/time-zones/releases` | release-index candidate | retain as fallback discovery candidate; do not access in the preferred next batch |

No exact archive, provider checksum, signature or TZDB-specific terms URI was
visible in the authorized landing-page link inventory. Therefore P1 did not
establish an exact artifact identity or integrity route.

## 6. Evidence interpretation

P1 proves only that both official IANA landing resources were reachable inside
the approved envelope and that candidate links were captured without being
followed. It does not prove:

- that any candidate is the legally or technically approved source;
- that IANA licensing terms cover the intended storage, parsing, derivative
  output, notices, redistribution or commercial/mobile use;
- the exact current language-registry artifact, file date or hash;
- the exact TZDB release archive, checksum/signature or bundled notices;
- structural safety, parser readiness or Baltic semantic coverage.

## 7. Recommended disposition

Recommendation: **Accept EXT-A P1 execution evidence with retained gates**.

If accepted:

1. `EXT-G1` may be recorded `Pass` only for authorization instance
   `aba31978-ab80-4ca5-9d57-c976e54ebcb2` and the two exact landing requests;
2. temporary evidence should be retained until the next exact authorization is
   decided, then deleted only by a separate explicit disposition;
3. the next preferred operation is a new bounded P1 metadata-discovery request
   for exactly these two candidate URIs:
   - `https://www.iana.org/assignments/language-subtag-registry`;
   - `https://www.iana.org/time-zones/releases/2026d`;
4. `EXT-G2` must remain closed until the extended P1 inventory is reviewed and
   a separate exact terms-capture authorization is accepted;
5. no source record, market, schema, runtime or provider status advances.

This follow-up is preferred over immediate P2 because the current evidence
identifies a replacement language registry and only a TZDB release-detail
candidate, not the exact artifacts needed for later terms and acquisition
decisions.

## 8. Retained gates

- `SRC-IANA-LANG` and `SRC-IANA-TZDB` remain Pending as external sources;
- external artifact identity, terms/use, structural safety, parser readiness
  and semantic fitness remain Pending;
- `EXT-G2`–`EXT-G6` remain closed;
- all markets remain disabled;
- `BCK20-OD-02` and `BCK20-OD-05` remain Open;
- `OD-10` remains Proposed;
- `BCK-20` remains Draft;
- `BCK20-OD-03` remains Deferred;
- independent Security/Privacy and applicable qualified Legal evidence remain
  absent;
- provider selection, schema, IAM/runtime, Firebase, deployment, activation,
  push and merge remain unauthorized.

## 9. Owner decision requested

The owner is asked to decide whether to:

1. accept this exact P1 evidence review with retained gates;
2. retain the exact temporary evidence pending the next authorization decision;
3. permit preparation of a separate, exact follow-up P1 authorization package
   for the two preferred candidate URIs in section 7.

This review does not itself authorize the follow-up network operation.

## 10. Acceptance criteria

1. **BCK20-OD02-EXT-EV-G1-EXEC-REV-AC-01:** the review binds to the exact plan, authorization hash and authorization instance.
2. **BCK20-OD02-EXT-EV-G1-EXEC-REV-AC-02:** both source results, timestamps, sizes and raw-response hashes are recorded without committing response bodies.
3. **BCK20-OD02-EXT-EV-G1-EXEC-REV-AC-03:** independent local verification reproduces both hashes and finds no evidence-inventory mismatch.
4. **BCK20-OD02-EXT-EV-G1-EXEC-REV-AC-04:** every network, origin, redirect, request-count and byte limit passes.
5. **BCK20-OD02-EXT-EV-G1-EXEC-REV-AC-05:** 68 candidate links are recorded and zero are followed.
6. **BCK20-OD02-EXT-EV-G1-EXEC-REV-AC-06:** repository writes, artifact/terms downloads, parser executions and ingestion remain zero for the runner.
7. **BCK20-OD02-EXT-EV-G1-EXEC-REV-AC-07:** the obsolete language-registry observation and preferred replacement candidate are explicit.
8. **BCK20-OD02-EXT-EV-G1-EXEC-REV-AC-08:** the TZDB release candidate is explicit while archive/checksum/signature evidence remains Pending.
9. **BCK20-OD02-EXT-EV-G1-EXEC-REV-AC-09:** temporary evidence remains untracked and deletion requires an explicit disposition.
10. **BCK20-OD02-EXT-EV-G1-EXEC-REV-AC-10:** no source, terms/use, market, BCK/OD, runtime or deployment status is promoted.
11. **BCK20-OD02-EXT-EV-G1-EXEC-REV-AC-11:** the recommended follow-up requires a new exact authorization and grants no network authority.
12. **BCK20-OD02-EXT-EV-G1-EXEC-REV-AC-12:** EXT-G2–G6, Firebase, deployment, activation, push and merge remain unauthorized.

