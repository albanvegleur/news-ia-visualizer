#!/bin/bash

# Packager les lambdas
echo "Packaging des lambdas..."
./package_lambda.sh

# Appliquer les changements Terraform
echo "Application des changements Terraform..."
terraform apply -auto-approve

# Récupérer l'URL du bucket S3 pour le site web
WEBSITE_BUCKET=$(terraform output -raw website_bucket)

# Récupérer l'URL de l'API depuis les outputs Terraform
API_URL=$(terraform output -raw api_url)

# Créer un fichier temporaire avec les variables remplacées
envsubst '${API_URL}' < website/index.html > website/index.html.tmp
mv website/index.html.tmp website/index.html

# Déployer le site web
echo "Déploiement du site web sur S3..."
aws s3 sync website/ s3://$WEBSITE_BUCKET/ --delete

# Invalider le cache CloudFront
echo "Invalidation du cache CloudFront..."
aws cloudfront create-invalidation --distribution-id $(terraform output -raw cloudfront_distribution_id) --paths "/*"

echo "Déploiement terminé !" 