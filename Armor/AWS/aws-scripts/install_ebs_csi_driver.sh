#!/bin/bash

helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver/
helm repo update

#sleep 30

helm install aws-ebs-csi-driver aws-ebs-csi-driver/aws-ebs-csi-driver \
--namespace kube-system \
# --set enableVolumeScheduling=true \
# --set enableVolumeResizing=true \
# --set enableVolumeSnapshot=true

sleep 30
#erwe