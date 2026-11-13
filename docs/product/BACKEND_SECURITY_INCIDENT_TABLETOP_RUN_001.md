# Recharge Backend — Incident Tabletop Run 001

- Run ID: **BCK04-OD09-TTX-RUN-001**
- Package: [BCK04-OD09-TTX-01 v0.1](BACKEND_SECURITY_INCIDENT_TABLETOP_EXERCISE.md)
- Scenario: **A — privileged compromise, cross-user exposure and Booking risk**
- Started at: **2026-08-20T20:48:15Z**
- Exercise status: **Closed before T+00 response — not executed**
- Result status: **No result — no pass claimed**
- Runtime status: **N/A; documentation simulation only**
- Runtime effect: **none**

---

## 1. Participants and limitations

| Exercise role | Recorded participant | Evidence/limitation |
|---|---|---|
| Facilitator | Codex | Facilitates from the approved package; not Incident Commander or specialist signatory |
| Evaluator/Scribe | Codex | Combined facilitator/evaluator; independence absent and disclosed |
| Incident Commander | `RechargeN / Product owner` | Assigned for this interactive run from the existing combined-owner instruction; participant decision required at each checkpoint |
| Security Lead | `RechargeN / Product owner` | Combined role; no independent Security reviewer |
| Operations Lead | `RechargeN / Product owner` | Combined role; no executable backend/operations evidence exists |
| Booking Domain Lead | `RechargeN / Product owner` | Combined role; documentation authority only |
| Communications Lead | `RechargeN / Product owner` | Combined role; all messages remain simulated drafts |
| Privacy/Legal Lead | `RechargeN / Product owner` for coordination only | Qualification not evidenced; cannot supply a qualified legal conclusion |

Recorded limitations:

1. facilitator and evaluator are combined;
2. all participant authority roles are combined in one Product owner;
3. no independent Security, Operations or Booking participant is present;
4. qualified Legal/Privacy participation is absent;
5. `apps/backend`, alerts, IAM, data, credentials, deployments and recovery
   tooling are absent, so actions are documented proposals only;
6. the privacy/legal-path objective cannot pass without qualified evidence;
7. the run may identify useful gaps but cannot prove operational readiness.

## 2. Exercise controls

- Mode: interactive documentation tabletop in the Codex thread.
- No production systems, secrets, user data, regulator or public contact.
- Facilitator releases one inject at a time.
- Only the Product owner's actual replies are recorded as participant decisions.
- Missing reply or facilitator recommendation is not participant evidence.
- Expected-answer material remains in the package evaluator key and is not
  copied into the participant decision before response.
- Times below are exercise times; UTC records when the thread action occurred.

## 3. Timeline and inject record

| Exercise time | Recorded UTC | Event | Participant decision | State |
|---:|---|---|---|---|
| T+00 | 2026-08-20T20:48:15Z | Credible alert prepared but not answered; owner chose to continue documentation instead of running the exercise | No participant decision | Closed/not executed |

## 4. T+00 decision request

The Incident Commander must record:

1. whether an incident is declared and its incident ID;
2. initial operational severity: `SEV-1`, `SEV-2` or `SEV-3`;
3. initial privacy state: `notPersonalDataBreach`, `assessmentPending`,
   `unlikelyRisk`, `likelyRisk` or `highRisk`;
4. the first containment/evidence actions and their owners;
5. which roles are activated and when the next status update is due.

No choice was supplied. The run closed before this checkpoint, so no later
inject may be recorded as executed.

## 5. Current checkpoint state

| Checkpoint | State | Evidence |
|---|---|---|
| C1 — declaration | Not tested | run closed before response |
| C2 — authority | Not tested | participant roster was prepared, but no IC activation response exists |
| C3 — containment | Not tested | run closed before response |
| C4 — evidence | Not tested | run closed before response |
| C5 — Booking integrity | Not reached | later inject |
| C6 — privacy path | Not tested | initial privacy state pending; qualified role absent |
| C7 — communications | Not reached | later inject |
| C8 — recovery | Not reached | later inject |
| C9 — closure | Not reached | later inject |

## 6. Findings register

| Finding ID | Class | Description | Owner | Due/retest | State |
|---|---|---|---|---|---|
| TTX001-F01 | Blocker | Qualified Legal/Privacy participant absent; legal decision path cannot be validated | Product owner | assign qualified reviewer before decision acceptance | Open |
| TTX001-F02 | Major | Facilitator and evaluator are combined; independent exercise evaluation absent | Product owner | assign independent evaluator for retest | Open |
| TTX001-F03 | Major | Security, Operations, Booking and Communications roles are combined in one participant | Product owner | specialist/backup participation before production readiness | Open |
| TTX001-F04 | Observation | Runtime controls are absent by design at D1; simulated actions cannot be executed | Platform Operations | executable evidence only after an authorized runtime slice | Open |

## 7. Result record

```text
Result: No result
Reason: run closed before the T+00 participant response; documentation work resumed
Passed objectives: none claimed
Blocking findings: TTX001-F01
Major findings: TTX001-F02, TTX001-F03
Runtime readiness: not evaluated and not implied
Decision promotion: none
```
