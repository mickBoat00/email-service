data "aws_caller_identity" "current" {}

module "identity_lambda" {
  source = "./modules/lambda"

  lambda_name         = "identity-func"
  region              = var.region
  account_id          = data.aws_caller_identity.current.account_id
  ecr_repository_name = "main"
  image_tag           = "identity"

  environment_variables = {
    MONGODB_URI   = var.mongodb_uri
    # USAGE_PLAN_ID = module.api_gateway.usage_plan_id
  }

  policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "*"
    },
    {
      Effect = "Allow"
      Action = [
        "apigateway:POST",
        "apigateway:GET"
      ]
      Resource = "*"
    }
  ]
}

module "email_lambda" {
  source = "./modules/lambda"

  lambda_name         = "email-func"
  region              = var.region
  account_id          = data.aws_caller_identity.current.account_id
  ecr_repository_name = "main"
  image_tag           = "email"

  environment_variables = {
    MONGODB_URI = var.mongodb_uri
  }

  policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "*"
    },
    {
      Effect = "Allow"
      Action = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ]
      Resource = "*"
    }
  ]
}


module "api_gateway" {
  source = "./modules/apigateway"

  api_name   = "email-service-api"
  region     = var.region
  stage_name = "dev"

  routes = [
    {
      path_part      = "identity"
      http_method    = "POST"
      lambda_arn     = module.identity_lambda.lambda_arn
      lambda_name    = module.identity_lambda.lambda_name
      enable_api_key = false
    },
    {
      path_part      = "send"
      http_method    = "POST"
      lambda_arn     = module.email_lambda.lambda_arn
      lambda_name    = module.email_lambda.lambda_name
      enable_api_key = true
    }
  ]

  usage_plan_config = {
    name         = "email-service-plan"
    burst_limit  = 100
    rate_limit   = 50
    quota_limit  = 10000
    quota_period = "DAY"
  }
}

