provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Project    = "Serverless Infra"
      Repository = "https://github.com/felipelaptrin/serverless-infra"
    }
  }
}