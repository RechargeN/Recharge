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

variable "service_accounts" {
  description = "Catalogue entries of the manifest: name, purpose and whether the module is deployed."
  type = list(object({
    name       = string
    kind       = string
    purpose    = string
    deployed   = bool
    authorized = bool
  }))
}
