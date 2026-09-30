variable "enabled" {
  description = "Authorization gate. False by default: a module with enabled = false creates no resource."
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
