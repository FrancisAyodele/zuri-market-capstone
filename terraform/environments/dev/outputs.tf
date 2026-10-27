output "instance_id" {
  value = module.compute.instance_id
}

output "public_ip" {
  value = module.compute.public_ip
}

output "secret_name" {
  value = module.secrets.secret_name
}
