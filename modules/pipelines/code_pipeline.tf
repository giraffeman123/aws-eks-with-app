data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "codepipeline_role" {
  name = "${var.name}-${var.mandatory_tags.Environment}-codepipeline-role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        "Sid" : "",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "codepipeline.amazonaws.com"
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "codepipeline_execution_policy" {
  name        = "${var.name}-${var.mandatory_tags.Environment}-codepipeline-policy"
  description = "A policy with permissions for codepipeline"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow"
        "Action" : ["codebuild:StartBuild", "codebuild:BatchGetBuilds"],
        "Resource" : "*",
      },
      {
        "Action" : ["cloudwatch:*"],
        "Resource" : "*",
        "Effect" : "Allow"
      },
      {
        "Action" : ["s3:Get*", "s3:List*", "s3:PutObject"],
        "Resource" : "*",
        "Effect" : "Allow"
      }
      #   ,
      #   {
      #     "Action" : ["codedeploy:CreateDeployment", "codedeploy:GetDeploymentConfig"],
      #     "Resource" : "*",
      #     "Effect" : "Allow"
      #   }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_codepipeline_execution_policy" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codepipeline_execution_policy.arn
}

resource "aws_codepipeline" "pipeline" {
  name     = "${var.name}-${var.mandatory_tags.Environment}-codepipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "${var.fsa_api_docker_image_name}-Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["${var.fsa_api_docker_image_name}_source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.fsa_api_codestar_connection.arn
        FullRepositoryId = var.fsa_api_repository_url # IMPORTANT: put here url of your repository ("github.com/username/repo.git")
        BranchName       = var.fsa_api_repository_branch
      }
    }

    action {
      name             = "${var.fsa_webapp_docker_image_name}-Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["${var.fsa_webapp_docker_image_name}_source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.fsa_webapp_codestar_connection.arn
        FullRepositoryId = var.fsa_webapp_repository_url # IMPORTANT: put here url of your repository ("github.com/username/repo.git")
        BranchName       = var.fsa_webapp_repository_branch
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "${var.fsa_api_docker_image_name}-Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["${var.fsa_api_docker_image_name}_source_output"]
      output_artifacts = ["${var.fsa_api_docker_image_name}_build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.fsa_api_codebuild_project.name
      }
    }

    action {
      name             = "${var.fsa_webapp_docker_image_name}-Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["${var.fsa_webapp_docker_image_name}_source_output"]
      output_artifacts = ["${var.fsa_webapp_docker_image_name}_build_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.fsa_webapp_codebuild_project.name
      }
    }
  }

  #   stage {
  #     name = "Deploy"
  #     action {
  #       name            = "Deploy"
  #       category        = "Deploy"
  #       owner           = "AWS"
  #       provider        = "CodeDeploy"
  #       input_artifacts = ["build_output"]
  #       version         = "1"
  #       configuration = {
  #         ApplicationName  = aws_codedeploy_app.codedeploy_app.name
  #         DeploymentGroupName = aws_codedeploy_deployment_group.deployment_group.deployment_group_name
  #       }
  #     }
  #   }

  tags = var.mandatory_tags
}