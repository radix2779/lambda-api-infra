variable "project_prefix" {}
variable "region" {}
variable "account_id" {}
variable "source_dir" {}
variable "output_path" {}
variable "api_path" {}

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# provider "aws" {
#   region = var.region
# }


data "archive_file" "lambda_function_zip" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = var.output_path
}


module "lambdas" {
  source           = "./lambdas"
  lambda_filename  = data.archive_file.lambda_function_zip.output_path
  lambda_json_hash = data.archive_file.lambda_function_zip.output_base64sha256
  project_prefix   = var.project_prefix
}

module "api_gateway" {
  source                    = "./api_gateway"
  region                    = var.region
  account_id                = var.account_id
  lambda_json_invoke_arn    = module.lambdas.lambda_json_invoke_arn
  lambda_json_function_name = module.lambdas.lambda_json_function_name
  project_prefix            = var.project_prefix
  api_path                  = var.api_path
}

