#!/bin/bash

source config.sh

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

#Now delete the Stack.
echo "Deleting stack $MASTER_STACK_NAME from AWS CloudFormation..."
delete_output=$(aws cloudformation delete-stack --stack-name $MASTER_STACK_NAME --region $REGION)

# Wait for the stack to be deleted
echo "Waiting for stack to be deleted..."
aws cloudformation wait stack-delete-complete --stack-name $MASTER_STACK_NAME --region $REGION

# Check if stack deletion was successful
if [ $? -eq 0 ]; then
    echo "Stack $MASTER_STACK_NAME deleted successfully."
else
    echo "Failed to delete stack $MASTER_STACK_NAME."
    exit 1
fi


#Deleting Worker Stack...
aws eks update-kubeconfig --name $WORKER_STACK_NAME-Cluster --region $WORKER_REGION --alias detect-worker
kubectl config use-context detect-worker

# Check if the worker installation already exists
WORKER_INSTALLATION=$(helm list -q -f detect-worker)
if [ "$WORKER_INSTALLATION" == "detect-worker" ]; then
    echo "Uninstalling detect-worker from worker cluster..."
    helm uninstall detect-worker --wait
else
    echo "No detect-worker installation found on worker cluster."
fi

# Delete stack
echo "Deleting stack $WORKER_STACK_NAME from AWS CloudFormation..."
delete_output=$(aws cloudformation delete-stack --stack-name $WORKER_STACK_NAME --region $REGION)

# Wait for the stack to be deleted
echo "Waiting for stack to be deleted..."
aws cloudformation wait stack-delete-complete --stack-name $WORKER_STACK_NAME --region $REGION

# Check if stack deletion was successful
if [ $? -eq 0 ]; then
    echo "Stack $WORKER_STACK_NAME deleted successfully."
else
    echo "Failed to delete stack $WORKER_STACK_NAME."
    exit 1
fi

echo "Master & Worker EKS Stack Successfully removed..."