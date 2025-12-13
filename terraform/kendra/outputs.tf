output "kendra_index_id" {
  description = "Kendra index ID"
  value       = aws_kendra_index.this.id
}

output "kendra_index_arn" {
  description = "Kendra index ARN"
  value       = aws_kendra_index.this.arn
}

output "kendra_data_source_id" {
  description = "Kendra data source ID"
  value       = aws_kendra_data_source.webcrawler.id
}

output "kendra_data_source_name" {
  description = "Kendra data source name"
  value       = aws_kendra_data_source.webcrawler.name
}

output "kendra_data_source_schedule" {
  description = "Kendra data source schedule (cron)"
  value       = aws_kendra_data_source.webcrawler.schedule
}
