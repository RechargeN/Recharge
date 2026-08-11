# Mobile Boundary Inventory

> Generator-owned by `tools/scripts/check_boundaries.dart`. Do not edit manually.

- Tool version: `1.0.0`
- Policy version: `1.0.0`
- Scanned Dart files: 380
- Active exceptions: 106
- Exception budget: 106
- Unsuppressed violations: 0
- Stale exceptions: 0
- Expired exceptions: 0

## By rule

| Rule | Count |
|---|---:|
| `cross_feature_import` | 59 |
| `domain_infrastructure_dependency` | 35 |
| `feature_to_app_di_or_app_presentation` | 12 |

## By source feature

| Source | Count |
|---|---:|
| `create` | 31 |
| `discover` | 24 |
| `explore` | 14 |
| `auth` | 11 |
| `scenarios` | 10 |
| `favorites` | 7 |
| `identity` | 4 |
| `notifications` | 3 |
| `visited` | 2 |

## By target group

| Target | Count |
|---|---:|
| `core` | 35 |
| `discover` | 24 |
| `auth` | 13 |
| `favorites` | 13 |
| `app/di` | 9 |
| `create` | 7 |
| `app/presentation` | 3 |
| `scenarios` | 2 |

## By pair

| Pair | Count |
|---|---:|
| `create → core` | 28 |
| `auth → discover` | 7 |
| `discover → auth` | 6 |
| `discover → favorites` | 6 |
| `favorites → discover` | 6 |
| `scenarios → discover` | 6 |
| `explore → discover` | 5 |
| `auth → favorites` | 3 |
| `discover → app/presentation` | 3 |
| `discover → core` | 3 |
| `explore → auth` | 3 |
| `explore → create` | 3 |
| `identity → core` | 3 |
| `create → auth` | 2 |
| `discover → app/di` | 2 |
| `discover → create` | 2 |
| `discover → scenarios` | 2 |
| `explore → favorites` | 2 |
| `scenarios → favorites` | 2 |
| `auth → app/di` | 1 |
| `create → app/di` | 1 |
| `explore → app/di` | 1 |
| `favorites → app/di` | 1 |
| `identity → app/di` | 1 |
| `notifications → app/di` | 1 |
| `notifications → auth` | 1 |
| `notifications → create` | 1 |
| `scenarios → auth` | 1 |
| `scenarios → create` | 1 |
| `visited → app/di` | 1 |
| `visited → core` | 1 |
