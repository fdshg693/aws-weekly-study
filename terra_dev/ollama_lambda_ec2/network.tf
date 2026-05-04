# Network and security
# --------------------
# この構成では、通信をかなり限定しています。最終的に許可される通信は次のとおりです。
#
# 1. Lambda -> EC2
#    - TCP ${var.ollama_port} 番のみ許可
#    - Lambda から EC2 上の Ollama API を呼び出すための通信です
#
# 2. Lambda -> Secrets Manager 用 Interface VPC Endpoint
#    - TCP 443 番のみ許可
#    - Lambda が VPC 内から Secrets Manager を private DNS 経由で利用するための通信です
#
# 3. Lambda -> SQS 用 Interface VPC Endpoint
#    - TCP 443 番のみ許可
#    - API Lambda が非同期リクエストを FIFO キューに投入するための通信です
#
# 4. Lambda -> DynamoDB Gateway Endpoint
#    - TCP 443 番のみ許可
#    - API Lambda と Worker Lambda がリクエスト状態を DynamoDB に保存するための通信です
#
# 5. Lambda -> VPC DNS Resolver
#    - TCP/UDP 53 番のみ許可
#    - private DNS 名の名前解決に必要な DNS 通信です
#
# 6. EC2 -> インターネット
#    - TCP 443/80 番のみ許可
#    - パッケージ取得、モデルダウンロード、SSM 関連通信などのための外向き通信です
#
# 7. EC2 -> VPC DNS Resolver
#    - TCP/UDP 53 番のみ許可
#    - 名前解決に必要な DNS 通信です
#
# 8. Lambda -> Interface VPC Endpoint の通信は、送信側と受信側の両方で明示
#    - Lambda 側では TCP 443 番への送信のみ許可
#    - Endpoint 側では Lambda からの TCP 443 番の受信のみ許可
#    - これは Lambda 用 SG と Endpoint 用 SG が別であり、同じ通信を
#      「送信元の許可」と「宛先の受信許可」の両方で定義しているためです
#
# 逆にいうと、上記以外の通信はこのファイルの Security Group ルールでは許可していません。
# また、NAT Gateway は使わず、Secrets Manager へのアクセスは Interface VPC Endpoint を使って
# VPC 内で閉じる構成にしています。

resource "aws_security_group" "ec2" {
  name        = "${local.name_prefix}-ec2-sg"
  description = "Security group for the EC2-hosted Ollama server"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${local.name_prefix}-ec2-sg"
  }
}

resource "aws_security_group" "lambda" {
  name        = "${local.name_prefix}-lambda-sg"
  description = "Security group for the Lambda function inside the default VPC"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${local.name_prefix}-lambda-sg"
  }
}

resource "aws_security_group" "vpce_secrets_manager" {
  name        = "${local.name_prefix}-secrets-vpce-sg"
  description = "Security group attached to the Secrets Manager interface VPC endpoint"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${local.name_prefix}-secrets-vpce-sg"
  }
}

resource "aws_security_group" "vpce_sqs" {
  name        = "${local.name_prefix}-sqs-vpce-sg"
  description = "Security group attached to the SQS interface VPC endpoint"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${local.name_prefix}-sqs-vpce-sg"
  }
}

# EC2 inbound: only the Lambda security group may reach Ollama on 11434/tcp.
resource "aws_vpc_security_group_ingress_rule" "ec2_from_lambda_ollama" {
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = aws_security_group.lambda.id
  from_port                    = var.ollama_port
  to_port                      = var.ollama_port
  ip_protocol                  = "tcp"
  description                  = "Allow Lambda to call the Ollama API on EC2"
}

# EC2 outbound: HTTP/HTTPS package and model downloads plus DNS queries to the VPC resolver.
resource "aws_vpc_security_group_egress_rule" "ec2_https_outbound" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow HTTPS egress for package installs, model downloads, and SSM"
}

