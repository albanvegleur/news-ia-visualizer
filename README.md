# Visualiseur d'Actualités

Une application qui génère automatiquement des visualisations artistiques des actualités en utilisant OpenAI DALL-E et AWS.

## Architecture

- **API Gateway** : Endpoint HTTP pour accéder aux images générées
- **Fonctions Lambda** :
  - `get_images` : Pour récupérer les images
  - `image_generator` : Pour générer les images
- **S3 Buckets** :
  - Bucket pour stocker les images générées
  - Bucket pour héberger le site web statique
- **CloudFront** : Distribution pour servir le site web
- **DynamoDB** : Table pour stocker les informations sur les actualités
- **CloudWatch** : Règle pour déclencher la génération d'images toutes les 15 minutes

## Prérequis

- AWS CLI configuré avec les permissions appropriées
- Terraform installé
- Node.js et npm installés
- Une clé API OpenAI

## Installation

1. Clonez le dépôt :
   ```bash
   git clone [URL_DU_REPO]
   cd news-visualizer
   ```

2. Installez les dépendances des fonctions Lambda :
   ```bash
   cd lambda
   npm install
   cd ..
   ```

3. Créez un fichier `terraform.tfvars` avec vos variables :
   ```hcl
   aws_region = "eu-west-3"
   project_name = "news-visualizer"
   environment = "dev"
   openai_api_key = "votre-clé-api-openai"
   ```

4. Initialisez et appliquez la configuration Terraform :
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Utilisation

Une fois déployé, l'application :
1. Générera automatiquement des images toutes les 15 minutes
2. Les images seront accessibles via l'interface web
3. L'interface web sera accessible via l'URL CloudFront fournie dans les sorties Terraform

## Maintenance

- Les logs des fonctions Lambda sont disponibles dans CloudWatch
- Les images sont stockées dans le bucket S3 dédié
- La configuration peut être modifiée via Terraform

## Sécurité

- La clé API OpenAI est stockée de manière sécurisée dans les variables d'environnement Lambda
- Les buckets S3 sont configurés avec les permissions appropriées
- L'API Gateway est configuré avec les en-têtes CORS nécessaires

## Coûts

L'application utilise les services AWS suivants qui peuvent générer des coûts :
- Lambda
- S3
- API Gateway
- CloudFront
- DynamoDB
- CloudWatch

Consultez la [calculatrice de prix AWS](https://calculator.aws/) pour estimer les coûts. 