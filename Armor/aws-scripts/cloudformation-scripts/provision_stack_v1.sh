#!/bin/bash

# Set Variables for Master
MASTER_STACK_NAME="Vardaan-Master-eks-stack"
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
WORKER_STACK_NAME="Vardaan-Worker-eks-stack"
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

#kubectl create configmap rabbitmq-config --from-file=rabbitmq.conf

#Installing Matric-server in the worker Cluster.
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Install aitrism-worker
echo "Logging in to AWS ECR..."
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 975757560751.dkr.ecr.us-east-1.amazonaws.com

# Delete the old Kubernetes secret (if exists) and create a new one
echo "Updating Kubernetes secret for Docker registry..."
kubectl delete secret regcred3 --ignore-not-found
TOKEN=$(aws ecr get-login-password --region us-east-1)
kubectl create secret docker-registry regcred3 --docker-server=975757560751.dkr.ecr.us-east-1.amazonaws.com/aitrism --docker-username=AWS --docker-password=$TOKEN

helm install aitrism-worker aitrism-worker-chart/
