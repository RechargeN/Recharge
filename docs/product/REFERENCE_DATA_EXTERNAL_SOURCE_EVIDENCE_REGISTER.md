# BCK-20 — External Source Evidence Register

- ID: **BCK20-OD02-EXT-EV-01**
- Version: **0.3**
- Date: **2026-09-19**
- Status: **Accepted evidence register — EXT-A–D technical evidence reconciled; no source approved for ingestion**
- Parent: [BCK20-OD02-SRC-REC-01 v0.2](REFERENCE_DATA_INTERNAL_SOURCE_RECORDS.md)
- Authority boundary: [BCK20-OD02-SRC-AUTH-01 v0.2](REFERENCE_DATA_SOURCE_AUTHORITY_MATRIX.md)
- Accountable owner: **Reference Data owner**
- Owner decision: [BCK20-OD02-SRC-REC-DEC-01 v0.1](REFERENCE_DATA_SOURCE_RECORDS_OWNER_DECISION.md)
- Technical baseline decision:
  [BCK20-OD02-EXT-AD-SRC-TERMS-DEC-01 v0.1](REFERENCE_DATA_EXT_A_D_SOURCE_TERMS_OWNER_DECISION.md)
- Legal/license disposition: **Pending for every external source**
- Runtime effect: **none**

---

## 1. Purpose

This register reconciles the accepted candidate-source list with exact EXT-A–D
technical evidence. It records evidence already collected under separately
bounded authorizations; this revision performs no network work. It does not
accept terms, determine lawful use, select a parser or authorize ingestion.

## 2. Evidence-state vocabulary

| State | Meaning |
|---|---|
| `discovery_only` | official source/role was observed, but no immutable artifact or use right is accepted |
| `artifact_pending` | exact release/file and content hash are absent |
| `terms_pending` | license/terms and allowed-use scope have no accepted disposition |
| `validation_pending` | parser/extraction and deterministic validation evidence are absent |
| `technical_evidence_captured` | exact artifact/response and bounded deterministic validation are pinned; terms and remaining gates still apply |
| `partial_technical_evidence` | some exact source dimensions passed, while named required dimensions remain absent or blocked |
| `access_blocked` | the authorized client could not obtain the required exact source or terms evidence without a new access decision |
| `freshness_pending` | mutable or retrieval-dated evidence lacks an accepted maximum-age/update policy |
| `spec_pin_pending` | the artifact is pinned but an associated normative specification version is not |
| `integrity_evidence_pending` | local hashes exist but required provider checksum/signature evidence is absent |
| `eligible_for_slice_review` | all required evidence exists; still not ingestion approval |
| `blocked` | source must not be used until the named issue is resolved |

Only a later explicit decision may move a source to
`eligible_for_slice_review`. That state still requires an Approved executable
slice before repository data, parser code or runtime work.

## 3. External source work register

The “evidence result” column is factual status for exact P6 records, not a
source allowlist. Raw third-party content remains outside the repository.

| Source ID | Bounded field authority | Exact technical evidence | Remaining terms/access/freshness gate | Current state |
|---|---|---|---|---|
| `SRC-ISO-3166` | ISO country code elements | landing and copyright endpoints returned HTTP 403; no artifact acquired | lawful exact artifact/edition and terms evidence | `access_blocked`, `artifact_pending`, `terms_pending` |
| `SRC-UN-M49` | M49 numeric codes, UN short names and ISO mapping evidence | exact full-view response; six 248-row tables; Baltic mappings Pass | qualified allowed-use decision and maximum-age/changed-hash policy for mutable undated response | `technical_evidence_captured`, `freshness_pending`, `terms_pending` |
| `SRC-ISO-4217` | direct ISO standard identity/edition | standard and copyright endpoints returned HTTP 403; SIX does not replace direct ISO evidence | lawful exact edition/artifact and ISO terms evidence | `access_blocked`, `artifact_pending`, `terms_pending` |
| `SRC-SIX-4217` | ISO 4217 maintenance/change evidence | authority page, List One dated `2026-09-17` and List Three dated `2026-01-01` Pass; List Two XML absent | current SIX terms, List Two disposition and provider integrity evidence | `partial_technical_evidence`, `integrity_evidence_pending`, `terms_pending` |
| `SRC-EU-EURO` | corroborating euro-adoption evidence | exact Commission page and Baltic adoption years Pass | qualified legal-notice decision and freshness policy for retrieval-dated page | `technical_evidence_captured`, `freshness_pending`, `terms_pending` |
| `SRC-IANA-LANG` | registered BCP 47 subtags/extensions | exact registry `File-Date` `2026-09-17`; structural and Baltic validation Pass | qualified IANA terms/use disposition | `technical_evidence_captured`, `terms_pending` |
| `SRC-UNICODE-CLDR` | locale display/format data and algorithms | exact CLDR 48.2 archive/module inventory and selected validation Pass | qualified Unicode terms/notices decision; immutable UTS #35 48.2 pin; checksum filename anomaly retained | `technical_evidence_captured`, `spec_pin_pending`, `terms_pending` |
| `SRC-IANA-TZDB` | IANA zone IDs and transition data | exact release `2026d`; archive inventory and Baltic validation Pass | qualified terms/notices decision and provider checksum/signature disposition | `technical_evidence_captured`, `integrity_evidence_pending`, `terms_pending` |

## 4. Required evidence record

One immutable record is required per source artifact and allowed-use scope:

