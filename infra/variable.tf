variable "region" {
  type = string
  default = "eu-west-2"
}

variable "account_id" {
    type = string
    default = "305870070165"
}

variable "ecr_repository_name" {
  type = string
  default = "main"
}

variable "image_tag" {
  type    = string
  default = "latest"
}
