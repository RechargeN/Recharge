# BCK-D1 — OD-11 Minors and Age-Eligibility Legal Brief

- Brief ID: **BCK-D1-OD11-LGL-01**
- Version: **0.1**
- Date: **2026-08-20**
- Decision status: **Open — no Recharge age policy selected**
- Brief status: **Draft — qualified Legal/Privacy review required**
- Runtime status: **Absent**
- Accountable owner: **Security/Privacy owner**
- Required decision co-owners: **Legal/Privacy, Identity, Content, Booking, Trust & Safety and Product**
- Parent specification: [BCK-04 §18](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Runtime effect: **none**

---

## 1. Purpose and non-decision

This brief separates legal facts, product-policy questions and technical gates.
It is not legal advice and does **not** choose:

- a minimum Recharge account age;
- whether minors may use Recharge;
- guardian-consent or guardian-control mechanics;
- age verification/assurance method;
- eligibility for Find People, Booking, publication or age-restricted content;
- a Baltic-wide rule inferred only from Latvia.

OD-11 remains `Open`. Numerical values in legal sources below describe their
specific legal scope and must not be copied into account or feature eligibility.

## 2. Verified legal-source snapshot

Sources were checked on 2026-08-20 and require qualified review before a
production decision.

| Source | Narrow verified point | What it does **not** decide |
|---|---|---|
| [GDPR Article 8](https://eur-lex.europa.eu/legal-content/EN-ES/TXT/?uri=CELEX%3A32016R0679) | When processing for an information-society service offered directly to a child relies on consent, the EU baseline is 16; Member States may lower it no further than 13; reasonable effort is required to verify parental authorization below the applicable age. | General account minimum, contract capacity, Booking eligibility or whether consent is the correct legal basis. |
| [Latvian Personal Data Processing Law §33](https://likumi.lv/ta/id/300099-fizisko-personu-datu-apstrades-likums) | In Latvia, for the Article 8 consent scenario, a child at least 13 may provide that consent; below 13 it comes from a parent/legal guardian. | A universal “Recharge is 13+” rule or authorization for high-risk social/booking features. |
| [Latvian DPA explanation](https://www.dvi.gov.lv/lv/jaunums/dviskaidro-vecaku-piekrišana-berna-personas-datu-apstradei) | The regulator explains the same consent distinction and parental role. | Product eligibility, age assurance level, contracts or all processing purposes. |
| [Digital Services Act Article 28](https://eur-lex.europa.eu/eli/reg/2022/2065/oj/eng) | Platforms accessible to minors need appropriate and proportionate high privacy/safety/security; profiling-based ads using personal data are prohibited when the provider knows with reasonable certainty the user is a minor; compliance does not itself require collecting extra personal data to assess age. | A specific account age, a required DOB field or a complete Recharge safety design. |

Estonia and Lithuania national rules, consumer/contract capacity, event-specific
age restrictions and app-store age policies are not established by the Latvia
source and require separate current evidence before market activation.

## 3. Required purpose-by-purpose analysis

A single `age` flag cannot lawfully or safely answer all functions. The
Accepted OD-11 record must classify each surface independently.

| Surface | Decision questions | Current state |
|---|---|---|
| account creation | minimum age; legal basis by processing purpose; parental path; deletion/rights | production blocked |
| profile/discovery | public fields, precise location, recommendations, messaging/interaction | minors path disabled |
| Find People | visibility, contact, location precision, abuse/report/block, adult/minor mixing | server-disabled |
| content publication | publisher eligibility, child-created UGC, moderation, restricted classification | age-sensitive path disabled |
| Event discovery | event age rating source, unknown rating, organizer evidence, regional rules | restricted paths disabled |
| Booking | contract capacity, organizer restrictions, guardian role, attendance versus booking actor | applicable minor paths disabled |
| reviews/social proof | public authorship, harassment, retention, moderation | minor-specific path disabled |
| ads/recommendations | profiling applicability and DSA safeguards | profiling ads to known minors prohibited; product policy still open |

## 4. Data-minimization and assurance questions

Legal/Privacy must select the least intrusive evidence sufficient for each
risk. “Collect full date of birth from everyone” is not a default.

Possible assurance levels for review, not selection:

| Level | Example evidence | Suitable only after review |
|---|---|---|
| unknown | no age signal | only unrestricted surfaces with minor-safe defaults |
| self-declared band | under/over policy threshold, no full DOB | low-risk eligibility if acceptable |
| account/provider assertion | verified claim without raw document in domain data | higher assurance where available/appropriate |
| guardian authorization | verified guardian relationship and versioned scope | only if Legal defines enforceable process |
| identity/age verification | specialist check with minimized retained result | high-risk/restricted surface after DPIA/vendor review |

The domain should receive only a server-resolved, versioned eligibility result,
not raw documents or a client-authored capability. Exact model remains Open.

## 5. Questions Legal/Privacy must answer per market

1. Which processing purposes rely on consent and which use another lawful basis?
2. What is the minimum account policy, distinct from GDPR consent age?
3. May minors use the base discovery product, and with which defaults?
4. Which features are adult-only, guardian-authorized or unavailable?
5. What event/content age taxonomy and evidence source are legally sufficient?
6. What contract-capacity rules apply to free and future paid Booking?
7. What assurance level is proportionate for each restricted feature?
8. How are guardian authority, withdrawal and child maturity handled?
9. Which notices/consents require child-appropriate language and locale?
10. What records, retention, access, correction and deletion rules apply?
11. Is a DPIA required for age assurance, Find People or profiling?
12. Which LV rule changes for EE and LT, and how is policy revision activated?

Every answer needs jurisdiction, source, qualified owner, effective date,
review date and supersession/rollback behavior.

## 6. Required policy artifact

Accepted OD-11 must publish a versioned, server-enforced policy conceptually
containing:

```text
AgeEligibilityPolicyRevision {
  policyRevision
  marketId
  effectiveAt
  accountRule
  featureRules[]
  assuranceRequirements[]
  guardianRules?
  disclosureRevisionIds[]
  retentionPolicyRef
  legalEvidenceRefs[]
  rollbackPolicyRef
}
```

This is a conceptual review shape, not authorization to add a schema. It must
avoid storing unnecessary birth date/document data and must return typed,
non-enumerating eligibility outcomes.

## 7. Fail-closed behavior while Open

- no production account-age policy is inferred from `13` or `16`;
- production account creation remains blocked by the existing R2/G6 gates;
- Find People and age-restricted publication/discovery are server-disabled;
- applicable Booking paths for minors/unknown eligibility are disabled;
- no guardian relationship, age-verification vendor or raw ID storage exists;
- client claims never grant eligibility;
- unknown/unsupported market policy cannot fall back to Latvia;
- no profiling-based ads are introduced, and known-minor safeguards require
  their own approved implementation evidence.

## 8. Acceptance and runtime gates

OD-11 becomes at least `Proposed` only after a qualified Legal/Privacy owner
answers §5 for Latvia and defines explicit EE/LT gaps. It becomes `Accepted`
only when:

1. purpose-by-purpose and market-by-market policy is signed;
2. account age, consent age and feature eligibility are explicitly distinct;
3. assurance/data-minimization/DPIA decisions are recorded;
4. Find People, Content and Booking enforcement matrices are approved;
5. notice/consent/guardian/withdrawal/rights behavior is versioned;
6. retention, audit, anti-enumeration and abuse safeguards are approved;
7. tests cover unknown, minor, adult, guardian, revoked and unsupported policy;
8. BCK-01/02/04/06/07/09/22 and LAUNCH_STATUS update atomically.

Acceptance still does not enable a feature. Each runtime path needs its own
Approved slice, server enforcement, rollback and applicable store/market gate.

## 9. Brief acceptance criteria

1. **OD11-LGL-AC-01:** OD-11 remains Open in this brief.
2. **OD11-LGL-AC-02:** GDPR consent age is not account minimum age.
3. **OD11-LGL-AC-03:** Latvia's `13` is confined to its Article 8 consent scope.
4. **OD11-LGL-AC-04:** Latvia evidence is not silently applied to EE/LT.
5. **OD11-LGL-AC-05:** account, Find People, Content and Booking are separate rules.
6. **OD11-LGL-AC-06:** no raw DOB/document collection is selected by default.
7. **OD11-LGL-AC-07:** client claims never authorize age-sensitive access.
8. **OD11-LGL-AC-08:** unknown policy/eligibility fails closed.
9. **OD11-LGL-AC-09:** Legal/Privacy/DPIA and retention evidence is required.
10. **OD11-LGL-AC-10:** policy Acceptance is separate from feature activation.
11. **OD11-LGL-AC-11:** no numerical product policy is invented.
12. **OD11-LGL-AC-12:** this brief creates no schema, vendor or runtime.
