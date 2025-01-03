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
            return {key: value.encode("utf-8") for key, value in secret_json.items()}
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
    data = {key: base64.b64encode(value).decode("utf-8") for key, value in secret_data.items()}
    body = {"apiVersion": "v1", "kind": "Secret", "metadata": metadata, "data": data}
    try:
        resp = v1.create_namespaced_secret(namespace=namespace, body=body)
        print("Kubernetes secret created successfully in default namespace.")
    except client.exceptions.ApiException as e:
        print(f"Error creating Kubernetes secret: {e}")
else:
    print("Failed to retrieve secret value.")



# import boto3
# from botocore.exceptions import ClientError,NoCredentialsError
# import subprocess
# # import json
# # import base64

# def get_secret_value(secret_name, region_name, source_account_id, role_name):
#     print("Assuming cross-account role...")
#     sts_client = boto3.client('sts')
#     role_arn = f"arn:aws:iam::{source_account_id}:role/{role_name}"
#     try:
#         assumed_role = sts_client.assume_role(
#             RoleArn=role_arn,
#             RoleSessionName="AssumeRoleSession",
#             #ExternalId=externalId
#         )
#     except NoCredentialsError:
#         print("No AWS credentials were found. Please set them up.")
#         return None
#     print("Retrieving secret value...")
#     session = boto3.Session(
#         aws_access_key_id=assumed_role['Credentials']['AccessKeyId'],
#         aws_secret_access_key=assumed_role['Credentials']['SecretAccessKey'],
#         aws_session_token=assumed_role['Credentials']['SessionToken'],
#     )
#     client = session.client(service_name='secretsmanager', region_name=region_name)

#     try:
#         response = client.get_secret_value(SecretId=secret_name)
#         print("Secret value retrieved successfully.")
#         if 'SecretString' in response:
#             secret = response['SecretString']
#             return secret
#         else:
#             secret = response['SecretBinary']
#             return secret
#     except ClientError as e:
#         print("Error occurred:", e)
#         return None

# # Usage
# secret_name = "Defend-Secret-infra"
# region_name = "us-east-1"
# source_account_id = "975757560751"
# role_name = "Defend_Secret_Role"
# #RoleArn=f"arn:aws:iam::975757560751:role/Defend_Secret_Role"
# #ExternalId="test123"
# print("Getting secret value for", secret_name, "in region", region_name)
# secret_value = get_secret_value(secret_name, region_name, source_account_id, role_name)
# if secret_value:
#     print("Secret Value:", secret_value)

# # # Extract the secret value from the output
# # secret_value = secret_value_output.decode("utf-8").strip()
# # print("Retrieved secret value:", secret_value)

# # Define the secret value as a dictionary
# # KMS_Key_ARN = "arn:aws:kms:us-east-1:975757560751:key/f66e635f-be2f-46a5-b963-d5ff4017dbc7"

# # # Convert the dictionary to a JSON string
# # plaintext = json.dumps(secret_value)

# # # Encode the plaintext JSON string into bytes
# # plaintext_bytes = plaintext.encode('utf-8')

# # # Base64 encode the bytes
# # plaintext_base64 = base64.b64encode(plaintext_bytes).decode('utf-8')

# # # Now, let's encrypt the plaintext using KMS
# # # Assuming KMS_Key_ARN is already defined
# # kms_command = f"aws kms encrypt --key-id {KMS_Key_ARN} --plaintext \"{plaintext_base64}\" --query CiphertextBlob --output text"
# # result = subprocess.run(kms_command, shell=True, capture_output=True, text=True)

# # if result.returncode == 0:
# #     encrypted_value = result.stdout.strip()
# #     print("Secret encrypted successfully.")
# #     # Construct the kubectl command to create the Kubernetes secret
# #     kubectl_cmd = f"kubectl create secret generic aws-secret-manager --from-literal=secret={encrypted_value}"
# #     # Run the kubectl command
# #     subprocess.run(kubectl_cmd, shell=True)
# #     print("Kubernetes secret created successfully.")
# # else:
# #     print("Error encrypting secret:", result.stderr)


# # # Create Kubernetes secret with encrypted value
# # kubectl_cmd = f"kubectl create secret generic aws-secret-manager --from-literal=secret={encrypted_value}"
# # subprocess.run(kubectl_cmd, shell=True)
# # print("Kubernetes secret created successfully.")


# # Create Kubernetes secret
# kubectl_cmd = f"kubectl create secret generic aitrism-aws --from-literal=secret={secret_value}"
# subprocess.run(kubectl_cmd, shell=True)
# print("Kubernetes secret created successfully.")
