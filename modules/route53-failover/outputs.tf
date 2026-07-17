output "primary_health_check_id" {
  value = aws_route53_health_check.primary.id
}

output "secondary_health_check_id" {
  value = aws_route53_health_check.secondary.id
}

output "failover_dns_name" {
  value       = var.hosted_zone_id != null ? var.dns_record_name : null
  description = "The DNS name clients should use, if hosted_zone_id was set. Null otherwise - call the two Lambda Function URLs directly."
}

output "sns_topic_arn" {
  value = aws_sns_topic.failover_alerts.arn
}
