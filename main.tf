terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region  = "us-east-2"
  profile = "cloudx"
}


locals {
  availability_zone = "${local.region}a"
  name              = "dm-cache-test"
  region            = "us-east-2"

  user_data = <<-EOT
  #!/bin/bash
  dnf -y upgrade
  EOT

  tags = {
    Name         = "dm-cache-test"
    ServiceOwner = "mhayden"
    ServicePhase = "Dev"
  }
}

data "aws_vpc" "default" {
  #id = "vpc-025bae7ee75e780a5"
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "fedora" {
  most_recent = true
  owners      = ["125523088429"]

  filter {
    name   = "name"
    values = ["Fedora-Cloud-Base-37-*.x86_64-hvm-*-gp2-*"]
  }
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = local.name
  description = "Major home temporary security group"
  vpc_id      = data.aws_vpc.default.id

  ingress_cidr_blocks = ["173.174.128.67/32"]
  ingress_rules       = ["all-tcp", "all-icmp"]
  egress_rules        = ["all-all"]

  tags = local.tags
}

module "ec2_instance" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 3.0"

  name = local.name

  ami                         = data.aws_ami.fedora.id
  instance_type               = "c5d.large"
  availability_zone           = local.availability_zone
  key_name                    = "mhayden"
  vpc_security_group_ids      = [module.security_group.security_group_id]
  associate_public_ip_address = true

  tags = local.tags
}

resource "aws_volume_attachment" "slow_disk" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.slow_disk.id
  instance_id = module.ec2_instance.id
}

resource "aws_ebs_volume" "slow_disk" {
  availability_zone = local.availability_zone
  size              = 100
  type              = "standard"

  tags = local.tags
}
