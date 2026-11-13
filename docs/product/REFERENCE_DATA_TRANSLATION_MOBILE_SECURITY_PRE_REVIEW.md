# BCK-20 — Translation Governance Mobile/Security Technical Pre-Review

- ID: **BCK20-OD02-MS-PRE-01**
- Version: **0.2**
- Date: **2026-09-17**
- Status: **Owner decision recorded — MS-F-001–MS-F-007 integrated in workflow v0.4**
- Frozen target: [BCK20-OD02-L10N-01 v0.3](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Target normalized-LF SHA-256: `f244b00bbd320de53e3edf8f076f5caa3fd09a962df37d079563d7cf25614309`
- Accepted v0.1 normalized-LF SHA-256: `e3edbf1c1ba495bca73c5c8ac3f5d40ac7dd77b574cd24f2047bcdfe8775651d`
- Owner decision: [BCK20-OD02-MS-PRE-DEC-01 v0.1](REFERENCE_DATA_TRANSLATION_MOBILE_SECURITY_PRE_REVIEW_DECISION.md)
- Integrated target: [BCK20-OD02-L10N-01 v0.4](REFERENCE_DATA_TRANSLATION_GOVERNANCE_WORKFLOW.md)
- Integrated target normalized-LF SHA-256: `d7cad4f1531005b02ee7c46028af03839be58985cd3285750084daa8293d6975`
- Parent: [BCK-20 v0.2.13](REFERENCE_DATA_LOCALIZATION_SPEC.md)
- Mobile baseline: [BCK-18 v0.5](MOBILE_BACKEND_INTEGRATION_STANDARD.md)
- Security/Privacy baseline: [BCK-04](BACKEND_SECURITY_PRIVACY_SPEC.md)
- Technical evidence author: **OpenAI Codex — analysis only, not a signatory**
- Human owner: **RechargeN / Product owner**
- Independence: **none; combined-owner technical process**
- Legal/Privacy qualification: **not claimed**
- Runtime effect: **none**

## 1. Outcome

The workflow has a coherent product/content governance core, but the exact v0.3
revision is not yet ready for Mobile and Security/Privacy owner review. Seven
cross-boundary gaps remain between an approved translation and a safely
consumable mobile artifact. They do not justify runtime work; they require a
documentation-only v0.4 correction first.

Recommended disposition:

> **Integrate MS-F-001–MS-F-007 as documentation-only technical corrections,
> append new acceptance criteria without renumbering AC-01–50, recompute the
> frozen hash, and only then prepare two separate Mobile and Security/Privacy
> owner verdicts.**

This pre-review is not either verdict. `BCK20-OD02-SIG-MOBILE` and
`BCK20-OD02-SIG-SEC` remain Pending. `BCK20-OD-02` remains Open, `OD-10`
remains Proposed, `BCK-20` remains Draft and `BCK20-OD-03` remains Deferred.

## 2. Review boundary and method

The review compares the frozen workflow against:

- BCK-18 read-state, version, cache, offline, tombstone, telemetry and binding
  rules;
- BCK-04 trust-boundary, data-inventory, least-privilege, audit, retention and
  emergency-disable rules;
- the workflow's own claims about atomic publication, immutable evidence,
  revocation, safe rollback and untrusted rich content.

Product meaning, linguistic correctness and source-authority content are not
re-opened. The already recorded Product Localization and Content verdicts stay
valid for v0.3 only; any later v0.4 verdict must review the new exact hash.

## 3. Findings

### BCK20-OD02-MS-F-001 — consumer/render compatibility is not revision-bound

- Severity: **Major**
- Affects: workflow §§5, 8, 13–16; AC-12/26/30/40
- Evidence: the manifest binds message-format and placeholder versions, but not
  the renderer capability profile that defines allowed rich-text nodes, link
  forms, escaping and unsupported-feature behavior.
- Risk: two supported app builds can interpret the same integrity-valid
  candidate differently or partially render a newer construct instead of
  returning typed `unsupported`.
- Required amendment:
  - define immutable `renderProfileRevision` as an identity/freshness input for
    candidate, approval and manifest;
  - require consumers to reject an unsupported profile atomically;
  - distinguish `render_profile_unsupported` from missing translation and
    transport failure;
  - leave concrete schema/code generation under API-DEC-05 and BCK20-OD-03.

### BCK20-OD02-MS-F-002 — atomic publication does not yet require atomic client installation

- Severity: **Major**
- Affects: workflow §§7, 12–16; AC-30/31/38
- Evidence: server-side manifest publication is atomic, while the client/cache
  handoff only says to reconcile caches and future adapter tests. No rule
  prevents key-by-key merge of two manifest revisions.
- Risk: one screen can combine old and new legal, safety or product copy while
  each individual entry looks valid.
- Required amendment:
  - define the BCK20-OD-03 handoff as stage full compatible bundle, verify exact
    manifest/hash/revisions, then atomically switch the active pointer;
  - forbid partial activation and cross-manifest key merging;
  - retain the last compatible, currently authorized bundle only where policy
    permits; otherwise expose typed unavailable/disabled state;
  - make interrupted install recover to one complete revision, never a mixed
    revision.

### BCK20-OD02-MS-F-003 — revocation cannot yet dominate offline cache monotonically

- Severity: **Blocking for withdrawn or safety-critical copy**
- Affects: workflow §§5.4, 6, 10, 12–13, 15–16; AC-18/29/32/38/45–46
- Evidence: a correction record has an ID and timestamp, but no monotonic
  authority/invalidation revision for client reconciliation. The prose says a
  revoked manifest cannot authorize cached artifacts without defining the
  marker that must win over an older cached bundle.
- Risk: an offline or delayed client can resurrect revoked copy after refresh,
  rollback or out-of-order invalidation delivery.
- Required amendment:
  - bind revoke/withdraw/disable actions to a monotonic
    `resolutionRevision` and exact target authority;
  - require authoritative tombstone/disable markers to win over cached content
    and survive retry, restart, restore and rollback reconciliation;
  - require revision-gap refresh and prohibit fallback to the revoked target;
  - keep exact transport, TTL and distribution mechanics in BCK20-OD-03.

### BCK20-OD02-MS-F-004 — actor identity is attributable but authority proof is incomplete

- Severity: **Major**
- Affects: workflow §§4–7, 10, 13; AC-07–10/19/29/44–49
- Evidence: reviewer, approver, publisher, revoker, corrector and exporter
  identities are named, but the workflow does not require trusted-session
  resolution, current capability revalidation or an authority-decision
  reference at each privileged action.
- Risk: a revoked or client-declared role can remain attributable yet still
  perform an unauthorized approval, publication, export or emergency action.
- Required amendment:
  - state that actor identity and authority are server/trusted-system resolved,
    never accepted from client payload or provider metadata;
  - revalidate current scoped authority at review acceptance, approval,
    publication, revoke/withdraw/disable and export;
  - capture an immutable authorization decision/evidence reference in every
    privileged action record or its attributable receipt;
  - treat stale/revoked authority as typed denial, not cached success.

### BCK20-OD02-MS-F-005 — the translation artifact data inventory is absent

- Severity: **Blocking before schema or production processing**
- Affects: workflow §§5, 9–10, 14, 16–17; BCK-04 §§6–7/19–22
- Evidence: the workflow says translation input is product/reference copy, but
  its records also contain identities, provenance, recipient/export evidence,
  screenshots/context and audit relationships. It supplies no record-family
  inventory using the BCK-04 template.
- Risk: pre-publication copy or residual personal/sensitive context can be
  treated as public, retained indefinitely, exported to an unapproved
  processor or omitted from access/deletion/incident scope.
- Required amendment:
  - add a documentation-only inventory covering source snapshot, candidate,
    review, approval, manifest, receipt, correction, impact, exception,
    source-authority entry and temporary work package;
  - conservatively classify source/candidate/work packages before publication,
    classify governance/audit identities as Operational, and classify only the
    sanitized approved public projection as Public;
  - require inherited highest-field classification for screenshots/context and
    reject undeclared Sensitive/personal content from ordinary translation
    tooling;
  - leave exact legal basis, retention periods, processor/transfer decisions
    and production ROPA/DPIA evidence Open under BCK-04/qualified review.

### BCK20-OD02-MS-F-006 — integrity hash is not proof of trusted origin

- Severity: **Major**
- Affects: workflow §§5.4, 7, 13–16; AC-30/44
- Evidence: `manifestIntegrityHash` detects payload change, but v0.3 does not
  explicitly say that the hash cannot authenticate the publisher,
  environment, market or distribution channel.
- Risk: an attacker or wrong environment can supply a self-consistent manifest
  and matching hash that the client mistakes for authorized Recharge content.
- Required amendment:
  - state that integrity and authenticity are separate controls;
  - require a future consumer to establish trusted publication origin,
    environment, market and current authority before accepting a manifest;
  - fail closed on origin/binding mismatch;
  - defer the exact authenticated transport or signature mechanism to the
    accepted threat model, API/distribution design and separately Approved
    executable slice.

### BCK20-OD02-MS-F-007 — allowlisted rich text lacks a safe render contract

- Severity: **Major**
- Affects: workflow §§7–10, 14–15; AC-12/14/40
- Evidence: v0.3 requires allowlisting and validation but does not require
  canonical safe nodes, output escaping or link resolution at the final mobile
  render boundary.
- Risk: validated translation text can still become executable markup,
  arbitrary URI navigation, WebView/script injection, deceptive Unicode or an
  accessibility-only mismatch.
- Required amendment:
  - treat translated text as untrusted through final rendering;
  - allow only canonical structured nodes from the exact render profile;
  - escape plain text, reject scripts/event handlers/unknown nodes and resolve
    links only through approved stable target/policy references;
  - prohibit arbitrary translator-provided URI schemes and raw executable
    HTML/WebView rendering;
  - add typed `unsafe_render_content` failure and require visual plus
    screen-reader evidence at supported scale/width.

## 4. Boundary checklist disposition

| Boundary | Covered | Covered with finding | Uncovered | Findings |
|---|---:|---:|---:|---|
| Mobile read/version/cache/offline | 7 | 5 | 0 | F-001–F-003, F-006–F-007 |
| Security authorization/integrity | 6 | 4 | 0 | F-004, F-006–F-007 |
| Privacy inventory/retention/provider | 6 | 3 | 0 | F-005 plus retained BCK-04 gates |
| Emergency revoke/rollback | 5 | 3 | 0 | F-002–F-003, F-006 |

`Covered with finding` means the intended principle exists, but the semantic
contract cannot yet prove a safe mobile/security outcome. Nothing in this table
is executable or specialist evidence.

## 5. Required paper vectors after amendment

| Vector | Required outcome |
|---|---|
| MS-V01 — newer render profile | atomic `render_profile_unsupported`; no partial text |
| MS-V02 — interrupted bundle install | prior complete authorized bundle or typed unavailable; never mixed revision |
| MS-V03 — revoke arrives after cached read | tombstone/resolution revision wins and revoked text no longer resolves |
| MS-V04 — rollback after revocation | revoked/expired/restricted target is refused |
| MS-V05 — actor loses capability before publish | current authority check denies; cached role cannot publish |
| MS-V06 — client submits actor/capability | ignored as authority and audited as typed denial where applicable |
| MS-V07 — matching hash from wrong environment | origin/binding mismatch fails closed |
| MS-V08 — rich text with script/event/unknown node | `unsafe_render_content`; no executable rendering |
| MS-V09 — translator-supplied arbitrary URI | rejected; only stable approved target resolves |
| MS-V10 — screenshot with undeclared personal data | rejected/quarantined or separately classified/authorized; not ordinary tooling input |
| MS-V11 — provider export deletion unconfirmed | typed open escalation; no false deletion claim |
| MS-V12 — large text at supported scale | meaning preserved, accessible, or publication blocked with attributable finding |

## 6. Amendment integration contract

If the owner accepts this pre-review:

1. advance the workflow to v0.4 and integrate MS-F-001–MS-F-007;
2. append AC-51 onward and preserve AC-01–50 identifiers unchanged;
3. add only semantic records/rules and documentation inventory — no physical
   schema, DTO, cache, endpoint or runtime code;
4. keep Product Localization/Content v0.3 verdicts as historical exact-hash
   evidence; require explicit revalidation for the new v0.4 hash;
5. prepare separate proposed `BCK20-OD02-SIG-MOBILE` and
   `BCK20-OD02-SIG-SEC` review records after v0.4 exists;
6. keep independent Security/Privacy and applicable qualified Legal evidence
   absent unless actually supplied;
7. keep source-authority content, provider selection, API-DEC-05 schema,
   BCK20-OD-03 distribution, runtime, Firebase, deployment, push and merge
   unauthorized;
8. reconcile BCK-20, coverage, BCK-01/BCK-02, D1/roadmap and LAUNCH_STATUS only
   after the corrected workflow and hashes exist.

## 7. Acceptance criteria

1. **BCK20-OD02-MS-PRE-AC-01:** the exact v0.3 normalized hash is frozen.
2. **BCK20-OD02-MS-PRE-AC-02:** this document is technical pre-review, not a Mobile or Security/Privacy verdict.
3. **BCK20-OD02-MS-PRE-AC-03:** F-001 makes renderer capability revision-bound and unsupported atomic.
4. **BCK20-OD02-MS-PRE-AC-04:** F-002 prevents mixed-manifest client state.
5. **BCK20-OD02-MS-PRE-AC-05:** F-003 makes revoke/withdraw/disable monotonic over cache and rollback.
6. **BCK20-OD02-MS-PRE-AC-06:** F-004 separates attributable identity from current scoped authority.
7. **BCK20-OD02-MS-PRE-AC-07:** F-005 supplies the missing BCK-04 inventory boundary without inventing Legal facts.
8. **BCK20-OD02-MS-PRE-AC-08:** F-006 separates content integrity from trusted origin.
9. **BCK20-OD02-MS-PRE-AC-09:** F-007 keeps rich content untrusted through final rendering.
10. **BCK20-OD02-MS-PRE-AC-10:** MS-V01–MS-V12 have deterministic fail-closed outcomes.
11. **BCK20-OD02-MS-PRE-AC-11:** AC-01–50 are never renumbered.
12. **BCK20-OD02-MS-PRE-AC-12:** BCK20-OD-03 remains the owner of physical distribution/cache/delta design.
13. **BCK20-OD02-MS-PRE-AC-13:** Product/Content v0.3 verdicts are not silently rebound to v0.4.
14. **BCK20-OD02-MS-PRE-AC-14:** Mobile and Security/Privacy verdicts remain separate and Pending.
15. **BCK20-OD02-MS-PRE-AC-15:** independent and qualified Legal evidence is not inferred.
16. **BCK20-OD02-MS-PRE-AC-16:** BCK20-OD-02 remains Open, OD-10 Proposed and BCK-20 Draft.
17. **BCK20-OD02-MS-PRE-AC-17:** no provider/schema/runtime/Firebase/deployment/push/merge authority is created.

## 8. Exact owner decision requested

```text
Одобряю BCK20-OD02-MS-PRE-01 v0.1:
интегрировать MS-F-001–MS-F-007 как documentation-only technical corrections
до Mobile и Security/Privacy owner review.
BCK20-OD-02 остаётся Open; OD-10 остаётся Proposed; BCK-20 остаётся Draft;
BCK20-OD-03 остаётся Deferred.
Product Localization/Content verdicts по v0.3 остаются историческим
exact-hash evidence и требуют revalidation для v0.4.
Independent Security/Privacy и applicable qualified Legal evidence не заявляю.
Source-authority content, provider selection, schema, runtime, Firebase,
deployment, push и merge не разрешаю.
```

## 9. Recorded disposition and next action

On 2026-09-17 the Product owner approved the exact §8 decision. The decision is
recorded in BCK20-OD02-MS-PRE-DEC-01 v0.1 and MS-F-001–MS-F-007 are integrated
in workflow v0.4. Product/Content v0.3 verdicts remain historical exact-hash
evidence and require v0.4 revalidation. Mobile and Security/Privacy verdicts
remain separate and Pending. Prepare their proposed review records against the
exact v0.4 hash; do not start implementation.
