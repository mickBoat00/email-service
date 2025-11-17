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

variable "mongodb_uri" {
  type = string
}

variable "ecr_repository_uri" {
  type    = string
  default = "public.ecr.aws/c2n6x7m0/email-services"
}

variable "identity_image_tag" {
  type = string
}

variable "email_image_tag" {
  type = string
}

variable "ecr_registry" {
  type = string
  default = "public.ecr.aws/c2n6x7m0"
}