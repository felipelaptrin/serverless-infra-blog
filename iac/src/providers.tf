provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "Serverless Infra"
      Repository = "https://github.com/felipelaptrin/serverless-infra"
    }
  }
}