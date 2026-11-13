# BCK-20 — EXT-A–D Qualified Terms and Access Review Package

- ID: **BCK20-OD02-EXT-AD-TERMS-ACCESS-REV-01**
- Version: **0.1**
- Date: **2026-09-19**
- Status: **Proposed — qualified review input; no qualified verdict recorded**
- Prepared by: **RechargeN / Product owner combined technical role**
- Required reviewer: **named qualified terms/license reviewer for the
  applicable jurisdictions and intended commercial use**
- Independence: **not established**
- Legal advice claim: **none**
- Runtime effect: **none**

---

## 1. Purpose and decision boundary

This package asks a qualified reviewer to decide the allowed-use and access
conditions for eight external source records. It contains technical evidence
and precise questions; it is not legal advice, terms acceptance or source
approval.

A reviewer verdict does not automatically move a source to
`eligible_for_slice_review`. Each source requires a later owner decision, and
any executable use requires a separately Approved slice.

## 2. Frozen technical inputs

Hashes are SHA-256 over UTF-8 bytes after CRLF-to-LF normalization.

| Input | Version | Normalized-LF SHA-256 |
|---|---|---|
| `REFERENCE_DATA_EXT_A_P6_EVIDENCE_RECORD.md` | v0.1 | `cf461ecc01650bb50e70a8dde0e32f5b8acca1cfee628e98cc0baef426e0892d` |
| `REFERENCE_DATA_EXT_B_P6_EVIDENCE_RECORD.md` | v0.1 | `6c69688f7cbfb180a871631bb107cc1e550c6dc066c16405d5c433ebe279115d` |
| `REFERENCE_DATA_EXT_C_P6_EVIDENCE_RECORD.md` | v0.1 | `c47d51f87dab836d3b6efcb85be9759be8475f7301068a9f084196208410e96c` |
| `REFERENCE_DATA_EXT_D_P6_EVIDENCE_RECORD.md` | v0.1 | `baa3a8527c5d545a12361154c8de77c983b95a9c2cce8b458a083356040c8533` |
| `REFERENCE_DATA_EXT_A_D_SOURCE_TERMS_DECISION_PACKAGE.md` | v0.1 | `596873a51fd09839b4d63f80cdcb0cc5a2c21cfbe97ec377e7678f5173727bd1` |

The owner acceptance is recorded in
`BCK20-OD02-EXT-AD-SRC-TERMS-DEC-01` v0.1. Changed input content or hashes
require impact analysis and a new review revision.

## 3. Exact terms and access evidence

| Family | Exact captured evidence | SHA-256 / outcome | Review state |
|---|---|---|---|
| IANA | IANA licensing-terms page | `43cfd90b1cb25ca86933032612a2c466fac94d7afc934ca8ef96a61e2b55e1b3` | evidence captured; disposition Pending |
| Unicode external | Unicode License v3 page | `e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96` | evidence captured; disposition Pending |
| Unicode bundled | CLDR 48.2 archive `LICENSE` | `780ed0d1e595f6bb3e7cad757ea147315596b96e75d6a271ae95e882185c8aa7` | evidence captured; notice/use obligations Pending |
| United Nations | UN terms-of-use page | `fc8db19659b8622d474340bf5d26e26ec5cc1e581c8e247c2e05333f51df5f94` | evidence captured; disposition Pending |
| European Commission | legal-notice page | `53841095389ec2b365b70a7a683426bf40d1df644a3ff7c64155364ea1fff739` | evidence captured; disposition Pending |
| ISO | ISO copyright/terms endpoint | HTTP 403; no response body retained | Blocked; no terms conclusion available |
| SIX | approved legacy disclaimer endpoint | HTTP 404; no terms body retained | Inconclusive; current candidate not visited |

Raw third-party content remains in authorized OS-temp evidence roots and is
not included in this package or repository.

## 4. Intended Recharge use to evaluate

