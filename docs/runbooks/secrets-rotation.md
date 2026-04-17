# Secrets Rotation Runbook

## Trigger

- Planned periodic rotation (every 90 days).
- Emergency rotation after incident or risk event.

## Roles

- Rotation owner: tech lead/on-call maintainer.
- Verifier: feature owner for affected services.

## Procedure

1. Inventory
   - List all affected secrets and dependent services/environments.
2. Prepare replacement
   - Create new secrets in the secret manager.
3. Deploy safely
   - Update CI/environment bindings.
   - Deploy non-prod first, then prod.
4. Validate
   - Health checks, error rate, auth and API connectivity.
5. Revoke old
   - Disable previous credentials after validation window.
6. Record
   - Document date, owner, scope, and verification result.

## Verification Checklist

- [ ] Application boots in all target environments.
- [ ] Auth/session flows work.
- [ ] Third-party integrations respond successfully.
- [ ] No elevated error rates after rotation.

## Rollback

- Re-enable previous secret only if new secret causes outage and no quick fix exists.
- Rollback window must be temporary and tracked in incident ticket.
