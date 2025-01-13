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
create_output=$(aws cloudformation create-stack --stack-name $WORKER_STACK_NAME --template-body $WORKER_TEMPLATE_BODY --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameters ParameterKey=WorkerNodeGroupDesiredSize,ParameterValue=$WorkerNodeGroupDesiredSize ParameterKey=WorkerInstanceType,ParameterValue=$WorkerInstanceType ParameterKey=WorkerNodeGroupMinSize,ParameterValue=$WorkerNodeGroupMinSize ParameterKey=WorkerNodeGroupMaxSize,ParameterValue=$WorkerNodeGroupMaxSize ParameterKey=WorkerSSHKeyname,ParameterValue=$WorkerSSHKeyname ParameterKey=WorkerInstanceAMIType,ParameterValue=$WorkerInstanceAMIType  --region $WORKER_REGION)

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

# Define the path to the values.yaml file to update Cognito Envs
values_path="../../detect-master-chart/values.yaml"

# Step 3: Use sed to replace the values in values.yaml
sed -i "s|COGNITO_CLIENT_ID: .*|COGNITO_CLIENT_ID: \"$COGNITO_CLIENT_ID\"|" $values_path
sed -i "s|COGNITO_USER_POOL_ID: .*|COGNITO_USER_POOL_ID: \"$COGNITO_USER_POOL_ID\"|" $values_path
sed -i "s|COGNITO_REGION: .*|COGNITO_REGION: \"$COGNITO_REGION\"|" $values_path
sed -i "s|NEW_USERNAME: .*|NEW_USERNAME: \"$NEW_USERNAME\"|" $values_path

echo "Updated values.yaml with the new values from user-config.sh."

# Define the path to the Python script
python_script_path="../secret-creation.py"

# Update values in the Python script using `sed`
sed -i "s|secret_name = .*|secret_name = \"$secret_name\"|" "$python_script_path"
sed -i "s|region_name = .*|region_name = \"$region_name\"|" "$python_script_path"
sed -i "s|source_account_id = .*|source_account_id = \"$source_account_id\"|" "$python_script_path"
sed -i "s|role_name = .*|role_name = \"$role_name\"|" "$python_script_path"
sed -i "s|k8s_secret_name = .*|k8s_secret_name = \"$k8s_secret_name\"|" "$python_script_path"
sed -i "s|namespace = .*|namespace = \"$namespace\"|" "$python_script_path"

echo "Python script updated with values from user-config.sh."

#************************************************************#
#Deploying the Application
#************************************************************#

# Update kubeconfig for Master Cluster
aws eks update-kubeconfig --name $MASTER_STACK_NAME-Cluster --region $MASTER_REGION --alias detect-master
kubectl config use-context detect-master

# Check if the master installation already exists
MASTER_INSTALLATION=$(helm list -q -f detect)
if [ "$MASTER_INSTALLATION" == "detect" ]; then
    echo "Uninstalling detect from master cluster..."
    helm uninstall detect --wait
else
    echo "No detect installation found on master cluster."
fi
cd ../.. || exit
./aws-scripts/install_ebs_csi_driver.sh

# Install detect-master
kubectl create configmap rabbitmq-config --from-file=conf/rabbitmq.conf
kubectl create configmap rabbitmq-advanced-config --from-file=advanced.config=./conf/advanced.config

# python3 secret-creation.py
python3 aws-scripts/secret-creation.py

# Variables For ECR Access
ECR_ROLE_ARN=$ECR_ROLE_ARN  
ECR_ROLE_SESSION_NAME=$ECR_ROLE_SESSION_NAME
ECR_ROLE_EXTERNAL_ID=$ECR_ROLE_EXTERNAL_ID

# Function to assume ECR role and export temporary credentials
assume_ecr_role() {
    echo "Assuming ECR role: $ECR_ROLE_ARN with ExternalId: $ECR_ROLE_EXTERNAL_ID"
    ASSUME_ROLE_OUTPUT=$(aws sts assume-role --role-arn "$ECR_ROLE_ARN" --role-session-name "$ECR_ROLE_SESSION_NAME" --external-id "$ECR_ROLE_EXTERNAL_ID" --region "$MASTER_REGION")

    if [ $? -ne 0 ]; then
        echo "Error assuming ECR role. Exiting."
        exit 1
    fi

    export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')

    echo "Temporary credentials for ECR set for this session."
}

