variable "environment_id" {
  description = "Logical Recharge environment only; it does not select a cloud project."
  type        = string
  default     = "local"

  validation {
    condition     = contains(["local", "dev", "stage", "prod"], var.environment_id)
    error_message = "environment_id must be local, dev, stage or prod."
  }
}

variable "project_id" {
  description = "Intentionally unbound in R1. A real project requires a later authorization."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.project_id == null
    error_message = "R1 forbids Firebase/GCP project binding."
  }
}

variable "cloud_enabled" {
  description = "Hard fail-closed switch for local R1."
  type        = bool
  default     = false

  validation {
    condition     = var.cloud_enabled == false
    error_message = "R1 cloud enablement is forbidden."
  }
}

variable "firestore_location" {
  type    = string
  default = "eur3"

  validation {
    condition     = var.firestore_location == "eur3"
    error_message = "R1 Firestore policy is fixed to eur3 pending cloud approval."
  }
}

variable "functions_region" {
  type    = string
  default = "europe-west1"

  validation {
    condition     = var.functions_region == "europe-west1"
    error_message = "R1 Functions policy is fixed to europe-west1 pending cloud approval."
  }
}
