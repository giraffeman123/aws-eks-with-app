resource "kubernetes_namespace" "fsa_stack" {
  metadata {
    annotations = {
      name = "${var.applications["fsa-stack"]["namespace"]}"
    }

    # labels = {
    #   istio-injection = "enabled"
    # }

    name = var.applications["fsa-stack"]["namespace"]
  }
}

resource "aws_iam_policy" "fsa_api_policy" {
  name        = "${var.applications["fsa-stack"]["fsa_api_irsa_name"]}-policy"
  path        = "/"
  description = "Policy for iam-service-account ${var.applications["fsa-stack"]["fsa_api_irsa_name"]}"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "secretsmanager:GetSecretValue",
          ],
          "Resource" : [
            "${data.aws_secretsmanager_secret.db_credentials.id}"
          ]
        }
      ]
    }
  )
}

module "fsa_api_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = var.applications["fsa-stack"]["fsa_api_irsa_name"]

  role_policy_arns = {
    policy = aws_iam_policy.fsa_api_policy.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.cluster_oidc_provider_arn
      namespace_service_accounts = ["${var.applications["fsa-stack"]["namespace"]}:${var.applications["fsa-stack"]["fsa_api_irsa_name"]}"]
    }
  }
}

resource "kubernetes_service_account" "service_account" {
  metadata {
    name      = var.applications["fsa-stack"]["fsa_api_irsa_name"]
    namespace = var.applications["fsa-stack"]["namespace"]
    labels = {
      "app.kubernetes.io/name" = "${var.applications["fsa-stack"]["fsa_api_irsa_name"]}"
      #   "app.kubernetes.io/component" = "controller"
    }
    annotations = {
      "eks.amazonaws.com/role-arn"               = module.fsa_api_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }
}

