# Creates the secret container only. The VALUE is set with the AWS CLI so it never
# enters Terraform state or Git:
#   aws secretsmanager put-secret-value --secret-id zuri/<env>/backend --secret-string file://secret.json

variable "env" {
  type = string
}

resource "aws_secretsmanager_secret" "backend" {
  name                    = "zuri/${var.env}/backend"
  description             = "Backend secrets for Zuri Market (${var.env})"
  recovery_window_in_days = 0 # lets you destroy and recreate during the capstone
}

output "secret_arns" {
  value = [aws_secretsmanager_secret.backend.arn]
}

output "secret_name" {
  value = aws_secretsmanager_secret.backend.name
}
