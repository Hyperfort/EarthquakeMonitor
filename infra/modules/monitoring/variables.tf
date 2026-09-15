variable "name" {
  description = "The name of the monitoring resources"
  type        = string
}

variable "lambda_name" {
  description = "The name of the Lambda function to monitor"
  type        = string
}

variable "cluster_name" {
  description = "The name of the ECS cluster to monitor"
  type        = string
}

variable "alb_arn_suffix" {
  description = "The ARN suffix of the ALB to monitor"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "The ARN suffix of the ALB target group to monitor"
  type        = string
}