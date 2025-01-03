#!/bin/bash

# Set Variables for Master
MASTER_STACK_NAME="Detect-Master-1-eks-stack"
MASTER_TEMPLATE_BODY="file://eks-master-infra.yaml"
REGION="ap-south-1"  # Change this as per your AWS Region
MasterNodeGroupDesiredSize="2"
MasterNodeGroupMinSize="2"
MasterNodeGroupMaxSize="3"
MasterSSHKeyname="mumbai_keypair_infrablok"

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
WORKER_STACK_NAME="Detect-Worker-1-eks-stack"
WORKER_TEMPLATE_BODY="file://eks-worker-infra.yaml"
REGION="ap-south-1"  # Change this as per your AWS Region
WorkerNodeGroupDesiredSize="2"
WorkerNodeGroupMinSize="2"
WorkerNodeGroupMaxSize="3"
WorkerSSHKeyname="mumbai_keypair_infrablok"

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
