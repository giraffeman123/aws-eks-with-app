data "aws_secretsmanager_secret" "git_credentials" {
  name = var.fsa_stack_git_credentials_secret
}

# data "aws_secretsmanager_secret_version" "secret_git_credentials" {
#   secret_id = data.aws_secretsmanager_secret.git_credentials.id
# }

