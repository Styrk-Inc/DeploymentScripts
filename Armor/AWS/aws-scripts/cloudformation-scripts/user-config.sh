#!/bin/bash

# ===============================
# Environment to be Updated by USER
# ===============================

# Master Configuration
MASTER_STACK_NAME="Defend-Master-eks-stack"
MASTER_REGION="us-east-1"  # Change this as per your AWS Region
MasterNodeGroupDesiredSize="2"
MasterNodeGroupMinSize="2"
MasterNodeGroupMaxSize="3"
MasterSSHKeyname="styrk_defend"
MasterInstanceType="t2.xlarge"
Master_KMS_KEY_ARN="arn:aws:kms:us-east-1:12345678:key/34bc7fb0-8509-41fc-8673-8509-41fc"

# Worker Configuration
WORKER_STACK_NAME="Defend-Worker-eks-stack"
WORKER_REGION="us-east-1"  # Change this as per your AWS Region
WorkerNodeGroupDesiredSize="2"
WorkerNodeGroupMinSize="2"
WorkerNodeGroupMaxSize="4"
WorkerSSHKeyname="styrk_defend"
WorkerInstanceType="g5.4xlarge"
WorkerInstanceAMIType="AL2_x86_64_GPU"  #For CPU Machine change this to "AL2_x86_64"
Worker_KMS_KEY_ARN="arn:aws:kms:us-east-1:12345678:key/34bc7fb0-8509-41fc-8673-34bc7fb0"

#Cognito Parameters
COGNITO_CLIENT_ID="pass-cognito-client-id"          # Update Cognito Client ID
COGNITO_USER_POOL_ID="pass-cognito-user-pool-id"    # Update Cognito User Pool ID
COGNITO_REGION="us-east-1"                          # Update Cognito Region
COGNITO_USER_MAIL_ID="user@domain.com"              # Provide Mail ID of the Cognito User

# Cross-account role details
ROLE_ARN="arn:aws:iam::123456789012:role/CrossAccountRoleName"
SESSION_NAME="NewSession"
EXTERNAL_ID="external-id-12345"
REGION="us-east-1"

# ===============================
# Leave These Fields Unchanged (Do Not Edit)
# ===============================

#Secret Manager Parameters.
AWS_REGION="us-east-1"
SECRET_NAME="Defend-Secret-infra"
K8S_SECRET_NAME="aitrism-aws"
K8S_NAMESPACE="default"

# #Secret Manager Parameters.
# secret_name="Defend-Secret-infra"                   # Secret Name
# region_name="us-east-1"                             # AWS Region for Secrets Manager
# source_account_id="637423168201"                    # AWS Account ID
# role_name="Defend_Secret_Role"                      # Role Name for Secret Access

# Variables for Master
MASTER_TEMPLATE_BODY="file://eks-master-infra.yaml"
#AWS Account ID
AWS_ACCOUNT_ID="637423168201"
#AWS_ACCOUNT_ID="975757560751"   #(Use this for Infrablok Account)

#AWS ECR REPO NAME
ECR_REPO_NAME_MASTER="defend-vardaan"
ECR_REPO_NAME_WORKER="name-of-worker-repo" #Currently not in use.

# Variables for Worker
CLIENT_ROLE_ARN="arn-of-role-to-create-the-resources"
WORKER_TEMPLATE_BODY="file://eks-worker-infra.yaml"

# ===============================
# Elastic IPs for Services
# ===============================

# Master EIPs
Master_Eip_1="aitrism-master"
Master_Eip_2="aitrism-master-2"
EIP_NAME_Master="$Master_Eip_1"

# React EIPs
React_Eip_1="aitrism-reactapp"
React_Eip_2="aitrism-reactapp-2"
EIP_NAME_React="$React_Eip_1"

# Kafka EIPs
Kafka_Eip_1="aitrism-kafka"
Kafka_Eip_2="aitrism-kafka-2"
EIP_NAME_Kafka="$Kafka_Eip_1"

#Docker tag for Web Image
Docker_Web_Tag=web

#Docker tag for Worker Image
Docker_Worker_Tag=worker

#Docker tag for React (UI) Image
Docker_React_Tag=UI

#Docker tag for (Kafka-consumer) Image
Docker_Kafka_Consumer_Tag=kafka_consumer

#Docker tag for (ntp-deamonset) Image
Docker_NTP_Tag=deamonset

# #Docker tag (For any other image) Image
# Docker_React_Tag=anyname

#ECR URI for Docker Images
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$MASTER_REGION.amazonaws.com/$ECR_REPO_NAME_MASTER"

#Currently ECR_URI_WORKER is not in use, it's for future when we want to run Worker Image in Client's Environment.
ECR_URI_WORKER="$AWS_ACCOUNT_ID.dkr.ecr.$WORKER_REGION.amazonaws.com/$ECR_REPO_NAME_WORKER"

