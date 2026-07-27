variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ec2_instance_id" {
  description = "EC2 instance ID to start on schedule"
  type        = string
  # e.g. "i-0abc123def456789"
}

variable "schedule_expression" {
  description = "EventBridge cron or rate expression (UTC)"
  type        = string
  default     = "cron(0 2 * * ? *)"   # 02:00 UTC daily
  # Other examples:
  # "cron(0 6 ? * MON-FRI *)"  → weekdays 06:00 UTC
  # "rate(12 hours)"            → every 12 hours
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds (max 900)"
  type        = number
  default     = 360   # 6 min — enough for EC2 start waiter
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "litellm-pipeline"
    ManagedBy   = "terraform"
  }
}
