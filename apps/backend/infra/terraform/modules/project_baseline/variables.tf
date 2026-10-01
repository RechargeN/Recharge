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
  description = "Provider project id of this environment. Null until the approved provisioning slice."
  type        = string
  default     = null
  nullable    = true
}

variable "services" {
  description = "APIs the environment needs. Enabling an API creates no data resource."
  type        = set(string)
}
