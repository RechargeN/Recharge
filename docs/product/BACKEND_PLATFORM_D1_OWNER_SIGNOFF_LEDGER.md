# Recharge Backend — D1 Owner Review and Sign-off Ledger

- Ledger ID: **BCK-D1-SIG-01**
- Version: **1.24**
- Date: **2026-09-17**
- Status: **Draft ledger — D1-SIG-API/OPS/SEC/MOBILE recorded; remaining D1 sign-offs incomplete**
- Runtime status: **N/A; documentation evidence only**
- Coordination owner: **RechargeN / Product owner**
- Review package: [BCK-D1-REV-01 v1.26](BACKEND_PLATFORM_D1_REVIEW_EVIDENCE_PACKAGE.md)
- Combined-owner workbook: [BCK-D1-OWN-REV-01 v1.22](BACKEND_PLATFORM_D1_COMBINED_OWNER_REVIEW_WORKBOOK.md)
- Owner Batch A decision: [BCK-D1-OWN-A-DEC-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_A_DECISION.md)
- Operations decision: [BCK03-OPS-DEC-01 v0.1](BACKEND_API_OPERATIONS_OWNER_DECISION.md)
- Security/Privacy decision: [BCK03-SEC-DEC-01 v0.1](BACKEND_API_SECURITY_PRIVACY_OWNER_DECISION.md)
- BCK-04 technical decision: [BCK04-SEC-DEC-01 v0.1](BACKEND_SECURITY_PRIVACY_OWNER_DECISION.md)
- Threat-model technical decision: [BCK04-OD01-DEC-01 v0.1](BACKEND_SECURITY_THREAT_MODEL_OWNER_DECISION.md)
- BCK-20 technical decision: [BCK20-OWN-DEC-01 v0.1](REFERENCE_DATA_LOCALIZATION_OWNER_DECISION.md)
- Translation-governance decision: [BCK20-OD02-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_GOVERNANCE_OWNER_DECISION.md)
- Product/Content pre-review decision: [BCK20-OD02-PC-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_PRODUCT_CONTENT_PRE_REVIEW_DECISION.md)
- Product/Content combined-owner decision: [BCK20-OD02-PC-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_COMBINED_OWNER_DECISION.md)
- Mobile/Security pre-review decision: [BCK20-OD02-MS-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW_DECISION.md)
- Mobile decision: [BCK03-MOB-DEC-01 v0.1](BACKEND_API_MOBILE_OWNER_DECISION.md)
- Runtime effect: **none**

---

## 0. Owner verdict reconciliation

The explicit Product-owner verdicts through 2026-09-16 record D1-SIG-API and
bounded D1-SIG-OPS/SEC/MOBILE as `Accept with required amendments`, defer the broader
API-DEC-01–05 scopes and retain OD-09 Proposed. Existing Booking-v1
API-DEC-01/03 Acceptance is not demoted.
BCK04-SEC-DEC-01 extends the combined-owner D1-SIG-SEC evidence only to the
technical BCK-04 documentation boundary; it does not provide independent or
qualified Legal evidence and does not accept BCK-04 or its ODs.
BCK04-OD01-DEC-01 additionally records the technical threat-model boundary and
amended v0.2, but BCK04-OD-01 remains Proposed until independent and required
cross-boundary evidence exists.
BCK20-OWN-DEC-01 records only BCK-20 decision triage. Five decisions are
Deferred, BCK20-OD-02/05 remain Open, OD-10 remains Proposed and no
Reference/Localization/Mobile/Content/Legal signature is inferred.
BCK20-OD02-DEC-01 additionally records the amended technical workflow v0.2;
it does not close OD-02 or satisfy any named specialist signature.
BCK20-OD02-PC-PRE-DEC-01 integrates eight documentation corrections in
workflow v0.3 and re-freezes specialist review; both specialist signatures
remain Pending and unnamed.
BCK20-OD02-PC-COMB-DEC-01 records two separate Product Localization and Content
combined-owner verdicts for exact workflow v0.3. Their shared owner and lack of
independence are explicit; they remain historical exact-hash evidence after
workflow v0.4 and do not transfer automatically.
BCK20-OD02-MS-PRE-DEC-01 then integrates seven documentation corrections in
workflow v0.4. The v0.3 Product/Content verdicts remain historical exact-hash
evidence; v0.4 Product/Content revalidation and proposed Mobile/Security
verdicts remain Pending.
BCK05-OD-01/02/07 remain distinct from cross-domain OD-01/02/07. Every other
incomplete specialist signature remains Pending and qualified Legal/Privacy
evidence remains absent.

