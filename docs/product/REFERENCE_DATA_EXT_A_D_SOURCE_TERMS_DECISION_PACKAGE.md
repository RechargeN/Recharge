# BCK-20 — EXT-A–D Source and Terms Decision Package

- ID: `BCK20-OD02-EXT-AD-SRC-TERMS-DEC-PKG-01`
- Version: `0.1`
- Date: `2026-09-19`
- Status: **Proposed — consolidated owner/qualified-review input; no source advancement**
- Scope: `SRC-IANA-LANG`, `SRC-IANA-TZDB`, `SRC-UNICODE-CLDR`,
  `SRC-UN-M49`, `SRC-EU-EURO`, `SRC-ISO-3166`, `SRC-ISO-4217`,
  `SRC-SIX-4217`
- Accountable technical owner: RechargeN / Product owner combined role
- Required retained authority: qualified terms/license review where
  applicable; independent Security/Privacy remains absent
- Runtime effect: **none**

## 1. Purpose and proposed verdict

This package consolidates the four completed technical evidence batches into
one decision boundary. It answers three questions separately:

1. what exact technical evidence exists;
2. which bounded fields each source may eventually support;
3. what still prevents source acceptance, parser work and ingestion.

Proposed verdict:

- accept EXT-A–D as the immutable **technical evidence baseline** for the
  exact hashes listed in this package;
- classify five sources as **technical candidates with retained gates**;
- classify `SRC-SIX-4217` as a **partial technical candidate** limited to
  captured List One and List Three evidence;
- retain `SRC-ISO-3166` and direct `SRC-ISO-4217` evidence as
  **Blocked/Pending**;
- advance **no source** to `eligible_for_slice_review` until its exact
  terms/access, freshness and owner-review gates pass;
- authorize no parser, fixture, repository dataset, runtime, Firebase,
  deployment or market activation.

Technical completeness and lawful allowed use are independent dimensions. A
public page, successful download, checksum or “free of charge” statement is
not a Legal permission or production authorization.

## 2. Immutable input set

| Batch | Exact evidence record | Normalized-LF SHA-256 |
|---|---|---|
| EXT-A | `REFERENCE_DATA_EXT_A_P6_EVIDENCE_RECORD.md` | `cf461ecc01650bb50e70a8dde0e32f5b8acca1cfee628e98cc0baef426e0892d` |
| EXT-B | `REFERENCE_DATA_EXT_B_P6_EVIDENCE_RECORD.md` | `6c69688f7cbfb180a871631bb107cc1e550c6dc066c16405d5c433ebe279115d` |
| EXT-C | `REFERENCE_DATA_EXT_C_P6_EVIDENCE_RECORD.md` | `c47d51f87dab836d3b6efcb85be9759be8475f7301068a9f084196208410e96c` |
| EXT-D | `REFERENCE_DATA_EXT_D_P6_EVIDENCE_RECORD.md` | `baa3a8527c5d545a12361154c8de77c983b95a9c2cce8b458a083356040c8533` |

Governance inputs:

| Document | Normalized-LF SHA-256 |
|---|---|
| `REFERENCE_DATA_EXTERNAL_SOURCE_EVIDENCE_REGISTER.md` | `ba855554a65967d3f9d66e32bb5901e52fd75d83c4db208a0d493af253ac1a5e` |
| `REFERENCE_DATA_SOURCE_AUTHORITY_MATRIX.md` | `05370dd311b402e8acb4ce6df0508f51b17ed493d68ba44673f12e04f7a4668b` |

A changed input hash requires impact analysis and a new decision revision. This
package does not silently inherit later source responses or document edits.

## 3. Consolidated source disposition

