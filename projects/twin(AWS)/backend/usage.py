"""Demo message quotas: 10 per visitor per day, 200 per month across all visitors.

Counters live in DynamoDB and are updated in a single transaction, so a refused
request consumes nothing and two simultaneous requests can't both slip past the
last remaining slot.
"""

import os
from datetime import datetime, timedelta, timezone

import boto3
from botocore.exceptions import ClientError
from fastapi import HTTPException

USAGE_TABLE = os.getenv("USAGE_TABLE", "twin-usage")
DAILY_LIMIT = int(os.getenv("DAILY_LIMIT", "10"))
MONTHLY_LIMIT = int(os.getenv("MONTHLY_LIMIT", "200"))

_client = None


def _dynamodb():
    global _client
    if _client is None:
        region = (
            os.getenv("AWS_REGION")
            or os.getenv("AWS_DEFAULT_REGION")
            or os.getenv("DEFAULT_AWS_REGION")
            or "us-east-2"
        )
        _client = boto3.client("dynamodb", region_name=region)
    return _client


def _counter_update(key: str, limit: int, ttl_epoch: int) -> dict:
    return {
        "Update": {
            "TableName": USAGE_TABLE,
            "Key": {"pk": {"S": key}},
            "UpdateExpression": "ADD #c :one SET expires_at = :ttl",
            "ConditionExpression": "attribute_not_exists(#c) OR #c < :limit",
            "ExpressionAttributeNames": {"#c": "count"},
            "ExpressionAttributeValues": {
                ":one": {"N": "1"},
                ":limit": {"N": str(limit)},
                ":ttl": {"N": str(ttl_epoch)},
            },
        }
    }


def check_limits(ip: str) -> None:
    """Consume one message from the visitor's daily quota and the global monthly quota."""
    now = datetime.now(timezone.utc)
    day_key = f"USER#{ip}#{now:%Y-%m-%d}"
    month_key = f"GLOBAL#{now:%Y-%m}"

    items = [
        _counter_update(day_key, DAILY_LIMIT, int((now + timedelta(days=2)).timestamp())),
        _counter_update(month_key, MONTHLY_LIMIT, int((now + timedelta(days=40)).timestamp())),
    ]

    try:
        _dynamodb().transact_write_items(TransactItems=items)
    except ClientError as e:
        if e.response["Error"]["Code"] != "TransactionCanceledException":
            raise
        reasons = e.response.get("CancellationReasons", [])
        if reasons and reasons[0].get("Code") == "ConditionalCheckFailed":
            raise HTTPException(
                status_code=429,
                detail=(
                    f"You've reached today's demo limit of {DAILY_LIMIT} messages. "
                    "Please come back tomorrow!"
                ),
            ) from e
        raise HTTPException(
            status_code=429,
            detail=(
                f"This demo has reached its monthly limit of {MONTHLY_LIMIT} messages. "
                "Please check back next month."
            ),
        ) from e
