#!/bin/bash

# Set Variables for Master
MASTER_STACK_NAME="Detect-Master-eks-stack"
MASTER_TEMPLATE_BODY="file://eks-master-infra.yaml"
REGION="ap-south-1"  # Change this as per your AWS Region
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
WORKER_STACK_NAME="Detect-Worker-eks-stack"
WORKER_TEMPLATE_BODY="file://eks-worker-infra.yaml"
REGION="ap-south-1"  # Change this as per your AWS Region
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
aws eks update-kubeconfig --name $MASTER_STACK_NAME-Cluster --region $REGION --alias detect-master
kubectl config use-context detect-master
helm repo add bitnami https://charts.bitnami.com/bitnami 

###########################Elastic ip creation#############################
 
# Array of names (tags) for the Elastic IPs you're managing
#Declaring all the Parameters
#!/bin/bash
 
 
eip_names=("Master_Eip_1" "Master_Eip_2")
 
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
 
# Name tag value to search for
#Master_Eip_1 = aitrism-master
#EIP_NAME = Master_Eip_1
 
# Use AWS CLI to query the EIP by its Name tag and extract the IP address
ip_address_master=$(aws ec2 describe-addresses --filters "Name=tag:Name,Values=Master_Eip_1" --query 'Addresses[*].PublicIp' --output text)
 
# Check if an IP address was found
if [ -n "$ip_address_master" ] && [ "$ip_address_master" != "None" ]; then
    echo "aitrism-master ip address: 'Master_Eip_1': $ip_address_master"
else
    echo "No IP Address found for the specified name: Master_Eip_1"
fi

#Define the path of 
#values_path="/home/ubuntu/Discovery-fastApi/detect-master-chart/files/godaddy_domain.sh"
cd ../.. || exit
./detect-master-chart/files/godaddy_domain.sh $ip_address_master
#sed -i "s/IP: .*/IP: \"$ip_address_master\"/" "$values_path"
echo "value passed in bash file"

echo "pwd"
pwd

# Check if the master installation already exists
MASTER_INSTALLATION=$(helm list -q -f detect)
if [ "$MASTER_INSTALLATION" == "detect" ]; then
    echo "Uninstalling detect from master cluster..."
    helm uninstall detect --wait
else
    echo "No detect installation found on master cluster."
fi
#cd ../.. || exit
./aws-scripts/install_ebs_csi_driver.sh

# Install detect
kubectl create configmap rabbitmq-config --from-file=conf/rabbitmq.conf
kubectl create configmap rabbitmq-advanced-config --from-file=advanced.config=./conf/advanced.config


echo "Logging in to AWS ECR..."
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 975757560751.dkr.ecr.ap-south-1.amazonaws.com

# Delete the old Kubernetes secret (if exists) and create a new one
echo "Updating Kubernetes secret for Docker registry..."
kubectl delete secret regcred --ignore-not-found
TOKEN=$(aws ecr get-login-password --region ap-south-1)
kubectl create secret docker-registry regcred --docker-server=975757560751.dkr.ecr.ap-south-1.amazonaws.com/detect --docker-username=AWS --docker-password=$TOKEN
echo "Current working directory:"
pwd
helm dependency build detect-master-chart/
helm install detect detect-master-chart/



# Update kubeconfig for Worker Cluster
aws eks update-kubeconfig --name $WORKER_STACK_NAME-Cluster --region $REGION --alias detect-worker
kubectl config use-context detect-worker
kubectl create configmap rabbitmq-config --from-file=conf/rabbitmq.conf
kubectl create configmap rabbitmq-advanced-config --from-file=conf/advanced.config
# Check if the worker installation already exists
WORKER_INSTALLATION=$(helm list -q -f detect-worker)
if [ "$WORKER_INSTALLATION" == "detect-worker" ]; then
    echo "Uninstalling detect-worker from worker cluster..."
    helm uninstall detect-worker --wait
else
    echo "No detect-worker installation found on worker cluster."
fi



#Installing Matric-server in the worker Cluster.
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Install detect-worker
echo "Logging in to AWS ECR..."
aws ecr get-login-password --region ap-south-1 | docker login --username AWS --password-stdin 975757560751.dkr.ecr.ap-south-1.amazonaws.com

# Delete the old Kubernetes secret (if exists) and create a new one
echo "Updating Kubernetes secret for Docker registry..."
kubectl delete secret regcred --ignore-not-found
TOKEN=$(aws ecr get-login-password --region ap-south-1)
kubectl create secret docker-registry regcred --docker-server=975757560751.dkr.ecr.ap-south-1.amazonaws.com/detect --docker-username=AWS --docker-password=$TOKEN

helm install detect-worker detect-worker-chart/
