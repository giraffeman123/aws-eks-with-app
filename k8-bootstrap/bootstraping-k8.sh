#!/bin/bash

source k8-config.env

aws_region=$(aws configure get region)
cluster_name=$(aws eks list-clusters | jq -r '.clusters[0]')
account_id=$(aws sts get-caller-identity --query Account --output text)
hosted_zone=$HOSTED_ZONE
hosted_zone_id=$HOSTED_ZONE_ID

aws eks update-kubeconfig --region $aws_region --name $cluster_name

#------Installing Karpenter------
. ./karpenter/install-karpenter.sh

#------Installing External DNS------
external_dns_sa="external-dns"
external_dns_namespace="external-dns"
external_dns_iam_policy_name="AWSExternalDNSIAMPolicy"

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
            - --policy=sync # (valid values are upsert-only, sync) would prevent ExternalDNS from deleting any records, omit to enable full synchronization
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
    --policy-name $alb_controller_iam_policy_name --policy-document file://aws-alb-controller/alb_controller_iam_policy.json | jq -r '.Policy.Arn')    

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

#------Installing ingress-nginx Controller------
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx \
    --version 4.2.3 \
    --namespace kube-system \
    --values ingress-nginx-controller/prod-values.yaml

#kubectl scale deployment ingress-nginx-controller -n kube-system --replicas=3
kubectl -n kube-system get all    

#------Installing Cert Manager
cert_manager_sa="cert-manager-acme-dns01-route53"
cert_manager_namespace="cert-manager"
cert_manager_iam_policy_name="CertManagerIAMPolicy"
email_address=$EMAIL_ADDRESS

helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager --namespace $cert_manager_namespace \
  --create-namespace --set installCRDs=true

kubectl -n cert-manager get all

cert_manager_iam_policy_arn=$(aws iam create-policy \
    --policy-name $cert_manager_iam_policy_name \
    --description "This policy allows cert-manager to manage ACME DNS01 records in Route53 hosted zones. See https://cert-manager.io/docs/configuration/acme/dns01/route53" \
    --policy-document \
    '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "route53:GetChange",
      "Resource": "arn:aws:route53:::change/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "route53:ChangeResourceRecordSets",
        "route53:ListResourceRecordSets"
      ],
      "Resource": "arn:aws:route53:::hostedzone/'"$hosted_zone_id"'"
    },
    {
      "Effect": "Allow",
      "Action": "route53:ListHostedZonesByName",
      "Resource": "*"
    }
  ]
}' | jq -r '.Policy.Arn')

# echo $cert_manager_iam_policy_arn

eksctl create iamserviceaccount --name $cert_manager_sa --namespace $cert_manager_namespace --cluster $cluster_name --role-name $cert_manager_sa --attach-policy-arn $cert_manager_iam_policy_arn --approve

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cert-manager-acme-dns01-route53-tokenrequest
  namespace: $cert_manager_namespace
rules:
  - apiGroups: ['']
    resources: ['serviceaccounts/token']
    resourceNames: ['$cert_manager_sa']
    verbs: ['create']
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cert-manager-acme-dns01-route53-tokenrequest
  namespace: $cert_manager_namespace
subjects:
  - kind: ServiceAccount
    name: cert-manager
    namespace: $cert_manager_namespace
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: cert-manager-acme-dns01-route53-tokenrequest
EOF

AWS_REGION=$aws_region ACCOUNT_ID=$account_id CERT_MANAGER_IRSA=$cert_manager_sa EMAIL_ADDRESS=$email_address envsubst < cert-manager/clusterissuer.yaml | kubectl apply -f -

kubectl get clusterissuer


#------Installing Fluent-Bit------
fluent_bit_sa="fluent-bit"
fluent_bit_namespace="amazon-cloudwatch"
fluent_bit_iam_policy_name="FluentBitIAMPolicy"

fluent_bit_iam_policy_arn=$(aws iam create-policy \
    --policy-name $fluent_bit_iam_policy_name \
    --description "This policy allows Fluent-Bit to send logs to AWS cloudwatch." \
    --policy-document \
    '{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CWACloudWatchServerPermissions",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData",
                "ec2:DescribeVolumes",
                "ec2:DescribeTags",
                "logs:PutLogEvents",
                "logs:PutRetentionPolicy",
                "logs:DescribeLogStreams",
                "logs:DescribeLogGroups",
                "logs:CreateLogStream",
                "logs:CreateLogGroup",
                "xray:PutTraceSegments",
                "xray:PutTelemetryRecords",
                "xray:GetSamplingRules",
                "xray:GetSamplingTargets",
                "xray:GetSamplingStatisticSummaries"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CWASSMServerPermissions",
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/AmazonCloudWatch-*"
        }
    ]
}' | jq -r '.Policy.Arn')

