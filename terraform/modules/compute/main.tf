# One EC2 node running k3s. No key pair: reach it with
#   aws ssm start-session --target "$(terraform output -raw instance_id)"

variable "name" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "instance_profile" {
  type = string
}

variable "region" {
  type = string
}

variable "root_volume_size" {
  type    = number
  default = 30
}

# Latest Amazon Linux 2023: SSM agent and AWS CLI are preinstalled.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_instance" "main" {
  ami                         = nonsensitive(data.aws_ssm_parameter.al2023.value)
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.security_group_id]
  iam_instance_profile        = var.instance_profile
  associate_public_ip_address = true

  user_data                   = templatefile("${path.module}/user_data.sh.tftpl", { region = var.region })
  user_data_replace_on_change = true # a changed bootstrap script means a fresh, reproducible node

  metadata_options {
    http_tokens                 = "required" # IMDSv2 only
    http_put_response_hop_limit = 2
  }

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
    encrypted   = true
  }

  tags = { Name = "${var.name}-node" }

  lifecycle {
    # A new AL2023 image is published every few weeks. Without this, every CD run after a
    # release would plan to replace the node. Roll the AMI deliberately instead
    # (terraform apply -replace=module.compute.aws_instance.main).
    ignore_changes = [ami]
  }
}

output "instance_id" {
  value = aws_instance.main.id
}

output "public_ip" {
  value = aws_instance.main.public_ip
}
