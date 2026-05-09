project_name = "prompt-manager"
environment  = "dev"

lambda_memory_size = 256
lambda_timeout     = 10
log_retention_days = 14

cors_allow_origin = "*"

additional_tags = {
  Owner   = "learning"
  Purpose = "prompt-api-dev"
}