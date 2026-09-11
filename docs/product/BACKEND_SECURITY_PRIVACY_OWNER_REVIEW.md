# Recharge Backend — Security & Privacy Architecture Owner Review

- ID: **BCK04-SEC-REV-01**
- Version: **0.1**
- Date: **2026-09-11**
- Status: **Proposed review — owner verdict pending**
- Recommended result: **Accept with required amendments — technical documentation boundary only**
- Reviewer: **RechargeN / Product owner** (combined Security/Privacy role)
- Independence: **not evidenced**
- Legal qualification: **not evidenced**
- Target: [BCK-04 v0.4.21](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Coverage: [BCK-04-PRE v0.3.21](BACKEND_SECURITY_PRIVACY_COVERAGE_MATRIX.md)
- Threat input: [BCK04-OD01-TM-01 v0.1](BACKEND_SECURITY_THREAT_MODEL.md)
- Incident input: [BCK04-OD09-IR-01 v0.1](BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md)
- Tabletop input: [BCK04-OD09-TTX-01 v0.1](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md)
- API baseline: [BCK-03 v0.3.12](BACKEND_API_CONTRACT_STANDARD.md)
- Runtime effect: **none**

## 1. Scope and verdict boundary

This review checks the technical Security/Privacy architecture of BCK-04 and
its consistency with the current API contract. It does not provide independent
Security review, qualified Legal/Privacy advice, a Latvian/Estonian/Lithuanian
legal conclusion, or evidence that any control exists in runtime.

The direction is coherent and structurally complete, but the exact reviewed
revision cannot leave Draft yet. Required contract amendments remain, the
threat and incident decisions are still Proposed, the tabletop is unexecuted,
OD-11 is Open, and independent and qualified Legal evidence are absent.

## 2. Review matrix

| Area | Result | Evidence / preserved gate |
|---|---|---|
| Source priority and ownership | Pass | Accepted ADR remain superior; Privacy Orchestration never writes another domain's aggregate |
| Authentication and authority | Pass with amendment | Auth is not authority; protected/sensitive queries must re-evaluate current grants just as mutations do |
| Data classification | Pass | One five-class model; audit/analytics are purpose or record-kind labels, not parallel classes |
| API and idempotency reconciliation | Gap — amendment required | BCK-03 split identity is resolved, but BCK-04 AC-06 and the DSR flow still use stale request-ID semantics |
| Privacy request identity | Gap — amendment required | Attempt correlation, logical command identity and persistent PrivacyRequest identity must be three explicit values |
| DSR scope authorization | Pass with amendment | Subject, workspace and resource scope must be server-resolved and owner-bound before dispatch/export |
| DSR unknown outcome/cancellation | Pass with amendment | Pre-send cancellation, post-send ambiguity and authoritative cancellation need distinct typed behavior |
| DSR export delivery | Gap — amendment required | Export retrieval must be authenticated, short-lived, purpose-bound and audited; raw email attachment is not a safe default |
| Retention, erasure and restore | Pass with amendment | Holds/exemptions need authority and review evidence; restore must not silently resurrect erased or restricted data |
| Threat model | Gated | 36 threats and owners are present; owner decision and independent Security review remain absent |
| Incident response | Gated | Model is reviewable, but qualified Legal verdict and a passed tabletop are absent |
| Age/minors policy | Gated | OD-11 remains Open and all affected market paths remain fail-closed |
| Rules, IAM, App Check and secrets | Pass at design level | Physical Rules/IAM/KMS/MFA/App Check evidence remains a later executable gate |
| Multi-market activation | Pass | LV, EE and LT policy revisions and activation remain independent |
| Production readiness | Not evaluated | G1, R1, Firebase resources, deployment and production processing remain blocked |

## 3. Required amendments

Before any BCK-04 status promotion, integrate and recheck all amendments below.

1. **Reconcile DSR command identity with BCK-03 v0.3.12.** Every physical
   attempt receives a fresh `requestId`; retry of one logical submission keeps
   its `idempotencyKey` and normalized payload. Equality may occur on the first
   attempt but is never required.
2. **Separate persistent request identity.** A successful submission returns a
   server-issued `privacyRequestId`. Status, cancellation and export retrieval
   address that ID under current owner authorization; they do not use an
   attempt `requestId` as the resource key.
3. **Correct the stale acceptance criterion.** BCK-04-AC-06 must require
   consistency with the resolved split-key contract instead of saying the
   former contradiction remains unresolved.
4. **Reauthorize protected reads.** Current account/session, capability,
   ownership, workspace and market policy are evaluated for protected or
   sensitive queries and result disclosure, not only for mutations. Cached
   grants and previously issued export links are not authority.
5. **Bind DSR scope server-side.** Client-supplied subject, publisher,
   workspace, domain or resource references are untrusted filters. They cannot
   widen the verified data subject's scope or include another person's data.
6. **Define unknown-outcome and cancellation behavior.** Local pre-send cancel
   means no submitted request. A timeout after send is `unknownOutcome` and is
   reconciled by the same idempotency key or returned resource receipt. An
   authoritative cancel is allowed only before the declared irreversible
   boundary; later attempts return a typed state conflict without pretending
   completed work was undone.
7. **Make DSR status revision-safe.** Responses carry server revision and
   freshness evidence. Late, cached or offline responses cannot overwrite a
   newer state or extend freshness; terminal states cannot regress.
8. **Specify safe export handoff.** Export availability returns an
   authenticated, short-lived, single-purpose retrieval capability after
   step-up where risk requires it. Retrieval is owner-bound, bounded, audited
   and revocable; raw export attachments in ordinary email are prohibited.
   Exact transport and lifetime remain BCK04-OD-08 decisions.
9. **Prevent deletion resurrection.** Erasure/restriction creates sufficient
   coordinator evidence for late workers, projections, imports and restores to
   remain suppressed or be re-reconciled. Identity teardown is sequenced so
   remaining domain tasks can complete without re-opening user authority.
10. **Bound legal/security holds.** Any retention exception or hold records its
    lawful/authorized basis, scope, owner, start, review/expiry condition and
    release evidence. A generic retention period is not an erasure exemption.
11. **Make App Check recovery non-bypassable.** Emergency degradation may
    change only the attestation layer; it cannot disable authentication,
    authorization, validation, rate limits or audit. It is narrow, expiring,
    monitored and separately approved under BCK04-OD-04.
12. **Correct current-revision wording.** The test/evidence section must refer
    to BCK-04 v0.4.21 (or `current revision`), not the historical v0.4.9.
13. **Keep decision gates explicit.** BCK04-OD-01 and BCK04-OD-09 cannot be
    accepted by this general review. Each needs its exact owner decision;
    OD-09 additionally retains qualified Legal and executed-tabletop gates.
14. **Preserve legal independence.** OD-11, lawful-basis, retention,
    processor/transfer, DPIA/ROPA and Article 22 conclusions remain reserved to
    qualified Legal/Privacy review for every enabled market and purpose.

## 4. Preserved statuses

- BCK-04 remains **Draft**.
- BCK04-OD-01 and BCK04-OD-09 remain **Proposed**.
- OD-11 remains **Open**.
- BCK04-OD-02–08 and BCK04-OD-10–14 retain their current status and gates.
- D1-SIG-SEC remains recorded only for the BCK-03 boundary until an explicit
  owner decision extends its scope.
- D1-SIG-LEGAL remains **Pending**; qualification is not inferred.
- Independent Security/Privacy evidence remains absent.
- Runtime, Firebase, deployment, push and merge remain unauthorized.

## 5. Recommended owner verdict

```text
Одобряю BCK04-SEC-REV-01 v0.1:
Accept with required amendments для технической границы BCK-04.
Это combined-owner documentation verdict; independent Security/Privacy и
qualified Legal/Privacy evidence отсутствуют. BCK-04 остаётся Draft,
BCK04-OD-01/09 остаются Proposed, OD-11 остаётся Open.
Runtime, Firebase, deployment, push и merge не разрешаю.
```

If approved, the next documentation-only change integrates the fourteen
amendments, records the exact bounded owner verdict and reconciles the canonical
D1/BCK registry. It still does not promote BCK-04 to Review or accept any OD.

## 6. Acceptance criteria

1. **BCK04-SEC-REV-AC-01:** the review is limited to technical documentation.
2. **BCK04-SEC-REV-AC-02:** combined ownership is not called independent review.
3. **BCK04-SEC-REV-AC-03:** no qualified Legal conclusion is inferred.
4. **BCK04-SEC-REV-AC-04:** request attempt, logical idempotency and persistent
   PrivacyRequest identity remain distinct.
5. **BCK04-SEC-REV-AC-05:** protected reads re-evaluate current authority.
6. **BCK04-SEC-REV-AC-06:** DSR scope cannot be widened by client input.
7. **BCK04-SEC-REV-AC-07:** unknown outcome and cancellation are typed.
8. **BCK04-SEC-REV-AC-08:** DSR state is monotonic, revisioned and server-fresh.
9. **BCK04-SEC-REV-AC-09:** export delivery is short-lived, owner-bound and audited.
10. **BCK04-SEC-REV-AC-10:** deletion/restriction survives restore and late work.
11. **BCK04-SEC-REV-AC-11:** holds and exemptions require bounded evidence.
12. **BCK04-SEC-REV-AC-12:** App Check recovery cannot bypass other controls.
13. **BCK04-SEC-REV-AC-13:** threat/incident/age decisions retain exact gates.
14. **BCK04-SEC-REV-AC-14:** BCK-04 stays Draft until its full DoR passes.
15. **BCK04-SEC-REV-AC-15:** no code, Firebase, deployment, push or merge
    authority is created.

## 7. Next action

Obtain the exact owner verdict above. Do not integrate amendments, accept
BCK04-OD-01/09, run the tabletop or begin executable work before that verdict.
