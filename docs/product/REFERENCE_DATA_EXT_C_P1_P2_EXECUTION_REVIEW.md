# BCK-20 — EXT-C P1/P2 Execution Review

- ID: **BCK20-OD02-EXT-C-P1P2-EXEC-REV-01**
- Version: **0.1**
- Date: **2026-09-19**
- Status: **Recorded — P1/P2 Pass; P3–P6 unauthorized**
- Authorization: `BCK20-OD02-EXT-C-P1P2-AUTH-01` v0.1
- Authorization normalized-LF SHA-256:
  `354b0eb9dd667900bd37a760fde4eaf673b2f03715dc703a11676c88c7fdfe9f`
- Authorization instance: `bb28a9bf-c907-489b-b321-c58983aecdca`
- Batch: **EXT-C — `SRC-UN-M49`, `SRC-EU-EURO`**
- Runtime effect: **none**

## 1. Verdict

The exact four-request P1/P2 run completed inside the approved envelope:

- two P1 source pages and two P2 terms/legal pages returned HTTP 200;
- total retained response bytes: 2,378,391;
- redirects, credentials, cookies, retries and candidate-link requests: zero;
- repository writes during execution: zero;
- typed outcome: `ext_c_p1p2_pass`;
- terms/use and qualified Legal disposition remain Pending;
- P3–P6, parser, ingestion and runtime remain unauthorized.

## 2. Exact response evidence

| Source / class | Exact URI | Bytes | SHA-256 |
|---|---|---:|---|
| `SRC-UN-M49` P1 | `https://unstats.un.org/unsd/methodology/m49/` | 2,051,368 | `4d5cabcb10ad9ef184553b5e64c0a34ba8deeb20dab2e02cd0be3599b93bb01d` |
| UN P2 | `https://www.un.org/en/about-us/terms-of-use` | 93,996 | `fc8db19659b8622d474340bf5d26e26ec5cc1e581c8e247c2e05333f51df5f94` |
| `SRC-EU-EURO` P1 | `https://economy-finance.ec.europa.eu/euro/what-euro-area_en` | 80,708 | `4ba3e44abb640b631ac5c2433fc52fc1525c9455b402b26e4717c7e82c51d715` |
| Commission P2 | `https://commission.europa.eu/legal-notice_en` | 152,319 | `53841095389ec2b365b70a7a683426bf40d1df644a3ff7c64155364ea1fff739` |

Evidence-file hashes:

| File | SHA-256 |
|---|---|
| `run-manifest.json` | `ff950741acaed8b50517566ede75b9c7534eb20ed75da679f6ce7eb895e63ada` |
| `run-result.json` | `c0c6589a9f345479c4c3f64606f72c5384feb6e422d04bf731d2c2a9da6e72d7` |
| original candidate inventory | `64ef891a80a8433170f14db76cdbc8d19d20e36e8b35b1d069f55334dc48e802` |
| original statement inventory | `490c0db2a9c2624d5c99f2aaddc9686905d4bb6dfd424be6d5db5e21543c991f` |
| terms question map | `21e919875c7b6a8a9ae1990c44bdb69fd8b5801942834ce8a60a29eed6a6b33a` |
| P1/P2 reconciliation | `f102e7ef8dee3935e9b00ce871deb0ddf81551c5fcb2df1d574e8d1b172ad8ab` |
| curated explicit statements | `b9213eebc7fe47c338d124d3c1b9872c563242b5ca6b53317ecea3b61244ba6c` |

## 3. UN M49 findings

The landing-page snapshot contains the country/area table and explicitly
represents the selected Baltic mappings:

| Name | M49 | Alpha-3 |
|---|---:|---|
| Estonia | `233` | `EST` |
| Latvia | `428` | `LVA` |
| Lithuania | `440` | `LTU` |

The page also contains UN statistical groupings and historical material. Those
sections are not Recharge market, service-area, pricing or launch-policy
authority.

Discovery found two relevant links:

1. `https://unstats.un.org/unsd/methodology/m49/overview/` — selected exact
   follow-up candidate for the primary full-view country/code table;