```text
ExternalSourceEvidenceRecord {
  evidenceId
  sourceId
  recordFamilies[]
  authorityFieldScope[]
  sourceArtifactName
  sourceArtifactVersion
  canonicalRetrievalUri
  retrievalRedirectChain?
  retrievedAtUtc
  originAuthenticationMethod
  rawContentHash
  normalizedContentHash?
  signatureOrChecksumEvidence?
  licenseOrTermsUri
  licenseOrTermsVersionOrRetrievedAt
  allowedUseScope
  requiredNotices[]
  prohibitedUses[]
  retentionOrRedistributionConstraints[]
  parserOrExtractionVersion
  validationMethod
  validationResult: pass | fail | inconclusive
  reviewedBy[]
  approvedAtUtc?
  recheckAtUtc
  supersedesEvidenceId?
}
```

The evidence ID is not a source authority. A matching hash proves content
identity only; it does not prove lawful use, semantic scope or correctness.

## 5. Minimum validation by source family

| Family | Required deterministic checks before slice review |
|---|---|
| country codes | uniqueness, canonical casing, expected code widths, mapping consistency, withdrawn/reserved handling |
| currency codes | unique alphabetic/numeric identity, minor-unit bounds, withdrawal/change handling, no price/rate inference |
| locale identifiers | registry syntax, preferred-value/deprecation handling, canonicalization vectors |
| CLDR data | exact module inventory, locale inheritance boundary, parser compatibility, notice preservation, size limits |
| tzdb | release identity, zone/link uniqueness, expected Baltic zones, transition parser compatibility, unknown-zone failure |
| EU adoption evidence | exact country/currency statement and retrieval date; never automatic market assignment |

All checks must run on a disposable local fixture first. Hosted CI, repository
tracking, production configuration or runtime ingestion require later explicit
authorization.

## 6. Conflict, freshness and withdrawal

1. A newer release never silently replaces pinned evidence.
2. Release change requires new evidence ID, impact analysis and parser/fixture
   rerun.
3. Conflicting official sources block only the affected fields and require an
   accountable owner decision.
4. Expired, unavailable, unverifiable or terms-inconclusive evidence remains
   fail-closed.
5. Withdrawal/deprecation is preserved as history and cannot be erased by a
   cached older artifact.
6. Recheck dates are evidence policy, not background-network permission.
7. No source may broaden itself from identifier/locale data into Recharge
   market, product, Legal or activation authority.

## 7. Retained gates

- every row remains `terms_pending`; ISO 3166/direct ISO 4217 also remain
  `access_blocked` and `artifact_pending`;
- technical or partial evidence does not move any source to
  `eligible_for_slice_review`;
- no external source is approved for redistribution, repository storage,
  parser implementation or ingestion;
- qualified Legal/license review remains Pending where applicable;
- BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and
  BCK20-OD-03 Deferred;
- provider selection, schema, IAM/runtime, Firebase, deployment, activation,
  push and merge remain unauthorized.

## 8. Acceptance criteria

1. **BCK20-OD02-EXT-EV-AC-01:** each external source has one bounded field-authority scope.
2. **BCK20-OD02-EXT-EV-AC-02:** inherited observations are not described as current revalidation.
3. **BCK20-OD02-EXT-EV-AC-03:** an official URL is never treated as immutable artifact evidence.
4. **BCK20-OD02-EXT-EV-AC-04:** content identity and lawful allowed-use scope are separate evidence.
5. **BCK20-OD02-EXT-EV-AC-05:** every executable candidate requires exact artifact version and hash.
6. **BCK20-OD02-EXT-EV-AC-06:** every executable candidate requires terms/license and notice disposition.
7. **BCK20-OD02-EXT-EV-AC-07:** every executable candidate requires parser/extraction and validation evidence.
8. **BCK20-OD02-EXT-EV-AC-08:** source updates create new immutable evidence and impact analysis.
9. **BCK20-OD02-EXT-EV-AC-09:** missing, stale, conflicting or terms-inconclusive evidence fails closed.
10. **BCK20-OD02-EXT-EV-AC-10:** external identifier data cannot create Recharge product or activation policy.
11. **BCK20-OD02-EXT-EV-AC-11:** source-specific validation is bounded and deterministic.
12. **BCK20-OD02-EXT-EV-AC-12:** this register performs no network retrieval or terms acceptance.
13. **BCK20-OD02-EXT-EV-AC-13:** no repository data, parser, schema or runtime ingestion is authorized.
14. **BCK20-OD02-EXT-EV-AC-14:** Firebase, deployment, activation, push and merge remain unauthorized.
15. **BCK20-OD02-EXT-EV-AC-15:** a future executable slice still requires explicit approval after evidence readiness.
16. **BCK20-OD02-EXT-EV-AC-16:** every technical state is pinned to an exact EXT-A–D P6 record and remains separate from terms acceptance.
17. **BCK20-OD02-EXT-EV-AC-17:** no source is `eligible_for_slice_review` after v0.3 reconciliation.
18. **BCK20-OD02-EXT-EV-AC-18:** ISO access failures and SIX/CLDR/IANA/UN/EU limitations remain visible and fail closed.

## 9. Recorded disposition and next action

BCK20-OD02-SRC-REC-DEC-01 continues to preserve the frozen v0.1 work queue.
BCK20-OD02-EXT-AD-SRC-TERMS-DEC-01 accepts the exact EXT-A–D P6 documents,
through package normalized-LF SHA-256
`596873a51fd09839b4d63f80cdcb0cc5a2c21cfbe97ec377e7678f5173727bd1`,
as the technical evidence baseline with retained gates.

This v0.3 revision is factual reconciliation only. Technical collection is
complete for the exact pinned evidence, but terms/access, freshness,
specification and integrity gaps remain as recorded. Every source remains
unapproved for ingestion and outside `eligible_for_slice_review`. The next
authorized action is the consolidated qualified terms/access review; network
or executable work requires a new decision.
