# Remote-state bucket for every other stack. Run ONCE by hand with local state:
# the bucket that stores state cannot be created by code that stores its state in it.
#
#   cd terraform/bootstrap
#   terraform init
#   terraform apply -var="region=eu-west-1" -var="bucket_name=zuri-market-tfstate-<ACCOUNT_ID>"

terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = { Project = "zuri-market", ManagedBy = "terraform" }
  }
}

variable "region" {
  type = string
}

variable "bucket_name" {
  description = "Globally unique name for the state bucket"
  type        = string
}

resource "aws_s3_bucket" "state" {
  bucket = var.bucket_name

  lifecycle {
    prevent_destroy = true # losing this bucket means losing track of every resource
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket_name" {
  value = aws_s3_bucket.state.bucket
}
