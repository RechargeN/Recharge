# Recharge Backend — Security and Privacy Incident Response Model

- Evidence ID: **BCK04-OD09-IR-01**
- Version: **0.1**
- Date: **2026-08-20**
- Decisions served: **BCK04-OD-09**, **BCK05-OD-08**
- Decision status: **Proposed — owner and qualified Legal/Privacy verdicts pending**
- Evidence status: **Draft — tabletop validation required**
- Accountable owner: **RechargeN / Product owner** (combined Incident/Security role)
- Independence: **self-review; no independent Security/Legal reviewer**
- Runtime status: **Absent**
- Security parent: [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Operations parent: [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Threat input: [BCK04-OD01-TM-01](BACKEND_SECURITY_THREAT_MODEL.md)
- Runtime effect: **none**

---

## 1. Purpose and verdict

This model defines one response language for security, privacy, availability,
integrity, abuse and cost incidents. It separates operational severity from the
legal assessment of risk to people.

It is a concrete proposal, not evidence that on-call routing, monitoring,
forensics, notification or recovery tooling exists. It advances
`BCK04-OD-09` and `BCK05-OD-08` from Open to Proposed; neither is Accepted.

## 2. Core principles

1. Protect people and stop ongoing harm before optimizing availability.
2. Preserve evidence while containing the incident.
3. A suspected incident is tracked until disproved with evidence.
4. Operational severity and personal-data risk are separate decisions.
5. Unknown scope involving authority or personal data starts conservatively.
6. Client messages, public statements and regulator/user notifications require
   approved facts; silence or speculation is forbidden.
7. Repair uses owning-domain commands and reconciliation, not untracked direct
   database edits.
8. Emergency access is narrow, time-bounded and audited.
9. Every incident ends with evidence, remediation owners and follow-up dates.
10. A documentation model does not authorize production processing.

## 3. What is an incident

Create an incident record when any of these is suspected or confirmed:

- unauthorized access, disclosure, modification or deletion;
- compromised session, service identity, secret or release artifact;
- cross-user/page/workspace authorization failure;
- Booking/inventory/ledger inconsistency;
- malicious or accidental data export, log or analytics exposure;
- provider/webhook, upload, dependency or supply-chain compromise;
- failed privacy export/deletion/retention obligation;
- major outage, data loss, restore failure or unbounded cost amplification;
- market/policy/localization failure that bypasses a safety/legal gate;
- monitoring blind spot during a high-risk change;
- any event an operator cannot confidently classify as harmless.

## 4. Operational severity model

The existing repository runbook owns the canonical `SEV-1/2/3` vocabulary and
communication cadence. This model refines triggers without creating SEV-0 or
SEV-4. A `crisis: true` modifier may be added to SEV-1 for root/service-account
compromise, widespread cross-user access, destructive authority corruption or
major sensitive-data exfiltration; it adds executive coordination but does not
change the canonical severity number.

| Level | Plain meaning | Primary triggers | Initial response target | Update cadence |
|---|---|---|---|---|
| **SEV-1 Critical** | production unavailable, critical user/security impact or plausible crisis | root/service compromise; confirmed material protected-data breach; Booking/inventory integrity failure; malicious production artifact; critical authorization bypass | assign Incident Commander and start first-15-minute checklist immediately | ≤15 min |
| **SEV-2 Major** | major degradation/security impact with bounded scope or workaround | limited unauthorized access; provider/replay issue; restore-control failure without confirmed loss; sustained abuse/cost event | assign owner and start first-15-minute checklist | ≤30 min |
| **SEV-3 Limited** | limited degradation or contained issue without critical-flow outage | isolated bounded incident, contained failed job or low-impact exposure | assign owner and start first-15-minute checklist | ≤60 min |

Targets start when Recharge becomes aware of credible evidence. They preserve
the existing runbook cadence, are not service SLOs and do not replace statutory
deadlines. If impact is unknown and a Critical trigger is plausible, classify
as SEV-1 until evidence supports downgrade. A hardening gap with no incident
impact remains a tracked security finding rather than inventing a fourth level.

## 5. Severity decision rules

Escalate severity for any of:

- cross-user, cross-page or cross-market scope;
- Sensitive data, credentials, precise private location or minors;
- authority/ledger/audit integrity uncertainty;
- ongoing attacker access or inability to contain;
- large or unknown affected population;
- irreversible deletion/corruption or unverified restore;
- public exploitation, extortion or safety consequences;
- loss of logging/evidence during the suspected event.

Downgrade only with recorded evidence, approver, UTC time and remaining risk.
Commercial pressure, absence of complaints or a temporarily quiet alert is not
downgrade evidence.

## 6. Incident-type mapping

| Incident type | Default starting level | Mandatory actions |
|---|---:|---|
| root/service identity or production signing secret compromise | SEV-1 + `crisis` | revoke/rotate, isolate release/deploy, preserve IAM/audit, validate artifacts and persistence |
| confirmed broad authorization bypass or sensitive-data export | SEV-1 + `crisis` | disable affected mutations/queries, preserve evidence, privacy-risk assessment, domain reconciliation |
| bounded cross-user/page access | SEV-1 | contain surface, determine full scope, privacy assessment, revoke affected grants/sessions |
| Booking/inventory/ledger invariant failure | SEV-1 | disable new affected work, preserve ledger/audit, reconcile through Booking authority |
| malicious/unknown production artifact or supply-chain compromise | SEV-1 | stop promotion, isolate artifact, verify provenance/dependencies, rollback compatible artifact |
| provider/webhook replay or forged integration input | SEV-1 or SEV-2 | disable provider path, rotate secret if relevant, dedupe/reconcile effects |
| backup/restore evidence failure without known data loss | SEV-2 | block destructive changes, validate backup chain and isolated restore |
| unbounded cost/DoS event with controls available | SEV-2 | rate/flag/quota containment, preserve request/cost evidence |
| privacy request/export/deletion partial failure | SEV-2 | stop false completion, identify affected domains, record partial state and remediation |
| monitoring blind spot during risky production change | SEV-2 | pause change/rollout, restore observability or roll back |
| contained low-impact control failure or bounded attempted exploitation | SEV-3 | preserve evidence, risk-assess, assign remediation, monitor for wider exploitation |

The Incident Commander may raise any level immediately. Lowering follows §5.

## 7. Personal-data breach and risk classification

### 7.1 Separate vocabulary

| Privacy state | Meaning |
|---|---|
| `notPersonalDataBreach` | evidence shows no breach of personal-data security |
| `assessmentPending` | facts/scope are incomplete; Legal/Privacy escalation active |
| `unlikelyRisk` | breach documented, but evidence supports unlikely risk to people's rights/freedoms |
| `likelyRisk` | risk is likely; supervisory-authority notification path applies |
| `highRisk` | high risk; affected-person communication path also applies unless a documented exception applies |

SEV-1/`crisis` does not automatically mean `highRisk`, and SEV-3 does not automatically
mean `unlikelyRisk`. Both assessments must be recorded independently.

### 7.2 Assessment factors

The qualified Legal/Privacy decision record evaluates at least:

- data categories, sensitivity, identifiability and protection/encryption;
- affected or potentially affected people and markets;
- children, vulnerable people or risk of discrimination/safety harm;
- confidentiality, integrity and availability consequences;
- duration, attacker capability, evidence of access/exfiltration/misuse;
- financial, identity, reputational, physical or loss-of-control consequences;
- ease and completeness of containment/revocation/recovery;
- whether backups, logs, projections, processors or recipients are involved;
- residual uncertainty and reasons for the selected conclusion.

No score automatically makes the legal decision. A worksheet may organize
facts; the accountable qualified reviewer records the conclusion and rationale.

### 7.3 Required timing path

- Legal/Privacy is engaged immediately for any suspected personal-data breach.
- The Article 33 decision record tracks when Recharge became aware.
- Where notification is required, the supervisory authority is notified
  without undue delay and, where feasible, within 72 hours of awareness.
- If notification occurs later, the delay reason is recorded.
- `highRisk` additionally triggers communication to affected people without
  undue delay, using clear language and approved facts.
- Missing facts do not stop a phased notification when the applicable legal
  path permits/needs it; later facts are supplied as updates.

These statements preserve BCK-04's legal boundary. This Draft does not claim a
qualified Latvian, Estonian or Lithuanian conclusion.

## 8. Response lifecycle

```text
Detect / report
  -> create incident ID and immutable timeline
  -> initial severity + privacy state
  -> assign Incident Commander and domain owners
  -> contain ongoing harm
  -> preserve evidence and establish scope
  -> eradicate cause / revoke / rotate / patch
  -> reconcile and recover through owning domains
  -> validate monitoring, security and user outcomes
  -> Legal/Privacy and communication decisions
  -> close only with evidence
  -> post-incident review and tracked remediation
```

Containment can precede complete diagnosis when delay increases harm. A risky
containment that may destroy evidence or corrupt authority needs an explicit
decision record.

## 9. Roles and authority

| Role | Authority and obligation |
|---|---|
| Reporter/Detector | opens incident; does not need proof or management approval |
| Incident Commander | owns severity, timeline, coordination, containment choices and status cadence |
| Security Lead | investigates compromise, evidence, access, secrets and control failures |
| Domain Lead | owns domain invariants, reconciliation and safe recovery commands |
| Operations Lead | owns environment, release, flags, observability, capacity and restore execution |
| Privacy/Legal Lead | owns personal-data breach risk and notification advice/decision evidence |
| Communications Lead | issues approved user/public/internal updates; never invents facts |
| Scribe | records immutable UTC timeline, decisions, evidence and owners |

`RechargeN / Product owner` is currently assigned to all roles for planning.
Production readiness requires real reachable contacts, backups and explicit
combined-role risk. Qualified Legal/Privacy judgment remains separately gated.

## 10. Emergency access and break glass

Emergency access must have:

- named incident and reason;
- minimum role/resource/time scope;
- step-up/MFA and no shared identity;
- approval by a second role for destructive/cross-user actions where feasible;
- immutable access and command audit;
- automatic expiry/revocation;
- post-use review and credential/session cleanup.

Break glass cannot bypass Booking/domain invariants, erase evidence, reopen
Rules broadly or become routine operational access.

## 11. Evidence preservation

Preserve, with access and chain-of-custody metadata where applicable:

- Auth/session/revocation and IAM/admin activity;
- request/correlation/idempotency/event IDs and affected revisions;
- deployment artifact/manifest/commit/config/policy revisions;
- relevant logs/alerts without copying unnecessary personal data;
- Rules/IAM/index/environment configuration snapshots;
- provider/webhook signature/replay metadata;
- booking ledger/audit, outbox and reconciliation evidence;
- backup/export/restore evidence;
- decisions, communications and awareness timestamps.

Do not collect broad new personal data “just in case.” Evidence access is
least-privilege, purpose-bound and retained under an accepted incident policy.

## 12. Communication rules

| Audience | Owner | Required content |
|---|---|---|
| internal responders | Incident Commander | known facts, unknowns, severity, containment, next update |
| Product/domain leadership | Incident Commander | user/business impact, decisions needed, risks |
| affected users | Communications + Legal/Privacy | clear nature, likely consequences, measures and protective actions |
| supervisory authority | Legal/Privacy | required breach facts, scope, contact, consequences and measures |
| providers/processors | Operations/Legal | contractual incident request, preservation and containment actions |
| public/status channel | Communications | verified availability/impact facts without sensitive details |

No raw tokens, personal records, exploit instructions or unverified attacker
claims are posted to general chat, tickets or status pages.

## 13. Closure and post-incident review

An incident closes only when:

1. containment is verified and no known ongoing unauthorized access remains;
2. affected data/services/domains and markets are bounded or residual unknowns
   are explicitly accepted by an authorized role;
3. recovery and reconciliation evidence passes;
4. privacy/notification decisions are recorded where applicable;
5. temporary access/flags are revoked or assigned an expiry owner;
6. user/support follow-up is owned;
7. remediation tasks have owner, priority and due date;
8. the final timeline and evidence links are immutable/reviewable.

SEV-1 requires a blameless post-incident review target within five business
days after stabilization. SEV-2 requires one within ten business days. Timing is
a Proposed operational target and does not shorten statutory obligations.

## 14. Exercises and readiness

- contact/on-call route check: monthly before production and after owner change;
- scenario tabletop: quarterly, rotating credential compromise,
  authorization/data breach, Booking integrity and provider/supply-chain cases;
- backup/restore/reconciliation exercise: quarterly under BCK-05;
- notification-decision exercise with qualified Legal/Privacy: before
  production personal-data processing and at least annually;
- unannounced alert-routing test: only after tooling exists and with safeguards;
- every exercise records gaps, owners, due dates and retest evidence.

A tabletop does not prove real IAM, backup, alert or notification capability.

## 15. Required records

Every incident record contains:

```text
incidentId
createdAt / awarenessAt / closedAt
reporter / Incident Commander / assigned roles
severity + history + downgrade evidence
privacyState + Legal/Privacy decision evidence
affected environments/markets/domains/data classes
known facts / unknowns / assumptions
containment/eradication/recovery actions
artifact/config/policy/revision identifiers
evidence links and access restrictions
communications/notifications and timestamps
residual risk and acceptance authority
remediation tasks, owners and due dates
postIncidentReviewRef
```

Production schema/tool selection belongs to a later Approved slice.

## 16. Acceptance and runtime gates

`BCK04-OD-09` may become Accepted only when:

1. Security/Privacy owner approves the severity/type mapping;
2. qualified Legal/Privacy owner approves the personal-data risk decision path;
3. actual incident contacts/routes and backup contacts are recorded securely;
4. threat model Critical/High cases map to a response path;
5. at least one documentation tabletop produces no blocking gap;
6. BCK-04 and the D1 ledger record the exact-version verdict.

`BCK05-OD-08` may become Accepted only when Operations additionally validates
alert routing, break glass, evidence access, rollback/restore ownership and
exercise cadence. Runtime readiness later requires executable alert, IAM,
backup and communication tests.

Acceptance of either decision does not authorize cloud resources or production
processing.

## 17. Acceptance criteria

1. **BCK04-IR-AC-01:** one severity vocabulary covers backend incidents.
2. **BCK04-IR-AC-02:** unknown material impact starts conservatively.
3. **BCK04-IR-AC-03:** downgrade requires recorded evidence and authority.
4. **BCK04-IR-AC-04:** operational SEV and privacy risk remain independent.
5. **BCK04-IR-AC-05:** likely/high privacy risk is not selected automatically.
6. **BCK04-IR-AC-06:** the 72-hour path starts from recorded awareness.
7. **BCK04-IR-AC-07:** qualified Legal/Privacy evidence remains required.
8. **BCK04-IR-AC-08:** personal-data breach records include facts/effects/actions.
9. **BCK04-IR-AC-09:** containment may precede full diagnosis to reduce harm.
10. **BCK04-IR-AC-10:** repair preserves owning-domain authority.
11. **BCK04-IR-AC-11:** break glass is named, narrow, expiring and audited.
12. **BCK04-IR-AC-12:** no shared privileged identity is authorized.
13. **BCK04-IR-AC-13:** evidence collection remains purpose/minimization bound.
14. **BCK04-IR-AC-14:** communications use verified approved facts.
15. **BCK04-IR-AC-15:** user/regulator/internal communications are distinct.
16. **BCK04-IR-AC-16:** incident closure requires reconciliation evidence.
17. **BCK04-IR-AC-17:** temporary access/flags cannot survive closure silently.
18. **BCK04-IR-AC-18:** remediation has owner and due date.
19. **BCK04-IR-AC-19:** exercise evidence is not runtime proof.
20. **BCK04-IR-AC-20:** response targets are Proposed, not service SLOs.
21. **BCK04-IR-AC-21:** Legal deadlines are not weakened by internal targets.
22. **BCK04-IR-AC-22:** Latvia policy is not silently generalized to EE/LT.
23. **BCK04-IR-AC-23:** self-review and missing independence are disclosed.
24. **BCK04-IR-AC-24:** Accepted documentation remains separate from runtime.
25. **BCK04-IR-AC-25:** this document creates no code or cloud resource.
