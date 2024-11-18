provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project    = "Serverless Infra"
      Repository = "https://github.com/felipelaptrin/serverless-infra"
    }
  }
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project    = "Serverless Infra"
      Repository = "https://github.com/felipelaptrin/serverless-infra"
    }
  }
}