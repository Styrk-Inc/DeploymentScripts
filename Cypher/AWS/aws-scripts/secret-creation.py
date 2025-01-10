from kubernetes import client, config
import boto3
from botocore.exceptions import ClientError
import json
import base64

def get_secret_value(secret_name, region_name, source_account_id, role_name):
    sts_client = boto3.client('sts')
    role_arn = f"arn:aws:iam::{source_account_id}:role/{role_name}"
    try:
        assumed_role = sts_client.assume_role(
            RoleArn=role_arn,
            RoleSessionName="AssumeRoleSession",
        )
    except ClientError as e:
        print("Error assuming role:", e)
        return None

    session = boto3.Session(
        aws_access_key_id=assumed_role['Credentials']['AccessKeyId'],
        aws_secret_access_key=assumed_role['Credentials']['SecretAccessKey'],
        aws_session_token=assumed_role['Credentials']['SessionToken'],
    )
    client = session.client(service_name='secretsmanager', region_name=region_name)

    try:
        response = client.get_secret_value(SecretId=secret_name)
        if 'SecretString' in response:
            secret_string = response['SecretString']
            secret_json = json.loads(secret_string)
            # Ensure all keys and values are properly formatted (no spaces or invalid characters)
            return {key.strip().replace(" ", "_"): value.encode("utf-8") for key, value in secret_json.items()}
        else:
            print("Secret binary is not supported.")
            return None
    except ClientError as e:
        print("Error occurred:", e)
        return None

# Usage
secret_name = "Defend-Secret-infra"
region_name = "us-east-1"
source_account_id = "637423168201"
role_name = "Defend_Secret_Role"
k8s_secret_name = "aitrism-aws"
namespace = "default"

print("Getting secret value for", secret_name, "in region", region_name)
secret_data = get_secret_value(secret_name, region_name, source_account_id, role_name)
if secret_data:
    # Configure Kubernetes client
    config.load_kube_config()  # Assuming kubeconfig is available
    v1 = client.CoreV1Api()

    # Delete existing Kubernetes secret if it exists
    try:
        v1.delete_namespaced_secret(name=k8s_secret_name, namespace=namespace)
        print(f"Deleted existing Kubernetes secret '{k8s_secret_name}' in namespace '{namespace}'.")
    except client.exceptions.ApiException as e:
        if e.status == 404:
            print(f"No existing secret named '{k8s_secret_name}' found in namespace '{namespace}'. Proceeding to create a new one.")
        else:
            print(f"Error deleting Kubernetes secret: {e}")
            raise

    # Create new Kubernetes secret
    metadata = {"name": k8s_secret_name}
    # Ensure all keys are valid (no invalid characters or spaces)
    data = {key: base64.b64encode(value).decode("utf-8") for key, value in secret_data.items()}
    body = {"apiVersion": "v1", "kind": "Secret", "metadata": metadata, "data": data}
    try:
        resp = v1.create_namespaced_secret(namespace=namespace, body=body)
        print("Kubernetes secret created successfully in default namespace.")
    except client.exceptions.ApiException as e:
        print(f"Error creating Kubernetes secret: {e}")
else:
    print("Failed to retrieve secret value.")