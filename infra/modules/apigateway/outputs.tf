output "api_id" {
  value       = aws_api_gateway_rest_api.this.id
  description = "API Gateway ID"
}

output "api_execution_arn" {
  value       = aws_api_gateway_rest_api.this.execution_arn
  description = "API Gateway execution ARN"
}

output "invoke_url" {
  value       = aws_api_gateway_stage.this.invoke_url
  description = "API Gateway invoke URL"
}

output "usage_plan_id" {
  value       = aws_api_gateway_usage_plan.main.id
  description = "Usage plan ID for attaching API keys"
}