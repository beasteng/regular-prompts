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

#Start lambda
aws lambda invoke \
  --function-name start-ec2-pipeline \
  --log-type Tail \
  --query 'LogResult' \
  --output text \
  /tmp/response.start.json | base64 --decode

cat /tmp/response.start.json

#Stop lmbca
aws lambda invoke \
  --function-name stop-ec2-pipeline \
  --log-type Tail \
  --query 'LogResult' \
  --output text \
  /tmp/response.stop.json | base64 --decode

cat /tmp/response.stop.json
