variable "name" {
  description = "The name of the EventBridge rule"
  type        = string
}

variable "lambda_arn" {
  description = "The ARN of the Lambda function"
  type        = string
}
