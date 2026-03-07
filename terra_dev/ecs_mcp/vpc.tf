# VPC（Virtual Private Cloud）
# このサンプル専用のネットワークを 1 つ切る。
# ALB はパブリックサブネット、ECS Fargate タスクはプライベートサブネットに置く。
resource "aws_vpc" "main" {
  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.environment}-${var.project_name}-vpc"
  }
}

#-------------------------------------------------------------------------------
# パブリックサブネット
# ALB はインターネット向けなので、2AZ にまたがるパブリックサブネットへ配置する。
#-------------------------------------------------------------------------------
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.30.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-${var.project_name}-public-1a"
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.30.2.0/24"
  availability_zone       = "${var.aws_region}c"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-${var.project_name}-public-1c"
  }
}

#-------------------------------------------------------------------------------
# プライベートサブネット
# Fargate タスクは直接インターネットに晒さず、ALB 経由だけで到達できるようにする。
#-------------------------------------------------------------------------------
resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.30.10.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.environment}-${var.project_name}-private-1a"
  }
}

resource "aws_subnet" "private_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.30.11.0/24"
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "${var.environment}-${var.project_name}-private-1c"
  }
}

#-------------------------------------------------------------------------------
# Internet Gateway
# パブリックサブネットからインターネットに出るためのゲートウェイ。
#-------------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-${var.project_name}-igw"
  }
}

#-------------------------------------------------------------------------------
# NAT Gateway
# プライベートサブネット上の Fargate タスクが ECR / CloudWatch Logs へ出るために使う。
# 学習用として分かりやすさを優先し、VPC Endpoint ではなく NAT Gateway を採用する。
#-------------------------------------------------------------------------------
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.environment}-${var.project_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1a.id

  tags = {
    Name = "${var.environment}-${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

#-------------------------------------------------------------------------------
# ルートテーブル
#-------------------------------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.environment}-${var.project_name}-private-rt"
  }
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1c" {
  subnet_id      = aws_subnet.public_1c.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_1a" {
  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_1c" {
  subnet_id      = aws_subnet.private_1c.id
  route_table_id = aws_route_table.private.id
}
