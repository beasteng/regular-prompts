output "start_lambda_name" {
  value = aws_lambda_function.start_ec2.function_name
}

output "stop_lambda_name" {
  value = aws_lambda_function.stop_ec2.function_name
}

output "start_schedule" {
  value = var.start_schedule
}

output "stop_schedule" {
  description = "Auto-derived stop schedule (start + 30 min)"
  value       = local.stop_schedule
}

output "log_group_start" {
  value = aws_cloudwatch_log_group.start_lambda_logs.name
}

output "log_group_stop" {
  value = aws_cloudwatch_log_group.stop_lambda_logs.name
}
