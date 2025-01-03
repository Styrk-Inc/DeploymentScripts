#!/bin/bash

# Set Variables for Master
PORTAL_STACK_NAME="Portal-ec2-stack"
PORTAL_TEMPLATE_BODY="file://portal_cf.yaml"
PORTAL_REGION="us-east-1"
SSHKeyname="portal"
InstanceType="t2.xlarge"