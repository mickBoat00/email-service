variable "api_name" {
  type        = string
  description = "Name of the API Gateway"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "stage_name" {
  type        = string
  description = "API Gateway stage name"
  default     = "dev"
}

variable "routes" {
  type = list(object({
    path_part      = string
    http_methods   = list(string)  # Changed from http_method to http_methods (list)
    lambda_arn     = string
    lambda_name    = string
    enable_api_key = bool
  }))
  description = "List of routes to create. Each route can have multiple HTTP methods."
}

variable "usage_plan_config" {
  type = object({
    name         = string
    burst_limit  = number
    rate_limit   = number
    quota_limit  = number
    quota_period = string
  })
  description = "Usage plan configuration for rate limiting"
  default = {
    name         = "default-plan"
    burst_limit  = 100
    rate_limit   = 50
    quota_limit  = 10000
    quota_period = "DAY"
  }
}