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

variable "mode" {
  description = "Enforcement mode. Null until the App Check decision is recorded; nothing is configured then."
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.mode == null || contains(["UNENFORCED", "ENFORCED"], coalesce(var.mode, "UNENFORCED"))
    error_message = "mode must be null, UNENFORCED or ENFORCED."
  }
}
