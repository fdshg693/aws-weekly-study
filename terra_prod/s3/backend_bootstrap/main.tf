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

  generated_state_bucket_name = "tfstate-${local.normalized_project}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  generated_lock_table_name   = "terraform-lock-${local.normalized_project}-${replace(var.aws_region, "-", "")}"

  effective_state_bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : local.generated_state_bucket_name
  effective_lock_table_name   = var.lock_table_name != "" ? var.lock_table_name : local.generated_lock_table_name
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = local.effective_state_bucket_name
  force_destroy = var.force_destroy_state_bucket

  tags = {
    Name        = local.effective_state_bucket_name
    Environment = "shared"
    Purpose     = "terraform remote state"
  }
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

  tags = {
    Name        = local.effective_lock_table_name
    Environment = "shared"
    Purpose     = "terraform state locking"
  }
}