# Function to authenticate with ECR and store the Docker login token
store_ecr_token() {
    echo "Logging in to AWS ECR..."
    TOKEN=$(aws ecr get-login-password --region "$MASTER_REGION")
    echo "ECR login token stored temporarily."
}

# Function to create Kubernetes secret for Docker registry
create_k8s_secret() {
    # Verify Kubernetes cluster access
    echo "Verifying Kubernetes cluster access..."
    kubectl get nodes || { echo "Error: Unable to access Kubernetes cluster."; exit 1; }
    kubectl get pods

    # Update Kubernetes secret for Docker registry
    echo "Updating Kubernetes secret for Docker registry..."
    kubectl delete secret regcred --ignore-not-found
    kubectl create secret docker-registry regcred \
        --docker-server="$ECR_URI_MASTER" \
        --docker-username=AWS \
        --docker-password="$TOKEN"

    echo "Kubernetes secret created successfully."
}

# Function to clear temporary credentials
clear_ecr_credentials() {
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    echo "Temporary credentials cleared."
}

# Main script
# Step 1: Assume the ECR role and set temporary credentials
assume_ecr_role

# Step 2: Authenticate with ECR and store the Docker login token
store_ecr_token

# Step 3: Clear the temporary credentials
clear_ecr_credentials

# Step 4: Create the Kubernetes secret for Docker registry
create_k8s_secret

echo "k8s secret created using ECR cross account"

# echo "Logging in to AWS ECR..."
# aws ecr get-login-password --region $MASTER_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID_MASTER.dkr.ecr.$MASTER_REGION.amazonaws.com

# echo "Getting SSL Certificate & Key from Secret Manager..."
# python3 aws-scripts/ssl-secret.py  #Python3 should be installed before this step
# echo "SSL Secret Created..."

# echo "Creating ssl-secret for prometheus"
# kubectl create secret generic prometheus-tls --from-file=aitrism-master-chart/files/prometheus.crt --from-file=aitrism-master-chart/files/prometheus.key

# echo "Enabling KMS Encryption on the Cluster..."
# eksctl utils enable-secrets-encryption \
#     --cluster $MASTER_STACK_NAME-Cluster \
#     --key-arn $Master_KMS_KEY_ARN

# # Delete the old Kubernetes secret (if exists) and create a new one
# echo "Updating Kubernetes secret for Docker registry..."
# kubectl delete secret regcred --ignore-not-found
# TOKEN=$(aws ecr get-login-password --region $MASTER_REGION)
# kubectl create secret docker-registry regcred --docker-server=$ECR_URI_MASTER --docker-username=AWS --docker-password=$TOKEN

# # Cleanup
# unset AWS_ACCESS_KEY_ID
# unset AWS_SECRET_ACCESS_KEY
# unset AWS_SESSION_TOKEN
# echo "Temporary credentials cleared. Script completed."

echo "Current working directory:"
pwd

#Creating configmap for Airflow
kubectl create configmap airflow-dags-configmap --from-file=airflow/dags/schedule_job.py
# Create configmap for graylog
kubectl create configmap graylog-script --from-file=conf/graylog.sh
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
values_path="./detect-master-chart/templates/detect-service.yaml"
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
    echo "detect-master ip address: '$EIP_NAME_Master': $ip_address_master"
else
    echo "No IP Address found for the specified name: $EIP_NAME_Master"
fi


#------------------------- Elastic IP for Rabbitmq-------------------------------------------------
# Array of names (tags) for the Elastic IPs you're managing
# Rabbitmq_Eip_1 = detect-rabbitmq
# Rabbitmq_Eip_2 = detect-rabbitmq-2
eip_names=("$Rabbitmq_Eip_1" "$Rabbitmq_Eip_2")  # Example names

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
values_path="./detect-master-chart/templates/rabbitmq-service.yaml"
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
#EIP_NAME = $Rabbitmq_Eip_1

