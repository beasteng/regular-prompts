# How the Switch from MinIO to S3 Works

| What to do | MinIO (default) | Real AWS S3 |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | MinIO root user | IAM key |
| `AWS_SECRET_ACCESS_KEY` | MinIO root password | IAM secret |
| `S3_ENDPOINT` | `http://minio:9000` | *(leave blank or delete)* |
| `minio` service | enabled | comment out |
| Workflow / credential name | unchanged | unchanged |

The workflow and the n8n credential name **never need to change** — only `.env` and optionally commenting out the `minio` service block.
