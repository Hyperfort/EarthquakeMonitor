# EventBridge triggers the ingestion Lambda every 5 minutes to keep the database current.
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = "${var.name}-ingestion-schedule"
  description         = "EventBridge rule to trigger Lambda function"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.schedule.name
  target_id = "lambda"
  arn       = var.lambda_arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}
