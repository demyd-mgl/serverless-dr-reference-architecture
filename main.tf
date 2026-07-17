#############################################
# Data layer: DynamoDB Global Table (both regions, one resource)
#############################################
module "dynamodb" {
  source = "./modules/dynamodb-global-table"

  providers = {
    aws.primary = aws.primary
  }

  project_name     = var.project_name
  environment      = var.environment
  secondary_region = var.secondary_region
  billing_mode     = var.dynamodb_billing_mode
  tags             = var.tags
}

#############################################
# Storage layer: S3 bucket + cross-region replica
#############################################
module "s3_replication" {
  source = "./modules/s3-cross-region-replication"

  providers = {
    aws.primary   = aws.primary
    aws.secondary = aws.secondary
  }

  project_name                     = var.project_name
  environment                      = var.environment
  enable_replication_time_control  = var.s3_enable_replication_time_control
  tags                              = var.tags
}

#############################################
# Compute layer: identical Lambda in each region
#############################################
module "lambda_primary" {
  source = "./modules/lambda-region"

  providers = {
    aws.this = aws.primary
  }

  project_name         = var.project_name
  environment          = var.environment
  region_name          = "primary"
  lambda_source_dir    = "${path.module}/lambda_src"
  lambda_runtime       = var.lambda_runtime
  lambda_timeout       = var.lambda_timeout
  lambda_memory_size   = var.lambda_memory_size
  dynamodb_table_name  = module.dynamodb.table_name
  dynamodb_table_arn   = module.dynamodb.table_arn
  tags                 = var.tags
}

module "lambda_secondary" {
  source = "./modules/lambda-region"

  providers = {
    aws.this = aws.secondary
  }

  project_name         = var.project_name
  environment          = var.environment
  region_name          = "secondary"
  lambda_source_dir    = "${path.module}/lambda_src"
  lambda_runtime       = var.lambda_runtime
  lambda_timeout       = var.lambda_timeout
  lambda_memory_size   = var.lambda_memory_size
  dynamodb_table_name  = module.dynamodb.table_name
  dynamodb_table_arn   = module.dynamodb.table_arn
  tags                 = var.tags
}

#############################################
# Failover layer: Route 53 health checks + failover routing + alarms
#############################################
module "failover" {
  source = "./modules/route53-failover"

  providers = {
    aws.primary   = aws.primary
    aws.us_east_1 = aws.us_east_1
  }

  project_name                = var.project_name
  environment                 = var.environment
  primary_endpoint_hostname   = module.lambda_primary.function_url_hostname
  secondary_endpoint_hostname = module.lambda_secondary.function_url_hostname
  hosted_zone_id              = var.hosted_zone_id
  dns_record_name             = var.dns_record_name
  failure_threshold           = var.route53_health_check_failure_threshold
  request_interval            = var.route53_health_check_interval
  record_ttl                  = var.route53_record_ttl
  alarm_notification_email    = var.alarm_notification_email
  tags                        = var.tags
}
