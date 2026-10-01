import json
import os
from datetime import datetime, timezone

import boto3

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET_NAME"]


def handler(event, context):
    """Save a timestamped record to the data bucket and return its key."""
    now = datetime.now(timezone.utc).isoformat()
    key = f"records/{now}.json"

    s3.put_object(
        Bucket=BUCKET,
        Key=key,
        Body=json.dumps({"received_at": now, "event": event}),
        ContentType="application/json",
    )

    return {"statusCode": 200, "body": json.dumps({"stored": key})}
