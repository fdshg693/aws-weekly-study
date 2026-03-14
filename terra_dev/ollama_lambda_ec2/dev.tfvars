# Development environment values
# --------------------------
# Replace shared_api_secret before applying. Because this sample stores the secret value
# through aws_secretsmanager_secret_version, the plaintext also lands in Terraform state.

environment                   = "dev"
instance_type                 = "t3.medium"
default_model                 = "qwen2.5:0.5b"
shared_api_secret             = "CHANGE-ME-DEV-SHARED-SECRET"
lambda_log_retention_days     = 14
api_access_log_retention_days = 14
