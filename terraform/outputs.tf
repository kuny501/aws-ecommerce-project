output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.frontend.id
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = "${aws_api_gateway_stage.prod.invoke_url}"
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.web.id
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.orders.name
}

output "sqs_orders_queue_url" {
  description = "SQS Orders Queue URL"
  value       = aws_sqs_queue.orders.url
}

output "sqs_long_tasks_queue_url" {
  description = "SQS Long Tasks Queue URL"
  value       = aws_sqs_queue.long_tasks.url
}

output "ec2_public_ip" {
  description = "EC2 Worker Public IP"
  value       = aws_instance.worker.public_ip
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "sns_topic_arn" {
  description = "SNS Topic ARN"
  value       = aws_sns_topic.notifications.arn
}