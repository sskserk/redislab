terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">=0.14.9"
}

provider "aws" {
  region  = "us-east-2"
}

# common

variable "training_ami_id" {
  # Ubuntu Server 18.04 LTS (HVM), SSD Volume Type
  default = "ami-0a59f0e26c55590e9"
}

resource "aws_key_pair" "ssh_access_key" {
  key_name   = "id_rsa"
  public_key = file("${path.cwd}/id_rsa.pub")

  tags = {
    env = "redis_training"
  }
}

# VPC

resource "aws_vpc" "redis_training" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "Redis Training VPC"
    env  = "redis_training"
  }
}

resource "aws_subnet" "prod-subnet-public-0" {
  vpc_id                  = aws_vpc.redis_training.id
  cidr_block              = "10.0.0.0/20"
  map_public_ip_on_launch = "true" //it makes this a public subnet
  availability_zone       = "us-east-2a"

  tags = {
    Name = "subnet-0"
    env  = "redis_training"
  }
}

resource "aws_subnet" "prod-subnet-public-1" {
  vpc_id                  = aws_vpc.redis_training.id
  cidr_block              = "10.0.16.0/20"
  map_public_ip_on_launch = "true" //it makes this a public subnet
  availability_zone       = "us-east-2b"


  tags = {
    Name = "subnet-1"
    env  = "redis_training"
  }
}

resource "aws_subnet" "prod-subnet-public-2" {
  vpc_id                  = aws_vpc.redis_training.id
  cidr_block              = "10.0.32.0/20"
  map_public_ip_on_launch = "true" //it makes this a public subnet
  availability_zone       = "us-east-2c"


  tags = {
    Name = "subnet-2"
    env  = "redis_training"
  }
}

# Instances

resource "aws_instance" "node_0" {
  ami           = var.training_ami_id
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.prod-subnet-public-0.id
  # cpu_core_count = 2
  # cpu_threads_per_core = 1
  key_name               = aws_key_pair.ssh_access_key.key_name
  vpc_security_group_ids = [aws_default_security_group.default.id]

  tags = {
    Name = "node_0"
    env  = "redis_training"
  }
}

resource "aws_instance" "node_1" {
  ami           = var.training_ami_id
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.prod-subnet-public-1.id
  # cpu_core_count = 2
  # cpu_threads_per_core = 1
  key_name               = aws_key_pair.ssh_access_key.key_name
  vpc_security_group_ids = [aws_default_security_group.default.id]

  tags = {
    Name = "node_1"
    env  = "redis_training"
  }
}

resource "aws_instance" "node_2" {
  ami           = var.training_ami_id
  instance_type = "t2.medium"
  subnet_id     = aws_subnet.prod-subnet-public-2.id
  # cpu_core_count = 1
  # cpu_threads_per_core = 1
  key_name               = aws_key_pair.ssh_access_key.key_name
  vpc_security_group_ids = [aws_default_security_group.default.id]

  tags = {
    Name = "node_2"
    env  = "redis_training"
  }
}

# VPC / gateway + security group

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.redis_training.id

  tags = {
    Name = "redis_training-igw"
    env  = "redis_training"
  }
}

resource "aws_route" "route-public" {
  route_table_id         = aws_vpc.redis_training.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.redis_training.id

  tags = {
    Name = "Redis training security group"
    env  = "redis_training"
  }

  ingress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ELB + Target group

resource "aws_lb_target_group" "redis_nodes_tg" {
  name        = "redis-nodes-tg"
  target_type = "instance"
  port        = 12000
  protocol    = "TCP"
  vpc_id      = aws_vpc.redis_training.id

  health_check {
    port    = 12000
    enabled = true
    #  protocol = "TCP"
    healthy_threshold   = 3
    interval            = 30
    unhealthy_threshold = 3
    path                = ""
    matcher             = ""
    protocol            = "TCP"
  }

}

resource "aws_lb_target_group_attachment" "node0_member" {
  target_group_arn = aws_lb_target_group.redis_nodes_tg.arn
  target_id        = aws_instance.node_0.id
  port             = 12000
}

resource "aws_lb_target_group_attachment" "node1_member" {
  target_group_arn = aws_lb_target_group.redis_nodes_tg.arn
  target_id        = aws_instance.node_1.id
  port             = 12000
}

resource "aws_lb_target_group_attachment" "node2_member" {
  target_group_arn = aws_lb_target_group.redis_nodes_tg.arn
  target_id        = aws_instance.node_2.id
  port             = 12000
}

resource "aws_lb" "redis_db_public_lb" {
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.prod-subnet-public-0.id, aws_subnet.prod-subnet-public-1.id, aws_subnet.prod-subnet-public-2.id]
  tags = {
    Name = "Redis LB"
    env  = "redis_training"
  }
}

resource "aws_lb_listener" "redis_public_lb_listener" {
  load_balancer_arn = aws_lb.redis_db_public_lb.arn
  port              = 12000
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.redis_nodes_tg.arn
  }
}
