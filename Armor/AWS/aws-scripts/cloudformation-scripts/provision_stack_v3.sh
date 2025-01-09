#!/bin/bash
source user-config.sh

#Creating Master Cluster
# Create stack
echo "Creating stack $MASTER_STACK_NAME in AWS CloudFormation..."
create_output=$(aws cloudformation create-stack --stack-name $MASTER_STACK_NAME --template-body $MASTER_TEMPLATE_BODY --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameters ParameterKey=MasterNodeGroupDesiredSize,ParameterValue=$MasterNodeGroupDesiredSize ParameterKey=MasterInstanceType,ParameterValue=$MasterInstanceType ParameterKey=MasterNodeGroupMinSize,ParameterValue=$MasterNodeGroupMinSize ParameterKey=MasterNodeGroupMaxSize,ParameterValue=$MasterNodeGroupMaxSize ParameterKey=MasterSSHKeyname,ParameterValue=$MasterSSHKeyname --region $MASTER_REGION)

# Wait for the stack to be created
echo "Waiting for stack to be created..."
aws cloudformation wait stack-create-complete --stack-name $MASTER_STACK_NAME --region $MASTER_REGION

# Check if stack creation was successful
if [ $? -eq 0 ]; then
    echo "Stack $MASTER_STACK_NAME created successfully."
else
    echo "Failed to create stack $MASTER_STACK_NAME."
    exit 1
fi

#Creating the Worker Cluster
# Create stack
echo "Creating stack $WORKER_STACK_NAME in AWS CloudFormation..."
create_output=$(aws cloudformation create-stack --stack-name $WORKER_STACK_NAME --template-body $WORKER_TEMPLATE_BODY --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameters ParameterKey=WorkerInstanceAMIType,ParameterValue=$WorkerInstanceAMIType ParameterKey=WorkerNodeGroupDesiredSize,ParameterValue=$WorkerNodeGroupDesiredSize ParameterKey=WorkerInstanceType,ParameterValue=$WorkerInstanceType ParameterKey=WorkerNodeGroupMinSize,ParameterValue=$WorkerNodeGroupMinSize ParameterKey=WorkerNodeGroupMaxSize,ParameterValue=$WorkerNodeGroupMaxSize ParameterKey=WorkerSSHKeyname,ParameterValue=$WorkerSSHKeyname --region $WORKER_REGION)

# Wait for the stack to be created
echo "Waiting for stack to be created..."
aws cloudformation wait stack-create-complete --stack-name $WORKER_STACK_NAME --region $WORKER_REGION

# Check if stack creation was successful
if [ $? -eq 0 ]; then
    echo "Stack $WORKER_STACK_NAME created successfully."
else
    echo "Failed to create stack $WORKER_STACK_NAME."
    exit 1
fi


#************************************************************#
#Deploying the Application
#************************************************************#

# Update kubeconfig for Master Cluster
aws eks update-kubeconfig --name $MASTER_STACK_NAME-Cluster --region $MASTER_REGION --alias master
kubectl config use-context master

# Check if the master installation already exists
MASTER_INSTALLATION=$(helm list -q -f aitrism)
if [ "$MASTER_INSTALLATION" == "aitrism" ]; then
    echo "Uninstalling aitrism from master cluster..."
    helm uninstall aitrism --wait
else
    echo "No aitrism installation found on master cluster."
fi
cd ../.. || exit
./aws-scripts/install_ebs_csi_driver.sh

# Install aitrism
kubectl create configmap rabbitmq-config --from-file=conf/rabbitmq.conf
kubectl create configmap rabbitmq-advanced-config --from-file=advanced.config=./conf/advanced.config
kubectl create configmap airflow-dags-configmap --from-file=airflow/dags/bulk_scan_dag.py
# docker-compose run airflow-webserver airflow db init
# #When run for first time
# docker-compose run airflow-webserver airflow users create \
# --username admin \
# --password admin \
# --firstname Vilayannur \
# --lastname Sitaraman \
# --role Admin \
# --email vsitaraman@infrablok.com
# docker-compose run airflow-webserver airflow db upgrade

