#!/bin/bash

# Set Variables for Master
MASTER_STACK_NAME="Vardaan-Master-eks-stack"
REGION="us-east-1"  # Change this as per your AWS Region

# Delete stack
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

# Set Variables for Worker
WORKER_STACK_NAME="Vardaan-Worker-eks-stack"
REGION="us-east-1"  # Change this as per your AWS Region

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
