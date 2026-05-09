project_name = "prompt-manager"
environment  = "prod"

lambda_memory_size = 256
lambda_timeout     = 10
log_retention_days = 30

cors_allow_origin = "*"

additional_tags = {
  Owner   = "learning"
  Purpose = "prompt-api-prod"
}