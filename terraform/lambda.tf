# Archive des Lambdas (chemins adaptés à VOTRE structure)
data "archive_file" "lambda_checkout" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda-checkout"      # ← Adapté
  output_path = "${path.module}/lambda_checkout.zip"
}

data "archive_file" "lambda_webhook" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda-webhook-handler"  # ← Adapté
  output_path = "${path.module}/lambda_webhook.zip"
}

data "archive_file" "lambda_worker" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda-worker"        # ← Adapté
  output_path = "${path.module}/lambda_worker.zip"
}

# Lambda Checkout
resource "aws_lambda_function" "checkout" {
  filename         = data.archive_file.lambda_checkout.output_path
  function_name    = "${var.project_name}-checkout"
  role            = aws_iam_role.lambda_checkout.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_checkout.output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = 30

  environment {
    variables = {
      STRIPE_SECRET_KEY = var.stripe_api_key
    }
  }

  tags = {
    Name = "${var.project_name}-lambda-checkout"
  }
}

# Lambda Webhook
resource "aws_lambda_function" "webhook" {
  filename         = data.archive_file.lambda_webhook.output_path
  function_name    = "${var.project_name}-webhook"
  role            = aws_iam_role.lambda_webhook.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_webhook.output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = 30

  environment {
    variables = {
      STRIPE_WEBHOOK_SECRET = var.stripe_webhook_secret
      SQS_QUEUE_URL        = aws_sqs_queue.orders.url
    }
  }

  tags = {
    Name = "${var.project_name}-lambda-webhook"
  }
}

# Lambda Worker
resource "aws_lambda_function" "worker" {
  filename         = data.archive_file.lambda_worker.output_path
  function_name    = "${var.project_name}-worker"
  role            = aws_iam_role.lambda_worker.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_worker.output_base64sha256
  runtime         = "nodejs20.x"
  timeout         = 300 # 5 minutes
  reserved_concurrent_executions = 5

  environment {
    variables = {
      DYNAMODB_TABLE     = aws_dynamodb_table.orders.name
      SQS_LONG_TASKS_URL = aws_sqs_queue.long_tasks.url
    }
  }

  tags = {
    Name = "${var.project_name}-lambda-worker"
  }
}

# Event Source Mapping - SQS Orders → Lambda Worker
resource "aws_lambda_event_source_mapping" "orders_to_worker" {
  event_source_arn = aws_sqs_queue.orders.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 1
  enabled          = true
}