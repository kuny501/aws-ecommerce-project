# Infrastructure Terraform - AWS E-commerce

## Prérequis

- [Terraform](https://www.terraform.io/downloads) >= 1.6.0
- [AWS CLI](https://aws.amazon.com/cli/) configuré
- Compte AWS avec permissions appropriées

## Configuration

1. Créer `terraform.tfvars` avec vos valeurs :
```hcl
   bucket_name = "votre-bucket-unique"
   stripe_api_key = "sk_test_..."
   # etc.
```

2. Créer EC2 Key Pair dans AWS Console (si pas déjà fait)

## Déploiement
```bash
# Initialiser
terraform init

# Valider
terraform validate

# Prévisualiser
terraform plan

# Déployer
terraform apply
```

## Outputs

Après `apply`, récupérer les URLs et IDs :
```bash
terraform output
```

## Destruction

⚠️ **ATTENTION : Supprime toute l'infrastructure !**
```bash
terraform destroy
```

## Structure

- `providers.tf` - Configuration AWS
- `variables.tf` - Variables paramétrables
- `s3.tf` - Bucket frontend
- `cloudfront.tf` - CDN
- `api-gateway.tf` - API REST
- `lambda.tf` - 3 fonctions Lambda
- `sqs.tf` - 2 queues
- `dynamodb.tf` - Table orders
- `ec2.tf` - Worker instance
- `rds.tf` - MySQL database
- `sns.tf` - Notifications
- `cognito.tf` - User pool
- `iam.tf` - Roles et policies
- `outputs.tf` - Exports

## Coûts

- Free Tier : 0€ (12 mois)
- Après Free Tier : ~32-37€/mois
```