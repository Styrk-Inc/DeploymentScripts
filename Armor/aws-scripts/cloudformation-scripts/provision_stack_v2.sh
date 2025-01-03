#!/bin/bash

# Set Variables for Master
MASTER_STACK_NAME="Master-eks-stack"
MASTER_TEMPLATE_BODY="file://eks-master-infra.yaml"
REGION="us-east-1"  # Change this as per your AWS Region
MasterNodeGroupDesiredSize="2"
MasterNodeGroupMinSize="2"
MasterNodeGroupMaxSize="3"
MasterSSHKeyname="infrablok_key"

#Creating Master Cluster
# Create stack
echo "Creating stack $MASTER_STACK_NAME in AWS CloudFormation..."
create_output=$(aws cloudformation create-stack --stack-name $MASTER_STACK_NAME --template-body $MASTER_TEMPLATE_BODY --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameters ParameterKey=MasterNodeGroupDesiredSize,ParameterValue=$MasterNodeGroupDesiredSize ParameterKey=MasterNodeGroupMinSize,ParameterValue=$MasterNodeGroupMinSize ParameterKey=MasterNodeGroupMaxSize,ParameterValue=$MasterNodeGroupMaxSize ParameterKey=MasterSSHKeyname,ParameterValue=$MasterSSHKeyname --region $REGION)

# Wait for the stack to be created
echo "Waiting for stack to be created..."
aws cloudformation wait stack-create-complete --stack-name $MASTER_STACK_NAME --region $REGION

# Check if stack creation was successful
if [ $? -eq 0 ]; then
    echo "Stack $MASTER_STACK_NAME created successfully."
else
    echo "Failed to create stack $MASTER_STACK_NAME."
    exit 1
fi


#Set Variables for Worker
WORKER_STACK_NAME="Worker-eks-stack"
WORKER_TEMPLATE_BODY="file://eks-worker-infra.yaml"
REGION="us-east-1"  # Change this as per your AWS Region
WorkerNodeGroupDesiredSize="2"
WorkerNodeGroupMinSize="2"
WorkerNodeGroupMaxSize="3"
WorkerSSHKeyname="infrablok_key"

#Creating the Worker Cluster
# Create stack
echo "Creating stack $WORKER_STACK_NAME in AWS CloudFormation..."
create_output=$(aws cloudformation create-stack --stack-name $WORKER_STACK_NAME --template-body $WORKER_TEMPLATE_BODY --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameters ParameterKey=WorkerNodeGroupDesiredSize,ParameterValue=$WorkerNodeGroupDesiredSize ParameterKey=WorkerNodeGroupMinSize,ParameterValue=$WorkerNodeGroupMinSize ParameterKey=WorkerNodeGroupMaxSize,ParameterValue=$WorkerNodeGroupMaxSize ParameterKey=WorkerSSHKeyname,ParameterValue=$WorkerSSHKeyname --region $REGION)

# Wait for the stack to be created
echo "Waiting for stack to be created..."
aws cloudformation wait stack-create-complete --stack-name $WORKER_STACK_NAME --region $REGION

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
aws eks update-kubeconfig --name $MASTER_STACK_NAME-Cluster --region $REGION --alias master
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
docker-compose run airflow-webserver airflow db init
#When run for first time
docker-compose run airflow-webserver airflow users create \
--username admin \
--password admin \
--firstname Vilayannur \
--lastname Sitaraman \
--role Admin \
--email vsitaraman@infrablok.com
#docker compose run airflow-webserver airflow db upgrade


echo "Logging in to AWS ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 975757560751.dkr.ecr.us-east-1.amazonaws.com

# Delete the old Kubernetes secret (if exists) and create a new one
echo "Updating Kubernetes secret for Docker registry..."
kubectl delete secret regcred3 --ignore-not-found
TOKEN=$(aws ecr get-login-password --region us-east-1)
kubectl create secret docker-registry regcred3 --docker-server=975757560751.dkr.ecr.us-east-1.amazonaws.com/aitrism --docker-username=AWS --docker-password=$TOKEN
echo "Current working directory:"
pwd