| Source | Technical result | Permitted future field scope | Current blocker | Proposed disposition |
|---|---|---|---|---|
| `SRC-IANA-LANG` | exact registry snapshot and validation Pass | BCP 47 registered subtag identity/canonicalization | IANA terms/use disposition | technical candidate; source Pending |
| `SRC-IANA-TZDB` | release `2026d`, archive safety and Baltic zone validation Pass | IANA time-zone identifiers and transition data | terms/use; no provider checksum/signature identified | technical candidate; source Pending |
| `SRC-UNICODE-CLDR` | CLDR 48.2 inventory and selected locale validation Pass | locale display/format conventions only | Unicode allowed use; immutable 48.2 UTS #35 pin; checksum filename anomaly | technical candidate; source Pending |
| `SRC-UN-M49` | six tables, code-set consistency and Baltic mapping Pass | M49 numeric mappings and UN short-name evidence | mutable/undated response; terms/use and freshness policy | technical candidate; source Pending |
| `SRC-EU-EURO` | exact Baltic euro-adoption statements Pass | corroborating adoption-history evidence only | retrieval-dated mutable page; legal-notice disposition | technical candidate; source Pending |
| `SRC-ISO-3166` | exact landing and copyright pages returned 403 | ISO country-code authority if lawfully acquired | no artifact, edition or terms evidence | Blocked/Pending; not a candidate for executable work |
| `SRC-ISO-4217` | exact standard and copyright pages returned 403 | direct ISO standard identity/edition only | access and terms blocked; SIX cannot replace direct ISO edition evidence | Blocked/Pending for direct ISO dimension |
| `SRC-SIX-4217` | authority page, current List One and historic List Three Pass; List Two XML absent | operational ISO 4217 maintenance evidence for captured active/historic lists | current terms not captured; List Two gap; no provider checksum/signature | partial technical candidate; source Pending |

No row in this table is an ingestion allowlist. “Technical candidate” means
only that evidence is strong enough to enter the retained terms/freshness
review.

## 4. Field-authority boundary

| Record family / field | Candidate technical source | Explicit non-authority |
|---|---|---|
| BCP 47 locale identifier | IANA Language Subtag Registry | supported Recharge locales and product activation |
| time-zone identifier/transitions | IANA TZDB | political/legal time-zone policy and market activation |
| locale display/format conventions | Unicode CLDR | Recharge product copy, mandatory copy and Legal meaning |
| M49 numeric/country mapping | UN M49 | ISO 3166 licensing, Recharge market identity or service area |
| euro-adoption history | European Commission page | production currency assignment, prices, tax or payment support |
| active currency code/numeric/minor-unit evidence | SIX List One | exchange rates, prices, tax, payments or direct ISO edition evidence |
| historic currency evidence | SIX List Three | active currency promotion or current market policy |
| ISO 3166 normative artifact | none accepted | no substitution from UN, CLDR, IANA or memory |
| ISO 4217 normative standard edition | none accepted | SIX operational lists do not silently prove the ISO edition/license |

Internal Recharge authorities remain responsible for:

- market ID, lifecycle, enablement and effective revision;
- supported locales and fallback policy;
- market-to-currency assignment;
- service-area geometry and availability;
- product copy, policy copy and mandatory Legal text;
- provider selection and production activation.

## 5. Exact terms/access evidence matrix

| Source family | Captured evidence | Exact evidence hash / outcome | Current disposition |
|---|---|---|---|
| IANA | IANA licensing-terms page | SHA-256 `43cfd90b1cb25ca86933032612a2c466fac94d7afc934ca8ef96a61e2b55e1b3` | captured; allowed use Pending |
| Unicode external | Unicode License v3 text | SHA-256 `e7a93b009565cfce55919a381437ac4db883e9da2126fa28b91d12732bc53d96` | captured; allowed use Pending |
| Unicode bundled | CLDR archive `LICENSE` | SHA-256 `780ed0d1e595f6bb3e7cad757ea147315596b96e75d6a271ae95e882185c8aa7` | captured; notices/use Pending |
| UN | UN terms-of-use page | SHA-256 `fc8db19659b8622d474340bf5d26e26ec5cc1e581c8e247c2e05333f51df5f94` | captured; allowed use Pending |
| European Commission | legal-notice page | SHA-256 `53841095389ec2b365b70a7a683426bf40d1df644a3ff7c64155364ea1fff739` | captured; allowed use Pending |
| ISO | privacy/copyright URI | HTTP 403; no response body retained | Blocked; no disposition possible from this run |
| SIX | approved legacy disclaimer URI | HTTP 404; no terms body | Pending; current terms candidate not followed |

