variable "aws_region" {
  description = "La région AWS où déployer les ressources"
  type        = string
  default     = "eu-west-3"
}

variable "project_name" {
  description = "Le nom du projet"
  type        = string
  default     = "news-visualizer"
}

variable "environment" {
  description = "L'environnement de déploiement"
  type        = string
  default     = "dev"
}

variable "openai_api_key" {
  description = "La clé API OpenAI"
  type        = string
  sensitive   = true
}

variable "news_api_key" {
  description = "La clé API News"
  type        = string
  sensitive   = true
} 