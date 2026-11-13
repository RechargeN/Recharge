# Recharge Backend — Security Incident Tabletop Exercise Package

- Evidence ID: **BCK04-OD09-TTX-01**
- Version: **0.1**
- Date: **2026-08-20**
- Package status: **Ready for scheduling**
- Exercise status: **Not scheduled — not executed**
- Result status: **No result; no pass claimed**
- Decisions served: **BCK04-OD-09**, **BCK05-OD-08**
- Accountable coordinator: **RechargeN / Product owner**
- Required perspectives: **Incident, Security, Operations, Privacy/Legal,
  Communications and affected domain owner**
- Independence: **facilitator/evaluator independence not yet evidenced**
- Runtime status: **Absent**
- Incident model: [BCK04-OD09-IR-01](BACKEND_SECURITY_INCIDENT_RESPONSE_MODEL.md)
- Threat model: [BCK04-OD01-TM-01](BACKEND_SECURITY_THREAT_MODEL.md)
- Security parent: [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Operations parent: [BCK-05](BACKEND_DEPLOYMENT_OPERATIONS_SPEC.md)
- Runtime effect: **none**

---

## 1. Purpose and honest verdict

This package makes the first backend security/privacy tabletop repeatable and
auditable. It supplies the scenario, facilitator injects, expected control
decisions, observation forms, blocker vocabulary and completion record.

The exercise has **not** been run. Blank participant, timestamp, decision and
result fields are intentional. Document presence is preparation evidence only;
it does not satisfy the tabletop gate, accept either decision or demonstrate
working IAM, alerts, backups, legal notification or recovery.

## 2. Exercise objective

The exercise tests whether the team can, on paper and without touching a real
environment:

1. declare one incident and preserve the canonical `SEV-1/2/3` vocabulary;
2. separate operational severity from personal-data-breach risk;
3. assign authority without accepting client/operator claims as truth;
4. contain cross-user access while preserving evidence;
5. protect Booking ledger/domain-writer invariants during recovery;
6. start and record the awareness/notification decision clock;
7. communicate verified facts without exposing sensitive evidence;
8. identify missing runtime controls honestly;
9. produce owned, dated remediation and retest actions.

## 3. Status lifecycle

```text
Draft
  -> Ready for execution
  -> Scheduled
  -> Executed / evaluation pending
  -> Passed | Passed with non-blocking actions | Not passed
  -> Retest required
  -> Retest passed | Retest not passed
```

Rules:

- only a named facilitator may mark the exercise `Executed`;
- only a completed §15 record plus §14 evaluation may set a result;
- `Passed with non-blocking actions` contains no Blocker finding;
- a missing mandatory role, invented evidence or skipped privacy decision path
  makes the result `Not passed`;
- a simulated action never becomes runtime proof.

## 4. Format and safe boundaries

- Target duration: **120 minutes**, plus a 30-minute debrief.
- Mode: documentation tabletop; no production systems, credentials, user data,
  regulator contact or public communication.
- Facilitator reveals injects in order and records actual team decisions.
- Participants may request facts; the facilitator answers only from §10.
- Assumptions are allowed only when recorded as assumptions and gaps.
- Screenshots/notes must not contain real secrets or personal data.
- This exercise cannot provide qualified legal advice. A qualified
  Legal/Privacy participant owns any legal conclusion; otherwise the expected
  action is escalation and the legal verdict remains `assessmentPending`.

## 5. Preconditions and scheduling gate

Before scheduling, record:

| Required item | Minimum evidence | Current state |
|---|---|---|
| Facilitator | named person not simultaneously acting as Incident Commander | Pending |
| Evaluator/scribe | named person and recording location | Pending |
| Incident Commander | named primary and backup | Pending |
| Security and Operations | named reachable participants | Pending |
| Privacy/Legal | named participant; qualification stated honestly | Pending |
| Communications | named participant or explicit combined-role disclosure | Pending |
| Domain owner | Booking owner for Scenario A | Pending |
| Secure exercise record | repository/ticket location without secrets | Pending |
| Date/time/time zone | ISO date plus IANA zone | Pending |
| Conflict disclosure | combined roles and missing independence listed | Pending |

The coordinator may schedule with combined roles, but cannot hide missing
independence or legal qualification. A no-show for Incident, Security,
Operations or the affected domain is a Blocker. Privacy/Legal absence is a
Blocker for validating the legal decision path; it does not permit another
role to invent the conclusion.

## 6. Roles during the exercise

| Role | Exercise responsibility | Forbidden shortcut |
|---|---|---|
| Facilitator | releases injects, answers from scenario facts, protects pace | coaching the desired answer as if it were participant evidence |
| Evaluator/Scribe | records UTC timeline, decisions, evidence requests and findings | filling gaps after the session without attribution |
| Incident Commander | declares severity, assigns owners, chooses containment and cadence | taking every technical/legal role silently |
| Security Lead | scopes compromise, access, secrets and evidence preservation | broad untracked access or destructive collection |
| Operations Lead | proposes flags, release freeze, rollback, IAM and restore actions | claiming nonexistent tooling worked |
| Privacy/Legal Lead | owns breach-risk and notification-decision process | treating SEV as the legal conclusion |
| Booking Domain Lead | protects ledger/inventory/audit authority and reconciliation | direct database repair or ledger rewrite |
| Communications Lead | drafts verified internal/user/public messages | publishing speculation, tokens or personal records |

## 7. Scenario A — privileged compromise, cross-user exposure and Booking risk

### 7.1 Initial context

Recharge is assumed to have a production-like backend for simulation only.
Latvia is active; Estonia and Lithuania are disabled. A new backend release was
promoted 40 minutes ago. Monitoring reports abnormal reads from a privileged
service identity. A support ticket alleges that one user briefly saw another
user's Booking details.

This context is fictional. It is not evidence that such infrastructure or data
exists in the repository.

### 7.2 Success themes

- one SEV-1 incident, with `crisis: true` considered when compromise scope is
  credible;
- `assessmentPending` privacy state until accountable evidence supports a
  qualified decision;
- release freeze, authority containment and evidence preservation;
- no direct Booking ledger edits;
- explicit awareness time and 72-hour decision path;
- verified, audience-specific communications;
- unknowns remain visible.

## 8. Optional rotation scenarios

These are separate future exercises, not simultaneous hidden requirements for
the first run.

| Rotation | Primary controls tested | Starting evidence |
|---|---|---|
| B — supply-chain artifact | signing/provenance, promotion freeze, rollback, dependency scope | deployed artifact digest differs from approved manifest |
| C — provider replay/cost abuse | signature/replay defense, quotas, outbox dedupe, provider disable | duplicate webhook effects and rapidly rising spend |
| D — restore and privacy-request failure | backup chain, isolated restore, DSR partial state, honest completion | deletion job says complete while one domain task failed |

Each rotation requires its own execution record. Passing Scenario A does not
claim coverage of B–D.

## 9. Facilitator rules

1. Do not reveal future injects or expected decisions.
2. Record the time each inject is released and when the team responds.
3. If the team asks for an unavailable control, answer “not evidenced” and
   record a gap; do not simulate a successful tool invisibly.
4. If the team attempts a dangerous direct write, ask for authority,
   idempotency, audit and rollback evidence.
5. Legal questions are answered only by the qualified participant. Otherwise
   record escalation and `assessmentPending`.
6. The facilitator may compress time but must not erase deadlines or unknowns.
7. Stop the exercise for real safety, privacy or production impact.

## 10. Inject sequence and scenario facts

| Exercise time | Inject supplied to participants | Facts available if requested | Control being tested |
|---:|---|---|---|
| T+00 | Alert: privileged identity made unusual cross-user reads after release | alert is credible; scope unknown; awareness clock starts now | incident creation, severity, roles, release freeze |
| T+08 | Support reports one user saw another user's Booking name/time | report is authentic; exact record count unknown | privacy state, user harm, anti-enumeration scope |
| T+16 | IAM log shows a service credential used from an unexpected execution context | credential validity is confirmed; attacker persistence unknown | revoke/rotate/isolate versus evidence preservation |
| T+24 | Metrics show Booking inventory mismatch for three occurrences | cause may be read exposure, retry or mutation; ledger remains available | domain authority, stop-work boundary, reconciliation |
| T+34 | Operator proposes editing inventory directly to restore availability | no approved direct-write repair path exists | fail-closed repair and audit |
| T+44 | Log export has a 12-minute gap during the suspicious window | alternative request/audit evidence is partial | uncertainty, severity, evidence-gap handling |
| T+54 | Processor reports one encrypted export object was downloaded; key-access evidence is incomplete | object may contain Protected/Sensitive records; contents/scope unconfirmed | Legal/Privacy escalation and risk factors |
| T+66 | Revocation stops new suspicious calls, but old sessions may remain valid | session revocation propagation is not evidenced | containment validation and residual risk |
| T+78 | Journalist asks whether Recharge leaked customer data | no approved final scope or legal conclusion exists | verified public communication |
| T+90 | Booking reconciliation reports no lost ledger entries, but two derived availability projections are stale | owning ledger is consistent; projections require rebuild | recovery order, freshness and user impact |
| T+102 | All known privileged access is contained; affected-person count remains a range | remaining uncertainty is documented | notification decision, phased facts, closure blockers |

The facilitator does not state whether the final privacy state is `likelyRisk`
or `highRisk`. The qualified Privacy/Legal participant must evaluate the facts,
unknowns and applicable law. Without that participant, the recorded result is
escalation with `assessmentPending` and the legal-path objective is not passed.

## 11. Mandatory decision checkpoints

| Checkpoint | Required record | Blocking failure examples |
|---|---|---|
| C1 — declaration | incident ID, awareness time, initial SEV/privacy state | no incident opened; severity invented outside SEV-1/2/3 |
| C2 — authority | Incident Commander and role assignments | nobody owns containment/timeline |
| C3 — containment | release/identity/session/domain actions with owner/rollback | broad Rules opening; untracked shared admin access |
| C4 — evidence | sources preserved, gaps and access restrictions | destructive action before preservation without decision record |
| C5 — Booking integrity | pause/reconcile/rebuild through Booking authority | direct ledger/inventory edit |
| C6 — privacy path | awareness clock, facts, risk factors, qualified escalation | severity used as automatic legal result |
| C7 — communications | internal, user/regulator and public drafts separated | public certainty unsupported by evidence |
| C8 — recovery | authority first, projections second, validation and residual risk | traffic restored while privileged persistence unknown |
| C9 — closure | all §13 closure conditions or explicit reason incident stays open | closing only because alerts stopped |

## 12. Expected control decisions — evaluator key

This is an evaluation key, not a script participants must repeat verbatim.

1. Open a single incident at T+00 and start conservatively at SEV-1 while a
   privileged cross-user compromise remains plausible.
2. Record privacy state `assessmentPending`; do not infer it from SEV.
3. Assign Incident Commander, Security, Operations, Privacy/Legal, Booking and
   Communications owners; disclose combined roles.
4. Freeze risky promotion and contain the privileged identity/session path
   using named, reversible and audited actions.
5. Preserve IAM, request, release, ledger/audit and processor evidence before
   destructive cleanup where safe.
6. Disable affected work if needed, but retain Booking as the only ledger and
   inventory authority; reject direct repair.
7. Track the 12-minute evidence gap as uncertainty that prevents an unsupported
   downgrade or closure.
8. Give the Privacy/Legal owner the facts and awareness time; keep the
   Article 33/34 decision record separate from operational severity.
9. Respond to media with a holding statement limited to verified facts.
10. Reconcile ledger/audit, rebuild derived projections, validate freshness and
    only then restore affected behavior.
11. Keep the incident open while persistence, affected scope, notification or
    residual-risk decisions remain unresolved.
12. Convert every missing runtime control into an owner/date/retest finding.

## 13. Observation and decision log templates

### 13.1 Timeline

| UTC time | Inject/event | Decision/action | Owner | Evidence/assumption | Result |
|---|---|---|---|---|---|
| — | — | — | — | — | — |

### 13.2 Severity/privacy history

| UTC time | SEV | Privacy state | Changed by | Evidence/rationale | Approver |
|---|---|---|---|---|---|
| — | — | — | — | — | — |

### 13.3 Findings

| Finding ID | Class | Description/evidence | Owner | Due date | Retest evidence | State |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | Open |

Finding classes:

- **Blocker:** unsafe authority/repair, missing mandatory decision/role,
  fabricated proof, uncontained critical harm or failed privacy clock/path;
- **Major:** material delay/ambiguity that could become a Blocker in runtime;
- **Minor:** clarity, ergonomics or non-critical evidence improvement;
- **Observation:** useful fact with no required remediation.

## 14. Evaluation and result contract

Score each objective as `Pass`, `Partial`, `Fail` or `Not tested`. Scores aid
review; they never override a Blocker.

| Objective | Evidence | Result | Finding refs |
|---|---|---|---|
| canonical incident/severity declaration | §13 timeline/history | Not tested | — |
| independent privacy-risk path and clock | §13 history/decision record | Not tested | — |
| safe containment and evidence preservation | §13 timeline | Not tested | — |
| Booking authority/reconciliation preserved | §13 decisions | Not tested | — |
| verified communications | message drafts/decisions | Not tested | — |
| recovery/closure criteria applied | §13 timeline/findings | Not tested | — |
| missing runtime controls converted to actions | findings register | Not tested | — |

Result rules:

- **Passed:** every objective Pass, no Blocker/Major remains open;
- **Passed with non-blocking actions:** every objective Pass, no Blocker, only
  owned Minor/Observation actions remain;
- **Not passed:** any Blocker, any Fail/Not tested mandatory objective, missing
  record, or unsupported/fabricated evidence;
- **Retest required:** every Blocker/Major must have an owner/date and be
  exercised again against the affected checkpoint.

This tabletop may satisfy only the documentation-exercise part of the incident
decision gates. It cannot satisfy executable alert routing, IAM, backup,
restore, notification or production-readiness evidence.

## 15. Execution record — intentionally blank

```text
Exercise ID/instance:
Scenario and package version: Scenario A / BCK04-OD09-TTX-01 v0.1
Scheduled start and IANA zone:
Actual start/end UTC:
Facilitator:
Evaluator/Scribe:
Participants and actual roles:
Combined-role/independence disclosure:
Legal/Privacy qualification evidence or explicit absence:
Record/evidence location:
Objectives tested:
Result: no result until evaluation is complete
Blocker findings:
Major findings:
Minor findings:
Remediation owners/dates:
Retest scope/date:
Security owner verdict/signature/date:
Operations owner verdict/signature/date:
Qualified Legal/Privacy verdict/signature/date where applicable:
```

No field may be prefilled as evidence from this Draft.

## 16. Post-exercise reconciliation

After actual execution:

1. preserve the completed record and finding evidence;
2. update this artifact status/result without rewriting the original timeline;
3. link remediation and retest evidence;
4. update BCK-04/BCK-05 matrices and D1 ledger atomically;
5. keep `BCK04-OD-09`/`BCK05-OD-08` Proposed if any required owner/Legal or
   tabletop gate remains incomplete;
6. never promote runtime readiness from a documentation exercise;
7. update LAUNCH_STATUS with exact evidence and remaining blockers.

## 17. Acceptance criteria

1. **BCK04-TTX-AC-01:** the package states that the exercise is not executed.
2. **BCK04-TTX-AC-02:** no participant, timestamp, result or signature is fabricated.
3. **BCK04-TTX-AC-03:** canonical severity remains SEV-1/2/3 only.
4. **BCK04-TTX-AC-04:** privacy risk remains independent from severity.
5. **BCK04-TTX-AC-05:** awareness time and notification path are exercised.
6. **BCK04-TTX-AC-06:** legal conclusions require qualified ownership.
7. **BCK04-TTX-AC-07:** missing Legal participation cannot be silently combined away.
8. **BCK04-TTX-AC-08:** combined-role and independence risks are recorded.
9. **BCK04-TTX-AC-09:** facilitator and Incident Commander are separate roles.
10. **BCK04-TTX-AC-10:** inject facts cannot be invented by participants.
11. **BCK04-TTX-AC-11:** unavailable runtime controls are recorded as gaps.
12. **BCK04-TTX-AC-12:** containment is named, reversible where possible and audited.
13. **BCK04-TTX-AC-13:** evidence preservation precedes destructive cleanup where safe.
14. **BCK04-TTX-AC-14:** evidence gaps remain explicit uncertainty.
15. **BCK04-TTX-AC-15:** severity downgrade requires evidence and authority.
16. **BCK04-TTX-AC-16:** Booking remains the only ledger/inventory writer.
17. **BCK04-TTX-AC-17:** direct database repair is a blocking failure.
18. **BCK04-TTX-AC-18:** projections recover after authority reconciliation.
19. **BCK04-TTX-AC-19:** communications contain only verified approved facts.
20. **BCK04-TTX-AC-20:** internal/user/regulator/public messages remain separate.
21. **BCK04-TTX-AC-21:** closure applies every incident-model condition.
22. **BCK04-TTX-AC-22:** alert silence alone cannot close the incident.
23. **BCK04-TTX-AC-23:** every Blocker/Major has owner, date and retest scope.
24. **BCK04-TTX-AC-24:** scoring cannot override a Blocker.
25. **BCK04-TTX-AC-25:** each scenario execution has a separate immutable record.
26. **BCK04-TTX-AC-26:** passing Scenario A does not claim B–D coverage.
27. **BCK04-TTX-AC-27:** a tabletop does not prove executable operations.
28. **BCK04-TTX-AC-28:** decision status changes require exact-version signatures.
29. **BCK04-TTX-AC-29:** post-exercise registry updates are atomic.
30. **BCK04-TTX-AC-30:** this package creates no code, cloud resource or production processing.
