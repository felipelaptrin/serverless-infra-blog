data "aws_caller_identity" "current" {}

# Reference: https://developer.hashicorp.com/terraform/language/backend/s3#state-storage
module "s3-bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "4.2.2"

  bucket = "terraform-states-${data.aws_caller_identity.current.account_id}-serverless-infra"
}

# Reference: https://developer.hashicorp.com/terraform/language/backend/s3#dynamodb-state-locking
module "dynamodb_table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "4.2.0"

  name     = "terraform-lock-${data.aws_caller_identity.current.account_id}-serverless-infra"
  hash_key = "LockID"
  attributes = [
    {
      name = "LockID"
      type = "S"
    }
  ]
}