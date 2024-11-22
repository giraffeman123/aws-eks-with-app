variable "aws_region" {
  type    = string
  default = "us-east-2"
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "cluster_name" {
  type    = string
  default = ""
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

variable "db_credentials_secret" {
  type = string
}

variable "fsa_api_docker_image_url" {
  type = string
}

variable "fsa_webapp_docker_image_url" {
  type = string
}

variable "fsa_stack_git_credentials_secret" {
  type = string
}
