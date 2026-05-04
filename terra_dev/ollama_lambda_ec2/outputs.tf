output "api_endpoint" {
  description = "Base HTTPS endpoint for the HTTP API. With the $default stage, append /generate or /requests/{request_id}."
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "generate_url" {
  description = "Ready-to-use POST endpoint for asynchronous prompt generation requests."
  value       = "${aws_apigatewayv2_api.http.api_endpoint}/generate"
}

output "request_status_url_template" {
  description = "Template for polling request status after POST /generate returns a request_id."
  value       = "${aws_apigatewayv2_api.http.api_endpoint}/requests/{request_id}"
}

output "lambda_function_name" {
  description = "Name of the API Lambda function that accepts requests and returns status."
  value       = aws_lambda_function.api.function_name
}

output "worker_lambda_function_name" {
  description = "Name of the worker Lambda function that drains the FIFO queue and calls Ollama."
  value       = aws_lambda_function.worker.function_name
}

output "ec2_instance_id" {
  description = "Instance ID of the Ollama EC2 host. Useful for Session Manager and Ansible inventory checks."
  value       = aws_instance.ollama.id
}

output "ec2_private_ip" {
  description = "Private IP address used by the Lambda function to reach Ollama."
  value       = aws_instance.ollama.private_ip
}

output "ec2_public_ip" {
  description = "Public IP assigned for bootstrap egress and Session Manager friendliness. No inbound internet rules are opened."
  value       = aws_instance.ollama.public_ip
}

output "shared_api_secret_arn" {
  description = "Secrets Manager ARN that Lambda reads at runtime."
  value       = aws_secretsmanager_secret.shared_api_secret.arn
}

output "shared_api_secret_name" {
  description = "Secrets Manager name that operators can use with the AWS CLI."
  value       = aws_secretsmanager_secret.shared_api_secret.name
}

output "request_queue_url" {
  description = "URL of the FIFO queue that serializes Ollama requests."
  value       = aws_sqs_queue.request_queue.id
}

output "request_status_table_name" {
  description = "DynamoDB table that stores queued request state and completed results."
  value       = aws_dynamodb_table.requests.name
}

output "default_vpc_id" {
  description = "Default VPC reused by this sample project."
  value       = data.aws_vpc.default.id
}
