output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.start_ec2.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.start_ec2.arn
}

output "eventbridge_rule_name" {
  description = "EventBridge rule name"
  value       = aws_cloudwatch_event_rule.trigger.name
}

output "log_group" {
  description = "CloudWatch log group for Lambda"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}
