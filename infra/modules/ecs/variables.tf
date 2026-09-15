variable "name" {
  description = "The name of the ECS cluster"
  type        = string
}

variable "image" {
  description = "The Docker image for the ECS service"
  type        = string
}

variable "private_subnets" {
  description = "A list of private subnet IDs for the ECS service"
  type        = list(string)
}

variable "sg_id" {
  description = "The ID of the security group for the ECS service"
  type        = string
}

variable "target_group_arn" {
  description = "The ARN of the ALB target group for the ECS service"
  type        = string
}

variable "db_host" {
  description = "The hostname of the RDS instance"
  type        = string
}

variable "db_username" {
  description = "The username for the RDS instance"
  type        = string
}

variable "db_password" {
  description = "The password for the RDS instance"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "The name of the database"
  type        = string
}
