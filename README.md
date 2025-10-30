# 🛒 AWS E-Commerce Platform - Projet Cloud Architecture

> Plateforme e-commerce serverless complète déployée sur AWS avec Terraform

## 📋 Table des matières

- [Vue d'ensemble](#-vue-densemble)
- [Architecture](#-architecture)
- [Prérequis](#-prérequis)
- [Installation rapide](#-installation-rapide)
- [Configuration détaillée](#-configuration-détaillée)
- [Déploiement](#-déploiement)
- [Tests](#-tests)
- [Nettoyage](#-nettoyage)
- [Troubleshooting](#-troubleshooting)

---

## 🎯 Vue d'ensemble

Cette plateforme e-commerce démontre une architecture cloud moderne utilisant les services AWS managés :

- **Frontend** : Application Next.js hébergée sur S3 + CloudFront
- **Backend** : Architecture serverless avec Lambda, API Gateway, SQS
- **Base de données** : DynamoDB (NoSQL) + RDS MySQL (Analytics)
- **Authentification** : AWS Cognito
- **Paiements** : Intégration Stripe
- **Workers** : EC2 pour les tâches longues (packaging, shipping)
- **Notifications** : SNS pour emails automatiques
- **Infrastructure as Code** : Terraform

### 🌟 Fonctionnalités

✅ Authentification utilisateur sécurisée (Cognito)
✅ Paiement en ligne via Stripe
✅ Gestion des commandes asynchrone (SQS + Lambda)
✅ Traitement long des commandes (EC2 Worker)
✅ Notifications par email (SNS)
✅ Analytics avec RDS MySQL
✅ Infrastructure sécurisée (VPC, Security Groups)
✅ CDN global avec CloudFront

---

## 🏗️ Architecture

### Diagramme d'architecture

```
┌─────────────┐
│   Client    │
│  (Browser)  │
└──────┬──────┘
       │
       ├────────────────────────────────────────────────┐
       │                                                │
       ▼                                                ▼
┌─────────────┐                              ┌──────────────────┐
│ CloudFront  │◄─────────────────────────────│  S3 Frontend     │
│    (CDN)    │                              │   (Next.js)      │
└──────┬──────┘                              └──────────────────┘
       │                                               ▲
       │                                               │
       ▼                                               │
┌───────────────────────────────────────────┐         │
│           API Gateway                      │         │
└──────┬────────────────────────┬───────────┘         │
       │                        │                     │
       │ /checkout (POST)       │ /webhook (POST)    │
       ▼                        ▼                     │
┌─────────────┐          ┌──────────────────┐        │
│   Lambda    │          │     Lambda       │        │
│  Checkout   │          │  Webhook Handler │        │
│             │          │                  │        │
│  Crée la    │          │ Valide signature │        │
│  session    │          │ Stripe webhook   │        │
│  Stripe     │          └────────┬─────────┘        │
└──────┬──────┘                   │                  │
       │                          │                  │
       │ Renvoie URL              │                  │
       │ session Stripe           │                  │
       ▼                          │                  │
    Client ──────────────────────────────────────────┘
       │                          │
       │ Paiement sur             │
       │ Stripe Checkout          │
       │                          │
       └─► Stripe ────────────────┘
           (Webhook sur succès)
                   │
                   ▼
          ┌────────────────────────┐
          │   SQS Orders Queue     │
          └────────┬───────────────┘
                   │
                   ▼
            ┌─────────────┐
            │   Lambda    │
            │   Worker    │
            └──────┬──────┘
                   │
       ┌───────────┼───────────────┐
       │           │               │
       ▼           ▼               ▼
  ┌─────────┐ ┌──────────┐  ┌───────────────┐
  │DynamoDB │ │   SQS    │  │   Cognito     │
  │ Orders  │ │Long Tasks│  │ User Pool     │
  └─────────┘ └────┬─────┘  └───────────────┘
                   │
                   ▼
            ┌─────────────┐
            │ EC2 Worker  │
            │  (Node.js)  │
            └──────┬──────┘
                   │
       ┌───────────┼────────────┐
       │           │            │
       ▼           ▼            ▼
  ┌─────────┐ ┌────────┐  ┌────────┐
  │DynamoDB │ │  RDS   │  │  SNS   │
  │         │ │ MySQL  │  │ Topics │
  └─────────┘ └────────┘  └────────┘
```

### Flux de paiement détaillé

```
1. Client clique "Acheter"
         ↓
2. Frontend → API Gateway → Lambda Checkout
         ↓
3. Lambda Checkout crée session Stripe
         ↓
4. Lambda renvoie l'URL de session Stripe
         ↓
5. Frontend redirige vers Stripe Checkout
         ↓
6. Client paie sur Stripe (carte 4242...)
         ↓
7. Stripe webhook → API Gateway → Lambda Webhook
         ↓
8. Lambda Webhook envoie commande → SQS Orders Queue
         ↓
9. Lambda Worker traite → DynamoDB + SQS Long Tasks
         ↓
10. EC2 Worker traite (30s packaging + 1min shipping)
         ↓
11. EC2 Worker → DynamoDB + RDS + SNS (email client)
```

### Réseau VPC

```
VPC (10.0.0.0/16)
│
├── Public Subnets (Internet Gateway)
│   ├── 10.0.1.0/24 (eu-west-1a) → EC2 Worker
│   └── 10.0.2.0/24 (eu-west-1b) → NAT Gateway
│
└── Private Subnets (NAT Gateway)
    ├── 10.0.11.0/24 (eu-west-1a) → RDS MySQL
    └── 10.0.12.0/24 (eu-west-1b) → RDS MySQL (Multi-AZ)
```

---

## 📦 Prérequis

### Outils requis

1. **AWS CLI** (v2.x)
   ```bash
   # Installation
   # macOS
   brew install awscli

   # Linux
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Windows
   # Télécharger depuis https://aws.amazon.com/cli/
   ```

2. **Terraform** (v1.6+)
   ```bash
   # macOS
   brew install terraform

   # Linux
   wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
   unzip terraform_1.6.0_linux_amd64.zip
   sudo mv terraform /usr/local/bin/

   # Windows
   # Télécharger depuis https://www.terraform.io/downloads
   ```

3. **Node.js** (v20.x)
   ```bash
   # macOS/Linux
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
   nvm install 20
   nvm use 20

   # Windows
   # Télécharger depuis https://nodejs.org/
   ```

4. **Git**
   ```bash
   # Vérifier l'installation
   git --version
   ```

### Comptes requis

- ✅ **Compte AWS** (Free Tier suffisant pour les tests)
- ✅ **Compte Stripe** (mode test gratuit)
- ✅ **Email valide** (pour les notifications SNS)

---

## 🚀 Installation rapide

### 1️⃣ Cloner le projet

```bash
git clone <URL_DU_REPO>
cd aws-ecommerce-project
```

### 2️⃣ Configurer AWS CLI

```bash
aws configure
# AWS Access Key ID: VOTRE_ACCESS_KEY
# AWS Secret Access Key: VOTRE_SECRET_KEY
# Default region name: eu-west-1
# Default output format: json
```

### 3️⃣ Créer une clé SSH pour EC2

```bash
# Depuis le dossier racine du projet
aws ec2 create-key-pair \
  --key-name ecommerce-worker-key \
  --query 'KeyMaterial' \
  --output text > ecommerce-worker-key.pem

# Sécuriser la clé (Linux/macOS)
chmod 400 ecommerce-worker-key.pem

# Windows (PowerShell)
icacls ecommerce-worker-key.pem /inheritance:r
icacls ecommerce-worker-key.pem /grant:r "%username%:R"
```

### 4️⃣ Configurer les variables Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Éditer `terraform.tfvars` avec vos valeurs :

```hcl
aws_region     = "eu-west-1"
environment    = "prod"
project_name   = "ecommerce"
bucket_name    = "aws-ecommerce-frontend-VOTRE-NOM-UNIQUE"

# Stripe (obtenez vos clés sur https://dashboard.stripe.com/test/apikeys)
stripe_api_key        = "sk_test_VOTRE_CLE_STRIPE"
stripe_webhook_secret = "whsec_VOTRE_SECRET_WEBHOOK"

# Base de données
db_username = "admin"
db_password = "VotreMotDePasseSecurise123!"

# Notifications
sns_email = "votre.email@example.com"

# SSH Key
ec2_key_name = "ecommerce-worker-key"
```

### 5️⃣ Déployer l'infrastructure

```bash
# Initialiser Terraform
terraform init

# Vérifier le plan de déploiement
terraform plan

# Déployer (⚠️ Coût estimé: ~15-20€/mois)
terraform apply
```

⏱️ **Temps de déploiement** : 10-15 minutes

### 6️⃣ Récupérer les outputs

```bash
# Voir tous les outputs
terraform output

# URLs importantes
terraform output cloudfront_url
terraform output api_gateway_url
```

---

## ⚙️ Configuration détaillée

### Structure du projet

```
aws-ecommerce-project/
├── README.md                          # Ce fichier
├── terraform/                         # Infrastructure as Code
│   ├── providers.tf                   # Configuration AWS
│   ├── variables.tf                   # Variables d'entrée
│   ├── terraform.tfvars              # Valeurs des variables (à créer)
│   ├── outputs.tf                     # Outputs du déploiement
│   ├── vpc.tf                         # Configuration réseau VPC
│   ├── ec2.tf                         # Worker EC2
│   ├── rds.tf                         # Base de données MySQL
│   ├── lambda.tf                      # Fonctions Lambda
│   ├── api-gateway.tf                # API REST
│   ├── dynamodb.tf                    # Table DynamoDB
│   ├── sqs.tf                         # Files d'attente SQS
│   ├── sns.tf                         # Topics SNS
│   ├── s3.tf                          # Bucket frontend
│   ├── cloudfront.tf                  # CDN CloudFront
│   ├── cognito.tf                     # Authentification
│   ├── iam.tf                         # Permissions IAM
│   └── ec2-user-data.sh              # Script de démarrage EC2
├── lambda-checkout/                   # Lambda création session Stripe
│   ├── index.js                       # (à implémenter)
│   └── package.json
├── lambda-webhook-handler/            # Lambda webhooks Stripe
│   ├── index.mjs
│   └── package.json
├── lambda-worker/                     # Lambda traitement commandes
│   ├── index.mjs
│   └── package.json
├── ec2-worker/                        # Worker longue durée
│   ├── worker.js
│   └── package.json
└── aws-ecommerce-frontend/           # Application Next.js
    ├── src/
    ├── public/
    └── package.json
```

### Variables d'environnement

Toutes les configurations sont dans `terraform/terraform.tfvars` :

| Variable | Description | Exemple |
|----------|-------------|---------|
| `aws_region` | Région AWS | `eu-west-1` |
| `project_name` | Nom du projet | `ecommerce` |
| `bucket_name` | Nom bucket S3 (unique) | `aws-ecommerce-frontend-john` |
| `stripe_api_key` | Clé API Stripe | `sk_test_...` |
| `stripe_webhook_secret` | Secret webhook Stripe | `whsec_...` |
| `db_username` | Utilisateur MySQL | `admin` |
| `db_password` | Mot de passe MySQL | `SecurePassword123!` |
| `sns_email` | Email notifications | `you@example.com` |
| `ec2_key_name` | Nom clé SSH EC2 | `ecommerce-worker-key` |

---

## 🔧 Déploiement

### Configuration post-déploiement

#### 1. Confirmer l'abonnement SNS

Après le déploiement, vous recevrez 3 emails de confirmation AWS SNS :
- Un pour `ecommerce-order-completed` (notifications clients)
- Un pour `ecommerce-admin-alerts` (alertes admin)
- Un pour `ecommerce-notifications` (legacy)

**Action requise** : Cliquer sur "Confirm subscription" dans chaque email.

#### 2. Configurer le webhook Stripe

```bash
# Récupérer l'URL de l'API Gateway
terraform output api_gateway_url

# URL webhook sera: <API_GATEWAY_URL>/webhook
```

Dans le dashboard Stripe (https://dashboard.stripe.com/test/webhooks) :
1. Cliquer sur "Add endpoint"
2. URL : `https://<API_GATEWAY_URL>/webhook`
3. Événements à écouter : `checkout.session.completed`, `payment_intent.succeeded`
4. Copier le "Signing secret" dans `terraform.tfvars`

#### 3. Déployer le frontend

```bash
cd aws-ecommerce-frontend

# Installer les dépendances
npm install

# Configurer les variables d'environnement
cat > .env.local <<EOF
NEXT_PUBLIC_API_URL=$(cd ../terraform && terraform output -raw api_gateway_url)
NEXT_PUBLIC_COGNITO_USER_POOL_ID=$(cd ../terraform && terraform output -raw cognito_user_pool_id)
NEXT_PUBLIC_COGNITO_CLIENT_ID=$(cd ../terraform && terraform output -raw cognito_client_id)
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_VOTRE_CLE_PUBLIQUE_STRIPE
EOF

# Build de production
npm run build

# Déployer vers S3
aws s3 sync out/ s3://$(cd ../terraform && terraform output -raw s3_bucket_name)/ --delete
```

### Commandes essentielles

```bash
# Voir les outputs après déploiement
terraform output

# Modifier l'infrastructure
terraform plan
terraform apply

# Détruire l'infrastructure
terraform destroy
```

---

## 🧪 Tests

### Tester le flux complet

1. **Ouvrir le frontend**
   ```bash
   # Récupérer l'URL CloudFront
   terraform output cloudfront_url
   ```

2. **S'inscrire avec Cognito**
   - Email : `test@example.com`
   - Mot de passe : `TestPass123!` (min 8 caractères avec majuscule, minuscule, chiffre, symbole)

3. **Simuler un achat**
   - Ajouter des produits au panier
   - Cliquer sur "Checkout"
   - Le frontend appelle Lambda Checkout qui crée la session Stripe
   - Vous êtes redirigé vers Stripe Checkout

4. **Payer avec carte test Stripe**
   - Numéro : `4242 4242 4242 4242`
   - Date : N'importe quelle date future
   - CVV : N'importe quel 3 chiffres
   - Nom : Test User

5. **Vérifier le traitement**
   - Stripe renvoie le succès au frontend
   - Stripe envoie un webhook à Lambda Webhook Handler
   - La commande est créée dans DynamoDB
   - EC2 Worker traite la commande (30s packaging + 1min shipping)
   - Email de confirmation reçu via SNS

### Cartes de test Stripe

| Carte | Résultat |
|-------|----------|
| `4242 4242 4242 4242` | ✅ Paiement réussi |
| `4000 0000 0000 0002` | ❌ Paiement refusé |
| `4000 0025 0000 3155` | 🔐 Authentification 3D Secure requise |

### Vérifier les logs

```bash
# Logs Lambda Checkout
aws logs tail /aws/lambda/ecommerce-checkout --follow

# Logs Lambda Webhook
aws logs tail /aws/lambda/ecommerce-webhook --follow

# Logs Lambda Worker
aws logs tail /aws/lambda/ecommerce-worker --follow

# Logs EC2 Worker (depuis l'instance)
ssh -i ecommerce-worker-key.pem ec2-user@<EC2_PUBLIC_IP>
sudo journalctl -u ec2-worker -f
```

### Vérifier les données

```bash
# Scanner la table DynamoDB
aws dynamodb scan --table-name ecommerce-orders

# Se connecter à RDS (depuis EC2)
ssh -i ecommerce-worker-key.pem ec2-user@<EC2_PUBLIC_IP>
mysql -h <RDS_ENDPOINT> -u admin -p
# Mot de passe : celui dans terraform.tfvars

mysql> USE ecommerce;
mysql> SELECT * FROM orders;
```

---

## 🧹 Nettoyage

### Supprimer toute l'infrastructure

```bash
cd terraform

# IMPORTANT : Vider le bucket S3 d'abord
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive

# Détruire l'infrastructure
terraform destroy

# Confirmer avec 'yes'
```

### Supprimer les ressources manuelles

```bash
# Supprimer la clé SSH
aws ec2 delete-key-pair --key-name ecommerce-worker-key
rm ecommerce-worker-key.pem

# Supprimer les logs CloudWatch (optionnel)
aws logs delete-log-group --log-group-name /aws/lambda/ecommerce-checkout
aws logs delete-log-group --log-group-name /aws/lambda/ecommerce-webhook
aws logs delete-log-group --log-group-name /aws/lambda/ecommerce-worker
```

⚠️ **Attention** : Cette commande supprime TOUT et est IRRÉVERSIBLE !

---

## 🐛 Troubleshooting

### ❌ Erreur : "Bucket already exists"

**Problème** : Le nom du bucket S3 est déjà pris (les noms S3 sont globaux).

**Solution** :
```hcl
# Dans terraform.tfvars, changer :
bucket_name = "aws-ecommerce-frontend-votrenom-12345"
```

### ❌ Erreur : "Invalid credentials"

**Problème** : AWS CLI n'est pas configuré correctement.

**Solution** :
```bash
aws configure
aws sts get-caller-identity  # Vérifier l'identité
```

### ❌ Lambda Checkout ne renvoie pas d'URL de session

**Problème** : Lambda Checkout n'est pas implémenté (fichier vide).

**Solution** : Implémenter la logique dans `lambda-checkout/index.js` :
```javascript
import Stripe from 'stripe';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

export const handler = async (event) => {
  try {
    const body = JSON.parse(event.body);

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: body.items,
      mode: 'payment',
      success_url: body.success_url,
      cancel_url: body.cancel_url,
    });

    return {
      statusCode: 200,
      body: JSON.stringify({ url: session.url }),
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
    };
  }
};
```

### ❌ Webhook Stripe non reçu

**Problème** : Le webhook n'est pas configuré dans Stripe.

**Solution** :
1. Aller sur https://dashboard.stripe.com/test/webhooks
2. Ajouter l'endpoint : `<API_GATEWAY_URL>/webhook`
3. Sélectionner événements : `checkout.session.completed`
4. Copier le signing secret dans `terraform.tfvars`
5. Redéployer : `terraform apply`

### ❌ EC2 Worker ne traite pas les commandes

**Problème** : Le service systemd ne démarre pas.

**Solution** :
```bash
# SSH vers l'instance EC2
ssh -i ecommerce-worker-key.pem ec2-user@<EC2_PUBLIC_IP>

# Vérifier le statut
sudo systemctl status ec2-worker

# Voir les logs
sudo journalctl -u ec2-worker -f

# Vérifier les variables d'environnement
sudo systemctl show ec2-worker --property=Environment

# Redémarrer
sudo systemctl restart ec2-worker
```

### ❌ RDS inaccessible depuis EC2

**Problème** : Security groups mal configurés.

**Solution** :
```bash
# Vérifier depuis EC2
ssh -i ecommerce-worker-key.pem ec2-user@<EC2_PUBLIC_IP>

# Tester la connexion MySQL
mysql -h <RDS_ENDPOINT> -u admin -p

# Si échec, vérifier les security groups dans la console AWS
```

### ❌ SNS emails non reçus

**Problème** : Abonnement SNS non confirmé.

**Solution** :
1. Vérifier le dossier spam
2. Dans la console AWS SNS, aller dans "Subscriptions"
3. Vérifier que le statut est "Confirmed"
4. Sinon, renvoyer la confirmation ou créer un nouvel abonnement

### ❌ CloudFront montre une erreur 403

**Problème** : Le bucket S3 est vide ou la policy n'est pas correcte.

**Solution** :
```bash
# Déployer le frontend
cd aws-ecommerce-frontend
npm run build
aws s3 sync out/ s3://<BUCKET_NAME>/ --delete

# Invalider le cache CloudFront
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

---

## 📚 Ressources

- [Documentation AWS](https://docs.aws.amazon.com/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Documentation Stripe](https://stripe.com/docs)
- [Next.js Documentation](https://nextjs.org/docs)

---

## 📊 Coûts estimés

### Free Tier (12 premiers mois)

- ✅ Lambda : 1M requêtes/mois gratuites
- ✅ API Gateway : 1M requêtes/mois gratuites
- ✅ DynamoDB : 25 GB gratuits
- ✅ S3 : 5 GB gratuits
- ✅ CloudFront : 50 GB gratuits
- ✅ RDS : 750h/mois t2.micro gratuits
- ✅ EC2 : 750h/mois t2.micro gratuits

### Hors Free Tier (estimation mensuelle)

| Service | Utilisation | Coût estimé |
|---------|-------------|-------------|
| EC2 t2.micro | 24/7 | ~8€ |
| RDS t3.micro | 24/7 | ~15€ |
| NAT Gateway | 24/7 | ~30€ |
| CloudFront | 100 GB | ~10€ |
| Lambda + API Gateway | 100K req/mois | ~2€ |
| DynamoDB on-demand | 1M req/mois | ~1€ |
| SQS | 1M messages | ~0,50€ |
| SNS | 1K emails | ~2€ |
| **TOTAL** | | **~68€/mois** |

💡 **Conseils pour réduire les coûts** :
- ✅ Arrêter RDS/EC2 quand non utilisé (économie ~50%)
- ✅ Utiliser VPC endpoints au lieu de NAT Gateway (-30€/mois)
- ✅ Passer DynamoDB en mode provisionné pour usage prévisible
- ✅ Utiliser CloudFront avec cache agressif

---

## 🎓 Contexte académique

Ce projet démontre les compétences suivantes :

✅ **Architecture cloud AWS** - Utilisation de 10+ services AWS
✅ **Infrastructure as Code** - Terraform pour tout provisionner
✅ **Serverless computing** - Lambdas, API Gateway, S3
✅ **Microservices** - Découplage avec SQS, async processing
✅ **Sécurité cloud** - VPC, Security Groups, IAM, subnets privés
✅ **Intégration tierce** - Stripe pour paiements
✅ **Monitoring** - CloudWatch Logs, métriques
✅ **Scalabilité** - Auto-scaling implicite des services serverless

---

## 🤝 Support

Pour toute question concernant le déploiement :

1. Vérifier la section [Troubleshooting](#-troubleshooting)
2. Consulter les logs CloudWatch
3. Ouvrir une issue GitHub

---

## 📝 Notes importantes

- ⚠️ Ce projet est conçu pour l'éducation, pas la production
- ⚠️ Les secrets sont dans `terraform.tfvars` pour simplifier (à éviter en prod)
- ⚠️ Le bucket S3 doit avoir un nom globalement unique
- ⚠️ Pensez à détruire l'infrastructure après les tests pour éviter les coûts
- ⚠️ Confirmez tous les abonnements SNS pour recevoir les emails

---

**Version** : 1.0
**Dernière mise à jour** : Octobre 2025
**Terraform** : >= 1.6.0
**AWS Provider** : ~> 5.0
**Node.js** : >= 20.x

**Auteurs** : Projet IMT Nord Europe 2025 
Islem ZOUAOUI ; Zhengkun YANG ; Vianney MARC
