terraform {
  required_version = "~> 1.9.8"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.75"
    }
  }

  backend "s3" {
    bucket         = "terraform-states-937168356724-serverless-infra"
    key            = "state.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-937168356724-serverless-infra"
  }
}