The contemplated product is a commercial mobile application for Latvia with
planned Baltic expansion. The bounded candidate uses are:

- validate and canonicalize locale identifiers;
- provide locale display/format conventions for `en`, `ru`, `lv`, `et`, `lt`;
- validate IANA time-zone identifiers and transitions;
- retain M49 numeric mappings and limited country-name evidence;
- retain corroborating euro-adoption facts;
- validate current/historic currency identifiers and minor-unit evidence.

None of these sources may define Recharge market enablement, service areas,
product copy, mandatory Legal copy, price, tax, payment support or exchange
rates.

## 5. Required verdict per source

For every applicable source, the named reviewer must answer each row with one
of: `Allowed with controls`, `Not allowed`, `Inconclusive`, or
`Blocked by unavailable terms`.

| Question | Required determination |
|---|---|
| exact snapshot storage | whether Recharge may retain the acquired source snapshot and for how long |
| parsing and validation | whether automated local/CI parsing and validation are permitted |
| derived facts | whether normalized identifiers, mappings and bounded facts may be stored |
| commercial distribution | whether derived values may ship in a commercial mobile product/backend |
| modification/localization | whether formatting, normalization, selection or localized presentation is permitted |
| notices and attribution | exact copyright, attribution, source-link and change-notice text/placement |
| repository/CI material | whether fixtures, excerpts, generated bundles or notices may be tracked or processed in hosted CI |
| automated refresh | allowed request method/frequency, rate limits and access controls |
| withdrawal/replacement | deletion, replacement, audit-retention and downstream correction duties |
| account/license | whether an account, purchase, agreement, click-through or separate license is required |

The verdict must identify the exact evidence hash reviewed, reviewer name and
capacity, date, jurisdiction assumptions, intended-use assumptions, required
controls, open questions and re-review trigger.

## 6. Source-specific questions

### 6.1 IANA Language and TZDB

- Do the captured IANA terms and bundled TZDB `LICENSE` permit snapshot
  storage, automated parsing and commercial redistribution of derived locale
  and time-zone data?
- Which notices must ship in application, backend, repository or distribution
  artifacts?
- Does absence of a provider checksum/signature require any additional legal
  or contractual control?

### 6.2 Unicode CLDR 48.2

- Do the external Unicode License v3 text and bundled CLDR `LICENSE` govern
  the same selected modules and agree for the contemplated use?
- What copyright/license notices, attribution and copy-of-license obligations
  apply to derived format data and generated bundles?
- Are localized or subsetted outputs and hosted-CI processing permitted?
- Must UTS #35 be separately pinned or reproduced for compliance purposes?

### 6.3 UN M49

- May Recharge retain a retrieval-dated source snapshot and derived code/name
  mappings from the mutable, undated response?
- What attribution, source-link, modification and commercial redistribution
  conditions apply?
- Does the terms page require a narrower country-name or code-only scope?

### 6.4 European Commission euro evidence

- May Recharge retain and display the selected adoption-year facts in a
  commercial product?
- What attribution/reuse notice applies, and do third-party-content carve-outs
  require item-level verification?
- Is periodic automated revalidation permitted?

### 6.5 ISO 3166 and direct ISO 4217

- Is a paid/licensed artifact, account or separate agreement required for the
  intended code/edition evidence?
- May Recharge use only independently lawful UN/SIX facts without claiming
  possession or licensing of the ISO standards?
- What wording avoids a false claim of ISO edition authority?

Until answered, both direct ISO sources remain
`Blocked by unavailable terms` and no substitute may be relabelled as ISO
evidence.

### 6.6 SIX 4217 maintenance lists

- Do the current SIX terms permit automated acquisition, snapshot storage,
  derived currency facts and commercial redistribution?
- What notices or source links are mandatory?
- Is List Two required for the intended Recharge scope, and may the exposed
  `.doc` be acquired and safely converted under the same terms?
- Are locally computed hashes adequate evidence, or is provider integrity
  evidence contractually required?

