terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = "ap-east-1"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "app-vpc"
  cidr = "10.32.0.0/16"

  azs             = ["ap-east-1a", "ap-east-1b"]
  private_subnets = ["10.32.10.0/24", "10.32.11.0/24"]
  public_subnets  = ["10.32.20.0/24", "10.32.21.0/24"]

  private_subnet_tags = {
     alb_subnet = "private"
  }

  public_subnet_tags = {
     alb_subnet = "public"
  }

  enable_nat_gateway = false
  enable_vpn_gateway = false

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
module "web_server_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  name        = "web-srv"
  description = "Security group open ports 22,80,443 "
  vpc_id      = module.vpc.vpc_id
  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp","http-80-tcp","ssh-tcp"]
}

module "ec2_front" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "web-frontend-srv"

  ami                    = "ami-09800b995a7e41703"
  instance_type          = "t3.micro"
  key_name               = "Front2"
  monitoring             = true
  vpc_security_group_ids = [module.web_server_sg.security_group_id]
  subnet_id              = element(module.vpc.public_subnets, 0)

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
module "ec2_backend" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = "web-backend-srv"

  ami                    = "ami-09800b995a7e41703"
  instance_type          = "t3.micro"
  key_name               = "Front2"
  monitoring             = true
  vpc_security_group_ids = [module.web_server_sg.security_group_id]
  subnet_id              = element(module.vpc.private_subnets, 0)

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}
output "ec2_front" {
  value = {
    private_ip = module.ec2_front.private_ip
  }
}
