#!/bin/bash

# cluster_endpoint=""
# oidc_endpoint="$(aws eks describe-cluster --name ${cluster_name} \
#   --query "cluster.identity.oidc.issuer" --output text)"

# echo ${oidc_endpoint#*//}

# karpenter_node_role_name="KarpenterNodeRole-${cluster_name}"
# karpenter_node_instance_profile_name="KarpenterNodeInstanceProfile-${cluster_name}"

# karpenter_controller_role_name="KarpenterControllerRole-${cluster_name}"
# karpenter_controller_role_policy_name="KarpenterControllerPolicy-${cluster_name}"

# aws iam create-role --role-name $karpenter_node_role_name \
#     --assume-role-policy-document \
#     '{
#       "Version": "2012-10-17",
#       "Statement": [
#           {
#               "Effect": "Allow",
#               "Principal": {
#                   "Service": "ec2.amazonaws.com"
#               },
#               "Action": "sts:AssumeRole"
#           }
#       ]    
#     }'

# aws iam attach-role-policy --role-name $karpenter_node_role_name \
#     --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy

# aws iam attach-role-policy --role-name $karpenter_node_role_name \
#     --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy

# aws iam attach-role-policy --role-name $karpenter_node_role_name \
#     --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

# aws iam attach-role-policy --role-name $karpenter_node_role_name \
#     --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore    

# aws iam create-instance-profile --instance-profile-name $karpenter_node_instance_profile_name

# aws iam add-role-to-instance-profile \
# --instance-profile-name $karpenter_node_instance_profile_name \
# --role-name $karpenter_node_role_name

# aws iam create-role --role-name $karpenter_controller_role_name \
#     --assume-role-policy-document \
#     '
#     {
#         "Version": "2012-10-17",
#         "Statement": [
#             {
#                 "Effect": "Allow",
#                 "Principal": {
#                     "Federated": "arn:aws:iam::'"$account_id"':oidc-provider/'"${oidc_endpoint#*//}"'"
#                 },
#                 "Action": "sts:AssumeRoleWithWebIdentity",
#                 "Condition": {
#                     "StringEquals": {
#                         "'"${oidc_endpoint#*//}"':aud": "sts.amazonaws.com",
#                         "'"${oidc_endpoint#*//}"':sub": "system:serviceaccount:karpenter:karpenter"
#                     }
#                 }
#             }
#         ]
#     }    
#     '

# aws iam put-role-policy --role-name $karpenter_controller_role_name \
#     --policy-name $karpenter_controller_role_policy_name \
#     --policy-document \
#     '
#     {
#       "Version":"2012-10-17",
#       "Statement":[
#           {
#             "Action":[
#                 "ssm:GetParameter",
#                 "ec2:DescribeImages",
#                 "ec2:RunInstances",
#                 "ec2:DescribeSubnets",
#                 "ec2:DescribeSecurityGroups",
#                 "ec2:DescribeLaunchTemplates",
#                 "ec2:DescribeInstances",
#                 "ec2:DescribeInstanceTypes",
#                 "ec2:DescribeInstanceTypeOfferings",
#                 "ec2:DescribeAvailabilityZones",
#                 "ec2:DeleteLaunchTemplate",
#                 "ec2:CreateTags",
#                 "ec2:CreateLaunchTemplate",
#                 "ec2:CreateFleet",
#                 "ec2:DescribeSpotPriceHistory",
#                 "pricing:GetProducts"
#             ],
#             "Effect":"Allow",
#             "Resource":"*",
#             "Sid":"Karpenter"
#           },
#           {
#             "Action":"ec2:TerminateInstances",
#             "Condition":{
#                 "StringLike":{
#                   "ec2:ResourceTag/karpenter.sh/nodepool":"*"
#                 }
#             },
#             "Effect":"Allow",
#             "Resource":"*",
#             "Sid":"ConditionalEC2Termination"
#           },
#           {
#             "Effect":"Allow",
#             "Action":"iam:PassRole",
#             "Resource":"arn:aws:iam::'"$account_id"':role/'"$karpenter_node_role_name"'",
#             "Sid":"PassNodeIAMRole"
#           },
#           {
#             "Effect":"Allow",
#             "Action":"eks:DescribeCluster",
#             "Resource":"arn:aws:iam::'"$account_id"':role/'"$karpenter_node_role_name"'",
#             "Sid":"EKSClusterEndpointLookup"
#           },
#           {
#             "Sid":"AllowScopedInstanceProfileCreationActions",
#             "Effect":"Allow",
#             "Resource":"*",
#             "Action":[
#                 "iam:CreateInstanceProfile"
#             ],
#             "Condition":{
#                 "StringEquals":{
#                   "aws:RequestTag/kubernetes.io/cluster/'"$cluster_name"'":"owned",
#                   "aws:RequestTag/topology.kubernetes.io/region":"'"$aws_region"'"
#                 },
#                 "StringLike":{
#                   "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass":"*"
#                 }
#             }
#           },
#           {
#             "Sid":"AllowScopedInstanceProfileTagActions",
#             "Effect":"Allow",
#             "Resource":"*",
#             "Action":[
#                 "iam:TagInstanceProfile"
#             ],
#             "Condition":{
#                 "StringEquals":{
#                   "aws:ResourceTag/kubernetes.io/cluster/'"$cluster_name"'":"owned",
#                   "aws:ResourceTag/topology.kubernetes.io/region":"'"$aws_region"'",
#                   "aws:RequestTag/kubernetes.io/cluster/'"$cluster_name"'":"owned",
#                   "aws:RequestTag/topology.kubernetes.io/region":"'"$aws_region"'"
#                 },
#                 "StringLike":{
#                   "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass":"*",
#                   "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass":"*"
#                 }
#             }
#           },
#           {
#             "Sid":"AllowScopedInstanceProfileActions",
#             "Effect":"Allow",
#             "Resource":"*",
#             "Action":[
#                 "iam:AddRoleToInstanceProfile",
#                 "iam:RemoveRoleFromInstanceProfile",
#                 "iam:DeleteInstanceProfile"
#             ],
#             "Condition":{
#                 "StringEquals":{
#                   "aws:ResourceTag/kubernetes.io/cluster/'"$cluster_name"'":"owned",
#                   "aws:ResourceTag/topology.kubernetes.io/region":"'"$aws_region"'"
#                 },
#                 "StringLike":{
#                   "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass":"*"
#                 }
#             }
#           },
#           {
#             "Sid":"AllowInstanceProfileReadActions",
#             "Effect":"Allow",
#             "Resource":"*",
#             "Action":"iam:GetInstanceProfile"
#           },
#           {
#             "Effect":"Allow",
#             "Action":"iam:CreateServiceLinkedRole",
#             "Resource":"arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot",
#             "Sid":"CreateServiceLinkedRoleForEC2Spot"
#           }
#       ]
#     }    
#     '

