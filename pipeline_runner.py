#!/usr/bin/env python3
"""
Runs inside docker-compose as a sidecar.
Triggered automatically when all services are healthy.
"""

import os, time, logging, datetime, socket
import boto3, requests

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)
log = logging.getLogger(__name__)

# ── Config from environment ───────────────────────────────────────
N8N_BASE_URL    = os.environ.get("N8N_BASE_URL", "http://n8n:5678")
N8N_API_KEY     = os.environ["N8N_API_KEY"]
N8N_WORKFLOW_ID = os.environ["N8N_WORKFLOW_ID"]

S3_BUCKET       = os.environ["S3_BUCKET"]
S3_KEY_PREFIX   = os.environ.get("S3_KEY_PREFIX", "pipeline-logs")
AWS_REGION      = os.environ.get("AWS_DEFAULT_REGION", "us-east-1")

POLL_INTERVAL   = int(os.environ.get("POLL_INTERVAL", "15"))
WORKFLOW_TIMEOUT= int(os.environ.get("WORKFLOW_TIMEOUT", "600"))  # 10 min


# ── Helpers ───────────────────────────────────────────────────────

def wait_for_n8n(timeout: int = 120):
    url = f"{N8N_BASE_URL}/healthz"
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            r = requests.get(url, timeout=5)
            if r.status_code < 500:
                log.info("n8n is ready.")
                return
        except requests.RequestException:
            pass
        log.info("Waiting for n8n...")
        time.sleep(5)
    raise TimeoutError("n8n not ready")


def trigger_workflow() -> str:
    url = f"{N8N_BASE_URL}/api/v1/workflows/{N8N_WORKFLOW_ID}/run"
    headers = {"X-N8N-API-KEY": N8N_API_KEY, "Content-Type": "application/json"}
    resp = requests.post(url, headers=headers, json={}, timeout=30)
    resp.raise_for_status()
    data = resp.json()
    exec_id = (
        data.get("data", {}).get("executionId") or
        data.get("executionId")
    )
    log.info(f"Workflow triggered. Execution ID: {exec_id}")
    return str(exec_id)


def poll_execution(exec_id: str) -> str:
    """Returns final status string."""
    url = f"{N8N_BASE_URL}/api/v1/executions/{exec_id}"
    headers = {"X-N8N-API-KEY": N8N_API_KEY}
    deadline = time.time() + WORKFLOW_TIMEOUT

    while time.time() < deadline:
        resp = requests.get(url, headers=headers, timeout=15)
        resp.raise_for_status()
        body = resp.json()
        status = (
            body.get("data", {}).get("status") or
            body.get("status")
        )
        log.info(f"Execution {exec_id}: {status}")
        if status in ("success", "error", "crashed", "canceled"):
            return status
        time.sleep(POLL_INTERVAL)

    raise TimeoutError(f"Workflow did not finish in {WORKFLOW_TIMEOUT}s")


def upload_logs_to_s3(content: str, ts: str):
    key = f"{S3_KEY_PREFIX}/{ts}/pipeline.log"
    s3 = boto3.client("s3", region_name=AWS_REGION)
    s3.put_object(
        Bucket=S3_BUCKET,
        Key=key,
        Body=content.encode("utf-8"),
        ContentType="text/plain",
    )
    log.info(f"Logs uploaded → s3://{S3_BUCKET}/{key}")


def self_stop_ec2():
    """
    Stop the EC2 instance this container is running on.
    Works via EC2 instance metadata + IAM instance profile.
    """
    try:
        # Get own instance ID from metadata service
        resp = requests.get(
            "http://169.254.169.254/latest/meta-data/instance-id",
            timeout=3
        )
        instance_id = resp.text.strip()
        log.info(f"Stopping EC2 instance: {instance_id}")
        ec2 = boto3.client("ec2", region_name=AWS_REGION)
        ec2.stop_instances(InstanceIds=[instance_id])
        log.info("Stop command issued. Goodbye.")
    except Exception as e:
        log.error(f"Failed to stop EC2: {e}")
        # Don't raise — logs are already uploaded


# ── Main ──────────────────────────────────────────────────────────

def main():
    ts = datetime.datetime.utcnow().strftime("%Y-%m-%d_%H-%M-%S")
    log_lines = []

    def record(msg: str):
        log.info(msg)
        log_lines.append(f"{datetime.datetime.utcnow().isoformat()} {msg}")

    try:
        record("=== Pipeline runner started ===")

        wait_for_n8n()
        record("n8n healthy")

        exec_id = trigger_workflow()
        record(f"Workflow triggered: {exec_id}")

        status = poll_execution(exec_id)
        record(f"Workflow finished with status: {status}")

        if status != "success":
            record(f"WARNING: workflow did not succeed (status={status})")

    except Exception as e:
        record(f"FATAL ERROR: {e}")
        import traceback
        log_lines.append(traceback.format_exc())

    finally:
        # Always upload logs, always stop EC2
        try:
            upload_logs_to_s3("\n".join(log_lines), ts)
        except Exception as e:
            log.error(f"Log upload failed: {e}")

        self_stop_ec2()


if __name__ == "__main__":
    main()
