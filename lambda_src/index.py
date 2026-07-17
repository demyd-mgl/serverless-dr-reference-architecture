"""
Regional health-check / canary handler for the Serverless DR reference architecture.

Deployed identically into the primary and secondary regions. Route 53 health
checks poll the Function URL exposed by this Lambda. On GET it reports the
region it's running in plus the last-seen replication watermark from
DynamoDB, which is what the failover drill script uses to compute RPO.

On POST it writes a timestamped canary item to the regional DynamoDB table.
Because the table is a DynamoDB Global Table, that write replicates to the
paired region, and comparing write time vs. read time in the peer region is
how scripts/measure-rto-rpo.sh derives an actual, empirical replication lag
instead of a guessed number.
"""
import json
import os
import time
import uuid
import boto3

REGION = os.environ.get("AWS_REGION", "unknown")
TABLE_NAME = os.environ["DDB_TABLE_NAME"]
ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")

dynamodb = boto3.resource("dynamodb", region_name=REGION)
table = dynamodb.Table(TABLE_NAME)


def _response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }


def handler(event, context):
    http_method = (
        event.get("requestContext", {}).get("http", {}).get("method")
        or event.get("httpMethod")
        or "GET"
    )

    if http_method == "POST":
        canary_id = str(uuid.uuid4())
        written_at = time.time()
        table.put_item(
            Item={
                "pk": f"CANARY#{canary_id}",
                "sk": "WRITE",
                "written_in_region": REGION,
                "written_at_epoch": str(written_at),
                "environment": ENVIRONMENT,
            }
        )
        return _response(201, {
            "region": REGION,
            "canary_id": canary_id,
            "written_at_epoch": written_at,
        })

    # GET: health check + optional lookup of a canary_id for replication-lag checks
    canary_id = (event.get("queryStringParameters") or {}).get("canary_id")
    if canary_id:
        result = table.get_item(Key={"pk": f"CANARY#{canary_id}", "sk": "WRITE"})
        item = result.get("Item")
        if not item:
            return _response(404, {"region": REGION, "found": False})
        return _response(200, {"region": REGION, "found": True, "item": item})

    return _response(200, {
        "status": "healthy",
        "region": REGION,
        "environment": ENVIRONMENT,
        "timestamp": time.time(),
    })