2. `https://unstats.un.org/unsd/methodology/m49/historical-classification-of-developed-and-developing-regions.xlsx`
   — excluded from the primary M49 scope because it is a historical
   developed/developing grouping rather than the country/code table.

The landing response has no usable provider version or modification date.
Retrieval time plus raw hash preserves the observed response but does not turn
the mutable landing URI into an immutable source artifact.

## 4. EU euro findings

The exact Commission page explicitly states:

| Member State | Joined euro area |
|---|---:|
| Estonia | 2011 |
| Latvia | 2014 |
| Lithuania | 2015 |

The captured page also states that the euro area currently contains 21 EU
Member States. Only the three explicit Baltic adoption facts are proposed for
the bounded Recharge evidence scope. The page does not authorize an inference
about Recharge launch markets, market activation, prices, taxes, payment
support or commercial policy.

The exact captured response and hash are sufficient for later technical
validation. No second EU artifact GET is currently required.

## 5. Terms status

The UN terms page and Commission legal notice were captured exactly. No
automatic conclusion was made for:

- snapshot storage;
- normalized derived facts;
- attribution and notices;
- redistribution in a commercial mobile application;
- modification or localization;
- automated periodic retrieval;
- withdrawal or terms-change handling;
- need for qualified Legal review.

Both sources remain `terms_pending` until an applicable qualified disposition
exists.

## 6. Reconciliation

The initial generic link classifier produced 521 candidates because ordinary
navigation and assets were intentionally retained before local
classification. The reconciliation selects only the M49 `overview/` URI for
the next primary-table request and excludes the historical-grouping workbook
from that scope. It performed no additional network request and did not alter
raw responses.

## 7. Temporary evidence

Raw and derived evidence remains outside the repository at:

```text
C:\Users\User\AppData\Local\Temp\recharge-bck20-ext-c-p1p2-bb28a9bf-c907-489b-b321-c58983aecdca
```

Deletion is not authorized by this review.

## 8. Retained gates and next action

- P1/P2 is Pass only for the exact captured pages;
- `SRC-UN-M49` remains Pending for an exact reproducible table snapshot;
- `SRC-EU-EURO` has technical page evidence but remains terms/use Pending;
- P3–P6 require the separately approved exact authorization package;
- `BCK20-OD-02` and `BCK20-OD-05` remain Open;
- `OD-10` remains Proposed, `BCK-20` Draft and `BCK20-OD-03` Deferred;
- all markets remain disabled;
- parser, fixtures, repository data, schema, IAM/runtime, Firebase, ingestion,
  deployment, activation, push and merge remain unauthorized.

The next bounded action is one exact M49 `overview/` GET plus conditional local
P4/P5 validation. If the page contains the complete primary table, produce one
docs-only EXT-C P6 evidence record. If it exposes another artifact URI instead,
record that URI and stop without following it.

## 9. Acceptance criteria

1. **BCK20-OD02-EXT-C-P1P2-EXEC-REV-AC-01:** all four exact responses, sizes and hashes are recorded.
2. **BCK20-OD02-EXT-C-P1P2-EXEC-REV-AC-02:** P1 source evidence and P2 terms evidence remain distinct.
3. **BCK20-OD02-EXT-C-P1P2-EXEC-REV-AC-03:** candidate links were not followed.
4. **BCK20-OD02-EXT-C-P1P2-EXEC-REV-AC-04:** UN statistical groupings do not create Recharge product policy.
5. **BCK20-OD02-EXT-C-P1P2-EXEC-REV-AC-05:** only explicit Baltic euro-adoption statements are retained.
6. **BCK20-OD02-EXT-C-P1P2-EXEC-REV-AC-06:** captured terms are not presented as allowed-use or Legal approval.
7. **BCK20-OD02-EXT-C-P1P2-EXEC-REV-AC-07:** source states remain Pending and no runtime authority is created.
8. **BCK20-OD02-EXT-C-P1P2-EXEC-REV-AC-08:** raw evidence remains temporary and untracked.