# Use AWS CLI to query the EIP by its Name tag and extract the IP address
ip_address_rabbitmq=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$EIP_Name_Rabbitmq" --query 'Addresses[*].PublicIp' --output text)

# Check if an IP address was found
if [ -n "$ip_address_rabbitmq" ] && [ "$ip_address_rabbitmq" != "None" ]; then
    echo "detect-rabbitmq ip address: '$EIP_Name_Rabbitmq': $ip_address_rabbitmq"
else
    echo "No IP Address found for the specified name: $EIP_Name_Rabbitmq"
fi

#-----------------------------Elastic Ips for Mongodb----------------------------------##
# Array of names (tags) for the Elastic IPs you're managing
eip_names=("$Mongo_Eip_1" "$Mongo_Eip_2") 

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

# Define the path to your values.yaml file
placeholder="PLACEHOLDER"
values_path="./detect-master-chart/values.yaml"

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

# # Name tag value to search for
# #Kafka_Eip_1 = aitrism-kafka
# #EIP_NAME = $Kafka_Eip_1

# Use AWS CLI to query the EIP by its Name tag and extract the IP address
ip_address_mongodb=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$EIP_NAME_Mongo" --query 'Addresses[*].PublicIp' --output text)

# Check if an IP address was found
if [ -n "$ip_address_mongodb" ] && [ "$ip_address_mongodb" != "None" ]; then
    echo "detect-mongodb ip address: '$EIP_NAME_Mongo': $ip_address_mongodb"
else
    echo "No IP Address found for the specified name: $EIP_NAME_Mongo"
fi

# #------------------------- Elastic IP for Graylog-------------------------------------------------
# # Array of names (tags) for the Elastic IPs you're managing
# # Graylog_Eip_1 = detect-graylog
# # Graylog_Eip_2 = detect-graylog-2
# eip_names=("$Graylog_Eip_1" "$Graylog_Eip_2")  # Example names

# # Step 1: Release Elastic IPs by Name
# for eip_name in "${eip_names[@]}"; do
#     # List all EIPs, filter by tag "Name", and extract the Allocation ID
#     allocation_ids_to_release=$(aws ec2 describe-addresses --query 'Addresses[?Tags[?Key==`Name` && Value==`'"$eip_name"'`]].AllocationId' --output text)

#     # Release each EIP found
#     for alloc_id in $allocation_ids_to_release; do
#         echo "Releasing EIP with Allocation ID: $alloc_id"
#         aws ec2 release-address --allocation-id $alloc_id
#     done
# done

# # Step 2: Allocate new Elastic IPs and tag them with the same names
# allocation_ids=()
# for eip_name in "${eip_names[@]}"; do
#     echo "Allocating new EIP and tagging with Name: $eip_name"
#     # Allocate new EIP
#     allocation_id=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)
#     allocation_ids+=("$allocation_id")
#     # Tag the new EIP with the provided name
#     aws ec2 create-tags --resources $allocation_id --tags Key=Name,Value=$eip_name
# done

# # Convert the allocation IDs array to a comma-separated string
# allocation_ids_string=$(IFS=, ; echo "${allocation_ids[*]}")
# echo "Allocation IDs: $allocation_ids_string"

# # Modify the Helm aitrism-service.yaml
# # Create or modify a placeholder in your values.yaml file for the EIP allocation IDs:
# # eipAllocations: "PLACEHOLDER"


# placeholder="PLACEHOLDER"
# values_path="./detect-master-chart/templates/graylog-service.yaml"
# # Detect OS
# OS="`uname`"
# case $OS in
#   'Linux')
#     sed -i 's/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations:.*/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations: PLACEHOLDER/' "$values_path"
#     sed -i "s/$placeholder/$allocation_ids_string/" "$values_path"

#     ;;
#   'Darwin')
#     sed -i '' 's/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations:.*/service.beta.kubernetes.io\/aws-load-balancer-eip-allocations: PLACEHOLDER/' "$values_path"
#     sed -i '' "s/$placeholder/$allocation_ids_string/" "$values_path"

#     ;;
#   *)
#     echo "Unsupported OS: $OS"
#     exit 1
#     ;;
# esac


