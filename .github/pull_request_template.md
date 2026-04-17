## Summary

Describe what changed and why.

## Linked Task

Issue / task link:

## PR Size

- [ ] <= 400 lines changed (excluding generated/lockfiles/snapshots)
- [ ] 401-800 with split rationale in this PR
- [ ] >800 allowed by incident/hotfix exception

## Architecture Compliance

- [ ] Change follows `docs/architecture/ARCHITECTURE_BASELINE.md`.
- [ ] No forbidden cross-feature imports.
- [ ] Layer direction is respected (`presentation -> application -> domain`, `data -> domain`).
- [ ] No manual edits in generated files.

## Env / Secrets Compliance

- [ ] No secrets committed to git.
- [ ] Env/flavor impact is documented (if changed).
- [ ] Secret rotation/leak playbook impact reviewed (if applicable).

## API Contract Impact

- [ ] No API contract changes
- [ ] API contract changed and `docs/api/CONTRACT_CHANGE_TEMPLATE.md` is completed

## Analytics Impact

- [ ] No analytics changes
- [ ] Analytics changed and `docs/analytics/EVENT_CATALOG.md` is updated
- [ ] Event naming/params follow `docs/analytics/ANALYTICS_TAXONOMY.md`

## UI Baseline / Design System

- [ ] No reusable UI changes
- [ ] Reusable UI changes follow `docs/architecture/UI_BASELINE_DESIGN_SYSTEM.md`
- [ ] DS promotion intake completed (if applicable): `docs/architecture/DS_COMPONENT_INTAKE.md`

## Testing

- [ ] Testing scope mapped using `docs/architecture/TESTING_STRATEGY.md`
- [ ] Unit tests added/updated
- [ ] Widget tests added/updated
- [ ] Integration tests added/updated
- [ ] Existing tests pass
- [ ] Critical flow impact declared (if applicable)

## Quality Gates (Required Before Merge)

- [ ] Lint passes
- [ ] Test suite passes
- [ ] Codegen check passes
- [ ] Boundaries check passes

## Review And Merge Governance

- [ ] Required approvals collected (1 standard / 2 critical areas)
- [ ] No self-approval
- [ ] Merge strategy follows governance (`squash` by default)

## Temporary Override (Only For Incidents)

- [ ] Not used
- [ ] Used with ticket link + risk note + TTL + remediation task

## Notes

Include risks, rollout notes, and follow-up tasks if needed.
