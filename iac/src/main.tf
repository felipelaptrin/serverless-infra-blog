########################################
##### NETWORKING
########################################
module "vpc" {
  count = var.vpc_deploy == true ? 1 : 0

  source = "terraform-aws-modules/vpc/aws"
  version = "5.15.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
}

########################################
##### BACKEND
########################################
module "ecr" {
  source = "terraform-aws-modules/ecr/aws"
  version = "2.3.0"

  repository_name = "backend-api"
  repository_image_tag_mutability = "MUTABLE"
  repository_image_scan_on_push	= false
  create_lifecycle_policy	= false
}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"
  version = "7.14.0"

  function_name = var.lambda_name
  description   = "Lambda Function based API serving as backend for the app"
  create_package = false
  architectures = [var.lambda_architecture]
  image_uri    = "${module.ecr.repository_url}:latest"
  package_type = "Image"
  cloudwatch_logs_retention_in_days = var.logs_retention

  attach_network_policy	= true
  vpc_subnet_ids = module.vpc[0].private_subnets

  memory_size = var.lambda_memory
  timeout = var.lambda_timeout

  create_current_version_allowed_triggers = false
  allowed_triggers = {
    ApiGateway = {
      service = "apigateway",
      source_arn = "arn:aws:execute-api:${var.aws_region}:${data.aws_caller_identity.current.account_id}:${module.api_gateway.api_id}/*/*"
    }
  }
}

module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"
  version = "5.2.0"

  name          = "backend-gateway"
  description   = "HTTP API Gateway for the Lambda-based API"
  protocol_type = "HTTP"
  domain_name = "${var.backend_subdomain}.${var.domain}"
  hosted_zone_name = var.domain
  subdomains  = [var.backend_subdomain]


  routes = {
    "$default" = {
      integration = {
        uri = "arn:aws:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.lambda_name}" // module.lambda_function.lambda_function_arn
        payload_format_version = "2.0"
      }
    }
  }
}
