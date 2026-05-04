# Data sources
# ------------
# This project intentionally reuses the account's default VPC and default subnets so
# that the sample stays compact. If the default VPC or default subnets are missing,
# Terraform will fail naturally and the README explains that requirement.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_route_tables" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_prefix_list" "dynamodb" {
  name = "com.amazonaws.${var.aws_region}.dynamodb"
}

# Amazon Linux 2023 x86_64 AMI
# ----------------------------
# We pin only by family and architecture so that the newest AL2023 patch release is
# selected automatically when Terraform is applied.

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Lambda package archive
# ----------------------
# archive_file gives us a simple deterministic zip created directly from src/ without
# adding another build tool. If the source file changes, source_code_hash changes too.

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/src"
  output_path = "${path.module}/lambda_bundle.zip"
}
