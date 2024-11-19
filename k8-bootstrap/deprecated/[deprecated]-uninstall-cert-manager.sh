#!/bin/bash

source k8-config.env

aws_region=$(aws configure get region)
cluster_name=$(aws eks list-clusters | jq -r '.clusters[0]')
account_id=$(aws sts get-caller-identity --query Account --output text)
hosted_zone=$HOSTED_ZONE
hosted_zone_id=$HOSTED_ZONE_ID

#------Uninstalling Cert Manager
cert_manager_sa="cert-manager-acme-dns01-route53"
cert_manager_namespace="cert-manager"
cert_manager_iam_policy_name="CertManagerIAMPolicy"
email_address="yourmail@mail.com"


kubectl delete -f - <<EOF
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

kubectl delete -f - <<EOF
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

eksctl delete iamserviceaccount \
    --name $cert_manager_sa  \
    --cluster $cluster_name \
    --namespace $cert_manager_namespace

cert_manager_iam_policy_arn=$(aws iam list-policies --query 'Policies[?starts_with(PolicyName,`'"$cert_manager_iam_policy_name"'`)]' | jq -r '.[0].Arn')

#echo $cert_manager_iam_policy_arn

aws iam delete-policy --policy-arn $cert_manager_iam_policy_arn

helm uninstall -n cert-manager cert-manager