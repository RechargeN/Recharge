# BCK-20 — Mandatory Legal and Safety Copy Policy Review

- Review ID: **BCK20-OD05-POL-REV-01**
- Version: **0.1**
- Date: **2026-09-20**
- Status: **Proposed — Product design boundary ready; qualified Legal verdict absent**
- Decision served: **BCK20-OD-05**
- Exact BCK-20 target: [BCK-20 v0.2.21](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Target normalized-LF SHA-256:
  `b9520fa15ec99d2272dee2d2edb9b7b42bcfabcceddabfd915e9af850b7a7da9`
- Exact OD-10 evidence: [BCK-D1-OD10-EV-01 v0.2](BACKEND_OD_10_LOCALIZATION_EVIDENCE.md)
- Evidence normalized-LF SHA-256:
  `dceebb4ed1f993523393c8a979099ae5b02798d50d8349275109ae92c8063cfd`
- Product owner/coordinator: **RechargeN / Product owner**
- Required retained authority: **named qualified Legal/Privacy reviewer for
  applicable market, purpose and surface**
- Independence: **none**
- Legal advice claim: **none**
- Runtime effect: **none**

---

## 1. Purpose and recommended Product verdict

This package defines the product/technical policy boundary for copy that may
not use ordinary locale fallback. It deliberately does not decide which
language is legally mandatory in Latvia, Estonia or Lithuania, whether a
specific text is legally sufficient, or which legal basis applies.

Recommended Product verdict:

**Accept mandatory-copy classification and fail-closed design boundary with
retained qualified Legal and executable gates.**

The verdict would make the classification reviewable and implementation-ready
in principle, but BCK20-OD-05 remains Open until a qualified reviewer supplies
the exact market/surface/locale/revision matrix.

## 2. Core invariants

1. Mandatory copy is identified by stable `copyPolicyId`, not UI label or
   screen name.
2. Each policy record is market-, surface-, purpose- and revision-scoped.
3. `requiredLocales` is explicit; it is never inferred from device locale,
   home market, content language or another Baltic market.
4. `fallbackForbidden=true` means no generic language, market or default-value
   fallback can produce an authoritative success.
5. Missing, expired, withdrawn, unapproved, stale mandatory or wrong-market
   copy disables the affected action/surface.
6. Viewer convenience fallback can never authorize consent, acceptance,
   purchase, publication, booking, safety acknowledgement or account action.
7. Machine translation, AI rewriting and silent normalization cannot create
   an approved mandatory revision.
8. Acceptance evidence records the exact copy revision and locale presented.
9. A changed legal/policy requirement creates a new immutable revision; it
   does not rewrite historical acceptance evidence.
10. Latvia readiness cannot satisfy Estonia or Lithuania readiness.

## 3. Copy classes

| Class | Examples | Default fallback posture | Missing-copy effect |
|---|---|---|---|
| `legal_notice` | privacy notice, terms, processor/transfer disclosure where required | forbidden unless qualified policy explicitly permits a named alternative | block affected consent/acceptance or surface |
| `consent_text` | granular consent, marketing permission, optional data processing | forbidden | do not collect consent; feature requiring it disabled |
| `transaction_terms` | booking/cancellation/refund obligations, material transaction disclosure | forbidden for authoritative confirmation | block transaction/confirmation; informational preview must not imply completion |
| `age_eligibility` | account or feature age rule, guardian/eligibility notice | forbidden | deny gated feature; do not infer age permission |
| `rights_and_requests` | DSR rights, deletion/export/appeal instructions | forbidden for authoritative submission guidance unless qualified policy says otherwise | block or route to approved accessible support path without inventing copy |
| `safety_critical` | emergency, access restriction, health/safety prerequisite, organizer safety acknowledgement | forbidden by default | hide/disable affected action or require approved exact-language acknowledgement |
| `enforcement_and_appeal` | moderation sanction reason classes, appeal rights/process | forbidden for authoritative notice | do not finalize notice/decision delivery until approved copy exists |
| `identity_and_authority` | verification consequence, page/workspace authority, privileged-action confirmation | forbidden for authoritative confirmation | block privileged action/confirmation |
| `material_product_disclosure` | not-live data, provider limitation, material availability/freshness warning | only explicitly approved fallback with visible language/provenance state | affected claim/action disabled when policy marks disclosure mandatory |
| `ordinary_product_copy` | navigation labels, generic descriptions, non-material helper text | deterministic OD-10 fallback allowed | typed missing/fallback state; no authority effect |
| `user_authored_content` | titles, descriptions, comments, organizer text | no implied translation; original `contentLocale` preserved | show original/typed unavailable by product policy |

This table is a conservative design taxonomy. A qualified reviewer may narrow
or expand mandatory classes for a specific market and purpose. Until then,
ambiguity is classified into the stricter applicable class.

## 4. Target policy record

Documentation-only target:

```text
MandatoryCopyPolicyV1 {
  copyPolicyId
  policyRevision
  marketId
  environment
  surfaceId
  purposeId
  copyClass
  requiredLocales[]
  fallbackForbidden
  allowedFallbackLocales[]
  acknowledgementMode: none | view | explicit_accept | explicit_confirm
  effectiveFrom
  expiresAt?
  supersedesRevision?
  legalApprovalRef
  productApprovalRef
  contentRevisionRefsByLocale
  withdrawalState
  schemaRevision
}
```

No field above authorizes schema creation. Physical encoding remains gated by
API-DEC-05 and a separately Approved executable slice.

## 5. Required qualified decision matrix

One row is required for every affected market/surface/purpose combination:

| Field | Required qualified determination |
|---|---|
| market and jurisdiction assumptions | exact market/legal scope and exclusions |
| surface/purpose | exact action, notice, consent or transaction being governed |
| copy class | applicable class and rationale |
| required locales | exact locale set; no inference |
| fallback | forbidden or exact permitted fallback with conditions |
| acknowledgement | none/view/accept/confirm and evidence requirements |
| effective/expiry rule | when revision becomes valid and when it must stop |
| retention | acceptance/presentation evidence retention and lawful exceptions |
| withdrawal/correction | stop condition, replacement and historical evidence treatment |
| accessibility | required accessible delivery and alternate support path |
| reviewer | name, capacity, qualification, conflicts and date |
| approval reference | exact immutable qualified verdict/evidence ID |
| re-review triggers | law/policy/source/surface/purpose/copy changes |

An empty, conditional or conflicting row remains Pending and the affected
surface fails closed.

## 6. Resolution and presentation behavior

### 6.1 Authoritative action

Before an authoritative action:

1. resolve current market/environment and copy policy revision;
2. verify the action's surface and purpose match the policy;
3. verify required locale and approved content revision;
4. reject withdrawn, expired, stale, wrong-market or integrity-failed copy;
5. present the exact approved revision;
6. record acknowledgement only after successful presentation and user action;
7. revalidate policy revision at commit time when the action changes state.

Policy revision change between presentation and commit produces a typed
`mandatory_copy_changed` outcome and requires re-presentation. It is not a
successful acknowledgement.

### 6.2 Informational read

An informational read may use ordinary OD-10 fallback only when the governing
copy class permits it. The UI must preserve requested/resolved locale and
fallback state. Informational fallback cannot be reused as authoritative
acceptance evidence.

### 6.3 Offline and stale state

- cached mandatory copy is usable only under an explicitly accepted policy;
- expired or unknown-revision mandatory copy fails closed;
- offline state cannot invent consent or confirmation;
- queued acceptance is prohibited unless a later qualified/executable policy
  explicitly defines revalidation and user intent semantics.

## 7. Typed documentation outcomes

| Outcome | Meaning | Required behavior |
|---|---|---|
| `mandatory_copy_missing` | no approved required-locale revision | disable affected action/surface |
| `mandatory_copy_stale` | freshness/effective revision cannot be proven | fail closed and request authorized refresh path |
| `mandatory_copy_changed` | policy/copy revision changed after presentation | require re-presentation; no commit |
| `mandatory_copy_withdrawn` | revision is no longer eligible | disable and route to approved replacement/support |
| `mandatory_copy_wrong_market` | copy/policy scope does not match effective market | fail closed; never substitute another market |
| `mandatory_copy_wrong_purpose` | copy approved for a different action/purpose | fail closed |
| `mandatory_copy_integrity_failed` | content/policy identity does not verify | quarantine/disable; no acceptance |
| `mandatory_copy_policy_unsupported` | client/backend cannot interpret critical policy revision | fail closed; minimum-client policy applies later |
| `mandatory_copy_ack_required` | approved copy shown but required user action absent | no authoritative success |

These are documentation names, not an authorized wire schema.

## 8. Audit and privacy boundary

Evidence may record:

- user/account or workspace subject according to owning-domain policy;
- market/environment/surface/purpose IDs;
- copy policy and content revision IDs;
- presented locale and acknowledgement mode;
- server receipt time and authoritative result;
- request/idempotency identities where applicable.

Evidence must not duplicate full copy text, arbitrary user input or unrelated
personal data. Retention, lawful basis, access, export, deletion and legal-hold
rules require BCK-04 and qualified policy. Operational telemetry uses IDs and
typed outcomes only.

## 9. Market activation matrix

| Market | Current state | Product design readiness | Qualified locale/copy matrix | Activation effect |
|---|---|---|---|---|
| Latvia | disabled | this package supplies Proposed class/fail-closed boundary | Pending | no activation |
| Estonia | disabled | isolation only | Pending; must be market-specific | no activation |
| Lithuania | disabled | isolation only | Pending; must be market-specific | no activation |

No market can borrow another market's qualified result. EU-level guidance may
be an input but does not replace country/surface-specific disposition.

## 10. Recommended exact Product-owner response

```text
Одобряю BCK20-OD05-POL-REV-01 v0.1:
Accept mandatory-copy classification and fail-closed design boundary with
retained qualified Legal and executable gates для точных BCK-20 v0.2.21 /
normalized-LF SHA-256
b9520fa15ec99d2272dee2d2edb9b7b42bcfabcceddabfd915e9af850b7a7da9
и BCK-D1-OD10-EV-01 v0.2 / normalized-LF SHA-256
dceebb4ed1f993523393c8a979099ae5b02798d50d8349275109ae92c8063cfd.
Принимаю только Product/technical classification, fail-closed defaults,
policy-record boundary и qualified decision template. Не заявляю qualified
Legal/Privacy verdict или independent review. BCK20-OD-05 остаётся Open;
OD-10 Proposed; BCK-20 Draft; все markets disabled. Schema, fixtures, copy
approval, runtime, Firebase, deployment, activation, push и merge не разрешаю.
```

## 11. Acceptance criteria

1. **BCK20-OD05-POL-AC-01:** exact BCK-20 and OD-10 inputs are hash-pinned.
2. **BCK20-OD05-POL-AC-02:** Product design and qualified Legal judgment remain separate.
3. **BCK20-OD05-POL-AC-03:** mandatory copy uses stable policy/revision identity.
4. **BCK20-OD05-POL-AC-04:** required locales are explicit and market-scoped.
5. **BCK20-OD05-POL-AC-05:** fallbackForbidden never resolves through generic fallback.
6. **BCK20-OD05-POL-AC-06:** viewer fallback cannot authorize an action.
7. **BCK20-OD05-POL-AC-07:** machine translation cannot create approved mandatory copy.
8. **BCK20-OD05-POL-AC-08:** changed policy between presentation and commit requires re-presentation.
9. **BCK20-OD05-POL-AC-09:** missing/stale/withdrawn/wrong-market mandatory copy fails closed.
10. **BCK20-OD05-POL-AC-10:** acknowledgement records exact policy/content revision and locale.
11. **BCK20-OD05-POL-AC-11:** informational fallback is not acceptance evidence.
12. **BCK20-OD05-POL-AC-12:** offline state cannot invent consent or confirmation.
13. **BCK20-OD05-POL-AC-13:** audit evidence minimizes copy text and personal data.
14. **BCK20-OD05-POL-AC-14:** qualified matrix is per market/surface/purpose.
15. **BCK20-OD05-POL-AC-15:** Latvia evidence cannot activate Estonia or Lithuania.
16. **BCK20-OD05-POL-AC-16:** ambiguous classification uses the stricter fail-closed class.
17. **BCK20-OD05-POL-AC-17:** physical schema remains gated by API-DEC-05.
18. **BCK20-OD05-POL-AC-18:** exact copy and Legal sufficiency remain outside Product-owner authority.
19. **BCK20-OD05-POL-AC-19:** BCK20-OD-05 remains Open after Product acceptance.
20. **BCK20-OD05-POL-AC-20:** OD-10 remains Proposed and BCK-20 Draft.
21. **BCK20-OD05-POL-AC-21:** all markets remain disabled.
22. **BCK20-OD05-POL-AC-22:** no copy, source or executable artifact is approved.
23. **BCK20-OD05-POL-AC-23:** owner acceptance permits documentation reconciliation only.
24. **BCK20-OD05-POL-AC-24:** schema, fixtures, runtime, Firebase, deployment, push and merge remain unauthorized.

## 12. Next action

Freeze this package by normalized-LF SHA-256. Product owner may accept the
technical classification in one bounded verdict. A named qualified reviewer
must then complete §5 for every intended Latvia launch surface; Estonia and
Lithuania remain separate future reviews. No implementation begins from this
package.
