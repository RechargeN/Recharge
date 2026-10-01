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
    condition     = var.location == "EU"
    error_message = "State buckets live in the EU multi-region."
  }
}
