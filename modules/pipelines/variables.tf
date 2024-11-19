variable "mandatory_tags" {}

variable "name" {
  type = string
}

variable "fsa_api_docker_image_name" {
  type = string
}

variable "fsa_api_repository_url" {
  type = string
}

variable "fsa_api_repository_branch" {
  type = string
}

variable "fsa_api_repository_provider_type" {
  type = string
}

variable "fsa_webapp_docker_image_name" {
  type = string
}

variable "fsa_webapp_repository_url" {
  type = string
}

variable "fsa_webapp_repository_branch" {
  type = string
}

variable "fsa_webapp_repository_provider_type" {
  type = string
}

variable "fsa_stack_git_credentials_secret" {
  type = string
}