#Adding Secret Store CSI Driver
# helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
# helm install -n kube-system csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver

# helm repo add aws-secrets-manager https://aws.github.io/secrets-store-csi-driver-provider-aws
# helm install -n kube-system secrets-provider-aws aws-secrets-manager/secrets-store-csi-driver-provider-aws

#kubectl apply -f https://raw.githubusercontent.com/aws/secrets-store-csi-driver-provider-aws/main/deployment/aws-provider-installer.yaml

#Install Eksctl in your system.(Linux)

# wget https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz -O /tmp/eksctl.tar.gz
# tar -xzvf /tmp/eksctl.tar.gz -C /usr/local/bin
# eksctl version
###########################################################################################################################

#Before this Step, Make sure to Install Eksctl in your system.

# cd ../.. || exit
echo "Getting AWS Creds for S3..."
python3 aws-scripts/secret-create.py  #Python3 should be installed before this step
echo "S3 Access Secret Created..."

# echo "Getting SSL Certificate & Key from Secret Manager..."
# python3 aws-scripts/ssl-secret.py  #Python3 should be installed before this step
# echo "SSL Secret Created..."

# echo "Creating ssl-secret for prometheus"
# kubectl create secret generic prometheus-tls --from-file=aitrism-master-chart/files/prometheus.crt --from-file=aitrism-master-chart/files/prometheus.key


# echo "Enabling KMS Encryption on the Cluster..."
# eksctl utils enable-secrets-encryption \
#     --cluster $MASTER_STACK_NAME-Cluster \
#     --key-arn $Master_KMS_KEY_ARN

#Create OIDC Provider for your Cluster.
# eksctl utils associate-iam-oidc-provider --region=$MASTER_REGION --cluster=$MASTER_STACK_NAME-Cluster --approve 
# #Create Kubernetes_Service_Account
# eksctl create iamserviceaccount --name $Kubernetes_Service_Account_name --region=$MASTER_REGION --cluster $MASTER_STACK_NAME-Cluster --attach-policy-arn $Master_Secret_Policy_ARN --approve --override-existing-serviceaccounts



echo "Logging in to AWS ECR..."
aws ecr get-login-password --region $MASTER_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$MASTER_REGION.amazonaws.com

# Delete the old Kubernetes secret (if exists) and create a new one
echo "Updating Kubernetes secret for Docker registry..."
kubectl delete secret regcred3 --ignore-not-found
TOKEN=$(aws ecr get-login-password --region $MASTER_REGION)
kubectl create secret docker-registry regcred3 --docker-server=$ECR_URI --docker-username=AWS --docker-password=$TOKEN
echo "Current working directory:"
pwd

############################Elastic ip creation#############################

# Array of names (tags) for the Elastic IPs you're managing
#Declaring all the Parameters
#!/bin/bash


eip_names=("$Master_Eip_1" "$Master_Eip_2") 

# Step 1: Release Elastic IPs by Name
for eip_name in "${eip_names[@]}"; do
    # List all EIPs, filter by tag "Name", and extract the Allocation ID
    allocation_ids_to_release=$(aws ec2 describe-addresses --query 'Addresses[?Tags[?Key==`Name` && Value==`'"$eip_name"'`]].AllocationId' --output text)

    # Release each EIP found
    for alloc_id in $allocation_ids_to_release; do
        echo "Releasing EIP with Allocation ID: $alloc_id"
        aws ec2 release-address --allocation-id $alloc_id
    done
done

# Step 2: Allocate new Elastic IPs and tag them with the same names
allocation_ids=()
for eip_name in "${eip_names[@]}"; do
    echo "Allocating new EIP and tagging with Name: $eip_name"
    # Allocate new EIP
    allocation_id=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
    allocation_ids+=("$allocation_id")
    # Tag the new EIP with the provided name
    aws ec2 create-tags --resources $allocation_id --tags Key=Name,Value=$eip_name
done

