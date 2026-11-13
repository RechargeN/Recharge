# Recharge Backend — D1 Owner Batch B Review Package

- Package ID: **BCK-D1-OWN-B-REV-01**
- Version: **0.1**
- Date: **2026-09-19**
- Status: **Proposed — one owner action may record six separate bounded verdicts**
- OD-10 review: [OD10-OWN-COMB-REV-01 v0.1](BACKEND_OD_10_MULTI_OWNER_REVIEW_PACKAGE.md)
- OD-10 review normalized-LF SHA-256:
  `60fe9f3ca621f5f7a489e5f4e77a48f63399b2e5bc72f569dfa5c41a7a532a84`
- Source-governance review: [BCK20-OD02-SRC-GOV-REV-01 v0.1](REFERENCE_DATA_SOURCE_GOVERNANCE_OWNER_REVIEW.md)
- Source-governance review normalized-LF SHA-256:
  `fd040e3bfc3fcb8c3b5f51eb5dc4c3ce9c4b1265e66635eb0fa4f0b8775bbcda`
- Owner/signatory requested: **RechargeN / Product owner combined role**
- Technical preparer: **OpenAI Codex — evidence preparation only, not a signatory**
- Independence: **none**
- Qualified Legal/Privacy claim: **none**
- Runtime effect: **none**

---

## 1. Purpose

Batch B combines the next two safe D1 documentation decisions into one owner
action while preserving six distinct verdicts:

1. `OD10-SIG-REF`;
2. `OD10-SIG-API`;
3. `OD10-SIG-L10N`;
4. `OD10-SIG-CONTENT`;
5. `OD10-SIG-MOBILE`;
6. `BCK20-OD02-SRC-GOV`.

The first five review one exact OD-10 documentation target from separate
functional perspectives. The sixth accepts only the external-source technical
governance boundary. One owner response may record them together because the
combined roles and lack of independence are explicit; the verdicts do not
merge.

## 2. Why this batch is safe to combine

Both packages:

- are documentation-only;
- target exact normalized hashes;
- retain qualified Legal/terms gates;
- create no independent-review claim;
- keep OD-10 Proposed and BCK-20 Draft;
- keep every source outside `eligible_for_slice_review`;
- authorize no network, schema, fixture, dataset, parser, runtime, Firebase,
  deployment or market activation;
- can be rolled back as one local documentation commit.

Their dependencies are complementary, not circular: OD-10 review confirms the
consumer contract boundary, while source governance confirms how future
external evidence may support bounded reference fields. Neither makes the
other executable.

## 3. Batch verdict matrix

| Verdict ID | Scope | Recommended verdict | What remains open |
|---|---|---|---|
| `OD10-SIG-REF` | revision, normalization identity, eligibility, rollback | Accept documentation design boundary with retained gates | source eligibility, executable normalization, publication |
| `OD10-SIG-API` | typed result, compatibility and decoder boundary | Accept documentation design boundary with retained gates | API-DEC-05, schema, transport, parity |
| `OD10-SIG-L10N` | locale/content separation and fallback semantics | Accept documentation design boundary with retained gates | final LV policy, EE/LT policy, quality workflow |
| `OD10-SIG-CONTENT` | content/source/withdrawal/telemetry boundary | Accept documentation design boundary with retained gates | source use, mandatory copy, correction workflow |
| `OD10-SIG-MOBILE` | typed consumption and fail-closed client boundary | Accept documentation design boundary with retained gates | UI policy, cache/adapter/runtime evidence |
| `BCK20-OD02-SRC-GOV` | eight-source field/freshness/change/withdrawal governance | Accept source-governance design boundary with retained terms and executable gates | qualified terms, source owner acceptance, EXT-G5/G6 |

## 4. Batch-wide retained gates

After acceptance:

- OD-10 remains **Proposed**;
- BCK-20 remains **Draft**;
- BCK20-OD-02 and BCK20-OD-05 remain **Open**;
- BCK20-OD-03 and API-DEC-05 remain **Deferred**;
- D1 is not complete and G1 does not pass;
- `D1-SIG-LEGAL` remains Pending and qualification is not evidenced;
- independent Security/Privacy and Mobile review remain absent;
- external-source terms/use, notices and lawful artifact access remain
  Pending/Blocked;
- no source enters `eligible_for_slice_review`;
- all markets remain disabled;
- schema, fixtures, datasets, parser, IAM/runtime, Firebase, deployment,
  activation, push and merge remain unauthorized.

## 5. Exact owner response

