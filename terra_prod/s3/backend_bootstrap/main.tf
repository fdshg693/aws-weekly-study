data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "terraform_state_bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

locals {
  normalized_project = trim(replace(lower(var.project_name), "/[^a-z0-9-]/", "-"), "-")

  bootstrap_name_prefix = "${local.normalized_project}-shared-${data.aws_caller_identity.current.account_id}-${var.aws_region}"

  generated_state_bucket_name = "${local.bootstrap_name_prefix}-tfstate"
  generated_lock_table_name   = "${local.bootstrap_name_prefix}-terraform-lock"

  effective_state_bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : local.generated_state_bucket_name
  effective_lock_table_name   = var.lock_table_name != "" ? var.lock_table_name : local.generated_lock_table_name

  default_tags = merge(
    {
      ManagedBy   = "Terraform"
      Project     = local.normalized_project
      Environment = "shared"
      Purpose     = "terraform-state-management"
    },
    var.tags,
  )

  resource_tags = {
    terraform_state = {
      Name         = local.effective_state_bucket_name
      ResourceRole = "tfstate"
      Purpose      = "terraform remote state"
    }
    terraform_lock = {
      Name         = local.effective_lock_table_name
      ResourceRole = "terraform-lock"
      Purpose      = "terraform state locking"
    }
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = local.effective_state_bucket_name
  force_destroy = var.force_destroy_state_bucket

  tags = local.resource_tags.terraform_state
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = data.aws_iam_policy_document.terraform_state_bucket.json
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = local.effective_lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.resource_tags.terraform_lock
}
