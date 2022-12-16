terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}
provider "aws" {
  region = "us-west-1"
}
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "myvpc"
  }
}
resource "aws_subnet" "pub" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-1b"

  tags = {
    Name = "PUBSUB"
  }
}
resource "aws_subnet" "pri" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-west-1b"
  tags = {
    Name = "PRISUB"
  }
}
resource "aws_internet_gateway" "intgw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "MYINTGW"
  }
}
resource "aws_route_table" "pubrout" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.intgw.id
  }
  tags = {
    Name = "PUBLICROUTETABLE"
  }
}
resource "aws_route_table_association" "rouasso" {
  subnet_id      = aws_subnet.pub.id
  route_table_id = aws_route_table.pubrout.id
}
resource "aws_security_group" "pubsecurity" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 0
    to_port          = 65535
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    }

  tags = {
    Name = "MYsecurityPublic"
  }
}
resource "aws_security_group" "prisecurity" {
  name        = "allow_pri"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "TLS from VPC"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    security_groups = ["${aws_security_group.pubsecurity.id}"]

  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    }

  tags = {
    Name = "MYsecurityPublic"
  }
}

resource "aws_instance" "instpub" {
  ami = "ami-0f5e8a042c8bfcd5e"
  instance_type = "t2.micro"
  key_name = "calikey"
  vpc_security_group_ids = ["${aws_security_group.pubsecurity.id}"]
  subnet_id =  aws_subnet.pub.id
  associate_public_ip_address = true

  tags = {
    Name = "PUBLICINSTANCE"
  }
}

resource "aws_eip" "myeip" {
  #instance = aws_instance.instpub.id
  vpc      = true
}
resource "aws_nat_gateway" "mynat" {
  allocation_id = aws_eip.myeip.id
  subnet_id     = aws_subnet.pub.id

  tags = {
    Name = "MYNATGW"
  }
}
resource "aws_route_table" "prirout" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.mynat.id
  }
  tags = {
    Name = "PRIVATEROUTETABLE"
  }
}
resource "aws_route_table_association" "priasso" {
  subnet_id      = aws_subnet.pri.id
  route_table_id = aws_route_table.prirout.id
}
resource "aws_instance" "instpri" {
  ami = "ami-0f5e8a042c8bfcd5e"
  instance_type = "t2.micro"
  key_name = "calikey"
  vpc_security_group_ids = ["${aws_security_group.prisecurity.id}"]
  subnet_id =  aws_subnet.pri.id
  associate_public_ip_address = true

  tags = {
    Name = "PRIVATEINSTANCE"
  }
} 
