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


#------Uninstalling ArgoCD Controller------
helm uninstall argocd -n argocd
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

#------Uninstalling External DNS
kubectl delete -f - <<EOF
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


eksctl delete iamserviceaccount \
    --name $external_dns_sa  \
    --cluster $cluster_name \
    --namespace $external_dns_namespace

external_dns_iam_policy_arn=$(aws iam list-policies --query 'Policies[?starts_with(PolicyName,`'"$external_dns_iam_policy_name"'`)]' | jq -r '.[0].Arn')

#echo $external_dns_iam_policy_arn

aws iam delete-policy --policy-arn $external_dns_iam_policy_arn

kubectl -n external-dns get all
kubectl -n external-dns get sa


#------Uninstalling ALB Controller
alb_controller_sa="aws-load-balancer-controller"
alb_controller_namespace="cert-manager"
alb_controller_iam_policy_name="AWSLoadBalancerControllerIAMPolicy"

eksctl delete iamserviceaccount \
    --name $alb_controller_sa  \
    --cluster $cluster_name \
    --namespace kube-system

alb_controller_iam_policy_arn=$(aws iam list-policies --query 'Policies[?starts_with(PolicyName,`'"$alb_controller_iam_policy_name"'`)]' | jq -r '.[0].Arn')

#echo $cert_manager_iam_policy_arn

aws iam delete-policy --policy-arn $alb_controller_iam_policy_arn

helm uninstall -n kube-system aws-load-balancer-controller

