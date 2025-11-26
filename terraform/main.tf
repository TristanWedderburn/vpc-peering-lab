terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

################
# Data sources #
################

data "aws_ami" "amazon_linux" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

#############
# VPC A     #
#############

resource "aws_vpc" "vpc_a" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "vpc-a" }
}

resource "aws_internet_gateway" "igw_a" {
  vpc_id = aws_vpc.vpc_a.id
  tags   = { Name = "igw-a" }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "public-a" }
}

resource "aws_route_table" "public_a" {
  vpc_id = aws_vpc.vpc_a.id
  tags   = { Name = "rtb-public-a" }
}

resource "aws_route_table_association" "public_a_assoc" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public_a.id
}

resource "aws_route" "public_a_internet" {
  route_table_id         = aws_route_table.public_a.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_a.id
}

#############
# VPC B     #
#############

resource "aws_vpc" "vpc_b" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "vpc-b" }
}

resource "aws_internet_gateway" "igw_b" {
  vpc_id = aws_vpc.vpc_b.id
  tags   = { Name = "igw-b" }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.vpc_b.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "public-b" }
}

resource "aws_route_table" "public_b" {
  vpc_id = aws_vpc.vpc_b.id
  tags   = { Name = "rtb-public-b" }
}

resource "aws_route_table_association" "public_b_assoc" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public_b.id
}

resource "aws_route" "public_b_internet" {
  route_table_id         = aws_route_table.public_b.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw_b.id
}

#########################
# Security groups       #
#########################

locals {
  my_ip_cidr = "${var.my_ip}/32"
}

resource "aws_security_group" "flask_a_sg" {
  name        = "flask-a-sg"
  description = "Allow SSH and Flask to instance A"
  vpc_id      = aws_vpc.vpc_a.id

  # SSH from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  # Flask HTTP from your IP and VPC B CIDR
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr, aws_vpc.vpc_b.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "flask-a-sg" }
}

resource "aws_security_group" "flask_b_sg" {
  name        = "flask-b-sg"
  description = "Allow SSH and Flask to instance B"
  vpc_id      = aws_vpc.vpc_b.id

  # SSH from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr]
  }

  # Flask HTTP from your IP and VPC A CIDR
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [local.my_ip_cidr, aws_vpc.vpc_a.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "flask-b-sg" }
}

#########################
# EC2 instances         #
#########################

resource "aws_instance" "flask_a" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_a.id
  vpc_security_group_ids = [aws_security_group.flask_a_sg.id]
  key_name               = var.key_name

  user_data = file("${path.module}/../app/user_data_flask_a.sh")

  tags = { Name = "flask-a" }
}

resource "aws_instance" "flask_b" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_b.id
  vpc_security_group_ids = [aws_security_group.flask_b_sg.id]
  key_name               = var.key_name

  user_data = file("${path.module}/../app/user_data_flask_b.sh")

  tags = { Name = "flask-b" }
}

#########################
# VPC Peering           #
#########################

resource "aws_vpc_peering_connection" "a_to_b" {
  vpc_id      = aws_vpc.vpc_a.id
  peer_vpc_id = aws_vpc.vpc_b.id
  auto_accept = true

  tags = {
    Name = "vpc-a-to-vpc-b"
  }
}

# Routes so each VPC knows how to reach the other via the peering link

resource "aws_route" "a_to_b_route" {
  route_table_id            = aws_route_table.public_a.id
  destination_cidr_block    = aws_vpc.vpc_b.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.a_to_b.id
}

resource "aws_route" "b_to_a_route" {
  route_table_id            = aws_route_table.public_b.id
  destination_cidr_block    = aws_vpc.vpc_a.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.a_to_b.id
}
