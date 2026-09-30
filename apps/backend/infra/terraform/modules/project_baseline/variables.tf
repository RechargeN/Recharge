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
  description = "Provider project id of this environment. Null until the approved provisioning slice."
  type        = string
  default     = null
  nullable    = true
}

variable "services" {
  description = "APIs the environment needs. Enabling an API creates no data resource."
  type        = set(string)
}
