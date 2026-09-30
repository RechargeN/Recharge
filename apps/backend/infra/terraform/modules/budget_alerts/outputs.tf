output "budget_created" {
  value = length(google_billing_budget.guardrail) == 1
}
