# serverless-dr-reference-architecture
A `terraform apply`-ready module deploying a multi-region, serverless disaster-recovery pattern on AWS: **Lambda + DynamoDB Global Tables + S3 Cross-Region Replication**, with **Route 53 health-check failover** doing the actual traffic cutover — no manual DNS changes, no runbook step where a human flips a switch.
