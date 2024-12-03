variable "mandatory_tags" {}

variable "cluster_name" {
  type = string
}

variable "cluster_endpoint" {
  type = string
}

variable "cluster_certificate_authority_data" {
  type = string
}

variable "cluster_oidc_provider_arn" {
  type = string
}

variable "db_credentials_secret" {
  type = string
}

variable "applications" {
  type = map(map(string))
}

# variable "main_domain_name" {
#   type = string
# }

# variable "website_domain" {
#   type = string
# }

# variable "argocd_domain" {
#   type = string
# }

# variable "prometheus_domain" {
#   type = string
# }

# variable "grafana_domain" {
#   type = string
# }

# variable "alertmanager_domain" {
#   type = string
# }
