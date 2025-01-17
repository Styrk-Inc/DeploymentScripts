#!/bin/bash

# ===============================
# Environment to be Updated by USER
# ===============================

# Portal Configuration
PORTAL_STACK_NAME="Portal-ec2-stack"
PORTAL_REGION="us-east-1"
SSHKeyname="portal"
InstanceType="t2.xlarge"
ExistingIAMRoleName="Portal_ECR_Role"               # Provide the Role name created for ECR Cross Account Setup

#Cognito Parameters
COGNITO_CLIENT_ID="pass-cognito-client-id"          # Update Cognito Client ID
COGNITO_USER_POOL_ID="pass-cognito-user-pool-id"    # Update Cognito User Pool ID
COGNITO_REGION="us-east-1"                          # Update Cognito Region
COGNITO_USER_MAIL_ID="user@domain.com"              # Provide Mail ID of the Cognito User

#Secret Manager Parameters.
SECRET_NAME="secret_name"                   # Secret Name
SECRET_REGION_NAME="us-east-1"                             # AWS Region for Secrets Manager

# Cross-Account ECR Access Setup
ECR_ROLE_ARN="arn:aws:iam::637423168201:role/edna-ecr-role"     # Replace <SOURCE_ACCOUNT_ID> and <ROLE_NAME>
ECR_ROLE_SESSION_NAME="ECRAssumeRoleSession"                    # Replace session_name with any desired value (temporary)
ECR_ROLE_EXTERNAL_ID="external-id-12345"                        # Replace <ECR_ROLE_EXTERNAL_ID> with the provider's external ID

# ===============================
# Leave These Fields Unchanged (Do Not Edit)
# ===============================

PORTAL_TEMPLATE_BODY="file://portal_cf.yaml"