eksctl create iamserviceaccount \
  --cluster $cluster_name \
  --namespace $fluent_bit_namespace \
  --name $fluent_bit_sa \
  --role-name $fluent_bit_sa \
  --attach-policy-arn $fluent_bit_iam_policy_arn \
  --approve   

kubectl -n $fluent_bit_namespace delete serviceaccount $fluent_bit_sa  

helm repo add fluent https://fluent.github.io/helm-charts
fluent_bit_values_file=$(FLUENT_BIT_IRSA=$fluent_bit_sa ACCOUNT_ID=$account_id AWS_REGION=$aws_region CLUSTER_NAME=$cluster_name envsubst < fluent-bit/custom-values.yaml)
echo "$fluent_bit_values_file" > fluent-bit/prod-values.yaml

helm install fluent-bit fluent/fluent-bit \
  --create-namespace --namespace $fluent_bit_namespace \
  -f fluent-bit/prod-values.yaml


# ------Deploying kube-prometheus-stack------
kubectl create ns monitoring
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
kubectl apply -f kube-prometheus-stack/prod-certificate.yaml
helm install -f kube-prometheus-stack/prod-values.yaml kube-prometheus-stack prometheus-community/kube-prometheus-stack --create-namespace --namespace monitoring --version 43.2.1

# ------Installing ArgoCD Controller------
# ------NOTE! FIRST VALIDATE THE GENERATED CERTIFICATE ARN FOR THE ARGOCD DOMAIN AND THEN PASTE IT INTO prod-values.yaml file
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd --create-namespace --namespace argocd
kubectl apply -f argocd/prod-certificate.yaml
kubectl apply -f argocd/prod-ingress.yaml
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d


# ------Installing Istio Controller------
istioctl operator init -f istio-with-prometheus-stack/istio-operator.yaml

kubectl apply -f istio-with-prometheus-stack/prod-certificate.yaml
kubectl apply -f istio-with-prometheus-stack/jaeger/jaeger.yaml
kubectl apply -f istio-with-prometheus-stack/istio-prometheus/prometheus.yaml
kubectl apply -f istio-with-prometheus-stack/istio-prometheus/prod-ingress.yaml
kubectl apply -f istio-with-prometheus-stack/custom-metric.yaml

# ------!!!!!!ATTENTION REQUIRED BEFORE EXECUTING prometheus-stack/istio-service-monitor.yaml!!!!!!------
# kubectl get prometheuses.monitoring.coreos.com --all-namespaces -o jsonpath="{.items[*].spec.serviceMonitorSelector}"
# ------Execute this comand below to find matching labels required for servicemonitor,prometheusrule CRD objects------
# ------If the result of the command returns a value different than the current matching label(release: kube-prometheus-stack)------
# ------Then it would be necessary to update corresponding prometheus operator CRD's with new label------
# ------Examples of this would be istio-with-prometheus-stack/prometheus-stack/istio-service-monitor.yaml------
# ------But also any custom prometheusrule or alert created ------
kubectl apply -f istio-with-prometheus-stack/prometheus-stack/istio-service-monitor.yaml

helm repo add kiali https://kiali.org/helm-charts
helm install --namespace kiali-operator --create-namespace kiali-operator kiali/kiali-operator --version 1.80.0
kubectl apply -f istio-with-prometheus-stack/kiali/kiali.yaml

# kubectl -n istio-system get secret $(kubectl -n istio-system get sa/kiali-service-account -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"
# kubectl get secret -n istio-system $(kubectl get sa kiali-service-account -n istio-system -o "jsonpath={.secrets[0].name}") -o jsonpath={.data.token} | base64 -d


# ------Deploying fsa-stack with argocd------
# ------NOTE! FIRST VALIDATE THE GENERATED CERTIFICATE ARN FOR THE WEBSITE DOMAIN AND THEN PASTE IT INTO fsa-stack-app.yaml file
kubectl apply -f argocd/fsa-stack-app.yaml