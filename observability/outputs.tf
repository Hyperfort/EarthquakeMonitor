output "synthetic_test_ids" {
  description = "Datadog Synthetic API test IDs"
  value       = { for name, test in datadog_synthetics_test.api : name => test.id }
}

output "tested_api_url" {
  description = "Base API URL monitored by Datadog"
  value       = var.api_base_url
}

output "api_availability_slo_id" {
  description = "Datadog API availability SLO ID"
  value       = datadog_service_level_objective.api_availability.id
}
