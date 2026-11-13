# Viewer Profile retirement map

Status: **Reference map — non-normative**
Version: **1.1**
Date: **2026-10-10**
Verified stages: **PVR-01/03 transfer; PVR-01/07 retirement and restore**

Source root: C:/Users/User/.codex/worktrees/7275/Recharge.
HEAD: 8c69715bba03eb1cef7309d4496ebfddd6d11a1e; branch codex/recharge-integration.
Sources: Viewer v1.17 (Draft), Public Viewer v1.0 (Draft), archive 01 manifest.
Accepted ADR 0021 and explicit user acceptance of plan §6.1/§13 authorize UI
policy and this bounded docs transfer. They do not approve Draft full-release
rules or Open defaults. Source paths now contain retired compatibility pointers; immutable original bytes remain in archive 01.

This map is routing/provenance only: no new domain rules, aggregate, decisions
or maturity. CP original §§0–23 and transferred VP sections are distinct
namespaces; PVP sections are separate from original public-card sections.
Every retained ID has one canonical declaration in Creator common part.
Original declarations remain in the immutable archive; table mentions are references.
No VP-D/VP-AC renumbering or alias with a different meaning is introduced.

## Section routing — Viewer v1.17

Source §0 authority is integrated into Creator §0/VP §0 and index current
registry. Source §0.3 and Appendix B are history, not active requirements.
VP §0.2 is retained as a dated source snapshot; current runtime evidence is
in stage 00 and LAUNCH_STATUS, not inferred from this transfer.

