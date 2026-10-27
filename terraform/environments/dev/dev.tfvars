region              = "eu-west-1"
env                 = "dev"
vpc_cidr            = "10.0.0.0/16" # kept from the first apply so the VPC is not recreated
public_subnet_cidr  = "10.0.1.0/24"
private_subnet_cidr = "10.0.2.0/24"
instance_type       = "t3.medium"
allowed_http_cidrs  = ["0.0.0.0/0"]
