variable "lambda_name" {
  type = string
}

variable "region" {
  type = string
}

variable "memory_size" {
  type    = number
  default = 256
}

variable "timeout" {
  type    = number
  default = 10
}

variable "ecr_repository_name" {
  type = string
  default = "main"
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "policy_statements" {
  type = list(any)
  description = "List of IAM policy statements to attach to the Lambda role"
}

variable "environment_variables" {
  type    = map(string)
  default = {}
}

variable "account_id" {
  default = 305870070165
}