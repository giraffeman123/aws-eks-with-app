variable "mandatory_tags" {}

variable "cluster_name" {
  type = string
}

variable "cluster_version" {
  type = string
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "private_subnets_ids" {
  type    = list(string)
  default = [""]
}

variable "public_subnets_ids" {
  type    = list(string)
  default = [""]
}

variable "main_domain_name" {
  type = string
}

variable "website_domain" {
  type = string
}

variable "argocd_domain" {
  type = string
}