## 1. Purpose and verdict

This is the single repository-owned place for D1 reviewer assignment, scope,
verdict and signatures. It does not replace the BCK specifications, evidence
packages or accountable professional judgment.

The Product owner instruction dated 2026-08-20 assigns
`RechargeN / Product owner` to every D1 review role. Therefore:

- every review row is `Assigned`; D1-SIG-API and the bounded BCK05 numerical
  baseline disposition are recorded, while full D1 role sign-offs remain
  incomplete;
- BCK-03/04/05/20 remain Draft;
- OD-07 is Accepted at `OD07-A1-EU-MR-v1` with controls; OD-09/10 remain
  Proposed and OD-11 remains Open;
- D1 exit, G1–G7, provisioning and runtime remain blocked.

This is a single-owner bootstrap assignment with no independent review. Codex
technical review may identify contradictions and prepare amendments, but it is
not an API Platform, Operations, Security, Legal or Privacy signature. The
Legal/Privacy assignment records decision coordination only and does not claim
that the assignee is qualified legal counsel or that legal advice was obtained.

## 1.1 Combined-role assignment record

| Field | Recorded value |
|---|---|
| Assignment authority | Explicit Product owner instruction dated 2026-08-20: “сейчас все беру” |
| Named accountable identity | `RechargeN / Product owner` |
| Roles combined | API Platform, Platform Operations, Security/Privacy, Legal/Privacy, Reference Data, Product Localization, Mobile Platform, Content Platform, Product/Finance, Booking and Notifications |
| Independence | None; self-review and concentration-of-authority risk accepted for preparation, not hidden |
| Current verdict | Bounded numerical Product-owner disposition recorded in §4.1; all broader D1 specialist sign-offs remain incomplete |
| Legal qualification | Not evidenced; qualified Legal/Privacy conclusion remains required wherever the specifications demand professional legal judgment |
| Runtime authority | None |

## 2. Technical pre-review findings

| Finding | Result | Resolution |
|---|---|---|
| D1-TR-01 | BCK-03 Review depended on BCK-18, although BCK-18 belongs to D2 after D1 | Require a named Mobile Platform boundary review now; BCK-18 file/runtime remains D2 |
| D1-TR-02 | OD-07 required measured cloud latency before allowing any candidate resource | Split pre-Acceptance published/modelled evidence from mandatory post-provision synthetic validation before traffic |
| D1-TR-03 | BCK-05 called OD-09 `Open/Proposed` | Normalize to the factual `Proposed` status |
| D1-TR-04 | Several current-version statements still named older revisions | Align current version/status text; preserve historical changelog entries |
| D1-TR-05 | DoR lists mixed requirements with current facts, obscuring which checks actually pass | Add explicit current-readiness statements and ledger references |
| D1-TR-06 | BCK-20 wording could imply executable OD-10 fixtures before API-DEC-05 | Separate approved documentation vectors from later executable contract parity |
| D1-TR-07 | Evidence presence could be mistaken for specialist acceptance | Keep all unsigned decisions/specifications at their previous status |

Technical verdict: **internally reviewable after these amendments; not
owner-reviewed and not Approved**.

## 3. D1 signature matrix

`Required now` means needed for the D1 status transition described in the
owning specification. `Later gate` preserves narrower runtime/market evidence
without turning it into an artificial D1 blocker.

