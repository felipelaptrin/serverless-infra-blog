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
##### DATABASE
########################################
module "dynamodb-table" {
  source  = "terraform-aws-modules/dynamodb-table/aws"
  version = "4.2.0"

  name = var.table_name
  attributes = var.table_attributes
  hash_key = var.table_hash_key
  billing_mode = "PAY_PER_REQUEST"
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
  environment_variables = {
    TABLE_NAME = var.table_name
    FRONTEND_ENDPOINT = "https://${var.frontend_subdomain}.${var.domain}"
  }

  create_current_version_allowed_triggers = false
  allowed_triggers = {
    ApiGateway = {
      service = "apigateway",
      source_arn = "arn:aws:execute-api:${var.aws_region}:${local.account_id}:${module.api_gateway.api_id}/*/*"
    }
  }

  attach_policy_json = true
  policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:Batch*",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan",
        ]
        Effect   = "Allow"
        Resource = "${module.dynamodb-table.dynamodb_table_arn	}"
      },
    ]
  })
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

  cors_configuration = {
    allow_headers = ["*"]
    allow_methods = ["*"]
    allow_origins = ["https://${var.frontend_subdomain}.${var.domain}"]
  }

  routes = {
    "$default" = {
      integration = {
        uri = "arn:aws:lambda:${var.aws_region}:${local.account_id}:function:${var.lambda_name}" // module.lambda_function.lambda_function_arn
        payload_format_version = "2.0"
      }
    }
  }
}

########################################
##### FRONTEND
########################################
module "s3_bucket" {
  source = "terraform-aws-modules/s3-bucket/aws"
  version = "4.2.2"

  bucket = var.frontend_bucket_name

  attach_policy	= true
  policy = jsonencode({
    "Version" : "2008-10-17",
    "Id" : "PolicyForCloudFrontPrivateContent",
    "Statement" : [
      {
        "Sid" : "AllowCloudFrontServicePrincipal",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "cloudfront.amazonaws.com"
        },
        "Action" : "s3:GetObject",
        "Resource" : "arn:aws:s3:::${var.frontend_bucket_name}/*",
        "Condition" : {
          "StringEquals" : {
            "AWS:SourceArn" : "arn:aws:cloudfront::${local.account_id}:distribution/${module.cdn.cloudfront_distribution_id	}"
          }
        }
      }
    ]
  })

  providers = {
    aws = aws.us_east_1
  }
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "5.1.1"

  domain_name  = var.domain
  validation_method = "DNS"
  zone_id = data.aws_route53_zone.this.id

  subject_alternative_names = [
    "${var.frontend_subdomain}.${var.domain}",
  ]
  wait_for_validation = true

  providers = {
    aws = aws.us_east_1
  }
}

module "cdn" {
  source = "terraform-aws-modules/cloudfront/aws"
  version = "3.4.1"

  aliases = ["${var.frontend_subdomain}.${var.domain}"]
  comment             = "CDN of Frontend"
  price_class         = "PriceClass_All"
  is_ipv6_enabled     = true
  default_root_object	= "index.html"

  create_origin_access_control = true
  origin_access_control = {
    s3_bucket_frontend = {
      description = "Frontend assets bucket"
      origin_type = "s3"
      signing_behavior = "always",
      signing_protocol = "sigv4"
    }
  }
  origin = {
    s3 = {
      domain_name = "${var.frontend_bucket_name}.s3.us-east-1.amazonaws.com"
      origin_access_control = "s3_bucket_frontend"
    }
  }

  default_cache_behavior = {
    target_origin_id           = "s3"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
  }

  viewer_certificate = {
    acm_certificate_arn = module.acm.acm_certificate_arn
    ssl_support_method  = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

module "records" {
  source  = "terraform-aws-modules/route53/aws//modules/records"
  version = "4.1.0"

  zone_name = data.aws_route53_zone.this.name

  records = [
    {
      name    = "${var.frontend_subdomain}"
      type    = "A"
      alias   = {
        name    = module.cdn.cloudfront_distribution_domain_name
        zone_id = module.cdn.cloudfront_distribution_hosted_zone_id
      }
    }
  ]
}