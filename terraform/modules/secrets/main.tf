resource "aws_secretsmanager_secret" "backend" {
  name        = "zuri/dev/backend"
  description = "Backend secrets for Zuri Market (dev)"
}

output "secret_arn" {
  value = aws_secretsmanager_secret.backend.arn
}

output "secret_name" {
  value = aws_secretsmanager_secret.backend.name
}