| Sign-off ID | Role | Scope | Required now | Named reviewer | Verdict | Signed at |
|---|---|---|:---:|---|---|---|
| D1-SIG-API | API Platform | BCK-03; OD-09 semantic boundary; OD-10 wire review | Yes | `RechargeN / Product owner` | **Accept with required amendments — combined-owner verdict; independent review absent** | [BCK-D1-OWN-A-DEC-01 v0.1](BACKEND_PLATFORM_D1_OWNER_BATCH_A_DECISION.md), 2026-09-08 |
| D1-SIG-OPS | Platform Operations | BCK-03 operational boundary; BCK-05; OD-07; OD-09 transport boundary | Yes | `RechargeN / Product owner` | **Accept with required amendments — BCK-03 boundary only; independent evidence absent** | [BCK03-OPS-DEC-01 v0.1](BACKEND_API_OPERATIONS_OWNER_DECISION.md), 2026-09-08 |
| D1-SIG-SEC | Security/Privacy | BCK-03 security boundary; BCK-04; OD-07 privacy boundary; OD-11 safeguards | Yes | `RechargeN / Product owner` | **Accept with required amendments — combined-owner technical BCK-03/BCK-04 boundaries only; independent/Legal evidence absent** | [BCK03-SEC-DEC-01 v0.1](BACKEND_API_SECURITY_PRIVACY_OWNER_DECISION.md), 2026-09-08; [BCK04-SEC-DEC-01 v0.1](BACKEND_SECURITY_PRIVACY_OWNER_DECISION.md), 2026-09-12 |
| D1-SIG-LEGAL | Legal/Privacy | OD-07 processing/residency; OD-11; OD-10 mandatory Legal copy | Yes | `RechargeN / Product owner` | Pending; qualification not evidenced | — |
| D1-SIG-REF | Reference Data | BCK-20; OD-10 revisions/fallback | Yes | `RechargeN / Product owner` | Pending | — |
| D1-SIG-L10N | Product Localization | OD-10 LV/EE/LT locale and review workflow | Yes | `RechargeN / Product owner` | Pending for full D1 scope and exact-v0.4 revalidation; bounded v0.3 workflow verdict is historical with no independence | [BCK20-OD02-PC-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_COMBINED_OWNER_DECISION.md), 2026-09-17 |
| D1-SIG-MOBILE | Mobile Platform | BCK-03/BCK-20 client/cache/compatibility boundary | Yes | `RechargeN / Product owner` | **Accept with required amendments — BCK-03 boundary only; independent evidence absent** | [BCK03-MOB-DEC-01 v0.1](BACKEND_API_MOBILE_OWNER_DECISION.md), 2026-09-09 |
| D1-SIG-CONTENT | Content Platform | OD-10 source/content-language/readiness boundary | Yes for OD-10 Acceptance | `RechargeN / Product owner` | Pending for full D1 scope and exact-v0.4 revalidation; bounded v0.3 workflow verdict is historical with no independence | [BCK20-OD02-PC-COMB-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_COMBINED_OWNER_DECISION.md), 2026-09-17 |
| D1-SIG-FIN | Product/Finance | OD-07/BCK-05 cost envelope and containment ownership | Yes for OD-07 Acceptance | `RechargeN / Product owner` | Pending | — |
| D1-SIG-BOOK | Booking | OD-09 Booking compatibility and future effect contract | Later before OD-09 Acceptance/effects | `RechargeN / Product owner` | Pending | — |
| D1-SIG-NOTIF | Notifications | OD-09 consumer/delivery/read semantics | Later before OD-09 Acceptance/effects | `RechargeN / Product owner` | Pending | — |

The Product owner may assign named reviewers and coordinate reconciliation but
may not sign a specialist row unless that person actually holds the role and
accepts its accountability.

## 4. Artifact review assignments

