variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ecommerce"
}

variable "bucket_name" {
  description = "S3 bucket name for frontend"
  type        = string
  # Doit être globalement unique
  default     = "aws-ecommerce-frontend-terraform"
}

variable "stripe_api_key" {
  description = "Stripe API Key"
  type        = string
  sensitive   = true
}

variable "stripe_webhook_secret" {
  description = "Stripe Webhook Secret"
  type        = string
  sensitive   = true
}

variable "db_username" {
  description = "RDS MySQL username"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "RDS MySQL password"
  type        = string
  sensitive   = true
}

variable "sns_email" {
  description = "Email for SNS notifications"
  type        = string
}

variable "ec2_key_name" {
  description = "EC2 SSH key pair name"
  type        = string
}