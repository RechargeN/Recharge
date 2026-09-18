# BCK-20 — External Source Evidence Register

- ID: **BCK20-OD02-EXT-EV-01**
- Version: **0.2**
- Date: **2026-09-18**
- Status: **Accepted evidence work queue — no source approved for ingestion**
- Parent: [BCK20-OD02-SRC-REC-01 v0.2](REFERENCE_DATA_INTERNAL_SOURCE_RECORDS.md)
- Authority boundary: [BCK20-OD02-SRC-AUTH-01 v0.2](REFERENCE_DATA_SOURCE_AUTHORITY_MATRIX.md)
- Accountable owner: **Reference Data owner**
- Owner decision: [BCK20-OD02-SRC-REC-DEC-01 v0.1](REFERENCE_DATA_SOURCE_RECORDS_OWNER_DECISION.md)
- Legal/license disposition: **Pending for every external source**
- Runtime effect: **none**

---

## 1. Purpose

This register converts the accepted candidate-source list into a bounded
evidence work queue. It does not repeat or upgrade the 2026-09-17 observations
in the authority matrix. No network revalidation, artifact download, terms
acceptance, license determination, parser choice or executable ingestion is
claimed by this revision.

## 2. Evidence-state vocabulary

| State | Meaning |
|---|---|
| `discovery_only` | official source/role was observed, but no immutable artifact or use right is accepted |
| `artifact_pending` | exact release/file and content hash are absent |
| `terms_pending` | license/terms and allowed-use scope have no accepted disposition |
| `validation_pending` | parser/extraction and deterministic validation evidence are absent |
| `eligible_for_slice_review` | all required evidence exists; still not ingestion approval |
| `blocked` | source must not be used until the named issue is resolved |

Only a later explicit decision may move a source to
`eligible_for_slice_review`. That state still requires an Approved executable
slice before repository data, parser code or runtime work.

## 3. External source work register

All observations below are inherited from BCK20-OD02-SRC-AUTH-01 and are stale
until deliberately rechecked. “Artifact required” describes the evidence to
capture, not permission to download or redistribute it.

| Source ID | Bounded field authority | Last inherited observation | Artifact required | Terms/use evidence | Current state |
|---|---|---|---|---|---|
| `SRC-ISO-3166` | ISO country code elements | official ISO page observed 2026-09-17 | exact approved code-list release/file or licensed snapshot + hash | redistribution, storage, derivative and update rights | `artifact_pending`, `terms_pending` |
| `SRC-UN-M49` | M49 numeric codes, UN short names and ISO mapping evidence | official UNSD page observed 2026-09-17 | dated downloadable table/snapshot + hash | reuse/attribution/redistribution terms | `artifact_pending`, `terms_pending` |
| `SRC-ISO-4217` | alphabetic/numeric currency codes and minor-unit relationship | ISO standard page observed 2026-09-17 | exact standard/release evidence + hash where lawful | standard/data use and redistribution rights | `artifact_pending`, `terms_pending` |
| `SRC-SIX-4217` | ISO 4217 maintenance/change evidence | official SIX maintenance role observed 2026-09-17 | dated maintenance-list artifact + hash | access, automation, storage and redistribution terms | `artifact_pending`, `terms_pending` |
| `SRC-EU-EURO` | corroborating euro-adoption evidence | Commission page observed 2026-09-17 | dated page/document snapshot + hash | reuse/attribution terms | `artifact_pending`, `terms_pending` |
| `SRC-IANA-LANG` | registered BCP 47 subtags/extensions | official registry observed 2026-09-17 | exact registry file with file date + hash | IANA terms/license disposition | `artifact_pending`, `terms_pending` |
| `SRC-UNICODE-CLDR` | locale display/format data and algorithms | CLDR 48.2 / UTS #35 observed 2026-09-17 | exact CLDR release archive/module set + hash | Unicode license, notices, redistribution and modification obligations | `artifact_pending`, `terms_pending` |
| `SRC-IANA-TZDB` | IANA zone IDs and transition data | release 2026d observed 2026-09-17 | exact release archive + signature/hash | IANA tzdb terms/notices and redistribution disposition | `artifact_pending`, `terms_pending` |

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

- every row remains `artifact_pending` and `terms_pending`;
- no external source is approved for download, redistribution, repository
  storage, parser implementation or ingestion;
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

## 9. Recorded disposition and next action

BCK20-OD02-SRC-REC-DEC-01 accepts the frozen v0.1 register at normalized-LF
SHA-256 `faee6caaa2a65380c2e631c745669f32da20926502792560c657184bd3bf750d`
as a work queue only. Every source remains unapproved for ingestion. This v0.2
revision adds status traceability without changing the frozen work items.

Network revalidation, artifact retrieval, terms/license disposition and
validation evidence remain separate work requiring explicit authorization.
