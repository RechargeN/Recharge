# BCK-20 — External Evidence Collection Plan

- ID: **BCK20-OD02-EXT-EV-PLAN-01**
- Version: **0.1**
- Date: **2026-09-18**
- Status: **Proposed — documentation plan only; execution unauthorized**
- Parent register: [BCK20-OD02-EXT-EV-01 v0.2](REFERENCE_DATA_EXTERNAL_SOURCE_EVIDENCE_REGISTER.md)
- Source-record decision: [BCK20-OD02-SRC-REC-DEC-01 v0.1](REFERENCE_DATA_SOURCE_RECORDS_OWNER_DECISION.md)
- Accountable owner: **Reference Data owner**
- Required reviewers: **Security/Privacy technical, Product/Market, Product Localization/Content and qualified license/Legal where applicable**
- Network authority: **none**
- Runtime effect: **none**

---

## 1. Purpose and bounded result

This plan defines how a later explicitly authorized session may revalidate and
collect evidence for the eight external candidate sources without turning a
web page, download or hash into semantic, legal or runtime approval.

The plan is not permission to access the network, follow redirects, accept
terms, download artifacts, store external data in the repository, implement a
parser, use hosted CI or publish a dataset. Each execution phase has a separate
entry gate and produces reviewable evidence before the next phase.

## 2. Source scope and execution order

| Batch | Source IDs | Purpose | Why grouped | Execution authority |
|---|---|---|---|---|
| `EXT-A` | `SRC-IANA-LANG`, `SRC-IANA-TZDB` | identifier registries and release evidence | public technical registries; no product copy | unauthorized |
| `EXT-B` | `SRC-UNICODE-CLDR` | locale display/format data | larger artifact and separate Unicode terms/notices | unauthorized |
| `EXT-C` | `SRC-UN-M49`, `SRC-EU-EURO` | country/name/mapping and euro-adoption evidence | official public-institution evidence | unauthorized |
| `EXT-D` | `SRC-ISO-3166`, `SRC-ISO-4217`, `SRC-SIX-4217` | standard identifiers and maintenance evidence | licensing/access may be restrictive or ambiguous | unauthorized |

Batches run in this order so lower-complexity technical evidence proves the
process before standards with potentially stricter use terms. Approval of one
batch never authorizes another.

## 3. Required authorization envelope

Before any network call, the owner records one execution authorization with:

```text
ExternalEvidenceExecutionAuthorization {
  authorizationId
  planId: BCK20-OD02-EXT-EV-PLAN-01
  exactPlanVersion
  exactPlanNormalizedHash
  allowedSourceIds[]
  allowedOfficialOrigins[]
  allowedRequestMethods[]
  redirectPolicy
  perArtifactByteLimit
  totalRunByteLimit
  runExpiresAtUtc
  temporaryStorageRoot
  credentialsAllowed: false
  repositoryWriteAllowed: false
  parserExecutionAllowed: false
  approvedBy
  approvedAtUtc
}
```

Defaults are fail-closed: no source IDs, origins, methods, redirects, bytes or
time are authorized by omission. Authentication, account creation, paid access,
click-through acceptance and bypass of technical controls are prohibited.

## 4. Origin and redirect policy

The later authorization must name exact origins observed during fresh discovery.
The following domains are discovery candidates inherited from the accepted
register, not a current allowlist:

| Source | Candidate official domain family | Rule |
|---|---|---|
| ISO 3166 / ISO 4217 | `iso.org` | discovery only until exact artifact and terms path are reviewed |
| UN M49 | `unstats.un.org` | exact redirect chain and artifact origin must be captured |
| SIX 4217 | `six-group.com` | no authenticated or paid route without a new decision |
| EU euro evidence | `economy-finance.ec.europa.eu` | evidence page/document only; no market-policy inference |
| IANA registries | `iana.org` | exact registry/release path and origin authentication recorded |
| Unicode CLDR | `unicode.org` | exact release/module set and license/notices recorded |

