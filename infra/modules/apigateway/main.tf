##############################
# REST API
##############################

resource "aws_api_gateway_rest_api" "this" {
  name        = var.api_name
  description = "API Gateway for ${var.api_name}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  api_key_source = "HEADER"
}

##############################
# BUILD METHOD MAP
##############################

locals {
  # Expand each route into individual method objects
  route_methods = flatten([
    for r in var.routes : [
      for m in r.http_methods : {
        path_part      = r.path_part
        method         = m
        lambda_arn     = r.lambda_arn
        lambda_name    = r.lambda_name
        enable_api_key = r.enable_api_key
      }
    ]
  ])

  # Map for_each → "apps-GET" = { method="GET", ... }
  route_methods_map = {
    for rm in local.route_methods :
    "${rm.path_part}-${rm.method}" => rm
  }

  # Unique Lambdas → permission for each one
  unique_lambdas = {
    for r in var.routes : r.lambda_name => r.lambda_arn...
  }
  
  # Flatten the grouped values (take first ARN for each unique lambda)
  lambda_permissions = {
    for name, arns in local.unique_lambdas : name => arns[0]
  }

}

##############################
# RESOURCES
##############################

resource "aws_api_gateway_resource" "routes" {
  for_each = { for r in var.routes : r.path_part => r }

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.key
}

##############################
# METHODS
##############################

resource "aws_api_gateway_method" "methods" {
  for_each = local.route_methods_map

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.routes[each.value.path_part].id
  http_method   = each.value.method
  authorization = "NONE"
  api_key_required = each.value.enable_api_key
}

##############################
# INTEGRATIONS
##############################

resource "aws_api_gateway_integration" "integrations" {
  for_each = local.route_methods_map

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.routes[each.value.path_part].id
  http_method = aws_api_gateway_method.methods[each.key].http_method 
  type        = "AWS_PROXY"

  integration_http_method = "POST"

  uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${each.value.lambda_arn}/invocations"
  
  depends_on = [
    aws_api_gateway_method.methods
  ]
}

##############################
# LAMBDA PERMISSIONS
##############################

resource "aws_lambda_permission" "api_invoke" {
  for_each = local.lambda_permissions

  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = each.value
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

##############################
# DEPLOYMENT
##############################

resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Redeploy when methods or integrations change
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.methods,
      aws_api_gateway_integration.integrations
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.integrations
  ]
}

##############################
# STAGE
##############################

resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.stage_name
}

##############################
# USAGE PLAN
##############################

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
