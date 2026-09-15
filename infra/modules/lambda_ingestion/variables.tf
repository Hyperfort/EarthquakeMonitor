variable "name" {
  description = "The name of the Lambda function"
  type        = string
}

variable "zip_path" {
  description = "The path to the zip file containing the Lambda function code"
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

variable "private_subnets" {
  description = "A list of private subnet IDs for the Lambda function"
  type        = list(string)
}

variable "sg_id" {
  description = "The ID of the security group for the Lambda function"
  type        = string
}