| Artifact | Accountable sign-off | Required boundary reviews | Current disposition |
|---|---|---|---|
| BCK-03 v0.3.14 | D1-SIG-API + D1-SIG-OPS | D1-SIG-SEC, D1-SIG-MOBILE | API/Operations/Security/Mobile boundary verdicts Accept with required amendments; independent evidence Pending; spec remains Draft |
| BCK-04 v0.4.23 | D1-SIG-SEC + D1-SIG-LEGAL where legal judgment applies | D1-SIG-OPS, domain owners | BCK-04 and threat-model combined-owner technical verdicts recorded; independent/qualified Legal, BCK04-OD-01/09 and tabletop gates remain; spec remains Draft |
| BCK-05 v0.2.30 | D1-SIG-OPS | D1-SIG-SEC, D1-SIG-LEGAL, D1-SIG-FIN and affected domains | Draft retained; bounded R0 Pass and accepted OD baselines Present; BCK-03/BCK-04/threat-model owner-boundary verdicts do not accept BCK-05; executable/specialist/stage/product-cloud evidence remains pending |
| BCK-20 v0.2.14 | D1-SIG-REF + D1-SIG-L10N | D1-SIG-API, D1-SIG-MOBILE, D1-SIG-CONTENT, D1-SIG-SEC, D1-SIG-LEGAL | workflow v0.4 corrections integrated; exact-v0.4 Product/Content/Mobile/Security reviews incomplete; BCK20-OD-02/05 Open and OD-10 Proposed |
| BCK04-OD01-TM-01 v0.2 | D1-SIG-SEC | independent Security/Privacy, D1-SIG-API, D1-SIG-OPS, Identity, D1-SIG-MOBILE and affected domains | Combined-owner technical verdict recorded; OD-01 Proposed pending independent/cross-boundary confirmations |
| BCK04-OD09-IR-01 v0.1 | D1-SIG-SEC + D1-SIG-OPS | D1-SIG-LEGAL where personal-data-breach judgment applies; domain owners | Proposed; owner/Legal verdict, executable routes and completed tabletop pending |
| BCK04-OD09-TTX-01 v0.1 | D1-SIG-SEC + D1-SIG-OPS | D1-SIG-LEGAL, D1-SIG-BOOK, Communications and exercise evaluator | Ready/not executed; no result, signature or gate closure |
| BCK05-OD04-COST-01 v0.4 | D1-SIG-FIN + D1-SIG-OPS | Product owner, D1-SIG-SEC and D1-SIG-LEGAL where applicable | OD-07 Accepted; BCK05-OD-04 Proposed; Finance Inconclusive; EUR SKU/stage evidence pending |
| BCK05-OD03-SLO-01 v0.1 | D1-SIG-OPS + Product/domain owners | D1-SIG-SEC, D1-SIG-MOBILE and affected domains | Proposed; Product baseline accepted; combined-owner Operations disposition requires stage telemetry/alerts and specialist proof |
| BCK05-OD05-REC-01 v0.1 | D1-SIG-OPS + affected domain owners | D1-SIG-SEC, D1-SIG-LEGAL, D1-SIG-FIN and Privacy | Proposed; Product baseline accepted; restore drills, privacy/IAM evidence and qualified review pending |
| BCK05-NUM-REV-01 v0.2 | Product owner coordination | D1-SIG-OPS/FIN/SEC/LEGAL plus affected domains | Bounded exact-version Product-owner disposition recorded; no OD/BCK/runtime promotion |
| BCK05-OD01-TCH-01 v0.3.4 | D1-SIG-OPS + D1-SIG-SEC | release, API and affected domain owners | Accepted status record for exact baseline v0.3.3 with controls; pre-R1 revalidation mandatory |
| BCK05-OD01-TCH-REV-01 v0.2.4 | D1-SIG-OPS + D1-SIG-SEC | Architecture owner | Completed technical review; bounded R0 Pass and separate owner verdict linked |
| BCK-R0-TCH-01 v0.2.2 | Product/Platform owner | D1-SIG-OPS + D1-SIG-SEC + Architecture owner | Pass — bounded tooling feasibility only; no R1/cloud authorization |
| BCK-R0-TCH-DEC-01 v0.2 | Product/Platform owner | D1-SIG-OPS + D1-SIG-SEC + Architecture owner | Bounded execution and `BCK-R0-TCH-ADV-01` accepted; product/cloud runtime excluded |
| BCK05-OD01-DEC-01 v0.2 | D1-SIG-OPS + D1-SIG-SEC | Architecture/release boundary review | Accepted at `2026-08-24T15:33:18Z`; exact baseline only; G1/R1 remain blocked |
| BCK05-OD02-IAM-01 v0.2.1 + BCK05-OD02-DEC-01 v0.2 | D1-SIG-OPS + D1-SIG-SEC | D1-SIG-LEGAL where applicable and release/runtime owners | Accepted at `2026-08-24T19:53:07Z`; architecture policy only; executable fixtures/roles/bindings/JIT and runtime evidence pending |
| BCK05-OD07-REL-01 v0.2.1 + BCK05-OD07-DEC-01 v0.2 | D1-SIG-OPS + D1-SIG-SEC | API, domain, incident and release owners | `BCK05-REL-A1-DUAL-PROV-v1` Accepted with controls; executable policy/provider/runtime evidence pending |
| OD-07 evidence v0.6 + OD07-DEC-01 v0.2 | D1-SIG-OPS | D1-SIG-SEC, D1-SIG-FIN; qualified D1-SIG-LEGAL remains mandatory before production processing | Accepted at `2026-08-24T17:51:38Z` with controls; no cloud permission |
| OD-09 evidence | D1-SIG-API | D1-SIG-OPS; later D1-SIG-BOOK/NOTIF | Proposed retained by Owner Batch A; D1 minimum only |
| OD-10 evidence | D1-SIG-REF | D1-SIG-L10N/API/MOBILE/CONTENT/LEGAL | Proposed; assigned; unsigned |
| OD-11 brief | D1-SIG-SEC + D1-SIG-LEGAL | Product/domain owners per feature | Open; assigned; no policy selected |

