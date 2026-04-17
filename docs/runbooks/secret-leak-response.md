# Secret Leak Response Runbook

## Severity

Treat all confirmed leaks as high severity until proven otherwise.

## Immediate Response (0-30 minutes)

1. Revoke exposed secret(s) immediately.
2. Issue replacement credentials.
3. Block further exposure paths (remove leaked artifact, stop compromised job/token).
4. Open incident ticket and assign owner.

## Containment (30-120 minutes)

1. Rotate all related secrets in affected environment(s).
2. Audit access logs and suspicious activity.
3. Re-deploy services with new credentials.
4. Verify core user flows and API connectivity.

## Communication

- Notify engineering lead and product owner.
- If user impact is possible, prepare external communication plan.

## Recovery And Follow-up (same day)

1. Confirm old credentials are disabled.
2. Add preventive controls (git ignore, secret scan, CI hardening).
3. Publish short post-incident report:
   - root cause,
   - blast radius,
   - timeline,
   - mitigation,
   - prevention actions.

## Exit Criteria

- [ ] Leaked credentials revoked.
- [ ] Replacements deployed and verified.
- [ ] Incident report and remediation tasks created.
