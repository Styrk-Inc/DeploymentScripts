#!/bin/bash

# ===============================
# Environment to be Updated by USER
# ===============================

# Portal Configuration
PORTAL_STACK_NAME="Portal-ec2-stack"
PORTAL_REGION="us-east-1"
SSHKeyname="portal"
InstanceType="t2.xlarge"

# ===============================
# Leave These Fields Unchanged (Do Not Edit)
# ===============================

PORTAL_TEMPLATE_BODY="file://portal_cf.yaml"