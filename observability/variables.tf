variable "datadog_api_key" {
  description = "Datadog API key used by Terraform"
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog application key used by Terraform"
  type        = string
  sensitive   = true
}

variable "datadog_api_url" {
  description = "Datadog API URL"
  type        = string
  default     = "https://api.datadoghq.com"
}

variable "api_base_url" {
  description = "Public base URL of the deployed Earthquake Monitor API"
  type        = string
}

variable "datadog_locations" {
  description = "Datadog Synthetic locations that execute the API tests"
  type        = list(string)
  default     = ["aws:us-east-2"]
}

variable "test_interval_seconds" {
  description = "Interval between Synthetic API test runs"
  type        = number
  default     = 300

  validation {
    condition     = var.test_interval_seconds >= 60
    error_message = "Datadog test intervals must be at least 60 seconds."
  }
}

variable "response_time_ms" {
  description = "Maximum accepted API response time in milliseconds"
  type        = number
  default     = 2000

  validation {
    condition     = var.response_time_ms > 0
    error_message = "The response time threshold must be greater than zero."
  }
}

variable "api_availability_slo" {
  description = "Monthly API availability SLO target as a percentage"
  type        = number
  default     = 99.9

  validation {
    condition     = var.api_availability_slo > 0 && var.api_availability_slo <= 100
    error_message = "The API availability SLO must be greater than zero and no more than 100."
  }
}

variable "api_availability_warning" {
  description = "Monthly API availability warning threshold as a percentage"
  type        = number
  default     = 99.95

  validation {
    condition     = var.api_availability_warning > 0 && var.api_availability_warning <= 100
    error_message = "The API availability warning threshold must be greater than zero and no more than 100."
  }
}
