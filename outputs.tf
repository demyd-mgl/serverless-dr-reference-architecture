output "primary_function_url" {
  value = module.lambda_primary.function_url
}

output "secondary_function_url" {
  value = module.lambda_secondary.function_url
}

output "failover_dns_name" {
  value = module.failover.failover_dns_name
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "s3_primary_bucket" {
  value = module.s3_replication.primary_bucket_name
}

output "s3_replica_bucket" {
  value = module.s3_replication.replica_bucket_name
}

output "sns_alert_topic_arn" {
  value = module.failover.sns_topic_arn
}

output "measure_rto_rpo_command" {
  description = "Run this after `terraform apply` to generate real, measured RTO/RPO numbers for your account and region pair."
  value       = "./scripts/measure-rto-rpo.sh ${module.lambda_primary.function_url} ${module.lambda_secondary.function_url} ${module.failover.primary_health_check_id}"
}
