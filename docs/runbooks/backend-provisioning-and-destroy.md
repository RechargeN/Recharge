# Backend provisioning and destroy (Draft, not executed)

Status: **Draft.** Writing this procedure and the IaC grants no authority to
create or destroy anything. Provider project IDs follow
`recharge-<env>-<uniqueSuffix>` and are chosen only in the approved provisioning
slice after availability checks; none is invented here.

## Provisioning (separately authorized slice)

1. Create the environment project and link billing (outside this repository).
2. Bootstrap the state bucket: local state first, then migrate to the bucket of
   that environment (`<project>-tfstate`, versioned, never public,
   destroy-protected). One bucket per environment; never shared.
3. Supply `project_id`, the authorization record reference and the manifest hash.
   Without all three the plan creates zero resources.
4. Review the plan of that environment root; apply only in the approved slice.
5. Deploy Rules, indexes, TTL and Functions with the Firebase CLI (they are not
   managed by Terraform); run the smoke list.

## Destroy (data protection first)

| Environment | Rule |
|---|---|
| dev | allowed, after a verified export and a protection check |
| stage | only with a dated record and the same checks |
| prod | forbidden except through a superseding decision |

Before any destroy: verified export of data and audit, list of protected
resources (databases, buckets and secrets carry `deletion_protection` /
`prevent_destroy` and are unprotected only by a reviewed change, never forced),
and confirmation that nothing another environment depends on is removed.
`force_destroy` stays false everywhere.