| Source section / title | Original maturity | Destination / anchor | Treatment / conflict | Owning aggregate / concern | Verified |
|---|---|---|---|---|---|
| VP v1.17 §0 — Document authority and purpose | Draft; cited Approved/Accepted contracts unchanged | [VP §0](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-0) | Integrated under ADR 0021; single personal UI; existing gates / future DoD retained | Identity / original owning contracts | 03 |
| VP v1.17 §0.1 — Normative language | Draft; cited Approved/Accepted contracts unchanged | [VP §0.1](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-0-1) | Transferred; bare § inside common part uses VP namespace | Identity / original owning contracts | 03 |
| VP v1.17 §0.2 — Current implementation boundary | Draft; cited Approved/Accepted contracts unchanged | [VP §0.2](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-0-2) | Dated source boundary only; no new runtime claim | Identity / original owning contracts | 03 |
| VP v1.17 §0.3 — Why this document was resynced with the sibling documents | Draft; cited Approved/Accepted contracts unchanged | [archive source](../../archive/viewer-profile/2026-10-10/README.md) | Historical resync rationale retained in archive; no active rule retired | Identity / original owning contracts | 03 |
| VP v1.17 §1 — Product definition | Draft; cited Approved/Accepted contracts unchanged | [VP §1](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-1) | Integrated under ADR 0021; single personal UI; existing gates / future DoD retained | Identity / profile projections | 03 |
| VP v1.17 §1.1 — Four surfaces of one account | Draft; cited Approved/Accepted contracts unchanged | [VP §1.1](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-1-1) | Transferred; bare § inside common part uses VP namespace | Identity / profile projections | 03 |
| VP v1.17 §2 — Full-release extension policy | Draft; cited Approved/Accepted contracts unchanged | [VP §2](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-2) | Transferred; bare § inside common part uses VP namespace | originating Approved slice | 03 |
| VP v1.17 §3 — Canonical access model | Draft; cited Approved/Accepted contracts unchanged | [VP §3](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-3) | Transferred; bare § inside common part uses VP namespace | Identity / access snapshot | 03 |
| VP v1.17 §3.1 — Access states | Draft; cited Approved/Accepted contracts unchanged | [VP §3.1](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-3-1) | Integrated under ADR 0021; single personal UI; existing gates / future DoD retained | Identity / access snapshot | 03 |
| VP v1.17 §3.2 — Personal workspace, restated | Draft; cited Approved/Accepted contracts unchanged | [VP §3.2](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-3-2) | Transferred; bare § inside common part uses VP namespace | Identity / access snapshot | 03 |
| VP v1.17 §3.3 — No membership, no capability gate to open | Draft; cited Approved/Accepted contracts unchanged | [VP §3.3](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-3-3) | Transferred; bare § inside common part uses VP namespace | Identity / access snapshot | 03 |
| VP v1.17 §4 — Domain contracts and invariants | Draft; cited Approved/Accepted contracts unchanged | [VP §4](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-4) | Transferred; bare § inside common part uses VP namespace | UserProfile / owning libraries | 03 |
| VP v1.17 §4.1 — Accepted core entity | Draft; cited Approved/Accepted contracts unchanged | [VP §4.1](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-4-1) | Transferred; bare § inside common part uses VP namespace | UserProfile / owning libraries | 03 |
| VP v1.17 §4.2 — Personal library projections | Draft; cited Approved/Accepted contracts unchanged | [VP §4.2](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-4-2) | Transferred; bare § inside common part uses VP namespace | UserProfile / owning libraries | 03 |
| VP v1.17 §4.3 — Invariants | Draft; cited Approved/Accepted contracts unchanged | [VP §4.3](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-4-3) | Transferred; bare § inside common part uses VP namespace | UserProfile / owning libraries | 03 |
| VP v1.17 §5 — My planning — Scenario and Quick Plan | Draft; cited Approved/Accepted contracts unchanged | [VP §5](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-5) | Transferred; bare § inside common part uses VP namespace | Scenario; Quick Plan contract ownership Open VP-D02 | 03 |
| VP v1.17 §5.1 — Why they are not one library — and their two different collaboration states | Draft; cited Approved/Accepted contracts unchanged | [VP §5.1](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-5-1) | Transferred; bare § inside common part uses VP namespace | Scenario; Quick Plan contract ownership Open VP-D02 | 03 |
| VP v1.17 §5.2 — Scenario library — required lifecycle surface | Draft; cited Approved/Accepted contracts unchanged | [VP §5.2](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-5-2) | Transferred; bare § inside common part uses VP namespace | Scenario; Quick Plan contract ownership Open VP-D02 | 03 |
| VP v1.17 §5.3 — Quick Plan library — required lifecycle surface | Draft; cited Approved/Accepted contracts unchanged | [VP §5.3](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-5-3) | Transferred; bare § inside common part uses VP namespace | Scenario; Quick Plan contract ownership Open VP-D02 | 03 |
| VP v1.17 §5.4 — Required empty and error states | Draft; cited Approved/Accepted contracts unchanged | [VP §5.4](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-5-4) | Transferred; bare § inside common part uses VP namespace | Scenario; Quick Plan contract ownership Open VP-D02 | 03 |
| VP v1.17 §6 — My activity — Saved is several libraries, not one | Draft; cited Approved/Accepted contracts unchanged | [VP §6](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-6) | Transferred; bare § inside common part uses VP namespace | Favorites / SavedSearch / SmartSearchHistory | 03 |
| VP v1.17 §7 — Visit History | Draft; cited Approved/Accepted contracts unchanged | [VP §7](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-7) | Transferred; bare § inside common part uses VP namespace | VisitHistory (VIS-HIST-01) | 03 |
| VP v1.17 §8 — My participation | Draft; cited Approved/Accepted contracts unchanged | [VP §8](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-8) | Transferred; bare § inside common part uses VP namespace | Booking / admission / invitations | 03 |
| VP v1.17 §9 — Reviews — authored and received | Draft; cited Approved/Accepted contracts unchanged | [VP §9](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-9) | Transferred; bare § inside common part uses VP namespace | Review (future canonical contract) | 03 |
| VP v1.17 §10 — Photos | Draft; cited Approved/Accepted contracts unchanged | [VP §10](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-10) | Transferred; bare § inside common part uses VP namespace | Media / PhotoAsset; Open policy | 03 |
| VP v1.17 §11 — My publishing — boundary only | Draft; cited Approved/Accepted contracts unchanged | [VP §11](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-11) | Integrated under ADR 0021; single personal UI; existing gates / future DoD retained | Identity / content publishing | 03 |
| VP v1.17 §12 — Public projection and privacy | Draft; cited Approved/Accepted contracts unchanged | [VP §12](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-12) | Public rendering moved to baseline; existing fields/gates; VP decisions stay Creator | UserProfile / public rendering | 03 |
| VP v1.17 §12.1 — Visibility defaults — see sibling document §2 | Draft; cited Approved/Accepted contracts unchanged | [VP §12.1](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-2) | Public rendering moved to baseline; existing fields/gates; VP decisions stay Creator | UserProfile / public rendering | 03 |
| VP v1.17 §12.2 — Public User Projection — see sibling document §3 | Draft; cited Approved/Accepted contracts unchanged | [VP §12.2](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-3) | Public rendering moved to baseline; existing fields/gates; VP decisions stay Creator | UserProfile / public rendering | 03 |
| VP v1.17 §12.3 — Discoverability, blocking, deleted accounts — see sibling document §4 | Draft; cited Approved/Accepted contracts unchanged | [VP §12.3](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-4) | Public rendering moved to baseline; existing fields/gates; VP decisions stay Creator | UserProfile / public rendering | 03 |
| VP v1.17 §12.4 — Follow (proposed direction only) — see sibling document §5 | Draft; cited Approved/Accepted contracts unchanged | [VP §12.4](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-5) | Public rendering moved to baseline; existing fields/gates; VP decisions stay Creator | UserProfile / public rendering | 03 |
| VP v1.17 §13 — Product modules versus authorization capabilities | Draft; cited Approved/Accepted contracts unchanged | [VP §13](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-13) | Transferred; bare § inside common part uses VP namespace | Identity / owning action capabilities | 03 |
| VP v1.17 §14 — Information architecture | Draft; cited Approved/Accepted contracts unchanged | [VP §14](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-14) | Integrated under ADR 0021; single personal UI; existing gates / future DoD retained | personal presentation / Identity | 03 |
| VP v1.17 §15 — Account, session and multi-device states | Draft; cited Approved/Accepted contracts unchanged | [VP §15](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-15) | Transferred; bare § inside common part uses VP namespace | Identity account/session (target) | 03 |
| VP v1.17 §15.1 — `AccountStatus` — formal contract | Draft; cited Approved/Accepted contracts unchanged | [VP §15.1](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-15-1) | Transferred; bare § inside common part uses VP namespace | Identity account/session (target) | 03 |
| VP v1.17 §15.2 — Session and multi-device states | Draft; cited Approved/Accepted contracts unchanged | [VP §15.2](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-15-2) | Transferred; bare § inside common part uses VP namespace | Identity account/session (target) | 03 |
| VP v1.17 §16 — Notifications and settings | Draft; cited Approved/Accepted contracts unchanged | [VP §16](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-16) | Transferred; bare § inside common part uses VP namespace | Notifications / Settings / originating event | 03 |
| VP v1.17 §17 — Security, privacy, offline and operations | Draft; cited Approved/Accepted contracts unchanged | [VP §17](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-17) | Transferred; bare § inside common part uses VP namespace | Identity + target aggregate | 03 |
| VP v1.17 §18 — Required UX states | Draft; cited Approved/Accepted contracts unchanged | [VP §18](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-18) | Transferred; bare § inside common part uses VP namespace | owning library projection | 03 |
| VP v1.17 §19 — Delivery roadmap | Draft; cited Approved/Accepted contracts unchanged | [VP §19](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-19) | Transferred; bare § inside common part uses VP namespace | originating future slice | 03 |
| VP v1.17 §20 — Acceptance criteria | Draft; cited Approved/Accepted contracts unchanged | [VP §20](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-20) | Transferred; bare § inside common part uses VP namespace | owning criterion contracts | 03 |
| VP v1.17 §21 — Required test matrix | Draft; cited Approved/Accepted contracts unchanged | [VP §21](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-21) | Transferred; bare § inside common part uses VP namespace | owning implementation slice | 03 |
| VP v1.17 §22 — Decisions required before implementation | Draft; cited Approved/Accepted contracts unchanged | [VP §22](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-22) | Transferred; bare § inside common part uses VP namespace | individual VP decision, owner TBD | 03 |
| VP v1.17 §22.1 — Decision tracking | Draft; cited Approved/Accepted contracts unchanged | [VP §22.1](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-22-1) | Transferred; bare § inside common part uses VP namespace | individual VP decision, owner TBD | 03 |
| VP v1.17 §23 — Definition of Done | Draft; cited Approved/Accepted contracts unchanged | [VP §23](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-23) | Integrated under ADR 0021; single personal UI; existing gates / future DoD retained | Creator common personal delivery | 03 |
| VP v1.17 §24 — Viewer Profile lifecycle as a personal object | Draft; cited Approved/Accepted contracts unchanged | [VP §24](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-24) | Transferred; bare § inside common part uses VP namespace | owning aggregate / Identity account lifecycle | 03 |
| VP v1.17 §24.1 — Scenario and Quick Plan state transitions | Draft; cited Approved/Accepted contracts unchanged | [VP §24.1](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-24-1) | Transferred; bare § inside common part uses VP namespace | owning aggregate / Identity account lifecycle | 03 |
| VP v1.17 §24.2 — Visit History record lifecycle | Draft; cited Approved/Accepted contracts unchanged | [VP §24.2](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-24-2) | Transferred; bare § inside common part uses VP namespace | owning aggregate / Identity account lifecycle | 03 |
| VP v1.17 §24.3 — Concurrent editing | Draft; cited Approved/Accepted contracts unchanged | [VP §24.3](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-24-3) | Transferred; bare § inside common part uses VP namespace | owning aggregate / Identity account lifecycle | 03 |
| VP v1.17 §24.4 — Account deletion and retention | Draft; cited Approved/Accepted contracts unchanged | [VP §24.4](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-24-4) | Transferred; bare § inside common part uses VP namespace | owning aggregate / Identity account lifecycle | 03 |
| VP v1.17 §24.5 — Notification recipients and read state | Draft; cited Approved/Accepted contracts unchanged | [VP §24.5](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-24-5) | Transferred; bare § inside common part uses VP namespace | owning aggregate / Identity account lifecycle | 03 |
| VP v1.17 §24.6 — Follow relationship lifecycle | Draft; cited Approved/Accepted contracts unchanged | [VP §24.6](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-24-6) | Transferred; bare § inside common part uses VP namespace | owning aggregate / Identity account lifecycle | 03 |
| VP v1.17 §25 — Relationship to the sibling documents | Draft; cited Approved/Accepted contracts unchanged | [VP §25](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-25) | Integrated under ADR 0021; single personal UI; existing gates / future DoD retained | owning contracts / reference index | 03 |
| Appendix A | Non-normative exclusions index | [VP Appendix A](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-appendix-a) | Retained with originating rules, no new authority | Reference to owning contracts | 03 |
| Appendix B | Historical corrections | [archive](../../archive/viewer-profile/2026-10-10/README.md) | History retained only; not new rules | Historical evidence | 03 |

