data "aws_secretsmanager_secret" "db_credentials" {
  name = var.db_credentials_secret
}

data "aws_secretsmanager_secret_version" "secret_db_credentials" {
  secret_id = data.aws_secretsmanager_secret.db_credentials.id
}

