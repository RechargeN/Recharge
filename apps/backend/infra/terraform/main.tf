# R1 intentionally creates no cloud resource. This root exists so CI can prove
# variable validation, deterministic topology and the absence of credentials,
# remote state, project binding, plan mutations and provider-specific resources.

check "r1_remains_unbound" {
  assert {
    condition     = var.cloud_enabled == false && var.project_id == null && local.binding_state == "unbound"
    error_message = "R1 must remain local, disabled and unbound."
  }
}
