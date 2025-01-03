#!/bin/bash

#Environments for Source pod
AWS_BUCKET="vardaan-2023"
AWS_REGION="us-east-1"
AWS_S3_PATH="s3://${AWS_BUCKET}/Mongodb-backups/"
Source_Mongodb_pod="aitrism-mongodb-0"
Destination_Mongodb_pod="xyz"
Cluster_name="abc"
Cluster_Alias="master"

# Run the kubectl exec command to enter the pod and start a shell
kubectl exec -it $Source_Mongodb_pod -- /bin/bash -c \
  'echo "Creating dump of MongoDB" && \
   mongodump mongodb://admin:admin@aitrism-mongodb/aitrism-db --out /tmp/mongodb.dump && \
   exit'

# Copy the dump from pod to host machine
echo "Copying from Pod to host path $(pwd)"
kubectl cp $Source_Mongodb_pod:/tmp/mongodb.dump ./mongodb.dump
#kubectl cp aitrism-mongodb-0:/tmp/mongodb.dump/aitrism-db ./aitrism-db

cp -r mongodb.dump/aitrism-db/ .
aws s3 cp mongodb.dump $AWS_S3_PATH --region $AWS_REGION --recursive
echo "Copy to S3 Completed"

##########################################################################################################################################################
#**********************************************Importing the MongoDB**************************************************************************************

#Here we have to switch context if the mongo-db is in different cluster.
aws eks update-kubeconfig --name $Cluster_name --region us-east-1 --alias $Cluster_Alias
kubectl config use-context $Cluster_Alias

# Restore the backup into a new pod
#Replace the URL and database-name to restore.
kubectl cp ./aitrism-db $Destination_Mongodb_pod:/tmp/aitrism-db
echo "Copy to Mongo pod successfully completed"

kubectl exec -it $Destination_Mongodb_pod -- /bin/bash -c \
 'echo "Restoring the mongo_data" && \
  mongorestore mongodb://admin:admin@a4433a8a39c9748b3a85ba23826034cb-a120e2dd63ae787f.elb.us-east-1.amazonaws.com/aitrism-db /tmp/aitrism-db && \
  exit'


echo "All Task Completed"

