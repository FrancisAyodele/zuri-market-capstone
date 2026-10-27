terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }

  # Remote state: shared by your laptop and the CD pipeline, versioned, encrypted, locked.
  # The bucket comes from terraform/bootstrap. Change the name if yours differs.
  backend "s3" {
    bucket       = "zuri-market-tfstate-885446904056"
    key          = "dev/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true # S3 native locking, no DynamoDB table needed
  }
}
