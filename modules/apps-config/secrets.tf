data "aws_secretsmanager_secret" "db_credentials" {
  name = var.db_credentials_secret
}