############################Elastic ip creation#############################
#!/bin/bash

# Array of names (tags) for the Elastic IPs you're managing
eip_names=("aitrism-master" "aitrism-master-2")  # Example names

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
EIP_NAME="aitrism-master"

# Use AWS CLI to query the EIP by its Name tag and extract the IP address
ip_address_master=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$EIP_NAME" --query 'Addresses[*].PublicIp' --output text)

# Check if an IP address was found
if [ -n "$ip_address_master" ] && [ "$ip_address_master" != "None" ]; then
    echo "aitrism-master ip address: '$EIP_NAME': $ip_address_master"
else
    echo "No IP Address found for the specified name: $EIP_NAME"
fi


#------------------------- Elastic IP for FrontEnd-------------------------------------------------
# Array of names (tags) for the Elastic IPs you're managing
eip_names=("aitrism-reactapp" "aitrism-reactapp-2")  # Example names

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
EIP_NAME="aitrism-reactapp"

# Use AWS CLI to query the EIP by its Name tag and extract the IP address
ip_address_reactapp=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$EIP_NAME" --query 'Addresses[*].PublicIp' --output text)

# Check if an IP address was found
if [ -n "$ip_address_reactapp" ] && [ "$ip_address_reactapp" != "None" ]; then
    echo "aitrism-reactapp ip address: '$EIP_NAME': $ip_address_reactapp"
else
    echo "No IP Address found for the specified name: $EIP_NAME"
fi

#-----------------------------Elastic Ips for Kafka----------------------------------
# Array of names (tags) for the Elastic IPs you're managing
eip_names=("aitrism-kafka" "aitrism-kafka-2")  # Example names

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
EIP_NAME="aitrism-kafka"

# Use AWS CLI to query the EIP by its Name tag and extract the IP address
ip_address_kafka=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=$EIP_NAME" --query 'Addresses[*].PublicIp' --output text)

# Check if an IP address was found
if [ -n "$ip_address_kafka" ] && [ "$ip_address_kafka" != "None" ]; then
    echo "aitrism-kafka ip address: '$EIP_NAME': $ip_address_kafka"
else
    echo "No IP Address found for the specified name: $EIP_NAME"
fi

#########################modify .env to change redis_client host##########################
# Define the file path
file_path=".env"

# Use sed to replace the placeholder or an existing IP address
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^REDIS_HOST=.*/REDIS_HOST=${ip_address_master}/" "$file_path"
else
    # Linux
    sed -i "s/^REDIS_HOST=.*/REDIS_HOST=${ip_address_master}/" "$file_path"
fi

#---------------build and push worker image-------------------------------------
echo "Logging in to AWS ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 975757560751.dkr.ecr.us-east-1.amazonaws.com
docker-compose -f docker-compose-worker.yml build
docker tag fastapi_celery_example_celery_worker:latest 975757560751.dkr.ecr.us-east-1.amazonaws.com/defend-vardaan:worker
docker push 975757560751.dkr.ecr.us-east-1.amazonaws.com/defend-vardaan:worker

#---------------build and push master image-------------------------------------
docker-compose -f docker-compose-web.yml build
docker tag fastapi_celery_example_web:latest 975757560751.dkr.ecr.us-east-1.amazonaws.com/defend-vardaan:web
docker push 975757560751.dkr.ecr.us-east-1.amazonaws.com/defend-vardaan:web


#######Modify .env for front end#########################################
# Specify the path to your .env file
env_file="./aitrism-react-app/.env"

# Use sed to replace the IP address in the specified line
# Detecting the platform to handle the in-place (-i) flag correctly for both GNU sed and BSD sed
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS (BSD sed)
  sed -i '' "s|REACT_APP_DEFEND_BACKEND_API_ENDPOINT=http://[^:]*:8000/|REACT_APP_DEFEND_BACKEND_API_ENDPOINT=http://${ip_address_master}:8000/|" "$env_file"
