#!/bin/bash
source user-config-1.sh

# Define the target file (e.g., your CloudFormation template or any script)
target_file="portal_cf.yaml"

# Perform replacements using sed
# Update Cross Account Setup for ECR access
sed -i "s|ECR_ROLE_ARN=\".*\"|ECR_ROLE_ARN=\"${ECR_ROLE_ARN}\"|" "$target_file"
sed -i "s|ECR_ROLE_SESSION_NAME=\".*\"|ECR_ROLE_SESSION_NAME=\"${ECR_ROLE_SESSION_NAME}\"|" "$target_file"
sed -i "s|ECR_ROLE_EXTERNAL_ID=\".*\"|ECR_ROLE_EXTERNAL_ID=\"${ECR_ROLE_EXTERNAL_ID}\"|" "$target_file"

# Update Secret Manager values
sed -i "s|SECRET_BASE_NAME: \".*\"|SECRET_BASE_NAME: \"${SECRET_BASE_NAME}\"|" "$target_file"
sed -i "s|SECRET_REGION_NAME: \".*\"|SECRET_REGION_NAME: \"${SECRET_REGION_NAME}\"|" "$target_file"

# Update Cognito values
sed -i "s|COGNITO_CLIENT_ID: \".*\"|COGNITO_CLIENT_ID: \"${COGNITO_CLIENT_ID}\"|" "$target_file"
sed -i "s|COGNITO_USER_POOL_ID: \".*\"|COGNITO_USER_POOL_ID: \"${COGNITO_USER_POOL_ID}\"|" "$target_file"
sed -i "s|COGNITO_REGION: \".*\"|COGNITO_REGION: \"${COGNITO_REGION}\"|" "$target_file"
sed -i "s|NEW_USERNAME: \".*\"|NEW_USERNAME: \"${NEW_USERNAME}\"|" "$target_file"

# Print a message indicating completion
echo "Replacements completed successfully in $target_file."

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
