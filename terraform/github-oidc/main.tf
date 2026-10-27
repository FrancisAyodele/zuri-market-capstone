# terraform/github-oidc/main.tf
# Run ONCE by hand (local state), like terraform/bootstrap.
# Lets GitHub Actions get short-lived AWS credentials via OIDC, so no AWS access keys
# are ever stored in GitHub.

terraform {
  required_version = ">= 1.11"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

provider "aws" { region = var.region }

variable "region" { type = string }

variable "github_repo" {
  type    = string
  default = "FrancisAyodele/zuri-market-capstone"
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

# One per AWS account. If it already exists, import it:
# terraform import aws_iam_openid_connect_provider.github \
#   arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# Only THIS repo, and only the main branch (plan) or the "dev" environment (apply/deploy),
# can assume the role. Pull requests and forks cannot.
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_repo}:ref:refs/heads/main",
        "repo:${var.github_repo}:environment:dev",
      ]
    }
  }
}

resource "aws_iam_role" "github_deployer" {
  name                 = "zuri-github-deployer"
  assume_role_policy   = data.aws_iam_policy_document.trust.json
  max_session_duration = 3600
}

# Broad on purpose for the capstone: Terraform creates VPCs, EC2, security groups,
# Secrets Manager entries, and reads/writes state in S3. "Tighten to exact actions"
# is a good answer to "what would you do differently?".
resource "aws_iam_role_policy_attachment" "power_user" {
  role       = aws_iam_role.github_deployer.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

# PowerUserAccess excludes IAM. Allow IAM only on Zuri's own roles and instance profiles.
data "aws_iam_policy_document" "iam_scoped" {
  statement {
    actions = ["iam:*"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/zuri-*",
      "arn:aws:iam::${local.account_id}:instance-profile/zuri-*",
    ]
  }
}

resource "aws_iam_role_policy" "iam_scoped" {
  name   = "manage-zuri-iam-only"
  role   = aws_iam_role.github_deployer.id
  policy = data.aws_iam_policy_document.iam_scoped.json
}

output "role_arn" {
  value = aws_iam_role.github_deployer.arn
}
