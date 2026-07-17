terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # Uncomment and configure for team use. Left local-backend by default so
  # this repo is `terraform apply`-ready with zero external state setup.
  # backend "s3" {
  #   bucket         = "your-tf-state-bucket"
  #   key            = "serverless-dr/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}
