# The ingestion Lambda runs on a schedule, fetches USGS events, writes them to RDS,
# and publishes CloudWatch latency/error metrics for operational monitoring.
resource "aws_iam_role" "lambda_role" {
  name = "${var.name}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_metrics" {
  name = "${var.name}-lambda-cloudwatch-metrics"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "cloudwatch:PutMetricData"
      Resource = "*"
      Condition = {
        StringEquals = {
          "cloudwatch:namespace" = "EarthquakeMonitor/SLI"
        }
      }
    }]
  })
}

resource "aws_lambda_function" "ingestion" {
  function_name = "${var.name}-ingestion"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_ingestion.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30

  filename         = var.zip_path
  source_code_hash = filebase64sha256(var.zip_path)

  environment {
    variables = {
      DB_HOST     = var.db_host
      DB_USERNAME = var.db_username
      DB_PASSWORD = var.db_password
      DB_NAME     = var.db_name
    }
  }

  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [var.sg_id]
  }
}