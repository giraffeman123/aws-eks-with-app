#!/bin/bash

source k8-config.env

aws_region=$(aws configure get region)
cluster_name=$(aws eks list-clusters | jq -r '.clusters[0]')
account_id=$(aws sts get-caller-identity --query Account --output text)
hosted_zone=$HOSTED_ZONE
hosted_zone_id=$HOSTED_ZONE_ID

#------Installing Cert Manager
cert_manager_sa="cert-manager-acme-dns01-route53"
cert_manager_namespace="cert-manager"
cert_manager_iam_policy_name="CertManagerIAMPolicy"
email_address="yourmail@mail.com"

helm repo add jetstack https://charts.jetstack.io
helm repo update
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
      "Resource": "arn:aws:route53:::hostedzone/*"
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

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-production
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $email_address
    privateKeySecretRef:
      name: letsencrypt-production
    solvers:
    - dns01:
        route53:
          region: $aws_region
          role: arn:aws:iam::$account_id:role/$cert_manager_sa
          auth:
            kubernetes:
              serviceAccountRef:
                name: $cert_manager_sa
EOF               