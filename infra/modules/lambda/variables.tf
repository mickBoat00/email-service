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
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "policy_statements" {
  type = list(any)
  description = "List of IAM policy statements to attach to the Lambda role"
}
