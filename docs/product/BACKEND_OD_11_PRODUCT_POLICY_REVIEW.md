# Recharge Backend — OD-11 Product Age-Eligibility Review

- Review ID: **BCK-D1-OD11-PROD-REV-01**
- Version: **0.1**
- Date: **2026-09-20**
- Status: **Prepared — Product boundary unsigned; qualified Legal/Privacy review required**
- Runtime status: **Absent**
- Accountable coordinator: **RechargeN / Product owner**
- Required external authority: **qualified Legal/Privacy reviewer**
- Legal brief: [BCK-D1-OD11-LGL-01 v0.1](BACKEND_OD_11_AGE_POLICY_LEGAL_BRIEF.md)
- Legal-brief normalized-LF SHA-256: `307a69964793fa37494f1ca1a7b59b1c49dd59b0a777e95a2932005ae0a44ee8`
- Parent: [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Runtime effect: **none**

---

## 1. Purpose

This review defines the Product decisions that must exist before OD-11 can
advance from `Open`. It deliberately does not provide legal advice, select a
numeric account age, infer one Baltic rule from Latvia or authorize collection
of date of birth, identity documents, guardian data or age-estimation signals.

The review is useful even before qualified advice because it fixes:

1. the product surfaces that require separate eligibility decisions;
2. the fail-closed behavior while age or policy is unresolved;
3. the distinction between account eligibility, feature eligibility and
   content/admission restrictions;
4. the minimum evidence needed for an attributable OD-11 decision;
5. the boundary between Product policy and later schema/runtime work.

## 2. Exact non-decisions

This document does **not** decide:

- a minimum age for a Recharge account;
- whether a minor can use Recharge with or without guardian involvement;
- the legal basis or mechanics for parental authorization;
- age-verification, age-assurance or identity-verification providers;
- retention of birth date, age band or evidence;
- whether a specific Event, Booking offer or venue is legally age-restricted;
- Estonia or Lithuania policy based on a Latvia conclusion;
- production enforcement, migration or exception handling.

Until those decisions are accepted, OD-11 remains `Open` and every dependent
high-risk surface remains fail-closed.

## 3. Product decision taxonomy

OD-11 must publish independent decisions for the following concepts.

| Concept | Question | Must not be conflated with |
|---|---|---|
| Account eligibility | May this person create/retain an account in this market? | consent to analytics, feature eligibility |
| Feature eligibility | May the account use a particular high-risk capability? | general account access |
| Content eligibility | May the account discover, create or publish this content class? | venue admission |
| Transaction eligibility | May the account initiate or manage this Booking path? | payment authorization or provider acceptance |
| Admission restriction | Does the Event/venue/provider impose an age rule? | Recharge account policy |
| Creator/Page authority | May the account become verified Creator or manage a Professional Page? | Viewer authentication |

One positive result never grants another category implicitly.

## 4. Required surface matrix

Every accepted market policy must explicitly disposition each row. `Unknown`
or missing policy means the fail-closed behavior below.

| Surface | Product risk | Required policy decision | Default while OD-11 Open |
|---|---|---|---|
| account creation/recovery | identity and legal eligibility | market-specific account rule | no production account creation |
| general authenticated discovery | low-to-moderate | whether eligible accounts may browse general content | unavailable until account eligibility exists |
| Favorites/Library/Visit History | personal data | whether eligible accounts may use personal storage | unavailable until account eligibility exists |
| Find People discovery/contact | interpersonal safety | explicit feature rule and safety controls | disabled for unknown/minor state |
| Event age-restricted discovery | regulated/restricted content | classification and visibility rule | hidden or blocked; never silently shown |
| Event creation/publication | UGC and public exposure | creator/content eligibility | disabled for unknown/minor state |
| ordinary external-booking handoff | transactional | transaction/handoff rule | blocked when eligibility cannot be proved |
| age-restricted Booking | high-risk transaction | content + transaction + admission rules | blocked |
| Creator verification | identity and public authority | explicit creator eligibility | disabled for unknown/minor state |
| Professional Page management | commercial/public authority | explicit page-role eligibility | disabled for unknown/minor state |
| reviews/reports/appeals | UGC and safety | participation and safeguarding rule | no production use until decided |
| Admin/support actions | privileged processing | workforce policy, not end-user age policy | separate IAM/capability gate |

## 5. Policy-state semantics

The eventual domain/API contract may use different names, but it must represent
these meanings without relying on a nullable Boolean:

| Semantic state | Meaning | Authority consequence |
|---|---|---|
| `policyUnavailable` | market policy is absent, expired or invalid | deny dependent operation |
| `eligibilityUnknown` | no authoritative eligibility result exists | deny high-risk operation |
| `eligibleGeneral` | account may use explicitly listed general surfaces | grants only named general capabilities |
| `eligibleRestricted` | account satisfies a named additional policy | grants only that policy/surface |
| `ineligible` | policy outcome denies the operation | deny with safe typed result |
| `reviewRequired` | authoritative manual/guardian/legal flow is needed | no provisional capability |

This is a semantic design boundary, not permission to add schema fields or
collect new data.

## 6. Product rules proposed for owner review

The Product owner may accept the following boundary without claiming a legal
conclusion:

1. Every market has its own versioned age-policy record and effective window.
2. Account eligibility and every high-risk feature are decided separately.
3. Unknown, stale, unsupported or newer policy fails closed.
4. Find People, age-restricted content/Booking, Creator verification and
   Professional Page management never inherit general account eligibility.
5. Client claims, profile text and self-selected UI mode are not authority.
6. Venue/provider admission metadata is not Recharge account eligibility.
7. Product copy states the practical restriction without exposing sensitive
   reason codes to unrelated users.
8. No automatic transition is inferred from birthday passage without an
   authoritative policy re-evaluation.
9. Latvia acceptance cannot activate Estonia or Lithuania.
10. Policy changes require migration, re-evaluation and rollback plans before
    activation.

## 7. Typed outcomes

Dependent commands require explicit outcomes rather than `null`, generic
`permissionDenied` or silent hiding:

| Outcome | Meaning | UI/log behavior |
|---|---|---|
| `agePolicyUnavailable` | no valid policy can decide | safe retry/support path; no sensitive detail |
| `ageEligibilityUnknown` | authoritative result absent | explain that eligibility must be resolved |
| `ageEligibilityRequired` | additional approved flow is required | open only the approved flow |
| `ageRestricted` | operation is not permitted under current policy | neutral denial; no public disclosure |
| `guardianActionRequired` | accepted policy requires guardian action | available only if such flow is separately approved |
| `agePolicyChanged` | prior result is stale under a new revision | stop and re-evaluate |
| `ageEligibilityConflict` | inconsistent authoritative evidence | fail closed and route to controlled review |

These names are contract candidates. BCK-03 owns final wire naming and schema.

## 8. Data-minimization boundary

Before any executable slice, the accepted policy must specify:

- the minimum attribute needed: result, band, date or other evidence;
- authoritative writer and permitted readers;
- purpose and legal basis per field;
- retention, deletion, export and correction behavior;
- whether raw evidence is prohibited from product stores/logs;
- audit data that proves a decision without copying sensitive source material;
- migration when policy revision changes eligibility.

The preferred product posture is to store the least expressive authoritative
result that can enforce the accepted policy. This preference is not a final
Legal/Privacy determination.

## 9. Market and policy revision contract

An accepted OD-11 record must contain, at minimum:

- immutable `policyRevisionId`;
- market and applicable jurisdiction scope;
- effective-from and optional effective-until instants;
- separate account and surface decisions;
- Product owner and qualified Legal/Privacy verdict references;
- source/evidence snapshot identifiers;
- migration and rollback disposition;
- explicit Latvia, Estonia and Lithuania activation flags;
- supersession and emergency-disable behavior.

No client-provided market, locale or timezone may grant eligibility.

## 10. Review lanes

| Lane | Reviewer | Scope | Required result |
|---|---|---|---|
| Product | RechargeN / Product owner | taxonomy, surfaces, UX defaults, separation rules | exact bounded verdict |
| Legal/Privacy | qualified named reviewer | market rules, consent/guardian requirements, notices, data basis | attributable qualified verdict |
| Identity | accountable owner | authority, recovery/linking, policy evaluation trigger | cross-boundary confirmation |
| Trust & Safety/Content | accountable owner | Find People, UGC, restricted content, reporting | cross-boundary confirmation |
| Booking | accountable owner | handoff/transaction/admission separation | cross-boundary confirmation |
| Security/Privacy | accountable owner | data minimization, access, retention, abuse controls | technical confirmation |

Combined Product ownership may prepare the first lane only. It cannot mark the
other lanes complete.

## 11. Evidence required before OD-11 Proposed

OD-11 may become at least `Proposed` only when:

1. the exact Product boundary is accepted;
2. a named qualified reviewer provides an attributable market-scoped verdict;
3. each required cross-boundary owner records an exact confirmation or finding;
4. numeric ages, if any, cite their precise legal/product scope;
5. Latvia is decided independently from Estonia and Lithuania;
6. all unresolved questions have fail-closed defaults and later gates;
7. no document claims runtime, schema or collection authority.

## 12. Later executable gates

Even an Accepted OD-11 design does not authorize implementation. A later slice
must separately cover schema, migrations, authorization, Rules/IAM, emulator
tests, abuse cases, telemetry minimization, account recovery, deletion/export,
rollback, staged rollout and production activation.

## 13. Acceptance criteria

1. **OD11-PROD-AC-01:** the exact legal brief is hash-pinned.
2. **OD11-PROD-AC-02:** no numeric account age is selected.
3. **OD11-PROD-AC-03:** Product judgment is not represented as legal advice.
4. **OD11-PROD-AC-04:** account and feature eligibility remain separate.
5. **OD11-PROD-AC-05:** content, transaction and admission restrictions remain separate.
6. **OD11-PROD-AC-06:** Creator/Page authority does not follow Viewer eligibility automatically.
7. **OD11-PROD-AC-07:** unknown or stale policy fails closed.
8. **OD11-PROD-AC-08:** client claims never grant eligibility.
9. **OD11-PROD-AC-09:** Find People has an explicit independent decision.
10. **OD11-PROD-AC-10:** age-restricted Event and Booking paths are explicit.
11. **OD11-PROD-AC-11:** ordinary Booking handoff does not imply admission eligibility.
12. **OD11-PROD-AC-12:** typed outcomes avoid generic/null denial.
13. **OD11-PROD-AC-13:** sensitive reasons are not exposed to unrelated users.
14. **OD11-PROD-AC-14:** data minimization precedes schema work.
15. **OD11-PROD-AC-15:** retention/deletion/export requirements are mandatory inputs.
16. **OD11-PROD-AC-16:** policy revisions have migration and rollback semantics.
17. **OD11-PROD-AC-17:** Latvia cannot activate Estonia or Lithuania.
18. **OD11-PROD-AC-18:** locale/timezone/client market are not authority.
19. **OD11-PROD-AC-19:** qualified Legal/Privacy review remains mandatory.
20. **OD11-PROD-AC-20:** Identity confirmation remains separate.
21. **OD11-PROD-AC-21:** Trust & Safety/Content confirmation remains separate.
22. **OD11-PROD-AC-22:** Booking confirmation remains separate.
23. **OD11-PROD-AC-23:** Security/Privacy confirmation remains separate.
24. **OD11-PROD-AC-24:** Proposed status requires attributable exact evidence.
25. **OD11-PROD-AC-25:** this review creates no schema, runtime or data collection.
26. **OD11-PROD-AC-26:** Firebase, deployment, activation, push and merge remain unauthorized.

## 14. Current disposition

The Product boundary is prepared but unsigned. OD-11 remains `Open`, every
market remains disabled and the qualified/cross-boundary lanes remain Pending.
