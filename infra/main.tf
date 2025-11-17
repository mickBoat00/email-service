module "image_processor_lambda" {
  source = "./modules/lambda"

  lambda_name          = "test-func"
  region               = var.region
  ecr_repository_name  = var.ecr_repository_name
  image_tag            = var.image_tag

  policy_statements = [
    {
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "*"
    }
  ]
}


module "api_gateway" {
  source = "./modules/apigateway"

  api_name     = "email-service-api"
  lambda_arn   = module.image_processor_lambda.lambda_arn
  lambda_name  = module.image_processor_lambda.lambda_name
  region       = var.region
  stage_name   = "dev"
}