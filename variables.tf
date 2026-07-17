variable "project_name" {
  description = "Short name used as a prefix for all resources."
  type        = string
  default     = "serverless-dr"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "primary_region" {
  description = "Primary (active) AWS region."
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary (standby/failover) AWS region."
  type        = string
  default     = "us-west-2"
}

variable "lambda_runtime" {
  description = "Lambda runtime for the regional handler."
  type        = string
  default     = "python3.12"
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds."
  type        = number
  default     = 10
}

variable "lambda_memory_size" {
  description = "Lambda memory in MB."
  type        = number
  default     = 128
}

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode. PAY_PER_REQUEST is recommended for DR since traffic on the standby region is near-zero."
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "s3_enable_replication_time_control" {
  description = "Enable S3 Replication Time Control (RTC), which gives a 15-minute, 99.99% SLA on replication instead of the 'best effort' default. Adds cost per GB replicated."
  type        = bool
  default     = true
}

variable "route53_health_check_failure_threshold" {
  description = "Number of consecutive failed health checks before Route 53 considers the primary endpoint down. Lower = faster failover, higher = fewer false positives."
  type        = number
  default     = 3
}

variable "route53_health_check_interval" {
  description = "Seconds between Route 53 health checks. Valid values: 10 or 30."
  type        = number
  default     = 10
}

variable "route53_record_ttl" {
  description = "TTL in seconds for the failover DNS record. Bounds how long clients cache the pre-failover answer."
  type        = number
  default     = 30
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID to create the failover record in. Leave null to skip DNS failover and only deploy the health checks + regional endpoints (useful if you don't own a domain yet)."
  type        = string
  default     = null
}

variable "dns_record_name" {
  description = "Fully-qualified DNS name for the failover record, e.g. api.example.com. Required if hosted_zone_id is set."
  type        = string
  default     = null
}

variable "alarm_notification_email" {
  description = "Optional email address subscribed to the SNS topic that fires on failover-related CloudWatch alarms. Leave null to skip the subscription."
  type        = string
  default     = null
}

variable "tags" {
  description = "Extra tags merged into every resource."
  type        = map(string)
  default     = {}
}

locals {
  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }, var.tags)
}
