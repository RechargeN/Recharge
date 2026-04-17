# ADR 0012: Tech Stack Defaults

- Status: Accepted
- Date: 2026-04-17
- Review date: 2026-07-17
- Deciders: Recharge team
- Related baseline: [ARCHITECTURE_BASELINE.md](../architecture/ARCHITECTURE_BASELINE.md)

## Context

The architecture is frozen, but implementation consistency depends on clear default technical standards.
Without explicit defaults and deviation rules, teams introduce parallel approaches and increase maintenance cost.

## Decision

The following defaults are mandatory for new code unless a deviation is approved.

## Standards Matrix

| Area | Default standard | Allowed deviation | Deviation is allowed when | Approval |
|---|---|---|---|---|
| State management | Riverpod (`Notifier` / `AsyncNotifier`) with immutable state objects | Alternative local state for isolated UI-only widgets | The state is strictly local, has no cross-screen impact, and removal/migration cost is low | Feature owner + tech lead |
| Dependency injection | `get_it` in composition root (`app/di`), constructor injection in feature code | Manual constructor graph in tiny modules | Module is small, lifecycle is trivial, and testability is preserved | Tech lead |
| Routing | `go_router` with centralized route names/guards | Local nested router only for isolated flow package | Flow is self-contained and does not affect global navigation contracts | Feature owner + app owner |
| HTTP client | `dio` + interceptors (auth, logging, retry, timeout) | Direct package client wrapper behind repository boundary | External SDK forces specific client, but repository/domain contracts remain unchanged | Platform owner + tech lead |
| Storage | `flutter_secure_storage` for secrets, local key-value for non-sensitive prefs, repository-owned persistence abstractions | Additional local DB/cache technology | Data volume/querying needs exceed key-value capabilities | Tech lead |
| Error handling | `AppException` + `Failure` mapping; no raw infra exceptions crossing domain/application boundaries | Feature-specific typed failures | Domain requires explicit semantic failure categories | Feature owner |
| Telemetry | Unified telemetry facade with analytics + crash reporting + structured logs | Temporary no-op telemetry in prototypes | Feature is non-production prototype and flagged as temporary | Product owner + tech lead |

## Additional Constraints

1. Generated code is never edited manually.
2. Any deviation must include:
   - reason,
   - expected lifespan,
   - rollback/migration path,
   - follow-up task link.
3. Unapproved deviations are considered architecture violations.

## Deviation Workflow

1. Open a mini-RFC (max 1 page) referencing this ADR.
2. Add impact on architecture boundaries, CI, testing, and migration.
3. Get required approvals from the matrix above.
4. If the deviation affects project-wide standards, create a new ADR.

## Consequences

- Positive: consistent implementation, lower onboarding cost, fewer stack-level conflicts.
- Trade-off: slower introduction of new tools due to explicit approval path.
