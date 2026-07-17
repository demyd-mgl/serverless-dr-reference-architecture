# DR Runbook

## Detection

- Route 53 health check `${project_name}-${environment}-primary-region-unhealthy`
  alarms to the SNS topic in `sns_alert_topic_arn`. Subscribe on-call to it
  (set `alarm_notification_email`, or attach a Chatbot/Slack integration to
  the topic).
- The alarm is created in `us-east-1` regardless of `primary_region`, because
  that's where CloudWatch publishes Route 53 health-check metrics.

## During an active failover

1. Confirm it's real: check the primary Lambda's CloudWatch Logs and the
   `aws_route53_health_check.primary` status in the console or via
   `aws route53 get-health-check-status --health-check-id <id>`.
2. Traffic is already moving - Route 53 failover routing is automatic once
   the health check fails `failure_threshold` consecutive times. There is no
   manual DNS step.
3. Verify the secondary region is actually serving traffic and writes are
   landing in DynamoDB (global table replication is bidirectional, so writes
   accepted by the secondary during the outage will replicate back to the
   primary once it recovers - watch for write conflicts if both regions
   accepted writes during a network partition rather than a clean primary
   failure).
4. Check `s3_replica_bucket` for the latest expected objects if the
   workload depends on S3 content being current.

## Recovery (failback)

1. Once the primary is healthy again, Route 53 will automatically start
   directing traffic back to it (failover routing, not "sticky" failover) -
   confirm this is the behavior you want. If you'd rather stay on the
   secondary until you can validate the primary manually, temporarily set
   the primary health check's `invert_healthcheck` or disable the record
   before restoring service, then re-enable deliberately.
2. Reconcile any DynamoDB items written to the secondary during the outage -
   Global Tables use last-writer-wins conflict resolution, so check for
   unexpected overwrites if the same keys were written on both sides.
3. Re-run `scripts/measure-rto-rpo.sh` post-incident and compare against
   your baseline drill numbers - a real incident is also a data point.

## Regular drills

Run `scripts/failover-drill.sh` and `scripts/measure-rto-rpo.sh` on a
schedule (quarterly is a reasonable starting cadence) and keep the results
in the README's "Measured results" table with a date and git commit hash, so
the numbers don't silently drift out of date as the infrastructure changes.
