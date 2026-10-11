# One-time setup: the S3 bucket that stores Terraform state for everything else.
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  # The bucket below stores its own state. First apply ran with local state; once the
  # bucket existed the state moved here, so no laptop holds the only copy.
  backend "s3" {
    bucket       = "tfstate-070443470685-eu-north-1"
    key          = "bootstrap/terraform.tfstate"
    region       = "eu-north-1"
    profile      = "aws-learning"
    use_lockfile = true
  }
}

provider "aws" {
  region  = "eu-north-1"
  profile = "aws-learning"
  default_tags { tags = { project = "aws-learning", managed_by = "terraform" } }
}

data "aws_caller_identity" "me" {}

resource "aws_s3_bucket" "tfstate" {
  bucket = "tfstate-${data.aws_caller_identity.me.account_id}-eu-north-1"
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Referencing the versioning resource makes Terraform create this after versioning is on.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket_versioning.tfstate.bucket

  rule {
    id     = "expire-old-state"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
}

output "state_bucket" { value = aws_s3_bucket.tfstate.bucket }