# for nodegroup in $(aws eks list-nodegroups --cluster-name ${cluster_name} \
#     --query 'nodegroups' --output text); do aws ec2 create-tags \
#         --tags "Key=karpenter.sh/discovery,Value=${cluster_name}" \
#         --resources $(aws eks describe-nodegroup --cluster-name ${cluster_name} \
#         --nodegroup-name $nodegroup --query 'nodegroup.subnets' --output text )
# done

# nodegroup=$(aws eks list-nodegroups --cluster-name ${cluster_name} \
#     --query 'nodegroups[0]' --output text)

# launch_template=$(aws eks describe-nodegroup --cluster-name ${cluster_name} \
#     --nodegroup-name ${nodegroup} --query 'nodegroup.launchTemplate.{id:id,version:version}' \
#     --output text | tr -s "\t" ",")

# security_groups=$(aws eks describe-cluster \
#     --name ${cluster_name} --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" --output text)

# aws ec2 create-tags \
#     --tags "Key=karpenter.sh/discovery,Value=${cluster_name}" \
#     --resources ${security_groups}

# # ATTENTION!!!!!!! 
# # This is a manual step and needs to be executed before installing karpenter helm chart
# kubectl edit configmap aws-auth -n kube-system    

# helm upgrade --install --namespace karpenter --create-namespace \
#   karpenter oci://public.ecr.aws/karpenter/karpenter \
#   --version ${karpenter_version} \
#   --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="arn:aws:iam::${account_id}:role/${karpenter_controller_role_name}" \
#   --set settings.clusterEndpoint=${cluster_endpoint} \
#   --set settings.clusterName=${cluster_name} \
#   --wait                

karpenter_version=v0.37.0
karpenter_node_role_name="node-group-1-eks-node-group"
# karpenter_node_instance_profile="KarpenterNodeInstanceProfile-${cluster_name}"

echo $karpenter_node_instance_profile

kubectl get pod -n karpenter

# kubectl apply -f https://raw.githubusercontent.com/aws/karpenter/${karpenter_version}/pkg/apis/crds/karpenter.sh_nodepools.yaml
# kubectl apply -f https://raw.githubusercontent.com/aws/karpenter/${karpenter_version}/pkg/apis/crds/karpenter.sh_nodeclaims.yaml
# kubectl apply -f https://raw.githubusercontent.com/aws/karpenter/${karpenter_version}/pkg/apis/crds/karpenter.k8s.aws_ec2nodeclasses.yaml

kubectl apply -f karpenter/nodepool.yaml
KARPENTER_NODE_ROLE_NAME=$karpenter_node_role_name CLUSTER_NAME=$cluster_name envsubst < karpenter/ec2nodeclass.yaml | kubectl apply -f -

kubectl get NodePool
kubectl get EC2NodeClass