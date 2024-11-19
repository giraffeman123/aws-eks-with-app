# ==================== IAM Roles and Policies ====================
data "aws_iam_policy_document" "assume_codebuild_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "codebuild_project_role" {
  name               = "${var.name}-${var.mandatory_tags.Environment}-codebuild-role"
  assume_role_policy = data.aws_iam_policy_document.assume_codebuild_policy.json
}

resource "aws_iam_policy" "codebuild_policy" {
  name        = "${var.name}-${var.mandatory_tags.Environment}-codebuild-policy"
  description = "A policy for codebuild to write to cloudwatch"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "cloudwatch:*",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        # "Action": ["s3:Get*", "s3:List*"],
        "Action" : ["s3:*"],
        # "Resource": [aws_s3_bucket.codepipeline_bucket.arn],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:ListImages"
        ],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Effect" : "Allow",
        "Action" : "secretsmanager:GetSecretValue",
        "Resource" : [
          "${data.aws_secretsmanager_secret.git_credentials.id}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_codebuild_policy" {
  role       = aws_iam_role.codebuild_project_role.name
  policy_arn = aws_iam_policy.codebuild_policy.arn
}

# ==================== CodeBuild ====================

resource "aws_codebuild_project" "fsa_api_codebuild_project" {
  name          = "${var.fsa_api_docker_image_name}-${var.mandatory_tags.Environment}-codebuild"
  description   = "Codebuild for ${var.fsa_api_docker_image_name}-${var.mandatory_tags.Environment}"
  build_timeout = "30"
  service_role  = aws_iam_role.codebuild_project_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.fsa_api_docker_image_name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.mandatory_tags.Environment
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "GITHUB_TOKEN"
      value = "${data.aws_secretsmanager_secret.git_credentials.id}:GITHUB_TOKEN"
      type  = "SECRETS_MANAGER"
    }

    environment_variable {
      name  = "GITHUB_USER"
      value = "${data.aws_secretsmanager_secret.git_credentials.id}:GITHUB_USER"
      type  = "SECRETS_MANAGER"
    }

    environment_variable {
      name  = "GITHUB_USER_EMAIL"
      value = "${data.aws_secretsmanager_secret.git_credentials.id}:GITHUB_USER_EMAIL"
      type  = "SECRETS_MANAGER"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${var.fsa_api_docker_image_name}-${var.mandatory_tags.Environment}"
      #   stream_name = "codebuild_project-log-stream"
    }
  }

  source {
    type = "CODEPIPELINE"
  }

  tags = var.mandatory_tags
}

resource "aws_codebuild_project" "fsa_webapp_codebuild_project" {
  name          = "${var.fsa_webapp_docker_image_name}-${var.mandatory_tags.Environment}-codebuild"
  description   = "Codebuild for ${var.fsa_webapp_docker_image_name}-${var.mandatory_tags.Environment}"
  build_timeout = "30"
  service_role  = aws_iam_role.codebuild_project_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:7.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "IMAGE_REPO_NAME"
      value = var.fsa_webapp_docker_image_name
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "ENVIRONMENT"
      value = var.mandatory_tags.Environment
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "GITHUB_TOKEN"
      value = "${data.aws_secretsmanager_secret.git_credentials.id}:GITHUB_TOKEN"
      type  = "SECRETS_MANAGER"
    }

    environment_variable {
      name  = "GITHUB_USER"
      value = "${data.aws_secretsmanager_secret.git_credentials.id}:GITHUB_USER"
      type  = "SECRETS_MANAGER"
    }

    environment_variable {
      name  = "GITHUB_USER_EMAIL"
      value = "${data.aws_secretsmanager_secret.git_credentials.id}:GITHUB_USER_EMAIL"
      type  = "SECRETS_MANAGER"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/${var.fsa_webapp_docker_image_name}-${var.mandatory_tags.Environment}"
      #   stream_name = "codebuild_project-log-stream"
    }
  }

  source {
    type = "CODEPIPELINE"
  }

  tags = var.mandatory_tags
}