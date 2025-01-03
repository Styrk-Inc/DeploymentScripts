#https://docs.aws.amazon.com/eks/latest/userguide/managing-ebs-csi.html#adding-ebs-csi-eks-add-on

MASTER_CLUSTER_NAME="sitaraman-master-eks-cluster"
WORKER_CLUSTER_NAME="sitaraman-worker-eks-cluster"
REGION="us-east-1"

eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster $MASTER_CLUSTER_NAME \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve \
    --role-name AmazonEKS_EBS_CSI_DriverRole \
    --role-only


aws iam attach-role-policy \
  --policy-arn arn:aws:iam::975757560751:policy/KMS_Key_For_Encryption_On_EBS_Policy \
  --role-name AmazonEKS_EBS_CSI_DriverRole

eksctl create addon --name aws-ebs-csi-driver --cluster $MASTER_CLUSTER_NAME --service-account-role-arn arn:aws:iam::975757560751:role/AmazonEKS_EBS_CSI_DriverRole --force

#eksctl get addon --name aws-ebs-csi-driver --cluster my-cluster
#Run the following command
#eksctl get addon --name aws-ebs-csi-driver --cluster sitaraman-master-eks-cluster
##GEt the version number from the above command and use in below
#ADDON_VERSION=v1.26.0-eksbuild.1
#eksctl update addon --name aws-ebs-csi-driver --version $ADDON_VERSION --cluster $MASTER_CLUSTER_NAME \
#  --service-account-role-arn arn:aws:iam::975757560751:role/AmazonEKS_EBS_CSI_DriverRole --force



# Fetch the details of the aws-ebs-csi-driver addon and extract the version
ADDON_DETAILS=$(eksctl get addon --name aws-ebs-csi-driver --cluster $MASTER_CLUSTER_NAME -o json)
ADDON_VERSION=$(echo $ADDON_DETAILS | jq -r '.[0].Version')

# Check if the version was successfully retrieved
if [ -z "$ADDON_VERSION" ]; then
    echo "Failed to retrieve addon version."
    exit 1
else
    echo "Addon version retrieved: $ADDON_VERSION"
fi

# Update the aws-ebs-csi-driver addon with the retrieved version
eksctl update addon \
  --name aws-ebs-csi-driver \
  --version $ADDON_VERSION \
  --cluster $MASTER_CLUSTER_NAME \
  --service-account-role-arn arn:aws:iam::975757560751:role/AmazonEKS_EBS_CSI_DriverRole \
  --force

echo "Addon update command executed."