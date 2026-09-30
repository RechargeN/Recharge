variable "enabled" {
  description = "Authorization gate. False by default: a module with enabled = false creates no resource."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Provider labels: application, environment, managed_by and the stage."
  type        = map(string)
}

variable "billing_account_id" {
  type     = string
  default  = null
  nullable = true
}

variable "project_number" {
  type     = string
  default  = null
  nullable = true
}

variable "display_name" {
  type = string
}

variable "amount_eur" {
  description = "Monthly guardrail in whole EUR (proposed by BCK05-OD-04)."
  type        = number
}

variable "thresholds_percent" {
  type = list(number)
}

variable "notification_channel_ids" {
  description = "Existing notification channels. A budget alert is a notification, never a hard stop."
  type        = list(string)
  default     = []
}
