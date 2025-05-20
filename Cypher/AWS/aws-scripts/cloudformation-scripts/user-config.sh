#!/bin/bash

# ===============================
# Environment to be Updated by USER
# ===============================

# Master Configuration
MASTER_STACK_NAME="Master-eks-detect-stack"     # Update Master Stack name
MASTER_REGION="us-east-1"                       # Change this as per your AWS Region
MasterNodeGroupDesiredSize="2"                  # Update DesiredSize of NodeGroup
MasterNodeGroupMinSize="2"                      # Update Minikum Size of NodeGroup
MasterNodeGroupMaxSize="3"                      # Update Max Size of NodeGroup
MasterSSHKeyname="styrk_detect"                 # Update SSH Keyname
MasterInstanceType="t2.2xlarge"                 # Update Master Instance type
Master_KMS_KEY_ARN="arn:aws:kms:us-east-1:637423168201:key/34bc7fb0-8509-41fc-8673-8d0a08e58228"        # Update KMS KEY ARN

# Worker Configuration
WORKER_STACK_NAME="Worker-eks-detect-stack"     # Update Worker Stack name
WORKER_REGION="us-east-1"                       # Change this as per your AWS Region
WorkerNodeGroupDesiredSize="2"                  # Update DesiredSize of NodeGroup
WorkerNodeGroupMinSize="2"                      # Update Minikum Size of NodeGroup
WorkerNodeGroupMaxSize="5"                      # Update Max Size of NodeGroup
WorkerSSHKeyname="styrk_detect"                 # Update SSH Keyname
Worker_KMS_KEY_ARN="arn:aws:kms:us-east-1:637423168201:key/34bc7fb0-8509-41fc-8673-8d0a08e58228"        # Update KMS KEY ARN

# Update Worker Instance type
#   For CPU Configuration
# WorkerInstanceType="c5.9xlarge"
# WorkerInstanceAMIType="AL2_x86_64"             #For CPU Machine use this architecture "AL2_x86_64"

#   For GPU Configuration
WorkerInstanceType="g5.4xlarge"
WorkerInstanceAMIType="AL2_x86_64_GPU"           #For GPU Machine use this architecture "AL2_x86_64_GPU"

#Cognito Parameters
COGNITO_CLIENT_ID="pass-cognito-client-id"          # Update Cognito Client ID
COGNITO_USER_POOL_ID="pass-cognito-user-pool-id"    # Update Cognito User Pool ID
COGNITO_REGION="us-east-1"                          # Update Cognito Region
COGNITO_USER_MAIL_ID="user@domain.com"              # Provide Mail ID of the Cognito User

#Secret Manager Parameters.
secret_name="Defend-Secret-infra"                   # Secret Name
region_name="us-east-1"                             # AWS Region for Secrets Manager
source_account_id="637423168201"                    # AWS Account ID
role_name="Defend_Secret_Role"                      # Role Name for Secret Access


# Cross-account role details
ROLE_ARN="arn:aws:iam::123456789012:role/CrossAccountRoleName"  # Replace <SOURCE_ACCOUNT_ID> and <ROLE_NAME>
SESSION_NAME="NewSession"                                       # Replace session_name with any desired value (temporary)
EXTERNAL_ID="external-id-12345"                                 # Replace <ECR_ROLE_EXTERNAL_ID> with the provider's external ID
REGION="us-east-1"                                              # Replace with the desired AWS Region


# # Cross-Account ECR Access Setup
# ECR_ROLE_ARN="arn:aws:iam::637423168201:role/edna-ecr-role"     # Replace <SOURCE_ACCOUNT_ID> and <ROLE_NAME>
# ECR_ROLE_SESSION_NAME="ECRAssumeRoleSession"                    # Replace session_name with any desired value (temporary)
# ECR_ROLE_EXTERNAL_ID="external-id-12345"                        # Replace <ECR_ROLE_EXTERNAL_ID> with the provider's external ID


# ===============================
# Leave These Fields Unchanged (Do Not Edit)
# ===============================

#Secret Manager Parameters.
AWS_REGION="us-east-1"
SECRET_NAME="Defend-Secret-infra"
K8S_SECRET_NAME="aitrism-aws"
K8S_NAMESPACE="default"

# Variables for Master
AWS_ACCOUNT_ID_MASTER="637423168201"
ECR_REPO_NAME_MASTER="edna-detect"
MASTER_TEMPLATE_BODY="file://eks-master-infra.yaml"


# Variables for Worker
CLIENT_ROLE_ARN="arn-of-role-to-create-the-resources"
AWS_ACCOUNT_ID_WORKER="637423168201"
ECR_REPO_NAME_WORKER="edna-detect" 
WORKER_TEMPLATE_BODY="file://eks-worker-infra.yaml"

# ===============================
# Elastic IPs for Services
# ===============================

# Master EIPs
Master_Eip_1="detect-master"
Master_Eip_2="detect-master-2"
EIP_NAME_Master="$Master_Eip_1"

# # React EIPs
# React_Eip_1="detect-reactapp"
# React_Eip_2="detect-reactapp-2"
# EIP_NAME_React="$React_Eip_1"

#Mongo EIPs
Mongo_Eip_1="detect-mongo"
Mongo_Eip_2="detect-mongo-2"
EIP_NAME_Mongo="$Mongo_Eip_1"

#RAbbitmq EIPs
Rabbitmq_Eip_1="detect-rabbitmq"
Rabbitmq_Eip_2="detect-rabbitmq-2"
EIP_Name_Rabbitmq="$Rabbitmq_Eip_1"

#Graylog EIPs
Graylog_Eip_1="detect-graylog"
Graylog_Eip_2="detect-graylog-2"
EIP_Name_Graylog="$Graylog_Eip_1"

#Worker-Node-Exporter_Eip
Worker_Node_Exporter_Eip_1="detect-Worker-Node-Exporter"
Worker_Node_Exporter_Eip_2="detect-Worker-Node-Exporter-2"
Worker_Node_Exporter_Eip=$Worker_Node_Exporter_Eip_2

# # Kafka EIPs
# Kafka_Eip_1="detect-kafka"
# Kafka_Eip_2="detect-kafka-2"
# EIP_NAME_Kafka="$Kafka_Eip_1"

# ===============================
# Docker Tags for Images
# ===============================

#Docker tag for Web Image
Docker_Web_Tag=web

#Docker tag for Worker Image
Docker_Worker_Tag=worker

#Docker tag for React (UI) Image
Docker_React_Tag=UI

# ===============================
# ECR URIs
# ===============================

#ECR URI for Docker Images
ECR_URI_MASTER="$AWS_ACCOUNT_ID_MASTER.dkr.ecr.$MASTER_REGION.amazonaws.com/$ECR_REPO_NAME_MASTER"

#Currently ECR_URI_WORKER is not in use, it's for future when we want to run Worker Image in Client's Environment.
ECR_URI_WORKER="$AWS_ACCOUNT_ID_WORKER.dkr.ecr.$WORKER_REGION.amazonaws.com/$ECR_REPO_NAME_WORKER"

