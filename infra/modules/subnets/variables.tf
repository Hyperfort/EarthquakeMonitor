variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "public_subnets" {
  description = "A list of public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnets" {
  description = "A list of private subnet CIDR blocks"
  type        = list(string)
}

variable "azs" {
  description = "A list of availability zones"
  type        = list(string)
}

variable "name" {
  description = "The name of the subnets"
  type        = string
}