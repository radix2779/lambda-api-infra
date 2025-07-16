variable "project_prefix" {}
variable "region" {}
variable "account_id" {}

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

  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "terraform/state"
  #   region         = "ap-south-1"
  #   dynamodb_table = "terraform-lock-table"
  # }
}

provider "aws" {
  region = "ap-south-1"
}


data "archive_file" "lambda_json" {
  type        = "zip"
  source_dir  = "${path.module}/src/lambda_json"
  output_path = "${path.module}/_build/lambda_json.zip"
}


module "lambdas" {
  source           = "./lambdas"
  lambda_filename  = data.archive_file.lambda_json.output_path
  lambda_json_hash = data.archive_file.lambda_json.output_base64sha256
  project_prefix   = var.project_prefix
}

module "api_gateway" {
  source                    = "./api_gateway"
  region                    = var.region
  account_id                = var.account_id
  lambda_json_invoke_arn    = module.lambdas.lambda_json_invoke_arn
  lambda_json_function_name = module.lambdas.lambda_json_function_name
  project_prefix            = var.project_prefix
}

