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

variable "pool_id" {
  type = string
}

variable "provider_id" {
  type = string
}

variable "repository_id" {
  description = "Immutable GitHub repository id. Null until known; the provider then trusts nothing."
  type        = string
  default     = null
  nullable    = true
}

variable "repository_owner_id" {
  type     = string
  default  = null
  nullable = true
}
