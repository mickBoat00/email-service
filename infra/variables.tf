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

variable "mongodb_uri" {
  type = string
}

variable "ecr_repository_uri" {
  type    = string
  default = "public.ecr.aws/c2n6x7m0/email-services"
}
