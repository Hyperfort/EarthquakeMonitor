terraform {
  required_version = ">= 1.5.0"

  required_providers {
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.0"
    }
  }
}

provider "datadog" {
  api_key = var.datadog_api_key
  app_key = var.datadog_app_key
  api_url = var.datadog_api_url
}

# Datadog synthetic checks and SLOs monitor the public API endpoints and signal when
# the service falls below the agreed availability target.
locals {
  api_tests = {
    health = {
      path  = "/health"
      title = "Earthquake Monitor API health"
    }
    latest = {
      path  = "/quakes/latest"
      title = "Earthquake Monitor latest quakes"
    }
    weekly_average = {
      path  = "/quakes/weekly-average"
      title = "Earthquake Monitor weekly average"
    }
    historical = {
      path  = "/quakes/top?days=30&limit=5"
      title = "Earthquake Monitor historical quakes"
    }
  }
}

resource "datadog_synthetics_test" "api" {
  for_each = local.api_tests

  type      = "api"
  subtype   = "http"
  name      = each.value.title
  message   = "Notify the Earthquake Monitor owners if this API test fails."
  status    = "live"
  tags      = ["service:earthquake-monitor", "env:production", "managed-by:terraform"]
  locations = var.datadog_locations

  request_definition {
    method = "GET"
    url    = "${trimsuffix(var.api_base_url, "/")}${each.value.path}"
  }

  assertion {
    type     = "statusCode"
    operator = "is"
    target   = "200"
  }

  assertion {
    type     = "responseTime"
    operator = "lessThan"
    target   = tostring(var.response_time_ms)
  }

  options_list {
    tick_every = var.test_interval_seconds

    retry {
      count    = 2
      interval = 300
    }
  }
}

resource "datadog_service_level_objective" "api_availability" {
  name        = "Earthquake Monitor API availability"
  type        = "monitor"
  description = "Monthly availability SLO based on Datadog Synthetic API tests."
  monitor_ids = [for test in datadog_synthetics_test.api : test.monitor_id]
  tags        = ["service:earthquake-monitor", "sli:api-availability", "managed-by:terraform"]

  thresholds {
    timeframe = "30d"
    target    = var.api_availability_slo
    warning   = var.api_availability_warning
  }
}
