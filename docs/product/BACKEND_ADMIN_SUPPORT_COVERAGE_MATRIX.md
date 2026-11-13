# BCK-19 — Admin & Support Backend Coverage Matrix

- ID: **BCK-19-PRE**
- Version: **0.2**
- Date: **2026-08-26**
- Status: **Review — coverage and reconciliation evidence**
- Runtime status: **N/A; no Admin/Support backend or privileged access**
- Accountable owner: **Admin Operations owner**
- Target: [BCK-19 v0.2](ADMIN_SUPPORT_BACKEND_SPEC.md)
- Coordination baseline: [BCK-02 v2.4.39](RECHARGE_BACKEND_DELIVERY_MAP.md)
- Canonical path: `docs/product/BACKEND_ADMIN_SUPPORT_COVERAGE_MATRIX.md`

## 0. Changelog

### v0.2 — 2026-08-26

- reconciled the repository audit with BCK-19 v0.2 Review;
- verified 22/22 mandatory design categories, 60 target AC and ten explicit
  BCK19 owner decisions;
- separated tool/case/repair workflow from Identity/IAM, domain, Privacy,
  Trust & Safety, Notifications and Platform authority;
- kept staff access, Firebase, repair commands, RUN-03 and runtime absent.

### v0.1 — 2026-08-26

- inventoried canonical API, Security/Privacy, Operations/IAM, Identity,
  Notifications and current local Admin/moderation inputs;
- recorded implementation gaps, fail-closed defaults and 24 preparatory AC.

## 1. Verdict

BCK-19 v0.2 is suitable for **Review as a documentation-only target**. It
defines one Admin Operations authority for cases, case-scoped privileged reads,
read audit and repair orchestration while preserving every owning-domain writer.

Runtime remains **Absent**. Local Admin preview and Route moderation are not
staff authority. No dedicated production identity, Admin backend, repair
registry/command, immutable audit store, Firebase resource, production access or
RUN-03 execution exists or is authorized.

## 2. Sources and status

| Source | Status used here | BCK-19 treatment |
|---|---|---|
| BCK-01 v0.4.34 | Review | Parent single-writer/admin-repair baseline |
| BCK-02 v2.4.38 | Approved coordination | Owner, scope, D3/R6/G5 and RUN-03 direction |
| BCK-03 v0.3.3 | Draft | Registered commands/errors/split keys; non-Booking schemas gated |
| BCK-04 v0.4.16 | Draft | Privileged identity/read audit/privacy baseline; exact policy unresolved |
| BCK-05 v0.2.23 | Draft | Flags/incident/operations/recovery; product runtime absent |
| IAM model v0.2.1 | Accepted policy input; runtime absent | JIT/no blanket impersonation/break-glass controls |
| BCK-06 v0.2 | Review | Staff principal/capability/session/domain review input |
| BCK-13 v0.2 | Review | Post-commit notification handoff; runtime absent |
| BCK-18 v0.2 | Review | Typed client seam; no direct Firestore authority |
| BCK-22 | Planned | T&S ownership is reserved, not silently implemented here |
| Current mobile runtime | Local mock Admin preview and Route queues | UX/debt evidence only |

## 3. Current implementation inventory

| Area | Present | Gap to target |
|---|---|---|
| Admin identity | Mock Auth/Identity capabilities and `admin.experience.preview` | No dedicated privileged identity, MFA/JIT/roster/tool context |
| Admin workspace | Presentation-only Viewer/Creator/Page preview | Not a principal, workspace, publisher or grant |
| Route moderation | Local/in-memory requests and decisions | No server authority, immutable audit, separation or cross-device state |
| Route quality/safety | Local controller and safety report decisions | T&S/domain boundary unresolved; not BCK-19 authority |
| Moderator notification | Local `__moderators__` inbox | Not a case queue, staff assignment or production notification |
| Support cases | No canonical backend model found | No intake, assignment, transcript, access scope or retention |
| Repair | No registered production repair command/registry | No simulation, proposal, approval, execution or reconciliation |
| Backend scaffold | R0 non-product toolchain only | No product handlers, repositories, IAM or resources |
| Boundary gate | 380 Dart files, 71 exact suppressions, zero violations | Budget full; docs add no suppression |

## 4. Mandatory BCK-02 coverage

