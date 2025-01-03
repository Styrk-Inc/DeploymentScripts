#!/bin/bash

# Set Variables for Master
AWS_ACCOUNT_ID_MASTER="637423168201"
ECR_REPO_NAME_MASTER="detect-vardaan"
MASTER_STACK_NAME="Master-eks-detect-stack"
MASTER_TEMPLATE_BODY="file://eks-master-infra.yaml"
MASTER_REGION="us-east-1"  # Change this as per your AWS Region
MasterNodeGroupDesiredSize="2"
MasterNodeGroupMinSize="2"
MasterNodeGroupMaxSize="3"
MasterSSHKeyname="styrk_detect"
MasterInstanceType="t2.2xlarge"
Master_KMS_KEY_ARN="arn:aws:kms:us-east-1:637423168201:key/34bc7fb0-8509-41fc-8673-8d0a08e58228"

#Set Variables for Worker
CLIENT_ROLE_ARN="arn-of-role-to-create-the-resources"
AWS_ACCOUNT_ID_WORKER="637423168201"
ECR_REPO_NAME_WORKER="detect-vardaan" 
WORKER_STACK_NAME="Worker-eks-detect-stack"
WORKER_TEMPLATE_BODY="file://eks-worker-infra.yaml"
WORKER_REGION="us-east-1"  # Change this as per your AWS Region
WorkerNodeGroupDesiredSize="2"
WorkerNodeGroupMinSize="2"
WorkerNodeGroupMaxSize="5"
WorkerSSHKeyname="styrk_detect"
Worker_KMS_KEY_ARN="arn:aws:kms:us-east-1:637423168201:key/34bc7fb0-8509-41fc-8673-8d0a08e58228"

#   For CPU Configuration
# WorkerInstanceType="c5.9xlarge"
# WorkerInstanceAMIType="AL2_x86_64"  #For CPU Machine use this architecture "AL2_x86_64"

#   For GPU Configuration
WorkerInstanceType="g5.4xlarge"
WorkerInstanceAMIType="AL2_x86_64_GPU"  #For GPU Machine use this architecture "AL2_x86_64_GPU"

#Godaddy Parameters for domain
API_KEY="pass-api-key-godaddy"
API_SECRET="pass-api-secret-godaddy"
DOMAIN="styrk.ai"
SUBDOMAIN="vardaan.detect"
RECORD_TYPE="A"
TTL="600"
IP_UI="10.0.0.0"
IP_API="10.0.0.0"
IP_Airflow="0.0.0.0"
IP_Greylog="0.0.0.0"
PREFIX_UI="ui"
PREFIX_API="api"
PREFIX_AIRFLOW="airflow"
PREFIX_GRAYLOG="graylog"

#Cognito Parameters
COGNITO_CLIENT_ID="pass-cognito-client-id"
COGNITO_USER_POOL_ID="pass-cognito-user-pool-id"
COGNITO_REGION="us-east-1"
ADMIN_USER="admin"


#Secret Manager Parameters.
secret_name="Defend-Secret-infra"
region_name="us-east-1"
source_account_id="637423168201"
role_name="Defend_Secret_Role"
k8s_secret_name="aitrism-aws"
namespace="default"

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
EIP_NAME_Mongo=$Mongo_Eip_2

#RAbbitmq EIPs
Rabbitmq_Eip_1="detect-rabbitmq"
Rabbitmq_Eip_2="detect-rabbitmq-2"
EIP_Name_Rabbitmq=$Rabbitmq_Eip_1

#Graylog EIPs
Graylog_Eip_1="detect-graylog"
Graylog_Eip_2="detect-graylog-2"
EIP_Name_Graylog=$Graylog_Eip_1

#Worker-Node-Exporter_Eip
Worker_Node_Exporter_Eip_1="detect-Worker-Node-Exporter"
Worker_Node_Exporter_Eip_2="detect-Worker-Node-Exporter-2"
Worker_Node_Exporter_Eip=$Worker_Node_Exporter_Eip_2

# # Kafka EIPs
# Kafka_Eip_1="detect-kafka"
# Kafka_Eip_2="detect-kafka-2"
# EIP_NAME_Kafka="$Kafka_Eip_1"

#Docker tag for Web Image
Docker_Web_Tag=web

#Docker tag for Worker Image
Docker_Worker_Tag=worker

#Docker tag for React (UI) Image
Docker_React_Tag=UI

#ECR URI for Docker Images
ECR_URI_MASTER="$AWS_ACCOUNT_ID_MASTER.dkr.ecr.$MASTER_REGION.amazonaws.com/$ECR_REPO_NAME_MASTER"

#Currently ECR_URI_WORKER is not in use, it's for future when we want to run Worker Image in Client's Environment.
ECR_URI_WORKER="$AWS_ACCOUNT_ID_WORKER.dkr.ecr.$WORKER_REGION.amazonaws.com/$ECR_REPO_NAME_WORKER"

