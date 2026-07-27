#!/usr/bin/env bash

# REQUIRES /infra/terraform.tfvars

cd infra/tf

# Init
terraform init

# Preview
terraform plan

# Apply
terraform apply

# Test Lambda manually (bypasses schedule)
aws lambda invoke \
  --function-name start-ec2-pipeline \
  --log-type Tail \
  --query 'LogResult' \
  --output text \
  /tmp/response.json | base64 --decode

cat /tmp/response.json
