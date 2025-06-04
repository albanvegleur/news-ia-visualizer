terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Rôle IAM pour les fonctions Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-lambda-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Politique IAM pour les fonctions Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-lambda-policy-${var.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.images_bucket.arn,
          "${aws_s3_bucket.images_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# S3 Bucket pour les images générées
resource "aws_s3_bucket" "images_bucket" {
  bucket = "${var.project_name}-images-${var.environment}"
}

# S3 Bucket pour le site web statique
resource "aws_s3_bucket" "website_bucket" {
  bucket = "${var.project_name}-website-${var.environment}"
  force_destroy = true
}

# Configuration du bucket website pour l'hébergement statique
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Désactiver le blocage d'accès public du bucket
resource "aws_s3_bucket_public_access_block" "website_bucket_access" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Politique de bucket pour permettre l'accès public
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  depends_on = [aws_s3_bucket_public_access_block.website_bucket_access]
  
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      }
    ]
  })
}

# Configuration CORS pour le bucket d'images
resource "aws_s3_bucket_cors_configuration" "images_bucket_cors" {
  bucket = aws_s3_bucket.images_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# DynamoDB Table
resource "aws_dynamodb_table" "news_table" {
  name           = "${var.project_name}-news-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

# Lambda Function pour la génération d'images
resource "aws_lambda_function" "image_generator" {
  filename         = "lambda/image_generator.zip"
  function_name    = "${var.project_name}-image-generator-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  timeout         = 300
  environment {
    variables = {
      OPENAI_API_KEY = var.openai_api_key
      BUCKET_NAME    = aws_s3_bucket.images_bucket.id
      NEWS_API_KEY   = var.news_api_key
    }
  }
}

# Lambda Function pour récupérer les images
resource "aws_lambda_function" "get_images" {
  filename         = "lambda/get_images.zip"
  function_name    = "${var.project_name}-get-images-${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "nodejs18.x"
  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.images_bucket.id
    }
  }
}

# CloudWatch Event Rule pour déclencher la génération d'images
resource "aws_cloudwatch_event_rule" "image_generation" {
  name                = "${var.project_name}-image-generation-${var.environment}"
  description         = "Déclenche la génération d'images toutes les 15 minutes"
  schedule_expression = "rate(15 minutes)"
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "image_generation_target" {
  rule      = aws_cloudwatch_event_rule.image_generation.name
  target_id = "ImageGenerator"
  arn       = aws_lambda_function.image_generator.arn
}

# API Gateway
resource "aws_apigatewayv2_api" "api" {
  name          = "${var.project_name}-api-${var.environment}"
  protocol_type = "HTTP"
  cors_configuration {
    allow_headers = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_origins = ["*"]
    max_age      = 300
  }
}

# API Gateway Stage
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id = aws_apigatewayv2_api.api.id
  name   = var.environment
  auto_deploy = true
}

# Route pour la génération d'images
resource "aws_apigatewayv2_route" "generate_image" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /generate-image"
  target    = "integrations/${aws_apigatewayv2_integration.image_generator.id}"
}

# Route pour récupérer les images
resource "aws_apigatewayv2_route" "get_images" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /images"
  target    = "integrations/${aws_apigatewayv2_integration.get_images.id}"
}

# Intégration pour la fonction image_generator
resource "aws_apigatewayv2_integration" "image_generator" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  description        = "Intégration avec la fonction Lambda image_generator"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.image_generator.invoke_arn
}

# Intégration pour la fonction get_images
resource "aws_apigatewayv2_integration" "get_images" {
  api_id           = aws_apigatewayv2_api.api.id
  integration_type = "AWS_PROXY"

  connection_type    = "INTERNET"
  description        = "Intégration avec la fonction Lambda get_images"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.get_images.invoke_arn
}

# Permission pour que l'API Gateway puisse invoquer image_generator
resource "aws_lambda_permission" "api_gateway_image_generator" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_generator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# Permission pour que l'API Gateway puisse invoquer get_images
resource "aws_lambda_permission" "api_gateway_get_images" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_images.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "website_distribution" {
  origin {
    domain_name = aws_s3_bucket_website_configuration.website_config.website_endpoint
    origin_id   = "S3-${aws_s3_bucket.website_bucket.bucket}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.website_bucket.bucket}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Outputs
output "website_url" {
  description = "L'URL du site web"
  value       = "https://${aws_cloudfront_distribution.website_distribution.domain_name}"
}

output "api_url" {
  description = "L'URL de l'API"
  value       = "${aws_apigatewayv2_stage.api_stage.invoke_url}"
}

output "website_bucket" {
  value = aws_s3_bucket.website_bucket.id
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.website_distribution.id
} 