# Name tag value to search for
#React_Eip_1 = aitrism-reactapp
#EIP_NAME = $Graylog_Eip_1

# # Use AWS CLI to query the EIP by its Name tag and extract the IP address
# ip_address_Graylog=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$EIP_Name_Graylog" --query 'Addresses[*].PublicIp' --output text)

# # Check if an IP address was found
# if [ -n "$ip_address_Graylog" ] && [ "$ip_address_Graylog" != "None" ]; then
#     echo "detect-Graylog ip address: '$EIP_Name_Graylog': $ip_address_Graylog"
# else
#     echo "No IP Address found for the specified name: $EIP_Name_Graylog"
# fi


# # Define the path to your values.yaml file
# values_path="./detect-worker-chart/values.yaml"

# # Check the operating system
# if [[ "$OSTYPE" == "darwin"* ]]; then
#   # macOS requires an empty string argument after -i to edit in place without backup
#   echo "Replacing ${ip_address_Graylog}"
#   sed -i '' "s/GRAYLOG_HOST: .*/GRAYLOG_HOST: \"$ip_address_Graylog\"/" "$values_path"
# else
#   # Linux
#   echo "Replacing ${ip_address_Graylog}"
#   sed -i "s/GRAYLOG_HOST: .*/GRAYLOG_HOST: \"$ip_address_Graylog\"/" "$values_path"
# fi


#------------------------- Elastic IP for Worker_Node_Exporter-------------------------------------------------
# Array of names (tags) for the Elastic IPs you're managing
# Worker_Node_Exporter_Eip_1 = detect-Worker_Node_Exporter
# Worker_Node_Exporter_2 = detect-Worker_Node_Exporter-2
eip_names=("$Worker_Node_Exporter_Eip_1" "$Worker_Node_Exporter_Eip_2")  # Example names

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
values_path="./detect-worker-chart/templates/Node-exporter-Service.yaml"
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
# React_Eip_1 = aitrism-reactapp
# EIP_NAME = $Worker_Node_Exporter_Eip_1

# Use AWS CLI to query the EIP by its Name tag and extract the IP address
ip_address_Worker_Node_Exporter_Eip=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$Worker_Node_Exporter_Eip" --query 'Addresses[*].PublicIp' --output text)

# Check if an IP address was found
if [ -n "$ip_address_Worker_Node_Exporter_Eip" ] && [ "$ip_address_Worker_Node_Exporter_Eip" != "None" ]; then
    echo "detect-worker-node ip address: '$Worker_Node_Exporter_Eip': $ip_address_Worker_Node_Exporter_Eip"
else
    echo "No IP Address found for the specified name: $Worker_Node_Exporter_Eip"
fi


# Define the path to your Prometheus config file
prometheus_config_path="./detect-master-chart/files/prometheus.yml"

# Define the new IP address for the detect-worker
# ip_address_Worker_Node_Exporter="${ip_address_Worker_Node_Exporter_Eip}"

# Create a dynamic search pattern to find the existing IP address for the detect-worker
search_pattern="targets: \[ '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' \]"

# Define the new target line
new_target="targets: [ '${ip_address_Worker_Node_Exporter_Eip}' ]"

# # Print current file contents
# echo "Current Prometheus config:"
# cat "$prometheus_config_path"

# Use sed to update the IP address in the config file
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS
  echo "Updating Prometheus config on macOS"
  sed -i '' "s|$search_pattern|$new_target|" "$prometheus_config_path"
else
  # Linux
  echo "Updating Prometheus config on Linux"
  sed -i "s|$search_pattern|$new_target|" "$prometheus_config_path"
fi

# Print updated file contents
# echo "Updated Prometheus config:"
# cat "$prometheus_config_path"

# # Verify the update
# grep "targets:" "$prometheus_config_path"


echo "Prometheus configuration updated with new worker IP: ${ip_address_Worker_Node_Exporter}"


#Installing Matric-server in the Master Cluster.
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# # Install aitrism-worker
# echo "Logging in to AWS ECR..."
# aws ecr get-login-password --region $MASTER_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID_MASTER.dkr.ecr.$MASTER_REGION.amazonaws.com



