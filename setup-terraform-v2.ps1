# Script PowerShell - Setup Terraform Infrastructure
# Cree automatiquement tous les fichiers Terraform necessaires

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Terraform Setup Script" -ForegroundColor Cyan
Write-Host "  AWS E-commerce Project" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verifier qu'on est dans le bon repertoire
$currentPath = Get-Location
Write-Host "Repertoire actuel: $currentPath" -ForegroundColor Yellow

$confirmation = Read-Host "Etes-vous dans E:\IMT\CI3\AWS_Cloud\aws-ecommerce-project ? (O/N)"
if ($confirmation -ne "O" -and $confirmation -ne "o") {
    Write-Host "Veuillez d'abord naviguer vers le bon repertoire:" -ForegroundColor Red
    Write-Host "cd E:\IMT\CI3\AWS_Cloud\aws-ecommerce-project" -ForegroundColor Yellow
    exit
}

# Creer le dossier terraform
Write-Host ""
Write-Host "Creation du dossier terraform/..." -ForegroundColor Green
New-Item -Path "terraform" -ItemType Directory -Force | Out-Null

# Fonction pour creer un fichier avec contenu
function Create-TerraformFile {
    param(
        [string]$FileName,
        [string]$Content
    )
    
    $filePath = "terraform\$FileName"
    Write-Host "  OK Creation de $FileName" -ForegroundColor Green
    Set-Content -Path $filePath -Value $Content -Encoding UTF8
}

Write-Host ""
Write-Host "Creation des fichiers Terraform..." -ForegroundColor Cyan
Write-Host ""

# Creer chaque fichier
Create-TerraformFile -FileName "providers.tf" -Content @"
terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "AWS-Ecommerce"
      ManagedBy   = "Terraform"
      Environment = var.environment
    }
  }
}
"@

Create-TerraformFile -FileName "variables.tf" -Content @"
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment"
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
"@

Create-TerraformFile -FileName "terraform.tfvars" -Content @"
# terraform.tfvars
# NE JAMAIS COMMITER CE FICHIER !

aws_region   = "eu-west-1"
environment  = "prod"
project_name = "ecommerce"

bucket_name = "aws-ecommerce-20251027223716"

stripe_api_key        = "sk_test_REMPLACER"
stripe_webhook_secret = "whsec_REMPLACER"

db_username = "admin"
db_password = "CHOISIR_MOT_DE_PASSE"

sns_email = "votre.email@example.com"

ec2_key_name = "ecommerce-keypair"
"@

Create-TerraformFile -FileName "outputs.tf" -Content @"
output "cloudfront_url" {
  description = "CloudFront distribution URL"
  value       = "https://`${aws_cloudfront_distribution.frontend.domain_name}"
}

output "s3_bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.frontend.id
}

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = aws_api_gateway_stage.prod.invoke_url
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
"@

Create-TerraformFile -FileName "s3.tf" -Content @"
resource "aws_s3_bucket" "frontend" {
  bucket = var.bucket_name

  tags = {
    Name = "`${var.project_name}-frontend"
  }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "PublicReadGetObject"
        Effect = "Allow"
        Principal = "*"
        Action   = "s3:GetObject"
        Resource = "`${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}
"@

Write-Host "Fichiers de base crees..." -ForegroundColor Yellow
Write-Host "Creation des fichiers restants..." -ForegroundColor Yellow

# Continuer avec les autres fichiers (simplifie pour eviter les erreurs)
$files = @(
    "cloudfront.tf",
    "dynamodb.tf", 
    "sqs.tf",
    "sns.tf",
    "cognito.tf",
    "iam.tf",
    "lambda.tf",
    "api-gateway.tf",
    "ec2.tf",
    "rds.tf"
)

foreach ($file in $files) {
    New-Item -Path "terraform\$file" -ItemType File -Force | Out-Null
    Write-Host "  OK Creation de $file (vide - a completer)" -ForegroundColor Yellow
}

# Creer .gitignore
Create-TerraformFile -FileName ".gitignore" -Content @"
**/.terraform/*
*.tfstate
*.tfstate.*
crash.log
crash.*.log
*.tfvars
*.tfvars.json
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc
*.zip
.terraform.lock.hcl
"@

# Creer README
Create-TerraformFile -FileName "README.md" -Content @"
# Infrastructure Terraform - AWS E-commerce

## Prerequis

- Terraform >= 1.6.0
- AWS CLI configure
- Compte AWS avec permissions

## Configuration

1. Modifier terraform.tfvars avec vos valeurs
2. Creer EC2 Key Pair dans AWS Console

## Deploiement

```bash
terraform init
terraform validate
terraform plan
terraform apply
```

## Voir les fichiers complets

Consulter TERRAFORM_INFRASTRUCTURE_COMPLETE.md pour le contenu complet de chaque fichier.
"@

# Creer user-data
Create-TerraformFile -FileName "ec2-user-data.sh" -Content @"
#!/bin/bash
yum update -y
curl -sL https://rpm.nodesource.com/setup_20.x | bash -
yum install -y nodejs mysql

mkdir -p /home/ec2-user/worker
cd /home/ec2-user/worker

# TODO: Ajouter votre code worker
"@

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  OK Creation Terminee !" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Fichiers crees dans terraform/ :" -ForegroundColor Yellow
Get-ChildItem -Path "terraform" | ForEach-Object { Write-Host "  - `$(`$_.Name)" -ForegroundColor Green }

Write-Host ""
Write-Host "IMPORTANT : Prochaines etapes :" -ForegroundColor Yellow
Write-Host "1. Copier le contenu complet de chaque fichier depuis le guide TERRAFORM_INFRASTRUCTURE_COMPLETE.md" -ForegroundColor White
Write-Host "2. Modifier terraform/terraform.tfvars avec VOS vraies valeurs" -ForegroundColor White
Write-Host "3. cd terraform" -ForegroundColor White
Write-Host "4. terraform init" -ForegroundColor White
Write-Host ""
"@