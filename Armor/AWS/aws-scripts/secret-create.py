import boto3
import os
import subprocess
import json

# === Configurable via environment variables ===
REGION = os.getenv("AWS_REGION", "us-east-1")
SECRET_NAME = os.getenv("SECRET_NAME", "Defend-Secret-infra")
K8S_SECRET_NAME = os.getenv("K8S_SECRET_NAME", "aitrism-aws")
K8S_NAMESPACE = os.getenv("K8S_NAMESPACE", "default")

# # === Assumed credentials must be set in env by shell before this script is run ===
# ASSUMED_ENV_VARS = ["ASSUMED_AWS_ACCESS_KEY_ID", "ASSUMED_AWS_SECRET_ACCESS_KEY", "ASSUMED_AWS_SESSION_TOKEN"]

# def validate_assumed_credentials():
#     for var in ASSUMED_ENV_VARS:
#         if not os.getenv(var):
#             raise EnvironmentError(f"❌ Missing required environment variable: {var}")

def get_secret_from_aws(secret_name: str) -> dict:
    """Fetch secret from AWS Secrets Manager using boto3."""
    client = boto3.client("secretsmanager", region_name=REGION)
    response = client.get_secret_value(SecretId=secret_name)
    secret_string = response["SecretString"]
    return json.loads(secret_string)

def create_k8s_secret(secret_data: dict):
    """Use kubectl to create a Kubernetes secret using assumed role credentials."""
    # Build command with each key as --from-literal
    cmd = [
        "kubectl", "create", "secret", "generic", K8S_SECRET_NAME,
        "--namespace", K8S_NAMESPACE,
        "--dry-run=client", "-o", "yaml"
    ]

    for key, value in secret_data.items():
        cmd.extend(["--from-literal", f"{key}={value}"])

    # Generate YAML
    print("🔧 Generating Kubernetes secret manifest...")
    secret_yaml = subprocess.check_output(cmd)

    # Save YAML to a file
    with open("secret.yaml", "wb") as f:
        f.write(secret_yaml)

    print("🔁 Switching to assumed role credentials for kubectl...")
    # Switch to assumed creds (must be exported already by shell)
    assumed_env = os.environ.copy()
    assumed_env["AWS_ACCESS_KEY_ID"] = os.environ["ASSUMED_AWS_ACCESS_KEY_ID"]
    assumed_env["AWS_SECRET_ACCESS_KEY"] = os.environ["ASSUMED_AWS_SECRET_ACCESS_KEY"]
    assumed_env["AWS_SESSION_TOKEN"] = os.environ["ASSUMED_AWS_SESSION_TOKEN"]

    print("🚀 Applying secret to Kubernetes...")
    subprocess.run(["kubectl", "apply", "-f", "secret.yaml"], check=True, env=assumed_env)


if __name__ == "__main__":
    try:
        print(f"Getting secret value for {SECRET_NAME} in region {REGION}")
        secret = get_secret_from_aws(SECRET_NAME)
        print("✅ Secret fetched from AWS.")
        create_k8s_secret(secret)
        print("✅ Kubernetes secret created successfully.")
    except Exception as e:
        print(f"❌ Error occurred: {e}")
