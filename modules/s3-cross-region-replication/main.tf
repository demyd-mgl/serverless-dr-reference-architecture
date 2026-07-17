# Cross-region replication requires versioning on both buckets. With
# Replication Time Control (RTC) enabled, AWS commits to replicating 99.99%
# of new objects within 15 minutes and publishes a
# S3.replicationLatency / OperationsFailedReplication metric pair you can
# alarm on. Without RTC, replication is "best effort" (typically minutes,
# no SLA). RPO for anything stored in S3 is bounded by whichever of these
# you choose - see scripts/measure-rto-rpo.sh for measuring your actual lag.

data "aws_caller_identity" "current" {
  provider = aws.primary
}

resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "${var.project_name}-${var.environment}-primary-${data.aws_caller_identity.current.account_id}"
  tags     = var.tags
}

resource "aws_s3_bucket" "replica" {
  provider = aws.secondary
  bucket   = "${var.project_name}-${var.environment}-replica-${data.aws_caller_identity.current.account_id}"
  tags     = var.tags
}

resource "aws_s3_bucket_versioning" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "primary" {
  provider                = aws.primary
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "replica" {
  provider                = aws.secondary
  bucket                  = aws_s3_bucket.replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.replica.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role" "replication" {
  provider = aws.primary
  name     = "${var.project_name}-${var.environment}-s3-replication"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "replication" {
  provider = aws.primary
  name     = "${var.project_name}-${var.environment}-s3-replication"
  role     = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = [aws_s3_bucket.primary.arn]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Resource = ["${aws_s3_bucket.primary.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Resource = ["${aws_s3_bucket.replica.arn}/*"]
      }
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "this" {
  provider = aws.primary
  # Versioning must exist before the replication config is created.
  depends_on = [
    aws_s3_bucket_versioning.primary,
    aws_s3_bucket_versioning.replica
  ]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "dr-replication"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"

      dynamic "replication_time" {
        for_each = var.enable_replication_time_control ? [1] : []
        content {
          status = "Enabled"
          time {
            minutes = 15
          }
        }
      }

      dynamic "metrics" {
        for_each = var.enable_replication_time_control ? [1] : []
        content {
          status = "Enabled"
          event_threshold {
            minutes = 15
          }
        }
      }
    }
  }
}
