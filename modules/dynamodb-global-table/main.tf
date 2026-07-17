# DynamoDB Global Tables (v2, resource-based) create the table in the
# primary region and manage the replica in the secondary region from a
# single resource. Streams must be enabled for global tables to work.
#
# RPO for this component is bounded by DynamoDB's cross-region replication
# lag, which AWS publishes as typically sub-second under normal load. Actual
# lag for your workload should be measured with scripts/measure-rto-rpo.sh
# (write in one region, poll for visibility in the other, diff the
# timestamps).

resource "aws_dynamodb_table" "this" {
  provider = aws.primary

  name         = "${var.project_name}-${var.environment}"
  billing_mode = var.billing_mode
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  point_in_time_recovery {
    enabled = true
  }

  replica {
    region_name            = var.secondary_region
    point_in_time_recovery = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = var.tags
}
