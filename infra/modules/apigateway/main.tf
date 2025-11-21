# API Gateway REST API
resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = "API Gateway for ${var.api_name}"
  
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Create resources for each route
resource "aws_api_gateway_resource" "routes" {
  count = length(var.routes)

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = var.routes[count.index].path_part
}

# Create methods for each route
resource "aws_api_gateway_method" "routes" {
  count = length(var.routes)

  rest_api_id      = aws_api_gateway_rest_api.this.id
  resource_id      = aws_api_gateway_resource.routes[count.index].id
  http_method      = var.routes[count.index].http_method
  authorization    = "NONE"
  api_key_required = var.routes[count.index].enable_api_key
}

# Create integrations for each route
resource "aws_api_gateway_integration" "routes" {
  count = length(var.routes)

  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.routes[count.index].id
  http_method             = aws_api_gateway_method.routes[count.index].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.routes[count.index].lambda_arn}/invocations"
}

locals {
  unique_lambdas = distinct([
    for r in var.routes : r.lambda_name
  ])
  
  lambda_map = {
    for r in var.routes : r.lambda_name => r.lambda_arn...
  }
  
  # Get the first ARN for each unique lambda name
  lambda_permissions = {
    for name in local.unique_lambdas : name => [
      for r in var.routes : r.lambda_arn if r.lambda_name == name
    ][0]
  }
}

# One permission per unique Lambda function
resource "aws_lambda_permission" "api_invoke" {
  for_each = local.lambda_permissions

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.routes,
      aws_api_gateway_method.routes,
      aws_api_gateway_integration.routes,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.routes
  ]
}

# API Gateway Stage
resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.stage_name
}

# Usage Plan (for rate limiting)
resource "aws_api_gateway_usage_plan" "main" {
  name        = var.usage_plan_config.name
  description = "Usage plan for ${var.api_name}"

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.this.stage_name
  }

  throttle_settings {
    burst_limit = var.usage_plan_config.burst_limit
    rate_limit  = var.usage_plan_config.rate_limit
  }

  quota_settings {
    limit  = var.usage_plan_config.quota_limit
    period = var.usage_plan_config.quota_period
  }
}