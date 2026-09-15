variable "name" {
  description = "The name of the Amazon Load Balancer"
  type        = string
}

variable "public_subnets" {
  description = "A list of public subnet IDs"
  type        = list(string)
}

variable "sg_id" {
  description = "The ID of the security group for the ALB"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}