```text
Одобряю BCK-D1-OWN-B-REV-01 v0.1 для точных пакетов:
OD10-OWN-COMB-REV-01 v0.1 / normalized-LF SHA-256
60fe9f3ca621f5f7a489e5f4e77a48f63399b2e5bc72f569dfa5c41a7a532a84
и BCK20-OD02-SRC-GOV-REV-01 v0.1 / normalized-LF SHA-256
fd040e3bfc3fcb8c3b5f51eb5dc4c3ce9c4b1265e66635eb0fa4f0b8775bbcda.

Принимаю шесть раздельных bounded verdict:
OD10-SIG-REF, OD10-SIG-API, OD10-SIG-L10N, OD10-SIG-CONTENT и
OD10-SIG-MOBILE — Accept documentation design boundary with retained gates;
BCK20-OD02-SRC-GOV — Accept source-governance design boundary with retained
terms and executable gates.

Подтверждаю совмещение ролей RechargeN / Product owner, отсутствие independent
review и отсутствие qualified Legal/Privacy/terms claim. OD-10 остаётся
Proposed; BCK-20 Draft; BCK20-OD-02/05 Open; BCK20-OD-03 и API-DEC-05
Deferred; D1/G1 не закрыты. Ни один source не переводить в
eligible_for_slice_review. Разрешаю только docs-only reconciliation и один
локальный коммит. Network, terms acceptance, schema, fixtures, datasets,
parser, runtime, Firebase, deployment, activation, push и merge не разрешаю.
```

## 6. Permitted reconciliation after acceptance

Only after the exact owner response is recorded, one docs-only reconciliation
may:

1. create one immutable Batch B owner-decision record;
2. record the five OD-10 perspective verdicts in the D1 ledger;
3. record the source-governance boundary without advancing any source;
4. update the D1 workbook/review package;
5. update BCK-20/coverage, BCK-01/02 and Launch Status factually;
6. append stable AC numbers rather than renumbering existing criteria;
7. make one local commit containing only the exact documentation set.

It may not create or edit schema, fixture, runtime, Firebase or mobile files.

## 7. Remaining D1 work after Batch B

Batch B deliberately leaves a short, honest queue:

1. qualified exact-hash terms/access verdicts for the external sources;
2. per-source owner dispositions only after those qualified results;
3. attributable qualified Legal/Product policy for mandatory/fallback-
   forbidden copy under BCK20-OD-05;
4. independent Security/Privacy and required cross-boundary confirmations;
5. unresolved BCK-04/BCK-05 specialist and qualified evidence;
6. final D1 reconciliation and an explicit G1 decision;
7. only then a separately Approved R1 planning/execution slice.

No further broad network discovery or implementation is needed before items
1–5 produce an exact gap that requires it.

## 8. Rollback and invalidation

- Before acceptance, delete/revert only the prepared Batch B documentation.
- After acceptance, revert the single reconciliation commit if the decision
  was recorded incorrectly; do not rewrite historical decision text.
- Any changed package hash invalidates the corresponding verdicts until an
  explicit impact review revalidates them.
- A later qualified or independent verdict may narrow this package; it cannot
  silently broaden runtime authority.

## 9. Acceptance criteria

1. **BCK-D1-OWN-B-AC-01:** both review packages are frozen by exact normalized hash.
2. **BCK-D1-OWN-B-AC-02:** six verdict IDs remain separate.
3. **BCK-D1-OWN-B-AC-03:** combined roles and zero independence are explicit.
4. **BCK-D1-OWN-B-AC-04:** Codex is not a signatory.
5. **BCK-D1-OWN-B-AC-05:** no qualified Legal/Privacy/terms claim is created.
6. **BCK-D1-OWN-B-AC-06:** OD-10 perspective review and source governance remain distinct boundaries.
7. **BCK-D1-OWN-B-AC-07:** OD-10 remains Proposed after every bounded verdict.
8. **BCK-D1-OWN-B-AC-08:** BCK-20 remains Draft.
9. **BCK-D1-OWN-B-AC-09:** BCK20-OD-02/05 remain Open.
10. **BCK-D1-OWN-B-AC-10:** BCK20-OD-03 and API-DEC-05 remain Deferred.
11. **BCK-D1-OWN-B-AC-11:** no source enters eligible-for-slice-review.
12. **BCK-D1-OWN-B-AC-12:** all markets remain disabled.
13. **BCK-D1-OWN-B-AC-13:** D1/G1 remain incomplete.
14. **BCK-D1-OWN-B-AC-14:** target-hash changes invalidate affected verdicts.
15. **BCK-D1-OWN-B-AC-15:** reconciliation appends stable AC numbers without renumbering.
16. **BCK-D1-OWN-B-AC-16:** one local docs-only commit is the maximum authorized effect after acceptance.
17. **BCK-D1-OWN-B-AC-17:** no new network access is inferred.
18. **BCK-D1-OWN-B-AC-18:** no terms/license/click-through is accepted.
19. **BCK-D1-OWN-B-AC-19:** no schema, fixture, dataset, parser or runtime authority is created.
20. **BCK-D1-OWN-B-AC-20:** Firebase, deployment, activation, push and merge remain unauthorized.

## 10. Current disposition

The package is prepared for one owner response. Until that response is given,
all six verdicts remain Pending and canonical statuses remain unchanged.
