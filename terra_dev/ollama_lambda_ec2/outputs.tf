output "api_endpoint" {
  description = "Base HTTPS endpoint for the HTTP API. With the $default stage, append /generate directly."
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "generate_url" {
  description = "Ready-to-use POST endpoint for prompt generation requests."
  value       = "${aws_apigatewayv2_api.http.api_endpoint}/generate"
}

output "lambda_function_name" {
  description = "Name of the Lambda proxy function."
  value       = aws_lambda_function.proxy.function_name
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

output "default_vpc_id" {
  description = "Default VPC reused by this sample project."
  value       = data.aws_vpc.default.id
}
