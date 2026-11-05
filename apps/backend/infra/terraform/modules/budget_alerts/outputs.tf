output "budget_created" {
  value = length(google_billing_budget.guardrail) == 1
}

output "budget_name" {
  description = "Exact created budget resource name, for binding delivery evidence."
  value       = try(google_billing_budget.guardrail[0].id, null)
}
