
########################################
##### GENERAL
########################################
variable "aws_region" {
  type        = string
  description = "AWS region to deploy the infrastructure"
  default     = "us-east-1"
}

variable "domain" {
  type        = string
  description = "The domain of your project"
}

variable "logs_retention" {
  type        = number
  description = "CloudWatch Group log retention"
  default     = 90
}

########################################
##### NETWORKING
########################################
variable "vpc_deploy" {
  type        = bool
  description = "Controls the deployment of the VPC resources (VPC, Subnets, Internet Gateway, Route Table...). If you already have a VPC deployed, set this variable to false and set 'vpc_id' variable."
  default     = true
}

variable "vpc_id" {
  type        = string
  description = "VPC ID of the already deployed VPC in your account. To use this, set vpc_deploy to false."
  default     = ""
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC to deploy"
  default     = "PoC"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR of the VPC to create. Please use a /16 mask for high compatibility with this module."
  default     = "10.50.0.0/16"
}

########################################
##### BACKEND
########################################
variable "backend_subdomain" {
  type        = string
  description = "Subdomain where the API Gateway will be exposed, i.e. https://{backend_subdomain}/{domain}"
  default     = "api"
}

variable "lambda_name" {
  type        = string
  description = "Name of the Lambda Function"
  default     = "backend-api"
}

variable "lambda_memory" {
  type        = number
  description = "Amount of memory that should be used in the Lambda"
  default     = 256
}

variable "lambda_architecture" {
  type        = string
  description = "Architecture that the Lambda function will run"
  default     = "arm64"

  validation {
    condition     = contains(["x86_64", "arm64"], var.lambda_architecture)
    error_message = "Valid values for var: test_variable are: 'x86_64' and 'arm64'."
  }
}

variable "lambda_timeout" {
  type        = number
  description = "Timeout in seconds of the Lambda"
  default     = 5
}

########################################
##### DATABASE
########################################
variable "table_name" {
  type        = string
  description = "Name of the DynamoDB table"
  default     = "table"
}

variable "table_attributes" {
  type        = list(map(string))
  description = "Attributes of the DynamoDB table"
  default = [
    {
      name = "UserId",
      type = "S",
    },
  ]
}

variable "table_hash_key" {
  type        = string
  description = "Hash key of the DynamodDB table"
  default     = "UserId"
}

########################################
##### FRONTEND
########################################
variable "frontend_subdomain" {
  type        = string
  description = "Subdomain that the Website will be exposed, i.e. https://{frontend_subdomain}/{domain}"
  default     = "app"
}

variable "frontend_bucket_name" {
  type        = string
  description = "Name of the S3 bucket that will contains the frontend website"
}