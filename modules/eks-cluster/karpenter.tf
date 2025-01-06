module "karpenter_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name                          = "karpenter-controller-${var.cluster_name}"
#   attach_karpenter_controller_policy = true

  karpenter_controller_cluster_name = var.cluster_name
  karpenter_controller_node_iam_role_arns = [
    module.eks.eks_managed_node_groups["one"].iam_role_arn
  ]

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  karpenter_controller_ssm_parameter_arns = [
    "arn:aws:ssm:*:*:parameter/aws/service/*"
  ]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["karpenter:karpenter"]
    }
  }
}

resource "aws_iam_role_policy" "karpenter_irsa_custom_policy" {
  name = "KarpenterControllerPolicy-${var.cluster_name}"
  role = module.karpenter_irsa.iam_role_name
  policy = jsonencode(
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Action":[
            "ssm:GetParameter",
            "ec2:DescribeImages",
            "ec2:RunInstances",
            "ec2:DescribeSubnets",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeLaunchTemplates",
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceTypes",
            "ec2:DescribeInstanceTypeOfferings",
            "ec2:DescribeAvailabilityZones",
            "ec2:DeleteLaunchTemplate",
            "ec2:CreateTags",
            "ec2:CreateLaunchTemplate",
            "ec2:CreateFleet",
            "ec2:DescribeSpotPriceHistory",
            "pricing:GetProducts"
         ],
         "Effect":"Allow",
         "Resource":"*",
         "Sid":"Karpenter"
      },
      {
         "Action":"ec2:TerminateInstances",
         "Condition":{
            "StringLike":{
               "ec2:ResourceTag/karpenter.sh/nodepool":"*"
            }
         },
         "Effect":"Allow",
         "Resource":"*",
         "Sid":"ConditionalEC2Termination"
      },
      {
         "Effect":"Allow",
         "Action":"iam:PassRole",
         "Resource":"arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${module.eks.eks_managed_node_groups["one"].iam_role_name}",
         "Sid":"PassNodeIAMRole"
      },
      {
         "Effect":"Allow",
         "Action":"eks:DescribeCluster",
         "Resource":"arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${module.eks.eks_managed_node_groups["one"].iam_role_name}",
         "Sid":"EKSClusterEndpointLookup"
      },
      {
         "Sid":"AllowScopedInstanceProfileCreationActions",
         "Effect":"Allow",
         "Resource":"*",
         "Action":[
            "iam:CreateInstanceProfile"
         ],
         "Condition":{
            "StringEquals":{
               "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}":"owned",
               "aws:RequestTag/topology.kubernetes.io/region":"${data.aws_region.current.name}"
            },
            "StringLike":{
               "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass":"*"
            }
         }
      },
      {
         "Sid":"AllowScopedInstanceProfileTagActions",
         "Effect":"Allow",
         "Resource":"*",
         "Action":[
            "iam:TagInstanceProfile"
         ],
         "Condition":{
            "StringEquals":{
               "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}":"owned",
               "aws:ResourceTag/topology.kubernetes.io/region":"${data.aws_region.current.name}",
               "aws:RequestTag/kubernetes.io/cluster/${var.cluster_name}":"owned",
               "aws:RequestTag/topology.kubernetes.io/region":"${data.aws_region.current.name}"
            },
            "StringLike":{
               "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass":"*",
               "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass":"*"
            }
         }
      },
      {
         "Sid":"AllowScopedInstanceProfileActions",
         "Effect":"Allow",
         "Resource":"*",
         "Action":[
            "iam:AddRoleToInstanceProfile",
            "iam:RemoveRoleFromInstanceProfile",
            "iam:DeleteInstanceProfile"
         ],
         "Condition":{
            "StringEquals":{
               "aws:ResourceTag/kubernetes.io/cluster/${var.cluster_name}":"owned",
               "aws:ResourceTag/topology.kubernetes.io/region":"${data.aws_region.current.name}"
            },
            "StringLike":{
               "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass":"*"
            }
         }
      },
      {
         "Sid":"AllowInstanceProfileReadActions",
         "Effect":"Allow",
         "Resource":"*",
         "Action":"iam:GetInstanceProfile"
      },
      {
         "Effect":"Allow",
         "Action":"iam:CreateServiceLinkedRole",
         "Resource":"arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot",
         "Sid":"CreateServiceLinkedRoleForEC2Spot"
      }
   ]
}
  )
}

resource "aws_iam_instance_profile" "karpenter" {
  name = "KarpenterNodeInstanceProfile-${var.cluster_name}"
  role = module.eks.eks_managed_node_groups["one"].iam_role_name
}

resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "oci://public.ecr.aws/karpenter"
  #   repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  #   repository_password = data.aws_ecrpublic_authorization_token.token.password
  chart   = "karpenter"
  version = "0.37.0"

  set {
    name  = "settings.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.karpenter_irsa.iam_role_arn
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/sts-regional-endpoints"
    value = "true"
    type  = "string"
  }

#   set {
#     name  = "settings.defaultInstanceProfile"
#     value = aws_iam_instance_profile.karpenter.name
#   }

  #   set {
  #     name  = "settings.interruptionQueueName"
  #     value = module.karpenter.queue_name
  #   }  
}

#   --set "settings.clusterName=${CLUSTER_NAME}" \
#   --set "settings.interruptionQueue=${CLUSTER_NAME}" \
#   --set controller.resources.requests.cpu=1 \
#   --set controller.resources.requests.memory=1Gi \
#   --set controller.resources.limits.cpu=1 \
#   --set controller.resources.limits.memory=1Gi \