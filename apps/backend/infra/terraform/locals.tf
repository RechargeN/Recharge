locals {
  logical_environment_identity = "recharge-${var.environment_id}"
  binding_state                = "unbound"
  labels = {
    application = "recharge"
    environment = var.environment_id
    managed_by  = "terraform"
    stage       = "r1-local-foundation"
  }
}
