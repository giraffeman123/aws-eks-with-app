variable "mandatory_tags" {}

variable "public_subnet_tags" {}

variable "private_subnet_tags" {}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block of the vpc"
}

variable "public_subnets_cidr_block" {
  type        = list(any)
  description = "CIDR block for public subnet"
}

variable "private_subnets_cidr_block" {
  type        = list(any)
  description = "CIDR Block for private subnet"
}
