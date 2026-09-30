variable "environment_id" {
  description = "Logical environment of this root."
  type        = string
  default     = "prod"

  validation {
    condition     = var.environment_id == "prod"
    error_message = "This root belongs to the prod environment only."
  }
}

variable "project_id" {
  description = "Provider project id, chosen in the approved provisioning slice after availability checks. Null until then."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.project_id == null || can(regex("^recharge-prod-[a-z0-9]{4,20}$", var.project_id))
    error_message = "project_id must follow recharge-prod-<uniqueSuffix> or be null."
  }
}

variable "authorization_ref" {
  description = "Reference of the signed record that authorizes provisioning of this environment. Null keeps every resource closed."
  type        = string
  default     = null
  nullable    = true
}

variable "manifest_sha256" {
  description = "SHA-256 of the execution manifest the authorization record covers."
  type        = string
  default     = null
  nullable    = true
}

variable "billing_account_id" {
  type     = string
  default  = null
  nullable = true
}

variable "project_number" {
  type     = string
  default  = null
  nullable = true
}

variable "notification_channel_ids" {
  type    = list(string)
  default = []
}

variable "github_repository_id" {
  type     = string
  default  = null
  nullable = true
}

variable "github_repository_owner_id" {
  type     = string
  default  = null
  nullable = true
}

variable "point_in_time_recovery" {
  type    = bool
  default = false
}

variable "recovery_bucket_enabled" {
  type    = bool
  default = false
}
