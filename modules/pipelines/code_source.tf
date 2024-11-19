resource "aws_iam_policy" "codestar_connection_policy" {
  name        = "${var.name}-${var.mandatory_tags.Environment}-codestar-connection-policy"
  description = "A policy with permissions for codestar connection"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codestar-connections:UseConnection"
        ]
        Resource = [
          aws_codestarconnections_connection.fsa_api_codestar_connection.arn,
          aws_codestarconnections_connection.fsa_webapp_codestar_connection.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_codestar_connection_policy" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codestar_connection_policy.arn
}

# ==================== Codestar Connection ====================
resource "aws_codestarconnections_connection" "fsa_api_codestar_connection" {
  name          = "${var.fsa_api_docker_image_name}-${var.mandatory_tags.Environment}-codestar"
  provider_type = var.fsa_api_repository_provider_type

  tags = var.mandatory_tags
}

resource "aws_codestarconnections_connection" "fsa_webapp_codestar_connection" {
  name          = "${var.fsa_webapp_docker_image_name}-${var.mandatory_tags.Environment}-codestar"
  provider_type = var.fsa_webapp_repository_provider_type

  tags = var.mandatory_tags
}