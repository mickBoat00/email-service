import os
import json
import boto3
import hashlib
from pymongo import MongoClient

from botocore.exceptions import ClientError

client = MongoClient(host=os.environ["MONGODB_URI"])
db = client.get_database()
collection = db.get_collection("apps")

client = boto3.client('ses', region_name=os.getenv('AWS_REGION', 'eu-east-2'))

def hash_key(key):
    return hashlib.sha256(key.encode()).hexdigest()

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
        
        api_key = event["headers"].get("x-api-key")
        if not api_key:
            return {
                "statusCode": 401,
                "body": json.dumps({"error": "Missing API key"})
            }   

        api_key_hash = hash_key(api_key)
        
        app = collection.find_one({"apiKeyHash": api_key_hash})
        if not app:
            return {
                "statusCode": 403,
                "body": json.dumps({"error": "Invalid API key"})
            }   

        sender = app["email_sender"]

        response = client.send_email(
            Destination={
                'ToAddresses': [
                    recipient,
                ],
            },
            Message={
                'Body': {
                    'Text': {
                        'Charset': "UTF-8",
                        'Data': message,
                    },
                },
                'Subject': {
                    'Charset': "UTF-8",
                    'Data': subject,
                },
            },
            Source=sender,
        )

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "Email sent successfully",
                "messageId": response['MessageId']
            })
        }


    except ClientError as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": e.response['Error']['Message']})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
