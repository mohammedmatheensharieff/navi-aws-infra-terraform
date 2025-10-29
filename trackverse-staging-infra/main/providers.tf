terraform {
  required_version = ">= 1.6"

  backend "s3" {} # 👈 this tells Terraform you'll use -backend-config for S3

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}