Rules:

1. deny cross-origin redirect unless the destination is explicitly added to
   the authorization after ownership is verified;
2. record the full redirect chain, final URI and retrieval timestamp;
3. reject downgrade to non-TLS transport;
4. do not send cookies, credentials, repository metadata or user data;
5. do not execute downloaded HTML, JavaScript, macros, installers or binaries;
6. reject unexpected content type, archive nesting or byte limit before saving;
7. robots, rate and provider terms are constraints, never obstacles to bypass.

## 5. Staged collection procedure

### P0 — authorization and clean workspace

- verify exact plan version/hash and allowed source subset;
- use a new cleanup-bound temporary directory outside tracked repository paths;
- record tool versions, operating system, UTC clock source and run ID;
- prove Git working tree state before execution;
- confirm no secrets, credentials or authenticated browser session are used.

Exit: signed authorization exists and temporary scope is exact. Otherwise
`authorization_missing` and no network call occurs.

### P1 — metadata discovery

- request only the minimum authorized official pages required to locate the
  artifact and terms evidence;
- capture status, headers, content type, content length when supplied, redirect
  chain, final URI and retrieval timestamp;
- do not treat metadata success as artifact or license evidence;
- stop on authentication, payment, click-through, ambiguous origin or
  disallowed redirect.

Exit: candidate artifact and terms URIs are recorded for owner review. No
artifact download is implied.

### P2 — terms and allowed-use evidence

- capture the exact terms/license page or bundled license file identified for
  the candidate artifact;
- hash raw bytes and record retrieval metadata;
- extract no legal conclusion automatically;
- list questions for storage, parsing, derived data, notices, redistribution,
  update frequency and commercial/mobile use;
- qualified review is required where the disposition depends on legal judgment.

Exit: `terms_evidence_captured` only. Allowed use remains Pending until an
explicit reviewer disposition exists.

### P3 — artifact acquisition

- requires a second authorization referencing P1/P2 evidence and an exact URI,
  expected type and byte limits;
- stream into the cleanup-bound temporary directory without execution;
- compute SHA-256 over raw bytes during or immediately after transfer;
- preserve provider checksum/signature separately when available;
- never auto-unpack an archive or follow embedded links.

Exit: immutable raw-artifact evidence exists in temporary quarantine. It is
not repository data and not an approved source.

### P4 — structural inspection

- inspect archive/file inventory without executing contents;
- reject path traversal, absolute paths, symlinks escaping the temporary root,
  unexpected binaries, encrypted members or nested archives outside the
  authorization;
- calculate per-member hashes only when the approved scope requires them;
- record exact modules/files proposed for later parsing and all exclusions.

Exit: a bounded artifact inventory exists or the run fails closed.

### P5 — deterministic validation design

- produce fixture vectors and expected results for the exact source family;
- select or design a parser only in a separately approved code slice;
- parser output must preserve source identity, withdrawals/deprecations and
  provenance, and must reject unknown/newer critical forms;
- no parsed data enters repository, Firebase, schema or application runtime.

Exit: reviewable validation design. Parser execution remains unauthorized by
this plan.

### P6 — evidence disposition

- assemble `ExternalSourceEvidenceRecord` from the accepted register;
- mark each dimension independently: origin, artifact identity, terms/use,
  structural safety, parser readiness and semantic field scope;
- `pass` applies only to completed checks; any missing dimension stays Pending;
- owner decision may advance a source only to `eligible_for_slice_review`;
- ingestion still requires a later Approved executable slice.

## 6. Source-specific evidence checklist