resource "aws_vpc_security_group_egress_rule" "ec2_http_outbound" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Allow HTTP egress for package repositories that still redirect via port 80"
}

resource "aws_vpc_security_group_egress_rule" "ec2_dns_udp_outbound" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = "${local.vpc_dns_resolver_ip}/32"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  description       = "Allow DNS queries to the VPC resolver"
}

resource "aws_vpc_security_group_egress_rule" "ec2_dns_tcp_outbound" {
  security_group_id = aws_security_group.ec2.id
  cidr_ipv4         = "${local.vpc_dns_resolver_ip}/32"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  description       = "Allow TCP-based DNS queries to the VPC resolver"
}

# Lambda outbound: only the paths it actually needs.
# 1) Ollama on EC2 over port 11434.
# 2) Secrets Manager interface endpoint over port 443.
# 3) DNS to the VPC resolver so private DNS names can resolve.
resource "aws_vpc_security_group_egress_rule" "lambda_to_ec2_ollama" {
  security_group_id            = aws_security_group.lambda.id
  referenced_security_group_id = aws_security_group.ec2.id
  from_port                    = var.ollama_port
  to_port                      = var.ollama_port
  ip_protocol                  = "tcp"
  description                  = "Allow Lambda to reach the Ollama API on EC2"
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_secrets_vpce_https" {
  security_group_id            = aws_security_group.lambda.id
  referenced_security_group_id = aws_security_group.vpce_secrets_manager.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow Lambda to reach Secrets Manager through the interface VPC endpoint"
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_sqs_vpce_https" {
  security_group_id            = aws_security_group.lambda.id
  referenced_security_group_id = aws_security_group.vpce_sqs.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow Lambda to reach SQS through the interface VPC endpoint"
}

resource "aws_vpc_security_group_egress_rule" "lambda_to_dynamodb_https" {
  security_group_id = aws_security_group.lambda.id
  prefix_list_id    = data.aws_prefix_list.dynamodb.id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow Lambda to reach DynamoDB through the gateway VPC endpoint"
}

resource "aws_vpc_security_group_egress_rule" "lambda_dns_udp_outbound" {
  security_group_id = aws_security_group.lambda.id
  cidr_ipv4         = "${local.vpc_dns_resolver_ip}/32"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  description       = "Allow DNS queries to the VPC resolver"
}

resource "aws_vpc_security_group_egress_rule" "lambda_dns_tcp_outbound" {
  security_group_id = aws_security_group.lambda.id
  cidr_ipv4         = "${local.vpc_dns_resolver_ip}/32"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  description       = "Allow TCP-based DNS queries to the VPC resolver"
}

resource "aws_vpc_security_group_ingress_rule" "vpce_from_lambda_https" {
  security_group_id            = aws_security_group.vpce_secrets_manager.id
  referenced_security_group_id = aws_security_group.lambda.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow the VPC Lambda function to call the endpoint privately"
}

resource "aws_vpc_security_group_ingress_rule" "vpce_sqs_from_lambda_https" {
  security_group_id            = aws_security_group.vpce_sqs.id
  referenced_security_group_id = aws_security_group.lambda.id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow the VPC Lambda function to call SQS privately"
}

resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.default_subnet_ids
  security_group_ids  = [aws_security_group.vpce_secrets_manager.id]
  private_dns_enabled = true

  tags = {
    Name = "${local.name_prefix}-secretsmanager-vpce"
  }
}

resource "aws_vpc_endpoint" "sqs" {
  vpc_id              = data.aws_vpc.default.id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.default_subnet_ids
  security_group_ids  = [aws_security_group.vpce_sqs.id]
  private_dns_enabled = true

  tags = {
    Name = "${local.name_prefix}-sqs-vpce"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = data.aws_vpc.default.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = data.aws_route_tables.default_vpc.ids

  tags = {
    Name = "${local.name_prefix}-dynamodb-vpce"
  }
}
