# Notification only. There is deliberately no action that disables billing or
# stops a service: a budget alert is not a spend limiter and automatic billing
# detach could destroy data. Containment is by server-side flags and quotas.
resource "google_billing_budget" "guardrail" {
  count = var.enabled ? 1 : 0

  billing_account = var.billing_account_id
  display_name    = var.display_name

  budget_filter {
    projects = ["projects/${var.project_number}"]
  }

  amount {
    specified_amount {
      currency_code = "EUR"
      units         = tostring(var.amount_eur)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.thresholds_percent
    content {
      threshold_percent = threshold_rules.value / 100
    }
  }

  all_updates_rule {
    monitoring_notification_channels = var.notification_channel_ids
    disable_default_iam_recipients   = false
  }
}