| Source ID | Identity/version evidence | Terms evidence | Structural/semantic checks | Stop conditions |
|---|---|---|---|---|
| `SRC-IANA-LANG` | exact registry file date/version and raw hash | exact IANA terms disposition | record syntax, preferred/deprecated values, canonicalization vectors | ambiguous origin, malformed registry, unknown critical field |
| `SRC-IANA-TZDB` | exact release archive, release name, checksum/signature where published | exact bundled/external terms | expected files, zone/link uniqueness, Baltic zone presence | unexpected executable, bad signature/hash, missing named zone |
| `SRC-UNICODE-CLDR` | exact release and exact module inventory | Unicode license and required notices | locale inheritance, parser compatibility, bounded module size | unclear module scope, missing notices, unexpected archive content |
| `SRC-UN-M49` | dated table/snapshot and raw hash | exact reuse/attribution terms | code width, uniqueness, ISO mapping consistency, name provenance | undated mutable output without a reproducible snapshot |
| `SRC-EU-EURO` | dated page/document snapshot and hash | exact reuse/attribution terms | explicit LV/EE/LT euro-adoption statement only | inference beyond published statement or missing date/provenance |
| `SRC-ISO-3166` | exact authorized code-list artifact/release | storage/derivative/redistribution disposition | alpha identity, reserved/withdrawn handling | paywall/click-through/terms ambiguity or no lawful snapshot route |
| `SRC-ISO-4217` | exact authorized standard/release evidence | standard/data use disposition | alphabetic/numeric identity and minor-unit bounds | no exact lawful artifact or unclear version |
| `SRC-SIX-4217` | dated maintenance-list artifact and hash | access/automation/storage/redistribution disposition | change/withdrawal consistency with accepted currency evidence | authentication/paid access required or terms unresolved |

## 7. Evidence artifacts and repository boundary

During an authorized collection run, all downloaded bytes and derived
inventories remain in the named temporary root. The repository may receive
only a later owner-approved, non-copyright-infringing evidence record that
contains permitted metadata, hashes, provenance, decisions and required
notices. Raw third-party content is never committed by default.

Any proposal to track raw or derived external data must specify:

- exact files and byte size;
- license/terms basis and required notices;
- update, retention and removal process;
- parser and fixture ownership;
- generated-file policy and review diff strategy;
- rollback and source-withdrawal handling.

## 8. Typed outcomes

| Outcome | Meaning / required action |
|---|---|
| `authorization_missing` | no network action; obtain exact owner authorization |
| `origin_unverified` | stop; do not follow/download |
| `redirect_disallowed` | stop; owner must approve exact destination |
| `authentication_required` | stop; new decision required |
| `terms_inconclusive` | keep source Pending; no artifact use |
| `artifact_too_large` | stop before saving; revise bounded authorization if justified |
| `content_type_unexpected` | quarantine/stop; do not execute or unpack |
| `integrity_failed` | discard temporary artifact and record failure evidence |
| `structure_unsafe` | discard/quarantine and block source |
| `validation_inconclusive` | retain evidence but do not advance source state |
| `eligible_for_slice_review` | evidence package complete enough for owner review; ingestion still forbidden |

Timeout or interrupted transfer is `unknown/incomplete`, never success. Retry
requires the same authorization to remain valid and creates a new attempt ID.

## 9. Cleanup and rollback

Before repository/runtime integration, rollback is evidence-only:

1. cancel the run and block additional requests;
2. record attempt ID, completed requests, byte counts and failure reason;
3. remove temporary downloaded content after any required security inspection
   and evidence preservation decision;
4. retain only permitted minimal metadata needed to explain the outcome;
5. do not promote the source state;
6. if any tracked file was proposed later, revert only through a reviewed
   superseding commit and preserve the decision history.

No production data or cloud rollback exists because this plan creates none.

## 10. Evidence and acceptance gates

