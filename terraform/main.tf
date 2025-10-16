provider "aws" {
  region = var.region
}

# ----------------------------
# VPC
# ----------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "petclinic-vpc"
  }
}

# ----------------------------
# Public Subnet
# ----------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]

  tags = {
    Name = "petclinic-public-subnet"
  }
}

data "aws_availability_zones" "available" {}

# ----------------------------
# Internet Gateway
# ----------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "petclinic-igw"
  }
}

# ----------------------------
# Route Table
# ----------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "petclinic-public-rt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ----------------------------
# Security Groups
# ----------------------------

# App SG
resource "aws_security_group" "app_sg" {
  name        = "app-sg"
  description = "App server SG"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP / Tomcat
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg"
  }
}

# MySQL SG
resource "aws_security_group" "mysql_sg" {
  name        = "mysql-sg"
  description = "MySQL SG"
  vpc_id      = aws_vpc.main.id

  # SSH for now
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MySQL access restricted from App SG (rule defined below)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mysql-sg"
  }
}

# Allow App SG to access MySQL SG on 3306
resource "aws_security_group_rule" "app_to_mysql" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.mysql_sg.id
  source_security_group_id = aws_security_group.app_sg.id
}

# ----------------------------
# EC2 Instances
# ----------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# App server
resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "petclinic-app-server"
    Env  = "dev"
  }
}

# MySQL server
resource "aws_instance" "mysql" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.mysql_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "petclinic-mysql-server"
    Env  = "dev"
  }
}
