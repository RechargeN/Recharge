# Testing Strategy

This document defines minimum test requirements and release-critical flows for Recharge.

## 1) Test Types

- Unit tests: domain logic, use cases, mappers, validators, pure utilities.
- Widget tests: UI states, rendering contracts, interactions within a screen/component.
- Integration tests: end-to-end behavior across layers/modules and platform/service boundaries.

## 2) Minimum Matrix (Change Type -> Required Tests)

| Change type | Unit | Widget | Integration |
|---|---|---|---|
| Pure domain/usecase logic | required | optional | optional |
| Mapper/serialization/parsing | required | optional | optional |
| Feature UI layout/interaction (single screen) | optional | required | optional |
| Navigation/route guards/deep links | required | required | required |
| Repository/data source behavior | required | optional | required |
| Auth/session/token behavior | required | required | required |
| Permissions/location/connectivity flows | required | required | required |
| Publish/create flow behavior | required | required | required |
| API contract adoption changes | required | optional | required |
| Hotfix touching multiple layers | required | required | required |

## 3) Critical Flows (Release-Blocking)

The following flows are critical and must remain green before release:

1. Sign in -> session restore -> sign out.
2. Discover feed load -> search/filter -> details open.
3. Map open -> apply radius/filter -> object details.
4. Create draft save/load -> publish flow completion.
5. Profile/settings update -> role switch persistence.

## 4) Mandatory Integration Test Cases

Integration tests are mandatory when change affects at least one of:

- auth/session lifecycle;
- route guards, deep links, or global navigation wiring;
- repository behavior + remote/local source coordination;
- publish/create workflow;
- permissions/location flow;
- API breaking contract changes;
- data persistence schema/migration behavior.

## 5) Sufficiency Criteria

A change is test-sufficient only if all are true:

1. Required test types from the matrix are implemented or updated.
2. Affected critical flow (if any) is covered by integration or explicit regression test.
3. CI test job is green.
4. If test was intentionally skipped, rationale and risk are documented in PR.

## 6) PR Expectations

- Every PR must declare testing scope.
- PR touching critical flow must explicitly mention impacted flow IDs.
- No merge with failing required tests.

Related docs:

- [CI_GATES_POLICY.md](./CI_GATES_POLICY.md)
- [ARCHITECTURE_BASELINE.md](./ARCHITECTURE_BASELINE.md)
