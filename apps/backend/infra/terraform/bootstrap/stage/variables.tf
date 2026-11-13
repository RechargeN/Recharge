variable "project_id" {
  type = string
  validation {
    condition     = var.project_id == "recharge-staging-y9y2y"
    error_message = "Only the reviewed staging project recharge-staging-y9y2y is allowed (N4a)."
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

# ---- N3b (dev Media tools). All default to "absent"; presence needs the N3b record.
variable "n3b_enabled" {
  description = "Desired presence of N3b Media tools infrastructure. Not execution authority."
  type        = bool
  default     = false
}

variable "n3b_authorization_record_path" {
  description = "Private owner-issued N3b plan record. Never stored in Git."
  type        = string
  default     = ""
}

variable "n3b_authorization_record_sha256" {
  type    = string
  default = ""
}

variable "n3b_image_digest" {
  description = "Empty: phase 1 (no services). Set: exact sha256 digest of the Cloud Build image; must equal the record."
  type        = string
  default     = ""
}

variable "n3b_operator_email" {
  description = "Owner account that may invoke the two services for the operator smoke (phase 2)."
  type        = string
  default     = ""
  sensitive   = true
}

# ---- N3a.2 (dev Content + Media runtime grants). Absent by default; needs the N3a.2 record.
variable "n3a2_enabled" {
  description = "Desired presence of the N3a.2 runtime grants. Not execution authority."
  type        = bool
  default     = false
}

variable "n3a2_authorization_record_path" {
  description = "Private owner-issued N3a.2 plan record. Never stored in Git."
  type        = string
  default     = ""
}

variable "n3a2_authorization_record_sha256" {
  type    = string
  default = ""
}

# ---- N3c (dev Notifications runtime grants). Absent by default; needs the N3c record.
variable "n3c_enabled" {
  description = "Desired presence of the N3c runtime grants. Not execution authority."
  type        = bool
  default     = false
}

variable "n3c_authorization_record_path" {
  description = "Private owner-issued N3c plan record. Never stored in Git."
  type        = string
  default     = ""
}

variable "n3c_authorization_record_sha256" {
  type    = string
  default = ""
}
