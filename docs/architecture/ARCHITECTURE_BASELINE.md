# Recharge Architecture Baseline

Status: Frozen baseline  
Effective date: 2026-04-17  
Owner: Recharge team

## 1) Canonical Project Tree

```txt
recharge/
├─ README.md
├─ .gitignore
├─ melos.yaml
├─ analysis_options.yaml
├─ .github/
│  ├─ workflows/
│  │  ├─ mobile-ci.yml
│  │  ├─ mobile-tests.yml
│  │  ├─ codegen-check.yml
│  │  └─ release.yml
│  ├─ pull_request_template.md
│  └─ ISSUE_TEMPLATE/
│     └─ task.md
│
├─ apps/
│  └─ mobile/
│     ├─ pubspec.yaml
│     ├─ analysis_options.yaml
│     ├─ android/
│     ├─ ios/
│     ├─ web/
│     ├─ assets/
│     │  ├─ images/{common,onboarding,mock_events,mock_places,avatars}
│     │  ├─ icons/
│     │  ├─ fonts/
│     │  ├─ map/{markers,pins,overlays}
│     │  └─ mock/{json,seed}
│     ├─ lib/
│     │  ├─ main.dart
│     │  ├─ app/{app.dart,bootstrap.dart,router/,di/,theme/,config/,observers/}
│     │  ├─ core/{errors/,network/,storage/,telemetry/,security/,platform/,utils/,extensions/}
│     │  ├─ shared/{primitives/,models/,extensions/}
│     │  ├─ l10n/
│     │  ├─ generated/{l10n/,api/}
│     │  └─ features/
│     │     ├─ splash/{application/,presentation/,splash_feature.dart}
│     │     ├─ onboarding/{application/,presentation/,onboarding_feature.dart}
│     │     ├─ auth/{domain/,data/,application/,presentation/,auth_feature.dart}
│     │     ├─ discover/{domain/,data/,application/,presentation/,discover_feature.dart}
│     │     ├─ create/{domain/,data/,application/,presentation/,create_feature.dart}
│     │     ├─ explore/{domain/,data/,application/,presentation/,explore_feature.dart}
│     │     ├─ favorites/{domain/,data/,application/,presentation/,favorites_feature.dart}
│     │     └─ notifications/{domain/,data/,application/,presentation/,notifications_feature.dart}
│     ├─ test/{unit/,widget/,golden/,features/}
│     └─ integration_test/
│
├─ packages/
│  ├─ design_system/
│  │  ├─ pubspec.yaml
│  │  ├─ lib/design_system.dart
│  │  ├─ lib/src/{foundation/,tokens/,theme/,components/,patterns/}
│  │  └─ test/
│  └─ api_contracts/
│     ├─ pubspec.yaml
│     ├─ lib/api_contracts.dart
│     ├─ lib/src/{contracts/,dto/{request,response},clients/,serializers/,generated/}
│     └─ test/
│
├─ docs/
│  ├─ adr/
│  ├─ architecture/
│  ├─ api/
│  ├─ analytics/
│  ├─ product/
│  └─ runbooks/{release.md,rollback.md,incident.md,feature-flags.md}
│
└─ tools/
   ├─ ci/{lint/,test/,build/,release/}
   └─ scripts/{bootstrap/,codegen/,format/,localization/,clean/,check-boundaries/}
```

## 2) Mandatory Rules

1. `packages/design_system` is the single source of truth for reusable UI components.
2. `packages/api_contracts` is the single source of truth for DTOs and API clients.
3. Feature layering is mandatory: `presentation -> application -> domain`; `data -> domain`.
4. `domain` layer must not depend on framework/infrastructure code.
5. `features/*` must not import each other directly. Cross-feature interaction only via contracts/facades.
6. `core` contains only infrastructure and cross-cutting technical concerns, never product/business workflows.
7. `lib/generated/**` and package `generated/**` are codegen-only; manual edits are forbidden.
8. Mock/seed assets and mock datasources are excluded from production flavors.
9. CI gates are required before merge: lint, tests, codegen check, boundaries check.
10. Any architecture change to this baseline requires a new ADR with status `Accepted`.

## 3) Definition Of Done (Architecture Compliance)

- New code is placed in the correct feature and layer.
- Imports respect layer and feature boundaries.
- Tests are added according to change scope (`unit`/`widget`/`integration`).
- No manual edits in generated code.
- PR checklist is fully completed.
