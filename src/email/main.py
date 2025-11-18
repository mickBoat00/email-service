import json

def lambda_handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
        recipient = body.get("recipient")
        subject = body.get("subject")
        message = body.get("message")

        if not recipient or not subject or not message:
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Missing recipient, subject or message"})
            }

        return {
            "statusCode": 200,
            "body": json.dumps({
                "status": "success",
                "message": f"Email request accepted for {recipient}",
                "details": {
                    "subject": subject,
                    "message": message
                }
            })
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
