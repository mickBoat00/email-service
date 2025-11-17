resource "aws_api_gateway_rest_api" "this" {
    name = var.api_name
    description = "API for email service"
    endpoint_configuration {
        types = ["REGIONAL"]
    }
}

resource "aws_api_gateway_resource" "identity" {
    rest_api_id = aws_api_gateway_rest_api.this.id
    parent_id = aws_api_gateway_rest_api.this.root_resource_id
    path_part = "identity"
}

resource "aws_api_gateway_method" "post_identity" {
    rest_api_id = aws_api_gateway_rest_api.this.id
    resource_id = aws_api_gateway_resource.identity.id
    http_method = "POST"
    authorization = "NONE"
}

resource "aws_api_gateway_integration" "post_identity_integration" {
    rest_api_id = aws_api_gateway_rest_api.this.id
    resource_id = aws_api_gateway_resource.identity.id
    http_method = aws_api_gateway_method.post_identity.http_method
    type = "AWS_PROXY"
    integration_http_method = "POST"
    uri = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_arn}/invocations"
}

resource "aws_lambda_permission" "api_invoke" {
    statement_id = "AllowAPIGatewayInvoke-${var.lambda_name}"
    action = "lambda:InvokeFunction"
    function_name = var.lambda_arn
    principal = "apigateway.amazonaws.com"
    source_arn = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "this" {
    depends_on = [aws_api_gateway_integration.post_identity_integration]
    
    rest_api_id = aws_api_gateway_rest_api.this.id
}


resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = "dev"
}
