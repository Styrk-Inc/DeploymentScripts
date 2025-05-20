#!/bin/bash
set -euo pipefail

# Load environment config
source user-config.sh

# Store original IAM user credentials if set
export ORIGINAL_AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID:-""}
export ORIGINAL_AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY:-""}
export ORIGINAL_AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN:-""}

# Set region globally from config
export AWS_REGION=$REGION
export AWS_DEFAULT_REGION=$REGION

role_arn=${ROLE_ARN:-"arn:aws:iam::123456789012:role/MyRole"}
session_name=${SESSION_NAME:-"TestSession"}
external_id=${EXTERNAL_ID:-"external-id-12345"}
region=${REGION:-"us-east-1"}

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: 'jq' is required but not installed."
  exit 1
fi

# Assume role
echo "Assuming role..."
response=$(aws sts assume-role \
  --role-arn "$role_arn" \
  --role-session-name "$session_name" \
  --external-id "$external_id" \
  --region "$region" 2>&1)

if [[ $? -ne 0 ]]; then
  echo "Error: Failed to assume role. Details:"
  echo "$response"
  exit 1
fi

# Extract and export assumed role credentials separately
export ASSUMED_AWS_ACCESS_KEY_ID=$(echo "$response" | jq -r .Credentials.AccessKeyId)
export ASSUMED_AWS_SECRET_ACCESS_KEY=$(echo "$response" | jq -r .Credentials.SecretAccessKey)
export ASSUMED_AWS_SESSION_TOKEN=$(echo "$response" | jq -r .Credentials.SessionToken)

if [[ -z "$ASSUMED_AWS_ACCESS_KEY_ID" || -z "$ASSUMED_AWS_SECRET_ACCESS_KEY" || -z "$ASSUMED_AWS_SESSION_TOKEN" ]]; then
  echo "Error: Failed to extract temporary credentials."
  exit 1
fi

echo "✅ Temporary credentials set in ASSUMED_AWS_* variables."

# Explicitly switch to assumed-role creds to provision
export AWS_ACCESS_KEY_ID=$ASSUMED_AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$ASSUMED_AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN=$ASSUMED_AWS_SESSION_TOKEN

echo "➡️  Running provisioning script with assumed role..."
./provision_stack_cross_account.sh