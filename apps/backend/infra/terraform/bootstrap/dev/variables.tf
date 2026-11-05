variable "project_id" {
  type = string
  validation {
    condition     = can(regex("^recharge-dev-[a-z0-9]{4,20}$", var.project_id))
    error_message = "Only an exact recharge-dev project ID is allowed."
  }
}

variable "billing_account_id" {
  type = string
}

variable "notification_email" {
  type      = string
  sensitive = true
}

variable "authorization_record_path" {
  type = string
}

variable "authorization_record_sha256" {
  type = string
}

variable "manifest_sha256" {
  type = string
}

variable "release_commit_sha" {
  type = string
}

variable "delivery_receipt_path" {
  description = "Private receipt bound to the created budget/channel and actual owner acknowledgement. Never stored in Git."
  type        = string
}

# ---- N2c (dev Identity). All default to "absent"; presence needs the N2c record.
variable "n2c_enabled" {
  description = "Desired presence of N2c Identity registration/runtime infrastructure. Not execution authority."
  type        = bool
  default     = false
}

variable "n2c_authorization_record_path" {
  description = "Private owner-issued N2c plan record. Never stored in Git."
  type        = string
  default     = ""
}

variable "n2c_authorization_record_sha256" {
  type    = string
  default = ""
}