# Define the path to your values.yaml file
values_path="./detect-master-chart/values.yaml"

# Check the operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS requires an empty string argument after -i to edit in place without backup
  echo "Replacing ${ip_address_master}"
  sed -i '' "s/DETECT_MASTER_DNS: .*/DETECT_MASTER_DNS: \"$ip_address_master\"/" "$values_path"
  #sed -i '' "s/AITRISM_KAFKA_BOOTSTRAP_SERVER: .*/AITRISM_KAFKA_BOOTSTRAP_SERVER: \"$ip_address_kafka\"/" "$values_path"
else
  # Linux
  echo "Replacing ${ip_address_master}"
  sed -i "s/DETECT_MASTER_DNS: .*/DETECT_MASTER_DNS: \"$ip_address_master\"/" "$values_path"
  #sed -i "s/AITRISM_KAFKA_BOOTSTRAP_SERVER: .*/AITRISM_KAFKA_BOOTSTRAP_SERVER: \"$ip_address_kafka\"/" "$values_path"
fi

####################################### Testing for Domain ####################################################

# echo "Logging in to AWS ECR..."
# aws ecr get-login-password --region $MASTER_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID_MASTER.dkr.ecr.$MASTER_REGION.amazonaws.com
# Define the path to your values.yaml file
# values_path="./aws-scripts/cloudformation-scripts/config.sh"

# if [[ "$OSTYPE" == "darwin"* ]]; then
#   echo "Replacing ${ip_address_master} in macOS"
#   sed -i '' "s/^IP_UI=\"[^\"]*\"/IP_UI=\"$ip_address_master\"/" "$values_path"
#   sed -i '' "s/^IP_API=\"[^\"]*\"/IP_API=\"$ip_address_master\"/" "$values_path"
#   # sed -i '' "s/^IP_Airflow=\"[^\"]*\"/IP_Airflow=\"$ip_address_master\"/" "$values_path"
#   # sed -i '' "s/^IP_Graylog=\"[^\"]*\"/IP_Graylog=\"$ip_address_master\"/" "$values_path"
# else
#   # Linux
#   echo "Replacing ${ip_address_master} in Linux"
#   sed -i "s/^IP_UI=\"[^\"]*\"/IP_UI=\"$ip_address_master\"/" "$values_path"
#   sed -i "s/^IP_API=\"[^\"]*\"/IP_API=\"$ip_address_master\"/" "$values_path"
#   # sed -i "s/^IP_Airflow=\"[^\"]*\"/IP_Airflow=\"$ip_address_master\"/" "$values_path"
#   # sed -i "s/^IP_Graylog=\"[^\"]*\"/IP_Graylog=\"$ip_address_master\"/" "$values_path"
# fi

# echo "Ip replaced for Godaddy"
# # ./aws-scripts/cloudformation-scripts/godaddy.sh

# #For UI
# curl -X PUT "https://api.godaddy.com/v1/domains/$DOMAIN/records/$RECORD_TYPE/$PREFIX_UI.$SUBDOMAIN" \
# -H "Authorization: sso-key $API_KEY:$API_SECRET" \
# -H "Content-Type: application/json" \
# -d "[{\"data\": \"$IP_UI\", \"ttl\": 600}]"

# #For Fast-api
# curl -X PUT "https://api.godaddy.com/v1/domains/$DOMAIN/records/$RECORD_TYPE/$PREFIX_API.$SUBDOMAIN" \
# -H "Authorization: sso-key $API_KEY:$API_SECRET" \
# -H "Content-Type: application/json" \
# -d "[{\"data\": \"$IP_API\", \"ttl\": 600}]"

# #For Airflow
# curl -X PUT "https://api.godaddy.com/v1/domains/$DOMAIN/records/$RECORD_TYPE/$PREFIX_AIRFLOW.$SUBDOMAIN" \
# -H "Authorization: sso-key $API_KEY:$API_SECRET" \
# -H "Content-Type: application/json" \
# -d "[{\"data\": \"$IP_Airflow\", \"ttl\": 600}]"