### 4.1 Recorded numerical baseline disposition

| Field | Recorded value |
|---|---|
| Owner identity / actual role | `RechargeN / Product owner`; combined-role bootstrap assignment disclosed; no independent review |
| Reviewed versions | SLO v0.1; Cost v0.2; Recovery v0.1; BCK-05 v0.2.8; BCK05-NUM-REV-01 v0.2 |
| Product/domain baseline | Accept as stage-validation baseline |
| Platform Operations perspective | Accept with required stage and restore evidence; not a completed D1-SIG-OPS specialist sign-off |
| Product/Finance perspective | Inconclusive pending EUR SKU, tax/support and stage reconciliation |
| Security/Privacy perspective | Accept with required IAM and privacy-resurrection evidence; not an independent security sign-off |
| Legal/Privacy perspective | Inconclusive; qualification not claimed |
| Decision status | OD-03/04/05 remain Proposed; BCK-05 remains Draft |
| Runtime authority | None |
| Recorded date | 2026-08-21 |

The disposition stabilizes test hypotheses only. It does not complete any
broader D1 role row in §3, because those rows include OD-07, cross-spec and
specialist scopes beyond the three numerical artifacts.

## 5. Review verdict vocabulary

- `Accept`: reviewed scope has no blocker and named evidence is sufficient.
- `Accept with required amendments`: listed amendments must be applied and
  rechecked before the signature becomes effective.
- `Reject`: proposal cannot proceed; reasons and replacement owner/action are
  recorded.
- `Inconclusive`: evidence or authority is insufficient; never treated as pass.

Blank, oral, chat-only or role-only acknowledgements are not signatures.

## 6. Required review record

Each completed sign-off row links to a record with:

```text
Sign-off ID:
Named reviewer and accountable role:
Artifact ID/version/commit:
Scope reviewed and explicit exclusions:
Verdict:
Blocking findings:
Required amendments and owner/date:
Evidence links:
Decision IDs affected:
Migration/rollback assessment:
Conflict-of-interest or combined-role disclosure:
Signature and UTC date:
```

A changed artifact version invalidates the previous signature unless the
review record explicitly accepts the bounded follow-up diff.

## 7. Current readiness by specification

| Specification | Structural evidence | Owner evidence | Current status |
|---|---|---|---|
| BCK-03 | complete; technical circular dependency removed | API/Operations/Security/Mobile boundary verdicts recorded; independent evidence pending | Draft |
| BCK-04 | complete; OD-11 and threat-model v0.2 reconciled | BCK-04/threat-model combined-owner technical verdicts recorded; BCK04-OD-01 remains Proposed pending independent/cross-boundary evidence; Legal/OD-09/tabletop remain | Draft |
| BCK-05 | complete; OD-07 evidence split; bounded R0 Pass and BCK05-OD-01/02 Acceptance recorded | full Operations/Finance/Security/Legal, executable IAM, remaining OD, stage and product-cloud evidence incomplete | Draft |
| BCK-20 | complete; documentation/executable fixtures separated | combined owner assigned; verdicts and qualified Legal evidence pending | Draft |

No child is promoted merely because the combined package is structurally
complete.