# Convert the allocation IDs array to a comma-separated string
allocation_ids_string=$(IFS=, ; echo "${allocation_ids[*]}")
echo "Allocation IDs: $allocation_ids_string"

# Modify the Helm aitrism-service.yaml
# Create or modify a placeholder in your values.yaml file for the EIP allocation IDs:
# eipAllocations: "PLACEHOLDER"

placeholder="PLACEHOLDER"
values_path="./aitrism-master-chart/templates/aitrism-service.yaml"
# Detect OS
OS="`uname`"
case $OS in
  'Linux')
    sed -i 's/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations:.*/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations: PLACEHOLDER/' "$values_path"
    sed -i "s/$placeholder/$allocation_ids_string/" "$values_path"

    ;;
  'Darwin')
    sed -i '' 's/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations:.*/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations: PLACEHOLDER/' "$values_path"
    sed -i '' "s/$placeholder/$allocation_ids_string/" "$values_path"

    ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac



# Name tag value to search for
#Master_Eip_1 = aitrism-master
#EIP_NAME = $Master_Eip_1

# Use AWS CLI to query the EIP by its Name tag and extract the IP address
ip_address_master=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$EIP_NAME_Master" --query 'Addresses[*].PublicIp' --output text)

# Check if an IP address was found
if [ -n "$ip_address_master" ] && [ "$ip_address_master" != "None" ]; then
    echo "aitrism-master ip address: '$EIP_NAME_Master': $ip_address_master"
else
    echo "No IP Address found for the specified name: $EIP_NAME_Master"
fi


#------------------------- Elastic IP for FrontEnd-------------------------------------------------
# Array of names (tags) for the Elastic IPs you're managing
# React_Eip_1 = aitrism-reactapp
# React_Eip_2 = aitrism-reactapp-2
eip_names=("$React_Eip_1" "$React_Eip_2")  # Example names

# Step 1: Release Elastic IPs by Name
for eip_name in "${eip_names[@]}"; do
    # List all EIPs, filter by tag "Name", and extract the Allocation ID
    allocation_ids_to_release=$(aws ec2 describe-addresses --query 'Addresses[?Tags[?Key==`Name` && Value==`'"$eip_name"'`]].AllocationId' --output text)

    # Release each EIP found
    for alloc_id in $allocation_ids_to_release; do
        echo "Releasing EIP with Allocation ID: $alloc_id"
        aws ec2 release-address --allocation-id $alloc_id
    done
done

# Step 2: Allocate new Elastic IPs and tag them with the same names
allocation_ids=()
for eip_name in "${eip_names[@]}"; do
    echo "Allocating new EIP and tagging with Name: $eip_name"
    # Allocate new EIP
    allocation_id=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
    allocation_ids+=("$allocation_id")
    # Tag the new EIP with the provided name
    aws ec2 create-tags --resources $allocation_id --tags Key=Name,Value=$eip_name
done

# Convert the allocation IDs array to a comma-separated string
allocation_ids_string=$(IFS=, ; echo "${allocation_ids[*]}")
echo "Allocation IDs: $allocation_ids_string"

# Modify the Helm aitrism-service.yaml
# Create or modify a placeholder in your values.yaml file for the EIP allocation IDs:
# eipAllocations: "PLACEHOLDER"

placeholder="PLACEHOLDER"
values_path="./aitrism-master-chart/templates/reactapp-service.yaml"
# Detect OS
OS="`uname`"
case $OS in
  'Linux')
    sed -i 's/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations:.*/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations: PLACEHOLDER/' "$values_path"
    sed -i "s/$placeholder/$allocation_ids_string/" "$values_path"

    ;;
  'Darwin')
    sed -i '' 's/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations:.*/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations: PLACEHOLDER/' "$values_path"
    sed -i '' "s/$placeholder/$allocation_ids_string/" "$values_path"

    ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

# Name tag value to search for
#React_Eip_1 = aitrism-reactapp
#EIP_NAME = $React_Eip_1

# Use AWS CLI to query the EIP by its Name tag and extract the IP address
ip_address_reactapp=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$EIP_NAME_React" --query 'Addresses[*].PublicIp' --output text)

