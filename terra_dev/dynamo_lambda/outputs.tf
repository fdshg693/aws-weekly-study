output "api_base_url" {
  description = "Base invoke URL for the REST API stage"
  value       = "https://${aws_api_gateway_rest_api.prompts.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.prompts.stage_name}"
}

output "prompts_collection_url" {
  description = "Prompt collection endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.prompts.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.prompts.stage_name}/prompts"
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table used for prompt storage"
  value       = aws_dynamodb_table.prompts.name
}

output "lambda_function_name" {
  description = "Name of the prompt API Lambda function"
  value       = aws_lambda_function.prompt_api.function_name
}