"""
Lambda: Stop EC2 instance by ID.
Safety net — triggered 30 min after start Lambda.
Stops the instance regardless of what is running on it.
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
        resp = ec2.describe_instances(InstanceIds=[EC2_INSTANCE_ID])
        state = (
            resp["Reservations"][0]["Instances"][0]
            ["State"]["Name"]
        )
        log.info(f"Instance {EC2_INSTANCE_ID} current state: {state}")

        if state in ("stopped", "stopping"):
            log.info("Instance already stopped/stopping. Nothing to do.")
            return {"status": "already_stopped", "instance_id": EC2_INSTANCE_ID}

        if state == "pending":
            log.warning("Instance is still pending — stopping anyway.")

        ec2.stop_instances(InstanceIds=[EC2_INSTANCE_ID])
        log.info(f"Stop command issued for {EC2_INSTANCE_ID}.")

        return {
            "status":      "stop_issued",
            "instance_id": EC2_INSTANCE_ID,
            "prior_state": state,
        }

    except ClientError as e:
        log.error(f"AWS error: {e}")
        raise
    except Exception as e:
        log.error(f"Unexpected error: {e}", exc_info=True)
        raise
