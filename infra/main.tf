data "aws_caller_identity" "current" {}

module "apps_lambda" {
  source = "./modules/lambda"

  lambda_name         = "apps-func"
  region              = var.region
  account_id          = data.aws_caller_identity.current.account_id
  ecr_repository_name = "main"
  image_tag           = "apps"

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
        "apigateway:GET",
        "apigateway:DELETE",
      ]
      Resource = "*"
    },
    {
      Effect = "Allow"
      Action = [
        "ses:VerifyEmailIdentity",
        "ses:GetIdentityVerificationAttributes",
        "ses:DeleteIdentity"
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


  routes = [{
    path_part      = "apps"
    http_methods   = ["GET", "POST", "DELETE" ]
    lambda_arn     = module.apps_lambda.lambda_arn
    lambda_name    = module.apps_lambda.lambda_name
    enable_api_key = false
  },
  {
    path_part      = "apikeys"
    http_methods   = ["POST", "DELETE"]
    lambda_arn     = module.apps_lambda.lambda_arn
    lambda_name    = module.apps_lambda.lambda_name
    enable_api_key = false
  },
  {
    path_part      = "email"
    http_methods   = ["POST"]
    lambda_arn     = module.email_lambda.lambda_arn
    lambda_name    = module.email_lambda.lambda_name
    enable_api_key = true
  }
  
  ]

  usage_plan_config = {
    name         = "email-service-plan"
    burst_limit  = 5
    rate_limit   = 3
    quota_limit  = 3
    quota_period = "DAY"
  }
}


resource "null_resource" "update_lambda_usage_plan" {
  depends_on = [
    module.api_gateway,
    module.apps_lambda
  ]

  triggers = {
    usage_plan_id = module.api_gateway.usage_plan_id
    always_run     = timestamp()
  }

  provisioner "local-exec" {
    command = <<EOF
aws lambda update-function-configuration \
  --function-name ${module.apps_lambda.lambda_name} \
  --environment "Variables={MONGODB_URI=${var.mongodb_uri},USAGE_PLAN_ID=${module.api_gateway.usage_plan_id}}" \
  --region ${var.region}
EOF
  }
}

