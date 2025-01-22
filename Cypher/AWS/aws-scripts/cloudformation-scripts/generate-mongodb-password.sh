#!/bin/bash

# Step 1: Generate a dynamic password each time the script runs
#mongodb_password=$(openssl rand -base64 16)
mongodb_password=$(openssl rand -hex 8)

# Define the path to the master values.yaml file
detect_master_chart_values_path="../../detect-master-chart/values.yaml"

# Ensure that the path is correct and the file exists
echo "Checking if the path exists: $detect_master_chart_values_path"
if [ -f "$detect_master_chart_values_path" ]; then
  echo "File exists!"
else
  echo "File not found. Please check the path."
  exit 1
fi

# Proceed with replacing values if file exists
# Step 2: Replace the old rootPassword and password with the newly generated password
echo "Replacing rootPassword and password with the new MongoDB password..."
# sed -i "s|rootPassword: .*|rootPassword: $mongodb_password|g" "$detect_master_chart_values_path"
# sed -i "s|password: .*|password: $mongodb_password|g" "$detect_master_chart_values_path"
sed -i "s|rootPassword: .*|rootPassword: \"$mongodb_password\"|g" "$detect_master_chart_values_path"
sed -i "s|password: .*|password: \"$mongodb_password\"|g" "$detect_master_chart_values_path"

# Master deployment file update MongoDB password
detect_master_chart_deployment_path="../../detect-master-chart/templates/deployment.yaml"

# Ensure that the deployment file exists
echo "Checking if the deployment file exists: $detect_master_chart_deployment_path"
if [ -f "$detect_master_chart_deployment_path" ]; then
  echo "Deployment file exists!"
else
  echo "Deployment file not found. Please check the path."
  exit 1
fi

# Update the MongoDB password in the deployment file
echo "Updating MongoDB password in deployment file..."
sed -i "s|mongodb://admin:admin@detect-mongodb|mongodb://admin:$mongodb_password@detect-mongodb|g" "$detect_master_chart_deployment_path"


# Worker values path
detect_worker_chart_values_path="../../detect-worker-chart/values.yaml"

# Ensure that the worker values file exists
echo "Checking if the worker values file exists: $detect_worker_chart_values_path"
if [ -f "$detect_worker_chart_values_path" ]; then
  echo "Worker values file exists!"
else
  echo "Worker values file not found. Please check the path."
  exit 1
fi

# Update MongoDB password in the worker values.yaml file
echo "Updating MongoDB password in worker values.yaml..."
# sed -i "s|mongodbPassword: .*|mongodbPassword: $mongodb_password|g" "$detect_worker_chart_values_path"
sed -i "s|mongodbPassword: .*|mongodbPassword: \"$mongodb_password\"|g" "$detect_worker_chart_values_path"

# Worker deployment file update MongoDB password
detect_worker_chart_deployment_path="../../detect-worker-chart/templates/worker-deployment.yaml"

# Ensure that the worker deployment file exists
echo "Checking if the worker deployment file exists: $detect_worker_chart_deployment_path"
if [ -f "$detect_worker_chart_deployment_path" ]; then
  echo "Worker deployment file exists!"
else
  echo "Worker deployment file not found. Please check the path."
  exit 1
fi

# Update MongoDB password in the worker deployment file
echo "Updating MongoDB password in worker deployment file..."
sed -i "s|mongodb://admin:admin@{{ .Values.env.MONGODB_SVC_NAME }}|mongodb://admin:$mongodb_password@{{ .Values.env.MONGODB_SVC_NAME }}|g" "$detect_worker_chart_deployment_path"

# Step 3: Optionally print the new password for verification
echo "Generated MongoDB Password: $mongodb_password"
