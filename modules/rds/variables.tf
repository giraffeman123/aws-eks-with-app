variable "mandatory_tags" {}

variable "vpc_id" {
  type = string
}

variable "private_subnets_ids" {
  type    = list(string)
  default = [""]
}

variable "private_subnets_cidr_block" {
  type    = list(string)
  default = [""]
}

variable "db_credentials_secret" {
  type = string
}

variable "db_port" {
  type = number
}