# #For Greylog
# curl -X PUT "https://api.godaddy.com/v1/domains/$DOMAIN/records/$RECORD_TYPE/$PREFIX_GREYLOG.$SUBDOMAIN" \
# -H "Authorization: sso-key $API_KEY:$API_SECRET" \
# -H "Content-Type: application/json" \
# -d "[{\"data\": \"$IP_Greylog\", \"ttl\": 600}]"

# echo "All domain Setup Successfully"

###################################################################################################################
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
# Add the Apache Airflow Helm repo
helm repo add apache-airflow https://airflow.apache.org
helm repo add bitnami https://charts.bitnami.com/bitnami
# Update the Helm repositories
helm repo update
helm install node-exporter prometheus-community/prometheus-node-exporter
helm dependency build ./detect-master-chart/
helm install detect ./detect-master-chart/


############################################################################
# Update kubeconfig for Worker Cluster
aws eks update-kubeconfig --name $WORKER_STACK_NAME-Cluster --region $WORKER_REGION --alias detect-worker
kubectl config use-context detect-worker
kubectl create configmap rabbitmq-config --from-file=conf/rabbitmq.conf
kubectl create configmap rabbitmq-advanced-config --from-file=conf/advanced.config
# Create configmap for graylog
kubectl create configmap graylog-script --from-file=conf/graylog.sh
kubectl create namespace monitoring

#echo "Create aitrism-aws Secret to get AWS Secret Manager Values"
# python3 secret-creation.py
python3 aws-scripts/secret-creation.py

# Function to assume ECR role and export temporary credentials
assume_ecr_role() {
    echo "Assuming ECR role: $ECR_ROLE_ARN with ExternalId: $ECR_ROLE_EXTERNAL_ID"
    ASSUME_ROLE_OUTPUT=$(aws sts assume-role --role-arn "$ECR_ROLE_ARN" --role-session-name "$ECR_ROLE_SESSION_NAME" --external-id "$ECR_ROLE_EXTERNAL_ID" --region "$MASTER_REGION")

    if [ $? -ne 0 ]; then
        echo "Error assuming ECR role. Exiting."
        exit 1
    fi

    export AWS_ACCESS_KEY_ID=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo "$ASSUME_ROLE_OUTPUT" | jq -r '.Credentials.SessionToken')

    echo "Temporary credentials for ECR set for this session."
}

# Function to authenticate with ECR and store the Docker login token
store_ecr_token() {
    echo "Logging in to AWS ECR..."
    TOKEN=$(aws ecr get-login-password --region "$MASTER_REGION")
    echo "ECR login token stored temporarily."
}

# Function to create Kubernetes secret for Docker registry
create_k8s_secret() {
    # Verify Kubernetes cluster access
    echo "Verifying Kubernetes cluster access..."
    kubectl get nodes || { echo "Error: Unable to access Kubernetes cluster."; exit 1; }
    kubectl get pods

    # Update Kubernetes secret for Docker registry
    echo "Updating Kubernetes secret for Docker registry..."
    kubectl delete secret regcred --ignore-not-found
    kubectl create secret docker-registry regcred \
        --docker-server="$ECR_URI_MASTER" \
        --docker-username=AWS \
        --docker-password="$TOKEN"

    echo "Kubernetes secret created successfully."
}

# Function to clear temporary credentials
clear_ecr_credentials() {
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    echo "Temporary credentialscript completed successfully cleared."
}

# Main script
# Step 1: Assume the ECR role and set temporary credentials
assume_ecr_role

# Step 2: Authenticate with ECR and store the Docker login token
store_ecr_token

# Step 3: Clear the temporary credentials
clear_ecr_credentials

# Step 4: Create the Kubernetes secret for Docker registry
create_k8s_secret

echo "ECR Access Role Script completed successfully for worker."

# echo "Logging in to AWS ECR..."
# aws ecr get-login-password --region $MASTER_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID_WORKER.dkr.ecr.$MASTER_REGION.amazonaws.com
# #kubectl create configmap rabbitmq-advanced-config --from-file=conf/advanced.config