# Check if an IP address was found
if [ -n "$ip_address_reactapp" ] && [ "$ip_address_reactapp" != "None" ]; then
    echo "aitrism-reactapp ip address: '$EIP_NAME_React': $ip_address_reactapp"
else
    echo "No IP Address found for the specified name: $EIP_NAME_React"
fi

#-----------------------------Elastic Ips for Kafka----------------------------------
# Array of names (tags) for the Elastic IPs you're managing
# Kafka_Eip_1 = aitrism-kafka
# Kafka_Eip_1 = aitrism-kafka-2

eip_names=("$Kafka_Eip_1" "$Kafka_Eip_2")

# Step 1: Release Elastic IPs by Name
for eip_name in "${eip_names[@]}"; do
    # List all EIPs, filter by tag "Name", and extract the Allocation ID
    allocation_ids_to_release=$(aws ec2 describe-addresses --query 'Addresses[?Tags[?Key==`Name` && Value==`'"$eip_name"'`]].AllocationId' --output text)

    # Release each EIP found
    for alloc_id in $allocation_ids_to_release; do
        echo "Releasing EIP with Allocation ID: $alloc_id"
        aws ec2 release-address --allocation-id $alloc_id
    done
done

# Step 2: Allocate new Elastic IPs and tag them with the same names
allocation_ids=()
for eip_name in "${eip_names[@]}"; do
    echo "Allocating new EIP and tagging with Name: $eip_name"
    # Allocate new EIP
    allocation_id=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
    allocation_ids+=("$allocation_id")
    # Tag the new EIP with the provided name
    aws ec2 create-tags --resources $allocation_id --tags Key=Name,Value=$eip_name
done

# Convert the allocation IDs array to a comma-separated string
allocation_ids_string=$(IFS=, ; echo "${allocation_ids[*]}")
echo "Allocation IDs: $allocation_ids_string"

# Modify the Helm aitrism-service.yaml
# Create or modify a placeholder in your values.yaml file for the EIP allocation IDs:
# eipAllocations: "PLACEHOLDER"

placeholder="PLACEHOLDER"
values_path="./aitrism-master-chart/templates/kafka-service.yaml"
# Detect OS
OS="`uname`"
case $OS in
  'Linux')
    sed -i 's/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations:.*/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations: PLACEHOLDER/' "$values_path"
    sed -i "s/$placeholder/$allocation_ids_string/" "$values_path"

    ;;
  'Darwin')
    sed -i '' 's/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations:.*/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations: PLACEHOLDER/' "$values_path"
    sed -i '' "s/$placeholder/$allocation_ids_string/" "$values_path"

    ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

# Name tag value to search for
#Kafka_Eip_1 = aitrism-kafka
#EIP_NAME = $Kafka_Eip_1

# Use AWS CLI to query the EIP by its Name tag and extract the IP address
ip_address_kafka=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$EIP_NAME_Kafka" --query 'Addresses[*].PublicIp' --output text)

# Check if an IP address was found
if [ -n "$ip_address_kafka" ] && [ "$ip_address_kafka" != "None" ]; then
    echo "aitrism-kafka ip address: '$EIP_NAME_Kafka': $ip_address_kafka"
else
    echo "No IP Address found for the specified name: $EIP_NAME_Kafka"
fi

# #########################modify .env to change redis_client host##########################
# # Define the file path
# file_path=".env"

# # Use sed to replace the placeholder or an existing IP address
# if [[ "$OSTYPE" == "darwin"* ]]; then
#     # macOS
#     sed -i '' "s/^REDIS_HOST=.*/REDIS_HOST=${ip_address_master}/" "$file_path"
# else
#     # Linux
#     sed -i "s/^REDIS_HOST=.*/REDIS_HOST=${ip_address_master}/" "$file_path"
# fi