Qualified disposition must answer separately for every applicable source:

1. storage of exact snapshots;
2. parser and validation processing;
3. storage of normalized/derived facts;
4. attribution, copyright, source-link and change notices;
5. redistribution inside a commercial mobile product;
6. modification and localized display output;
7. automated update cadence, rate limits and monitoring;
8. withdrawal, deletion and replacement obligations;
9. whether repository fixtures or generated bundles may contain source-derived
   values;
10. whether account, purchase or separately licensed access is required.

## 6. Version, integrity and freshness matrix

| Source | Exact evidence identity | Integrity evidence | Freshness requirement before executable use |
|---|---|---|---|
| IANA Language | registry `File-Date` `2026-09-17` | raw SHA-256 recorded | version/date change creates new immutable evidence |
| IANA TZDB | release `2026d` | raw SHA-256; provider signature/checksum not identified | release monitoring and explicit update/rollback policy |
| Unicode CLDR | release `48.2` | raw SHA-256/SHA-512; byte-identical `core.zip` reconciliation; filename checksum anomaly retained | immutable UTS #35 pin and release update policy |
| UN M49 | retrieval-dated full-view hash | raw SHA-256 only; provider version/date absent | define maximum age and changed-hash review; fail closed on unknown schema |
| EU euro page | retrieval-dated page hash | raw SHA-256 only | revalidate before market-currency decision; page remains corroborating evidence |
| ISO 3166 | none | none | blocked until exact lawful artifact/version exists |
| ISO 4217 | none directly | none directly | blocked until exact lawful standard identity/terms exist |
| SIX List One | provider date `2026-09-17` | raw SHA-256, ETag and Last-Modified; no provider signature | release/date monitoring and exact-list rollback |
| SIX List Three | provider date `2026-01-01` | raw SHA-256, ETag and Last-Modified; no provider signature | historic list update/withdrawal monitoring |

Unknown/newer schema, changed terms, changed artifact hash without a new
published identity, missing required notice or stale mutable evidence fails
closed.

## 7. Executable-scope recommendation

No EXT-G6 executable slice should be proposed yet.

The minimum entry conditions for a later parser/fixture proposal are:

1. exact source and exact field scope has an accepted terms/use disposition;
2. every required notice and attribution path is specified;
3. mutable sources have maximum-age, refresh, withdrawal and changed-hash
   rules;
4. blocked ISO dimensions are either lawfully resolved or explicitly excluded
   from the product contract without false ISO authority claims;
5. the source is advanced by owner decision only to
   `eligible_for_slice_review`;
6. a separate exact-file EXT-G6 slice defines parser, fixtures, normalized
   output, generated-file policy, rollback and source removal;
7. BCK20-OD-03 remains the owner of any physical distribution/cache/delta
   mechanism;
8. market activation remains a later internal Product/Operations decision.

## 8. Proposed owner disposition

The proposed owner decision is:

- **Accept** the four P6 documents as the exact EXT-A–D technical evidence
  baseline;
- **Accept with retained gates** the field-authority boundaries in this
  package;
- **Do not advance** any source to `eligible_for_slice_review`;
- send the captured IANA, Unicode, UN and Commission evidence to one qualified
  terms/use review;
- retain ISO 3166 and direct ISO 4217 as Blocked/Pending without bypass;
- send the exact SIX access evidence and discovered current terms candidate to
  the same qualified access/use review before any additional request;
- treat SIX List One/List Three as technical evidence only and List Two as
  Absent;
- close the EXT-A–D collection phase as **technical evidence collected**, not
  as source approval or backend completion.

## 9. Status effects if accepted

Acceptance of this package would change only documentation status:

| Item | Result |
|---|---|
| EXT-A–D technical collection | complete for exact recorded evidence |
| source evidence register | eligible for factual reconciliation only |
| IANA/Unicode/UN/EU/SIX source acceptance | remains Pending |
| ISO 3166 / direct ISO 4217 | remains Blocked/Pending |
| EXT-G5 | remains closed until qualified terms/freshness/owner gates pass |
| EXT-G6 | closed |
| BCK20-OD-02 / BCK20-OD-05 | Open |
| OD-10 | Proposed |
| BCK-20 | Draft |
| BCK20-OD-03 | Deferred |
| markets | disabled |
| parser/runtime/Firebase/deployment | unauthorized |

## 10. Required follow-up documents

After exact owner acceptance, prepare in this order:

1. one factual reconciliation revision for the external source evidence
   register referencing the four exact P6 hashes;
2. one qualified terms/access review package covering the exact evidence in
   section 5;
3. one owner decision per source only after the qualified review result;
4. one BCK20-OD-02/OD-05 reconciliation after source and mandatory-copy gates;
5. an EXT-G6 proposal only for sources actually advanced to
   `eligible_for_slice_review`.

No further broad network discovery is recommended before the consolidated
terms/access review identifies an exact evidence gap that requires it.

## 11. Retained gates

- no qualified Legal or independent Security/Privacy conclusion is claimed;
- no external source is accepted for ingestion;
- raw third-party pages, registries, archives, XML and full tables remain
  outside the repository;
- temporary-evidence cleanup remains unauthorized;
- `BCK20-OD-02` and `BCK20-OD-05` remain Open;
- `OD-10` remains Proposed, `BCK-20` Draft and `BCK20-OD-03` Deferred;
- all markets remain disabled;
- parser, fixtures, repository datasets, provider selection, schema,
  IAM/runtime, Firebase, ingestion, deployment, activation, push and merge
  remain unauthorized.

## 12. Acceptance criteria

1. **BCK20-OD02-EXT-AD-DEC-PKG-AC-01:** all four P6 records are pinned by exact normalized-LF hash.
2. **BCK20-OD02-EXT-AD-DEC-PKG-AC-02:** technical evidence and lawful allowed use remain independent dimensions.
3. **BCK20-OD02-EXT-AD-DEC-PKG-AC-03:** every source has one bounded field-authority scope and explicit non-authority.
4. **BCK20-OD02-EXT-AD-DEC-PKG-AC-04:** ISO 3166 and direct ISO 4217 remain Blocked/Pending without source substitution.
5. **BCK20-OD02-EXT-AD-DEC-PKG-AC-05:** SIX partial technical Pass does not imply ISO standard-edition or terms acceptance.
6. **BCK20-OD02-EXT-AD-DEC-PKG-AC-06:** mutable UN/EU evidence requires explicit freshness and changed-hash policy.
7. **BCK20-OD02-EXT-AD-DEC-PKG-AC-07:** the CLDR checksum filename anomaly and UTS #35 pin gap remain visible.
8. **BCK20-OD02-EXT-AD-DEC-PKG-AC-08:** no source advances to eligible-for-slice-review from this package alone.
9. **BCK20-OD02-EXT-AD-DEC-PKG-AC-09:** no parser, fixture, dataset or runtime authority is created.
10. **BCK20-OD02-EXT-AD-DEC-PKG-AC-10:** source acceptance requires exact terms/access, freshness and owner dispositions.
11. **BCK20-OD02-EXT-AD-DEC-PKG-AC-11:** raw third-party evidence remains temporary and untracked.
12. **BCK20-OD02-EXT-AD-DEC-PKG-AC-12:** BCK/OD/market/Firebase/deployment/push/merge gates remain unchanged.

## 13. Next action

Freeze this v0.1 package by normalized-LF SHA-256 and obtain one exact owner
decision accepting or rejecting the proposed disposition. Acceptance permits
only factual register reconciliation and preparation of the consolidated
qualified terms/access review; it does not permit new network activity or
executable implementation.