# echo "Enabling KMS Encryption on the Cluster..."
# eksctl utils enable-secrets-encryption \
#     --cluster $WORKER_STACK_NAME-Cluster \
#     --key-arn $Worker_KMS_KEY_ARN
    
# # Delete the old Kubernetes secret (if exists) and create a new one
# echo "Updating Kubernetes secret for Docker registry..."
# kubectl delete secret regcred --ignore-not-found
# TOKEN=$(aws ecr get-login-password --region $WORKER_REGION )
# kubectl create secret docker-registry regcred --docker-server=$ECR_URI_WORKER --docker-username=AWS --docker-password=$TOKEN

# Check if the worker installation already exists
WORKER_INSTALLATION=$(helm list -q -f detect-worker)
if [ "$WORKER_INSTALLATION" == "detect-worker" ]; then
    echo "Uninstalling detect-worker from worker cluster..."
    helm uninstall detect-worker --wait
else
    echo "No detect-worker installation found on worker cluster."
fi
pwd

#Installing Matric-server in the worker Cluster.
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Define the path to your values.yaml file
values_path="./detect-worker-chart/values.yaml"

# Check the operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS requires an empty string argument after -i to edit in place without backup
  echo "Replacing ${ip_address_rabbitmq}"
  sed -i '' "s/DETECT_RABBITMQ_IP: .*/DETECT_RABBITMQ_IP: \"$ip_address_rabbitmq\"/" "$values_path"
  #sed -i '' "s/AITRISM_KAFKA_BOOTSTRAP_SERVER: .*/AITRISM_KAFKA_BOOTSTRAP_SERVER: \"$ip_address_kafka\"/" "$values_path"
else
  # Linux
  echo "Replacing ${ip_address_rabbitmq}"
  sed -i "s/DETECT_RABBITMQ_IP: .*/DETECT_RABBITMQ_IP: \"$ip_address_rabbitmq\"/" "$values_path"
  #sed -i "s/AITRISM_KAFKA_BOOTSTRAP_SERVER: .*/AITRISM_KAFKA_BOOTSTRAP_SERVER: \"$ip_address_kafka\"/" "$values_path"
fi

#Replacing Mongodb Ip
# Define the path to your values.yaml file
values_path="./detect-worker-chart/values.yaml"

# Check the operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS requires an empty string argument after -i to edit in place without backup
  echo "Replacing ${ip_address_mongodb}"
  sed -i '' "s/MONGODB_SVC_NAME: .*/MONGODB_SVC_NAME: \"$ip_address_mongodb\"/" "$values_path"
else
  # Linux
  echo "Replacing ${ip_address_mongodb}"
  sed -i "s/MONGODB_SVC_NAME: .*/MONGODB_SVC_NAME: \"$ip_address_mongodb\"/" "$values_path"
fi


# # Check the operating system
# if [[ "$OSTYPE" == "darwin"* ]]; then
#   # macOS requires an empty string argument after -i to edit in place without backup
#   echo "Replacing Docker tag on MacOS"
#   sed -i '' "s|\(image_worker:.*\):.*|image_worker: \"$ECR_URI:$Docker_Worker_Tag\"|" "$values_path"
#   sed -i '' "s|\(image_fastapi:.*\):.*|image_fastapi: \"$ECR_URI:$Docker_Web_Tag\"|" "$values_path"

# else
#   # Linux
#   echo "Replacing Docker tag on Linux"
#   sed -i "s|\image_fastapi: \".*\"|image_fastapi: \"$ECR_URI:$Docker_Web_Tag\"|g" "$values_path"
#   sed -i "s|\(image_worker:.*\):.*|image_worker: \"$ECR_URI:$Docker_Worker_Tag\"|" "$values_path"

# fi
# echo "Image tag changed in values.yaml file of worker chart"
echo "Installing Nvidia Driver Toolkit for GPU"
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.16.1/deployments/static/nvidia-device-plugin.yml
helm install detect-worker detect-worker-chart/
# # Restart detect-fastapi deployment
# kubectl rollout restart deployment detect-fastapi --kubeconfig master-kubeconfig.yaml 
# echo "detect-fastapi deployment restarted"
# echo "Setup completed!"
echo "Deployment and configuration completed."