output "primary_bucket_name" {
  value = aws_s3_bucket.primary.id
}

output "replica_bucket_name" {
  value = aws_s3_bucket.replica.id
}

output "primary_bucket_arn" {
  value = aws_s3_bucket.primary.arn
}

output "replica_bucket_arn" {
  value = aws_s3_bucket.replica.arn
}
