variable "name" {
  description = "The name of the RDS instance"
  type        = string
}

variable "private_subnets" {
  description = "A list of private subnet IDs for the RDS instance"
  type        = list(string)
}

variable "sg_id" {
  description = "The ID of the security group for the RDS instance"
  type        = string
}

variable "instance_class" {
  description = "The instance class for the RDS instance"
  type        = string
}

variable "db_name" {
  description = "The name of the database"
  type        = string
}

variable "username" {
  description = "The master username for the RDS instance"
  type        = string
}

variable "password" {
  description = "The master password for the RDS instance"
  type        = string
  sensitive   = true
}
