# Production environment values
# ---------------------------
# Replace shared_api_secret before applying. A production deployment should store the
# Terraform state in a protected remote backend because the secret plaintext is sensitive.

environment                   = "prod"
instance_type                 = "t3.large"
default_model                 = "qwen2.5:0.5b"
shared_api_secret             = "CHANGE-ME-PROD-SHARED-SECRET"
lambda_log_retention_days     = 30
api_access_log_retention_days = 30
