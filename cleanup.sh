#!/bin/bash

# Fonction pour afficher le menu
show_menu() {
    echo "=== Menu de nettoyage AWS ==="
    echo "1) Nettoyer tous les buckets S3"
    echo "2) Nettoyer toutes les fonctions Lambda"
    echo "3) Nettoyer la table DynamoDB"
    echo "4) Nettoyer les rôles IAM"
    echo "5) Nettoyer l'API Gateway"
    echo "6) Nettoyer la distribution CloudFront"
    echo "7) Nettoyer toutes les ressources"
    echo "0) Quitter"
    echo "============================"
    echo -n "Choisissez une option (0-7): "
}

# Fonction pour nettoyer tous les buckets S3
cleanup_s3() {
    echo "Nettoyage des buckets S3..."
    delete_s3_bucket "news-visualizer-website-dev"
    delete_s3_bucket "news-visualizer-images-dev"
}

# Fonction pour nettoyer toutes les fonctions Lambda
cleanup_lambda() {
    echo "Nettoyage des fonctions Lambda..."
    delete_lambda_function "news-visualizer-image-generator-dev"
    delete_lambda_function "news-visualizer-get-images-dev"
}

# Fonction pour nettoyer toutes les ressources
cleanup_all() {
    echo "Nettoyage de toutes les ressources..."
    cleanup_s3
    cleanup_lambda
    delete_dynamodb_table "news-visualizer-news-dev"
    delete_iam_role "news-visualizer-lambda-role-dev"
    delete_api_gateway "kbfh7vdcba"
    delete_cloudfront_distribution "E3QZE652RLPG2C"
    echo "Nettoyage terminé !"
}

# Fonction pour supprimer un bucket S3 et son contenu
delete_s3_bucket() {
    local bucket_name=$1
    echo "Suppression du bucket S3: $bucket_name"
    aws s3 rm s3://$bucket_name --recursive
    aws s3api delete-bucket --bucket $bucket_name
}

# Fonction pour supprimer une distribution CloudFront
delete_cloudfront_distribution() {
    local distribution_id=$1
    echo "Suppression de la distribution CloudFront: $distribution_id"
    aws cloudfront get-distribution-config --id $distribution_id --query 'DistributionConfig' > config.json
    aws cloudfront delete-distribution --id $distribution_id --if-match $(jq -r '.ETag' config.json)
    rm config.json
}

# Fonction pour supprimer une fonction Lambda
delete_lambda_function() {
    local function_name=$1
    echo "Suppression de la fonction Lambda: $function_name"
    aws lambda delete-function --function-name $function_name
}

# Fonction pour supprimer une table DynamoDB
delete_dynamodb_table() {
    local table_name=$1
    echo "Suppression de la table DynamoDB: $table_name"
    aws dynamodb delete-table --table-name $table_name
}

# Fonction pour supprimer une API Gateway
delete_api_gateway() {
    local api_id=$1
    echo "Suppression de l'API Gateway: $api_id"
    aws apigateway delete-rest-api --rest-api-id $api_id
}

# Fonction pour supprimer un rôle IAM
delete_iam_role() {
    local role_name=$1
    echo "Suppression du rôle IAM: $role_name"
    aws iam detach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    aws iam delete-role --role-name $role_name
}

# Boucle principale du menu
while true; do
    show_menu
    read -r choice

    case $choice in
        1) cleanup_s3 ;;
        2) cleanup_lambda ;;
        3) delete_dynamodb_table "news-visualizer-news-dev" ;;
        4) delete_iam_role "news-visualizer-lambda-role-dev" ;;
        5) delete_api_gateway "kbfh7vdcba" ;;
        6) delete_cloudfront_distribution "E3QZE652RLPG2C" ;;
        7) cleanup_all ;;
        0) echo "Au revoir !"; exit 0 ;;
        *) echo "Option invalide. Veuillez réessayer." ;;
    esac

    echo
    read -p "Appuyez sur Entrée pour continuer..."
done 