# #---------------build and push worker image-------------------------------------
# echo "Logging in to AWS ECR..."
# aws ecr get-login-password --region $MASTER_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$MASTER_REGION.amazonaws.com
# docker-compose -f docker-compose-worker.yml build
# docker tag fastapi_celery_example_celery_worker:latest $ECR_URI:$Docker_Worker_Tag
# docker push $ECR_URI:$Docker_Worker_Tag

# #---------------build and push master image-------------------------------------
# docker-compose -f docker-compose-web.yml build
# docker tag fastapi_celery_example_web:latest $ECR_URI:$Docker_Web_Tag
# docker push $ECR_URI:$Docker_Web_Tag


#######Modify .env for front end#########################################
# Specify the path to your .env file
# env_file="./aitrism-react-app/.env"

# Use sed to replace the IP address in the specified line
# Detecting the platform to handle the in-place (-i) flag correctly for both GNU sed and BSD sed
# if [[ "$OSTYPE" == "darwin"* ]]; then
#   # macOS (BSD sed)
#   sed -i '' "s|REACT_APP_DEFEND_BACKEND_API_ENDPOINT=http://[^:]*:8000/|REACT_APP_DEFEND_BACKEND_API_ENDPOINT=http://${ip_address_master}:8000/|" "$env_file"
# else
#   # Linux (GNU sed)
#   sed -i "s|REACT_APP_DEFEND_BACKEND_API_ENDPOINT=http://[^:]*:8000/|REACT_APP_DEFEND_BACKEND_API_ENDPOINT=http://${ip_address_master}:8000/|" "$env_file"
# fi

# #UI, Build & Push
# docker-compose -f docker-compose-frontend.yaml build
# docker tag aitrism_frontend:latest $ECR_URI:$Docker_React_Tag
# docker push $ECR_URI:$Docker_React_Tag

#kubectl create configmap rabbitmq-config --from-file=rabbitmq.conf

#Installing Matric-server in the Master Cluster.
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Install aitrism-worker
echo "Logging in to AWS ECR..."
aws ecr get-login-password --region $MASTER_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$MASTER_REGION.amazonaws.com



# # Define the path to your values.yaml file
# values_path="./aitrism-master-chart/values.yaml"

# # Check the operating system
# if [[ "$OSTYPE" == "darwin"* ]]; then
#   # macOS requires an empty string argument after -i to edit in place without backup
#   echo "Replacing Docker tag on MacOS"
#   sed -i '' "s|\(image_worker:.*\):.*|image_worker: \"$ECR_URI:$Docker_Worker_Tag\"|" "$values_path"
#   sed -i '' "s|\(image_web:.*\):.*|image_web: \"$ECR_URI:$Docker_Web_Tag\"|" "$values_path"
#   sed -i '' "s|\(image_frontend:.*\):.*|image_frontend: \"$ECR_URI:$Docker_React_Tag\"|" "$values_path"
#   sed -i '' "s|\(image_ntp:.*\):.*|image_ntp: \"$ECR_URI:$Docker_NTP_Tag\"|" "$values_path"
#   #sed -i '' "s|\(image_kafka:.*\):.*|image_kafka: \"$ECR_URI:$Docker_Kafka_Consumer_Tag\"|" "$values_path"

  
# else
#   # Linux
#   echo "Replacing Docker tag on Linux"
#   sed -i "s|\image_web: \".*\"|image_web: \"$ECR_URI:$Docker_Web_Tag\"|g" "$values_path"
#   sed -i "s|\(image_worker:.*\):.*|image_worker: \"$ECR_URI:$Docker_Worker_Tag\"|" "$values_path"
#   sed -i "s|\(image_frontend:.*\):.*|image_frontend: \"$ECR_URI:$Docker_React_Tag\"|" "$values_path"
#   sed -i "s|\(image_ntp:.*\):.*|image_ntp: \"$ECR_URI:$Docker_NTP_Tag\"|" "$values_path"
#  # sed -i "s|\(image_kafka:.*\):.*|image_kafka: \"$ECR_URI:$Docker_Kafka_Consumer_Tag\"|" "$values_path"
# fi
# echo "Image tag changed in values.yaml file of Master chart"

############################################################################

