# BCK-D1 — OD-10 Documentation-Vector Owner Decision

- Decision ID: **OD10-DOC-DEC-01**
- Version: **0.1**
- Date: **2026-09-19**
- Status: **Accepted design direction with required amendments**
- Owner/signatory: **RechargeN / Product owner combined role**
- Independence: **none**
- Qualified Legal/Privacy claim: **none**
- Frozen target: [BCK-D1-OD10-EV-01 v0.1](BACKEND_OD_10_LOCALIZATION_EVIDENCE.md)
- Frozen target normalized-LF SHA-256:
  `82c31bd8b03b7b627e1ebf978a135696311800fb0f4e01e9dc2b4af6800a299d`
- Frozen review: [OD10-DOC-REV-01 v0.1](BACKEND_OD_10_LOCALIZATION_OWNER_REVIEW.md)
- Frozen review normalized-LF SHA-256:
  `a0338a570f5062f98cff6cc8a3c6bb1bb356be8d8ded8ba1cdec24286b57aa91`
- Integrated target: [BCK-D1-OD10-EV-01 v0.2](BACKEND_OD_10_LOCALIZATION_EVIDENCE.md)
- Integrated target normalized-LF SHA-256:
  `dceebb4ed1f993523393c8a979099ae5b02798d50d8349275109ae92c8063cfd`
- Runtime effect: **none**

---

## 1. Decision

The owner accepts the OD-10 documentation design direction and requires
integration of F-001–F-012 from the frozen review into amended evidence v0.2
and its canonical documentation references.

This is not OD-10 Acceptance. OD-10 remains Proposed, BCK-20 remains Draft and
BCK20-OD-02/05 remain Open. The decision supplies no independent or qualified
Legal verdict and no executable authority.

## 2. Effective documentation scope

The authorized reconciliation may:

- correct the unreachable `value_default` vector;
- distinguish unsupported viewer reads from unsupported mutation/publication;
- define resolved/unresolved result shapes;
- remove ambiguous silent text normalization;
- revision-bind locale normalization identity;
- specify duplicate-member, fallback, withdrawal, stale-cache, integrity and
  telemetry behavior;
- preserve EE/LT isolation without inventing future locale policy;
- add deterministic compatibility outcomes;
- update canonical documentation status and traceability.

## 3. Retained gates

- OD-10 remains Proposed and BCK-20 remains Draft;
- BCK20-OD-02 and BCK20-OD-05 remain Open;
- no qualified Legal/Privacy or independent specialist conclusion is claimed;
- no locale/source becomes approved for executable ingestion by this decision;
- API-DEC-05 remains the schema/toolchain gate;
- schema, executable fixtures, generated clients, datasets, runtime, Firebase,
  deployment and activation remain unauthorized;
- push and merge remain unauthorized.

## 4. Verbatim owner instruction

> Одобряю OD10-DOC-REV-01 v0.1 для target BCK-D1-OD10-EV-01 v0.1 /
> normalized-LF SHA-256
> 82c31bd8b03b7b627e1ebf978a135696311800fb0f4e01e9dc2b4af6800a299d:
> Accept design direction with required amendments F-001–F-012. Разрешаю
> docs-only integration и подготовку amended evidence v0.2. OD-10 остаётся
> Proposed; BCK-20 Draft; BCK20-OD-02/05 Open. Independent/qualified Legal
> verdict, schema, executable fixtures, runtime, Firebase, deployment, push и
> merge не разрешаю.

## 5. Acceptance criteria

1. **OD10-DOC-DEC-AC-01:** target and review are frozen by exact version and normalized hash.
2. **OD10-DOC-DEC-AC-02:** F-001–F-012 are integrated into the exact hashed v0.2 target without changing runtime.
3. **OD10-DOC-DEC-AC-03:** OD-10 remains Proposed after reconciliation.
4. **OD10-DOC-DEC-AC-04:** BCK-20 remains Draft and BCK20-OD-02/05 remain Open.
5. **OD10-DOC-DEC-AC-05:** zero independence and absent qualified Legal evidence remain explicit.
6. **OD10-DOC-DEC-AC-06:** API-DEC-05 and a later exact-file slice retain executable authority.
7. **OD10-DOC-DEC-AC-07:** schema, fixtures, datasets, runtime and Firebase remain unauthorized.
8. **OD10-DOC-DEC-AC-08:** push and merge remain unauthorized.
