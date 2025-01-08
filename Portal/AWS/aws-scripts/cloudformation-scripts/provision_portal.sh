#!/bin/bash
source user-config.sh

# Creating Portal Instance
# Create stack
echo "Creating stack $PORTAL_STACK_NAME in AWS CloudFormation..."
create_output=$(aws cloudformation create-stack --stack-name $PORTAL_STACK_NAME --template-body $PORTAL_TEMPLATE_BODY --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameters ParameterKey=SSHKeyname,ParameterValue=$SSHKeyname ParameterKey=InstanceType,ParameterValue=$InstanceType --region $PORTAL_REGION)

# Wait for the stack to be created
echo "Waiting for stack to be created..."
aws cloudformation wait stack-create-complete --stack-name $PORTAL_STACK_NAME --region $PORTAL_REGION

# Check if stack creation was successful
if [ $? -eq 0 ]; then
    echo "Stack $PORTAL_STACK_NAME created successfully."
else
    echo "Failed to create stack $PORTAL_STACK_NAME."
    exit 1
fi
