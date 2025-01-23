#!/bin/bash
source user-config.sh

# Define the target file (e.g., your CloudFormation template or any script)
target_file="portal_cf.yaml"

# Perform replacements using sed
# Update Cross Account Setup for ECR access
sed -i "s|ECR_ROLE_ARN=\".*\"|ECR_ROLE_ARN=\"${ECR_ROLE_ARN}\"|" "$target_file"
sed -i "s|ECR_ROLE_SESSION_NAME=\".*\"|ECR_ROLE_SESSION_NAME=\"${ECR_ROLE_SESSION_NAME}\"|" "$target_file"
sed -i "s|ECR_ROLE_EXTERNAL_ID=\".*\"|ECR_ROLE_EXTERNAL_ID=\"${ECR_ROLE_EXTERNAL_ID}\"|" "$target_file"

# Update Secret Manager values
sed -i "s|SECRET_NAME: \".*\"|SECRET_NAME: \"${SECRET_NAME}\"|" "$target_file"
sed -i "s|SECRET_REGION_NAME: \".*\"|SECRET_REGION_NAME: \"${SECRET_REGION_NAME}\"|" "$target_file"

# Update Cognito values
sed -i "s|COGNITO_CLIENT_ID: \".*\"|COGNITO_CLIENT_ID: \"${COGNITO_CLIENT_ID}\"|" "$target_file"
sed -i "s|COGNITO_USER_POOL_ID: \".*\"|COGNITO_USER_POOL_ID: \"${COGNITO_USER_POOL_ID}\"|" "$target_file"
sed -i "s|COGNITO_REGION: \".*\"|COGNITO_REGION: \"${COGNITO_REGION}\"|" "$target_file"
sed -i "s|NEW_USERNAME: \".*\"|NEW_USERNAME: \"${COGNITO_USER_MAIL_ID}\"|" "$target_file"

# Print a message indicating completion
echo "Replacements completed successfully in $target_file."

# # Update MongoDb password
# # Step 1: Generate a dynamic password each time the script runs
# # mongodb_password=$(openssl rand -base64 16)
# mongodb_password=$(openssl rand -hex 8)

# Define the path where the MongoDB password will be saved
password_file="./mongodb_password.txt"

# Check if the password file exists
if [ -f "$password_file" ]; then
  echo "MongoDB password already exists. Using the stored password."
  mongodb_password=$(cat "$password_file")
else
  # Step 1: Generate a dynamic password if it doesn't exist
  echo "Generating a new MongoDB password..."
  mongodb_password=$(openssl rand -hex 8)

  # Save the generated password to the file
  echo "$mongodb_password" > "$password_file"
  echo "MongoDB password has been saved to $password_file"
fi

# Define the path to the configuration file where the MongoDB password is stored
config_file_path="./portal_cf.yaml"

# Ensure that the path is correct and the file exists
echo "Checking if the config file exists: $config_file_path"
if [ -f "$config_file_path" ]; then
  echo "Config file exists!"
else
  echo "Config file not found. Please check the path."
  exit 1
fi

# Step 2: Update MongoDB password in the config file (specific to the private GPT container environment variables)
echo "Updating MongoDB password in config file..."
# Update in Env of Portal Backend
#sed -i "s|mongo_password: .*|mongo_password: $mongodb_password|g" "$config_file_path"
sed -i "s|mongo_password: .*|mongo_password: \"$mongodb_password\"|g" "$config_file_path"
# Update in Compose file
sed -i "s|MONGO_INITDB_ROOT_PASSWORD: .*|MONGO_INITDB_ROOT_PASSWORD: \"$mongodb_password\"|g" "$config_file_path"

# Step 3: Optionally print the new password for verification
echo "Generated MongoDB Password: $mongodb_password"


# Creating Portal Instance
# Create stack
echo "Creating stack $PORTAL_STACK_NAME in AWS CloudFormation..."
create_output=$(aws cloudformation create-stack --stack-name $PORTAL_STACK_NAME --template-body $PORTAL_TEMPLATE_BODY --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM --parameters ParameterKey=SSHKeyname,ParameterValue=$SSHKeyname ParameterKey=InstanceType,ParameterValue=$InstanceType ParameterKey=ExistingIAMRoleName,ParameterValue=$ExistingIAMRoleName --region $PORTAL_REGION)

# Wait for the stack to be created
echo "Waiting for stack to be created..."
aws cloudformation wait stack-create-complete --stack-name $PORTAL_STACK_NAME --region $PORTAL_REGION

# Check if stack creation was successful
if [ $? -eq 0 ]; then
    echo "Stack $PORTAL_STACK_NAME created successfully."
    
    # Retrieve the stack outputs and extract the ALB DNS Name
    ALBDNSName=$(aws cloudformation describe-stacks --stack-name $PORTAL_STACK_NAME --region $PORTAL_REGION \
        --query "Stacks[0].Outputs[?OutputKey=='ALBDNSName'].OutputValue" --output text)
    
    # Display the ALB DNS Name
    echo "ALB DNS Name: $ALBDNSName"
else
    echo "Failed to create stack $PORTAL_STACK_NAME."
    exit 1
fi