# VPC（Virtual Private Cloud）
# AWS上に構築するプライベートな仮想ネットワーク
# ECS Fargateタスクをプライベートサブネットに配置し、ALBをパブリックサブネットに配置する
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true # VPC内でDNS解決を有効化（ECSがサービスディスカバリで使用）
  enable_dns_hostnames = true # VPC内のリソースにDNSホスト名を割り当て

  tags = {
    Name = "${var.environment}-${var.project_name}-vpc"
  }
}

#-------------------------------------------------------------------------------
# パブリックサブネット（ALB配置用）
# ALBは最低2つのAZ（Availability Zone）にまたがるサブネットが必要
#-------------------------------------------------------------------------------
resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true # このサブネット内のリソースにパブリックIPを自動割り当て

  tags = {
    Name = "${var.environment}-${var.project_name}-public-1a"
  }
}

resource "aws_subnet" "public_1c" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}c"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.environment}-${var.project_name}-public-1c"
  }
}

#-------------------------------------------------------------------------------
# プライベートサブネット（ECS Fargateタスク配置用）
# インターネットから直接アクセスできないサブネット
# 外部への通信はNAT Gateway経由で行う（ECRからのイメージ取得に必要）
#-------------------------------------------------------------------------------
resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.environment}-${var.project_name}-private-1a"
  }
}

resource "aws_subnet" "private_1c" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.aws_region}c"

  tags = {
    Name = "${var.environment}-${var.project_name}-private-1c"
  }
}

#-------------------------------------------------------------------------------
# Internet Gateway
# VPCとインターネットを接続するゲートウェイ
# パブリックサブネット内のリソース（ALB）がインターネットと通信するために必要
#-------------------------------------------------------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.environment}-${var.project_name}-igw"
  }
}

#-------------------------------------------------------------------------------
# NAT Gateway
# プライベートサブネットからインターネットへの一方向通信を実現
# ECS FargateタスクがECRからDockerイメージを取得するために必要
#
# 注意: NAT Gatewayは時間課金（約$0.062/h ≒ $45/月）が発生する
# 使わない時は terraform destroy を忘れずに
#-------------------------------------------------------------------------------

# NAT Gatewayに割り当てるElastic IP
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.environment}-${var.project_name}-nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway本体（パブリックサブネットに配置）
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1a.id # パブリックサブネットに配置（インターネットへの出口となるため）

  tags = {
    Name = "${var.environment}-${var.project_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

#-------------------------------------------------------------------------------
# ルートテーブル
# サブネット内のトラフィックのルーティング先を定義
#-------------------------------------------------------------------------------

# パブリックサブネット用ルートテーブル
# 全てのトラフィック（0.0.0.0/0）をInternet Gatewayに向ける
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

# プライベートサブネット用ルートテーブル
# 全てのトラフィック（0.0.0.0/0）をNAT Gatewayに向ける
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

# ルートテーブルとサブネットの関連付け
# サブネットにルートテーブルを紐付けることで、そのサブネット内のルーティングが決定する
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
