terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Deploy VPC
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "projectvpc"
  }
}

# Deploy Internet Gateway
resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "ig-project"
  }
}

# Deploy 2 Public Subnets
resource "aws_subnet" "public1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "1public"
  }
}

resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "2public"
  }
}

# Deploy 2 Private Subnets
resource "aws_subnet" "private1" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false

  tags = {
    Name = "1private"
  }
}

resource "aws_subnet" "private2" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = false

  tags = {
    Name = "2private"
  }
}

# Deploy Route Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }
  tags = {
    Name = "routetable"
  }
}

# Associate Subnets With Route Table
resource "aws_route_table_association" "route1" {
  subnet_id      = aws_subnet.public1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "route2" {
  subnet_id      = aws_subnet.public2.id
  route_table_id = aws_route_table.rt.id
}

# Deploy Security Groups
resource "aws_security_group" "publicsg" {
  name        = "publicsg"
  description = "Allow traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

resource "aws_security_group" "privatesg" {
  name        = "privatesg"
  description = "Allow traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    cidr_blocks     = ["10.0.0.0/16"]
    security_groups = [aws_security_group.publicsg.id]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]

  }
}

# Deploy ALB Security Group
resource "aws_security_group" "albsg" {
  name        = "albsg"
  description = "ALB Security Group"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Deploy Application Load Balancer
resource "aws_lb" "alb" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.albsg.id]
  subnets            = [aws_subnet.public1.id, aws_subnet.public2.id]
}

# Create ALB Target Group
resource "aws_lb_target_group" "albtg" {
  name     = "albtg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

  depends_on = [aws_vpc.vpc]
}

# Deploy LB Target Attachments
resource "aws_lb_target_group_attachment" "tgattach1" {
  target_group_arn = aws_lb_target_group.albtg.arn
  target_id        = aws_instance.instance1.id
  port             = 80

  depends_on = [aws_instance.instance1]
}

resource "aws_lb_target_group_attachment" "tg_attach2" {
  target_group_arn = aws_lb_target_group.albtg.arn
  target_id        = aws_instance.instance2.id
  port             = 80

  depends_on = [aws_instance.instance2]
}

# Deploy LB Listener
resource "aws_lb_listener" "lblisten" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.albtg.arn
  }
}

# Deploy EC2 Instances
resource "aws_instance" "instance1" {
  ami                         = "ami-0b0dcb5067f052a63"
  instance_type               = "t2.micro"
  key_name                    = "KeyPair"
  availability_zone           = "us-east-1a"
  vpc_security_group_ids      = [aws_security_group.publicsg.id]
  subnet_id                   = aws_subnet.public1.id
  associate_public_ip_address = true
  user_data                   = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h1>First instance successfully deployed</h1></body></html>" > /var/www/html/index.html
        EOF

  tags = {
    Name = "ec2instance1"
  }
}
resource "aws_instance" "instance2" {
  ami                         = "ami-0b0dcb5067f052a63"
  instance_type               = "t2.micro"
  key_name                    = "KeyPair"
  availability_zone           = "us-east-1b"
  vpc_security_group_ids      = [aws_security_group.publicsg.id]
  subnet_id                   = aws_subnet.public2.id
  associate_public_ip_address = true
  user_data                   = <<-EOF
        #!/bin/bash
        yum update -y
        yum install httpd -y
        systemctl start httpd
        systemctl enable httpd
        echo "<html><body><h1>Second instance successfully deployed</h1></body></html>" > /var/www/html/index.html
        EOF

  tags = {
    Name = "ec2instance2"
  }
}

# Relational Database Service Subnet Group
resource "aws_db_subnet_group" "dbsubnet" {
  name       = "dbsubnet"
  subnet_ids = [aws_subnet.private1.id, aws_subnet.private2.id]
}

# Create RDS Instance
resource "aws_db_instance" "dbinstance" {
  allocated_storage      = 5
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  identifier             = "dbinstance"
  db_name                = "db"
  username               = "admin"
  password               = "password"
  db_subnet_group_name   = aws_db_subnet_group.dbsubnet.id
  vpc_security_group_ids = [aws_security_group.privatesg.id]
  skip_final_snapshot    = true
}
