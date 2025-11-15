resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.lambda_name}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.lambda_name}-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = var.policy_statements
  })
}

data "aws_ecr_image" "lambda_image" {
  repository_name = var.ecr_repository_name
  image_tag       = var.image_tag
}

resource "aws_lambda_function" "lambda_function" {
  function_name = var.lambda_name
  role          = aws_iam_role.lambda_exec_role.arn

  package_type = "Image"

  image_uri = "${data.aws_ecr_image.lambda_image.registry_id}.dkr.ecr.${var.region}.amazonaws.com/${var.ecr_repository_name}@${data.aws_ecr_image.lambda_image.image_digest}"

  memory_size = var.memory_size
  timeout     = var.timeout
}
