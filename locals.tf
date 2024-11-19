resource "random_string" "random" {
  length  = 8
  special = false
  lower   = true
}

locals {
  constructed_cluster_name = "${var.cluster_name}-${module.tags.mandatory_tags.Environment}-${random_string.random.result}"
}