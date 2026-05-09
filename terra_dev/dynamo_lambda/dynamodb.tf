resource "aws_dynamodb_table" "prompts" {
  name         = "${var.project_name}-prompts-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "access_pk"
    type = "S"
  }

  attribute {
    name = "access_sk"
    type = "S"
  }

  global_secondary_index {
    name            = "access_pattern_index"
    projection_type = "INCLUDE"
    non_key_attributes = [
      "entity_type",
      "prompt_id",
      "tag",
      "name",
      "description",
      "tags",
      "target_model",
      "version",
      "is_active",
      "created_at",
      "updated_at",
    ]

    key_schema {
      attribute_name = "access_pk"
      key_type       = "HASH"
    }

    key_schema {
      attribute_name = "access_sk"
      key_type       = "RANGE"
    }
  }

  tags = merge(
    {
      Name      = "${var.project_name}-prompts-${var.environment}"
      Component = "Database"
      Purpose   = "Prompt definition storage"
    },
    var.additional_tags,
  )
}