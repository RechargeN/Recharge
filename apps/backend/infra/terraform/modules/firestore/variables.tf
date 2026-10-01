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

variable "location_id" {
  description = "Creation-time location of the (default) database; fixed by OD-07."
  type        = string

  validation {
    condition     = var.location_id == "eur3"
    error_message = "OD-07 fixes the Firestore location to eur3."
  }
}

variable "point_in_time_recovery" {
  description = "Decided by BCK05-OD-05 (Proposed). False until that decision is accepted."
  type        = bool
  default     = false
}