## Section routing — Public Viewer v1.0

| Source | Original maturity | Destination | Treatment / conflict | Owning concern | Verified |
|---|---|---|---|---|---|
| PVP v1.0 §0 — Document authority and purpose | Draft; Follow proposed | [PVP §0](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-0) | Audience framing integrated into public baseline; old separate-file pair framing replaced, no semantic rule removed | Creator VP-D / Identity account/session; Public Creator rendering | 03 |
| PVP v1.0 §0.1 — Normative language | Draft; Follow proposed | [PVP §0.1](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-0-1) | Transferred baseline; fields/visibility unchanged | Creator VP-D / Identity account/session; Public Creator rendering | 03 |
| PVP v1.0 §1 — Product definition | Draft; Follow proposed | [PVP §1](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-1) | Audience framing integrated into public baseline; old separate-file pair framing replaced, no semantic rule removed | Creator VP-D / Identity account/session; Public Creator rendering | 03 |
| PVP v1.0 §1.1 — Relationship to sibling documents | Draft; Follow proposed | [PVP §1.1](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-1) | Audience framing integrated into public baseline; old separate-file pair framing replaced, no semantic rule removed | Creator VP-D / Identity account/session; Public Creator rendering | 03 |
| PVP v1.0 §2 — Visibility defaults | Draft; Follow proposed | [PVP §2](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-2) | Transferred baseline; fields/visibility unchanged | Creator VP-D / Identity account/session; Public Creator rendering | 03 |
| PVP v1.0 §3 — Public User Projection | Draft; Follow proposed | [PVP §3](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-3) | Transferred baseline; fields/visibility unchanged | Creator VP-D / Identity account/session; Public Creator rendering | 03 |
| PVP v1.0 §4 — Discoverability, blocking, deleted accounts | Draft; Follow proposed | [PVP §4](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-4) | Transferred baseline; fields/visibility unchanged | Creator VP-D / Identity account/session; Public Creator rendering | 03 |
| PVP v1.0 §5 — Follow (proposed direction only — joint decision pending, `PP-D44`/`PCP-D02`) | Draft; Follow proposed | [PVP §5](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-5) | Proposed only; joint Follow shape conflict remains Open VP-D12/PP-D44/PCP-D02, FOL-01 | Joint Follow decision; ownership pending | 03 |
| PVP v1.0 §6 — What this projection never exposes | Draft; Follow proposed | [PVP §6](PUBLIC_CREATOR_PROFILE_FUNCTIONAL_SPEC.md#pvp-6) | Transferred baseline; fields/visibility unchanged | Creator VP-D / Identity account/session; Public Creator rendering | 03 |
| Revision History | Historical | [archive](../../archive/viewer-profile/2026-10-10/README.md) | Retained; not an active rule | Source evidence | 03 |

## Transferred decisions — all 16, no acceptance

The full original question, recommended/partial default and remaining questions
are copied into [Creator VP §22](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-22).
Status, owner TBD, target slice and gate below are the original §22.1 facts.
Owner roles are not invented here. Aggregate routing is a reference, not an
assignment of the Open Quick Plan / Follow contract ownership question.

| Source v1.17 §22 / ID / question | Status | Target slice | Owner | Gate / remaining conflict | Destination | Owning concern | Treatment / verified |
|---|---|---|---|---|---|---|---|
| VP-D01 — Scenario rename/copy/duplicate/archive/delete UX: exact | Open — default proposed | VP-01 | TBD | — | [VP-D01](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d01) | Scenario / profile UX | transferred; Open unchanged; 03 |
| VP-D02 — Quick Plan collaboration domain contract (Quick Plan only — | Open — partial default (2 of 9 sub-questions) | VP-02 | TBD | — | [VP-D02](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d02) | Quick Plan (contract owner Open) | transferred; Open unchanged; 03 |
| VP-D03 — Saved decomposition IA: whether the three Saved libraries | Open — default proposed | VP-03 | TBD | — | [VP-D03](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d03) | Saved library presentation | transferred; Open unchanged; 03 |
| VP-D04 — My participation source contract: exact read-projection | Open — blocked | VP-06 | TBD | ADR 0019 backend readiness | [VP-D04](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d04) | Booking backend / projection | transferred; Open unchanged; 03 |
| VP-D05 — Photos pipeline: authorship/license confirmation, per-photo | Open — default proposed | VP-08 | TBD | — | [VP-D05](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d05) | Media / Photos | transferred; Open unchanged; 03 |
| VP-D06 — Account deletion and retention (widened): exact retention | Open — partial default (window pending legal; other-aggregate retention not covered) | VP-09 | TBD | Legal/privacy sign-off; `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` CP-AC-19 | [VP-D06](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d06) | Identity + per-aggregate retention | transferred; Open unchanged; 03 |
| VP-D07 — Public User Projection remaining open questions (narrowed): | Open — default proposed | VP-10 | TBD | — | [VP-D07](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d07) | UserProfile / contextual projection | transferred; Open unchanged; 03 |
| VP-D08 — Reviews about a person: whether Recharge ever supports a | Open — no default (product/legal) | Not yet in roadmap | TBD | — | [VP-D08](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d08) | Review person-subject (unaccepted) | transferred; Open unchanged; 03 |
| VP-D09 — Multi-device conflict per library: exact precondition and | Open — default proposed | VP-13 | TBD | — | [VP-D09](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d09) | each owning library concurrency | transferred; Open unchanged; 03 |
| VP-D10 — Minors' baseline Public User Projection: this document's own | Open — no default (child-safety) | Not yet in roadmap | TBD | Distinct from `CREATOR_PROFILE_FUNCTIONAL_SPEC.md` CP-D14 | [VP-D10](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d10) | baseline minors / child-safety | transferred; Open unchanged; 03 |
| VP-D11 — Notification category ownership and dedup: the exact | Open — default proposed | VP-14 | TBD | — | [VP-D11](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d11) | Notifications / source event | transferred; Open unchanged; 03 |
| VP-D12 — this document's half of the joint Follow decision | Open — blocked | VP-17 | TBD | Joint resolution with `PP-D44` and `PCP-D02` required — see §12.4 | [VP-D12](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d12) | joint Follow foundation, FOL-01 | transferred; Open unchanged; 03 |
| VP-D13 — Saved Search / Smart Search history retention and cleanup | Open — default proposed | VP-18 | TBD | — | [VP-D13](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d13) | SavedSearch / SmartSearchHistory | transferred; Open unchanged; 03 |
| VP-D14 — Account data export and format (§16, `VP-D06`'s sibling): | Open — default proposed | VP-19 | TBD | Legal/privacy sign-off, shares `VP-D06`'s gate | [VP-D14](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d14) | Identity export + per-library allowlists | transferred; Open unchanged; 03 |
| VP-D15 — Session list, re-authentication and remote device revoke | Open — default proposed, security review required before use | VP-20 | TBD | Security review of re-authentication design | [VP-D15](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d15) | Identity / account-security recovery | transferred; Open unchanged; 03 |
| VP-D16 — Photos media safety (§10): malware/file-type/size/ | Open — default proposed | VP-21 | TBD | Shares `VP-08`'s media-pipeline dependency | [VP-D16](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-d16) | Media / quarantine / Photos | transferred; Open unchanged; 03 |

## Transferred acceptance criteria — all 43

Each criterion retains its complete text in VP §20. Draft is criterion
maturity, not implementation evidence. Criteria concerning approved aggregate
behavior cite that aggregate; future/conditional criteria remain deferred.
PVR-01 verifies transfer completeness only, not those future runtime tests.

| Source v1.17 §20 / ID / criterion opening | Maturity / dependency | Destination | Treatment / conflict | Owning concern | Verified |
|---|---|---|---|---|---|
| VP-AC-01 — Opening Personal Profile never creates or implies a Public | Draft criterion; owning contract maturity unchanged | [VP-AC-01](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-01) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-02 — No action defined in §5–§10 requires Creator verification or | Draft criterion; owning contract maturity unchanged | [VP-AC-02](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-02) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-03 — Scenario and Quick Plan remain two libraries with two empty | Draft criterion; owning contract maturity unchanged | [VP-AC-03](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-03) | transferred; no renumber / implementation claim | Scenario | 03 |
| VP-AC-04 — Favorites, Saved Searches, Smart Search history, personal | Draft criterion; owning contract maturity unchanged | [VP-AC-04](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-04) | transferred; no renumber / implementation claim | originating criterion / slice | 03 |
| VP-AC-05 — An empty Scenario library shows a `Create Scenario` entry | Draft criterion; owning contract maturity unchanged | [VP-AC-05](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-05) | transferred; no renumber / implementation claim | Scenario | 03 |
| VP-AC-06 — All four `accessRole` values render in visibly distinct | Draft criterion; owning contract maturity unchanged | [VP-AC-06](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-06) | transferred; no renumber / implementation claim | Scenario | 03 |
| VP-AC-07 — `Expand to Scenario` creates a new Scenario ID; the source | Draft criterion; owning contract maturity unchanged | [VP-AC-07](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-07) | transferred; no renumber / implementation claim | Scenario | 03 |
| VP-AC-08 — A stale/corrupt/revision-conflict Scenario shows an explicit | Draft criterion; owning contract maturity unchanged | [VP-AC-08](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-08) | transferred; no renumber / implementation claim | Scenario | 03 |
| VP-AC-09 — A Visit History record is created only via explicit | Draft criterion; owning contract maturity unchanged | [VP-AC-09](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-09) | transferred; no renumber / implementation claim | VisitHistory | 03 |
| VP-AC-10 — The same Place can carry multiple Visit History records on | Draft criterion; owning contract maturity unchanged | [VP-AC-10](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-10) | transferred; no renumber / implementation claim | VisitHistory | 03 |
| VP-AC-11 — My participation renders each state family from its own | Draft criterion; owning contract maturity unchanged | [VP-AC-11](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-11) | transferred; no renumber / implementation claim | originating criterion / slice | 03 |
| VP-AC-12 — Public User Projection contains at most display name, | Draft baseline privacy criterion; no new exposure | [VP-AC-12](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-12) | transferred; no renumber / implementation claim | public projection / privacy | 03 |
| VP-AC-13 — A Viewer who never verifies as Creator does not appear as a | Draft baseline privacy criterion; no new exposure | [VP-AC-13](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-13) | transferred; no renumber / implementation claim | public projection / privacy | 03 |
| VP-AC-14 — A deleted/tombstoned account's projection returns the same | Draft baseline privacy criterion; no new exposure | [VP-AC-14](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-14) | transferred; no renumber / implementation claim | public projection / privacy | 03 |
| VP-AC-15 — Mute on a Viewer changes only the muting account's own view | Draft baseline privacy criterion; no new exposure | [VP-AC-15](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-15) | transferred; no renumber / implementation claim | public projection / privacy | 03 |
| VP-AC-16 — A failed or partial load of one personal library does not | Draft criterion; owning contract maturity unchanged | [VP-AC-16](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-16) | transferred; no renumber / implementation claim | originating criterion / slice | 03 |
| VP-AC-17 — A partial-load failure is never presented as an honest empty | Draft criterion; owning contract maturity unchanged | [VP-AC-17](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-17) | transferred; no renumber / implementation claim | originating criterion / slice | 03 |
| VP-AC-18 — Switching accounts on one device fully re-scopes every | Draft criterion; owning contract maturity unchanged | [VP-AC-18](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-18) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-19 — An expired session mid-edit fails closed on the next | Draft criterion; owning contract maturity unchanged | [VP-AC-19](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-19) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-20 — `LAUNCH_STATUS.md` records exact implementation evidence and | Draft criterion; owning contract maturity unchanged | [VP-AC-20](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-20) | transferred; no renumber / implementation claim | originating criterion / slice | 03 |
| VP-AC-21 — `AccountStatus` has exactly five values | Draft Identity/account target; VP-D15 security review remains required | [VP-AC-21](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-21) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-22 — A deep link into a §5–§10 item resolves via the full | Draft criterion; owning contract maturity unchanged | [VP-AC-22](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-22) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-23 — A notification event never produces two inbox entries across | Draft criterion; owning contract maturity unchanged | [VP-AC-23](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-23) | transferred; no renumber / implementation claim | originating criterion / slice | 03 |
| VP-AC-24 — `securityLocked`, `suspended` and `deletionPending` block | Draft Identity/account target; VP-D15 security review remains required | [VP-AC-24](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-24) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-25 — en/ru/lv-ready labels, 360 dp and 150% text scale are | Draft criterion; owning contract maturity unchanged | [VP-AC-25](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-25) | transferred; no renumber / implementation claim | originating criterion / slice | 03 |
| VP-AC-26 — Unit, widget and integration tests are proportional to each | Draft criterion; owning contract maturity unchanged | [VP-AC-26](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-26) | transferred; no renumber / implementation claim | originating criterion / slice | 03 |
| VP-AC-27 — `flutter analyze`, `flutter test`, boundary and diff checks | Draft criterion; owning contract maturity unchanged | [VP-AC-27](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-27) | transferred; no renumber / implementation claim | originating criterion / slice | 03 |
| VP-AC-28 — Follow does not ship in any form — production or local/mock | Draft conditional Follow criterion; joint VP-D12/PP-D44/PCP-D02 pending | [VP-AC-28](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-28) | transferred; no renumber / implementation claim | joint Follow (pending) | 03 |
| VP-AC-29 — *If* the joint decision adopts a Follow model, it is | Draft conditional Follow criterion; joint VP-D12/PP-D44/PCP-D02 pending | [VP-AC-29](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-29) | transferred; no renumber / implementation claim | joint Follow (pending) | 03 |
| VP-AC-30 — *If* Follow ships, a Block immediately removes any existing | Draft conditional Follow criterion; joint VP-D12/PP-D44/PCP-D02 pending | [VP-AC-30](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-30) | transferred; no renumber / implementation claim | joint Follow (pending) | 03 |
| VP-AC-31 — *If* Follow ships, it is reachable only via an existing | Draft conditional Follow criterion; joint VP-D12/PP-D44/PCP-D02 pending | [VP-AC-31](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-31) | transferred; no renumber / implementation claim | joint Follow (pending) | 03 |
| VP-AC-32 — *If* Follow ships, a `tombstoned` account loses all | Draft conditional Follow criterion; joint VP-D12/PP-D44/PCP-D02 pending | [VP-AC-32](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-32) | transferred; no renumber / implementation claim | joint Follow (pending) | 03 |
| VP-AC-33 — Closing an already-existing My participation obligation | Draft Identity/account target; VP-D15 security review remains required | [VP-AC-33](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-33) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-34 — A security or moderation signal arriving while | Draft Identity/account target; VP-D15 security review remains required | [VP-AC-34](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-34) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-35 — A restored (`tombstoned -> active`) account always resumes | Draft Identity/account target; VP-D15 security review remains required | [VP-AC-35](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-35) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-36 — `securityLocked -> deletionPending` requires its own fresh | Draft Identity/account target; VP-D15 security review remains required | [VP-AC-36](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-36) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-37 — A `StepUpGrant` authorizes exactly one `sessionId` for | Draft Identity/account target; VP-D15 security review remains required | [VP-AC-37](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-37) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-38 — `securityLocked -> active` (self-service unlock) revokes | Draft Identity/account target; VP-D15 security review remains required | [VP-AC-38](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-38) | transferred; no renumber / implementation claim | Identity / session + owning aggregate | 03 |
| VP-AC-39 — A slice MAY begin *preparing its own bounded slice spec* | Draft; bounded spec preparation only, defaults remain Open | [VP-AC-39](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-39) | transferred; no renumber / implementation claim | originating criterion / slice | 03 |
| VP-AC-40 — `private -> unlisted` on an owned Scenario requires only | Draft criterion; owning contract maturity unchanged | [VP-AC-40](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-40) | transferred; no renumber / implementation claim | Scenario | 03 |
| VP-AC-41 — No planning action this document defines — create, edit, | Draft criterion; owning contract maturity unchanged | [VP-AC-41](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-41) | transferred; no renumber / implementation claim | Scenario | 03 |
| VP-AC-42 — Inviting a known person into an owned Scenario/Quick Plan | Draft criterion; owning contract maturity unchanged | [VP-AC-42](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-42) | transferred; no renumber / implementation claim | originating criterion / slice | 03 |
| VP-AC-43 — For an account with an `IdentityFieldModerationOverlay` | Draft baseline privacy criterion; no new exposure | [VP-AC-43](CREATOR_PROFILE_FUNCTIONAL_SPEC.md#vp-ac-43) | transferred; no renumber / implementation claim | public projection / privacy | 03 |

## Known conflicts and preserved gates

- Old unconditional verified identity for all personal actions: corrected in
  Creator §3.1 / VP §3.1; active authenticated account opens unified Creator.
  Personal libraries retain owning eligibility/consent/revision/lifecycle rules.
- AccountStatus stays exactly active | securityLocked | suspended |
  deletionPending | tombstoned. CreatorVerification, public-card enforcement /
  review, IdentityFieldModerationOverlay and session-purpose StepUpGrant stay
  separate axes. Unlock revokes other sessions atomically; session A grants
  nothing to B. VP-D15 security review and human recovery remain Open; source
  exploit-path descriptions are target criteria, not verified implementation.
- Public Viewer §4/§6 prose named only suspended/securityLocked although
  VP §15.1's existing table also withdraws deletionPending. Baseline consumer
  prose now names all three, matching that unchanged Draft table and the
  existing Public Creator resolver; no new state or public field is introduced.
- VP-D02 only two proposed defaults; participant visibility, leave/revoke,
  owner deletion, rights, block, cap, audit and contract owner remain open.
- VP-D06 retention window is proposed subject to Legal/privacy; Review /
  Booking may retain independently. Sole owner of non-archived/non-tombstoned
  Page must satisfy Creator §22.4 / CP-AC-19 and page obligations before entry
  into deletionPending; transfer/archive path remains required.
- VP-D08 / VP-D10 remain product/legal/child-safety gates. VP-D14 export must
  allowlist fields per library; owner-scoped rows do not make embedded third-party
  data safe. No legal-hold/retention choice accepted here.
- VP-D12 person-only FollowRef and PP-D44 discriminated FollowRelation remain
  incompatible candidate shapes. VP/PCP/PP cannot accept unilaterally; FOL-01
  stays neutral and implementation gated. No local fixture presented as real.
- VP-D07 additional trigger/token questions remain Open; source VP §10's
  possible public-photo/public-Viewer-route wording does not authorize another
  Viewer page or extend the baseline. Photos public remains reserved/not settable.
- Baseline remains at most name/avatar/optional city; no contacts, security,
  personal libraries or searchable identity added. Existing overlay-row reads
  lastApprovedPublicValue; no-row reads UserProfile. CP-D18/CP-D19 mechanics
  remain Open; this routing pass does not resolve older CP-D20 tracking drift.
- Old six-document framing/owner citations remain only in visibly dated history
  or unchanged source records; current owners are four active specs. Historical
  decision package remains non-normative v1.4; only routing note added.

## Consumers and rollback

AGENTS / VISION / Approved Identity slice contain the ADR 0021 UI policy;
Approved Identity access / workspace / publisher authority remains unchanged.
Creator / Public Creator / Page / Public Page active references route to the
new sections; old review narratives and version pins are historical evidence.
Index §0–§1 contains current owners, with its previous audit explicitly historical.

Rollback: reverse this stage's bounded document diff as one coherent reference
set. Original Viewer source bytes remain intact in archive 01; do not replace shared
files with an old complete archive copy or discard unrelated WIP. Stage 07 pointers do not change runtime/data or close stage 06 regression gates.


## Stage 07 retirement verification

Both old spec paths are compatibility pointers. Exact destination anchors above
remain canonical; all 16 VP-D and 43 VP-AC declarations stay in Creator common
part, with Draft/Open maturity unchanged. Live consumer references were already
rewired by 03; remaining old names in visibly dated review/history and prepared
handoffs are provenance, not current ownership. Stage 06 remains not_ready.
