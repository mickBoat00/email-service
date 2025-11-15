module "image_processor_lambda" {
  source = "./modules/lambda"

  lambda_name          = "test-func"
  region               = var.region
  ecr_repository_name  = var.ecr_repository_name
  image_tag            = var.image_tag

  policy_statements = [
    {
      Effect = "Allow"
      Action = ["s3:GetObject"]
      Resource = "*"
    },
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
