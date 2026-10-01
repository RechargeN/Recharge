variable "enabled" {
  description = "Desired resource presence, not execution authority. Never change in response to approval expiry."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Provider labels: application, environment, managed_by and the stage."
  type        = map(string)
}

variable "project_id" {
  type     = string
  default  = null
  nullable = true
}

variable "media_location" {
  description = "Regional media bucket location; fixed by OD-07."
  type        = string

  validation {
    condition     = var.media_location == "europe-west1"
    error_message = "OD-07 fixes runtime media Storage to europe-west1."
  }
}

variable "recovery_location" {
  description = "Recovery/export bucket location; fixed by OD-07."
  type        = string

  validation {
    condition     = var.recovery_location == "EU"
    error_message = "OD-07 fixes the recovery/export bucket to the EU multi-region."
  }
}

variable "recovery_enabled" {
  description = "The recovery bucket stays disabled until BCK05-OD-05 is accepted."
  type        = bool
  default     = false
}
