terraform {
  required_version = ">= 1.9" # 1.9+ allows multiple validation blocks per variable

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  # Explicit region — the lab must not depend on your CLI default region.
  region = var.aws_region
}
