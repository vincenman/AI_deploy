import json
import os
from datetime import datetime, timezone

import boto3

MODEL_ID = os.environ.get("BEDROCK_MODEL_ID", "amazon.nova-lite-v1:0")
MAX_TOKENS = int(os.environ.get("MAX_TOKENS", "200"))
SYSTEM_PROMPT = os.environ.get(
    "SYSTEM_PROMPT", "You are a concise assistant. Answer in at most three sentences."
)

# Created once per container and reused across warm invocations.
bedrock = boto3.client("bedrock-runtime")


def handler(event, context):
    """Tiny AI API: /, /health, /ask (POST {"question": "..."}) backed by Amazon Bedrock."""
    http = event.get("requestContext", {}).get("http", {})
    method = http.get("method", "GET")
    path = event.get("rawPath", "/")

    if path == "/":
        status, body = 200, {"message": "Hello from the AI lab!", "managed_by": "terraform"}
    elif path == "/health":
        status, body = 200, {"status": "ok", "time": datetime.now(timezone.utc).isoformat()}
    elif path == "/ask" and method == "POST":
        question = ""
        if event.get("body"):
            try:
                question = (json.loads(event["body"]).get("question") or "").strip()
            except (json.JSONDecodeError, AttributeError):
                question = ""
        if not question:
            status, body = 400, {"error": 'Send JSON like {"question": "your question"}'}
        else:
            try:
                reply = bedrock.converse(
                    modelId=MODEL_ID,
                    messages=[{"role": "user", "content": [{"text": question}]}],
                    system=[{"text": SYSTEM_PROMPT}],
                    inferenceConfig={"maxTokens": MAX_TOKENS},
                )
                answer = reply["output"]["message"]["content"][0]["text"]
                status, body = 200, {"answer": answer, "model": MODEL_ID}
            except Exception as exc:
                # Keep the API response friendly; full details go to CloudWatch Logs.
                print(f"Bedrock call failed: {exc}")
                status, body = 502, {"error": "AI provider error", "detail": str(exc)[:300]}
    else:
        status, body = 404, {"message": f"No route for {method} {path}"}

    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