| # | Requirement | BCK-19 evidence | Coverage/gap |
|---:|---|---|---|
| 1 | Header/status/owner | Header and §1 | Full; Review/runtime Absent explicit |
| 2 | Parents/priority | §2 | Full; dependency statuses qualified |
| 3 | Outcome/non-goals | §3 | Full |
| 4 | Scope/disabled surfaces | §4 | Full |
| 5 | Ownership/principals | §5–6 | Full; no superuser/cross-domain writer |
| 6 | Data/state model | §7 | Full design; schemas absent |
| 7 | Commands/queries | §8–9 | Full semantic inventory; runtime absent |
| 8 | Authorization/access | §10 | Full; exact JIT/read policy decisions open |
| 9 | Repair lifecycle | §11 | Full; domain commands/RUN-03 absent |
| 10 | Emergency/break-glass | §12 | Full boundary; executable evidence absent |
| 11 | Cross-domain/events/errors | §13–14 | Full design; BCK-22/OD-09 runtime gated |
| 12 | Version/evolution | §15 | Full; schema workflow decision open |
| 13 | Persistence/transactions | §16 | Full logical split; physical layout absent |
| 14 | IDs/time/idempotency | §17 | Full |
| 15 | Notes/evidence/media | §18 | Full fail-closed profile |
| 16 | Privacy/retention/DSR | §19 | Full target; exact Legal policy absent |
| 17 | Security/abuse | §20 | Full target; staff/device/runtime evidence absent |
| 18 | Observability/SLO/cost | §21 | Full dimensions; numeric decisions absent |
| 19 | Flags/rollout/rollback | §22 | Full staged model; no runtime authority |
| 20 | Migration/compatibility | §23 | Full; mock/local authority excluded |
| 21 | Gates/files/tests/DoR/DoD | §24–28 | Full conditional delivery plan |
| 22 | AC/unimplemented/decisions | §29–31 | 60 AC, ten decisions, absence explicit |

**Coverage verdict:** 22/22 addressed at Review design level. This is not an
Approval, staff-access, repair-readiness, G5, RUN-03 or production verdict.

## 5. Single-writer reconciliation

| Concern | Writer | BCK-19 handoff | Forbidden ambiguity removed |
|---|---|---|---|
| Staff account/session/capability | BCK-06 + BCK-05 IAM | Current access decision/receipt | Mock Admin/role is not authority |
| Case/assignment/access scope | BCK-19 | Tool-owned workflow | Not a user workspace or domain record |
| Privileged read audit | BCK-19/audit service | Opaque resource/field-mask outcome | No raw content in audit |
| Domain repair | Owning domain | Approved typed command + receipt | No direct collection edit |
| Privacy request | BCK-04 | Verified directive/reference | No duplicate DSR authority |
| Reports/sanctions/appeals | BCK-22 | Linked case/navigation only | Support cannot moderate by convenience |
| Flags/break-glass | BCK-05 | Typed incident/action handoff | Admin UI cannot grant IAM |
| Notifications | BCK-13 | Post-commit minimized intent | No inline email/push |
| Analytics | BCK-21 | Approved events only | Audit is not analytics |

## 6. Gap register

| Gap | Why material | Resolution/blocker |
|---|---|---|
| Contracts/registry absent | Tool/domain shapes could drift or bypass invariants | BCK19-OD-01 |
| Staff/JIT/tool policy incomplete | Consumer/mock role could be mistaken for privilege | BCK19-OD-02 |
| Case model absent | No ownership, assignment, transcript or retention truth | BCK19-OD-03 |
| Privileged reveal policy absent | PII enumeration/exfiltration risk | BCK19-OD-04 |
| Risk/dual-control matrix absent | Self-approved or under-controlled repair risk | BCK19-OD-05 |
| Domain repair commands absent | Proposal cannot safely execute | BCK19-OD-06 |
| Emergency boundary not executable | Routine Support could misuse break-glass | BCK19-OD-07 |
| Retention/transparency unresolved | Support notes/audit may violate purpose/rights | BCK19-OD-08 |
| Local Admin/moderation migration unresolved | Demo decisions could become production truth | BCK19-OD-09 |
| Numeric evidence absent | No honest SLO, scale, batch or staffing claim | BCK19-OD-10 |
| BCK-22 absent | Moderation/enforcement staff surface cannot be enabled | BCK-22 Approval/runtime |
| RUN-03 absent by design | Persistent stage cannot prove repair operations | Implement commands, then build/drill RUN-03 |

## 7. Open owner decisions

