---
name: Task
about: Implementation task aligned with architecture baseline
title: "[TASK] "
labels: ["task"]
assignees: []
---

## Goal

Describe the expected outcome.

## Architecture Placement

- Stage ID(s): `#1`..`#10`
- MVP Slice ID (if applicable):
- Feature: `auth` / `discover` / `create` / `explore` / `favorites` / `notifications` / other
- Layer: `domain` / `data` / `application` / `presentation`
- Affected modules/packages:

## Boundaries Check

- [ ] No cross-feature direct imports were introduced.
- [ ] Layer dependency direction is preserved.
- [ ] `core` was not used for product/business logic.
- [ ] `design_system` remains the single source for reusable UI.
- [ ] `api_contracts` remains the single source for DTO/API clients.

## UI Governance

- [ ] Reusable UI changes follow `docs/architecture/UI_BASELINE_DESIGN_SYSTEM.md`
- [ ] If promoting component to DS, `docs/architecture/DS_COMPONENT_INTAKE.md` is completed

## Testing Scope

- Change type (from matrix):
- Critical flow impacted: yes/no (if yes, specify flow ID from `docs/architecture/TESTING_STRATEGY.md`)
- [ ] Unit tests required
- [ ] Widget tests required
- [ ] Integration tests required
- [ ] Not required (reason provided below)

Reason (if any):

## Acceptance Criteria

1. 
2. 
3. 
