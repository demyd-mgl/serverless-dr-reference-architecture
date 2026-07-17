# Automated failover mechanism: Route 53 health checks poll each region's
# Lambda Function URL. If the primary fails `failure_threshold` consecutive
# checks (each `request_interval` seconds apart), Route 53 stops returning
# the PRIMARY record and clients resolving the DNS name get the SECONDARY
# record instead - no human intervention required.
#
# RTO for the DNS layer is bounded by:
#   (failure_threshold * request_interval) + DNS TTL + client cache behavior
# e.g. with the defaults (3 * 10s) + 30s TTL ~= 60s worst case, though actual
# client-observed RTO depends on resolver caching. Measure it for real with
# scripts/measure-rto-rpo.sh, which kills the primary health check and times
# how long a polling client takes to observe the secondary's responses.

resource "aws_route53_health_check" "primary" {
  provider          = aws.primary
  fqdn              = var.primary_endpoint_hostname
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = var.failure_threshold
  request_interval  = var.request_interval
  measure_latency   = true

  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-primary-health" })
}

resource "aws_route53_health_check" "secondary" {
  provider          = aws.primary
  fqdn              = var.secondary_endpoint_hostname
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = var.failure_threshold
  request_interval  = var.request_interval
  measure_latency   = true

  tags = merge(var.tags, { Name = "${var.project_name}-${var.environment}-secondary-health" })
}

resource "aws_route53_record" "primary" {
  count = var.hosted_zone_id != null ? 1 : 0

  provider = aws.primary
  zone_id  = var.hosted_zone_id
  name     = var.dns_record_name
  type     = "CNAME"
  ttl      = var.record_ttl
  records  = [var.primary_endpoint_hostname]

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary.id
}

resource "aws_route53_record" "secondary" {
  count = var.hosted_zone_id != null ? 1 : 0

  provider = aws.primary
  zone_id  = var.hosted_zone_id
  name     = var.dns_record_name
  type     = "CNAME"
  ttl      = var.record_ttl
  records  = [var.secondary_endpoint_hostname]

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier  = "secondary"
  health_check_id = aws_route53_health_check.secondary.id
}

# Lives in us-east-1 alongside the alarm below, since a CloudWatch alarm's
# alarm_actions must reference an SNS topic in the same region as the alarm.
resource "aws_sns_topic" "failover_alerts" {
  provider = aws.us_east_1
  name     = "${var.project_name}-${var.environment}-failover-alerts"
  tags     = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_notification_email != null ? 1 : 0
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.failover_alerts.arn
  protocol  = "email"
  endpoint  = var.alarm_notification_email
}

resource "aws_cloudwatch_metric_alarm" "primary_unhealthy" {
  # Route 53 health-check metrics are only published to CloudWatch in
  # us-east-1, regardless of which region the health check itself lives
  # in. This alarm must be created there or it will silently never fire.
  provider            = aws.us_east_1
  alarm_name          = "${var.project_name}-${var.environment}-primary-region-unhealthy"
  alarm_description   = "Fires when Route 53 marks the primary region endpoint unhealthy, i.e. a failover is in progress or imminent."
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  treat_missing_data  = "breaching"

  dimensions = {
    HealthCheckId = aws_route53_health_check.primary.id
  }

  alarm_actions = [aws_sns_topic.failover_alerts.arn]
  ok_actions    = [aws_sns_topic.failover_alerts.arn]
  tags          = var.tags
}
