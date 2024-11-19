locals {
  mandatory_tags = {
    Application    = var.application,
    Project        = var.project,
    Team           = var.team,
    Environment    = var.environment,
    Owner          = var.owner,
    ProjectVersion = var.project_version,
    Contact        = var.contact,
    CostCenter     = var.cost_center
  }

  Sensitive = var.sensitive
}