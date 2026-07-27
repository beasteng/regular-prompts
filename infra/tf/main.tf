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

# ── Package Lambda code ───────────────────────────────────────────
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/start_ec2.py"
  output_path = "${path.module}/lambda/start_ec2.zip"
}

# ── Lambda function ───────────────────────────────────────────────
resource "aws_lambda_function" "start_ec2" {
  function_name    = "start-ec2-pipeline"
  role             = aws_iam_role.start_ec2_lambda.arn
  handler          = "start_ec2.lambda_handler"
  runtime          = "python3.12"
  timeout          = var.lambda_timeout
  memory_size      = 128            # minimal — no heavy libs needed

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      EC2_INSTANCE_ID = var.ec2_instance_id
      EC2_REGION      = var.aws_region
    }
  }

  tags = var.tags
}

# ── CloudWatch Log Group ──────────────────────────────────────────
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.start_ec2.function_name}"
  retention_in_days = 14
  tags              = var.tags
}

# ── EventBridge Scheduler ─────────────────────────────────────────
resource "aws_cloudwatch_event_rule" "trigger" {
  name                = "start-ec2-pipeline-schedule"
  description         = "Daily trigger to start EC2 pipeline instance"
  schedule_expression = var.schedule_expression
  state               = "ENABLED"
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.trigger.name
  target_id = "StartEC2Lambda"
  arn       = aws_lambda_function.start_ec2.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_ec2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trigger.arn
}
