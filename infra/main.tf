data "aws_caller_identity" "current" {}

module "apps_lambda" {
  source = "./modules/lambda"

  lambda_name         = "apps-func"
  region              = var.region
  account_id          = data.aws_caller_identity.current.account_id
  ecr_repository_name = "main"
  image_tag           = "apps"

  # environment_variables = {
  #   MONGODB_URI   = var.mongodb_uri
  #   USAGE_PLAN_ID = module.api_gateway.usage_plan_id
  # }

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

# module "email_lambda" {
#   source = "./modules/lambda"

#   lambda_name         = "email-func"
#   region              = var.region
#   account_id          = data.aws_caller_identity.current.account_id
#   ecr_repository_name = "main"
#   image_tag           = "email"

#   environment_variables = {
#     MONGODB_URI = var.mongodb_uri
#   }

#   policy_statements = [
#     {
#       Effect = "Allow"
#       Action = [
#         "logs:CreateLogGroup",
#         "logs:CreateLogStream",
#         "logs:PutLogEvents"
#       ]
#       Resource = "*"
#     },
#     {
#       Effect = "Allow"
#       Action = [
#         "ses:SendEmail",
#         "ses:SendRawEmail"
#       ]
#       Resource = "*"
#     }
#   ]
# }


module "api_gateway" {
  source = "./modules/apigateway"

  api_name   = "email-service-api"
  region     = var.region
  stage_name = "dev"

  routes = [
    {
      path_part      = "apps"
      http_method    = "GET"
      lambda_arn     = module.apps_lambda.lambda_arn
      lambda_name    = module.apps_lambda.lambda_name
      enable_api_key = false
    },
    {
      path_part      = "apps"
      http_method    = "POST"
      lambda_arn     = module.apps_lambda.lambda_arn
      lambda_name    = module.apps_lambda.lambda_name
      enable_api_key = false
    },
    {
      path_part      = "apps"
      http_method    = "DELETE"
      lambda_arn     = module.apps_lambda.lambda_arn
      lambda_name    = module.apps_lambda.lambda_name
      enable_api_key = false
    },
  ]

  usage_plan_config = {
    name         = "email-service-plan"
    burst_limit  = 100
    rate_limit   = 50
    quota_limit  = 10000
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

