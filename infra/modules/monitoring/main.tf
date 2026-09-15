# CloudWatch dashboards and alarms provide a single operational view of Lambda health,
# ingestion freshness, and ALB/ECS service health.
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", var.lambda_name],
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_name]
          ],
          period  = 300,
          stat    = "Sum",
          region  = "us-east-2",
          title   = "Lambda Ingestion – Errors & Invocations",
          view    = "timeSeries",
          stacked = false
        }
      },
      {
        type   = "metric",
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["EarthquakeMonitor/SLI", "IngestionFreshnessSeconds", "Service", "earthquake-monitor"]
          ],
          period  = 300,
          stat    = "Maximum",
          region  = "us-east-2",
          title   = "Ingestion Freshness (seconds)",
          view    = "timeSeries",
          stacked = false
        }
      },
      {
        type   = "metric",
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name]
          ],
          period  = 300,
          stat    = "Average",
          region  = "us-east-2",
          title   = "ECS Cluster – CPU & Memory",
          view    = "timeSeries",
          stacked = false
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.name}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Lambda ingestion is failing"
  dimensions = {
    FunctionName = var.lambda_name
  }
}

resource "aws_cloudwatch_metric_alarm" "ingestion_freshness" {
  alarm_name          = "${var.name}-ingestion-freshness"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "IngestionFreshnessBreached"
  namespace           = "EarthquakeMonitor/SLI"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "breaching"
  alarm_description   = "The newest successfully ingested earthquake is older than 15 minutes"
  dimensions = {
    Service = "earthquake-monitor"
  }
}

# ALB 5xx alarm
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB is returning 5xx errors"
  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }
}

# ECS API availability alarm
resource "aws_cloudwatch_metric_alarm" "ecs_unhealthy" {
  alarm_name          = "${var.name}-ecs-unhealthy"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnhealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "ECS tasks behind ALB are unhealthy"
  dimensions = {
    TargetGroup  = var.target_group_arn_suffix
    LoadBalancer = var.alb_arn_suffix
  }
}