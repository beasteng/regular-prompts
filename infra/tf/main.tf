terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── Derive stop schedule: exactly 30 min after start ─────────────
locals {
  # Parse "cron(M H ...rest)" and shift minute by +30, rolling hour if needed
  cron_inner = regex("cron\\((.+)\\)", var.start_schedule)[0]
  cron_parts = split(" ", local.cron_inner)

  start_minute = tonumber(local.cron_parts[0])
  start_hour   = tonumber(local.cron_parts[1])
  cron_rest    = join(" ", slice(local.cron_parts, 2, length(local.cron_parts)))

  stop_minute  = (local.start_minute + 30) % 60
  stop_hour    = (local.start_minute + 30) >= 60 ? (local.start_hour + 1) % 24 : local.start_hour

  stop_schedule = "cron(${local.stop_minute} ${local.stop_hour} ${local.cron_rest})"
}

# ── Package Lambda: start ─────────────────────────────────────────
data "archive_file" "start_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/start_ec2.py"
  output_path = "${path.module}/lambda/start_ec2.zip"
}

# ── Package Lambda: stop ──────────────────────────────────────────
data "archive_file" "stop_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/stop_ec2.py"
  output_path = "${path.module}/lambda/stop_ec2.zip"
}

# ── Lambda: start EC2 ─────────────────────────────────────────────
resource "aws_lambda_function" "start_ec2" {
  function_name    = "start-ec2-pipeline"
  role             = aws_iam_role.ec2_lambda.arn
  handler          = "start_ec2.lambda_handler"
  runtime          = "python3.12"
  timeout          = var.lambda_timeout
  memory_size      = 128

  filename         = data.archive_file.start_lambda_zip.output_path
  source_code_hash = data.archive_file.start_lambda_zip.output_base64sha256

  environment {
    variables = {
      EC2_INSTANCE_ID = var.ec2_instance_id
      EC2_REGION      = var.aws_region
    }
  }

  tags = var.tags
}

# ── Lambda: stop EC2 ──────────────────────────────────────────────
resource "aws_lambda_function" "stop_ec2" {
  function_name    = "stop-ec2-pipeline"
  role             = aws_iam_role.ec2_lambda.arn   # same role — needs stop too
  handler          = "stop_ec2.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60           # stop is fast, no waiter needed
  memory_size      = 128

  filename         = data.archive_file.stop_lambda_zip.output_path
  source_code_hash = data.archive_file.stop_lambda_zip.output_base64sha256

  environment {
    variables = {
      EC2_INSTANCE_ID = var.ec2_instance_id
      EC2_REGION      = var.aws_region
    }
  }

  tags = var.tags
}

# ── CloudWatch Log Groups ─────────────────────────────────────────
resource "aws_cloudwatch_log_group" "start_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.start_ec2.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

resource "aws_cloudwatch_log_group" "stop_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.stop_ec2.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

# ── EventBridge: START rule ───────────────────────────────────────
resource "aws_cloudwatch_event_rule" "start_trigger" {
  name                = "start-ec2-pipeline-schedule"
  description         = "Start EC2 pipeline instance on schedule"
  schedule_expression = var.start_schedule
  state               = "ENABLED"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "start_lambda_target" {
  rule      = aws_cloudwatch_event_rule.start_trigger.name
  target_id = "StartEC2Lambda"
  arn       = aws_lambda_function.start_ec2.arn
}

resource "aws_lambda_permission" "allow_eventbridge_start" {
  statement_id  = "AllowEventBridgeInvokeStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_ec2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_trigger.arn
}

# ── EventBridge: STOP rule (start + 30 min) ───────────────────────
resource "aws_cloudwatch_event_rule" "stop_trigger" {
  name                = "stop-ec2-pipeline-schedule"
  description         = "Safety net: stop EC2 pipeline instance 30 min after start"
  schedule_expression = local.stop_schedule
  state               = "ENABLED"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "stop_lambda_target" {
  rule      = aws_cloudwatch_event_rule.stop_trigger.name
  target_id = "StopEC2Lambda"
  arn       = aws_lambda_function.stop_ec2.arn
}

resource "aws_lambda_permission" "allow_eventbridge_stop" {
  statement_id  = "AllowEventBridgeInvokeStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_ec2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_trigger.arn
}
