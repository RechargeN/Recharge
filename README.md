# Recharge

Recharge is a Flutter mobile app for discovering, planning, and creating leisure
activities: events, places, routes, and quick scenarios. The launch market is
Riga, Latvia, with EUR as the initial currency.

The current product build uses local/mock datasources. Firebase Auth,
Cloud Firestore, and Storage are the target backend integrations and will be
connected in dedicated slices after stabilization.

The repository also contains a **local-only backend** (`apps/backend`): bounded
domain foundations that run in memory and against the Firebase Emulator. No
cloud environment is deployed, no production binding exists, and every market
and capability is disabled by default. Cloud deployment and market activation
are separate, explicitly approved steps.

## Repository layout

```text
apps/mobile/               Flutter application
apps/backend/              Local backend foundations (Functions, Rules, Emulator); not deployed
packages/design_system/    Shared design tokens and UI components
packages/api_contracts/    Shared data/API contracts
docs/adr/                  Accepted architecture decisions
docs/architecture/         Architecture baseline and launch status
docs/product/              Product and slice specifications, grouped by topic
tools/scripts/             Repository checks and maintenance scripts
```

Architecture and contribution rules are defined in
[`AGENTS.md`](AGENTS.md),
[`docs/architecture/ARCHITECTURE_BASELINE.md`](docs/architecture/ARCHITECTURE_BASELINE.md),
and [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Requirements

- Flutter 3.44.9 (pinned in CI)
- Dart >=3.12.2 <4.0.0 (bundled with the pinned Flutter)
- Node.js 22 and npm 10 (only for `apps/backend`; see its README)
- Android Studio or another Flutter-compatible IDE
- Melos for repository-wide commands

## Setup and verification

From the repository root:

```bash
melos bootstrap
melos run analyze
melos run test
```

Or work directly with the mobile app:

```bash
cd apps/mobile
flutter pub get
flutter analyze
flutter test
flutter run
```

A slice is not complete until both `flutter analyze` and `flutter test` pass.

## Configuration and secrets

Do not commit API keys, Firebase configuration, signing material, or local
environment files. Environment/flavor rules and secret-handling procedures are
documented in
[`docs/architecture/ENV_FLAVORS_SECRETS.md`](docs/architecture/ENV_FLAVORS_SECRETS.md).

Current implementation status and verification evidence are tracked in
[`docs/architecture/LAUNCH_STATUS.md`](docs/architecture/LAUNCH_STATUS.md).