| Gate | Required evidence | Opens |
|---|---|---|
| `EXT-G0` | exact plan owner decision | planning baseline only |
| `EXT-G1` | explicit bounded network authorization for named batch | P1 metadata discovery only |
| `EXT-G2` | reviewed P1 result and separate terms-capture authorization | P2 terms evidence only |
| `EXT-G3` | terms evidence captured, exact artifact URI/type/limits and second authorization | P3 artifact acquisition only |
| `EXT-G4` | raw hash/origin/inventory pass and safe artifact disposition | P5 validation-design work only |
| `EXT-G5` | terms/use disposition, validation evidence and owner review | `eligible_for_slice_review` only |
| `EXT-G6` | separately Approved exact-file executable slice | parser/repository ingestion work |

Gates are monotonic only for their exact evidence. A source update, URI change,
terms change, hash mismatch or expired authorization closes the affected gate.

## 11. Retained non-authority

- network access and every collection gate remain unauthorized;
- no terms/license conclusion or qualified Legal claim is made;
- no external artifact, parser, fixture or derived dataset exists;
- every market remains disabled;
- BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and
  BCK20-OD-03 Deferred;
- provider selection, schema, IAM/runtime, Firebase, deployment, activation,
  push and merge remain unauthorized.

## 12. Acceptance criteria

1. **BCK20-OD02-EXT-EV-PLAN-AC-01:** the plan itself grants no network or download authority.
2. **BCK20-OD02-EXT-EV-PLAN-AC-02:** eight sources are partitioned into independently authorized batches.
3. **BCK20-OD02-EXT-EV-PLAN-AC-03:** every network run requires exact plan hash, sources, origins, methods, byte limits and expiry.
4. **BCK20-OD02-EXT-EV-PLAN-AC-04:** credentials, paid access, click-through acceptance and control bypass are prohibited.
5. **BCK20-OD02-EXT-EV-PLAN-AC-05:** redirects and final origin are fail-closed and fully recorded.
6. **BCK20-OD02-EXT-EV-PLAN-AC-06:** terms evidence is separate from legal/use disposition.
7. **BCK20-OD02-EXT-EV-PLAN-AC-07:** artifact acquisition requires a second exact authorization after discovery and terms capture.
8. **BCK20-OD02-EXT-EV-PLAN-AC-08:** raw bytes are hashed and quarantined without execution or automatic unpacking.
9. **BCK20-OD02-EXT-EV-PLAN-AC-09:** archive inspection rejects traversal, escaping links, unexpected binaries and unauthorized nesting.
10. **BCK20-OD02-EXT-EV-PLAN-AC-10:** parser design and execution remain separate Approved work.
11. **BCK20-OD02-EXT-EV-PLAN-AC-11:** source-specific evidence cannot broaden field authority or market policy.
12. **BCK20-OD02-EXT-EV-PLAN-AC-12:** raw third-party content is not committed by default.
13. **BCK20-OD02-EXT-EV-PLAN-AC-13:** typed incomplete/failure outcomes never become success.
14. **BCK20-OD02-EXT-EV-PLAN-AC-14:** cleanup preserves only permitted minimal evidence and creates no cloud rollback.
15. **BCK20-OD02-EXT-EV-PLAN-AC-15:** each gate opens only its named next phase.
16. **BCK20-OD02-EXT-EV-PLAN-AC-16:** changed source, terms, URI, hash or expired authorization closes affected gates.
17. **BCK20-OD02-EXT-EV-PLAN-AC-17:** eligible-for-slice-review never means ingestion approval.
18. **BCK20-OD02-EXT-EV-PLAN-AC-18:** all markets and BCK-20/OD/runtime gates retain their current closed state.
19. **BCK20-OD02-EXT-EV-PLAN-AC-19:** Firebase, deployment, activation, push and merge remain unauthorized.
20. **BCK20-OD02-EXT-EV-PLAN-AC-20:** any plan content/version/hash change requires a new owner review before execution.

## 13. Next action

Freeze this v0.1 plan by normalized-LF SHA-256 in a bounded combined-owner
review package. Do not request network authorization or begin P0–P6 until the
exact plan decision is recorded.
