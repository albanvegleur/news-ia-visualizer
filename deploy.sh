#!/bin/bash

# Créer les packages Lambda
echo "Création des packages Lambda..."
./package_lambda.sh

# Appliquer les changements Terraform
echo "Application des changements Terraform..."
terraform apply -auto-approve

# Récupérer l'URL de l'API
API_URL=$(terraform output -raw api_url)

# Générer le fichier de configuration
echo "Génération du fichier de configuration..."
cat > website/config.js << EOF
const config = {
    API_ENDPOINT: '${API_URL}'
};
EOF

# Déployer le site web
echo "Déploiement du site web..."
aws s3 cp website/index.html s3://news-visualizer-website-dev/
aws s3 cp website/config.js s3://news-visualizer-website-dev/

# Invalider le cache CloudFront
echo "Invalidation du cache CloudFront..."
aws cloudfront create-invalidation --distribution-id $(terraform output -raw cloudfront_distribution_id) --paths "/*"

echo "Déploiement terminé !" 