"""
Lambda: Start EC2 instance by ID.
Triggered by EventBridge scheduler.
"""

import os
import logging
import boto3
from botocore.exceptions import ClientError

log = logging.getLogger()
log.setLevel(logging.INFO)

EC2_INSTANCE_ID = os.environ["EC2_INSTANCE_ID"]
EC2_REGION      = os.environ.get("EC2_REGION", "us-east-1")


def lambda_handler(event, context):
    ec2 = boto3.client("ec2", region_name=EC2_REGION)

    try:
        # Check current state first — avoid error if already running
        resp = ec2.describe_instances(InstanceIds=[EC2_INSTANCE_ID])
        state = (
            resp["Reservations"][0]["Instances"][0]
            ["State"]["Name"]
        )
        log.info(f"Instance {EC2_INSTANCE_ID} current state: {state}")

        if state in ("running", "pending"):
            log.info("Instance already running. Nothing to do.")
            return {"status": "already_running", "instance_id": EC2_INSTANCE_ID}

        if state == "stopping":
            log.warning("Instance is still stopping. Cannot start yet.")
            return {"status": "stopping", "instance_id": EC2_INSTANCE_ID}

        # Start it
        ec2.start_instances(InstanceIds=[EC2_INSTANCE_ID])
        log.info(f"Start command issued for {EC2_INSTANCE_ID}.")

        # Wait until running (up to ~5 min)
        waiter = ec2.get_waiter("instance_running")
        waiter.wait(
            InstanceIds=[EC2_INSTANCE_ID],
            WaiterConfig={"Delay": 10, "MaxAttempts": 30},
        )

        # Fetch public IP after start
        resp = ec2.describe_instances(InstanceIds=[EC2_INSTANCE_ID])
        instance = resp["Reservations"][0]["Instances"][0]
        public_ip = instance.get("PublicIpAddress", "N/A")
        log.info(f"Instance running. Public IP: {public_ip}")

        return {
            "status":      "started",
            "instance_id": EC2_INSTANCE_ID,
            "public_ip":   public_ip,
        }

    except ClientError as e:
        log.error(f"AWS error: {e}")
        raise
    except Exception as e:
        log.error(f"Unexpected error: {e}", exc_info=True)
        raise
