#!/bin/bash

# Run the kubectl exec command to enter the pod and start a shell
kubectl exec -it aitrism-mongodb-0 -- /bin/bash -c \
  'echo "Creating dump of MongoDB" && \
   mongodump mongodb://admin:admin@aitrism-mongodb/aitrism-db --out /tmp/mongodb.dump && \
   exit'

# Copy the dump from pod to host machine
echo "Copying from Pod to host path $(pwd)"
kubectl cp aitrism-mongodb-0:/tmp/mongodb.dump ./mongodb.dump
cp mongo.dump/aitrism-db ..


#Here we have to switch context if the mongo-db is in different cluster.
#aws eks update-kubeconfig --name <Cluster-name> --region us-east-1 --alias <name-for-context>


# Restore the backup into a new pod
#Replace the URL and database-name to restore.
kubectl cp ./aitrism-db detect-mongodb-0:/tmp/aitrism-db
echo "Copy to Mongo pod successfully completed"
kubectl exec -it detect-mongodb-0 -- /bin/bash -c \
 'echo "Restoring the mongo_data" && \
  mongorestore mongodb://admin:admin@a4cc4f2b546dc4f53a18add38b887b44-a2024dd6f7bccf21.elb.us-east-1.amazonaws.com/sensitive_information /tmp/aitrism-db && \
  exit'


echo "All Task Completed"
