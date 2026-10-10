variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "cyber-analyzer"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "eastus"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "cyber-analyzer-rg"
}

variable "openai_api_key" {
  description = "OpenAI API key for the application"
  type        = string
  sensitive   = true
  default     = ""
}

variable "openai_base_url" {
  description = "Base URL for the OpenAI-compatible API endpoint (override when using a proxy or relay)"
  type        = string
  default     = "https://api.openai.com/v1"
}

variable "semgrep_app_token" {
  description = "Semgrep app token for security scanning"
  type        = string
  sensitive   = true
  default     = ""
}

variable "docker_image_tag" {
  description = "Tag for the Docker image"
  type        = string
  default     = "latest"
}