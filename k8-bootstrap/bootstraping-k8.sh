#!/bin/bash

source k8-config.env

aws_region=$(aws configure get region)
cluster_name=$(aws eks list-clusters | jq -r '.clusters[0]')
account_id=$(aws sts get-caller-identity --query Account --output text)
hosted_zone=$HOSTED_ZONE
hosted_zone_id=$HOSTED_ZONE_ID

external_dns_sa="external-dns"
external_dns_namespace="external-dns"
external_dns_iam_policy_name="AWSExternalDNSIAMPolicy"

aws eks update-kubeconfig --region $aws_region --name $cluster_name

#------Installing External DNS------
external_dns_iam_policy_arn=$(aws iam create-policy \
    --policy-name $external_dns_iam_policy_name \
    --policy-document \
    '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": [
                "arn:aws:route53:::hostedzone/'"$hosted_zone_id"'"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:ListResourceRecordSets",                
                "route53:ListTagsForResource"                
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}' | jq -r '.Policy.Arn')

#echo $external_dns_iam_policy_arn

eksctl create iamserviceaccount --name $external_dns_sa --namespace $external_dns_namespace --cluster $cluster_name --role-name $external_dns_sa --attach-policy-arn $external_dns_iam_policy_arn --approve

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: external-dns
  labels:
    app.kubernetes.io/name: external-dns
rules:
  - apiGroups: [""]
    resources: ["services","endpoints","pods","nodes"]
    verbs: ["get","watch","list"]
  - apiGroups: ["extensions","networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get","watch","list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: external-dns-viewer
  labels:
    app.kubernetes.io/name: external-dns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: external-dns
subjects:
  - kind: ServiceAccount
    name: $external_dns_sa
    namespace: $external_dns_namespace # change to desired namespace: externaldns, kube-addons
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: external-dns
  namespace: $external_dns_namespace   
  labels:
    app.kubernetes.io/name: external-dns  
spec:
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app.kubernetes.io/name: external-dns
  template:
    metadata:
      labels:
        app.kubernetes.io/name: external-dns
    spec:
      serviceAccountName: $external_dns_sa
      containers:
        - name: external-dns
          image: registry.k8s.io/external-dns/external-dns:v0.14.0
          args:
            - --source=service
            - --source=ingress
            - --domain-filter=$hosted_zone # will make ExternalDNS see only the hosted zones matching provided domain, omit to process all available hosted zones
            - --provider=aws
            - --policy=upsert-only # would prevent ExternalDNS from deleting any records, omit to enable full synchronization
            - --aws-zone-type=public # only look at public hosted zones (valid values are public, private or no value for both)
            - --registry=txt
            - --txt-owner-id=external-dns
          env:
            - name: AWS_DEFAULT_REGION
              value: $aws_region # change to region where EKS is installed
EOF

kubectl -n external-dns get all
kubectl -n external-dns get sa 

#------Installing ALB Controller------
alb_controller_sa="aws-load-balancer-controller"
alb_controller_iam_policy_name="AWSLoadBalancerControllerIAMPolicy"

alb_controller_iam_policy_arn=$(aws iam create-policy \
    --policy-name $alb_controller_iam_policy_name --policy-document file://alb_controller_iam_policy.json | jq -r '.Policy.Arn')    

eksctl create iamserviceaccount \
  --cluster $cluster_name \
  --namespace kube-system \
  --name $alb_controller_sa \
  --role-name $alb_controller_sa \
  --attach-policy-arn $alb_controller_iam_policy_arn \
  --approve    

helm repo add eks https://aws.github.io/eks-charts
helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system \
  --set clusterName=$cluster_name \
  --set serviceAccount.create=false --set serviceAccount.name=$alb_controller_sa \
  
kubectl -n kube-system get all

#------Installing ArgoCD Controller------
#------NOTE! FIRST VALIDATE THE GENERATED CERTIFICATE ARN FOR THE ARGOCD DOMAIN AND THEN PASTE IT INTO argocd-prod-values.yaml file
# helm repo add argo https://argoproj.github.io/argo-helm
# helm install argocd argo/argo-cd -f argocd/argocd-prod-values.yaml --create-namespace --namespace argocd
# kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

#------Deploying fsa-stack with argocd------
#------NOTE! FIRST VALIDATE THE GENERATED CERTIFICATE ARN FOR THE WEBSITE DOMAIN AND THEN PASTE IT INTO fsa-stack-app.yaml file
# kubectl apply -f argocd/fsa-stack-app.yaml