output "s3-state-bucket-name" {
  description = "Name of the S3 bucket that stores Terraform state files"
  value       = module.s3-bucket.s3_bucket_id
}

output "dynamodb-lock-table-name" {
  description = "Name of the DynamoDB table used to lock deployments"
  value       = module.dynamodb_table.dynamodb_table_id
}