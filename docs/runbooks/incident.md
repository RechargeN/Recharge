# Incident Runbook (MVP)

## Severity Levels

- `SEV-1`: production unavailable / critical user impact.
- `SEV-2`: major degradation with workaround.
- `SEV-3`: limited degradation, no critical flow outage.

## First 15 Minutes

1. Assign incident commander.
2. Declare severity.
3. Open incident channel/thread.
4. Freeze risky releases until triage complete.
5. Capture:
   - affected flow,
   - start time,
   - current impact,
   - suspected change window.

## Triage Checklist

1. Reproduce issue.
2. Check latest release/build.
3. Check analyzer/test/build status of deployed commit.
4. Decide:
   - hotfix forward,
   - rollback.

## Communication Cadence

- `SEV-1`: update every 15 min.
- `SEV-2`: update every 30 min.
- `SEV-3`: update every 60 min.

## Resolution

1. Apply rollback or hotfix.
2. Validate critical flows.
3. Mark incident mitigated.
4. Publish summary.

## Postmortem (required for SEV-1/SEV-2)

- Timeline
- Root cause
- Detection gaps
- Permanent fixes
- Owners and due dates