else
  # Linux (GNU sed)
  sed -i "s|REACT_APP_DEFEND_BACKEND_API_ENDPOINT=http://[^:]*:8000/|REACT_APP_DEFEND_BACKEND_API_ENDPOINT=http://${ip_address_master}:8000/|" "$env_file"
fi

docker-compose -f docker-compose-frontend.yaml build
# Set up AWS credentials and login to ECR
echo "Logging in to AWS ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 975757560751.dkr.ecr.us-east-1.amazonaws.com

# Delete the old Kubernetes secret (if exists) and create a new one
echo "Updating Kubernetes secret for Docker registry..."
kubectl delete secret regcred3 --ignore-not-found
TOKEN=$(aws ecr get-login-password --region us-east-1)
kubectl create secret docker-registry regcred3 --docker-server=975757560751.dkr.ecr.us-east-1.amazonaws.com/aitrism --docker-username=AWS --docker-password=$TOKEN

docker tag aitrism_frontend:latest 975757560751.dkr.ecr.us-east-1.amazonaws.com/defend-vardaan:frontend
docker push 975757560751.dkr.ecr.us-east-1.amazonaws.com/defend-vardaan:frontend




#kubectl create configmap rabbitmq-config --from-file=rabbitmq.conf

#Installing Matric-server in the Master Cluster.
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Install aitrism-worker
echo "Logging in to AWS ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 975757560751.dkr.ecr.us-east-1.amazonaws.com

# Delete the old Kubernetes secret (if exists) and create a new one
echo "Updating Kubernetes secret for Docker registry..."
kubectl delete secret regcred3 --ignore-not-found
TOKEN=$(aws ecr get-login-password --region us-east-1)
kubectl create secret docker-registry regcred3 --docker-server=975757560751.dkr.ecr.us-east-1.amazonaws.com/aitrism --docker-username=AWS --docker-password=$TOKEN


############################################################################

helm dependency build aitrism-master-chart/
helm install aitrism aitrism-master-chart/

docker-compose run airflow-webserver airflow db upgrade

#kubectl config use-context $
#LOCAL_CONTEXT
# Update kubeconfig for Worker Cluster
aws eks update-kubeconfig --name $WORKER_STACK_NAME-Cluster --region $REGION --alias worker
kubectl config use-context worker
kubectl create configmap rabbitmq-config --from-file=conf/rabbitmq.conf
kubectl create configmap rabbitmq-advanced-config --from-file=conf/advanced.config

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

# Define the path to your values.yaml file
values_path="./aitrism-worker-chart/values.yaml"

# Check the operating system
if [[ "$OSTYPE" == "darwin"* ]]; then
  # macOS requires an empty string argument after -i to edit in place without backup
  echo "REplacing ${ip_address_master} ${ip_address_kafka}"
  sed -i '' "s/AITRISM_MASTER_DNS: .*/AITRISM_MASTER_DNS: \"$ip_address_master\"/" "$values_path"
  sed -i '' "s/AITRISM_KAFKA_BOOTSTRAP_SERVER: .*/AITRISM_KAFKA_BOOTSTRAP_SERVER: \"$ip_address_kafka\"/" "$values_path"
else
  # Linux
  echo "REplacing ${ip_address_master} ${ip_address_kafka}"
  sed -i "s/AITRISM_MASTER_DNS: .*/AITRISM_MASTER_DNS: \"$ip_address_master\"/" "$values_path"
  sed -i "s/AITRISM_KAFKA_BOOTSTRAP_SERVER: .*/AITRISM_KAFKA_BOOTSTRAP_SERVER: \"$ip_address_kafka\"/" "$values_path"
fi

helm install aitrism-worker aitrism-worker-chart/
