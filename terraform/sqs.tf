# SQS Queue - Orders to Process
resource "aws_sqs_queue" "orders" {
  name                       = "${var.project_name}-orders-queue"
  delay_seconds              = 0
  max_message_size           = 262144 # 256 KB
  message_retention_seconds  = 345600 # 4 days
  receive_wait_time_seconds  = 10     # Long polling
  visibility_timeout_seconds = 300    # 5 minutes

  tags = {
    Name = "${var.project_name}-orders-queue"
  }
}

# SQS Queue - Long Tasks
resource "aws_sqs_queue" "long_tasks" {
  name                       = "${var.project_name}-long-tasks-queue"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 10
  visibility_timeout_seconds = 900 # 15 minutes (long tasks)

  tags = {
    Name = "${var.project_name}-long-tasks-queue"
  }
}