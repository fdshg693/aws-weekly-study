# Async request pipeline
# ----------------------
# POST /generate now stores request metadata in DynamoDB and enqueues the work item into
# a FIFO queue. A dedicated worker Lambda processes the queue serially and writes the
# final success or failure result back to DynamoDB.

resource "aws_sqs_queue" "request_dlq" {
  name                        = local.request_dlq_name
  fifo_queue                  = true
  message_retention_seconds   = var.sqs_message_retention_seconds
  content_based_deduplication = false

  tags = {
    Name = "${local.name_prefix}-requests-dlq"
  }
}

resource "aws_sqs_queue" "request_queue" {
  name                        = local.request_queue_name
  fifo_queue                  = true
  content_based_deduplication = false
  visibility_timeout_seconds  = var.sqs_visibility_timeout_seconds
  message_retention_seconds   = var.sqs_message_retention_seconds

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.request_dlq.arn
    maxReceiveCount     = var.sqs_max_receive_count
  })

  tags = {
    Name = "${local.name_prefix}-requests"
  }
}

resource "aws_dynamodb_table" "requests" {
  name         = local.request_status_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "request_id"

  attribute {
    name = "request_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name = "${local.name_prefix}-requests"
  }
}

resource "aws_lambda_event_source_mapping" "worker_sqs" {
  event_source_arn = aws_sqs_queue.request_queue.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 1
  enabled          = true
}