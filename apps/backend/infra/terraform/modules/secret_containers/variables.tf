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

variable "location" {
  type = string

  validation {
    condition     = var.location == "europe-west1"
    error_message = "Secret data location is europe-west1."
  }
}

variable "references" {
  description = "Secret references of the manifest: names only, never values."
  type = list(object({
    logicalName   = string
    referenceName = string
    ownerRole     = string
    valuePresent  = bool
  }))
  default = []
}
