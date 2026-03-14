# Network and security
# --------------------
# The sample deliberately avoids NAT Gateway to keep cost and moving parts down.
# Because the Lambda function still needs to call Secrets Manager from inside the VPC,
# we create an Interface VPC Endpoint with private DNS enabled.

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
