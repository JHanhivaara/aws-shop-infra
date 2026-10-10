# The application stack. CI runs this; locally use: $env:AWS_PROFILE="aws-learning"
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  backend "s3" {
    bucket       = "tfstate-070443470685-eu-north-1"
    key          = "infra/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-north-1"
  default_tags { tags = { project = "aws-shop", managed_by = "terraform" } }
}

# Placeholder until the API exists: the Lambda will log here.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/aws/lambda/shop-api"
  retention_in_days = 7
}