Until current terms are captured under a separate authorization, the verdict
is at most `Inconclusive`.

## 7. Minimum controls for any positive verdict

An `Allowed with controls` verdict must define, at minimum:

1. exact source, version/date, field scope and permitted derived output;
2. required notices and their delivery location;
3. prohibited uses and non-authority statements;
4. retention, refresh, changed-hash and withdrawal policy;
5. whether raw content, excerpts, fixtures or generated output may enter Git;
6. whether hosted CI may process the evidence;
7. access/rate/account restrictions;
8. re-review triggers for changed terms, source URI, schema, version or use.

Unknown, conditional, conflicting or source-unavailable answers fail closed.

## 8. Review record template

One completed block is required per source ID:

```text
QualifiedTermsAccessVerdict {
  sourceId
  exactEvidenceHashes[]
  reviewerName
  reviewerCapacityAndQualification
  reviewedAtUtc
  jurisdictionAndUseAssumptions[]
  determinations {
    snapshotStorage
    parsingAndValidation
    derivedFacts
    commercialDistribution
    modificationAndLocalization
    noticesAndAttribution
    repositoryAndCiMaterial
    automatedRefresh
    withdrawalAndReplacement
    accountOrLicense
  }
  requiredControls[]
  prohibitedUses[]
  openQuestions[]
  reReviewTriggers[]
  overallVerdict: allowed_with_controls | not_allowed | inconclusive |
    blocked_by_unavailable_terms
}
```

## 9. Status effects and next decision

Preparing or completing this review changes no source automatically. After a
qualified verdict:

1. the product owner records one explicit decision per source;
2. the evidence register is updated atomically with that decision;
3. only a source explicitly advanced to `eligible_for_slice_review` may enter
   an EXT-G6 proposal;
4. parser, fixtures, datasets, runtime and market activation remain later,
   separately authorized work.

## 10. Retained gates

- no qualified verdict is currently recorded;
- no terms, license or click-through is accepted by this document;
- no new network access is authorized;
- no source is `eligible_for_slice_review`;
- raw third-party evidence remains outside the repository;
- all markets remain disabled;
- BCK20-OD-02/05 remain Open, OD-10 Proposed, BCK-20 Draft and
  BCK20-OD-03 Deferred;
- parser, fixtures, datasets, schema, IAM/runtime, Firebase, ingestion,
  deployment and activation remain unauthorized;
- push and merge remain unauthorized.

## 11. Acceptance criteria

1. **BCK20-OD02-EXT-AD-TA-REV-AC-01:** every technical input is pinned by exact version and normalized hash.
2. **BCK20-OD02-EXT-AD-TA-REV-AC-02:** every captured terms/access artifact is identified by hash or exact HTTP outcome.
3. **BCK20-OD02-EXT-AD-TA-REV-AC-03:** the package makes no qualified Legal or terms-acceptance claim.
4. **BCK20-OD02-EXT-AD-TA-REV-AC-04:** intended product use and explicit non-authority are bounded.
5. **BCK20-OD02-EXT-AD-TA-REV-AC-05:** ten required determinations are requested separately per source.
6. **BCK20-OD02-EXT-AD-TA-REV-AC-06:** ISO blocked access and SIX missing current terms remain fail-closed.
7. **BCK20-OD02-EXT-AD-TA-REV-AC-07:** positive verdicts require notices, retention, refresh, withdrawal and re-review controls.
8. **BCK20-OD02-EXT-AD-TA-REV-AC-08:** a qualified verdict cannot automatically approve a source or executable slice.
9. **BCK20-OD02-EXT-AD-TA-REV-AC-09:** no source advances to `eligible_for_slice_review` from this package.
10. **BCK20-OD02-EXT-AD-TA-REV-AC-10:** network and all executable/deployment actions remain unauthorized.
11. **BCK20-OD02-EXT-AD-TA-REV-AC-11:** push and merge remain unauthorized.
