terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

module "network" {
  source = "../../modules/network"
}

module "security" {
  source = "../../modules/security"
  vpc_id = module.network.vpc_id
}

module "secrets" {
  source = "../../modules/secrets"
}

output "secret_name" {
  value = module.secrets.secret_name
}

module "compute" {
  source             = "../../modules/compute"
  subnet_id          = module.network.public_subnet_id
  security_group_id  = module.security.security_group_id
  key_name           = var.key_name
}

variable "key_name" {
  description = "Name of an existing EC2 key pair"
  type        = string
}

output "public_ip" {
  value = module.compute.public_ip
}