## 8. Conflict and combined-role policy

1. A reviewer records only the scope of their actual authority.
2. One person may hold multiple roles only with an explicit combined-role and
   independence-risk disclosure.
3. Legal/Privacy conclusions requiring qualified advice cannot be replaced by
   product or engineering preference.
4. Security and Operations disagreement on irreversible infrastructure blocks
   OD-07 rather than being averaged into acceptance.
5. Conflicting amendments are resolved in BCK-D1-REV-01 and the canonical BCK;
   no parallel “accepted copy” is created.
6. Any status transition updates BCK-01/02, affected spec/matrix, this ledger,
   reconciliation report and LAUNCH_STATUS atomically.

## 9. Assignment procedure

The Product/Engineering owner has supplied one combined accountable identity
for every row. Before a verdict is effective, the review record must still
provide:

- role and decision authority;
- review scope;
- target review date;
- conflict/combined-role disclosure if applicable.

Recording an assignment does not record approval. The named reviewer then
returns a §6 review record.

## 10. Ledger acceptance criteria

1. **D1-SIG-AC-01:** one ledger owns D1 assignments and sign-off evidence.
2. **D1-SIG-AC-02:** role labels without named reviewers remain Unassigned.
3. **D1-SIG-AC-03:** technical review is not specialist approval.
4. **D1-SIG-AC-04:** every verdict names artifact version and scope.
5. **D1-SIG-AC-05:** inconclusive and blank are never Pass.
6. **D1-SIG-AC-06:** combined roles disclose independence risk.
7. **D1-SIG-AC-07:** BCK-18 is not made a circular D1 dependency.
8. **D1-SIG-AC-08:** Mobile Platform verdict is scoped explicitly and does not infer BCK-18/BCK-20 Approval.
9. **D1-SIG-AC-09:** OD-07 evidence and Acceptance require no unauthorized resource.
10. **D1-SIG-AC-10:** post-provision validation occurs before traffic.
11. **D1-SIG-AC-11:** documentation vectors do not claim executable parity.
12. **D1-SIG-AC-12:** unsigned OD/BCK status is not promoted.
13. **D1-SIG-AC-13:** every Accepted decision has migration/rollback assessment.
14. **D1-SIG-AC-14:** artifact changes invalidate stale signatures.
15. **D1-SIG-AC-15:** status updates are atomic across canonical records.
16. **D1-SIG-AC-16:** this ledger creates no runtime or cloud resource.
17. **D1-SIG-AC-17:** a combined-owner threat-model verdict does not satisfy
    independent Security/Privacy or cross-boundary signatures and does not
    accept BCK04-OD-01.
18. **D1-SIG-AC-18:** BCK20-OWN-DEC-01 does not satisfy Reference Data,
    Localization, Mobile, Content or qualified Legal signatures.
19. **D1-SIG-AC-19:** BCK20-OD02-DEC-01 records no specialist signature and
    does not close BCK20-OD-02.
20. **D1-SIG-AC-20:** BCK20-OD02-PC-PRE-DEC-01 records no specialist
    signature and creates no source-authority, Legal, schema or runtime authority.
21. **D1-SIG-AC-21:** Product Localization and Content verdicts remain
    separately attributable despite their shared non-independent owner and do
    not satisfy Mobile, Security/Privacy or qualified Legal gates.
22. **D1-SIG-AC-22:** BCK20-OD02-MS-PRE-DEC-01 integrates documentation
    corrections only; no exact-v0.4 specialist verdict is inferred.

## 11. Next action

Owner Batch A, the bounded numerical baseline, R0 evidence and exact
BCK05-OD-01/02/07, OD-07 and the bounded BCK-03, BCK-04 and threat-model owner
verdicts, BCK-20 decision triage and the amended technical translation-
governance workflow are recorded. Next, decide the Proposed Mobile and
Security/Privacy reviews of workflow v0.4 and separately revalidate
Product/Content against its exact v0.4 hash. Prior Product/Content verdicts
remain historical evidence with no independence. Independent
threat-model, BCK-04/BCK-05/BCK-20 specialist and qualified Legal/Privacy
evidence remains deferred but required before its named gate. D1 remains
blocked and no new runtime gate opens.
