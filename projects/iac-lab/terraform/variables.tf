variable "project_name" {
  description = "Name prefix for all lab resources"
  type        = string
  default     = "iac-lab"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }

  validation {
    condition     = var.project_name != "twin"
    error_message = "This lab must use its own prefix so it can never collide with your live twin."
  }
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, prod."
  }
}

variable "aws_region" {
  description = "AWS region for the lab (same as your twin is fine — names never collide)"
  type        = string
  default     = "us-east-2"
}

variable "bedrock_model_id" {
  description = "Amazon Bedrock model ID (Nova Lite runs in-region in us-east-2)"
  type        = string
  default     = "amazon.nova-lite-v1:0"
}

variable "max_tokens" {
  description = "Maximum tokens in the AI answer (keeps practice costs tiny)"
  type        = number
  default     = 200
}

variable "system_prompt" {
  description = "System prompt — change it and re-apply to watch Terraform update the Lambda"
  type        = string
  default     = "You are a concise assistant. Answer in at most three sentences."
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds (AI calls can take a few seconds)"
  type        = number
  default     = 30
}

variable "api_throttle_burst_limit" {
  description = "API Gateway throttle burst limit"
  type        = number
  default     = 10
}

variable "api_throttle_rate_limit" {
  description = "API Gateway throttle steady-state rate (requests per second)"
  type        = number
  default     = 5
}
