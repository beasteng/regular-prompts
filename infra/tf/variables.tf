variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "ec2_instance_id" {
  description = "EC2 instance ID to start/stop on schedule"
  type        = string
}

variable "start_schedule" {
  description = "EventBridge cron for START (UTC). Stop fires 30 min later."
  type        = string
  default     = "cron(0 2 * * ? *)"   # 02:00 UTC daily
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 360
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default = {
    Project   = "litellm-pipeline"
    ManagedBy = "terraform"
  }
}