helm dependency build ./aitrism-master-chart/
helm repo add apache-airflow https://airflow.apache.org
helm install aitrism ./aitrism-master-chart/

# docker-compose run airflow-webserver airflow db upgrade

#kubectl config use-context $
#LOCAL_CONTEXT
# Update kubeconfig for Worker Cluster
aws eks update-kubeconfig --name $WORKER_STACK_NAME-Cluster --region $WORKER_REGION --alias worker
kubectl config use-context worker
kubectl create configmap rabbitmq-config --from-file=conf/rabbitmq.conf
kubectl create configmap rabbitmq-advanced-config --from-file=conf/advanced.config

# Delete the old Kubernetes secret (if exists) and create a new one
echo "Updating Kubernetes secret for Docker registry..."
kubectl delete secret regcred3 --ignore-not-found
TOKEN=$(aws ecr get-login-password --region $WORKER_REGION )
kubectl create secret docker-registry regcred3 --docker-server=$ECR_URI --docker-username=AWS --docker-password=$TOKEN

# Check if the worker installation already exists
WORKER_INSTALLATION=$(helm list -q -f aitrism-worker)
if [ "$WORKER_INSTALLATION" == "aitrism-worker" ]; then
    echo "Uninstalling aitrism-worker from worker cluster..."
    helm uninstall aitrism-worker --wait
else
    echo "No aitrism-worker installation found on worker cluster."
fi
pwd

#Installing Matric-server in the worker Cluster.
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

echo "Getting AWS Creds for S3..."
python3 aws-scripts/secret-create.py  #Python3 should be installed before this step
echo "S3 Access Secret Created..."

# echo "Enabling KMS Encryption on the Cluster..."
# eksctl utils enable-secrets-encryption \
#     --cluster $WORKER_STACK_NAME-Cluster \
#     --key-arn $Worker_KMS_KEY_ARN

# Define the path to your values.yaml file
values_path="./aitrism-worker-chart/values.yaml"

# Check the operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS requires an empty string argument after -i to edit in place without backup
  echo "Replacing ${ip_address_master} ${ip_address_kafka}"
  sed -i '' "s/AITRISM_MASTER_DNS: .*/AITRISM_MASTER_DNS: \"$ip_address_master\"/" "$values_path"
  sed -i '' "s/AITRISM_KAFKA_BOOTSTRAP_SERVER: .*/AITRISM_KAFKA_BOOTSTRAP_SERVER: \"$ip_address_kafka\"/" "$values_path"
else
  # Linux
  echo "Replacing ${ip_address_master} ${ip_address_kafka}"
  sed -i "s/AITRISM_MASTER_DNS: .*/AITRISM_MASTER_DNS: \"$ip_address_master\"/" "$values_path"
  sed -i "s/AITRISM_KAFKA_BOOTSTRAP_SERVER: .*/AITRISM_KAFKA_BOOTSTRAP_SERVER: \"$ip_address_kafka\"/" "$values_path"
fi

# Check the operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS requires an empty string argument after -i to edit in place without backup
  echo "Replacing Docker tag on MacOS"
  sed -i '' "s|\(image_worker:.*\):.*|image_worker: \"$ECR_URI:$Docker_Worker_Tag\"|" "$values_path"
  sed -i '' "s|\(image_fastapi:.*\):.*|image_fastapi: \"$ECR_URI:$Docker_Web_Tag\"|" "$values_path"

else
  # Linux
  echo "Replacing Docker tag on Linux"
  sed -i "s|\image_fastapi: \".*\"|image_fastapi: \"$ECR_URI:$Docker_Web_Tag\"|g" "$values_path"
  sed -i "s|\(image_worker:.*\):.*|image_worker: \"$ECR_URI:$Docker_Worker_Tag\"|" "$values_path"

fi
echo "Image tag changed in values.yaml file of worker chart"

echo "Installing Nvidia Driver Toolkit for GPU"
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.16.1/deployments/static/nvidia-device-plugin.yml

helm install aitrism-worker aitrism-worker-chart/