| ID | Decision/evidence | Owners | Blocks | Fail-closed result |
|---|---|---|---|---|
| BCK19-OD-01 | API/schema/codegen, case/repair registry and fixtures | Admin Ops + API + domains | Any adapter/runtime | No remote tool |
| BCK19-OD-02 | Staff identity, MFA/JIT/tool session/device/roster | Security + Identity + Operations | Production access | No staff access |
| BCK19-OD-03 | Case taxonomy/severity/assignment/status/transcript | Support + Admin Ops + Product | Case runtime | Synthetic only |
| BCK19-OD-04 | Lookup/reveal masks/purpose/view-as/disclosure/export | Privacy/Legal + Security + Support | Protected read | Disabled |
| BCK19-OD-05 | Repair risk/approver/separation/expiry matrix | Security + Admin Ops + domains | Approval/execution | High-risk disabled |
| BCK19-OD-06 | Domain repair registry/simulation/batch/receipt/rollback | Domains + Admin Ops + API | State repair | Disabled |
| BCK19-OD-07 | Emergency tool actions and break-glass boundary | Operations + Security + Admin Ops | Emergency action | Disabled |
| BCK19-OD-08 | Retention/DSR/hold/transparency for all Admin families | Privacy/Legal + Support + Security | Personal data | Disabled |
| BCK19-OD-09 | Local Admin/moderation compatibility/cutover/rollback | Mobile + Content/Route + T&S + Admin Ops | Migration | No import |
| BCK19-OD-10 | Numeric response/access/approval/SLO/rate/batch/cost | Operations + Support + Security + Product | Scale/production | No scale claim |

## 8. Fail-closed defaults

- no production staff access, data reveal, export or arbitrary search;
- no user-session/publisher/workspace impersonation;
- no direct Firestore/Storage/domain write;
- no repair execution without simulation, frozen proposal and required approval;
- no weakening of dual control when qualified staff are unavailable;
- no BCK-22 moderation or payment action through Admin convenience;
- no attachments before protected Media family policy;
- no import of mock Admin grants, local decisions or moderator inbox;
- no persistent staging before implemented commands, G5 and RUN-03 drill;
- unknown policy/contract/access/outcome fails closed and is reconciled.

## 9. Preparatory acceptance criteria

1. **BCK-19-PRE-AC-01:** Target, Review status and runtime absence are explicit.
2. **BCK-19-PRE-AC-02:** All 22 mandatory categories are mapped.
3. **BCK-19-PRE-AC-03:** BCK-19 owns workflow records, not domain truth.
4. **BCK-19-PRE-AC-04:** Owning domains execute every state-changing repair.
5. **BCK-19-PRE-AC-05:** BCK-22 remains T&S authority.
6. **BCK-19-PRE-AC-06:** BCK-04 remains PrivacyRequest authority.
7. **BCK-19-PRE-AC-07:** BCK-05/IAM remains flag/break-glass authority.
8. **BCK-19-PRE-AC-08:** Admin role/mock preview is not privilege.
9. **BCK-19-PRE-AC-09:** Dedicated identity/MFA/case/purpose/audit are mandatory.
10. **BCK-19-PRE-AC-10:** Privileged reads use a field mask and read audit.
11. **BCK-19-PRE-AC-11:** Arbitrary query/export/direct data edit is forbidden.
12. **BCK-19-PRE-AC-12:** Proposal uses registered command and immutable hash.
13. **BCK-19-PRE-AC-13:** Simulation is non-mutating and revision-pinned.
14. **BCK-19-PRE-AC-14:** Required proposer/approver separation is explicit.
15. **BCK-19-PRE-AC-15:** Unknown outcome reconciles before retry.
16. **BCK-19-PRE-AC-16:** RUN-03 follows actual commands and remains absent.
17. **BCK-19-PRE-AC-17:** Local Admin/moderation decisions are not imported.
18. **BCK-19-PRE-AC-18:** Notes/evidence are minimized and classified.
19. **BCK-19-PRE-AC-19:** Retention/DSR applies per record family/purpose.
20. **BCK-19-PRE-AC-20:** No new boundary suppression is added.
21. **BCK-19-PRE-AC-21:** Documentation checks are not runtime/access evidence.
22. **BCK-19-PRE-AC-22:** Future files/resources remain conditional.
23. **BCK-19-PRE-AC-23:** G5/persistent staging remains separately gated.
24. **BCK-19-PRE-AC-24:** Firebase, staff access, runtime and `main` remain untouched.

## 10. Evidence summary

- target coverage: **22/22**;
- target acceptance criteria: **60/60 sequential**;
- preparatory criteria: **24/24 sequential**;
- explicit owner decisions: **10**;
- current implementation classification: **local/mock UX only**;
- Admin/Support backend and production privileged access: **Absent**;
- executable authority from this package: **none**.

## 11. Recommendation

Move BCK-19 v0.2 and BCK-19-PRE v0.2 to cross-owner Review together. Do not
promote to Approved until all ten decisions, dependency compatibility, domain
repair registry and qualified owner evidence exist. Do not start persistent
staging or write RUN-03 as “verified” until real commands are implemented and
the runbook has been executed successfully.
