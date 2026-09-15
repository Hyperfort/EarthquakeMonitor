# Datadog API Tests

This Terraform stack creates Datadog Synthetic HTTP API tests for the deployed Earthquake Monitor API:

- `/health`
- `/quakes/latest`
- `/quakes/weekly-average`
- `/quakes/top?days=30&limit=5`

Each test expects HTTP 200 and a response time below the configured threshold. Tests run from the configured Datadog locations every five minutes by default.

## SLI and SLO

The Synthetic tests provide these SLIs:

- API availability: successful HTTP 200 checks divided by total checks across the four endpoints.
- API latency: response time for each check, with a default threshold of 2,000 milliseconds.

Terraform creates an API availability SLO across all four Synthetic monitors with a 99.9% target over 30 days and a 99.95% warning threshold. The corresponding error budget is 0.1%, or approximately 43 minutes 12 seconds in a 30-day month.

## Configure

From this directory, provide credentials through environment variables and the deployed API URL:

```sh
export TF_VAR_datadog_api_key="your-datadog-api-key"
export TF_VAR_datadog_app_key="your-datadog-application-key"
export TF_VAR_api_base_url="http://your-alb-dns-name"
```

For a local `terraform.tfvars` file, use this template and do not commit the populated file:

```hcl
datadog_api_key = "your-datadog-api-key"
datadog_app_key = "your-datadog-application-key"
api_base_url    = "http://your-alb-dns-name"
```

Use `datadog_api_url` for another Datadog site, such as `https://api.datadoghq.eu`.

## Deploy

```sh
terraform init
terraform fmt -check
terraform validate
terraform plan
terraform apply
```

Destroy the tests with:

```sh
terraform destroy
```
